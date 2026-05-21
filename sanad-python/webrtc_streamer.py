"""
webrtc_streamer.py — WebRTC + Socket.IO (Python camera side)

DEMO MODE: Python + Docker + iOS Simulator all on same Mac.
- No TURN server (it routes through internet and breaks local connections)
- No STUN needed either (no NAT to traverse on localhost)
- ICE uses only host candidates (loopback / LAN)
- Camera registers as a pool device (no elderly_id needed at startup)
- Works for ANY caregiver/elder pair that connects from the app
"""

import asyncio
import logging
import threading
import cv2
import numpy as np
import uuid

from aiortc import (
    RTCPeerConnection,
    RTCSessionDescription,
    RTCConfiguration,
    RTCIceServer,
    VideoStreamTrack,
)
from aiortc.sdp import candidate_from_sdp
from av import VideoFrame
import socketio

import config

logger = logging.getLogger(__name__)

CAMERA_DEVICE_ID = config.CAMERA_DEVICE_ID or str(uuid.getnode())


def _build_ice_config() -> RTCConfiguration:
    """
    STUN servers help ICE gather a complete candidate set reliably.
    Even on the same Mac, host-only gathering can miss the right interface.
    No TURN — we don't want traffic routed through the internet.
    """
    return RTCConfiguration(iceServers=[
        RTCIceServer(urls=["stun:stun.l.google.com:19302"]),
        RTCIceServer(urls=["stun:stun1.l.google.com:19302"]),
    ])


class CameraVideoTrack(VideoStreamTrack):
    """One track per peer connection. Reads frames from a shared callable
    so the streamer can swap tracks freely between connect/disconnect cycles
    without losing the live frame source. (aiortc stops the track when its
    owning pc closes — a shared track would die after the first session.)
    """
    kind = "video"

    def __init__(self, frame_source):
        super().__init__()
        self._frame_source = frame_source  # () -> Optional[np.ndarray] (BGR)

    async def recv(self) -> VideoFrame:
        pts, time_base = await self.next_timestamp()
        src = self._frame_source()

        if src is not None:
            rgb      = cv2.cvtColor(src, cv2.COLOR_BGR2RGB)
            av_frame = VideoFrame.from_ndarray(rgb, format="rgb24")
        else:
            black    = np.zeros((config.FRAME_HEIGHT, config.FRAME_WIDTH, 3), np.uint8)
            av_frame = VideoFrame.from_ndarray(black, format="rgb24")

        av_frame.pts       = pts
        av_frame.time_base = time_base
        return av_frame


class WebRTCStreamer:
    def __init__(self):
        self.sio = socketio.AsyncClient(
            reconnection=True,
            reconnection_attempts=0,
            reconnection_delay=2,
            reconnection_delay_max=30,
            logger=False,
            engineio_logger=False,
        )
        self.peer_connections: dict[str, RTCPeerConnection] = {}
        self._pending_ice:     dict[str, list]              = {}
        self._frame_lock = threading.Lock()
        self._latest_frame: np.ndarray | None = None
        self._ice_config  = _build_ice_config()
        self._elderly_id: str | None = None

    def push_frame(self, frame: np.ndarray):
        with self._frame_lock:
            self._latest_frame = frame

    def _read_frame(self) -> np.ndarray | None:
        with self._frame_lock:
            return self._latest_frame

    async def start(self):
        # No elderly_id needed at startup — camera registers as a pool device.
        # The server assigns it to the right elderly when a caregiver connects.
        logger.info(f"📡 Starting as pool camera — device: {CAMERA_DEVICE_ID}")
        self._register_socket_events()
        await self.sio.connect(
            config.SERVER_URL,
            transports=["websocket"],
            wait_timeout=10,
        )
        await self.sio.wait()

    async def stop(self):
        await self._close_all_peers()
        if self.sio.connected:
            await self.sio.disconnect()

    def _register_socket_events(self):

        @self.sio.event
        async def connect():
            logger.info("✅ Socket connected to server")
            # Register as a pool camera — no elderly_id yet.
            # Server will send camera_assigned when a caregiver connects.
            await self.sio.emit("register_camera", {
                "camera_device_id": CAMERA_DEVICE_ID,
            })
            logger.info(f"📡 Registered as pool camera — device: {CAMERA_DEVICE_ID}")

        @self.sio.event
        async def disconnect():
            logger.warning("🔌 Disconnected — reconnecting...")
            self._elderly_id = None
            await self._close_all_peers()

        @self.sio.event
        async def connect_error(data):
            logger.error(f"❌ Connection error: {data}")

        @self.sio.on("camera_assigned")
        async def on_camera_assigned(data):
            """Server assigns this camera to a specific elderly when caregiver connects."""
            elderly_id = data.get("elderly_id") if isinstance(data, dict) else None
            if not elderly_id:
                logger.warning("⚠️  camera_assigned: missing elderly_id")
                return
            self._elderly_id = elderly_id
            config.ELDERLY_ID = elderly_id
            logger.info(f"🎯 Camera assigned to elderly: {elderly_id}")
            # Now register in the elder's room so signaling can reach us
            await self.sio.emit("register_elder", {
                "elderly_id":       self._elderly_id,
                "sender_id":        self._elderly_id,
                "camera_device_id": CAMERA_DEVICE_ID,
            })

        @self.sio.on("registered")
        async def on_registered(data):
            logger.info("✅ Server confirmed registration — ready for streams")

        @self.sio.on("start_stream")
        async def on_start_stream(data):
            caregiver_id = data.get("sender_id") or data.get("caregiver_id")
            if not caregiver_id:
                logger.warning("⚠️  start_stream: missing caregiver_id")
                return
            # Debounce: ignore duplicate start_stream events that arrive while
            # an offer/answer for this caregiver is still being negotiated.
            # The server occasionally fires two start_streams in quick succession
            # (re-notify + request_stream); a second _create_offer would close
            # the in-flight pc and corrupt the answer that's already on the wire.
            existing = self.peer_connections.get(caregiver_id)
            if existing is not None and existing.signalingState not in ("closed",):
                logger.info(
                    f"⏭️  Skipping duplicate start_stream — pc state: {existing.signalingState}"
                )
                return
            logger.info(f"📹 Stream request from caregiver: {caregiver_id}")
            await self._create_offer(caregiver_id)

        @self.sio.on("webrtc_answer")
        async def on_answer(data):
            caregiver_id = data.get("sender_id") or data.get("caregiver_id")
            answer       = data.get("answer")
            if not answer:
                return
            pc = self.peer_connections.get(caregiver_id)
            if pc is None:
                pc, caregiver_id = self._find_pc_awaiting_answer()
            # Guard against stale answers from a previously-closed offer arriving
            # after the pc was reset. setRemoteDescription would crash with
            # "'NoneType' object has no attribute 'media'" if localDescription
            # got cleared.
            if pc is None or pc.signalingState != "have-local-offer" or pc.localDescription is None:
                logger.info("⏭️  Ignoring stale/late webrtc_answer")
                return
            logger.info(f"📥 Answer received from caregiver: {caregiver_id}")
            try:
                await pc.setRemoteDescription(
                    RTCSessionDescription(sdp=answer["sdp"], type=answer["type"])
                )
            except Exception as e:
                logger.warning(f"setRemoteDescription failed (likely stale answer): {e}")
                return
            for candidate in self._pending_ice.pop(caregiver_id, []):
                await self._apply_ice(pc, candidate)

        @self.sio.on("ice_candidate")
        async def on_ice_candidate(data):
            caregiver_id = (
                data.get("sender_id") or data.get("caregiver_id") or data.get("from_id")
            )
            candidate = data.get("candidate")
            if not candidate or not caregiver_id:
                return
            pc = self.peer_connections.get(caregiver_id)
            if pc is None:
                return
            if pc.remoteDescription is None:
                self._pending_ice.setdefault(caregiver_id, []).append(candidate)
                return
            await self._apply_ice(pc, candidate)

        @self.sio.on("stop_stream")
        async def on_stop_stream(data=None):
            data = data or {}
            caregiver_id = data.get("sender_id") or data.get("caregiver_id")
            if caregiver_id and caregiver_id in self.peer_connections:
                await self._close_peer(caregiver_id)
            else:
                await self._close_all_peers()

    async def _create_offer(self, caregiver_id: str):
        if caregiver_id in self.peer_connections:
            await self._close_peer(caregiver_id)

        pc = RTCPeerConnection(self._ice_config)
        self.peer_connections[caregiver_id] = pc
        self._pending_ice[caregiver_id]     = []
        # Fresh track per pc — aiortc stops the track when its pc closes,
        # so a single shared instance would go dead after the first session.
        pc.addTrack(CameraVideoTrack(frame_source=self._read_frame))

        @pc.on("icecandidate")
        async def on_ice(candidate):
            if candidate and self._elderly_id:
                await self.sio.emit("ice_candidate", {
                    "sender_id":    self._elderly_id,
                    "recipient_id": caregiver_id,
                    "elderly_id":   self._elderly_id,
                    "candidate": {
                        "candidate":     candidate.candidate,
                        "sdpMid":        candidate.sdpMid,
                        "sdpMLineIndex": candidate.sdpMLineIndex,
                    },
                })

        @pc.on("connectionstatechange")
        async def on_state():
            state = pc.connectionState
            logger.info(f"🔗 WebRTC state: {state}")
            if state in ("failed", "closed", "disconnected"):
                self.peer_connections.pop(caregiver_id, None)
                self._pending_ice.pop(caregiver_id, None)

        offer = await pc.createOffer()
        await pc.setLocalDescription(offer)

        await self.sio.emit("webrtc_offer", {
            "sender_id":    self._elderly_id,
            "recipient_id": caregiver_id,
            "elderly_id":   self._elderly_id,
            "caregiver_id": caregiver_id,
            "offer": {
                "sdp":  pc.localDescription.sdp,
                "type": pc.localDescription.type,
            },
        })
        logger.info(f"📤 Offer sent to caregiver: {caregiver_id[:8]}…")

    @staticmethod
    async def _apply_ice(pc: RTCPeerConnection, candidate: dict):
        try:
            rtc_c               = candidate_from_sdp(candidate["candidate"])
            rtc_c.sdpMid        = candidate.get("sdpMid")
            rtc_c.sdpMLineIndex = candidate.get("sdpMLineIndex")
            await pc.addIceCandidate(rtc_c)
        except Exception as e:
            logger.debug(f"ICE apply: {e}")

    async def _close_peer(self, caregiver_id: str):
        pc = self.peer_connections.pop(caregiver_id, None)
        self._pending_ice.pop(caregiver_id, None)
        if pc:
            try:
                await pc.close()
            except Exception:
                pass

    async def _close_all_peers(self):
        for cid in list(self.peer_connections.keys()):
            await self._close_peer(cid)

    def _find_pc_awaiting_answer(self):
        for cid, pc in self.peer_connections.items():
            if pc.signalingState == "have-local-offer":
                return pc, cid
        return None, None
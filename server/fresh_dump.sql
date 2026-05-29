--
-- PostgreSQL database dump
--

\restrict dCbjtkCFq9J1HEzHByb2JTqa2T7RdgUQSXVb109laXswjGU0P6t8ynuZRtXbtcc

-- Dumped from database version 15.18
-- Dumped by pg_dump version 15.18

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cameras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cameras (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    camera_device_id text NOT NULL,
    elderly_id uuid,
    status text DEFAULT 'offline'::text,
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.cameras OWNER TO postgres;

--
-- Name: caregivers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.caregivers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firebase_uid text NOT NULL,
    email text NOT NULL,
    first_name text,
    last_name text,
    phone text,
    photo_url text,
    email_verified boolean DEFAULT false,
    fcm_token text,
    status text DEFAULT 'active'::text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.caregivers OWNER TO postgres;

--
-- Name: elder_locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.elder_locations (
    elderly_id uuid NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    address text DEFAULT ''::text,
    is_home boolean DEFAULT false,
    battery_level integer,
    updated_at timestamp without time zone DEFAULT now(),
    battery_alerted_at timestamp without time zone
);


ALTER TABLE public.elder_locations OWNER TO postgres;

--
-- Name: elder_safe_zones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.elder_safe_zones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    elderly_id uuid NOT NULL,
    caregiver_id uuid NOT NULL,
    center_lat double precision NOT NULL,
    center_lng double precision NOT NULL,
    radius_meters integer DEFAULT 200 NOT NULL,
    is_active boolean DEFAULT true,
    last_alerted_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.elder_safe_zones OWNER TO postgres;

--
-- Name: elderly; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.elderly (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    caregiver_id uuid NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    date_of_birth date,
    gender text,
    blood_type text,
    phone text,
    photo_url text,
    device_token text,
    emergency_contact_name text,
    emergency_contact_phone text,
    emergency_contact_relationship text,
    emergency_contact_email text,
    address text,
    city text,
    state text,
    postal_code text,
    country text DEFAULT 'Egypt'::text,
    medical_conditions text,
    allergies text,
    current_medications text,
    doctor_name text,
    doctor_phone text,
    hospital_preference text,
    mobility_level text,
    typical_sleep_time time without time zone,
    typical_wake_time time without time zone,
    is_connected boolean DEFAULT false,
    last_seen timestamp without time zone,
    status text DEFAULT 'active'::text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.elderly OWNER TO postgres;

--
-- Name: elderly_connections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.elderly_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    elderly_id uuid NOT NULL,
    qr_token_id uuid,
    connected_at timestamp without time zone DEFAULT now(),
    disconnected_at timestamp without time zone,
    disconnection_reason text
);


ALTER TABLE public.elderly_connections OWNER TO postgres;

--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    elderly_id uuid NOT NULL,
    event_type text NOT NULL,
    confidence double precision,
    snapshot_url text,
    pose_data jsonb,
    verified boolean DEFAULT false,
    is_false_positive boolean DEFAULT false,
    verified_by uuid,
    verified_at timestamp without time zone,
    alert_sent boolean DEFAULT false,
    alert_sent_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.events OWNER TO postgres;

--
-- Name: pill_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pill_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    schedule_id uuid,
    slot_id uuid NOT NULL,
    elderly_id uuid NOT NULL,
    scheduled_at timestamp without time zone NOT NULL,
    status text DEFAULT 'pending'::text,
    taken_at timestamp without time zone,
    notified_caregiver boolean DEFAULT false,
    notified_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT pill_logs_status_check CHECK ((status = ANY (ARRAY['taken'::text, 'missed'::text, 'pending'::text])))
);


ALTER TABLE public.pill_logs OWNER TO postgres;

--
-- Name: pill_schedules; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pill_schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slot_id uuid NOT NULL,
    elderly_id uuid NOT NULL,
    scheduled_time time without time zone NOT NULL,
    label text,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.pill_schedules OWNER TO postgres;

--
-- Name: pill_slots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pill_slots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    elderly_id uuid NOT NULL,
    slot_number integer NOT NULL,
    medication_name text DEFAULT ''::text NOT NULL,
    notes text,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT pill_slots_slot_number_check CHECK (((slot_number >= 1) AND (slot_number <= 3)))
);


ALTER TABLE public.pill_slots OWNER TO postgres;

--
-- Name: pillbox_devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pillbox_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    elderly_id uuid NOT NULL,
    device_mac text NOT NULL,
    firmware_version text,
    last_seen timestamp without time zone,
    is_online boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.pillbox_devices OWNER TO postgres;

--
-- Name: qr_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.qr_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    elderly_id uuid NOT NULL,
    token text NOT NULL,
    manual_code text,
    expires_at timestamp without time zone NOT NULL,
    is_active boolean DEFAULT true,
    used_at timestamp without time zone,
    revoked_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.qr_tokens OWNER TO postgres;

--
-- Name: sos_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sos_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    elderly_id uuid NOT NULL,
    caregiver_id uuid NOT NULL,
    status text DEFAULT 'pending'::text,
    source character varying(20) DEFAULT 'manual'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    acknowledged_at timestamp without time zone,
    escalated_at timestamp without time zone
);


ALTER TABLE public.sos_requests OWNER TO postgres;

--
-- Name: voice_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.voice_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    caregiver_id uuid NOT NULL,
    elderly_id uuid NOT NULL,
    title text NOT NULL,
    file_path text NOT NULL,
    duration_secs integer DEFAULT 0,
    used_times integer DEFAULT 0,
    is_saved boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.voice_messages OWNER TO postgres;

--
-- Data for Name: cameras; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cameras (id, camera_device_id, elderly_id, status, updated_at) FROM stdin;
\.


--
-- Data for Name: caregivers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.caregivers (id, firebase_uid, email, first_name, last_name, phone, photo_url, email_verified, fcm_token, status, created_at, updated_at) FROM stdin;
5611ddd1-f543-4883-83c7-90f33c8bb49f	F9aTK0jRkSb7u6EhlsXhdcptxEg2	sarahhh.emaddd@gmail.com_deleted_2026-05-21 08:52:12.634923+00	sarahhh.emaddd		\N	\N	t	\N	deleted	2026-05-21 08:42:26.164425	2026-05-21 08:52:12.634923
f4f689e1-3f94-48a3-95f9-49f281abd456	CFWQ4v7Hx8NIQwFpt7yE2Haxw9P2	sarahhh.emaddd@gmail.com_deleted_2026-05-21 08:56:26.589459+00	Sarah	Emad	01211799755	\N	f	\N	deleted	2026-05-21 08:54:04.812753	2026-05-21 08:56:26.589459
d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	issxETAnIWMaTySROC4zVflpYSB3	sarahhh.emaddd@gmail.com	Sarah	Emad	01211799755	\N	f	\N	active	2026-05-21 09:04:28.790341	2026-05-21 09:04:28.790341
\.


--
-- Data for Name: elder_locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.elder_locations (elderly_id, latitude, longitude, address, is_home, battery_level, updated_at, battery_alerted_at) FROM stdin;
dfb409d3-7773-42b3-a70a-53d780d7dc92	30.0444	31.2357		f	\N	2026-05-22 14:33:46.942668	\N
\.


--
-- Data for Name: elder_safe_zones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.elder_safe_zones (id, elderly_id, caregiver_id, center_lat, center_lng, radius_meters, is_active, last_alerted_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: elderly; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.elderly (id, caregiver_id, first_name, last_name, date_of_birth, gender, blood_type, phone, photo_url, device_token, emergency_contact_name, emergency_contact_phone, emergency_contact_relationship, emergency_contact_email, address, city, state, postal_code, country, medical_conditions, allergies, current_medications, doctor_name, doctor_phone, hospital_preference, mobility_level, typical_sleep_time, typical_wake_time, is_connected, last_seen, status, created_at, updated_at) FROM stdin;
18aa71ac-1765-42a0-bd0a-eb58fcf86a7a	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	Emad	Saeed	1980-01-06	male	B+	+20 1211799755	\N	\N	Sarah	01211799755	Daughter	sarahhh.emadddd@gmail.com	22 samir	Cairo	\N	\N	Egypt	Diabets	latex	500	\N	\N	\N	independent	22:00:00	07:00:00	f	\N	archived	2026-05-21 09:07:21.898819	2026-05-21 09:07:21.898819
dfb409d3-7773-42b3-a70a-53d780d7dc92	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	Emad	Saeed	1980-01-06	male	B+	+20 1211799755	\N	simulator-device-token	Sarah	01211799755	Daughter	sarahhh.emadddd@gmail.com	22 samir	Cairo	\N	\N	Egypt	Diabets	latex	500	\N	\N	\N	independent	22:00:00	07:00:00	t	2026-05-22 14:33:46.950188	active	2026-05-21 09:06:32.778718	2026-05-21 09:07:09.58751
\.


--
-- Data for Name: elderly_connections; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.elderly_connections (id, elderly_id, qr_token_id, connected_at, disconnected_at, disconnection_reason) FROM stdin;
e61e8e70-c14e-4aae-be76-82e6654150d0	dfb409d3-7773-42b3-a70a-53d780d7dc92	fe3f39a1-e179-463a-9049-a5ff02184e8d	2026-05-21 09:07:09.58751	\N	\N
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events (id, elderly_id, event_type, confidence, snapshot_url, pose_data, verified, is_false_positive, verified_by, verified_at, alert_sent, alert_sent_at, created_at, updated_at) FROM stdin;
38b20914-df64-42bc-9eb5-00c047009ea2	dfb409d3-7773-42b3-a70a-53d780d7dc92	fall	0.9	http://192.168.1.254:9000/sanad/snapshots/dfb409d3-7773-42b3-a70a-53d780d7dc92/fall_1779459339124.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin%2F20260522%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260522T141539Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=6f633a62473a9c89b73570dcdaa18f5ddbf0a995b571e8937c96da59fae0f454	{"NOSE": {"x": 226.8, "y": 338, "visibility": 1}, "LEFT_HIP": {"x": 330.5, "y": 388.1, "visibility": 0.99}, "LEFT_KNEE": {"x": 389.1, "y": 418.6, "visibility": 0.78}, "RIGHT_HIP": {"x": 294.6, "y": 418.3, "visibility": 1}, "LEFT_WRIST": {"x": 243.3, "y": 333.3, "visibility": 0.25}, "RIGHT_KNEE": {"x": 363.7, "y": 443.5, "visibility": 0.83}, "RIGHT_WRIST": {"x": 191.3, "y": 362.1, "visibility": 0.26}, "LEFT_SHOULDER": {"x": 267.2, "y": 340.8, "visibility": 1}, "RIGHT_SHOULDER": {"x": 216.3, "y": 382, "visibility": 1}}	t	f	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	2026-05-22 14:17:06.699677	f	\N	2026-05-22 14:15:39.14093	2026-05-22 14:15:39.14093
f1a38b17-d23e-4581-a1d2-8acc18d26ee5	dfb409d3-7773-42b3-a70a-53d780d7dc92	sleeping	0.8	http://192.168.1.254:9000/sanad/snapshots/dfb409d3-7773-42b3-a70a-53d780d7dc92/sleeping_1779459347152.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin%2F20260522%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260522T141547Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=04f823e72a0c610e31c6f73bd4d649a05dcdd30bee410ade23c75430e8316e88	{"NOSE": {"x": 227.5, "y": 336.2, "visibility": 0.99}, "LEFT_HIP": {"x": 328, "y": 386.5, "visibility": 0.99}, "LEFT_KNEE": {"x": 389.4, "y": 424.3, "visibility": 0.68}, "RIGHT_HIP": {"x": 296.6, "y": 417.2, "visibility": 1}, "LEFT_WRIST": {"x": 240.5, "y": 331, "visibility": 0.18}, "RIGHT_KNEE": {"x": 363.6, "y": 446.8, "visibility": 0.72}, "RIGHT_WRIST": {"x": 190.8, "y": 361.6, "visibility": 0.17}, "LEFT_SHOULDER": {"x": 264.2, "y": 338.9, "visibility": 1}, "RIGHT_SHOULDER": {"x": 216.9, "y": 380, "visibility": 1}}	t	f	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	2026-05-22 14:17:08.947013	f	\N	2026-05-22 14:15:47.162222	2026-05-22 14:15:47.162222
\.


--
-- Data for Name: pill_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pill_logs (id, schedule_id, slot_id, elderly_id, scheduled_at, status, taken_at, notified_caregiver, notified_at, created_at) FROM stdin;
\.


--
-- Data for Name: pill_schedules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pill_schedules (id, slot_id, elderly_id, scheduled_time, label, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: pill_slots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pill_slots (id, elderly_id, slot_number, medication_name, notes, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: pillbox_devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pillbox_devices (id, elderly_id, device_mac, firmware_version, last_seen, is_online, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: qr_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.qr_tokens (id, elderly_id, token, manual_code, expires_at, is_active, used_at, revoked_at, created_at) FROM stdin;
fe3f39a1-e179-463a-9049-a5ff02184e8d	dfb409d3-7773-42b3-a70a-53d780d7dc92	9a31dc501e7086418ce1a71bef0bb5af844212e50b13487cd299d80574bd97f7	629903	2026-05-21 09:11:32.785	f	2026-05-21 09:07:09.58751	\N	2026-05-21 09:06:32.784637
6f05e81a-4431-4223-a57e-919bd67ebe4d	18aa71ac-1765-42a0-bd0a-eb58fcf86a7a	c68fe0fc15f83b74ce1e39f1781fed93bcb85e8ddaf8d418b76c39d3a16a24b2	235894	2026-05-21 09:12:21.913	f	\N	2026-05-21 10:00:00.068738	2026-05-21 09:07:21.91235
\.


--
-- Data for Name: sos_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sos_requests (id, elderly_id, caregiver_id, status, source, created_at, acknowledged_at, escalated_at) FROM stdin;
278d1655-7bf7-4c62-9be7-2107badfba81	dfb409d3-7773-42b3-a70a-53d780d7dc92	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	pending	manual	2026-05-21 09:07:43.326776	\N	2026-05-21 10:02:00.052034
\.


--
-- Data for Name: voice_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.voice_messages (id, caregiver_id, elderly_id, title, file_path, duration_secs, used_times, is_saved, created_at) FROM stdin;
86383ab8-7933-4923-a834-25824ed83851	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	dfb409d3-7773-42b3-a70a-53d780d7dc92	Quick message – 12:38 PM	http://192.168.1.254:9000/sanad/voice/d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7/1779356339586.aac?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin%2F20260521%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260521T093859Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=206a04f819d92d578b425200604611a3d77e2a6ba3865a5021700f69a0afd4f9	3	1	t	2026-05-21 09:38:59.608013
bcee009f-e929-47d0-a2ec-4b1e1e3876ee	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	dfb409d3-7773-42b3-a70a-53d780d7dc92	hi	http://192.168.1.254:9000/sanad/voice/d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7/1779356361815.aac?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin%2F20260521%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260521T093921Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=13cfb10bdb193757f90479fc35cfadb4d82ca4eca94b6ebd84b950394315ed0c	2	2	t	2026-05-21 09:39:21.824776
15cec913-7ffa-4b43-a712-cec7811cd142	d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7	dfb409d3-7773-42b3-a70a-53d780d7dc92	mead	http://192.168.1.254:9000/sanad/voice/d8c09c8e-8c8d-46ba-8404-08ddcd45d6e7/1779459277975.aac?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin%2F20260522%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260522T141437Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=8373a6d7832d9cb1cf74e4238b21eabf4347092eab2294ae1b5428483430e9f1	1	2	t	2026-05-22 14:14:38.01071
\.


--
-- Name: cameras cameras_camera_device_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cameras
    ADD CONSTRAINT cameras_camera_device_id_key UNIQUE (camera_device_id);


--
-- Name: cameras cameras_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cameras
    ADD CONSTRAINT cameras_pkey PRIMARY KEY (id);


--
-- Name: caregivers caregivers_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caregivers
    ADD CONSTRAINT caregivers_email_key UNIQUE (email);


--
-- Name: caregivers caregivers_firebase_uid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caregivers
    ADD CONSTRAINT caregivers_firebase_uid_key UNIQUE (firebase_uid);


--
-- Name: caregivers caregivers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caregivers
    ADD CONSTRAINT caregivers_pkey PRIMARY KEY (id);


--
-- Name: elder_locations elder_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elder_locations
    ADD CONSTRAINT elder_locations_pkey PRIMARY KEY (elderly_id);


--
-- Name: elder_safe_zones elder_safe_zones_elderly_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elder_safe_zones
    ADD CONSTRAINT elder_safe_zones_elderly_id_key UNIQUE (elderly_id);


--
-- Name: elder_safe_zones elder_safe_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elder_safe_zones
    ADD CONSTRAINT elder_safe_zones_pkey PRIMARY KEY (id);


--
-- Name: elderly_connections elderly_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elderly_connections
    ADD CONSTRAINT elderly_connections_pkey PRIMARY KEY (id);


--
-- Name: elderly elderly_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elderly
    ADD CONSTRAINT elderly_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: pill_logs pill_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_logs
    ADD CONSTRAINT pill_logs_pkey PRIMARY KEY (id);


--
-- Name: pill_schedules pill_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_schedules
    ADD CONSTRAINT pill_schedules_pkey PRIMARY KEY (id);


--
-- Name: pill_slots pill_slots_elderly_id_slot_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_slots
    ADD CONSTRAINT pill_slots_elderly_id_slot_number_key UNIQUE (elderly_id, slot_number);


--
-- Name: pill_slots pill_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_slots
    ADD CONSTRAINT pill_slots_pkey PRIMARY KEY (id);


--
-- Name: pillbox_devices pillbox_devices_device_mac_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pillbox_devices
    ADD CONSTRAINT pillbox_devices_device_mac_key UNIQUE (device_mac);


--
-- Name: pillbox_devices pillbox_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pillbox_devices
    ADD CONSTRAINT pillbox_devices_pkey PRIMARY KEY (id);


--
-- Name: qr_tokens qr_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_tokens
    ADD CONSTRAINT qr_tokens_pkey PRIMARY KEY (id);


--
-- Name: qr_tokens qr_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_tokens
    ADD CONSTRAINT qr_tokens_token_key UNIQUE (token);


--
-- Name: sos_requests sos_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sos_requests
    ADD CONSTRAINT sos_requests_pkey PRIMARY KEY (id);


--
-- Name: voice_messages voice_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voice_messages
    ADD CONSTRAINT voice_messages_pkey PRIMARY KEY (id);


--
-- Name: cameras cameras_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cameras
    ADD CONSTRAINT cameras_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE SET NULL;


--
-- Name: elder_locations elder_locations_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elder_locations
    ADD CONSTRAINT elder_locations_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: elder_safe_zones elder_safe_zones_caregiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elder_safe_zones
    ADD CONSTRAINT elder_safe_zones_caregiver_id_fkey FOREIGN KEY (caregiver_id) REFERENCES public.caregivers(id) ON DELETE CASCADE;


--
-- Name: elder_safe_zones elder_safe_zones_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elder_safe_zones
    ADD CONSTRAINT elder_safe_zones_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: elderly elderly_caregiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elderly
    ADD CONSTRAINT elderly_caregiver_id_fkey FOREIGN KEY (caregiver_id) REFERENCES public.caregivers(id) ON DELETE CASCADE;


--
-- Name: elderly_connections elderly_connections_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elderly_connections
    ADD CONSTRAINT elderly_connections_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: elderly_connections elderly_connections_qr_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elderly_connections
    ADD CONSTRAINT elderly_connections_qr_token_id_fkey FOREIGN KEY (qr_token_id) REFERENCES public.qr_tokens(id);


--
-- Name: events events_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: events events_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.caregivers(id);


--
-- Name: pill_logs pill_logs_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_logs
    ADD CONSTRAINT pill_logs_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: pill_logs pill_logs_schedule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_logs
    ADD CONSTRAINT pill_logs_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES public.pill_schedules(id) ON DELETE SET NULL;


--
-- Name: pill_logs pill_logs_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_logs
    ADD CONSTRAINT pill_logs_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.pill_slots(id) ON DELETE CASCADE;


--
-- Name: pill_schedules pill_schedules_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_schedules
    ADD CONSTRAINT pill_schedules_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: pill_schedules pill_schedules_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_schedules
    ADD CONSTRAINT pill_schedules_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.pill_slots(id) ON DELETE CASCADE;


--
-- Name: pill_slots pill_slots_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pill_slots
    ADD CONSTRAINT pill_slots_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: pillbox_devices pillbox_devices_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pillbox_devices
    ADD CONSTRAINT pillbox_devices_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: qr_tokens qr_tokens_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_tokens
    ADD CONSTRAINT qr_tokens_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: sos_requests sos_requests_caregiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sos_requests
    ADD CONSTRAINT sos_requests_caregiver_id_fkey FOREIGN KEY (caregiver_id) REFERENCES public.caregivers(id) ON DELETE CASCADE;


--
-- Name: sos_requests sos_requests_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sos_requests
    ADD CONSTRAINT sos_requests_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- Name: voice_messages voice_messages_caregiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voice_messages
    ADD CONSTRAINT voice_messages_caregiver_id_fkey FOREIGN KEY (caregiver_id) REFERENCES public.caregivers(id) ON DELETE CASCADE;


--
-- Name: voice_messages voice_messages_elderly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voice_messages
    ADD CONSTRAINT voice_messages_elderly_id_fkey FOREIGN KEY (elderly_id) REFERENCES public.elderly(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict dCbjtkCFq9J1HEzHByb2JTqa2T7RdgUQSXVb109laXswjGU0P6t8ynuZRtXbtcc


"""
SANAD — Professional ERD Generator
Produces a publication-quality PNG suitable for graduation documentation.
Run:    python3 generate_erd.py
Output: ERD_SANAD.png
"""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.patheffects as pe

# ── Design tokens ─────────────────────────────────────────────────────────────
HDR_CORE   = '#1B4F72'   # deep navy  — core entities
HDR_WEAK   = '#1A6B3A'   # deep green — junction / weak entities
ATTR_EVEN  = '#EBF5FB'   # light blue row
ATTR_ODD   = '#FDFEFE'   # near-white row
PK_CLR     = '#C0392B'   # red badge
FK_CLR     = '#2471A3'   # blue badge
UK_CLR     = '#7D3C98'   # purple badge
BORDER_CLR = '#2C3E50'
LINE_CLR   = '#5D6D7E'
BG_CLR     = '#F0F3F4'
TITLE_CLR  = '#1B2631'

ROW_H = 0.30   # attribute row height
HDR_H = 0.44   # table header height
COL_W = 3.50   # fixed table width

# ─────────────────────────────────────────────────────────────────────────────
# Table definitions
# Each entry: (name, header_color, col_index, top_y, [ (col, type, flag) ])
# flag: 'PK' | 'FK' | 'UK' | 'PK,FK' | 'FK,UK' | ''
# Layout is 3 columns; col_index ∈ {0,1,2}
# ─────────────────────────────────────────────────────────────────────────────
TABLES = [

    # ── Column 0 (leftmost) ──────────────────────────────────────────────────
    ('caregivers', HDR_CORE, 0, 14.60, [
        ('id',             'UUID',      'PK'),
        ('firebase_uid',   'TEXT',      'UK'),
        ('email',          'TEXT',      'UK'),
        ('first_name',     'TEXT',      ''),
        ('last_name',      'TEXT',      ''),
        ('phone',          'TEXT',      ''),
        ('photo_url',      'TEXT',      ''),
        ('email_verified', 'BOOLEAN',   ''),
        ('fcm_token',      'TEXT',      ''),
        ('status',         'TEXT',      ''),
        ('created_at',     'TIMESTAMP', ''),
        ('updated_at',     'TIMESTAMP', ''),
    ]),

    ('qr_tokens', HDR_CORE, 0, 10.20, [
        ('id',          'UUID',      'PK'),
        ('elderly_id',  'UUID',      'FK'),
        ('token',       'TEXT',      'UK'),
        ('manual_code', 'TEXT',      ''),
        ('expires_at',  'TIMESTAMP', ''),
        ('is_active',   'BOOLEAN',   ''),
        ('used_at',     'TIMESTAMP', ''),
        ('revoked_at',  'TIMESTAMP', ''),
        ('created_at',  'TIMESTAMP', ''),
    ]),

    ('elderly_connections', HDR_WEAK, 0, 6.65, [
        ('id',                  'UUID',      'PK'),
        ('elderly_id',          'UUID',      'FK'),
        ('qr_token_id',         'UUID',      'FK'),
        ('connected_at',        'TIMESTAMP', ''),
        ('disconnected_at',     'TIMESTAMP', ''),
        ('disconnection_reason','TEXT',      ''),
    ]),

    ('elder_safe_zones', HDR_CORE, 0, 3.90, [
        ('id',              'UUID',    'PK'),
        ('elderly_id',      'UUID',    'FK,UK'),
        ('caregiver_id',    'UUID',    'FK'),
        ('center_lat',      'DOUBLE',  ''),
        ('center_lng',      'DOUBLE',  ''),
        ('radius_meters',   'INTEGER', ''),
        ('is_active',       'BOOLEAN', ''),
        ('last_alerted_at', 'TIMESTAMP',''),
        ('created_at',      'TIMESTAMP',''),
        ('updated_at',      'TIMESTAMP',''),
    ]),

    # ── Column 1 (center) ────────────────────────────────────────────────────
    ('elderly', HDR_CORE, 1, 14.60, [
        ('id',                             'UUID',      'PK'),
        ('caregiver_id',                   'UUID',      'FK'),
        ('first_name',                     'TEXT',      ''),
        ('last_name',                      'TEXT',      ''),
        ('date_of_birth',                  'DATE',      ''),
        ('gender',                         'TEXT',      ''),
        ('blood_type',                     'TEXT',      ''),
        ('phone',                          'TEXT',      ''),
        ('emergency_contact_name',         'TEXT',      ''),
        ('emergency_contact_phone',        'TEXT',      ''),
        ('emergency_contact_relationship', 'TEXT',      ''),
        ('medical_conditions',             'TEXT',      ''),
        ('allergies',                      'TEXT',      ''),
        ('current_medications',            'TEXT',      ''),
        ('doctor_name',                    'TEXT',      ''),
        ('mobility_level',                 'TEXT',      ''),
        ('typical_sleep_time',             'TIME',      ''),
        ('typical_wake_time',              'TIME',      ''),
        ('is_connected',                   'BOOLEAN',   ''),
        ('last_seen',                      'TIMESTAMP', ''),
        ('status',                         'TEXT',      ''),
        ('created_at',                     'TIMESTAMP', ''),
        ('updated_at',                     'TIMESTAMP', ''),
    ]),

    ('sos_requests', HDR_CORE, 1, 7.20, [
        ('id',              'UUID',      'PK'),
        ('elderly_id',      'UUID',      'FK'),
        ('caregiver_id',    'UUID',      'FK'),
        ('status',          'TEXT',      ''),
        ('source',          'VARCHAR',   ''),
        ('created_at',      'TIMESTAMP', ''),
        ('acknowledged_at', 'TIMESTAMP', ''),
        ('escalated_at',    'TIMESTAMP', ''),
    ]),

    ('voice_messages', HDR_WEAK, 1, 4.30, [
        ('id',            'UUID',      'PK'),
        ('caregiver_id',  'UUID',      'FK'),
        ('elderly_id',    'UUID',      'FK'),
        ('title',         'TEXT',      ''),
        ('file_path',     'TEXT',      ''),
        ('duration_secs', 'INTEGER',   ''),
        ('used_times',    'INTEGER',   ''),
        ('is_saved',      'BOOLEAN',   ''),
        ('created_at',    'TIMESTAMP', ''),
    ]),

    # ── Column 2 (rightmost) ─────────────────────────────────────────────────
    ('events', HDR_CORE, 2, 14.60, [
        ('id',                'UUID',    'PK'),
        ('elderly_id',        'UUID',    'FK'),
        ('event_type',        'TEXT',    ''),
        ('confidence',        'DOUBLE',  ''),
        ('snapshot_url',      'TEXT',    ''),
        ('pose_data',         'JSONB',   ''),
        ('verified',          'BOOLEAN', ''),
        ('is_false_positive', 'BOOLEAN', ''),
        ('verified_by',       'UUID',    'FK'),
        ('alert_sent',        'BOOLEAN', ''),
        ('alert_sent_at',     'TIMESTAMP',''),
        ('created_at',        'TIMESTAMP',''),
        ('updated_at',        'TIMESTAMP',''),
    ]),

    ('cameras', HDR_WEAK, 2, 9.80, [
        ('id',               'UUID',      'PK'),
        ('camera_device_id', 'TEXT',      'UK'),
        ('elderly_id',       'UUID',      'FK'),
        ('status',           'TEXT',      ''),
        ('updated_at',       'TIMESTAMP', ''),
    ]),

    ('elder_locations', HDR_CORE, 2, 7.45, [
        ('elderly_id',         'UUID',      'PK,FK'),
        ('latitude',           'DOUBLE',    ''),
        ('longitude',          'DOUBLE',    ''),
        ('address',            'TEXT',      ''),
        ('is_home',            'BOOLEAN',   ''),
        ('battery_level',      'INTEGER',   ''),
        ('battery_alerted_at', 'TIMESTAMP', ''),
        ('updated_at',         'TIMESTAMP', ''),
    ]),
]

# ── Column x-offsets ──────────────────────────────────────────────────────────
COL_X = [0.60, 4.65, 8.70]
GAP   = 0.60   # horizontal gap between columns

# ─────────────────────────────────────────────────────────────────────────────
# Relationship definitions
# (from_table, to_table, label, cardinality)
# ─────────────────────────────────────────────────────────────────────────────
RELATIONS = [
    # elderly → caregivers
    ('elderly',             'caregivers',      'caregiver_id',  'N:1'),
    # qr_tokens → elderly
    ('qr_tokens',           'elderly',         'elderly_id',    'N:1'),
    # elderly_connections → elderly
    ('elderly_connections', 'elderly',         'elderly_id',    'N:1'),
    # elderly_connections → qr_tokens
    ('elderly_connections', 'qr_tokens',       'qr_token_id',   'N:1'),
    # sos_requests → elderly
    ('sos_requests',        'elderly',         'elderly_id',    'N:1'),
    # sos_requests → caregivers
    ('sos_requests',        'caregivers',      'caregiver_id',  'N:1'),
    # events → elderly
    ('events',              'elderly',         'elderly_id',    'N:1'),
    # events → caregivers (verified_by)
    ('events',              'caregivers',      'verified_by',   'N:1'),
    # cameras → elderly
    ('cameras',             'elderly',         'elderly_id',    'N:1'),
    # elder_locations → elderly
    ('elder_locations',     'elderly',         'elderly_id',    '1:1'),
    # voice_messages → elderly
    ('voice_messages',      'elderly',         'elderly_id',    'N:1'),
    # voice_messages → caregivers
    ('voice_messages',      'caregivers',      'caregiver_id',  'N:1'),
    # elder_safe_zones → elderly
    ('elder_safe_zones',    'elderly',         'elderly_id',    '1:1'),
    # elder_safe_zones → caregivers
    ('elder_safe_zones',    'caregivers',      'caregiver_id',  'N:1'),
]


def tbl_height(attrs):
    return HDR_H + len(attrs) * ROW_H


def tbl_x(col_idx):
    return COL_X[col_idx]


def draw_table(ax, name, hdr_color, col_idx, top_y, attrs):
    x = tbl_x(col_idx)
    w = COL_W
    h = tbl_height(attrs)

    # ── Drop shadow ──────────────────────────────────────────────
    sx, sy = x + 0.045, top_y - h - 0.045
    ax.add_patch(mpatches.FancyBboxPatch(
        (sx, sy), w, h,
        boxstyle='round,pad=0.06', linewidth=0,
        facecolor='#AABBCC', alpha=0.30, zorder=1))

    # ── White card ───────────────────────────────────────────────
    ax.add_patch(mpatches.FancyBboxPatch(
        (x, top_y - h), w, h,
        boxstyle='round,pad=0.06', linewidth=1.1,
        edgecolor=BORDER_CLR, facecolor='white', zorder=2))

    # ── Header ───────────────────────────────────────────────────
    ax.add_patch(mpatches.FancyBboxPatch(
        (x, top_y - HDR_H), w, HDR_H,
        boxstyle='round,pad=0.06', linewidth=0,
        facecolor=hdr_color, zorder=3))

    ax.text(x + w / 2, top_y - HDR_H / 2, name,
            ha='center', va='center', zorder=4,
            fontsize=7.8, fontweight='bold',
            color='white', fontfamily='monospace')

    # ── Attribute rows ────────────────────────────────────────────
    for i, (col, dtype, flag) in enumerate(attrs):
        ry_top = top_y - HDR_H - i * ROW_H
        ry_bot = ry_top - ROW_H
        mid_y  = ry_bot + ROW_H / 2

        # Alternating row background
        ax.add_patch(mpatches.Rectangle(
            (x, ry_bot), w, ROW_H,
            linewidth=0, facecolor=ATTR_EVEN if i % 2 == 0 else ATTR_ODD, zorder=2))

        # Row separator
        ax.plot([x, x + w], [ry_bot, ry_bot],
                color='#D5D8DC', linewidth=0.35, zorder=3)

        # ── Badges ───────────────────────────────────────────────
        bx = x + 0.09
        badges = [f.strip() for f in flag.split(',') if f.strip()]
        badge_colors = {'PK': PK_CLR, 'FK': FK_CLR, 'UK': UK_CLR}
        offset = 0.0
        for b in badges:
            clr = badge_colors.get(b, '#666')
            ax.text(bx + offset, mid_y, b,
                    fontsize=4.2, va='center', zorder=5,
                    color='white', fontweight='bold',
                    bbox=dict(boxstyle='round,pad=0.18',
                              fc=clr, ec='none'))
            offset += 0.38

        col_x = bx + offset + (0.06 if badges else 0)

        # Column name
        ax.text(col_x, mid_y, col,
                fontsize=6.0, va='center', zorder=4,
                fontweight='bold' if 'PK' in badges else 'normal',
                color='#1A1A1A', fontfamily='monospace')

        # Data type (right-aligned, grey italic)
        ax.text(x + w - 0.10, mid_y, dtype,
                fontsize=5.3, va='center', ha='right', zorder=4,
                color='#717D7E', style='italic')

    return dict(x=x, top_y=top_y, w=w, h=h)


# ─────────────────────────────────────────────────────────────────────────────
# Anchor helpers
# ─────────────────────────────────────────────────────────────────────────────
def _side_anchor(info, side):
    x, top, w, h = info['x'], info['top_y'], info['w'], info['h']
    cx = x + w / 2
    cy = top - h / 2
    if side == 'left':   return x,      cy
    if side == 'right':  return x + w,  cy
    if side == 'top':    return cx,      top
    if side == 'bottom': return cx,      top - h
    return cx, cy


def _best_sides(i1, i2):
    """Pick connector sides by comparing table centres."""
    c1x = i1['x'] + i1['w'] / 2
    c2x = i2['x'] + i2['w'] / 2
    c1y = i1['top_y'] - i1['h'] / 2
    c2y = i2['top_y'] - i2['h'] / 2

    dx, dy = c2x - c1x, c2y - c1y

    if abs(dx) >= abs(dy):          # mainly horizontal
        return ('right', 'left') if dx > 0 else ('left', 'right')
    else:                            # mainly vertical
        return ('bottom', 'top') if dy < 0 else ('top', 'bottom')


def draw_relation(ax, i1, i2, label, card):
    s1, s2 = _best_sides(i1, i2)
    x1, y1 = _side_anchor(i1, s1)
    x2, y2 = _side_anchor(i2, s2)

    # Connector
    ax.annotate('',
        xy=(x2, y2), xytext=(x1, y1),
        zorder=6,
        arrowprops=dict(
            arrowstyle='-|>',
            color=LINE_CLR, lw=0.85,
            mutation_scale=9,
            connectionstyle='arc3,rad=0.06'))

    # Label
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    ax.text(mx, my, f'{label}\n({card})',
            ha='center', va='center', fontsize=4.5,
            color='#2C3E50', zorder=7, linespacing=1.3,
            bbox=dict(boxstyle='round,pad=0.22', fc='white',
                      ec='#AEB6BF', linewidth=0.5, alpha=0.92))


# ─────────────────────────────────────────────────────────────────────────────
# Figure setup
# ─────────────────────────────────────────────────────────────────────────────
FIG_W, FIG_H = 14.5, 19.0

fig, ax = plt.subplots(figsize=(FIG_W, FIG_H), dpi=220)
fig.patch.set_facecolor(BG_CLR)
ax.set_facecolor(BG_CLR)
ax.set_xlim(-0.20, 12.50)
ax.set_ylim(-1.80, 16.80)
ax.axis('off')

# ── Decorative background grid ────────────────────────────────────────────────
for gy in [i * 1.0 for i in range(-1, 17)]:
    ax.axhline(gy, color='white', linewidth=0.5, alpha=0.6, zorder=0)

# ── Page border ───────────────────────────────────────────────────────────────
ax.add_patch(mpatches.FancyBboxPatch(
    (-0.15, -1.70), 12.60, 18.40,
    boxstyle='round,pad=0.10', linewidth=2.0,
    edgecolor='#2C3E50', facecolor='none', zorder=10))

# ── Title block ───────────────────────────────────────────────────────────────
ax.add_patch(mpatches.FancyBboxPatch(
    (-0.05, 15.20), 12.40, 1.40,
    boxstyle='round,pad=0.08', linewidth=0,
    facecolor=HDR_CORE, zorder=8))

ax.text(6.15, 16.15,
        'SANAD — Smart Elderly Care System',
        ha='center', va='center', fontsize=16,
        fontweight='bold', color='white', zorder=9)

ax.text(6.15, 15.60,
        'Entity Relationship Diagram (ERD)  ·  PostgreSQL Database Schema',
        ha='center', va='center', fontsize=9,
        color='#AED6F1', zorder=9)

# ── Column headers ────────────────────────────────────────────────────────────
col_labels = ['Caregiver Module', 'Elderly Core', 'Monitoring Module']
for ci, lbl in enumerate(col_labels):
    cx = COL_X[ci] + COL_W / 2
    ax.text(cx, 15.00, lbl,
            ha='center', va='center', fontsize=7.5,
            fontweight='bold', color='#2C3E50',
            bbox=dict(boxstyle='round,pad=0.25',
                      fc='white', ec='#AEB6BF', linewidth=0.6))

# ── Draw tables ───────────────────────────────────────────────────────────────
table_info = {}
for (name, color, col, top_y, attrs) in TABLES:
    table_info[name] = draw_table(ax, name, color, col, top_y, attrs)

# ── Draw relationships ─────────────────────────────────────────────────────────
for (t1, t2, label, card) in RELATIONS:
    draw_relation(ax, table_info[t1], table_info[t2], label, card)

# ── Legend ────────────────────────────────────────────────────────────────────
leg_y = -0.80
ax.add_patch(mpatches.FancyBboxPatch(
    (-0.10, leg_y - 0.44), 12.45, 0.96,
    boxstyle='round,pad=0.08', linewidth=0.8,
    edgecolor='#AEB6BF', facecolor='white', alpha=0.95, zorder=8))

ax.text(0.10, leg_y + 0.30,
        'Legend', fontsize=7.5, fontweight='bold',
        color=TITLE_CLR, va='center', zorder=9)

badges_leg = [
    (PK_CLR, 'PK — Primary Key'),
    (FK_CLR, 'FK — Foreign Key'),
    (UK_CLR, 'UK — Unique Key'),
]
hdr_leg = [
    (HDR_CORE, 'Core Entity'),
    (HDR_WEAK, 'Junction / Weak Entity'),
]

bx0 = 1.00
for i, (clr, txt) in enumerate(badges_leg):
    bx = bx0 + i * 2.20
    ax.add_patch(mpatches.Rectangle(
        (bx, leg_y + 0.16), 0.26, 0.20,
        facecolor=clr, linewidth=0, zorder=9))
    ax.text(bx + 0.32, leg_y + 0.26, txt,
            fontsize=6.0, va='center', color='#2C3E50', zorder=9)

bx0 = 7.80
for i, (clr, txt) in enumerate(hdr_leg):
    bx = bx0 + i * 2.40
    ax.add_patch(mpatches.Rectangle(
        (bx, leg_y + 0.16), 0.26, 0.20,
        facecolor=clr, linewidth=0, zorder=9))
    ax.text(bx + 0.32, leg_y + 0.26, txt,
            fontsize=6.0, va='center', color='#2C3E50', zorder=9)

# Arrow sample
ax.annotate('', xy=(1.40, leg_y - 0.18), xytext=(1.00, leg_y - 0.18),
            zorder=9,
            arrowprops=dict(arrowstyle='-|>', color=LINE_CLR,
                            lw=1.0, mutation_scale=8))
ax.text(1.46, leg_y - 0.18, '→ References (FK)',
        fontsize=6.0, va='center', color='#2C3E50', zorder=9)

ax.text(3.60, leg_y - 0.18, 'Cardinality shown on connector labels  (1:1 = one-to-one · N:1 = many-to-one)',
        fontsize=5.8, va='center', color='#717D7E', zorder=9)

# ── Footer ────────────────────────────────────────────────────────────────────
ax.text(6.15, -1.50,
        'SANAD  |  Smart Elderly Care System  |  Database ERD  |  '
        'Computer Science Graduation Project  |  2025–2026',
        ha='center', va='center', fontsize=5.8,
        color='#7F8C8D', style='italic', zorder=9)

plt.tight_layout(pad=0.1)
out = 'ERD_SANAD.png'
plt.savefig(out, dpi=220, bbox_inches='tight',
            facecolor=BG_CLR, edgecolor='none')
plt.close()
print(f'✅  Saved → {out}')

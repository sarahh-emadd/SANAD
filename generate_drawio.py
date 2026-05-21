"""
SANAD — Draw.io ERD Generator
Produces ERD_SANAD.drawio that can be opened/edited directly in draw.io or diagrams.net
"""

import xml.etree.ElementTree as ET
from xml.dom import minidom

# ── Styling constants ──────────────────────────────────────────────────────────
HDR_CORE  = '#1B4F72'   # dark blue  — core entity header
HDR_WEAK  = '#1A6B3A'   # dark green — junction / weak entity header
HDR_FONT  = '#FFFFFF'
ROW_PK    = '#FDECEA'   # light red  — PK row
ROW_FK    = '#EBF5FB'   # light blue — FK row
ROW_UK    = '#F5EEF8'   # light purple — UK row
ROW_EVEN  = '#F2F3F4'   # light grey — even normal row
ROW_ODD   = '#FFFFFF'   # white      — odd normal row
FONT      = 'Helvetica'

ROW_H     = 28          # px — attribute row height
HDR_H     = 34          # px — table header height
TBL_W     = 300         # px — table width

# ── Table definitions ──────────────────────────────────────────────────────────
# (table_name, header_color, x, y,  [(col_name, data_type, flag)])
# flag: 'PK' | 'FK' | 'UK' | 'PK,FK' | 'FK,UK' | ''

TABLES = [

    # ── Column 0  ─────────────────────────────────────────────────────────────
    ('caregivers', HDR_CORE, 40, 40, [
        ('id',              'UUID',      'PK'),
        ('firebase_uid',    'TEXT',      'UK'),
        ('email',           'TEXT',      'UK'),
        ('first_name',      'TEXT',      ''),
        ('last_name',       'TEXT',      ''),
        ('phone',           'TEXT',      ''),
        ('photo_url',       'TEXT',      ''),
        ('email_verified',  'BOOLEAN',   ''),
        ('fcm_token',       'TEXT',      ''),
        ('status',          'TEXT',      ''),
        ('created_at',      'TIMESTAMP', ''),
        ('updated_at',      'TIMESTAMP', ''),
    ]),

    ('qr_tokens', HDR_CORE, 40, 0, [     # y set dynamically below
        ('id',              'UUID',      'PK'),
        ('elderly_id',      'UUID',      'FK'),
        ('token',           'TEXT',      'UK'),
        ('manual_code',     'TEXT',      ''),
        ('expires_at',      'TIMESTAMP', ''),
        ('is_active',       'BOOLEAN',   ''),
        ('used_at',         'TIMESTAMP', ''),
        ('revoked_at',      'TIMESTAMP', ''),
        ('created_at',      'TIMESTAMP', ''),
    ]),

    ('elderly_connections', HDR_WEAK, 40, 0, [
        ('id',                   'UUID',      'PK'),
        ('elderly_id',           'UUID',      'FK'),
        ('qr_token_id',          'UUID',      'FK'),
        ('connected_at',         'TIMESTAMP', ''),
        ('disconnected_at',      'TIMESTAMP', ''),
        ('disconnection_reason', 'TEXT',      ''),
    ]),

    ('elder_safe_zones', HDR_CORE, 40, 0, [
        ('id',               'UUID',      'PK'),
        ('elderly_id',       'UUID',      'FK,UK'),
        ('caregiver_id',     'UUID',      'FK'),
        ('center_lat',       'DOUBLE',    ''),
        ('center_lng',       'DOUBLE',    ''),
        ('radius_meters',    'INTEGER',   ''),
        ('is_active',        'BOOLEAN',   ''),
        ('last_alerted_at',  'TIMESTAMP', ''),
        ('created_at',       'TIMESTAMP', ''),
        ('updated_at',       'TIMESTAMP', ''),
    ]),

    # ── Column 1  ─────────────────────────────────────────────────────────────
    ('elderly', HDR_CORE, 420, 40, [
        ('id',                              'UUID',      'PK'),
        ('caregiver_id',                    'UUID',      'FK'),
        ('first_name',                      'TEXT',      ''),
        ('last_name',                       'TEXT',      ''),
        ('date_of_birth',                   'DATE',      ''),
        ('gender',                          'TEXT',      ''),
        ('blood_type',                      'TEXT',      ''),
        ('phone',                           'TEXT',      ''),
        ('emergency_contact_name',          'TEXT',      ''),
        ('emergency_contact_phone',         'TEXT',      ''),
        ('emergency_contact_relationship',  'TEXT',      ''),
        ('medical_conditions',              'TEXT',      ''),
        ('allergies',                       'TEXT',      ''),
        ('current_medications',             'TEXT',      ''),
        ('doctor_name',                     'TEXT',      ''),
        ('mobility_level',                  'TEXT',      ''),
        ('typical_sleep_time',              'TIME',      ''),
        ('typical_wake_time',               'TIME',      ''),
        ('is_connected',                    'BOOLEAN',   ''),
        ('last_seen',                       'TIMESTAMP', ''),
        ('status',                          'TEXT',      ''),
        ('created_at',                      'TIMESTAMP', ''),
        ('updated_at',                      'TIMESTAMP', ''),
    ]),

    ('sos_requests', HDR_CORE, 420, 0, [
        ('id',               'UUID',      'PK'),
        ('elderly_id',       'UUID',      'FK'),
        ('caregiver_id',     'UUID',      'FK'),
        ('status',           'TEXT',      ''),
        ('source',           'VARCHAR',   ''),
        ('created_at',       'TIMESTAMP', ''),
        ('acknowledged_at',  'TIMESTAMP', ''),
        ('escalated_at',     'TIMESTAMP', ''),
    ]),

    ('voice_messages', HDR_WEAK, 420, 0, [
        ('id',              'UUID',      'PK'),
        ('caregiver_id',    'UUID',      'FK'),
        ('elderly_id',      'UUID',      'FK'),
        ('title',           'TEXT',      ''),
        ('file_path',       'TEXT',      ''),
        ('duration_secs',   'INTEGER',   ''),
        ('used_times',      'INTEGER',   ''),
        ('is_saved',        'BOOLEAN',   ''),
        ('created_at',      'TIMESTAMP', ''),
    ]),

    # ── Column 2  ─────────────────────────────────────────────────────────────
    ('events', HDR_CORE, 800, 40, [
        ('id',                'UUID',      'PK'),
        ('elderly_id',        'UUID',      'FK'),
        ('event_type',        'TEXT',      ''),
        ('confidence',        'DOUBLE',    ''),
        ('snapshot_url',      'TEXT',      ''),
        ('pose_data',         'JSONB',     ''),
        ('verified',          'BOOLEAN',   ''),
        ('is_false_positive', 'BOOLEAN',   ''),
        ('verified_by',       'UUID',      'FK'),
        ('alert_sent',        'BOOLEAN',   ''),
        ('alert_sent_at',     'TIMESTAMP', ''),
        ('created_at',        'TIMESTAMP', ''),
        ('updated_at',        'TIMESTAMP', ''),
    ]),

    ('cameras', HDR_WEAK, 800, 0, [
        ('id',                'UUID',      'PK'),
        ('camera_device_id',  'TEXT',      'UK'),
        ('elderly_id',        'UUID',      'FK'),
        ('status',            'TEXT',      ''),
        ('updated_at',        'TIMESTAMP', ''),
    ]),

    ('elder_locations', HDR_CORE, 800, 0, [
        ('elderly_id',          'UUID',      'PK,FK'),
        ('latitude',            'DOUBLE',    ''),
        ('longitude',           'DOUBLE',    ''),
        ('address',             'TEXT',      ''),
        ('is_home',             'BOOLEAN',   ''),
        ('battery_level',       'INTEGER',   ''),
        ('battery_alerted_at',  'TIMESTAMP', ''),
        ('updated_at',          'TIMESTAMP', ''),
    ]),
]

# ── Auto-calculate Y positions within each column ─────────────────────────────
GAP = 40   # vertical gap between tables

def tbl_height(attrs):
    return HDR_H + len(attrs) * ROW_H

# Group by column (by x value)
cols = {}
for t in TABLES:
    x = t[2]
    cols.setdefault(x, []).append(t)

# Rebuild with correct y values
tables_with_y = []
for x, group in cols.items():
    cur_y = 40
    for (name, color, tx, _, attrs) in group:
        tables_with_y.append((name, color, tx, cur_y, attrs))
        cur_y += tbl_height(attrs) + GAP

TABLES = tables_with_y

# ── Relationship definitions ───────────────────────────────────────────────────
# (from_table, from_col_row_idx, to_table, to_col_row_idx, label, cardinality)
# row_idx = 0-based index of the FK row in the source table
# We'll connect from the FK row to the PK row (idx 0) of target

RELATIONS = [
    # (src_table,           src_col,        dst_table,    label,          card,  style)
    ('elderly',             'caregiver_id', 'caregivers', 'caregiver_id', 'N:1', 'left'),
    ('qr_tokens',           'elderly_id',   'elderly',    'elderly_id',   'N:1', 'right'),
    ('elderly_connections', 'elderly_id',   'elderly',    'elderly_id',   'N:1', 'right'),
    ('elderly_connections', 'qr_token_id',  'qr_tokens',  'qr_token_id',  'N:1', 'up'),
    ('sos_requests',        'elderly_id',   'elderly',    'elderly_id',   'N:1', 'left'),
    ('sos_requests',        'caregiver_id', 'caregivers', 'caregiver_id', 'N:1', 'left'),
    ('events',              'elderly_id',   'elderly',    'elderly_id',   'N:1', 'left'),
    ('events',              'verified_by',  'caregivers', 'verified_by',  'N:1', 'left'),
    ('cameras',             'elderly_id',   'elderly',    'elderly_id',   'N:1', 'left'),
    ('elder_locations',     'elderly_id',   'elderly',    'elderly_id',   '1:1', 'left'),
    ('voice_messages',      'elderly_id',   'elderly',    'elderly_id',   'N:1', 'up'),
    ('voice_messages',      'caregiver_id', 'caregivers', 'caregiver_id', 'N:1', 'left'),
    ('elder_safe_zones',    'elderly_id',   'elderly',    'elderly_id',   '1:1', 'right'),
    ('elder_safe_zones',    'caregiver_id', 'caregivers', 'caregiver_id', 'N:1', 'up'),
]

# ── Build Draw.io XML ──────────────────────────────────────────────────────────
root_el  = ET.Element('mxfile', host='app.diagrams.net', version='21.0.0')
diagram  = ET.SubElement(root_el, 'diagram', name='SANAD ERD', id='sanad-erd')
model    = ET.SubElement(diagram, 'mxGraphModel',
                         dx='1422', dy='762', grid='1', gridSize='10',
                         guides='1', tooltips='1', connect='1', arrows='1',
                         fold='1', page='0', pageScale='1',
                         pageWidth='1654', pageHeight='1169',
                         math='0', shadow='1')
xml_root = ET.SubElement(model, 'root')
ET.SubElement(xml_root, 'mxCell', id='0')
ET.SubElement(xml_root, 'mxCell', id='1', parent='0')

# ── ID registry ──────────────────────────────────────────────────────────────
cell_id  = 2
tbl_ids  = {}    # table_name → container cell id
row_ids  = {}    # (table_name, col_name) → cell id

def next_id():
    global cell_id
    cid = str(cell_id)
    cell_id += 1
    return cid

# ── Helper: row background color ─────────────────────────────────────────────
def row_fill(flag, idx):
    flags = [f.strip() for f in flag.split(',') if f.strip()]
    if 'PK' in flags:  return ROW_PK
    if 'FK' in flags:  return ROW_FK
    if 'UK' in flags:  return ROW_UK
    return ROW_EVEN if idx % 2 == 0 else ROW_ODD

def row_label(col, dtype, flag):
    flags = [f.strip() for f in flag.split(',') if f.strip()]
    badges = ''.join(f'[{f}] ' for f in flags)
    return f'{badges}{col}   :   {dtype}'

def row_style(flag, idx):
    fill  = row_fill(flag, idx)
    flags = [f.strip() for f in flag.split(',') if f.strip()]
    bold  = '1' if 'PK' in flags else '0'
    fc    = '#C0392B' if 'PK' in flags else ('#2471A3' if 'FK' in flags else '#2C3E50')
    return (
        f'text;strokeColor=#D5D8DC;fillColor={fill};'
        f'align=left;verticalAlign=middle;'
        f'spacingLeft=8;spacingRight=4;overflow=hidden;'
        f'rotatable=0;points=[[0,0.5],[1,0.5]];'
        f'portConstraint=eastwest;'
        f'fontSize=11;fontStyle={bold};fontColor={fc};'
        f'fontFamily={FONT};'
    )

# ── Draw tables ───────────────────────────────────────────────────────────────
for (name, hdr_color, x, y, attrs) in TABLES:
    h  = tbl_height(attrs)
    tid = next_id()
    tbl_ids[name] = tid

    # Container cell (table header)
    hdr_style = (
        f'swimlane;fontStyle=1;align=center;verticalAlign=top;'
        f'childLayout=stackLayout;horizontal=1;startSize={HDR_H};'
        f'horizontalStack=0;resizeParent=1;resizeParentMax=0;'
        f'collapsible=0;marginBottom=0;'
        f'fillColor={hdr_color};fontColor={HDR_FONT};'
        f'strokeColor=#0E2D45;fontSize=13;fontFamily={FONT};'
        f'shadow=1;'
    )
    tbl_cell = ET.SubElement(xml_root, 'mxCell',
        id=tid, value=name, style=hdr_style,
        vertex='1', parent='1')
    ET.SubElement(tbl_cell, 'mxGeometry',
        x=str(x), y=str(y), width=str(TBL_W), height=str(h),
        **{'as': 'geometry'})

    # Attribute rows
    for i, (col, dtype, flag) in enumerate(attrs):
        rid    = next_id()
        row_ids[(name, col)] = rid
        label  = row_label(col, dtype, flag)
        rstyle = row_style(flag, i)

        row_cell = ET.SubElement(xml_root, 'mxCell',
            id=rid, value=label, style=rstyle,
            vertex='1', parent=tid)
        ET.SubElement(row_cell, 'mxGeometry',
            y=str(HDR_H + i * ROW_H), width=str(TBL_W), height=str(ROW_H),
            **{'as': 'geometry'})

# ── Draw relationships (edges) ────────────────────────────────────────────────
EDGE_STYLE = (
    'edgeStyle=orthogonalEdgeStyle;'
    'orthogonalLoop=1;jettySize=auto;'
    'exitX=1;exitY=0.5;exitDx=0;exitDy=0;'
    'entryX=0;entryY=0.5;entryDx=0;entryDy=0;'
    'endArrow=ERmany;endFill=0;'
    'startArrow=ERone;startFill=0;'
    'strokeColor=#5D6D7E;strokeWidth=1.5;'
    'fontFamily=Helvetica;fontSize=10;fontColor=#2C3E50;'
    'labelBackgroundColor=#FDFEFE;'
)

for (src_tbl, src_col, dst_tbl, label, card, _) in RELATIONS:
    eid = next_id()

    # Find the source row cell id for the FK column
    src_cell = row_ids.get((src_tbl, src_col), tbl_ids.get(src_tbl, '1'))
    # Target is always the PK row (first attribute) of the destination table
    dst_pk_col = next(
        col for col, dtype, flag in
        next(attrs for name, *_, attrs in TABLES if name == dst_tbl)
        if 'PK' in flag
    )
    dst_cell = row_ids.get((dst_tbl, dst_pk_col), tbl_ids.get(dst_tbl, '1'))

    edge_cell = ET.SubElement(xml_root, 'mxCell',
        id=eid,
        value=f'{label}\n({card})',
        style=EDGE_STYLE,
        edge='1', parent='1',
        source=src_cell, target=dst_cell)
    ET.SubElement(edge_cell, 'mxGeometry', relative='1', **{'as': 'geometry'})

# ── Pretty-print and save ─────────────────────────────────────────────────────
raw    = ET.tostring(root_el, encoding='unicode')
pretty = minidom.parseString(raw).toprettyxml(indent='  ', encoding='UTF-8')
# minidom adds <?xml ...?> — keep it

out = 'ERD_SANAD.drawio'
with open(out, 'wb') as f:
    f.write(pretty)

print(f'✅  Saved → {out}')
print(f'   Tables : {len(TABLES)}')
print(f'   Relations: {len(RELATIONS)}')
print(f'   Total cells: {cell_id - 2}')
print()
print('   → Open in draw.io:  https://app.diagrams.net/')
print('   → Or desktop app:   File → Open → ERD_SANAD.drawio')

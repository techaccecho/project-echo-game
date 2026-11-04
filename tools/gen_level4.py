#!/usr/bin/env python3
"""Bake world/game_level_4.tscn — The Haven — and tilesets/winter_haven.tres.

The Haven is the one level with no route through it: a pale lavender plain
that frays into white-out at the edges, with the beats set far apart and
reachable in any order. There is no maze and no gate, so most of this file is
the island's shape, the tiles that draw its edge, and the rectangles that stop
you walking off into the white.

Run from the repo root:  python3 tools/gen_level4.py [--bake]
Without --bake it only writes the preview PNG.
"""
import base64, math, random, re, struct, sys

random.seed(104)

def rect(s):
    """The four numbers out of a `Rect2(x, y, w, h)` literal, as ints.

    Not `s.strip("Rect2() ")`: strip takes a set of characters, so that idiom
    also eats any leading or trailing digit that is one of Rect2's own —
    "Rect2(0, 0, 32, 32)" parsed as 32x3 and the open chest's
    "Rect2(200, 0, 16, 16)" parsed at x=0. Both were wrong for a long time,
    silently, in the preview renderer that is supposed to catch exactly this.
    """
    inside = re.search(r"\(([^)]*)\)", s).group(1)
    return tuple(int(n) for n in re.findall(r"-?\d+", inside))


ART = "res://art/Farm RPG - Tiny Asset Pack - (All in One)/"
DISK = "art/Farm RPG - Tiny Asset Pack - (All in One)/"
WINTER = ART + "Farm and Tileset/Tileset/Tileset Grass Winter.png"
WINTER_UID = "uid://3l374bmw3hcx"
TILESET_UID = "uid://cw1nt3rhav3n4"

W, H = 104, 72                     # tiles
TILE = 16
PX = (W * TILE, H * TILE)

# --- the Winter sheet -------------------------------------------------------
# 24x40 cells of 12x4 autotile variants, 2 across and 10 down. The one at cols
# 0-11 / rows 8-11 is lavender-on-white, and it is a *corner* (Wang) set, not
# an edge one: a tile is chosen by which of its four corners are lavender, so
# the island is defined on the grid's vertices rather than its cells. This
# table was read off the sheet's own pixels — the first three columns of the
# variant are a small decorative patch, not part of the blob.
WANG = {
    (0, 0, 0, 0): (9, 2),          # the sheet's one fully opaque white cell
    (0, 0, 0, 1): (5, 8), (0, 0, 1, 0): (6, 8), (0, 0, 1, 1): (9, 8),
    (0, 1, 0, 0): (7, 8), (0, 1, 0, 1): (8, 9), (0, 1, 1, 0): (9, 9),
    (0, 1, 1, 1): (5, 9), (1, 0, 0, 0): (4, 8), (1, 0, 0, 1): (10, 10),
    (1, 0, 1, 0): (11, 9), (1, 0, 1, 1): (6, 9), (1, 1, 0, 0): (9, 11),
    (1, 1, 0, 1): (5, 10), (1, 1, 1, 0): (6, 10), (1, 1, 1, 1): (9, 10),
}
WHITE_FILL = WANG[(0, 0, 0, 0)]
# The variant four rows up is the same set with the colours swapped — white on
# lavender. Painting a small disc of it under the altar turns the heart of the
# plain into a worn pale clearing without a second sheet.
def pale(c):
    return (c[0], c[1] - 8)

# --- the island -------------------------------------------------------------
CX, CY, RX, RY = 51.5, 35.0, 46.0, 31.0

def inside(vx, vy):
    """A lobed clover rather than an ellipse, so no stretch of the edge reads
    as a wall the player is being herded along. Evaluated on vertices."""
    dx, dy = (vx - CX) / RX, (vy - CY) / RY
    r = math.hypot(dx, dy)
    if r == 0.0:
        return True
    t = math.atan2(dy, dx)
    return r < (1.0 + 0.125 * math.sin(3 * t + 0.6)
                    + 0.075 * math.sin(5 * t + 2.4)
                    + 0.045 * math.sin(7 * t + 1.1))

VERT = [[inside(x, y) for y in range(H + 1)] for x in range(W + 1)]

def corners(x, y):
    return (int(VERT[x][y]), int(VERT[x + 1][y]),
            int(VERT[x][y + 1]), int(VERT[x + 1][y + 1]))

# Walkable means the whole tile is ground: all four of its corners are in.
MASK = [[corners(x, y) == (1, 1, 1, 1) for y in range(H)] for x in range(W)]

def at(x, y):
    return 0 <= x < W and 0 <= y < H and MASK[x][y]

# --- collision --------------------------------------------------------------
def cover(blocked):
    """Greedy largest-rectangle cover of the blocked cells. One big rect per
    corner of the white-out beats a hundred one-row slivers."""
    grid = [row[:] for row in blocked]
    rects = []
    while True:
        best, heights = None, [0] * W
        for y in range(H):
            for x in range(W):
                heights[x] = heights[x] + 1 if grid[x][y] else 0
            stack = []                                   # (start x, height)
            for x in range(W + 1):
                h = heights[x] if x < W else 0
                start = x
                while stack and stack[-1][1] >= h:
                    sx, sh = stack.pop()
                    area = sh * (x - sx)
                    if best is None or area > best[0]:
                        best = (area, sx, y - sh + 1, x - sx, sh)
                    start = sx
                stack.append((start, h))
        if best is None or best[0] == 0:
            return rects
        _, x0, y0, w, h = best
        rects.append((x0, y0, w, h))
        for x in range(x0, x0 + w):
            for y in range(y0, y0 + h):
                grid[x][y] = False

WALLS = cover([[not MASK[x][y] for y in range(H)] for x in range(W)])

# --- where the beats go -----------------------------------------------------
def snap(x, y, clear=2):
    """Nearest cell with `clear` tiles of ground all round it, so nothing is
    ever placed half inside the white-out."""
    best = None
    for ty in range(H):
        for tx in range(W):
            if not all(at(tx + dx, ty + dy)
                       for dx in (-clear, 0, clear)
                       for dy in (-clear, 0, clear)):
                continue
            d = (tx - x) ** 2 + (ty - y) ** 2
            if best is None or d < best[0]:
                best = (d, tx, ty)
    return best[1], best[2]

ALTAR = snap(52, 33)
CAMP = snap(21, 16)
ARCH = snap(52, 63)

# The clearing: a white disc centred on the altar, drawn with the inverted
# variant so its edge frays the same way the island's does.
CLEAR_R = 6.0

def pale_in(vx, vy):
    return math.hypot(vx - (ALTAR[0] + 0.5), vy - (ALTAR[1] - 0.6)) < CLEAR_R

def pale_corners(x, y):
    return (int(pale_in(x, y)), int(pale_in(x + 1, y)),
            int(pale_in(x, y + 1)), int(pale_in(x + 1, y + 1)))

# Hooded stones, out on the rim and well apart: they are a presence at the
# edge of sight, not furniture. The Guardian wears the same hood, so a crowd
# of them would spend the reveal before the player ever reaches it.
STATUES = [snap(int(CX + math.cos(math.radians(a)) * RX * r),
                int(CY + math.sin(math.radians(a)) * RY * r))
           for a, r in [(-112, 0.78), (-40, 0.84), (24, 0.74),
                        (96, 0.80), (150, 0.78), (-166, 0.72)]]

# The Guardian does not stand beside the stones, it is in one of them — so it
# is baked onto the east one and game_level_4.gd hides whichever stone it is
# occupying. Placing it anywhere else would show a seventh figure on load and
# then teleport it.
GUARDIAN = min(STATUES, key=lambda c: (c[0] - 85) ** 2 + (c[1] - 29) ** 2)
BEATS = [ALTAR, CAMP, GUARDIAN, ARCH]

# Pale stones and snow patches, thickest near the edge where the plain frays.
DRESSING = []
for _ in range(620):
    x, y = random.randrange(W), random.randrange(H)
    if not at(x, y):
        continue
    r = math.hypot((x + 0.5 - CX) / RX, (y + 0.5 - CY) / RY)
    if random.random() > 0.10 + r * r * 0.85:
        continue
    if min((x - a) ** 2 + (y - b) ** 2 for a, b in BEATS + STATUES) < 16:
        continue
    DRESSING.append((x, y, random.randrange(4)))

STONE_REGIONS = ["Rect2(32, 0, 16, 16)", "Rect2(80, 0, 16, 16)",
                 "Rect2(0, 16, 16, 16)", "Rect2(0, 32, 16, 16)"]

# Pages off Cedric's pile, carried out across the plain. Flat, nothing to pick
# up — they are a trail of him, and a reason to walk towards the middle of an
# otherwise featureless stretch. Thinnest at the camp, where they came from.
PAGES = []
for _ in range(400):
    x, y = random.randrange(W), random.randrange(H)
    if not at(x, y) or len(PAGES) >= 16:
        continue
    d_camp = math.hypot(x - CAMP[0], y - CAMP[1])
    if d_camp < 7 or random.random() > 0.55 - d_camp * 0.008:
        continue
    if min((x - a) ** 2 + (y - b) ** 2 for a, b in BEATS + STATUES) < 25:
        continue
    if PAGES and min((x - a) ** 2 + (y - b) ** 2 for a, b, _ in PAGES) < 36:
        continue
    PAGES.append((x, y, random.uniform(-0.5, 0.5)))
# Cedric's camp, laid out round the dead fire at the origin rather than
# scattered at random: someone chose where to put each of these. Entries are
# (sheet id, dx, dy, region, flat) — flat items have no collision and draw
# under the player, who walks over them.
CAMP_SHEETS = {
    "sheet": "Exterior/Picnic.png", "moss": "Exterior/wood moss.png",
    "chest": "Exterior/chest.png", "lamp": "Exterior/Lamp .png",
    "box": "Exterior/Box.png",
    "page": "Icons/Weapons/Books and Potions/Books.png",
}

CAMP_PROPS = [
    ("sheet",  34,  26, "Rect2(48, 0, 48, 48)",   True),   # his groundsheet
    ("page",   32,   4, "Rect2(0, 48, 16, 16)",   True),
    ("page",    6,  34, "Rect2(0, 48, 16, 16)",   True),
    ("page",  -34,  26, "Rect2(0, 48, 16, 16)",   True),
    ("page",  -20, -22, "Rect2(0, 48, 16, 16)",   True),
    ("moss",  -34,   6, "Rect2(0, 0, 32, 32)",    False),  # his woodpile
    ("moss",   22, -14, "Rect2(32, 0, 16, 32)",   False),  # a log to sit on
    ("chest",  -6, -24, "Rect2(200, 0, 16, 16)",  False),  # left standing open
    # East of the log, not behind it. The preview renderer draws these in
    # table order rather than y-sorted, so the lamp looked fine there while
    # the game would have hidden it behind the log entirely.
    ("lamp",   44, -26, "Rect2(0, 0, 16, 16)",    False),  # unlit
    ("box",   -30, -16, "Rect2(16, 0, 16, 16)",   False),
    ("box",   -16,  24, "Rect2(0, 0, 16, 16)",    False),
    ("box",    40,  -4, "Rect2(0, 16, 16, 16)",   False),
]

_FOOT = {}

def footprint(sheet, region):
    """Where a standing prop actually meets the ground, read off its alpha.

    Hand-written collision boxes were the bug here: the camp was baked as bare
    Sprite2Ds with none at all, so you walked straight through the crates and
    the woodpile, and the y-sorting that was working correctly looked broken
    because nothing stopped you standing inside a thing you were drawn over.

    Guessing the box from the crop is no good either — several of these crops
    have empty rows under the art (the lamp's bottom three are blank), so a
    box sized to the crop floats. This finds the lowest opaque row, takes the
    widest the art gets over the five rows above it, and returns a rect in the
    node's own space, where the sprite's offset puts the crop's bottom edge
    two pixels below the origin.
    """
    key = (sheet, region)
    if key in _FOOT:
        return _FOOT[key]
    from PIL import Image
    rx, ry, rw, rh = region
    a = (Image.open(DISK + CAMP_SHEETS[sheet]).convert("RGBA")
         .crop((rx, ry, rx + rw, ry + rh)).split()[3])
    rows = [[x for x in range(rw) if a.getpixel((x, y)) > 40] for y in range(rh)]
    solid = [y for y, xs in enumerate(rows) if xs]
    top, base = solid[0], solid[-1]
    span = [x for y in range(max(top, base - 4), base + 1) for x in rows[y]]
    lo, hi = min(span), max(span)
    # Half the art's height, so a crate is waist-deep and a woodpile is not
    # something you can stand in the middle of; capped either way.
    h = max(5, min(10, (base - top + 1) // 2))
    # The crop's bottom row sits at y = +2 in node space (offset is -rh + 2),
    # so the art's own last row is at +2 - (rh - 1 - base).
    bottom = 2 - (rh - 1 - base)
    foot = (hi - lo + 1, h, (lo + hi + 1) / 2 - rw / 2, bottom - h / 2)
    _FOOT[key] = foot
    return foot

# --- emit -------------------------------------------------------------------
def encode(cells):
    out = bytearray(struct.pack("<H", 0))
    for x, y, ax, ay in cells:
        out += struct.pack("<hhhhhh", x, y, 0, ax, ay, 0)
    return base64.b64encode(bytes(out)).decode()

GROUND = [(x, y, *WHITE_FILL) for y in range(H) for x in range(W)]
PLAIN = [(x, y, *WANG[corners(x, y)])
         for y in range(H) for x in range(W) if corners(x, y) != (0, 0, 0, 0)]
CLEARING = [(x, y, *pale(WANG[pale_corners(x, y)]))
            for y in range(H) for x in range(W)
            if pale_corners(x, y) != (0, 0, 0, 0)]

def px(cell, ox=0.0, oy=0.0):
    return (cell[0] * TILE + 8 + ox, cell[1] * TILE + 8 + oy)

_shapes, _n = [], 0

def shape(w, h):
    global _n
    _n += 1
    _shapes.append(f'[sub_resource type="RectangleShape2D" id="RS_{_n}"]\n'
                   f'size = Vector2({w}, {h})\n\n')
    return f"RS_{_n}"

def write_tileset():
    cells = "\n".join(f"{x}:{y}/0 = 0" for y in range(40) for x in range(24))
    open("tilesets/winter_haven.tres", "w").write(f'''[gd_resource type="TileSet" format=3 uid="{TILESET_UID}"]

[ext_resource type="Texture2D" uid="{WINTER_UID}" path="{WINTER}" id="1_winter"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_winter"]
texture = ExtResource("1_winter")
{cells}

[resource]
sources/0 = SubResource("TileSetAtlasSource_winter")
''')

def write_scene():
    walls = "".join(
        f'\n[node name="S{i}" type="CollisionShape2D" parent="Walls"]\n'
        f'position = Vector2({x * TILE + w * TILE / 2}, {y * TILE + h * TILE / 2})\n'
        f'shape = SubResource("{shape(w * TILE, h * TILE)}")\n'
        for i, (x, y, w, h) in enumerate(WALLS))
    stones = "".join(
        f'\n[node name="Stone{i}" parent="Stones" instance=ExtResource("statue")]\n'
        f'position = Vector2{px(c)}\n' for i, c in enumerate(STATUES))
    dressing = "".join(
        f'\n[node name="D{i}" parent="Dressing" instance=ExtResource("stone")]\n'
        f'position = Vector2({x * TILE + 8}, {y * TILE + 8})\nvariant = {v}\n'
        for i, (x, y, v) in enumerate(DRESSING))
    pages = "".join(
        f'\n[node name="Page{i}" type="Sprite2D" parent="Dressing"]\n'
        f'z_index = -1\nposition = Vector2({x * TILE + 8}, {y * TILE + 8})\n'
        f'rotation = {r:.3f}\nmodulate = Color(0.93, 0.92, 0.97, 1)\n'
        f'texture = ExtResource("page")\nregion_enabled = true\n'
        f'region_rect = Rect2(0, 48, 16, 16)\n'
        for i, (x, y, r) in enumerate(PAGES))
    ap, cp, gp, rp = px(ALTAR), px(CAMP), px(GUARDIAN), px(ARCH)
    camp, camp_bodies = "", ""
    for i, (sheet, dx, dy, r, flat) in enumerate(CAMP_PROPS):
        region = rect(r)
        w, h = float(region[2]), float(region[3])
        # Flat things lie on the ground under the player; standing ones have
        # their origin on the footprint so y-sorting puts him in front of
        # anything he is south of.
        off = (f"Vector2({-w / 2}, {-h / 2})" if flat
               else f"Vector2({-w / 2}, {-h + 2})")
        camp += (f'\n[node name="C{i}_{sheet}" type="Sprite2D" parent="Camp"]\n'
                 + (f'z_index = -1\n' if flat else "")
                 + f'position = Vector2({cp[0] + dx}, {cp[1] + dy})\n'
                 f'centered = false\ntexture = ExtResource("{sheet}")\n'
                 f'region_enabled = true\nregion_rect = {r}\n'
                 f'offset = {off}\n')
        if flat:
            continue
        # One StaticBody2D for all of them, with a shape per prop: the player
        # walks round the crates and the woodpile and over the groundsheet and
        # the pages, which is the distinction `flat` is for.
        fw, fh, fx, fy = footprint(sheet, region)
        camp_bodies += (
            f'\n[node name="F{i}_{sheet}" type="CollisionShape2D" '
            f'parent="CampProps"]\n'
            f'position = Vector2({cp[0] + dx + fx}, {cp[1] + dy + fy})\n'
            f'shape = SubResource("{shape(fw, fh)}")\n')
    altar_body, altar_touch = shape(44, 16), shape(60, 46)
    fire_body = shape(14, 6)

    open("world/game_level_4.tscn", "w").write(f'''[gd_scene format=4 uid="uid://bh4v3nl3v3l4"]

[ext_resource type="Script" path="res://world/game_level_4.gd" id="script"]
[ext_resource type="TileSet" uid="{TILESET_UID}" path="res://tilesets/winter_haven.tres" id="winterset"]
[ext_resource type="PackedScene" path="res://objects/haven/haven_statue.tscn" id="statue"]
[ext_resource type="PackedScene" path="res://objects/haven/haven_stone.tscn" id="stone"]
[ext_resource type="PackedScene" uid="uid://bibupx3yvo61" path="res://interaction/interaction_area/interaction_area.tscn" id="iarea"]
[ext_resource type="PackedScene" uid="uid://blvlaud102ec" path="res://objects/level_audio.tscn" id="levelaudio"]
[ext_resource type="PackedScene" uid="uid://ccamb0und5l2" path="res://objects/camera_bounds.tscn" id="cambounds"]
[ext_resource type="PackedScene" path="res://objects/haven_light.tscn" id="havenlight"]
[ext_resource type="PackedScene" path="res://objects/haven_motes.tscn" id="motes"]
[ext_resource type="Texture2D" uid="uid://c850ej4shok8h" path="{ART}Exterior/Altar.png" id="altar"]
[ext_resource type="PackedScene" uid="uid://dp0rta1hav3n4" path="res://objects/haven/haven_portal.tscn" id="portal"]
[ext_resource type="PackedScene" uid="uid://cgu4rd1anech4" path="res://character/npc_guardian.tscn" id="guardian"]
[ext_resource type="Texture2D" uid="uid://yuqplghwloxn" path="{ART}Exterior/bonfire.png" id="fire"]
[ext_resource type="Texture2D" uid="uid://bh4ej70q5hjqj" path="{ART}Exterior/Box.png" id="box"]
[ext_resource type="Texture2D" uid="uid://dc2lr78c1t8hk" path="{ART}Exterior/Picnic.png" id="sheet"]
[ext_resource type="Texture2D" uid="uid://dapbdupsehdj8" path="{ART}Exterior/wood moss.png" id="moss"]
[ext_resource type="Texture2D" uid="uid://dbgd72jo61kyv" path="{ART}Exterior/chest.png" id="chest"]
[ext_resource type="Texture2D" uid="uid://co0ei2pt10bxk" path="{ART}Exterior/Lamp .png" id="lamp"]
[ext_resource type="Texture2D" uid="uid://7g7rmeqwftkm" path="{ART}Icons/Weapons/Books and Potions/Books.png" id="page"]

{"".join(_shapes)}[node name="GameLevel4" type="Node2D"]
y_sort_enabled = true
script = ExtResource("script")

[node name="Ground" type="TileMapLayer" parent="."]
z_index = -20
tile_map_data = PackedByteArray("{encode(GROUND)}")
tile_set = ExtResource("winterset")

[node name="Plain" type="TileMapLayer" parent="."]
z_index = -19
tile_map_data = PackedByteArray("{encode(PLAIN)}")
tile_set = ExtResource("winterset")

[node name="Clearing" type="TileMapLayer" parent="."]
z_index = -18
tile_map_data = PackedByteArray("{encode(CLEARING)}")
tile_set = ExtResource("winterset")

[node name="Walls" type="StaticBody2D" parent="."]
{walls}
[node name="Dressing" type="Node2D" parent="."]
z_index = 5
y_sort_enabled = true
modulate = Color(0.96, 0.96, 1, 1)
{dressing}{pages}
[node name="Stones" type="Node2D" parent="."]
z_index = 5
y_sort_enabled = true
modulate = Color(0.88, 0.88, 0.97, 1)
{stones}
[node name="Altar" type="Node2D" parent="."]
z_index = 5
y_sort_enabled = true
position = Vector2{ap}

[node name="Sprite2D" type="Sprite2D" parent="Altar"]
centered = false
texture = ExtResource("altar")
region_enabled = true
region_rect = Rect2(0, 48, 48, 48)
offset = Vector2(-24, -42)

[node name="Body" type="StaticBody2D" parent="Altar"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Altar/Body"]
position = Vector2(0, -8)
shape = SubResource("{altar_body}")

[node name="InteractionArea" parent="Altar" instance=ExtResource("iarea")]
position = Vector2(0, -16)
action_name = "read the stone"

[node name="CollisionShape2D" type="CollisionShape2D" parent="Altar/InteractionArea"]
shape = SubResource("{altar_touch}")

[node name="Camp" type="Node2D" parent="."]
z_index = 5
y_sort_enabled = true
modulate = Color(0.92, 0.86, 0.88, 1)
{camp}
[node name="Fire" type="Sprite2D" parent="Camp"]
position = Vector2{cp}
centered = false
texture = ExtResource("fire")
region_enabled = true
region_rect = Rect2(0, 24, 16, 8)
offset = Vector2(-8, -7)

[node name="FireBody" type="StaticBody2D" parent="Camp"]
position = Vector2{cp}

[node name="CollisionShape2D" type="CollisionShape2D" parent="Camp/FireBody"]
position = Vector2(0, -3)
shape = SubResource("{fire_body}")

[node name="CampProps" type="StaticBody2D" parent="."]
{camp_bodies}
[node name="Arch" parent="." instance=ExtResource("portal")]
z_index = 5
position = Vector2{rp}

[node name="Entities" type="Node2D" parent="."]
z_index = 5
y_sort_enabled = true

[node name="Guardian" parent="Entities" instance=ExtResource("guardian")]
position = Vector2{gp}

[node name="FragmentMark" type="Marker2D" parent="Entities"]
position = Vector2({cp[0] + 34}, {cp[1] + 22})

[node name="HavenArrival" type="Marker2D" parent="." groups=["player_spawn"]]
position = Vector2({rp[0]}, {rp[1] - 30})

[node name="Light" parent="." instance=ExtResource("havenlight")]

[node name="Motes" parent="." instance=ExtResource("motes")]
area_size = Vector2({PX[0]}, {PX[1]})
area_center = Vector2({PX[0] / 2}, {PX[1] / 2})

[node name="CameraBounds" parent="." instance=ExtResource("cambounds")]
bounds = Rect2i(0, 0, {PX[0]}, {PX[1]})

[node name="LevelAudio" parent="." instance=ExtResource("levelaudio")]
music = "res://audio/music/haven_bed.wav"
music_volume_db = -9.5
music_fade = 7.0
''')

def write_preview():
    from PIL import Image
    src = Image.open(DISK + "Farm and Tileset/Tileset/Tileset Grass Winter.png").convert("RGBA")
    img = Image.new("RGBA", PX, (255, 255, 255, 255))
    for cells in (GROUND, PLAIN, CLEARING):
        for x, y, ax, ay in cells:
            img.alpha_composite(src.crop((ax * 16, ay * 16, ax * 16 + 16, ay * 16 + 16)),
                                (x * TILE, y * TILE))
    def prop(path, region, cell, ox=0, oy=0, tint=None):
        s = Image.open(DISK + path).convert("RGBA")
        rx, ry, rw, rh = region
        s = s.crop((rx, ry, rx + rw, ry + rh))
        if tint:
            s = Image.merge("RGBA", [b.point(lambda v, k=k: int(v * k))
                                     for b, k in zip(s.split(), tint + (1.0,))])
        img.alpha_composite(s, (int(cell[0] * TILE + 8 - rw // 2 + ox),
                                int(cell[1] * TILE + 8 - rh + oy)))
    for x, y, v in DRESSING:
        r = [rect(q) for q in STONE_REGIONS][v]
        prop("Farm and Tileset/Props/Winter/Stones .png", r, (x, y), 0, 0, (.96, .96, 1.))
    for x, y, _ in PAGES:
        prop("Icons/Weapons/Books and Potions/Books.png", (0, 48, 16, 16),
             (x, y), 0, 12, (.93, .92, .97))
    for c in STATUES:
        prop("Exterior/Dungeon/statue.png", (0, 48, 64, 48), c, 0, 6, (.88, .88, .97))
    sheets = {"sheet": "Exterior/Picnic.png", "moss": "Exterior/wood moss.png",
              "chest": "Exterior/chest.png", "lamp": "Exterior/Lamp .png",
              "box": "Exterior/Box.png",
              "page": "Icons/Weapons/Books and Potions/Books.png"}
    for sheet, dx, dy, q, flat in CAMP_PROPS:
        r = rect(q)
        # Scene offsets are (-w/2, -h/2) flat and (-w/2, -h+2) standing; prop()
        # already subtracts h, so only the remainder goes in here.
        prop(sheets[sheet], r, CAMP, dx, dy + (r[3] // 2 if flat else 2),
             (.92, .86, .88))
    prop("Exterior/bonfire.png", (0, 24, 16, 8), CAMP, 0, 2, (.92, .86, .88))
    prop("Exterior/Dungeon/statue.png", (0, 144, 64, 48), GUARDIAN, 0, 6, (1., .97, .94))
    prop("Exterior/Altar.png", (0, 48, 48, 48), ALTAR, 0, 6)
    prop("Exterior/Deep Forest/Root portal.png", (144, 0, 48, 48), ARCH, 0, 4, (.93, .88, .95))
    out = ("/private/tmp/claude-502/-Users-caleb-linden-Documents-GitHub-"
           "project-echo-game/0faff1fd-dfcd-4a0a-a85f-bcadcf212838/"
           "scratchpad/l4/level4.png")
    img.resize((PX[0] * 2, PX[1] * 2), Image.NEAREST).save(out)
    print("preview ->", out)

if "--bake" in sys.argv:
    write_tileset()
    write_scene()
    print(f"baked {W}x{H} tiles, {len(WALLS)} wall rects, "
          f"{len(DRESSING)} stones, {len(PAGES)} pages")
    print(f"  altar {ALTAR}  camp {CAMP}  guardian {GUARDIAN}  arch {ARCH}")
write_preview()

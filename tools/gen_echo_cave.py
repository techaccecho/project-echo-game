#!/usr/bin/env python3
"""Bake world/echo_cave_interior.tscn — the hidden fire-lit cave off the
Cliffside Path — and its TileSet. Run from the repo root."""
import base64, struct, random
random.seed(5)
ROCK = "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Farm and Tileset/Tileset/Rock Caves.png"
ROCK_UID = "uid://deyb2k33h45y"
W, H = 12, 10
FLOOR = [(5, 1), (6, 1), (5, 2), (6, 2)]
FACE = [(0, 4), (1, 4), (2, 4), (3, 4), (8, 4), (9, 4), (10, 4), (11, 4)]
RIM = {"tl": (4, 0), "t": (5, 0), "tr": (7, 0), "l": (4, 1), "r": (7, 1), "bl": (4, 3), "b": (5, 3), "br": (7, 3)}
EXIT = (5, 6)                     # columns of the gap in the bottom rim

def encode(cs):
    out = bytearray(struct.pack("<H", 0))
    for x, y, src, ax, ay in cs:
        out += struct.pack("<hhhhhh", x, y, src, ax, ay, 0)
    return base64.b64encode(bytes(out)).decode()

tiles = "\n".join(f"{x}:{y}/0 = 0" for y in range(45) for x in range(36))
open("tilesets/rock_caves.tres", "w").write(f'''[gd_resource type="TileSet" format=3 uid="uid://cr0ckcav3s2ec"]

[ext_resource type="Texture2D" uid="{ROCK_UID}" path="{ROCK}" id="1_rock"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_rock"]
texture = ExtResource("1_rock")
{tiles}

[resource]
sources/0 = SubResource("TileSetAtlasSource_rock")
''')

cells = []
for x in range(W):
    for y in range(3):                                  # the worked back wall
        cells.append((x, y, 0, *FACE[(x * 7 + y * 3) % len(FACE)]))
for y in range(3, H):
    for x in range(W):
        if y == 3: k = "tl" if x == 0 else ("tr" if x == W - 1 else "t")
        elif y == H - 1:
            if x in EXIT: cells.append((x, y, 0, *random.choice(FLOOR))); continue
            k = "bl" if x == 0 else ("br" if x == W - 1 else "b")
        elif x == 0: k = "l"
        elif x == W - 1: k = "r"
        else: cells.append((x, y, 0, *random.choice(FLOOR))); continue
        cells.append((x, y, 0, *RIM[k]))

ex = (EXIT[0] * 16 + 16, (H - 1) * 16 + 6)
shapes = ""; bodies = ""; n = 0
def solid(x, y, w, h):
    global shapes, bodies, n
    n += 1
    shapes += f'\n[sub_resource type="RectangleShape2D" id="RS_{n}"]\nsize = Vector2({w}, {h})\n'
    bodies += f'\n[node name="S{n}" type="CollisionShape2D" parent="Solids"]\nposition = Vector2({x + w/2}, {y + h/2})\nshape = SubResource("RS_{n}")\n'
solid(0, 0, W * 16, 4 * 16 - 6)          # back wall down to just into the top rim
solid(0, 0, 16 + 4, H * 16)
solid((W - 1) * 16 - 4, 0, 20, H * 16)
solid(0, (H - 1) * 16 + 4, EXIT[0] * 16, 16)
solid((EXIT[1] + 1) * 16, (H - 1) * 16 + 4, (W - EXIT[1] - 1) * 16, 16)
solid(82, 100, 28, 12)                    # the fire
areas = ""
for name, verb, x, y, w, h in [("Fire", "warm up", 80, 84, 32, 32), ("Wall", "look", 64, 40, 64, 30), ("Stones", "look", 24, 96, 40, 28)]:
    n += 1
    shapes += f'\n[sub_resource type="RectangleShape2D" id="RS_{n}"]\nsize = Vector2({w}, {h})\n'
    areas += f'\n[node name="{name}" parent="Interact" instance=ExtResource("iarea")]\nposition = Vector2({x + w/2}, {y + h/2})\naction_name = "{verb}"\n\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Interact/{name}"]\nshape = SubResource("RS_{n}")\n'

open("world/echo_cave_interior.tscn", "w").write(f'''[gd_scene format=4 uid="uid://c3ch0cav31nt2"]

[ext_resource type="Script" path="res://world/house_interior.gd" id="script"]
[ext_resource type="TileSet" uid="uid://cr0ckcav3s2ec" path="res://tilesets/rock_caves.tres" id="rockset"]
[ext_resource type="PackedScene" uid="uid://wvbxyfgl33vp" path="res://character/player_josh.tscn" id="player"]
[ext_resource type="PackedScene" uid="uid://blvlaud102ec" path="res://objects/level_audio.tscn" id="levelaudio"]
[ext_resource type="PackedScene" uid="uid://doa04urw7iidr" path="res://inventory/inv_ui.tscn" id="invui"]
[ext_resource type="PackedScene" uid="uid://bibupx3yvo61" path="res://interaction/interaction_area/interaction_area.tscn" id="iarea"]
[ext_resource type="PackedScene" uid="uid://cq40o8258u0ra" path="res://objects/campfire.tscn" id="campfire"]
[ext_resource type="PackedScene" uid="uid://cn1ght11ght2e" path="res://objects/night_light.tscn" id="light"]
[ext_resource type="PackedScene" uid="uid://c8frgpk2echo" path="res://objects/fragment_pickup.tscn" id="frag"]
[ext_resource type="Resource" uid="uid://bqechofrag06x" path="res://fragments/fragment_06_the_hollow_behind_the_pine.tres" id="frag06"]
[ext_resource type="Texture2D" uid="{ROCK_UID}" path="{ROCK}" id="rocktex"]
{shapes}
[sub_resource type="RectangleShape2D" id="RS_exit"]
size = Vector2(32, 12)

[node name="EchoCaveInterior" type="Node2D"]
y_sort_enabled = true
script = ExtResource("script")
outside = "res://world/game_level_2.tscn"
outside_spawn = "EggCave"
outside_is_shell = true
story = "res://dialogue/echo_cave.dialogue"
bed = ""
lines = {{"Fire": "fire", "Wall": "wall", "Stones": "stones"}}

[node name="Backdrop" type="Polygon2D" parent="."]
z_index = -10
color = Color(0.02, 0.015, 0.02, 1)
polygon = PackedVector2Array(-2000, -2000, 2500, -2000, 2500, 2500, -2000, 2500)

[node name="Dark" type="CanvasModulate" parent="."]
color = Color(0.42, 0.36, 0.42, 1)

[node name="Floor" type="TileMapLayer" parent="."]
z_index = -2
tile_map_data = PackedByteArray("{encode(cells)}")
tile_set = ExtResource("rockset")

[node name="Props" type="Node2D" parent="."]
y_sort_enabled = true

[node name="Stones" type="Sprite2D" parent="Props"]
position = Vector2(24, 96)
texture = ExtResource("rocktex")
centered = false
offset = Vector2(0, -16)
region_enabled = true
region_rect = Rect2(64, 64, 16, 16)

[node name="Campfire" parent="Props" instance=ExtResource("campfire")]
position = Vector2(96, 104)

[node name="FireLight" parent="Props/Campfire" instance=ExtResource("light")]
position = Vector2(0, -6)
radius = 96.0
strength = 1.3
flicker = 0.14
always_on = true

[node name="Fragment6" parent="Props" instance=ExtResource("frag")]
position = Vector2(150, 78)
fragment = ExtResource("frag06")

[node name="Solids" type="StaticBody2D" parent="."]
{bodies}
[node name="Interact" type="Node2D" parent="."]
{areas}
[node name="Exit" type="Area2D" parent="."]
position = Vector2({ex[0]}, {(H - 1) * 16 + 14})

[node name="CollisionShape2D" type="CollisionShape2D" parent="Exit"]
shape = SubResource("RS_exit")

[node name="Entrance" type="Marker2D" parent="." groups=["player_spawn"]]
position = Vector2({ex[0]}, {(H - 2) * 16 - 4})

[node name="PlayerJosh" parent="." instance=ExtResource("player")]
position = Vector2({ex[0]}, {(H - 2) * 16 - 4})

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2({W * 8}, {H * 8})
zoom = Vector2(4, 4)

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="Inv_UI" parent="CanvasLayer" instance=ExtResource("invui")]
offset_left = 527.0
offset_top = 167.0
offset_right = 624.0
offset_bottom = 241.0
scale = Vector2(10, 10)

[node name="LevelAudio" parent="." instance=ExtResource("levelaudio")]
music = "res://audio/music/cliffside_bed.wav"
music_volume_db = -12.0

[connection signal="body_entered" from="Exit" to="." method="_on_exit_body_entered"]
''')
print("cave", W, "x", H, "cells", len(cells), "exit at", ex)

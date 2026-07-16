import os, re

d_sprites = r'c:\Users\86130\CodeBuddy\20260605221757\tecent-hackathon\game2\assets\sprites'
d_scenes = r'c:\Users\86130\CodeBuddy\20260605221757\tecent-hackathon\game2\scenes\rooms'

# Map from kitchen.tscn ext_resource ids to expected UIDs
kitchen_expected = {
    '3': 'uid://c3dy8g67sxl5f', '4': 'uid://df0g2cw4131ws', '5': 'uid://cf2nv2e2omrlh',
    '6': 'uid://d2mnclkf3p2rl', '7': 'uid://bpl2kqsjwrqqk', '8': 'uid://dgk4ag6tpocxg',
    '9': 'uid://dph4tto1aq0hk', '10': 'uid://dxwpu48m7wimt', '12': 'uid://cpnjvb8qikvpb',
    '13': 'uid://d3bld2fux8ll0', '14': 'uid://cmk441t4t8rqs', '15': 'uid://b7ti4fhcoj0kk',
    '16': 'uid://v6703mfi44ny', '17': 'uid://dnrlxncm4m4u1'
}

f2import = {
    '3':'炉灶.png.import','4':'冰箱.png.import','5':'kitchen_cabinet.png.import',
    '6':'kitchen_crate.png.import','7':'kitchen_clock.png.import','8':'kitchen_plate.png.import',
    '9':'grandma.png.import','10':'水槽.png.import','12':'白菜竹篮.png.import',
    '13':'厨具架.png.import','14':'厨房柜子.png.import','15':'面粉袋.png.import',
    '16':'炉灶开火.png.import','17':'饺子锅.png.import'
}

print("=== Import UID verification ===")
for eid, fname in f2import.items():
    path = os.path.join(d_sprites, fname)
    if not os.path.exists(path):
        print(f"  id={eid}: IMPORT FILE MISSING!")
        continue
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    m = re.search(r'uid="([^"]+)"', content)
    current_uid = m.group(1) if m else 'NO UID'
    expected = kitchen_expected[eid]
    match = 'MATCH' if current_uid == expected else 'MISMATCH!'
    print(f"  id={eid}: current={current_uid} expected={expected} -> {match}")

# Check if kitchen.tscn scene UID was regenerated
print("\n=== Scene UID check ===")
kitchen_path = os.path.join(d_scenes, 'kitchen.tscn')
with open(kitchen_path, 'r', encoding='utf-8') as f:
    first_line = f.readline().strip()
print(f"  kitchen.tscn line1: {first_line}")

# Check for .uid file
uid_path = os.path.join(d_scenes, 'kitchen.tscn.uid')
if os.path.exists(uid_path):
    with open(uid_path, 'r', encoding='utf-8') as f:
        print(f"  .uid file exists: {f.read().strip()}")
else:
    print("  NO .uid file")

# Check room_2026_kitchen as working reference
r26_path = os.path.join(d_scenes, 'room_2026_kitchen.tscn')
with open(r26_path, 'r', encoding='utf-8') as f:
    r26_line1 = f.readline().strip()
print(f"  room_2026_kitchen.tscn line1: {r26_line1}")

# Also check: does .godot/imported have .ctex files for kitchen textures?
print("\n=== .godot/imported .ctex files ===")
imported = r'c:\Users\86130\CodeBuddy\20260605221757\tecent-hackathon\game2\.godot\imported'
if os.path.exists(imported):
    ctex_count = len([f for f in os.listdir(imported) if f.endswith('.ctex')])
    print(f"  Total .ctex files: {ctex_count}")
    # Try to find kitchen-related ones by md5
    for fname in ['炉灶.png','冰箱.png']:
        png_path = os.path.join(d_sprites, fname)
        if os.path.exists(png_path):
            import hashlib
            with open(png_path, 'rb') as fi:
                md5 = hashlib.md5(fi.read()).hexdigest()
            expected_ctex = f'{md5}.ctex'
            found = [f for f in os.listdir(imported) if f.endswith(expected_ctex)]
            print(f"  {fname}: md5={md5}, .ctex found={len(found)>0}")

#!/usr/bin/env python3
"""Generate procedural textures for the game."""
from PIL import Image, ImageDraw, ImageFilter
import math
import random
import os

OUTPUT = os.path.dirname(__file__).replace("scripts", "textures")
os.makedirs(OUTPUT, exist_ok=True)

def wood(w, h, name, base_color=(180, 140, 100), dark_color=(120, 80, 40), rings=12):
    """Generate a wood-grain texture."""
    img = Image.new("RGB", (w, h), base_color)
    draw = ImageDraw.Draw(img)

    # Vertical grain lines
    for y in range(h):
        r = random.random()
        if r < 0.3:
            # Grain line
            shade = int(30 * random.random())
            for x in range(w):
                nx = x + math.sin(y * 0.3) * 3 + math.sin(y * 0.7) * 2
                px = int(nx) % w
                c = max(0, min(255, base_color[0] - shade + int(random.random() * 10)))
                if random.random() < 0.15:
                    img.putpixel((px, y), (c, int(c * 0.65), int(c * 0.4)))

    # Horizontal rings
    for i in range(rings):
        y_center = random.randint(0, h)
        thickness = random.randint(2, 6)
        r_dark = dark_color[0] + random.randint(-15, 15)
        r_g = dark_color[1] + random.randint(-10, 10)
        r_b = dark_color[2] + random.randint(-8, 8)
        for dy in range(-thickness, thickness + 1):
            y = y_center + dy
            if 0 <= y < h:
                alpha = 1.0 - abs(dy) / (thickness + 1)
                for x in range(w):
                    if random.random() < 0.6 * alpha:
                        orig = img.getpixel((x, y))
                        blend = (
                            int(orig[0] * (1 - alpha * 0.4) + r_dark * alpha * 0.4),
                            int(orig[1] * (1 - alpha * 0.4) + r_g * alpha * 0.4),
                            int(orig[2] * (1 - alpha * 0.4) + r_b * alpha * 0.4),
                        )
                        img.putpixel((x, y), blend)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.7))
    img.save(os.path.join(OUTPUT, f"{name}.png"))
    print(f"  Generated {name}.png ({w}x{h})")

def metal(w, h, name, base=(160, 160, 165)):
    """Generate a brushed metal texture."""
    img = Image.new("RGB", (w, h), base)
    for y in range(h):
        shade = int(20 * math.sin(y * 0.1) + 15 * random.random())
        c = max(0, min(255, base[0] + shade))
        for x in range(w):
            if random.random() < 0.3:
                img.putpixel((x, y), (c, c, c + int(shade * 0.3)))

    img = img.filter(ImageFilter.GaussianBlur(radius=0.3))
    img.save(os.path.join(OUTPUT, f"{name}.png"))
    print(f"  Generated {name}.png ({w}x{h})")

def dark_plastic(w, h, name, base=(30, 32, 38)):
    """Dark plastic with subtle noise."""
    img = Image.new("RGB", (w, h), base)
    for y in range(h):
        for x in range(w):
            n = int(8 * random.random())
            c = max(0, min(255, base[0] + n))
            img.putpixel((x, y), (c, c + int(n * 0.5), c + int(n * 0.8)))
    img = img.filter(ImageFilter.GaussianBlur(radius=0.5))
    img.save(os.path.join(OUTPUT, f"{name}.png"))
    print(f"  Generated {name}.png ({w}x{h})")

def paper(w, h, name, base=(245, 238, 215)):
    """Aged paper texture."""
    img = Image.new("RGB", (w, h), base)
    for y in range(h):
        for x in range(w):
            n = int(15 * random.random() - 5)
            img.putpixel((x, y), (
                max(0, min(255, base[0] + n)),
                max(0, min(255, base[1] + n)),
                max(0, min(255, base[2] + n - 3)),
            ))
    # Add some stains
    for _ in range(20):
        sx = random.randint(0, w - 1)
        sy = random.randint(0, h - 1)
        sr = random.randint(3, 15)
        for dy in range(-sr, sr + 1):
            for dx in range(-sr, sr + 1):
                if dx * dx + dy * dy <= sr * sr and random.random() < 0.3:
                    px, py = sx + dx, sy + dy
                    if 0 <= px < w and 0 <= py < h:
                        orig = img.getpixel((px, py))
                        img.putpixel((px, py), (
                            max(0, orig[0] - 15),
                            max(0, orig[1] - 12),
                            max(0, orig[2] - 8),
                        ))
    img = img.filter(ImageFilter.GaussianBlur(radius=0.5))
    img.save(os.path.join(OUTPUT, f"{name}.png"))
    print(f"  Generated {name}.png ({w}x{h})")

def tv_screen(w, h, name):
    """Dark TV screen with subtle reflection."""
    img = Image.new("RGB", (w, h), (15, 18, 22))
    # Subtle gradient
    for y in range(h):
        brightness = 0.08 * (1 - y / h) + 0.02
        for x in range(w):
            c = int(20 * brightness + 5 * random.random())
            img.putpixel((x, y), (c, c + 2, c + 4))

    # Screen reflection line
    for x in range(int(w * 0.2), int(w * 0.8)):
        y = int(h * 0.3 + math.sin(x * 0.05) * h * 0.15)
        for dy in range(-2, 3):
            py = y + dy
            if 0 <= py < h:
                orig = img.getpixel((x, py))
                boost = int(30 * (1 - abs(dy) / 3))
                img.putpixel((x, py), (
                    min(255, orig[0] + boost),
                    min(255, orig[1] + boost),
                    min(255, orig[2] + boost + 5),
                ))

    img.save(os.path.join(OUTPUT, f"{name}.png"))
    print(f"  Generated {name}.png ({w}x{h})")

def wall_paper(w, h, name, base=(200, 190, 170)):
    """Slightly textured wall."""
    img = Image.new("RGB", (w, h), base)
    for y in range(h):
        for x in range(w):
            n = int(10 * random.random() - 3)
            img.putpixel((x, y), (
                max(0, min(255, base[0] + n)),
                max(0, min(255, base[1] + n - 2)),
                max(0, min(255, base[2] + n - 5)),
            ))
    img = img.filter(ImageFilter.GaussianBlur(radius=0.8))
    img.save(os.path.join(OUTPUT, f"{name}.png"))
    print(f"  Generated {name}.png ({w}x{h})")

def fabric(w, h, name, base=(160, 50, 40)):
    """Fabric-like texture for phone etc."""
    img = Image.new("RGB", (w, h), base)
    for y in range(h):
        for x in range(w):
            n = int(18 * random.random() - 6)
            weave = 5 if (x + y) % 3 == 0 else 0
            img.putpixel((x, y), (
                max(0, min(255, base[0] + n + weave)),
                max(0, min(255, base[1] + int(n * 0.3))),
                max(0, min(255, base[2] + int(n * 0.2))),
            ))
    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    img.save(os.path.join(OUTPUT, f"{name}.png"))
    print(f"  Generated {name}.png ({w}x{h})")


def _get_lum(pixels, x, y, w, h):
    if x < 0 or x >= w or y < 0 or y >= h:
        return 128
    return pixels[x, y]


def generate_normal_map(albedo_path: str, out_path: str, strength: float = 1.2):
    """Generate a tangent-space normal map from an albedo texture using Sobel operator."""
    img = Image.open(albedo_path).convert("L")
    w, h = img.size
    pixels = img.load()

    normal = Image.new("RGB", (w, h), (128, 128, 255))
    npixels = normal.load()

    for y in range(h):
        for x in range(w):
            # Sobel operators
            tl = _get_lum(pixels, x-1, y-1, w, h)
            tc = _get_lum(pixels, x,   y-1, w, h)
            tr = _get_lum(pixels, x+1, y-1, w, h)
            ml = _get_lum(pixels, x-1, y,   w, h)
            mr = _get_lum(pixels, x+1, y,   w, h)
            bl = _get_lum(pixels, x-1, y+1, w, h)
            bc = _get_lum(pixels, x,   y+1, w, h)
            br = _get_lum(pixels, x+1, y+1, w, h)

            gx = (-tl + tr - 2*ml + 2*mr - bl + br) * strength * 0.3
            gy = (-tl - 2*tc - tr + bl + 2*bc + br) * strength * 0.3

            # Convert gradient to normal (tangent space, Z-up)
            nx = 128.0 + gx
            ny = 128.0 + gy
            nz = 255.0

            length = math.sqrt((nx - 128)**2 + (ny - 128)**2 + 255**2)
            nx = int(128.0 + (nx - 128) / length * 127)
            ny = int(128.0 + (ny - 128) / length * 127)

            npixels[x, y] = (
                max(0, min(255, nx)),
                max(0, min(255, ny)),
                255,
            )

    normal.save(out_path)
    print(f"  Generated {os.path.basename(out_path)} ({w}x{h})")


def generate_roughness_map(albedo_path: str, out_path: str):
    """Generate a roughness map from albedo luminance. Darker = rougher."""
    img = Image.open(albedo_path).convert("L")
    w, h = img.size
    pixels = img.load()

    rough = Image.new("L", (w, h))
    rpixels = rough.load()

    for y in range(h):
        for x in range(w):
            lum = pixels[x, y]
            # Invert: bright areas = smooth, dark areas = rough
            r = (255 - lum) / 255.0
            # Add some variation from neighboring pixels for micro-detail
            noise = random.uniform(-0.05, 0.05)
            r = max(0.0, min(1.0, r + noise))
            rpixels[x, y] = int(r * 255)

    rough.save(out_path)
    print(f"  Generated {os.path.basename(out_path)} ({w}x{h})")

if __name__ == "__main__":
    print(f"Generating textures in {OUTPUT}...")
    S = 256  # texture size

    wood(S, S, "wood_dark", (100, 65, 35), (70, 40, 20))
    wood(S, S, "wood_medium", (160, 120, 70), (110, 70, 35))
    wood(S, S, "wood_light", (195, 160, 100), (140, 100, 50))
    metal(S, S, "metal_gray", (155, 158, 165))
    metal(S, S, "metal_gold", (200, 170, 60))
    dark_plastic(S, S, "plastic_dark", (28, 30, 36))
    dark_plastic(S, S, "plastic_tv", (55, 58, 65))
    paper(S, S, "paper_aged", (242, 235, 210))
    paper(S, S, "paper_white", (252, 250, 240))
    tv_screen(S, S, "tv_screen")
    wall_paper(S, S, "wall_beige", (200, 190, 170))
    fabric(S, S, "fabric_red", (170, 45, 35))

    print(f"Done! {len(os.listdir(OUTPUT))} textures generated.")

    # Generate PBR maps from existing albedo textures
    print(f"\nGenerating PBR maps (normal + roughness)...")
    for tex_file in sorted(os.listdir(OUTPUT)):
        fn = os.path.basename(tex_file)
        if fn.endswith(".png") and "_normal" not in fn and "_roughness" not in fn:
            base = fn[:-4]
            albedo = os.path.join(OUTPUT, fn)
            normal_out = os.path.join(OUTPUT, f"{base}_normal.png")
            rough_out = os.path.join(OUTPUT, f"{base}_roughness.png")
            generate_normal_map(albedo, normal_out)
            generate_roughness_map(albedo, rough_out)

    print(f"Done! {len(os.listdir(OUTPUT))} total files in {OUTPUT}.")

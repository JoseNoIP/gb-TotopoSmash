#!/usr/bin/env python3
"""Download AI backgrounds from Pollinations.ai and generate improved sprites.

Run from project root:
    /tmp/gb_venv/bin/python3 tools/fetch_ai_assets.py

Requires Pillow: /tmp/gb_venv/bin/pip install Pillow
"""
import io
import os
import sys
import time
import urllib.request
import urllib.parse

try:
    from PIL import Image
except ImportError:
    print("ERROR: Run with /tmp/gb_venv/bin/python3")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def fetch_image(prompt: str, width: int, height: int, seed: int,
                retries: int = 3) -> Image.Image | None:
    enc = urllib.parse.quote(prompt)
    url = (f"https://image.pollinations.ai/prompt/{enc}"
           f"?width={width}&height={height}&nologo=true&model=flux&seed={seed}")
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "GuacBlaster/1.0"})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            if data[:2] in (b'\xff\xd8', b'\x89PN'):
                img = Image.open(io.BytesIO(data))
                return img.convert("RGBA")
            else:
                msg = data[:80].decode("utf-8", errors="replace")
                print(f"  [attempt {attempt+1}] Bad response: {msg[:60]}")
                time.sleep(5)
        except Exception as e:
            print(f"  [attempt {attempt+1}] Error: {e}")
            time.sleep(5)
    return None


def save_img(img: Image.Image, path: str, size: tuple[int,int] | None = None) -> None:
    if size:
        img = img.resize(size, Image.LANCZOS)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    img.save(path, "PNG")
    print(f"  ✓ {path} ({img.width}×{img.height})")


def chroma_key(img: Image.Image, bg_color=(255,255,255), tolerance=30) -> Image.Image:
    """Remove near-white background to create transparency."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            dist = ((r-bg_color[0])**2 + (g-bg_color[1])**2 + (b-bg_color[2])**2)**0.5
            if dist < tolerance:
                px[x, y] = (r, g, b, 0)
    return img


# ---------------------------------------------------------------------------
# Background prompts  (5 biomes × 3 variants)
# ---------------------------------------------------------------------------

BIOME_PROMPTS = [
    # Biome 0: Sunny Earth meadow (friendly start)
    "sunny green meadow landscape game background portrait, "
    "bright blue sky fluffy white clouds, rolling green hills flowers, "
    "cheerful happy daytime, vibrant colors, mobile game art",

    # Biome 1: Dark jungle night
    "dark tropical jungle night game background portrait 390x844 pixels, "
    "dense dark green foliage palm trees, glowing fireflies, crescent moon, "
    "atmospheric moody, dark green tones, mobile game art",

    # Biome 2: Twilight indigo city
    "twilight indigo purple night sky cityscape game background portrait, "
    "mystical stars nebula glowing, urban silhouette, deep purple tones, "
    "atmospheric moody mobile game art",

    # Biome 3: Volcanic ember
    "volcanic lava landscape game background portrait, glowing lava rivers, "
    "molten rock dark red orange embers, volcano peak, dark inferno tones, "
    "atmospheric dramatic mobile game art",

    # Biome 4: Deep ocean abyss
    "deep ocean abyss underwater game background portrait, bioluminescent "
    "jellyfish creatures, dark blue tones, abyssal depth, glowing particles, "
    "atmospheric mobile game art",

    # Biome 5: Blood moon desert (final world)
    "blood moon red night desert game background portrait, dramatic crimson sky, "
    "dark sand dunes silhouette, dead trees, gothic dark red tones, "
    "atmospheric moody mobile game art",
]

VARIANT_SEEDS = [
    [500, 501, 502],  # biome 0 — sunny Earth
    [7, 44, 81],      # biome 1 — dark jungle
    [107, 144, 181],  # biome 2 — twilight city
    [207, 244, 281],  # biome 3 — volcanic
    [307, 344, 381],  # biome 4 — ocean abyss
    [407, 444, 481],  # biome 5 — blood moon
]

# ---------------------------------------------------------------------------
# Sprite prompts  (requested at 512×512, resized to game size)
# ---------------------------------------------------------------------------

SPRITE_SPECS = [
    {
        "path": "assets/sprites/player.png",
        "size": (64, 64),
        "prompt": ("pixel art green avocado spaceship top-down view, "
                   "triangular body green color, blue cockpit window, "
                   "orange engine glow, white background, "
                   "game sprite 2D isolated, clean"),
        "seed": 1001,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/enemy_basic.png",
        "size": (56, 56),
        "prompt": ("pixel art small red bubble enemy game sprite, "
                   "angry face eyes, round red bubble character, "
                   "white background, isolated 2D game asset"),
        "seed": 1002,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/enemy_tank.png",
        "size": (84, 84),
        "prompt": ("pixel art large dark red armored bubble enemy game sprite, "
                   "heavy armor plates, mean eyes, tough boss minion, "
                   "white background, isolated 2D game asset"),
        "seed": 1003,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/enemy_zigzag.png",
        "size": (112, 112),
        "prompt": ("pixel art orange nacho fly wasp enemy game sprite, "
                   "diamond body translucent wings, fast flying insect, "
                   "white background, isolated 2D game asset"),
        "seed": 1004,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/enemy_elite.png",
        "size": (56, 56),
        "prompt": ("pixel art gold elite bubble enemy game sprite, "
                   "golden crown spikes on top, shiny gold color, "
                   "white background, isolated 2D game asset"),
        "seed": 1005,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/enemy_boss.png",
        "size": (144, 144),
        "prompt": ("pixel art large purple demon boss face game sprite, "
                   "glowing red eyes, curved horns, wide evil grin teeth, "
                   "scary villain, white background, isolated 2D game asset"),
        "seed": 1006,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/projectile.png",
        "size": (28, 28),
        "prompt": ("pixel art small green guacamole bullet projectile game sprite, "
                   "glowing yellow-green teardrop shape, white background, "
                   "isolated 2D game asset"),
        "seed": 1007,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/gem.png",
        "size": (36, 36),
        "prompt": ("pixel art cyan blue XP diamond gem game sprite, "
                   "faceted crystal diamond shape, glowing, "
                   "white background, isolated 2D game asset"),
        "seed": 1008,
        "bg_remove": True,
    },
    {
        "path": "assets/sprites/heart.png",
        "size": (52, 52),
        "prompt": ("pixel art red heart life icon game sprite, "
                   "classic heart shape bright red, highlight shine, "
                   "white background, isolated 2D game asset"),
        "seed": 1009,
        "bg_remove": True,
    },
]

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("\n=== AI Background Download (sequential) ===")
    for biome_idx, prompt in enumerate(BIOME_PROMPTS):
        for variant, seed in enumerate(VARIANT_SEEDS[biome_idx]):
            path = f"assets/sprites/backgrounds/bg_{biome_idx}_{variant}.png"
            print(f"\n[{biome_idx},{variant}] seed={seed}")
            img = fetch_image(prompt, 390, 844, seed)
            if img:
                save_img(img, path)
            else:
                print(f"  ✗ FAILED — keeping procedural {path}")
            time.sleep(3)

    print("\n=== AI Sprite Download (sequential) ===")
    for spec in SPRITE_SPECS:
        print(f"\n{spec['path']}")
        img = fetch_image(spec["prompt"], 512, 512, spec["seed"])
        if img:
            if spec.get("bg_remove"):
                img = chroma_key(img, bg_color=(255, 255, 255), tolerance=40)
            save_img(img, spec["path"], size=spec["size"])
        else:
            print(f"  ✗ FAILED — keeping existing sprite")
        time.sleep(3)

    print("\nDone.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Download the menu background for Totopo Smash from Pollinations.ai.

Run from project root:
    /tmp/gb_venv/bin/python3 tools/fetch_ai_assets.py

Requires Pillow: /tmp/gb_venv/bin/pip install Pillow

Solo el fondo de menú usa IA (390×844, >=128px por el lado). Todo lo demás en este
juego (bloques, molcajete, semilla, íconos — todos <=96px) es procedural en
gen_assets.py: a esos tamaños la IA sale borrosa/ruidosa y no comunica la mecánica
con claridad (ver /gen-ai-art paso 4).
"""
import io
import sys
import time
import urllib.request
import urllib.parse

try:
    from PIL import Image
except ImportError:
    print("ERROR: Run with /tmp/gb_venv/bin/python3 (necesita Pillow)")
    sys.exit(1)

MENU_BG_PATH = "assets/sprites/backgrounds/menu_bg.png"
MENU_BG_PROMPT = (
    "dark moody kitchen counter at night with a stone molcajete mortar and "
    "scattered golden tortilla chips, mobile game menu background portrait, "
    "dark navy blue slate tones, clean vector art toony style, atmospheric, "
    "soft rim lighting, no text, no people"
)
MENU_BG_SEED = 4077


def fetch_image(prompt: str, width: int, height: int, seed: int, retries: int = 3):
    enc = urllib.parse.quote(prompt)
    url = (
        f"https://image.pollinations.ai/prompt/{enc}"
        f"?width={width}&height={height}&nologo=true&model=flux&seed={seed}"
    )
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "TotopoSmash/1.0"})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            if data[:2] in (b"\xff\xd8", b"\x89PN"):
                return Image.open(io.BytesIO(data)).convert("RGBA")
            msg = data[:80].decode("utf-8", errors="replace")
            print(f"  [attempt {attempt + 1}] Bad response: {msg[:60]}")
            time.sleep(5)
        except Exception as e:
            print(f"  [attempt {attempt + 1}] Error: {e}")
            time.sleep(5)
    return None


def main():
    print(f"\n=== Fondo de menú (Pollinations.ai) ===\n{MENU_BG_PATH}")
    img = fetch_image(MENU_BG_PROMPT, 390, 844, MENU_BG_SEED)
    if img is None:
        print("  x FAILED — el menú se queda con el ColorRect plano existente")
        return
    img.save(MENU_BG_PATH, "PNG")
    print(f"  + {MENU_BG_PATH} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Descarga los sprites de Totopo Smash generados con IA (Pollinations.ai).

Uso (desde la raíz del proyecto):
    /tmp/gb_venv/bin/python3 tools/fetch_ai_assets.py

Requiere Pillow: /tmp/gb_venv/bin/pip install Pillow

Historial de la decisión "IA vs procedural" para sprites chicos (≤96px): una sesión
anterior asumió que a esos tamaños la IA sale borrosa/ruidosa y dejó TODO (bloques,
molcajete, semilla, íconos) en procedural (`gen_assets.py`). Pedido explícito del usuario
("pulir sprites existentes con IA") llevó a probar la técnica real recomendada por el
skill /gen-ai-art — pedir la imagen a 512×512 y reducirla con `Image.LANCZOS` al tamaño
final — y el resultado SÍ es nítido y legible incluso a 64×64/96×96. La suposición
anterior era demasiado conservadora; se corrige acá con evidencia real (ver capturas
verificadas en idea-base.md).

Qué quedó en IA vs procedural, y por qué:
- Fondo de menú (390×844) — IA, sin cambios de esta ronda.
- Bloques totopo/queso (64×64) — IA, CON cara/personaje (pedido explícito: "personajes
  tiernos con cara en los bloques de comida").
- Bloques salsa/piedra (64×64) y molcajete (96×96) — IA, SIN cara (objetos con textura).
- Semilla (16×16) — SIGUE PROCEDURAL. Se intentó con IA (prompt pidiendo explícitamente
  "no face, no character") y aun así devolvió una calabaza completa con cara — Flux no
  respetó la instrucción para este objeto/tamaño. A 16px además no se distinguía del
  círculo procedural ya existente. No vale la pena seguir intentando para un sprite tan
  chico — ver `gen_assets.py::make_seed_sprite()`.
- Bloque triángulo — sin sprite propio a propósito (dibuja un `Polygon2D` de color plano
  en `triangle_block.gd`, es una variante geométrica del totopo, no necesita textura).

Reglas del skill /gen-ai-art aplicadas: descargas SECUENCIALES (nunca en paralelo, el tier
gratuito solo permite 1 en cola), `sleep(3)` entre cada una, seeds documentados abajo para
reproducibilidad exacta, chroma key sobre fondo blanco para la transparencia.
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

# --- Sprites chicos: se piden a 512x512 (calidad IA) y se reducen con LANCZOS al tamaño
# real de juego — la clave que hace que SÍ se vean nítidos, a diferencia de pedirlos ya al
# tamaño final (borroso/ruidoso, la suposición original que motivó dejarlos procedurales).
SPRITES = [
    {
        "path": "assets/sprites/blocks/totopo.png",
        "prompt": (
            "cute cartoon golden tortilla chip corn totopo game block, toony vector art "
            "style, thick black outline, flat colors, salt specks, triangular shape, "
            "happy kawaii face with eyes and smile, white background, isolated 2D game "
            "asset, centered"
        ),
        "seed": 91001,
        "size": 64,
    },
    {
        "path": "assets/sprites/blocks/queso.png",
        "prompt": (
            "cute cartoon yellow cheese wedge game character with holes, toony vector art "
            "style, thick black outline, flat colors, happy kawaii face with eyes and "
            "smile, white background, isolated 2D game asset, centered"
        ),
        "seed": 91010,
        "size": 64,
    },
    {
        "path": "assets/sprites/blocks/salsa.png",
        "prompt": (
            "cute cartoon glass jar of red spicy salsa sauce, toony vector art style, "
            "thick black outline, flat colors, jar with lid and label, no face, no "
            "character, white background, isolated 2D game asset, centered"
        ),
        "seed": 91011,
        "size": 64,
    },
    {
        "path": "assets/sprites/blocks/stone.png",
        "prompt": (
            "cute cartoon gray volcanic stone rock game block, toony vector art style, "
            "thick black outline, flat colors, rough cracked rock texture, no face, no "
            "character, white background, isolated 2D game asset, centered"
        ),
        "seed": 91012,
        "size": 64,
    },
    {
        "path": "assets/sprites/molcajete.png",
        "prompt": (
            "flat 2D icon of a mexican molcajete mortar bowl seen directly from above, "
            "top-down orthographic view, circular dark volcanic stone bowl, toony vector "
            "game icon style, thick black outline, flat colors, no perspective, no "
            "shading depth, white background, isolated 2D game asset, centered"
        ),
        "seed": 91005,
        "size": 96,
    },
]


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


def chroma_key(img: Image.Image, bg_color=(255, 255, 255), tolerance=40) -> Image.Image:
    """Remueve el fondo blanco pedido en el prompt para dejar transparencia real."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            dist = ((r - bg_color[0]) ** 2 + (g - bg_color[1]) ** 2 + (b - bg_color[2]) ** 2) ** 0.5
            if dist < tolerance:
                px[x, y] = (r, g, b, 0)
    return img


def main():
    print(f"\n=== Fondo de menú (Pollinations.ai) ===\n{MENU_BG_PATH}")
    img = fetch_image(MENU_BG_PROMPT, 390, 844, MENU_BG_SEED)
    if img is None:
        print("  x FAILED — el menú se queda con el ColorRect plano existente")
    else:
        img.save(MENU_BG_PATH, "PNG")
        print(f"  + {MENU_BG_PATH} ({img.width}x{img.height})")
    time.sleep(3)

    print("\n=== Sprites (512x512 -> LANCZOS al tamaño real) ===")
    for spec in SPRITES:
        print(f"  {spec['path']}")
        img = fetch_image(spec["prompt"], 512, 512, spec["seed"])
        if img is None:
            print(f"    x FAILED — se conserva el sprite anterior en {spec['path']}")
            time.sleep(3)
            continue
        keyed = chroma_key(img)
        small = keyed.resize((spec["size"], spec["size"]), Image.LANCZOS)
        small.save(spec["path"], "PNG")
        print(f"    + guardado ({spec['size']}x{spec['size']})")
        time.sleep(3)


if __name__ == "__main__":
    main()

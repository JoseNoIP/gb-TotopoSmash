#!/usr/bin/env python3
"""Generate placeholder pixel-art sprites and SFX WAVs for Totopo Smash.
Run from project root:  python3 tools/gen_assets.py
Requires only Python 3 stdlib — no PIL, no external packages.

Rule CLAUDE.md #36: NUNCA correr este archivo completo para regenerar un solo asset —
sobreescribe todo. Para un ícono/sonido suelto, importar solo la función necesaria:
  python3 -c "import sys; sys.path.insert(0,'tools'); from gen_assets import make_queso_block, save_png; save_png('ruta.png', 64, 64, make_queso_block(64))"
"""
import math
import os
import random
import struct
import wave
import zlib

# ---------------------------------------------------------------------------
# PNG helpers
# ---------------------------------------------------------------------------


def _chunk(tag: bytes, data: bytes) -> bytes:
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)


def save_png(path: str, w: int, h: int, pixels: list) -> None:
    """pixels: flat list of (r,g,b,a) tuples, row-major."""
    raw = bytearray()
    for row in range(h):
        raw.append(0)  # filter=None
        for col in range(w):
            raw.extend(pixels[row * w + col])
    content = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as f:
        f.write(content)
    print(f"  + {path}")


# ---------------------------------------------------------------------------
# Drawing primitives
# ---------------------------------------------------------------------------

T = (0, 0, 0, 0)  # transparent
BLK = (12, 12, 12, 255)  # outline black
WHT = (255, 255, 255, 255)


def _grid(w, h, fill=T):
    return [[list(fill)] * w for _ in range(h)]


def _flat(g):
    return [tuple(c) for row in g for c in row]


def _set(g, x, y, c):
    if 0 <= x < len(g[0]) and 0 <= y < len(g):
        g[y][x] = list(c)


def _circle(g, cx, cy, r, c):
    for y in range(max(0, int(cy - r) - 1), min(len(g), int(cy + r) + 2)):
        for x in range(max(0, int(cx - r) - 1), min(len(g[0]), int(cx + r) + 2)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                _set(g, x, y, c)


def _outline_circle(g, cx, cy, r, oc):
    r2 = (r + 1.4) ** 2
    for y in range(max(0, int(cy - r) - 2), min(len(g), int(cy + r) + 3)):
        for x in range(max(0, int(cx - r) - 2), min(len(g[0]), int(cx + r) + 3)):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if r * r < d2 <= r2 and tuple(g[y][x]) == T:
                _set(g, x, y, oc)


def _rect(g, x1, y1, x2, y2, c):
    for y in range(max(0, y1), min(len(g), y2 + 1)):
        for x in range(max(0, x1), min(len(g[0]), x2 + 1)):
            _set(g, x, y, c)


def _hline(g, y, x1, x2, c):
    for x in range(x1, x2 + 1):
        _set(g, x, y, c)


def _vline(g, x, y1, y2, c):
    for y in range(y1, y2 + 1):
        _set(g, x, y, c)


def _rounded_rect(g, x1, y1, x2, y2, r, c):
    """Filled rectangle with rounded corners (r = corner radius in pixels)."""
    _rect(g, x1 + r, y1, x2 - r, y2, c)
    _rect(g, x1, y1 + r, x2, y2 - r, c)
    _circle(g, x1 + r, y1 + r, r, c)
    _circle(g, x2 - r, y1 + r, r, c)
    _circle(g, x1 + r, y2 - r, r, c)
    _circle(g, x2 - r, y2 - r, r, c)


def _poly(g, pts, c):
    """Fill a polygon using scanline."""
    if not pts:
        return
    min_y = max(0, min(p[1] for p in pts))
    max_y = min(len(g) - 1, max(p[1] for p in pts))
    for y in range(min_y, max_y + 1):
        xs = []
        n = len(pts)
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            if y1 == y2:
                continue
            if min(y1, y2) <= y < max(y1, y2):
                t = (y - y1) / (y2 - y1)
                xs.append(x1 + t * (x2 - x1))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            for x in range(int(xs[i]) + 1, int(xs[i + 1]) + 1):
                _set(g, x, y, c)


# ---------------------------------------------------------------------------
# Pixel font (5×7) — uppercase A-Z subset used in studio logo
# ---------------------------------------------------------------------------

_PIXEL_FONT = {
    'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    'B': ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    'C': ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    'E': ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    'G': ["01110", "10000", "10000", "10011", "10001", "10001", "01110"],
    'I': ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    'M': ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
    'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    'T': ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    ' ': ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


def _text_width(text, scale):
    """Pixel width of rendered text at given scale."""
    if not text:
        return 0
    return scale * (6 * len(text) - 1)  # 5 px char + 1 px gap, no trailing gap


def _draw_text(g, text, x, y, scale, color, shadow=None):
    """Render text using 5×7 pixel font. Unknown chars are treated as space."""
    cursor = x
    for ch in text.upper():
        glyph = _PIXEL_FONT.get(ch, _PIXEL_FONT[' '])
        for ri, row in enumerate(glyph):
            for ci, px in enumerate(row):
                if px == '1':
                    rx, ry = cursor + ci * scale, y + ri * scale
                    if shadow:
                        _rect(g, rx + 1, ry + 1, rx + scale, ry + scale, shadow)
                    _rect(g, rx, ry, rx + scale - 1, ry + scale - 1, color)
        cursor += 6 * scale


# ---------------------------------------------------------------------------
# Studio logo helpers
# ---------------------------------------------------------------------------

def _draw_avocado(g, cx, cy, r):
    """Pixel-art avocado: dark shell, yellow-green flesh, brown seed."""
    SHELL    = (28,  78,  18, 255)
    SHELL_HI = (50, 118,  30, 255)
    FLESH    = (178, 215, 74, 255)
    FLESH_LO = (142, 172, 52, 255)
    SEED     = (112,  52,  10, 255)
    SEED_HI  = (155,  85,  28, 255)
    SHINE    = (222, 248, 132, 255)

    _circle(g, cx, cy, r, SHELL)
    _circle(g, cx, cy - r // 6, int(r * 0.82), SHELL)

    _circle(g, cx - int(r * 0.35), cy - int(r * 0.38), int(r * 0.14), SHELL_HI)

    fy = cy - int(r * 0.08)
    _circle(g, cx, fy, int(r * 0.68), FLESH)
    _circle(g, cx, fy + int(r * 0.18), int(r * 0.54), FLESH_LO)
    _circle(g, cx - int(r * 0.22), fy - int(r * 0.32), int(r * 0.14), SHINE)

    sy = cy + int(r * 0.12)
    _circle(g, cx, sy, int(r * 0.24), SEED)
    _circle(g, cx - int(r * 0.09), sy - int(r * 0.09), int(r * 0.11), SEED_HI)


def make_splash(w=512, h=512):
    """Guacamole Bit studio boot splash. Dark green field + avocado logo + pixel text."""
    BG      = (8,  13,  8, 255)
    BG_GRID = (11, 18, 11, 255)
    GREEN   = (68, 200, 40, 255)
    BRIGHT  = (120, 235, 80, 255)
    SHADOW  = (4,   8,  4, 255)
    DOT     = (55, 140, 30, 255)

    g = _grid(w, h, BG)

    for y in range(0, h, 32):
        for x in range(w):
            _set(g, x, y, BG_GRID)
    for x in range(0, w, 32):
        for y in range(h):
            if tuple(g[y][x]) == BG:
                _set(g, x, y, BG_GRID)

    # "GUACAMOLE" — scale 6
    s1 = 6
    t1 = "GUACAMOLE"
    tx1 = (w - _text_width(t1, s1)) // 2
    _draw_text(g, t1, tx1, 62, s1, GREEN, SHADOW)

    # Decorative dots above avocado
    for i in range(5):
        _circle(g, w // 2 - 32 + i * 16, 142, 3, DOT)

    # Avocado — centered
    _draw_avocado(g, w // 2, 248, 90)

    # Decorative dots below avocado
    for i in range(5):
        _circle(g, w // 2 - 32 + i * 16, 355, 3, DOT)

    # "BIT" — scale 9
    s2 = 9
    t2 = "BIT"
    tx2 = (w - _text_width(t2, s2)) // 2
    _draw_text(g, t2, tx2, 382, s2, BRIGHT, SHADOW)

    return _flat(g)


def make_totopo_icon(size=512):
    """Totopo Smash app icon — toasted tortilla chip triangle with a bite, on
    the board's dark slate background (Constants.COLOR_BG_BOARD)."""
    BG = (22, 27, 37, 255)
    CHIP = (249, 169, 40, 255)  # Constants.COLOR_TOTOPO
    SPECK = (140, 78, 16, 255)

    g = _grid(size, size, BG)

    m = int(size * 0.14)
    top = (size // 2, m)
    bl = (m, size - m)
    br = (size - m, size - m)
    _poly(g, [top, bl, br], CHIP)

    rnd = random.Random(1101)
    for _ in range(int(size * size * 0.0006)):
        y = rnd.randint(top[1], bl[1])
        t = (y - top[1]) / max(1, (bl[1] - top[1]))
        left_x = top[0] + t * (bl[0] - top[0])
        right_x = top[0] + t * (br[0] - top[0])
        x = rnd.randint(int(left_x), int(right_x))
        _circle(g, x, y, max(1, size // 170), SPECK)

    bite_r = int(size * 0.22)
    _circle(g, br[0] - int(size * 0.06), br[1] - int(size * 0.08), bite_r, BG)

    return _flat(g)


# ---------------------------------------------------------------------------
# Gameplay sprites (GDD sección 3 — colores desde Constants.gd)
# ---------------------------------------------------------------------------

def make_totopo_block(size=64):
    """Bloque Totopo — tostada cuadrada crujiente (Constants.COLOR_TOTOPO)."""
    CHIP = (249, 169, 40, 255)
    SPECK = (140, 78, 16, 255)
    g = _grid(size, size, T)
    m = int(size * 0.05)
    r = int(size * 0.14)
    _rounded_rect(g, m, m, size - 1 - m, size - 1 - m, r, CHIP)
    rnd = random.Random(2202)
    for _ in range(int(size * size * 0.0009)):
        x = rnd.randint(m + r // 2, size - m - r // 2)
        y = rnd.randint(m + r // 2, size - m - r // 2)
        _circle(g, x, y, max(1, size // 220), SPECK)
    return _flat(g)


def make_queso_block(size=64):
    """Bloque de Queso — pesado y viscoso (Constants.COLOR_QUESO), goteando por abajo."""
    QUESO = (242, 224, 169, 255)
    HI = (255, 245, 220, 255)
    g = _grid(size, size, T)
    m = int(size * 0.05)
    r = int(size * 0.18)
    _rounded_rect(g, m, m, size - 1 - m, size - 1 - m, r, QUESO)
    rnd = random.Random(77)
    drip_y = size - 1 - m
    x = m + r
    while x < size - m - r:
        drip_w = rnd.randint(6, 10)
        drip_h = rnd.randint(3, 7)
        _circle(g, x, drip_y, drip_w // 2, QUESO)
        _rect(g, x - drip_w // 2, drip_y, x + drip_w // 2, drip_y + drip_h, QUESO)
        x += drip_w + rnd.randint(2, 6)
    _circle(g, int(size * 0.32), int(size * 0.32), int(size * 0.15), HI)
    return _flat(g)


def make_salsa_jar(size=64):
    """Frasco de Salsa (Constants.COLOR_SALSA) — vidrio con tapa, explota en cruz."""
    SALSA = (212, 33, 33, 255)
    SALSA_HI = (255, 90, 60, 255)
    LID = (90, 40, 20, 255)
    LID_HI = (130, 70, 40, 255)
    g = _grid(size, size, T)
    jar_w = int(size * 0.62)
    jar_h = int(size * 0.66)
    jx1 = (size - jar_w) // 2
    jx2 = jx1 + jar_w
    jy1 = int(size * 0.3)
    jy2 = jy1 + jar_h
    r = int(size * 0.08)
    _rounded_rect(g, jx1, jy1, jx2, jy2, r, SALSA)
    _rounded_rect(g, jx1 + 3, jy1 + 3, jx2 - 3, jy1 + int(jar_h * 0.35), r, SALSA_HI)
    lid_w = int(jar_w * 0.7)
    lx1 = (size - lid_w) // 2
    lid_top = jy1 - int(size * 0.14)
    _rect(g, lx1, lid_top, lx1 + lid_w, jy1 + 2, LID)
    _rect(g, lx1, lid_top, lx1 + lid_w, lid_top + 3, LID_HI)
    return _flat(g)


def make_stone_block(size=64):
    """Piedra de Molcajete (Constants.COLOR_STONE) — indestructible, textura rugosa."""
    STONE = (107, 107, 115, 255)
    STONE_LO = (78, 78, 86, 255)
    STONE_HI = (140, 140, 148, 255)
    g = _grid(size, size, T)
    m = int(size * 0.05)
    r = int(size * 0.08)
    _rounded_rect(g, m, m, size - 1 - m, size - 1 - m, r, STONE)
    rnd = random.Random(909)
    for _ in range(int(size * size * 0.05)):
        x = rnd.randint(m, size - m - 1)
        y = rnd.randint(m, size - m - 1)
        c = STONE_LO if rnd.random() < 0.5 else STONE_HI
        _set(g, x, y, c)
    return _flat(g)


def make_molcajete(size=96):
    """Molcajete (Constants.COLOR_MOLCAJETE) — cuenco de piedra volcánica, vista superior."""
    OUTER = (89, 61, 41, 255)
    OUTER_HI = (120, 85, 58, 255)
    OUTER_LO = (70, 48, 32, 255)
    INNER = (58, 38, 24, 255)
    g = _grid(size, size, T)
    cx = cy = size // 2
    r = int(size * 0.46)
    _circle(g, cx, cy, r, OUTER)
    _circle(g, cx, cy - r // 8, int(r * 0.86), OUTER_HI)
    _circle(g, cx, cy, int(r * 0.62), INNER)
    rnd = random.Random(55)
    for _ in range(int(size * size * 0.02)):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(r * 0.65, r * 0.95)
        x = int(cx + rr * math.cos(a))
        y = int(cy + rr * math.sin(a))
        _set(g, x, y, OUTER_HI if rnd.random() < 0.5 else OUTER_LO)
    return _flat(g)


def make_seed_sprite(size=16):
    """Semilla en vuelo (Constants.COLOR_SEED_TRAIL)."""
    SEED = (79, 219, 112, 255)
    HI = (255, 255, 255, 200)
    g = _grid(size, size, T)
    cx = cy = size // 2
    r = size * 0.42
    _circle(g, cx, cy, r, SEED)
    _circle(g, cx - r * 0.25, cy - r * 0.25, r * 0.35, HI)
    return _flat(g)


def make_lemon_icon(size=48):
    """Limón Ácido (Constants.COLOR_LEMON) — ícono de poder, duplica la semilla."""
    RIND = (60, 158, 41, 255)
    PULP = (171, 236, 61, 255)
    g = _grid(size, size, T)
    cx = cy = size // 2
    r = int(size * 0.42)
    _circle(g, cx, cy, r, RIND)
    _circle(g, cx, cy, int(r * 0.8), PULP)
    rnd = random.Random(31)
    for _ in range(6):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(r * 0.2, r * 0.55)
        x = int(cx + rr * math.cos(a))
        y = int(cy + rr * math.sin(a))
        _circle(g, x, y, max(1, r // 10), (255, 255, 255, 160))
    _circle(g, cx - int(r * 0.3), cy - int(r * 0.3), int(r * 0.18), (255, 255, 255, 200))
    return _flat(g)


def make_seed_extra_icon(size=48):
    """Semilla Extra +1 (Constants.COLOR_SEED_EXTRA) — ícono de poder, brillante."""
    SEED = (255, 224, 80, 255)
    HI = (255, 255, 255, 220)
    g = _grid(size, size, T)
    cx = cy = size // 2
    r = int(size * 0.34)
    ray = int(r * 0.7)
    _hline(g, cy, cx - r - ray, cx - r - 2, HI)
    _hline(g, cy, cx + r + 2, cx + r + ray, HI)
    _vline(g, cx, cy - r - ray, cy - r - 2, HI)
    _vline(g, cx, cy + r + 2, cy + r + ray, HI)
    _circle(g, cx, cy, r, SEED)
    _circle(g, cx - int(r * 0.3), cy - int(r * 0.3), int(r * 0.3), HI)
    return _flat(g)


def make_laser_icon(size=48, horizontal=True):
    """Láser (Constants.COLOR_LASER) — ícono de poder, dispara en línea recta a toda la
    fila/columna donde está. DOS variantes (horizontal/vertical), nunca una sola imagen
    genérica para ambas: laser_icon.gd la usa para que el jugador vea la orientación real
    ANTES de tocarlo (no es información oculta — ver el comentario de _draw() en ese
    archivo, que este sprite reemplaza sin perder esa distinción)."""
    CORE = (230, 38, 217, 255)  # Constants.COLOR_LASER = Color(0.9, 0.15, 0.85)
    GLOW = (255, 255, 255, 210)
    g = _grid(size, size, T)
    cx = cy = size // 2
    beam_half_len = int(size * 0.44)
    beam_half_w = max(1, int(size * 0.07))
    if horizontal:
        _rect(g, cx - beam_half_len, cy - beam_half_w, cx + beam_half_len, cy + beam_half_w, CORE)
    else:
        _rect(g, cx - beam_half_w, cy - beam_half_len, cx + beam_half_w, cy + beam_half_len, CORE)
    r = int(size * 0.2)
    _circle(g, cx, cy, r, CORE)
    _circle(g, cx, cy, int(r * 0.45), GLOW)
    return _flat(g)


# ---------------------------------------------------------------------------
# Audio synthesis (stdlib `wave`, sin dependencias — sin encoder OGG disponible,
# por eso AudioManager reproduce .wav directamente en vez de .ogg)
# ---------------------------------------------------------------------------

RATE = 44100


def _env(samples, attack=0.005, release=0.08):
    n = len(samples)
    atk = max(1, int(attack * RATE))
    rel = max(1, int(release * RATE))
    return [
        s * min(1.0, i / atk) * min(1.0, (n - i) / rel)
        for i, s in enumerate(samples)
    ]


def _sine(freq, dur, amp=0.45):
    n = int(dur * RATE)
    return [amp * math.sin(2 * math.pi * freq * i / RATE) for i in range(n)]


def _sweep(f0, f1, dur, amp=0.45):
    n = int(dur * RATE)
    return [amp * math.sin(2 * math.pi * (f0 + (f1 - f0) * i / n) * i / RATE) for i in range(n)]


def _noise(dur, amp=0.25):
    n = int(dur * RATE)
    return [amp * (random.random() * 2 - 1) for _ in range(n)]


def _mix(*tracks):
    n = max(len(t) for t in tracks)
    result = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            result[i] += s
    peak = max(abs(s) for s in result) or 1.0
    return [s / peak * 0.9 for s in result]


def _concat(*tracks):
    result = []
    for t in tracks:
        result.extend(t)
    return result


def save_wav(path, samples):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    data = [max(-32767, min(32767, int(s * 32767))) for s in samples]
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(struct.pack(f"<{len(data)}h", *data))
    print(f"  + {path}")


# ---------------------------------------------------------------------------
# Sound designs (GDD sección 5 — Efectos de Sonido)
# ---------------------------------------------------------------------------

def sfx_seed_bounce():
    """Rebote normal — tono corto y brillante (xilófono/gota de agua). AudioManager
    sube pitch_scale en cada rebote sucesivo para el efecto de "escala ascendente"."""
    s = _sine(1046, 0.09, 0.4)
    return _env(s, 0.001, 0.09)


def sfx_totopo_crunch():
    """Impacto Totopo — crujido nítido: ruido + snap descendente corto."""
    base = _noise(0.12, 0.35)
    snap = _sweep(2200, 400, 0.05, 0.3)
    padded_snap = snap + [0.0] * max(0, len(base) - len(snap))
    s = _mix(base, padded_snap)
    return _env(s, 0.001, 0.05)


def sfx_queso_thud():
    """Impacto Queso — sonido sordo (thud), grave y corto."""
    s = _mix(_sine(90, 0.18, 0.5), _sweep(140, 50, 0.18, 0.3))
    return _env(s, 0.003, 0.14)


def sfx_salsa_splash():
    """Explosión de Frasco de Salsa — ola/splash, ruido + barrido descendente."""
    s = _mix(_noise(0.3, 0.35), _sweep(700, 120, 0.3, 0.3))
    return _env(s, 0.005, 0.2)


# ---------------------------------------------------------------------------
# Música de fondo (mismo criterio que los SFX: sintetizada con stdlib, sin dependencias
# ni assets de terceros — AudioManager.play_music() ya existía pero nunca se llamaba ni
# tenía ningún archivo real en assets/audio/music/).
# ---------------------------------------------------------------------------

NOTE_FREQS = {
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "G3": 196.00, "A3": 220.00,
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00, "C5": 523.25,
}


def _triangle(freq, dur, amp=0.3):
    """Onda triangular — más suave que cuadrada, mejor para un loop de fondo (una cuadrada
    fatiga el oído mucho más rápido al repetirse varios minutos)."""
    n = int(dur * RATE)
    period = RATE / freq
    out = []
    for i in range(n):
        phase = (i % period) / period
        out.append(amp * (4 * abs(phase - 0.5) - 1))
    return out


def _seq(notes, beat_dur, wave_fn=_triangle, amp=0.3, gap_ratio=0.12):
    """notes: lista de (nombre_de_NOTE_FREQS o None, num_beats). None = silencio."""
    out = []
    for name, beats in notes:
        dur = beat_dur * beats
        if name is None:
            out.extend([0.0] * int(dur * RATE))
            continue
        note_dur = dur * (1.0 - gap_ratio)
        gap_dur = dur - note_dur
        tone = _env(wave_fn(NOTE_FREQS[name], note_dur, amp), attack=0.01, release=note_dur * 0.3)
        out.extend(tone)
        out.extend([0.0] * int(gap_dur * RATE))
    return out


def music_theme():
    """Loop corto y alegre (~7s, 132 BPM) para menú/juego — melodía pentatónica simple
    sobre un bajo de dos notas, con un "shaker" de ruido en el contratiempo (guiño al sabor
    mexicano del juego). 16 beats en las 3 capas para que el loop encaje sin cortes. Volumen
    deliberadamente discreto (ver _mix) — es fondo, no debe competir con los SFX del GDD."""
    beat = 60.0 / 132
    melody_notes = [
        ("C4", 1), ("E4", 1), ("G4", 1), ("E4", 1),
        ("A4", 1), ("G4", 1), ("E4", 1), ("D4", 1),
        ("C4", 1), ("D4", 1), ("E4", 1), ("G4", 1),
        ("E4", 2), (None, 2),
    ]
    bass_notes = [
        ("C3", 2), ("G3", 2),
        ("C3", 2), ("G3", 2),
        ("C3", 2), ("A3", 2),
        ("G3", 4),
    ]
    melody = _seq(melody_notes, beat, wave_fn=_triangle, amp=0.26)
    bass = _seq(bass_notes, beat, wave_fn=_sine, amp=0.20)
    shaker = []
    for _ in range(16):
        burst_dur = beat * 0.4
        burst = _env(_noise(burst_dur, amp=0.05), attack=0.001, release=burst_dur * 0.3)
        shaker.extend([0.0] * int(beat * 0.5 * RATE))
        shaker.extend(burst)
        shaker.extend([0.0] * max(0, int(beat * 0.5 * RATE) - len(burst)))
    return _mix(melody, bass, shaker)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("\n=== Generating block/gameplay sprites ===")
    sprites = {
        "assets/sprites/blocks/totopo.png": (64, 64, make_totopo_block(64)),
        "assets/sprites/blocks/queso.png": (64, 64, make_queso_block(64)),
        "assets/sprites/blocks/salsa.png": (64, 64, make_salsa_jar(64)),
        "assets/sprites/blocks/stone.png": (64, 64, make_stone_block(64)),
        "assets/sprites/molcajete.png": (96, 96, make_molcajete(96)),
        "assets/sprites/seed.png": (16, 16, make_seed_sprite(16)),
    }
    for path, (w, h, pixels) in sprites.items():
        save_png(path, w, h, pixels)

    print("\n=== Generating power-up icons ===")
    icons = {
        "assets/sprites/powerup_icons/lemon.png": (48, 48, make_lemon_icon(48)),
        "assets/sprites/powerup_icons/seed_extra.png": (48, 48, make_seed_extra_icon(48)),
        "assets/sprites/powerup_icons/laser_horizontal.png": (48, 48, make_laser_icon(48, True)),
        "assets/sprites/powerup_icons/laser_vertical.png": (48, 48, make_laser_icon(48, False)),
    }
    for path, (w, h, pixels) in icons.items():
        save_png(path, w, h, pixels)

    print("\n=== Generating audio (GDD sección 5) ===")
    sfx = {
        "assets/audio/sfx/seed_bounce.wav": sfx_seed_bounce(),
        "assets/audio/sfx/totopo_crunch.wav": sfx_totopo_crunch(),
        "assets/audio/sfx/queso_thud.wav": sfx_queso_thud(),
        "assets/audio/sfx/salsa_splash.wav": sfx_salsa_splash(),
    }
    for path, samples in sfx.items():
        save_wav(path, samples)

    print("\n=== Generating music ===")
    save_wav("assets/audio/music/theme.wav", music_theme())

    print("\n=== Generating studio branding ===")
    save_png("assets/splash.png", 512, 512, make_splash(512, 512))
    save_png("assets/icon.png", 512, 512, make_totopo_icon(512))

    print("\nFondo de menú: correr tools/fetch_ai_assets.py (Pollinations.ai) — no procedural.")
    print("Done. Run 'godot --headless --editor --quit' to reimport assets.")


if __name__ == "__main__":
    main()

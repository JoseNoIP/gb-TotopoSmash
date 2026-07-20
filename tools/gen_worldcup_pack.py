#!/usr/bin/env python3
"""Genera el pack temático "Mundial" (data/levels/worldcup_00N.json) para Totopo Smash —
v3, corrige feedback real del usuario sobre v2:

1. **10 niveles**, no 3 — v2 redujo por error el pack de 10 a 3; esta versión vuelve a 10,
   con el estilo `static` (imagen fija) que sí gustó, aplicado a variedad completa de
   figuras (no solo las 3 usadas como ejemplo de referencia).
2. **Tamaño PROPORCIONAL a la grilla normal** (pedido explícito): "el espacio del cuadro
   de un nivel normal, podríamos dividirlo en 4 cuadros de niveles fijos" = subdivisión 2x2
   por celda → `grid_cols = Constants.GRID_COLS * 2 = 14` (ver
   `Constants.STATIC_LEVEL_DEFAULT_SUBDIVISION`). v2 usaba 22-50 columnas sin relación con
   el tablero normal — mucho más denso de lo pedido. Excepciones documentadas: la cancha
   usa subdivisión 3x (21 columnas, necesita más ancho) y el texto "GOL" subdivisión 4x
   (28 columnas, 3 letras legibles necesitan más resolución que una silueta simple).
3. **Centrado vertical + nunca tapa el molcajete** — ya no es responsabilidad de este
   script (antes intentaba adivinar cuántas filas cabían "a ojo" y se pasó con la copa,
   tapando el molcajete). Ahora BoardManager centra y auto-escala usando el nuevo campo
   obligatorio `grid_rows` (ver level_loader.gd/board_manager.gd) — este script solo
   declara cuántas filas necesita la figura, sin preocuparse de si "caben".
4. **Elementos decorativos** (pedido explícito: "que no se vean tan vacíos") — cada nivel
   suma 2-5 acentos chicos (mini-estrellas) en el margen alrededor de la figura principal.
5. **Puntos de entrada dentro de la figura** (pedido explícito: "entre las partes de las
   figuras puedes poner power up... para entrar a la figura y poder destruirla desde
   adentro") — algunas celdas INTERIORES (rodeadas por otros bloques en las 4 direcciones,
   no accesibles directo desde afuera) se reemplazan por power-ups en vez de bloques, así
   que acertarle a ese punto exacto "abre" un camino hacia el interior de la figura.
6. **Semillas extra abundantes** (pedido explícito tras jugar el pack: "en una partida de
   exhibición deberíamos poder llegar por lo menos a unas 300 semillas al finalizar el
   nivel") — `SEED_BOUNTY_COUNT` (12) íconos `seed_extra` sembrados en el fondo de cada
   nivel (fáciles de alcanzar, no requieren abrirse paso) más los que caigan en puntos de
   entrada, cada uno con `"amount": SEED_EXTRA_ICON_AMOUNT` (20) en vez del +1 de
   `Constants.SEED_EXTRA_AMOUNT` (pensado para Modo Infinito/campaña numérica, sin tocar) —
   ver el campo opcional `amount` en `seed_extra_icon.gd`/`EventBus.seed_extra_touched`.
7. **HP sesgado hacia golpes baratos** (pedido explícito tras jugar: "lo ideal sería que la
   mayoría de bloques no requirieran tantos golpes... el 80% por debajo de la mitad del
   rango, y solo el 20% por encima") — `_random_hp()` reemplaza el `randint(HP_MIN,HP_MAX)`
   uniforme: 80% de probabilidad de caer en `[HP_MIN, HP_MID]`, 20% en `[HP_MID, HP_MAX]`
   (`HP_LOW_HALF_RATIO`). Sigue siendo sorteado (nunca fijo), solo con el sesgo — baja el HP
   promedio ~20% sin tocar el rango declarado ni la variedad real.

Uso: /tmp/gb_venv/bin/python3 tools/gen_worldcup_pack.py
(usa Pillow solo para el texto "GOL" — el resto es geometría pura, sin dependencias)
"""
import json
import math
import os
import random

STANDARD_SUBDIVISION = 2  # Constants.STATIC_LEVEL_DEFAULT_SUBDIVISION
WIDE_SUBDIVISION = 3  # cancha: necesita más ancho para leerse bien
TEXT_SUBDIVISION = 4  # "GOL": 3 letras necesitan más resolución que una silueta simple
BASE_COLS = 7  # Constants.GRID_COLS

# Pedido explícito del usuario: "bajemos la complejidad de los packs a un nivel 50" — usar
# el mismo rango de HP que tendría un bloque del nivel 50 del roster numérico (antes usaba
# el rango del nivel 100, el tope de la campaña) conservando las "ayudas" ya definidas
# (sesgo 80/20, power-ups de entrada, semillas extra, decoraciones).
HP_MIN = 35  # = totopo_hp_min_for_level(50) en gen_levels.py
HP_MAX = 174  # = totopo_hp_max_for_level(50) en gen_levels.py
# Pedido explícito del usuario tras jugar: con HP uniforme entre HP_MIN y HP_MAX la partida
# se sentía larga/tediosa (un nivel `static` no tiene condición de derrota — se gana
# despejando TODO, así que el HP promedio determina directamente cuánto dura la partida).
# En vez de uniforme, 80% de los bloques cae en la mitad BAJA del rango y solo 20% en la
# mitad alta — sigue habiendo variedad real (regla `random_totopo_hp`, nunca un valor fijo)
# pero la mayoría del nivel se destraba rápido y los golpes "caros" son la excepción, no la
# norma. Baja el HP promedio ~20% (144 en vez de 180) sin sacrificar el rango declarado.
HP_MID = (HP_MIN + HP_MAX) / 2
HP_LOW_HALF_RATIO = 0.8
STARTING_SEEDS = 50
MARGIN_CELLS = 2  # padding alrededor de la figura, para que quepan los acentos decorativos
INTERIOR_POWERUP_TARGET = 5  # puntos de entrada dentro de la figura
DECORATION_COUNT_RANGE = (2, 5)
# Pedido explícito del usuario: "en una partida de este tipo de exhibición deberíamos poder
# llegar por lo menos a unas 300 semillas al finalizar el nivel" — con Constants.SEED_EXTRA_AMOUNT
# (+1, pensado para Modo Infinito/campaña numérica) sembrar suficientes íconos para sumar
# +250 sería poco práctico (250 íconos en un nivel de ~100-130 celdas). En vez de tocar esa
# constante global (afectaría el balance ya ajustado de los otros dos modos), cada ícono de
# este pack pide un bono grande vía el campo opcional "amount" (ver seed_extra_icon.gd).
SEED_EXTRA_ICON_AMOUNT = 20
SEED_BOUNTY_COUNT = 12  # sembrados en el fondo, fuera de la silueta — fácil de alcanzar


# --- Formas: cada función recibe (cols, rows) — el ESPACIO DE TRABAJO de la figura, SIN
# el margen (el margen se agrega después, en build_static_level) — y devuelve un set de
# (col, row) rellenas. Todo geometría pura salvo gol_text_cells (usa Pillow). ------------


def ball_cells(cols: int, rows: int) -> set:
    cells = set()
    cx, cy = (cols - 1) / 2.0, (rows - 1) / 2.0
    r = min(cols, rows) * 0.46
    for row in range(rows):
        for col in range(cols):
            if math.hypot(col - cx, row - cy) <= r:
                cells.add((col, row))
    return cells


_TROPHY_NECK_BASE_POINTS = [(0.32, 0.05), (0.55, 0.06), (0.75, 0.16), (0.86, 0.42), (1.0, 0.42)]


def _trophy_half_width(t: float) -> float:
    if t <= 0.32:
        u = max(-1.0, min(1.0, (t - 0.16) / 0.16))
        return 0.34 * math.sqrt(max(0.0, 1.0 - u * u)) + 0.05
    for (t0, w0), (t1, w1) in zip(_TROPHY_NECK_BASE_POINTS, _TROPHY_NECK_BASE_POINTS[1:]):
        if t0 <= t <= t1:
            span = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
            return w0 + (w1 - w0) * span
    return _TROPHY_NECK_BASE_POINTS[-1][1]


def trophy_cells(cols: int, rows: int) -> set:
    cells = set()
    center_col = (cols - 1) / 2.0
    hole_center = (center_col + cols * 0.06, rows * 0.14)
    hole_radius = cols * 0.09
    for r in range(rows):
        t = r / float(rows - 1)
        half_width = _trophy_half_width(t) * cols * 0.5
        c_lo, c_hi = int(round(center_col - half_width)), int(round(center_col + half_width))
        for c in range(max(0, c_lo), min(cols - 1, c_hi) + 1):
            if math.hypot(c - hole_center[0], r - hole_center[1]) < hole_radius:
                continue
            cells.add((c, r))
    return cells


def goal_cells(cols: int, rows: int) -> set:
    """Portería: dos postes + travesaño — marco limpio, sin malla (una malla con
    suficiente densidad para leerse como "red" termina rellenando casi todo el interior
    y el marco deja de distinguirse como forma abierta)."""
    cells = set()
    post_w = max(1, cols // 9)
    for row in range(rows):
        for t in range(post_w):
            cells.add((t, row))
            cells.add((cols - 1 - t, row))
    for t in range(post_w):
        for col in range(cols):
            cells.add((col, t))
    return cells


def jersey_cells(cols: int, rows: int) -> set:
    collar_h = max(1, int(rows * 0.12))
    sleeve_h = max(1, int(rows * 0.18))
    body_w = int(cols * 0.62)
    body_lo = (cols - body_w) // 2
    body_hi = body_lo + body_w
    neck_w = int(cols * 0.24)
    neck_lo = (cols - neck_w) // 2
    neck_hi = neck_lo + neck_w
    cells = set()
    for row in range(rows):
        if row < collar_h:
            for col in range(body_lo, body_hi):
                if neck_lo <= col < neck_hi:
                    continue
                cells.add((col, row))
        elif row < collar_h + sleeve_h:
            for col in range(cols):
                cells.add((col, row))
        else:
            for col in range(body_lo, body_hi):
                cells.add((col, row))
    return cells


def star_cells(cols: int, rows: int) -> set:
    cells = set()
    cx, cy = (cols - 1) / 2.0, (rows - 1) / 2.0
    max_r, min_r = min(cols, rows) * 0.48, min(cols, rows) * 0.48 * 0.42
    points = 5
    lobe = (2 * math.pi) / points
    for row in range(rows):
        for col in range(cols):
            dx, dy = col - cx, row - cy
            dist = math.hypot(dx, dy)
            if dist < 1e-6:
                cells.add((col, row))
                continue
            angle = math.atan2(dy, dx) % lobe
            tri = 1 - abs((angle / lobe) - 0.5) * 2
            if dist <= min_r + (max_r - min_r) * tri:
                cells.add((col, row))
    return cells


def player_silhouette_cells(cols: int, rows: int) -> set:
    """Silueta ABSTRACTA de un futbolista pateando — no busca realismo, solo ser
    reconocible como figura humana en movimiento (cabeza + torso + pierna de apoyo +
    pierna de patada extendida)."""
    cells = set()
    cx = cols / 2.0
    head_r = cols * 0.15
    head_cy = rows * 0.11
    for row in range(rows):
        for col in range(cols):
            if math.hypot(col - cx, row - head_cy) <= head_r:
                cells.add((col, row))
    torso_top, torso_bot = rows * 0.22, rows * 0.55
    torso_w = cols * 0.28
    for row in range(int(torso_top), int(torso_bot)):
        for col in range(int(cx - torso_w / 2), int(cx + torso_w / 2) + 1):
            cells.add((col, row))
    leg_w = max(1, int(cols * 0.12))
    stand_x = cx - cols * 0.08
    for row in range(int(torso_bot), int(rows * 0.92)):
        for col in range(int(stand_x - leg_w / 2), int(stand_x + leg_w / 2) + 1):
            cells.add((col, row))
    kick_len = rows * 0.34
    kick_angle = math.radians(38)
    kx0, ky0 = cx + cols * 0.05, torso_bot
    steps = max(1, int(kick_len))
    for s in range(steps):
        t = s / float(steps)
        kx = kx0 + math.sin(kick_angle) * kick_len * t
        ky = ky0 + math.cos(kick_angle) * kick_len * t
        for dc in (-1, 0, 1):
            cells.add((int(kx) + dc, int(ky)))
    return cells


def soccer_field_cells(cols: int, rows: int) -> set:
    cells = set()
    for c in range(cols):
        cells.add((c, 0))
        cells.add((c, rows - 1))
    for r in range(rows):
        cells.add((0, r))
        cells.add((cols - 1, r))
    mid_c = cols // 2
    for r in range(rows):
        cells.add((mid_c, r))
    center = (mid_c, rows / 2.0)
    radius = rows * 0.30
    for r in range(rows):
        for c in range(cols):
            if abs(math.hypot(c - center[0], r - center[1]) - radius) < 0.6:
                cells.add((c, r))
    cells.add((mid_c, int(rows / 2)))
    box_w, box_h = int(cols * 0.14), int(rows * 0.62)
    box_top = (rows - box_h) // 2
    box_bottom = box_top + box_h
    for r in range(box_top, box_bottom + 1):
        cells.add((box_w, r))
        cells.add((cols - 1 - box_w, r))
    for c in range(0, box_w + 1):
        cells.add((c, box_top))
        cells.add((c, box_bottom))
    for c in range(cols - 1 - box_w, cols):
        cells.add((c, box_top))
        cells.add((c, box_bottom))
    return cells


def pennant_flag_cells(cols: int, rows: int) -> set:
    """Banderín de esquina (asta + triángulo) — un patrón de tablero ajedrezado no se
    distingue en este juego porque solo hay un color de bloque (totopo); una silueta sólida
    sí se lee bien en monocromo."""
    cells = set()
    pole_w = max(1, cols // 14)
    pole_x = int(cols * 0.15)
    for row in range(rows):
        for dc in range(pole_w):
            cells.add((pole_x + dc, row))
    flag_top, flag_bot = int(rows * 0.06), int(rows * 0.42)
    flag_left, flag_right = pole_x + pole_w, cols - 1
    flag_mid = (flag_top + flag_bot) / 2.0
    flag_half_h = (flag_bot - flag_top) / 2.0
    for row in range(flag_top, flag_bot):
        t = max(0.0, 1.0 - abs(row - flag_mid) / flag_half_h) if flag_half_h > 0 else 1.0
        width = int((flag_right - flag_left) * t)
        for col in range(flag_left, flag_left + width):
            cells.add((col, row))
    return cells


def medal_cells(cols: int, rows: int) -> set:
    cells = set()
    ribbon_h = int(rows * 0.28)
    band_w = max(1, int(cols * 0.12))
    left_x, right_x = int(cols * 0.30), int(cols * 0.70) - band_w
    for row in range(ribbon_h):
        for dc in range(band_w):
            cells.add((left_x + dc, row))
            cells.add((right_x + dc, row))
    disc_r = min(cols, rows - ribbon_h) * 0.36
    cx, cy = (cols - 1) / 2.0, ribbon_h + disc_r * 1.05
    for row in range(rows):
        for col in range(cols):
            if math.hypot(col - cx, row - cy) <= disc_r:
                cells.add((col, row))
    return cells


FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def gol_text_cells(cols: int, rows: int) -> set:
    from PIL import Image, ImageDraw, ImageFont

    supersample = 6
    w, h = cols * supersample, rows * supersample
    img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(img)
    font_path = next((p for p in FONT_CANDIDATES if os.path.exists(p)), None)
    font = ImageFont.truetype(font_path, size=int(h * 0.85)) if font_path else ImageFont.load_default()
    text = "GOL"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pos = ((w - text_w) / 2 - bbox[0], (h - text_h) / 2 - bbox[1])
    draw.text(pos, text, fill=255, font=font)
    cells = set()
    threshold = 255 * 0.35
    for r in range(rows):
        for c in range(cols):
            box = img.crop((c * supersample, r * supersample, (c + 1) * supersample, (r + 1) * supersample))
            avg = sum(box.getdata()) / float(supersample * supersample)
            if avg > threshold:
                cells.add((c, r))
    return cells


# --- Ensamblado: silueta -> cells (hp), acentos decorativos, puntos de entrada interiores ---


def _mini_star(cx: int, cy: int) -> set:
    return {(cx, cy), (cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)}


def _random_hp(rng: random.Random) -> int:
    """80% de los bloques por debajo de la mitad del rango, 20% por encima (pedido
    explícito del usuario) — sigue siendo sorteado (nunca un valor fijo), solo con el sesgo
    hacia golpes baratos para que la mayoría del nivel se destrabe rápido."""
    if rng.random() < HP_LOW_HALF_RATIO:
        return rng.randint(HP_MIN, int(HP_MID))
    return rng.randint(int(HP_MID) + 1, HP_MAX)


def _add_decorations(filled: set, cols: int, rows: int, rng: random.Random) -> set:
    """Acentos chicos (mini-estrellas) en el margen alrededor de la figura, pedido
    explícito del usuario ("que no se vean tan vacíos") — nunca se superponen a la
    figura ni quedan pegados al borde del canvas."""
    decorations = set()
    attempts = 0
    target = rng.randint(*DECORATION_COUNT_RANGE)
    while len(decorations) < target and attempts < 200:
        attempts += 1
        cx, cy = rng.randint(2, cols - 3), rng.randint(2, rows - 3)
        star = _mini_star(cx, cy)
        if star & filled or star & decorations:
            continue
        decorations |= star
    return decorations


def _add_seed_bounties(filled: set, decorations: set, cols: int, rows: int, rng: random.Random) -> set:
    """Semillas extra sembradas en el fondo (fuera de la silueta, sin necesidad de abrirse
    paso como los puntos de entrada) — pedido explícito del usuario: una partida de
    exhibición debe poder acumular varios cientos de semillas para el final del nivel."""
    occupied = filled | decorations
    bounties = set()
    attempts = 0
    while len(bounties) < SEED_BOUNTY_COUNT and attempts < 400:
        attempts += 1
        pos = (rng.randint(1, cols - 2), rng.randint(1, rows - 2))
        if pos in occupied or pos in bounties:
            continue
        bounties.add(pos)
    return bounties


def _interior_entry_points(filled: set, count: int, rng: random.Random) -> set:
    """Celdas rodeadas por bloques en las 4 direcciones (no alcanzables directo desde
    afuera) — reemplazarlas por power-ups crea "puntos de entrada": el jugador tiene que
    acertarle a esa posición exacta para abrir un camino hacia adentro de la figura
    (pedido explícito del usuario)."""
    interior = [
        (c, r)
        for (c, r) in filled
        if all((c + dc, r + dr) in filled for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    ]
    rng.shuffle(interior)
    return set(interior[:count])


def build_static_level(level_id: str, name_key: str, shape_fn, work_cols: int, work_rows: int, seed: int) -> dict:
    rng = random.Random(seed)
    filled_raw = shape_fn(work_cols, work_rows)
    decorations_raw = _add_decorations(filled_raw, work_cols, work_rows, rng)
    entry_points_raw = _interior_entry_points(filled_raw, INTERIOR_POWERUP_TARGET, rng)
    seed_bounties_raw = _add_seed_bounties(filled_raw, decorations_raw, work_cols, work_rows, rng)

    grid_cols = work_cols + MARGIN_CELLS * 2
    grid_rows = work_rows + MARGIN_CELLS * 2

    def offset(pos):
        return (pos[0] + MARGIN_CELLS, pos[1] + MARGIN_CELLS)

    filled = {offset(p) for p in filled_raw}
    decorations = {offset(p) for p in decorations_raw}
    entry_points = {offset(p) for p in entry_points_raw}
    seed_bounties = {offset(p) for p in seed_bounties_raw}

    icon_kinds = ["lemon", "seed_extra", "seed_extra", "laser"]
    cells = []
    total_hp = 0
    icon_i = 0
    for (c, r) in sorted(filled):
        if (c, r) in entry_points:
            kind = icon_kinds[icon_i % len(icon_kinds)]
            icon_i += 1
            cell = {"col": c, "row": r, "kind": kind}
            if kind == "laser":
                cell["orientation"] = "horizontal" if rng.random() < 0.5 else "vertical"
            if kind == "seed_extra":
                cell["amount"] = SEED_EXTRA_ICON_AMOUNT
            cells.append(cell)
            continue
        hp = _random_hp(rng)
        total_hp += hp
        cells.append({"col": c, "row": r, "kind": "totopo", "hp": hp})
    for (c, r) in sorted(decorations):
        hp = _random_hp(rng)
        total_hp += hp
        cells.append({"col": c, "row": r, "kind": "totopo", "hp": hp})
    for (c, r) in sorted(seed_bounties):
        cells.append({"col": c, "row": r, "kind": "seed_extra", "amount": SEED_EXTRA_ICON_AMOUNT})

    hits_per_seed_estimate = 6
    par_turns = max(3, math.ceil(total_hp / (STARTING_SEEDS * hits_per_seed_estimate)))

    return {
        "id": level_id,
        "name": name_key,
        "static": True,
        "grid_cols": grid_cols,
        "grid_rows": grid_rows,
        "starting_seeds": STARTING_SEEDS,
        "par_turns": par_turns,
        "cells": cells,
    }


def _work_size(subdivision: int, aspect_h_over_w: float) -> tuple:
    """Ancho de trabajo = BASE_COLS*subdivision menos el margen (se agrega después);
    alto de trabajo según la proporción natural de la figura."""
    work_cols = BASE_COLS * subdivision
    work_rows = max(1, round(work_cols * aspect_h_over_w))
    return work_cols, work_rows


LEVELS_SPEC = [
    ("worldcup_001", "LEVEL_NAME_BALL", ball_cells, STANDARD_SUBDIVISION, 1.0),
    ("worldcup_002", "LEVEL_NAME_TROPHY_DETAILED", trophy_cells, STANDARD_SUBDIVISION, 1.9),
    ("worldcup_003", "LEVEL_NAME_GOAL", goal_cells, STANDARD_SUBDIVISION, 0.75),
    ("worldcup_004", "LEVEL_NAME_JERSEY", jersey_cells, STANDARD_SUBDIVISION, 1.15),
    ("worldcup_005", "LEVEL_NAME_STAR_MUNDIAL", star_cells, STANDARD_SUBDIVISION, 1.0),
    ("worldcup_006", "LEVEL_NAME_PLAYER", player_silhouette_cells, STANDARD_SUBDIVISION, 1.4),
    ("worldcup_007", "LEVEL_NAME_SOCCER_FIELD", soccer_field_cells, WIDE_SUBDIVISION, 0.5),
    ("worldcup_008", "LEVEL_NAME_GOL_TEXT", gol_text_cells, TEXT_SUBDIVISION, 0.42),
    ("worldcup_009", "LEVEL_NAME_PENNANT_FLAG", pennant_flag_cells, STANDARD_SUBDIVISION, 0.85),
    ("worldcup_010", "LEVEL_NAME_MEDAL", medal_cells, STANDARD_SUBDIVISION, 1.15),
]


def main() -> None:
    out_dir = "data/levels"
    os.makedirs(out_dir, exist_ok=True)

    new_ids = []
    print("=== Pack Mundial v3 (worldcup_001-010, static, proporcional) ===")
    for i, (level_id, name_key, shape_fn, subdivision, aspect) in enumerate(LEVELS_SPEC):
        work_cols, work_rows = _work_size(subdivision, aspect)
        level = build_static_level(level_id, name_key, shape_fn, work_cols, work_rows, seed=7000 + i)
        path = os.path.join(out_dir, f"{level_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        new_ids.append(level_id)
        totopo_hps = [c["hp"] for c in level["cells"] if c["kind"] == "totopo"]
        icon_count = len(level["cells"]) - len(totopo_hps)
        seed_bonus = sum(c.get("amount", 0) for c in level["cells"] if c["kind"] == "seed_extra")
        max_seeds = level["starting_seeds"] + seed_bonus
        avg_hp = sum(totopo_hps) / len(totopo_hps) if totopo_hps else 0
        print(
            f"  + {path} ({level['grid_cols']}x{level['grid_rows']}, {len(totopo_hps)} bloques, "
            f"HP prom={avg_hp:.0f}, {icon_count} power-ups, par_turns={level['par_turns']}, "
            f"semillas max={max_seeds})"
        )

    manifest_path = os.path.join(out_dir, "manifest.json")
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    kept = [lid for lid in manifest["levels"] if not lid.startswith("worldcup_")]
    kept.extend(new_ids)
    manifest["levels"] = kept
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"\n  + {manifest_path} ({len(kept)} niveles en total)")


if __name__ == "__main__":
    main()

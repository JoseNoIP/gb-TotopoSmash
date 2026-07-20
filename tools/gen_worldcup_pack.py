#!/usr/bin/env python3
"""Genera el pack temático "Mundial" (data/levels/worldcup_00N.json) para Totopo Smash —
v2, REEMPLAZA la v1 (10 niveles de baja resolución/HP fijo) por 3 niveles-figura `static`
de ALTA resolución (cancha, copa, "GOL"), pedido explícito del usuario tras ver imágenes
de referencia mucho más detalladas que el grid de 7 columnas del juego permite.

Uso: /tmp/gb_venv/bin/python3 tools/gen_worldcup_pack.py
(usa Pillow solo para el texto "GOL" — el resto es geometría pura, sin dependencias)

Diseño (`"static": true`, ver src/features/levels/level_loader.gd):
- Grilla PROPIA por nivel (`grid_cols`, mucho más angosta que Constants.GRID_COLS=7 — más
  bloques, más chicos, caben en el mismo ancho de pantalla). Los bloques NUNCA se
  desplazan y NO hay condición de derrota (BoardManager se salta shift/game-over para
  estos niveles) — se gana despejando todo lo destructible, sin importar los turnos.
- HP alto variado (60-300, mismo rango que totopo_hp_for_level(100) — decisión confirmada
  con el usuario: "HP alto, tipo pack Mundial actual").
- `starting_seeds` bajo (50, pedido explícito: "al no perder, podemos bajar la cantidad de
  semillas iniciales") — sin presión de tiempo, no hace falta un burst enorme por turno.
- `par_turns` habilita el bono de score de GameManager (Constants.STATIC_LEVEL_PAR_BONUS_
  MULTIPLIER) si se limpia rápido — "recompensar hacerlo en menos turnos" (pedido
  explícito). Valor aproximado: total_hp / (starting_seeds * daño_promedio_por_semilla),
  ajustable si el playtesting real muestra que es muy fácil/difícil de alcanzar.
- Huecos (celdas vacías dentro del recuadro de la figura, NO parte de la silueta) llevan
  power-ups sembrados (lemon/seed_extra/laser) — pedido explícito: "dentro de los huecos
  puedes poner los power up". `laser` es un power-up NUEVO (ver laser_icon.gd): dispara un
  golpe de Constants.LASER_DAMAGE en línea recta (fila u columna completa) al tocarlo.
"""
import json
import math
import os
import random

HP_MIN = 60  # = totopo_hp_min_for_level(100) en gen_levels.py
HP_MAX = 300  # = totopo_hp_max_for_level(100) en gen_levels.py
STARTING_SEEDS = 50
GAP_ICON_TARGET_COUNT = 18  # aprox. cuántos power-ups sembrar en los huecos por nivel


# --- Geometría pura: cancha de fútbol (contornos, sin PIL) -----------------------------


def soccer_field_cells(cols: int, rows: int) -> set:
    cells = set()
    # Borde exterior
    for c in range(cols):
        cells.add((c, 0))
        cells.add((c, rows - 1))
    for r in range(rows):
        cells.add((0, r))
        cells.add((cols - 1, r))

    # Línea de medio campo (vertical)
    mid_c = cols // 2
    for r in range(rows):
        cells.add((mid_c, r))

    # Círculo central (anillo)
    center = (mid_c, rows / 2.0)
    radius = rows * 0.32
    for r in range(rows):
        for c in range(cols):
            dist = math.hypot(c - center[0], r - center[1])
            if abs(dist - radius) < 0.6:
                cells.add((c, r))
    # Punto central
    cells.add((mid_c, int(rows / 2)))

    # Áreas grandes (penalty box) + áreas chicas (six-yard box), a cada lado
    box_w = int(cols * 0.14)
    box_h = int(rows * 0.62)
    box_top = (rows - box_h) // 2
    box_bottom = box_top + box_h
    small_w = int(cols * 0.06)
    small_h = int(rows * 0.34)
    small_top = (rows - small_h) // 2
    small_bottom = small_top + small_h
    for r in range(box_top, box_bottom + 1):
        cells.add((box_w, r))
        cells.add((cols - 1 - box_w, r))
    for c in range(0, box_w + 1):
        cells.add((c, box_top))
        cells.add((c, box_bottom))
    for c in range(cols - 1 - box_w, cols):
        cells.add((c, box_top))
        cells.add((c, box_bottom))
    for r in range(small_top, small_bottom + 1):
        cells.add((small_w, r))
        cells.add((cols - 1 - small_w, r))
    for c in range(0, small_w + 1):
        cells.add((c, small_top))
        cells.add((c, small_bottom))
    for c in range(cols - 1 - small_w, cols):
        cells.add((c, small_top))
        cells.add((c, small_bottom))

    # Arcos de esquina (cuartos de círculo chicos)
    corner_r = max(2, int(cols * 0.02))
    for (cx, cy) in [(0, 0), (cols - 1, 0), (0, rows - 1), (cols - 1, rows - 1)]:
        for dr in range(-corner_r, corner_r + 1):
            for dc in range(-corner_r, corner_r + 1):
                c, r = cx + dc, cy + dr
                if 0 <= c < cols and 0 <= r < rows:
                    if abs(math.hypot(dc, dr) - corner_r) < 0.8:
                        cells.add((c, r))
    return cells


# --- Geometría pura: trofeo (silueta paramétrica, sin PIL) ------------------------------


## Puntos de control (t, medio-ancho relativo) + interpolación lineal entre ellos, salvo
## la cabeza (semi-elipse) — garantiza continuidad exacta en cada frontera (0.32 da 0.05
## en ambas fórmulas), a diferencia de una versión anterior con un salto visible ahí.
_TROPHY_NECK_BASE_POINTS = [(0.32, 0.05), (0.55, 0.06), (0.75, 0.16), (0.86, 0.42), (1.0, 0.42)]


def _trophy_half_width(t: float) -> float:
    """t en [0,1] (0=arriba, 1=abajo). Devuelve medio-ancho relativo (0..1)."""
    if t <= 0.32:
        # Cabeza redondeada (semi-elipse)
        u = (t - 0.16) / 0.16
        u = max(-1.0, min(1.0, u))
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
    hole_radius = cols * 0.07
    for r in range(rows):
        t = r / float(rows - 1)
        half_width = _trophy_half_width(t) * cols * 0.5
        c_lo = int(round(center_col - half_width))
        c_hi = int(round(center_col + half_width))
        for c in range(max(0, c_lo), min(cols - 1, c_hi) + 1):
            if math.hypot(c - hole_center[0], r - hole_center[1]) < hole_radius:
                continue  # "ojo" hueco cerca de la cabeza, detalle del diseño de referencia
            cells.add((c, r))
    return cells


# --- PIL: texto "GOL" -------------------------------------------------------------------

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


# --- Ensamblado del nivel: silueta -> cells (hp) + power-ups en los huecos --------------


def build_static_level(level_id: str, name_key: str, filled: set, cols: int, rows: int, seed: int) -> dict:
    rng = random.Random(seed)
    cells = []
    total_hp = 0
    for (c, r) in sorted(filled):
        hp = rng.randint(HP_MIN, HP_MAX)
        total_hp += hp
        cells.append({"col": c, "row": r, "kind": "totopo", "hp": hp})

    gaps = [(c, r) for r in range(rows) for c in range(cols) if (c, r) not in filled]
    rng.shuffle(gaps)
    icon_kinds = ["lemon", "seed_extra", "seed_extra", "laser"]  # seed_extra más frecuente
    step = max(1, len(gaps) // GAP_ICON_TARGET_COUNT) if gaps else 1
    picked = gaps[::step][:GAP_ICON_TARGET_COUNT]
    for i, (c, r) in enumerate(picked):
        kind = icon_kinds[i % len(icon_kinds)]
        cell = {"col": c, "row": r, "kind": kind}
        if kind == "laser":
            cell["orientation"] = "horizontal" if rng.random() < 0.5 else "vertical"
        cells.append(cell)

    # par_turns aproximado: cuántos turnos de starting_seeds (asumiendo ~6 golpes útiles
    # por semilla en un tablero denso) hacen falta para cubrir el HP total. Ajustable sin
    # tocar nada más si el playtesting real muestra que está muy floja/apretada.
    hits_per_seed_estimate = 6
    par_turns = max(3, math.ceil(total_hp / (STARTING_SEEDS * hits_per_seed_estimate)))

    return {
        "id": level_id,
        "name": name_key,
        "static": True,
        "grid_cols": cols,
        "starting_seeds": STARTING_SEEDS,
        "par_turns": par_turns,
        "cells": cells,
    }


LEVELS_SPEC = [
    ("worldcup_001", "LEVEL_NAME_SOCCER_FIELD", "field", 44, 20),
    ("worldcup_002", "LEVEL_NAME_TROPHY_DETAILED", "trophy", 22, 40),
    ("worldcup_003", "LEVEL_NAME_GOL_TEXT", "gol", 50, 16),
]


def main() -> None:
    out_dir = "data/levels"
    os.makedirs(out_dir, exist_ok=True)

    new_ids = []
    print("=== Pack Mundial v2 (worldcup_001-003, static, alta resolución) ===")
    for i, (level_id, name_key, shape, cols, rows) in enumerate(LEVELS_SPEC):
        if shape == "field":
            filled = soccer_field_cells(cols, rows)
        elif shape == "trophy":
            filled = trophy_cells(cols, rows)
        else:
            filled = gol_text_cells(cols, rows)
        level = build_static_level(level_id, name_key, filled, cols, rows, seed=6000 + i)
        path = os.path.join(out_dir, f"{level_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        new_ids.append(level_id)
        totopo_count = sum(1 for c in level["cells"] if c["kind"] == "totopo")
        icon_count = len(level["cells"]) - totopo_count
        print(
            f"  + {path} ({cols}x{rows}, {totopo_count} bloques, {icon_count} power-ups, "
            f"par_turns={level['par_turns']})"
        )

    manifest_path = os.path.join(out_dir, "manifest.json")
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    # Quita CUALQUIER worldcup_* viejo (v1 tenía 10 niveles, v2 tiene 3) antes de agregar
    # los nuevos — si no, quedarían ids huérfanos apuntando a archivos ya borrados.
    kept = [lid for lid in manifest["levels"] if not lid.startswith("worldcup_")]
    kept.extend(new_ids)
    manifest["levels"] = kept
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"\n  + {manifest_path} ({len(kept)} niveles en total)")


if __name__ == "__main__":
    main()

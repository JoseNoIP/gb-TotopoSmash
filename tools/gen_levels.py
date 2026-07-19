#!/usr/bin/env python3
"""Genera los niveles de Totopo Smash (data/levels/) + su manifiesto.

Uso: python3 tools/gen_levels.py

Regla (paralela a la #36 de gen_assets.py sobre assets): NO editar a mano un nivel que
este script regenera sin también actualizar su spec aquí — si no, la próxima corrida
completa lo pisa. Niveles hechos por la skill /level-designer se editan directo y se
agregan a mano al manifiesto; ese es el mecanismo pensado para packs temáticos.

Los niveles procedurales (1-14) portan a Python las fórmulas de
src/features/board/wave_scaling.gd para producir un `row_queue` totalmente concreto en
tiempo de generación (nivel 1 = 10 filas, +2 por nivel siguiente — ver
total_rows_for_level) — Modo Nivel en runtime no depende de ningún RNG (mismo tablero
para todos los jugadores) y revela una fila nueva por turno hasta agotar la cola. Los
niveles-figura (15-20) se dibujan a mano en un grid ASCII de 7 columnas y se convierten a
`cells` absolutas (toda la forma visible desde el inicio), en SILUETA (solo borde) o
RELLENO (toda celda).
"""
import json
import math
import os
import random

GRID_COLS = 7

# --- Niveles procedurales: fórmulas portadas de wave_scaling.gd ------------------------


def totopo_hp(effective_wave: int) -> int:
    return max(1, round(effective_wave * 1.0))


def queso_hp(effective_wave: int) -> int:
    return max(1, math.ceil(effective_wave * 1.5))


def empty_chance(effective_wave: int) -> float:
    if effective_wave >= 31:
        return 0.08
    if effective_wave > 5:
        return 0.20
    return 0.30


def seed_extra_chance(effective_wave: int) -> float:
    return 0.22 if effective_wave <= 5 else 0.05


LEMON_CHANCE = 0.05
STONE_CHANCE = 0.10
QUESO_CHANCE = 0.18
TRIANGLE_CHANCE = 0.18
SALSA_CHANCE = 0.10


def pick_kind(effective_wave: int, rng: random.Random) -> str:
    if rng.random() < empty_chance(effective_wave):
        return "empty"
    if rng.random() < seed_extra_chance(effective_wave):
        return "seed_extra"
    if rng.random() < LEMON_CHANCE:
        return "lemon"
    if effective_wave >= 16 and rng.random() < STONE_CHANCE:
        return "stone"
    if effective_wave >= 6 and rng.random() < SALSA_CHANCE:
        return "salsa"
    if effective_wave >= 6 and rng.random() < QUESO_CHANCE:
        return "queso"
    if effective_wave >= 6 and rng.random() < TRIANGLE_CHANCE:
        return "triangle"
    return "totopo"


def total_rows_for_level(level_number: int) -> int:
    """Nivel 1 = 10 filas totales (pedido explícito del usuario), crece proporcional
    (+2 filas por nivel) para los siguientes — ajustable aquí sin tocar nada más."""
    return 10 + (level_number - 1) * 2


def generate_procedural_level(level_number: int) -> dict:
    """row_queue 100% concreto (sin RNG en runtime) — se hornea aquí, una sola vez.
    Nivel de dificultad progresiva: arranca mostrando 1 fila y el resto se revela de a
    poco (una fila nueva por turno, igual que Modo Infinito) hasta agotar la cola —
    nunca coloca todo el contenido de una vez (eso es lo que hacen las figuras/`cells`)."""
    rng = random.Random(1000 + level_number)
    # Dificultad efectiva crece más lento que el número de nivel: con más filas totales
    # ya hay de por sí más turnos de juego, así que el HP no necesita escalar tan rápido.
    effective_wave = max(1, (level_number + 1) // 2)
    total_rows = total_rows_for_level(level_number)

    row_queue = []
    for _ in range(total_rows):
        row_cells = []
        for col in range(GRID_COLS):
            kind = pick_kind(effective_wave, rng)
            if kind == "empty":
                continue
            cell = {"col": col, "kind": kind}
            if kind == "queso":
                cell["hp"] = queso_hp(effective_wave)
            elif kind in ("totopo", "salsa"):
                cell["hp"] = totopo_hp(effective_wave)
            elif kind == "triangle":
                cell["hp"] = totopo_hp(effective_wave)
                cell["corner"] = rng.randint(0, 3)
            row_cells.append(cell)
        row_queue.append(row_cells)

    level_id = f"level_{level_number:03d}"
    return {
        "id": level_id,
        "starting_seeds": 10 + effective_wave * 2,
        "row_queue": row_queue,
    }


# --- Niveles-figura: ASCII (7 columnas) -> celdas --------------------------------------


def cells_from_ascii(art: str, kind: str = "totopo", hp: int = 1, fill: bool = True) -> list:
    rows = [row for row in art.strip("\n").split("\n")]
    grid = [[ch == "X" for ch in row] for row in rows]
    h = len(grid)
    w = len(grid[0])
    cells = []
    for r in range(h):
        for c in range(w):
            if not grid[r][c]:
                continue
            if not fill:
                is_boundary = False
                for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nr, nc = r + dr, c + dc
                    if nr < 0 or nr >= h or nc < 0 or nc >= w or not grid[nr][nc]:
                        is_boundary = True
                        break
                if not is_boundary:
                    continue
            cells.append({"col": c, "row": r, "kind": kind, "hp": hp})
    return cells


def sprinkle_icons(cells: list, every: int = 6) -> list:
    """Reemplaza 1 de cada `every` celdas destructibles por lemon/seed_extra alternado,
    para variedad — determinístico (mismo resultado siempre), sin RNG."""
    result = []
    icon_i = 0
    for i, cell in enumerate(cells):
        if i % every == every - 1:
            icon_kind = "lemon" if icon_i % 2 == 0 else "seed_extra"
            icon_i += 1
            result.append({"col": cell["col"], "row": cell["row"], "kind": icon_kind})
        else:
            result.append(cell)
    return result


CROSS_ART = """
..XXX..
..XXX..
XXXXXXX
XXXXXXX
..XXX..
..XXX..
"""

HEART_ART = """
.XX.XX.
XXXXXXX
XXXXXXX
.XXXXX.
..XXX..
...X...
"""

BOTTLE_ART = """
..XXX..
..XXX..
.XXXXX.
XXXXXXX
XXXXXXX
XXXXXXX
"""

STAR_ART = """
...X...
...X...
X..X..X
XXXXXXX
X..X..X
...X...
"""

DIAMOND_ART = """
...X...
..XXX..
.XXXXX.
.XXXXX.
..XXX..
...X...
"""

SMILEY_ART = """
.XX.XX.
.XX.XX.
.......
X.....X
.XXXXX.
.......
"""


def generate_shape_level(level_number: int, shape_id: str, art: str, fill: bool) -> dict:
    cells = cells_from_ascii(art, kind="totopo", hp=1, fill=fill)
    cells = sprinkle_icons(cells)
    return {
        "id": f"level_{level_number:03d}",
        "name": f"LEVEL_NAME_{level_number:03d}",  # key de i18n: "Cruz", "Corazón", etc.
        "starting_seeds": 16,
        "cells": cells,
    }


SHAPE_LEVELS = [
    ("cross", CROSS_ART, True),
    ("heart", HEART_ART, False),
    ("bottle", BOTTLE_ART, True),
    ("star", STAR_ART, False),
    ("diamond", DIAMOND_ART, True),
    ("smiley", SMILEY_ART, False),
]


def main() -> None:
    out_dir = "data/levels"
    os.makedirs(out_dir, exist_ok=True)

    level_ids = []

    print("=== Niveles procedurales (1-14) ===")
    for n in range(1, 15):
        level = generate_procedural_level(n)
        path = os.path.join(out_dir, f"{level['id']}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        level_ids.append(level["id"])
        print(
            f"  + {path} ({len(level['row_queue'])} filas en cola, "
            f"{level['starting_seeds']} semillas)"
        )

    print("\n=== Niveles-figura (15-20) ===")
    for i, (shape_id, art, fill) in enumerate(SHAPE_LEVELS):
        n = 15 + i
        level = generate_shape_level(n, shape_id, art, fill)
        path = os.path.join(out_dir, f"{level['id']}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        level_ids.append(level["id"])
        mode = "relleno" if fill else "silueta"
        print(f"  + {path} ({shape_id}, {mode}, {len(level['cells'])} celdas)")

    manifest_path = os.path.join(out_dir, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump({"levels": level_ids}, f, ensure_ascii=False, indent=2)
    print(f"\n  + {manifest_path} ({len(level_ids)} niveles)")


if __name__ == "__main__":
    main()

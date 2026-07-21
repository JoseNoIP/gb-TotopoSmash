#!/usr/bin/env python3
"""Genera el pack temático navideño (data/levels/holiday_00N.json) para Totopo Smash.

Uso: python3 tools/gen_holiday_pack.py

A diferencia de tools/gen_levels.py (que se puede correr de nuevo en cualquier momento y
regenera TODO el roster numérico), este script es hand-authored y de una sola vez, siguiendo
la convención de packs temáticos de .claude/skills/level-designer/SKILL.md: namespace propio
(`holiday_00N`, nunca `level_0NN`) para que un futuro pack no choque con el roster principal.
No lo vuelvas a correr sin revisar el manifiesto — reescribe holiday_001..005 y vuelve a
agregarlos al final de manifest.json, pero NO toca level_001..100.
"""
import json
import os
import random

from gen_levels import cells_from_ascii, sprinkle_icons, starting_seeds_for_level

# Pedido explícito del usuario tras jugar: "en el pack de navidad todos los bloques
# tienen 1. Ajústalo a un nivel 20" — antes cells_from_ascii() recibía un hp=1 fijo, sin
# ninguna variedad real (mismo bug encontrado en los niveles 95-100 del roster numérico,
# ver gen_levels.py::generate_shape_level()). Ahora cada celda sortea su propio HP dentro
# del rango de este nivel de referencia, igual que el resto del juego.
LEVEL_EQUIVALENT = 20

TREE_ART = """
...X...
..XXX..
.XXXXX.
XXXXXXX
..XXX..
..XXX..
"""

GIFT_ART = """
..X.X..
.XXXXX.
XXXXXXX
XXX.XXX
XXXXXXX
XXXXXXX
"""

SNOWMAN_ART = """
..XXX..
..XXX..
.XXXXX.
.XXXXX.
XXXXXXX
XXXXXXX
"""

CANDY_CANE_ART = """
..XXX..
.X...X.
.X.....
.X.....
.X.....
.X.....
"""

BELL_ART = """
..XXX..
.XXXXX.
.XXXXX.
XXXXXXX
...X...
..XXX..
"""

PACK = [
    ("holiday_001", "tree", TREE_ART, True),
    ("holiday_002", "gift", GIFT_ART, False),
    ("holiday_003", "snowman", SNOWMAN_ART, True),
    ("holiday_004", "candy_cane", CANDY_CANE_ART, True),
    ("holiday_005", "bell", BELL_ART, False),
]


def generate_holiday_level(level_id: str, shape_id: str, art: str, fill: bool, seed: int) -> dict:
    rng = random.Random(seed)
    cells = cells_from_ascii(art, kind="totopo", level_number=LEVEL_EQUIVALENT, fill=fill, rng=rng)
    cells = sprinkle_icons(cells)
    return {
        "id": level_id,
        "name": f"LEVEL_NAME_{shape_id.upper()}",
        "starting_seeds": starting_seeds_for_level(LEVEL_EQUIVALENT),
        "cells": cells,
    }


def main() -> None:
    out_dir = "data/levels"
    os.makedirs(out_dir, exist_ok=True)

    new_ids = []
    print("=== Pack navideño (holiday_001-005) ===")
    for i, (level_id, shape_id, art, fill) in enumerate(PACK):
        level = generate_holiday_level(level_id, shape_id, art, fill, seed=8000 + i)
        path = os.path.join(out_dir, f"{level_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        new_ids.append(level_id)
        mode = "relleno" if fill else "silueta"
        hps = [c["hp"] for c in level["cells"] if c["kind"] == "totopo"]
        avg_hp = sum(hps) / len(hps) if hps else 0
        print(
            f"  + {path} ({shape_id}, {mode}, {len(level['cells'])} celdas, "
            f"HP prom={avg_hp:.0f}, semillas={level['starting_seeds']})"
        )

    manifest_path = os.path.join(out_dir, "manifest.json")
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    existing = set(manifest["levels"])
    appended = [lid for lid in new_ids if lid not in existing]
    manifest["levels"].extend(appended)
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"\n  + {manifest_path} (+{len(appended)} niveles, {len(manifest['levels'])} en total)")


if __name__ == "__main__":
    main()

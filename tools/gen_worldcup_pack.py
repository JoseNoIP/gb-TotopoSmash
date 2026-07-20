#!/usr/bin/env python3
"""Genera el pack temático "Mundial" (data/levels/worldcup_00N.json) para Totopo Smash.

Uso: python3 tools/gen_worldcup_pack.py

Pack hand-authored (mismo patrón que gen_holiday_pack.py) — namespace propio
`worldcup_00N`, nunca `level_0NN`, siguiendo la convención de packs temáticos de
.claude/skills/level-designer/SKILL.md.

Pedido explícito: 10 niveles con figuras/palabras alusivas al mundial, de complejidad POR
ENCIMA del nivel 100 (ver tools/gen_levels.py::totopo_hp_max_for_level, que en nivel 100
llega a HP 300). A diferencia del pack navideño (HP 1, solo "satisfacción de despejar la
figura"), estos usan el mismo rango VARIADO que el nivel 100 (60-300, sorteado por bloque,
NUNCA el mismo valor fijo en todos los bloques del nivel — corrección explícita del usuario
sobre el rebalance de HP) — son un pack "desafío" explícitamente muy difícil, no un
tutorial. Los niveles-figura (`cells`) solo dejan ~3 turnos de margen antes de la fila del
molcajete (6 filas de contenido, ver PASO 3 de SKILL.md) — con HP tan alto eso es un reto
real; starting_seeds se subió generoso (200, muy por encima de
starting_seeds_for_level(100)=110) para darle una chance genuina, pero sigue siendo un
ajuste de buena fe sin playtesting (ver idea-base.md).
"""
import json
import os
import random

from gen_levels import cells_from_ascii, sprinkle_icons, totopo_hp_max_for_level, totopo_hp_min_for_level

CHALLENGE_LEVEL_REF: int = 100  ## nivel de referencia para el rango de HP (ver docstring)
CHALLENGE_HP_MIN: int = totopo_hp_min_for_level(CHALLENGE_LEVEL_REF)
CHALLENGE_HP_MAX: int = totopo_hp_max_for_level(CHALLENGE_LEVEL_REF)
CHALLENGE_SEEDS: int = 200  ## generoso a propósito — solo ~3 turnos de margen (ver arriba)

BALL_ART = """
.XXXXX.
XXXXXXX
XXXXXXX
XXXXXXX
XXXXXXX
.XXXXX.
"""

TROPHY_ART = """
XX...XX
.XXXXX.
..XXX..
..XXX..
.XXXXX.
XXXXXXX
"""

GOAL_ART = """
X.....X
X.....X
X.....X
X.....X
XXXXXXX
XXXXXXX
"""

JERSEY_ART = """
X.....X
XX...XX
.XXXXX.
.XXXXX.
.XXXXX.
.XXXXX.
"""

FLAG_CHECKER_ART = """
X.X.X.X
.X.X.X.
X.X.X.X
.X.X.X.
X.X.X.X
.X.X.X.
"""

WHISTLE_ART = """
....XXX
...X..X
.XXXXXX
XXXXXXX
XXXXXXX
.XXXXX.
"""

BOOT_ART = """
XXX....
XXXXXX.
XXXXXXX
XXXXXXX
..XXXXX
.XXXXXX
"""

STOPWATCH_ART = """
...X...
..XXX..
.XXXXX.
XXXXXXX
XXXXXXX
.XXXXX.
"""

FLAG_WAVING_ART = """
X......
XXXXXXX
X.XXXX.
XXXXXX.
X..XXX.
X......
"""

MEDAL_ART = """
..X.X..
..X.X..
.XXXXX.
XXXXXXX
XXXXXXX
.XXXXX.
"""

PACK = [
    ("worldcup_001", "ball", BALL_ART, True),
    ("worldcup_002", "trophy", TROPHY_ART, True),
    ("worldcup_003", "goal", GOAL_ART, True),
    ("worldcup_004", "jersey", JERSEY_ART, False),
    ("worldcup_005", "flag_checker", FLAG_CHECKER_ART, True),
    ("worldcup_006", "whistle", WHISTLE_ART, True),
    ("worldcup_007", "boot", BOOT_ART, True),
    ("worldcup_008", "stopwatch", STOPWATCH_ART, True),
    ("worldcup_009", "flag_waving", FLAG_WAVING_ART, False),
    ("worldcup_010", "medal", MEDAL_ART, True),
]


def generate_worldcup_level(level_id: str, shape_id: str, art: str, fill: bool, rng: random.Random) -> dict:
    cells = cells_from_ascii(art, kind="totopo", hp=1, fill=fill)
    for cell in cells:
        cell["hp"] = rng.randint(CHALLENGE_HP_MIN, CHALLENGE_HP_MAX)  ## variado, no fijo
    cells = sprinkle_icons(cells)
    return {
        "id": level_id,
        "name": f"LEVEL_NAME_{shape_id.upper()}",
        "starting_seeds": CHALLENGE_SEEDS,
        "cells": cells,
    }


def main() -> None:
    out_dir = "data/levels"
    os.makedirs(out_dir, exist_ok=True)

    new_ids = []
    print("=== Pack Mundial (worldcup_001-010) ===")
    for i, (level_id, shape_id, art, fill) in enumerate(PACK):
        rng = random.Random(5000 + i)  ## determinista por nivel, mismo patrón que gen_levels.py
        level = generate_worldcup_level(level_id, shape_id, art, fill, rng)
        path = os.path.join(out_dir, f"{level_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        new_ids.append(level_id)
        mode = "relleno" if fill else "silueta"
        hps = [c["hp"] for c in level["cells"] if "hp" in c]
        hp_range = f"{min(hps)}-{max(hps)}" if hps else "n/a"
        print(f"  + {path} ({shape_id}, {mode}, {len(level['cells'])} celdas, HP {hp_range})")

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

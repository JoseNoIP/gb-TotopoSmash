#!/usr/bin/env python3
"""Genera los niveles de Totopo Smash (data/levels/) + su manifiesto.

Uso: python3 tools/gen_levels.py

Regla (paralela a la #36 de gen_assets.py sobre assets): NO editar a mano un nivel que
este script regenera sin también actualizar su spec aquí — si no, la próxima corrida
completa lo pisa. Niveles hechos por la skill /level-designer se editan directo y se
agregan a mano al manifiesto; ese es el mecanismo pensado para packs temáticos.

Los niveles procedurales (1-94) producen un `row_queue` totalmente concreto en tiempo de
generación (nivel 1 = 10 filas, +3 por nivel hasta un tope de 50 — ver
total_rows_for_level) — Modo Nivel en runtime no depende de ningún RNG (mismo tablero
para todos los jugadores) y revela una fila nueva por turno hasta agotar la cola. El tope
existe para respetar la "sesión target: 2-5 minutos" del GDD: dejar crecer las filas sin
límite habría hecho que un nivel alto tomara cientos de turnos.

Dos escalas de dificultad INDEPENDIENTES, a propósito:
- `effective_wave` (portada de src/features/board/wave_scaling.gd) sigue gobernando SOLO
  qué tipos de bloque pueden aparecer y con qué probabilidad — introducción gradual de
  queso/triángulo/salsa (oleada 6+) y piedra (oleada 16+), igual que Modo Infinito.
- `totopo_hp_max_for_level()`/`totopo_hp_min_for_level()` (pedido explícito del usuario)
  escalan el HP directamente con el NÚMERO DE NIVEL, no con `effective_wave`: nivel 1 va de
  10 a 50 golpes, nivel 100 de 60 a 300, sigue creciendo igual más allá de 100 (sin tope).
  CADA bloque sortea su propio HP dentro de ese rango (`random_totopo_hp()`, determinista
  vía la seed del nivel) — no todos los bloques del nivel comparten un solo valor fijo.
  `starting_seeds_for_level()` crece con la misma curva para compensar — sin esto, los
  niveles bajos serían virtualmente imposibles de limpiar con solo ~12 semillas contra
  bloques de hasta 50 golpes.

Los niveles-figura (95-100) se dibujan a mano en un grid ASCII de 7 columnas y se
convierten a `cells` absolutas (toda la forma visible desde el inicio), en SILUETA (solo
borde) o RELLENO (toda celda) — HP bajo fijo (no usa las escalas de arriba), sin cambios.
"""
import json
import os
import random

GRID_COLS = 7

# --- Niveles procedurales: probabilidades portadas de wave_scaling.gd ------------------
# `effective_wave` gobierna SOLO qué tipos de bloque pueden aparecer y con qué
# probabilidad (introducción gradual de queso/triángulo/salsa/piedra) — el HP de cada
# bloque es independiente de esto, ver queso_hp_for_level()/totopo_hp_for_level() más abajo.


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


TOTAL_ROWS_START: int = 10
TOTAL_ROWS_STEP: int = 3
TOTAL_ROWS_CAP: int = 50

def total_rows_for_level(level_number: int) -> int:
    """Nivel 1 = 10 filas totales (pedido explícito del usuario), crece +3 por nivel
    hasta un tope de 50 (nivel 14 en adelante) — sin tope, un roster de ~100 niveles
    llegaría a cientos de filas en los últimos, violando la sesión de 2-5 minutos del GDD.
    Ajustable aquí sin tocar nada más."""
    return min(TOTAL_ROWS_START + (level_number - 1) * TOTAL_ROWS_STEP, TOTAL_ROWS_CAP)


# --- HP por bloque: escala con el NÚMERO DE NIVEL, no con effective_wave (pedido
# explícito del usuario) — nivel 1 va de 10 a 50 golpes (VARIADO, no el mismo valor en
# todos los bloques), nivel 100 va de 60 a 300, y sigue creciendo igual de ahí en adelante
# (sin tope, a diferencia de total_rows_for_level). El HP de cada bloque se sortea (con la
# misma seed por nivel, así que sigue siendo 100% determinista/reproducible) dentro de ese
# rango — no todos los bloques del nivel comparten un solo valor fijo.
# La escala ancla en TOTOPO, no en queso: queso/triángulo/salsa recién desbloquean en
# oleada 6+ (nivel 11+, ver pick_kind), así que el nivel 1 solo tiene totopos — si el tope
# de 50 se aplicara a queso, el nivel 1 real nunca llegaría a mostrarlo. Igual que en
# wave_scaling.gd, totopo ES la escala base y queso es un múltiplo de esa base (1.5x).
TOTOPO_HP_MAX_START: float = 50.0
TOTOPO_HP_MAX_AT_100: float = 300.0
TOTOPO_HP_MAX_STEP: float = (TOTOPO_HP_MAX_AT_100 - TOTOPO_HP_MAX_START) / 99.0  # ~2.525/nivel
TOTOPO_HP_MIN_RATIO: float = 0.2  # HP mínimo = este % del HP máximo del nivel (10/50 en nivel 1)


def totopo_hp_max_for_level(level_number: int) -> int:
    """Tope real de golpes del nivel (lo que se ve en el bloque más resistente)."""
    return max(1, round(TOTOPO_HP_MAX_START + (level_number - 1) * TOTOPO_HP_MAX_STEP))


def totopo_hp_min_for_level(level_number: int) -> int:
    return max(1, round(totopo_hp_max_for_level(level_number) * TOTOPO_HP_MIN_RATIO))


def random_totopo_hp(level_number: int, rng: random.Random) -> int:
    """HP de UN bloque totopo/salsa/triángulo — sorteado dentro del rango del nivel, no un
    valor fijo repetido en todos los bloques. Determinista: `rng` ya trae la seed del nivel."""
    lo = totopo_hp_min_for_level(level_number)
    hi = totopo_hp_max_for_level(level_number)
    return rng.randint(lo, hi)


def queso_hp_for_base(base_hp: int) -> int:
    """Queso = 1.5x el HP base sorteado para ESE bloque (misma proporción que
    wave_scaling.gd) — no aparece hasta la oleada 6+ (nivel 11+), pero cuando lo hace
    también varía bloque a bloque, igual que totopo."""
    return max(1, round(base_hp * 1.5))


# --- Semillas iniciales: deben crecer en proporción al HP para que el nivel siga siendo
# jugable — con bloques de hasta 50 golpes desde el nivel 1, quedarse en las ~12 semillas
# de antes volvería el nivel prácticamente imposible de limpiar. Mismo patrón lineal que
# el HP, para que la curva de dificultad se sienta consistente en todo el roster.
SEEDS_START: float = 30.0
SEEDS_AT_100: float = 110.0
SEEDS_STEP: float = (SEEDS_AT_100 - SEEDS_START) / 99.0


def starting_seeds_for_level(level_number: int) -> int:
    return max(1, round(SEEDS_START + (level_number - 1) * SEEDS_STEP))


def generate_procedural_level(level_number: int) -> dict:
    """row_queue 100% concreto (sin RNG en runtime) — se hornea aquí, una sola vez.
    Nivel de dificultad progresiva: arranca mostrando 1 fila y el resto se revela de a
    poco (una fila nueva por turno, igual que Modo Infinito) hasta agotar la cola —
    nunca coloca todo el contenido de una vez (eso es lo que hacen las figuras/`cells`)."""
    rng = random.Random(1000 + level_number)
    # effective_wave sigue gobernando solo qué tipos de bloque pueden aparecer (ver arriba)
    # — el HP ya no depende de esto, se sortea por bloque con random_totopo_hp().
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
                cell["hp"] = queso_hp_for_base(random_totopo_hp(level_number, rng))
            elif kind in ("totopo", "salsa"):
                cell["hp"] = random_totopo_hp(level_number, rng)
            elif kind == "triangle":
                cell["hp"] = random_totopo_hp(level_number, rng)
                cell["corner"] = rng.randint(0, 3)
            row_cells.append(cell)
        row_queue.append(row_cells)

    level_id = f"level_{level_number:03d}"
    return {
        "id": level_id,
        "starting_seeds": starting_seeds_for_level(level_number),
        "row_queue": row_queue,
    }


# --- Niveles-figura: ASCII (7 columnas) -> celdas --------------------------------------


## `level_number`/`rng` (no un `hp` fijo): bug real reportado por el usuario ("en el pack
## de navidad todos los bloques tienen 1") — con el mismo motivo por el que
## random_totopo_hp() existe para los niveles procedurales (nunca el mismo valor repetido
## en todos los bloques), esta función también debe sortear el HP de cada celda dentro del
## rango del nivel pedido, no recibir un número fijo. Afectaba por igual a los niveles
## 95-100 (figuras Cruz/Corazón/Botella/Estrella/Diamante/Carita Feliz del roster numérico
## — encontrado al investigar el reporte del pack navideño, mismo código compartido) y al
## pack navideño. `rng=None` construye una determinista propia a partir de `level_number`
## si quien llama no necesita más de un nivel con seeds distintos (ver
## generate_shape_level() vs. gen_holiday_pack.py, que sí pasa su propio rng por seed).
def cells_from_ascii(
    art: str, kind: str = "totopo", level_number: int = 1, fill: bool = True,
    rng: "random.Random | None" = None
) -> list:
    rng = rng or random.Random(level_number)
    needs_hp = kind in ("totopo", "queso", "salsa", "triangle")
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
            cell = {"col": c, "row": r, "kind": kind}
            if needs_hp:
                cell["hp"] = random_totopo_hp(level_number, rng)
            cells.append(cell)
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


## Bug real corregido (encontrado al investigar un reporte del pack navideño, mismo
## código compartido): antes usaba hp=1 fijo y starting_seeds=16 fijo para las 6 figuras,
## sin relación con el número de nivel — violaba la regla ya documentada "HP por bloque en
## Modo Nivel escala con el NÚMERO DE NIVEL" que sí aplicaba correctamente a los niveles
## 1-94 (procedurales). Ahora usa random_totopo_hp()/starting_seeds_for_level() con SU
## PROPIO level_number (95-100), igual que el resto del roster.
def generate_shape_level(level_number: int, shape_id: str, art: str, fill: bool) -> dict:
    rng = random.Random(level_number)
    cells = cells_from_ascii(art, kind="totopo", level_number=level_number, fill=fill, rng=rng)
    cells = sprinkle_icons(cells)
    return {
        "id": f"level_{level_number:03d}",
        "name": f"LEVEL_NAME_{level_number:03d}",  # key de i18n: "Cruz", "Corazón", etc.
        "starting_seeds": starting_seeds_for_level(level_number),
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


PROCEDURAL_COUNT: int = 94  # + 6 niveles-figura = 100 (objetivo del GDD)


def main() -> None:
    out_dir = "data/levels"
    os.makedirs(out_dir, exist_ok=True)

    level_ids = []

    print(f"=== Niveles procedurales (1-{PROCEDURAL_COUNT}) ===")
    for n in range(1, PROCEDURAL_COUNT + 1):
        level = generate_procedural_level(n)
        path = os.path.join(out_dir, f"{level['id']}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        level_ids.append(level["id"])
        print(
            f"  + {path} ({len(level['row_queue'])} filas en cola, "
            f"{level['starting_seeds']} semillas)"
        )

    print(f"\n=== Niveles-figura ({PROCEDURAL_COUNT + 1}-{PROCEDURAL_COUNT + 6}) ===")
    for i, (shape_id, art, fill) in enumerate(SHAPE_LEVELS):
        n = PROCEDURAL_COUNT + 1 + i
        level = generate_shape_level(n, shape_id, art, fill)
        path = os.path.join(out_dir, f"{level['id']}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(level, f, ensure_ascii=False, indent=2)
        level_ids.append(level["id"])
        mode = "relleno" if fill else "silueta"
        print(f"  + {path} ({shape_id}, {mode}, {len(level['cells'])} celdas)")

    ## Bug real encontrado: este script sobreescribía manifest.json completo, borrando las
    ## entradas de los packs temáticos (holiday_00N/worldcup_00N) que gen_holiday_pack.py /
    ## gen_worldcup_pack.py ya habían agregado — sus archivos .json seguían en disco pero
    ## dejaban de estar en el manifiesto (invisibles en el juego) en cuanto se corría este
    ## script de nuevo. Fix: preservar cualquier id existente que NO empiece con "level_"
    ## (es un pack, no algo que este script genere) al final de la lista regenerada.
    manifest_path = os.path.join(out_dir, "manifest.json")
    existing_pack_ids = []
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            existing_manifest = json.load(f)
        existing_pack_ids = [
            lid for lid in existing_manifest.get("levels", []) if not lid.startswith("level_")
        ]
    level_ids.extend(existing_pack_ids)
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump({"levels": level_ids}, f, ensure_ascii=False, indent=2)
    print(f"\n  + {manifest_path} ({len(level_ids)} niveles, {len(existing_pack_ids)} de packs preservados)")


if __name__ == "__main__":
    main()

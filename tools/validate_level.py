#!/usr/bin/env python3
"""Valida uno o más niveles de Totopo Smash sin necesitar levantar Godot.

Uso:
    python3 tools/validate_level.py data/levels/level_005.json
    python3 tools/validate_level.py data/levels/*.json

Espejo en Python de src/features/levels/level_loader.gd::validate_level() — mismas
reglas, para que la skill /level-designer pueda revisar un nivel nuevo antes de correr
la suite GUT real (tests/unit/test_level_manifest_integrity.gd es la autoridad final).
"""
import json
import sys

GRID_COLS = 7
MOLCAJETE_ROW = 8  # Constants.MOLCAJETE_ROW (GRID_ROWS=9, última fila)
MAX_CONTENT_ROW = MOLCAJETE_ROW - 1

KNOWN_KINDS = {"totopo", "queso", "salsa", "stone", "triangle", "lemon", "seed_extra", "laser"}
KINDS_NEEDING_HP = {"totopo", "queso", "salsa", "triangle"}


def _is_whole_number(value) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return True
    return isinstance(value, float) and value == int(value)


def validate_level(data: dict, expected_id: str) -> list:
    errors = []
    if not data:
        return ["nivel vacío o no se pudo parsear"]

    level_id = data.get("id")
    if not isinstance(level_id, str) or not level_id:
        errors.append("falta 'id' o no es string")
    elif level_id != expected_id:
        errors.append(f"'id' ({level_id}) no coincide con el nombre de archivo esperado ({expected_id})")

    starting_seeds = data.get("starting_seeds")
    if not _is_whole_number(starting_seeds) or int(starting_seeds) <= 0:
        errors.append("'starting_seeds' debe ser un entero > 0")

    is_static = data.get("static", False) is True
    max_col = GRID_COLS - 1
    max_row = MAX_CONTENT_ROW
    if is_static:
        grid_cols = data.get("grid_cols")
        if not _is_whole_number(grid_cols) or int(grid_cols) <= 0:
            errors.append("nivel 'static' requiere 'grid_cols' entero > 0")
        else:
            max_col = int(grid_cols) - 1
        grid_rows = data.get("grid_rows")
        if not _is_whole_number(grid_rows) or int(grid_rows) <= 0:
            errors.append("nivel 'static' requiere 'grid_rows' entero > 0")
        else:
            max_row = int(grid_rows) - 1
        if "par_turns" in data:
            par_turns = data.get("par_turns")
            if not _is_whole_number(par_turns) or int(par_turns) <= 0:
                errors.append("'par_turns' debe ser un entero > 0 si está presente")

    cells = data.get("cells", [])
    row_queue = data.get("row_queue", [])
    has_cells = isinstance(cells, list) and len(cells) > 0
    has_queue = isinstance(row_queue, list) and len(row_queue) > 0
    if not has_cells and not has_queue:
        errors.append("el nivel no tiene contenido — 'cells' y 'row_queue' están vacíos o ausentes")
        return errors
    if is_static and has_queue:
        errors.append("un nivel 'static' no puede combinarse con 'row_queue'")

    if "cells" in data:
        if not isinstance(cells, list):
            errors.append("'cells' debe ser una lista")
        else:
            seen_positions = set()
            for i, cell in enumerate(cells):
                if not isinstance(cell, dict):
                    errors.append(f"cells[{i}]: no es un objeto")
                    continue
                errors.extend(
                    _validate_cell(cell, f"cells[{i}]", True, seen_positions, max_col, max_row)
                )

    if "row_queue" in data:
        if not isinstance(row_queue, list):
            errors.append("'row_queue' debe ser una lista")
        else:
            for r, row_cells in enumerate(row_queue):
                if not isinstance(row_cells, list):
                    errors.append(f"row_queue[{r}]: debe ser una lista")
                    continue
                if len(row_cells) > GRID_COLS:
                    errors.append(f"row_queue[{r}]: más celdas que columnas tiene el tablero")
                seen_cols = set()
                for i, cell in enumerate(row_cells):
                    if not isinstance(cell, dict):
                        errors.append(f"row_queue[{r}][{i}]: no es un objeto")
                        continue
                    errors.extend(
                        _validate_cell(
                            cell, f"row_queue[{r}][{i}]", False, seen_cols,
                            GRID_COLS - 1, MAX_CONTENT_ROW
                        )
                    )

    return errors


def _validate_cell(
    cell: dict, label: str, require_row: bool, seen_positions: set, max_col: int, max_row: int
) -> list:
    errors = []

    col = cell.get("col")
    col_ok = _is_whole_number(col) and 0 <= int(col) <= max_col
    if not col_ok:
        errors.append(f"{label}: 'col' fuera de rango [0, {max_col}]")

    if require_row:
        row = cell.get("row")
        row_ok = _is_whole_number(row) and 0 <= int(row) <= max_row
        if not row_ok:
            errors.append(f"{label}: 'row' fuera de rango [0, {max_row}]")
        if col_ok and row_ok:
            pos_key = (int(col), int(row))
            if pos_key in seen_positions:
                errors.append(f"{label}: posición {pos_key} duplicada")
            seen_positions.add(pos_key)
    elif col_ok:
        if int(col) in seen_positions:
            errors.append(f"{label}: columna {int(col)} duplicada en la misma fila")
        seen_positions.add(int(col))

    kind = cell.get("kind")
    if not isinstance(kind, str) or kind not in KNOWN_KINDS:
        errors.append(f"{label}: 'kind' desconocido: {kind!r}")
        return errors

    if kind in KINDS_NEEDING_HP:
        hp = cell.get("hp")
        if not _is_whole_number(hp) or int(hp) <= 0:
            errors.append(f"{label}: kind '{kind}' requiere 'hp' entero > 0")

    if kind == "triangle":
        corner = cell.get("corner")
        if not _is_whole_number(corner) or not (0 <= int(corner) <= 3):
            errors.append(f"{label}: kind 'triangle' requiere 'corner' entero en [0,3]")

    if kind == "laser" and "orientation" in cell:
        orientation = cell.get("orientation")
        if orientation not in ("horizontal", "vertical"):
            errors.append(f"{label}: 'orientation' de laser debe ser 'horizontal' o 'vertical'")

    return errors


def main() -> None:
    if len(sys.argv) < 2:
        print("Uso: python3 tools/validate_level.py <archivo.json> [...]")
        sys.exit(1)

    any_errors = False
    for path in sys.argv[1:]:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        expected_id = path.split("/")[-1].removesuffix(".json")
        errors = validate_level(data, expected_id)
        if errors:
            any_errors = True
            print(f"x {path}")
            for err in errors:
                print(f"    - {err}")
        else:
            print(f"+ {path}: OK")

    sys.exit(1 if any_errors else 0)


if __name__ == "__main__":
    main()

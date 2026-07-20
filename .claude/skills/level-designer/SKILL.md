---
name: level-designer
description: Diseña niveles nuevos para Totopo Smash (Modo Nivel) a partir de una descripción en lenguaje natural — figuras ("un corazón", "una cruz"), packs temáticos, o niveles de dificultad estándar. Escribe el JSON del nivel y lo registra en el manifiesto.
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
---

## /level-designer — Diseño de niveles para Modo Nivel

Genera un nivel nuevo (o varios, para un pack temático) para Totopo Smash: un tablero
finito y determinista — todos los jugadores ven exactamente el mismo contenido, a
diferencia de Modo Infinito (aleatorio, `wave_scaling.gd`).

---

### PASO 0 — Contexto imprescindible antes de escribir nada

Leer:
- `src/features/levels/level_loader.gd` — la validación real (`validate_level()`), fuente de verdad del esquema.
- `src/features/board/cell_factory.gd` — `KNOWN_KINDS`, la lista blanca de `kind` permitidos.
- Dos o tres niveles reales en `data/levels/` (ej. `level_001.json` y `level_016.json`, un procedural y un nivel-figura) para ver el formato en la práctica.
- `data/levels/manifest.json` — el orden de juego real.

---

### PASO 1 — El esquema (autoridad: `level_loader.gd`)

```json
{
  "id": "level_021",
  "name": "LEVEL_NAME_021",
  "starting_seeds": 14,
  "cells": [
    { "col": 3, "row": 0, "kind": "totopo", "hp": 3 },
    { "col": 2, "row": 1, "kind": "queso", "hp": 4 },
    { "col": 4, "row": 1, "kind": "triangle", "hp": 2, "corner": 1 },
    { "col": 0, "row": 2, "kind": "stone" },
    { "col": 6, "row": 0, "kind": "lemon" },
    { "col": 1, "row": 0, "kind": "seed_extra" }
  ]
}
```

| Campo | Regla |
|---|---|
| `id` | String única en TODO `manifest.json`, debe ser igual al nombre de archivo sin `.json`. |
| `name` | Opcional — key de i18n (ver PASO 4), se omite en niveles sin nombre propio. |
| `starting_seeds` | Entero > 0. |
| `cells` | Array disperso — solo listar celdas ocupadas, no hace falta rellenar vacíos. |
| `cells[].col` | Entero en `[0, 6]`. |
| `cells[].row` | Entero en `[0, 7]`. **NUNCA 8** (`Constants.MOLCAJETE_ROW`) — sería game over instantáneo en el primer turno. |
| `cells[].kind` | Uno de `KNOWN_KINDS` en `cell_factory.gd`: `totopo`, `queso`, `salsa`, `stone`, `triangle`, `lemon`, `seed_extra`, `laser`. **Nunca inventar un kind nuevo sin agregar antes su constante en `wave_scaling.gd` + su caso en `cell_factory.gd` + su clase de bloque/ícono.** |
| `cells[].hp` | Requerido para `totopo`/`queso`/`salsa`/`triangle`. Ausente/ignorado en `stone`/`lemon`/`seed_extra`. |
| `cells[].corner` | Requerido SOLO para `triangle`, entero `[0,3]` = **esquina que se RECORTA** (0=arriba-izq, 1=arriba-der, 2=abajo-der, 3=abajo-izq) — no la punta. Si no importa la orientación, usar cualquier valor fijo; no hay penalización por repetir el mismo corner en varias celdas. |

Un `Dictionary`/objeto por celda; no hay límite de cuántas celdas puede tener un nivel,
pero ver PASO 3 sobre cuántas filas son jugables.

**`cells` es para figuras** — toda la forma visible desde el inicio, nunca cambia. Para
niveles de **dificultad progresiva** (no-figura) existe un segundo mecanismo, `row_queue`,
que revela una fila nueva por turno igual que Modo Infinito pero con contenido fijo:

```json
{
  "id": "level_003",
  "starting_seeds": 14,
  "row_queue": [
    [ { "col": 2, "kind": "totopo", "hp": 2 }, { "col": 5, "kind": "queso", "hp": 3 } ],
    [ { "col": 0, "kind": "totopo", "hp": 2 }, { "col": 3, "kind": "lemon" } ]
  ]
}
```

| Campo | Regla |
|---|---|
| `row_queue` | Array de filas; cada fila es un array de celdas. La fila 0 de la cola se revela al iniciar el nivel, la siguiente al terminar el turno 1, etc. — el nivel se gana cuando la cola se agota Y no queda ningún bloque destructible en el tablero. |
| `row_queue[][].col` | Entero en `[0, 6]`. **Sin `row`** — es implícito, siempre "la próxima fila que aparece arriba" (fila 0 del tablero). |
| `row_queue[][].kind`/`hp`/`corner` | Mismas reglas que en `cells`. |
| Duplicados | Se valida por columna repetida DENTRO de la misma fila de la cola, no por `(col,row)` global (no tiene row explícito). |

Un nivel puede combinar ambos (`cells` para algo fijo de fondo + `row_queue` para
contenido que va bajando), pero lo normal es usar solo uno: `cells` para figuras,
`row_queue` para dificultad progresiva. Al menos uno de los dos debe tener contenido.

**Tercer mecanismo: `"static": true`** — figuras de ALTA resolución (cientos de bloques,
grilla propia más angosta que el tablero normal). Incompatible con `row_queue`.

```json
{
  "id": "worldcup_004",
  "static": true,
  "grid_cols": 30,
  "starting_seeds": 50,
  "par_turns": 80,
  "cells": [
    { "col": 12, "row": 3, "kind": "totopo", "hp": 120 },
    { "col": 5, "row": 40, "kind": "laser", "orientation": "vertical" }
  ]
}
```

| Campo | Regla |
|---|---|
| `static` | `true` activa el modo — bloques que NUNCA se desplazan y sin condición de derrota (se gana despejando todo lo destructible, sin importar los turnos). |
| `grid_cols` | **Obligatorio** si `static`. Entero > 0 — número de columnas de la grilla PROPIA de este nivel (nada que ver con `Constants.GRID_COLS=7`; entre más grande, más bloques más chicos caben en el mismo ancho de pantalla). `tools/gen_worldcup_pack.py` usa 22-50 según la forma. |
| `cells[].col` (en `static`) | Entero en `[0, grid_cols-1]` — NO `[0,6]` como en niveles normales. |
| `cells[].row` (en `static`) | Cualquier entero >= 0 (tope defensivo 300) — NO limitado a `Constants.MOLCAJETE_ROW`, no hay fila de molcajete prohibida porque no hay condición de derrota. |
| `par_turns` | Opcional. Si se limpia el nivel en <= este número de turnos, el score final se multiplica por `Constants.STATIC_LEVEL_PAR_BONUS_MULTIPLIER`. |
| `cells[].kind: "laser"` | Power-up nuevo — al tocarlo, daña TODA la fila (`"orientation": "horizontal"`, default) o columna (`"vertical"`) donde está. Sin `hp`. |

Ver PASO 2 para cómo rasterizar una figura de alta resolución (geometría pura o
`tools/gen_worldcup_pack.py` como referencia de un caso con Pillow para texto).

---

### PASO 2 — Rasterizar la figura pedida (sin librería de imágenes)

El tablero jugable es de **7 columnas × 8 filas** (filas 0-7; la 8 es la del molcajete,
prohibida). Para una figura ("corazón", "cruz", "botella", cualquier forma pedida en
lenguaje natural), razonar mentalmente un grid ASCII de 7×N (N ≤ 6, ver PASO 3) marcando
con `X` las celdas dentro de la figura y `.` las de afuera. Ejemplo (corazón, 7×6):

```
.XX.XX.
XXXXXXX
XXXXXXX
.XXXXX.
..XXX..
...X...
```

Esto es exactamente el mismo ejercicio ya usado para los íconos pixel-art del proyecto
(`tools/gen_assets.py`) — dibujar la forma a mano, celda por celda, con buen ojo para la
simetría y el reconocimiento de la silueta a baja resolución.

**SILUETA vs RELLENO** (el usuario elige):
- **RELLENO**: cada celda marcada `X` se convierte en una celda del nivel.
- **SILUETA**: una celda `X` se convierte en celda del nivel solo si es de **borde** —
  regla mecánica: al menos uno de sus 4 vecinos (arriba/abajo/izq/der) está FUERA de la
  figura o fuera del canvas. Las celdas `X` totalmente rodeadas de otras `X` se omiten.

Convertir cada celda resultante a `{"col": c, "row": r, "kind": "totopo", "hp": N}` por
default — variar el `kind` solo si el usuario lo pide o para variedad (ver PASO 3).

---

### PASO 3 — Defaults de dificultad y variedad

- **Filas jugables (niveles-figura, `cells`, sin `static`)**: el tablero se desplaza 1 fila
  por turno AUNQUE no aparezcan filas nuevas (`cells` se coloca todo de una vez, sin
  recarga) — así que "llegar a la fila del molcajete" sigue siendo derrota real. Un nivel
  con contenido en las filas `0..(R-1)` da al jugador `9-R` turnos antes de perder.
  **Recomendado: R ≤ 6 filas** (deja 3+ turnos de margen).
- **Filas (niveles `static`)**: NO aplica nada de lo anterior — no hay condición de
  derrota, así que la figura puede ocupar todas las filas que necesite (limitado solo por
  que la altura total en píxeles quepa en pantalla: `filas × (DESIGN_WIDTH/grid_cols)` no
  debería superar ~650-700px). Elegir `grid_cols` según qué tan ancha/angosta sea la figura
  (más columnas = bloques más chicos = más detalle horizontal).
- **Filas totales (dificultad progresiva, `row_queue`)**: como cada fila se revela recién
  cuando se consume la anterior, el total de filas NO reduce el margen turno a turno —
  define cuánto dura el nivel. `tools/gen_levels.py::total_rows_for_level()` usa nivel 1 =
  10 filas, +3 por nivel siguiente, con un TOPE de 50 filas (alcanzado en el nivel 15) —
  el tope evita que los niveles más altos de un roster grande tomen cientos de turnos; de
  ahí en adelante la dificultad escala por HP/variedad de bloques, no por duración. Seguir
  esa curva para niveles nuevos de este tipo salvo que se pida otra.
- **HP (niveles-figura, `cells`)**: `totopo`/`salsa`/`triangle` con HP bajo fijo (1-3) — el
  objetivo es la satisfacción de despejar la forma, no la dificultad. NO usar las escalas
  de abajo aquí.
- **HP (dificultad progresiva, `row_queue`)**: `tools/gen_levels.py::totopo_hp_max_for_level()`/
  `totopo_hp_min_for_level()` — escala DIRECTO con el número de nivel (no con
  `effective_wave`, que sigue gobernando solo qué tipos de bloque pueden aparecer): nivel 1
  va de 10 a 50 golpes, nivel 100 de 60 a 300, sin tope superior más allá de eso (pedido
  explícito del usuario, ver idea-base.md). **Cada bloque sortea su propio HP dentro de ese
  rango** vía `random_totopo_hp(level_number, rng)` — NUNCA el mismo valor fijo repetido en
  todos los bloques del nivel (corrección explícita del usuario: la primera versión hacía
  justo eso y no era lo pedido). Queso siempre 1.5x el HP sorteado de ESE bloque
  (`queso_hp_for_base()`, misma proporción que `wave_scaling.gd`), no un valor de queso
  fijo aparte. `starting_seeds_for_level()` escala con la misma curva para que la cantidad
  de semillas siga siendo consistente con el HP — un nivel nuevo de este tipo debe usar
  estas funciones juntas, nunca HP alto con semillas bajas a mano.
- **HP (niveles `static`)**: alto y variado (60-300 por bloque es el precedente del pack
  Mundial v2, sorteado con `rng.randint(HP_MIN, HP_MAX)` — nunca fijo, mismo criterio que
  `row_queue`) — como no hay condición de derrota, "difícil" solo significa "toma más
  turnos", no "imposible", así que hay más margen para HP alto que en los otros dos tipos.
- **Variedad**: sembrar `lemon`/`seed_extra` en ~10-15% de las celdas destructibles (nunca
  en TODAS — pierden gracia). En niveles `static`, sembrar además en los HUECOS (celdas
  vacías dentro del recuadro de la figura, no parte de la silueta) — incluir algo de
  `laser` ahí también (pedido explícito del usuario), no solo dentro de la silueta.
- **`stone`**: NUNCA usarlo salvo que el usuario lo pida explícitamente — es indestructible y bloquea el clear si se coloca sin cuidado (el nivel nunca se puede ganar si hay piedra bloqueando el único camino... en realidad la piedra no cuenta para el clear, así que no bloquea el WIN, pero si "atrapa" visualmente otros bloques detrás de un patrón imposible de alcanzar por geometría, sí podría volver el nivel injugable en la práctica).
- **`starting_seeds`**: generoso para niveles-figura con muchas celdas (14-20); más ajustado para niveles de dificultad progresiva. En niveles `static` puede ser más bajo (50 en el pack Mundial v2) porque no hay presión de tiempo — el jugador puede tomarse los turnos que necesite.

---

### PASO 4 — Guardar el archivo + registrar en el manifiesto

1. Elegir un `id`:
   - Roster principal: `level_0NN` (siguiente número libre en `manifest.json`).
   - Pack temático (ej. navideño): namespace propio, `holiday_001`, `holiday_002`, ... — no reutilizar `level_0NN` para packs, para no chocar con el roster principal si crece. **`LevelSelectScreen._is_pack_level()` decide qué es un pack por este prefijo** — cualquier id que NO empiece con `level_` se muestra en la sección "PACKS ESPECIALES" y queda SIEMPRE desbloqueado (sin depender de `highest_level_unlocked`, ver regla siguiente).
2. Escribir `data/levels/<id>.json` directo con `Write` (JSON con indentación de 2 espacios, UTF-8, sin BOM — igual que los generados por `tools/gen_levels.py`).
3. Si el nivel tiene `name`, agregar la key de traducción a `assets/translations/translations.txt` (es/en/pt_BR/fr — ver skill `/mobile-i18n` para el formato CSV con comillas si el texto lleva comas).
4. Agregar el `id` a `data/levels/manifest.json` en la posición pedida (default: al final del array). `tools/gen_levels.py::main()` ya preserva cualquier id que no empiece con `level_` al regenerarse (bug real corregido: antes sobreescribía el manifiesto completo y borraba los packs agregados a mano) — sigue siendo buena práctica no correrlo sin necesidad, pero ya no destruye packs existentes si se corre.

---

### PASO 5 — Validar antes de dar por terminado

```bash
python3 tools/validate_level.py data/levels/<id>.json
```

Si pasa, correr también la suite real (autoridad final, valida TODO el catálogo):

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=2
```

`tests/unit/test_level_manifest_integrity.gd` recorre cada id del manifiesto real y
falla si algo no valida — es la única prueba que hay que ver en verde para confirmar que
el nivel nuevo (y el manifiesto actualizado) quedaron bien.

---

### Checklist

- [ ] `id` único en todo `manifest.json`, igual al nombre de archivo.
- [ ] Ninguna celda en `row: 8` (fila del molcajete) — NO aplica a niveles `static`.
- [ ] Todo `kind` existe en `CellFactoryGd.KNOWN_KINDS` — si es nuevo, se agregó su caso ahí primero.
- [ ] `hp` presente en totopo/queso/salsa/triangle; `corner` presente en triangle; `orientation` de laser (si se usa) es `"horizontal"` o `"vertical"`.
- [ ] `starting_seeds` entero > 0.
- [ ] Contenido dentro de ~6 filas (niveles-figura, `cells`) o cola de filas balanceada según `tools/gen_levels.py::total_rows_for_level()` (dificultad progresiva, `row_queue`) — NO aplica a niveles `static` (sin límite de filas).
- [ ] `row_queue[][]` sin campo `row` (implícito); duplicados validados por columna dentro de cada fila, no por posición global.
- [ ] Si `static: true`: `grid_cols` presente y > 0; `col` validado contra `grid_cols`, no contra `Constants.GRID_COLS`; sin `row_queue`.
- [ ] `python3 tools/validate_level.py` sin errores.
- [ ] `manifest.json` actualizado (no regenerado desde cero) — `tools/gen_levels.py::main()` ya preserva packs existentes si se corre, pero mejor no correrlo sin necesidad.
- [ ] Si tiene `name`, la key existe en `assets/translations/translations.txt` para los 4 idiomas.
- [ ] GUT completo en verde (en particular `test_level_manifest_integrity.gd`).

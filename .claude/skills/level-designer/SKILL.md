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

**Tercer mecanismo: `"static": true`** — figuras de ALTA resolución (decenas/cientos de
bloques, grilla propia más angosta que el tablero normal, imagen fija que NUNCA se mueve).
Incompatible con `row_queue`.

```json
{
  "id": "worldcup_004",
  "static": true,
  "grid_cols": 14,
  "grid_rows": 20,
  "starting_seeds": 50,
  "par_turns": 80,
  "cells": [
    { "col": 12, "row": 3, "kind": "totopo", "hp": 120 },
    { "col": 5, "row": 12, "kind": "laser", "orientation": "vertical" }
  ]
}
```

| Campo | Regla |
|---|---|
| `static` | `true` activa el modo — bloques que NUNCA se desplazan y sin condición de derrota (se gana despejando todo lo destructible, sin importar los turnos). |
| `grid_cols` | **Obligatorio**. Entero > 0 — columnas de la grilla PROPIA de este nivel (nada que ver con `Constants.GRID_COLS=7`). Ver "Tamaño proporcional" más abajo — NO elegir un número arbitrario. |
| `grid_rows` | **Obligatorio** (agregado tras un bug real: un nivel sin límite de fila explícito terminó dibujándose sobre el molcajete). Entero > 0 — filas de la grilla propia. `BoardManager` usa `grid_cols`/`grid_rows` para auto-escalar el tamaño de celda (`min(ancho/grid_cols, alto_disponible/grid_rows)`) y **centrar la figura en ambos ejes** dentro del área de juego — por eso este script/skill NUNCA necesita calcular manualmente si la figura "cabe": basta con declarar cuántas columnas/filas ocupa el contenido y BoardManager garantiza que no invada el molcajete. |
| `cells[].col` (en `static`) | Entero en `[0, grid_cols-1]` — NO `[0,6]` como en niveles normales. |
| `cells[].row` (en `static`) | Entero en `[0, grid_rows-1]` — NO limitado a `Constants.MOLCAJETE_ROW` (no hay fila de molcajete prohibida, no hay condición de derrota), pero SÍ acotado por `grid_rows` de este nivel. |
| `par_turns` | Opcional. Si se limpia el nivel en <= este número de turnos, el score final se multiplica por `Constants.STATIC_LEVEL_PAR_BONUS_MULTIPLIER`. |
| `cells[].kind: "laser"` | Power-up PERSISTENTE (pedido explícito del usuario — a diferencia de lemon/seed_extra, NUNCA se libera al tocarse: sigue en el tablero y se dispara de nuevo cada vez que una semilla vuelve a entrar). Daña TODA la fila (`"orientation": "horizontal"`, default), columna (`"vertical"`), o AMBAS (`"both"` — cada bloque de esa fila O columna, un alcance mucho mayor que la cruz local de la salsa). Sin `hp`. |
| `cells[].kind: "seed_extra"` + `"amount"` | Opcional, entero > 0. Cuántas semillas otorga ESE ícono en particular — default `Constants.SEED_EXTRA_AMOUNT` (+1, pensado para Modo Infinito/campaña numérica) si se omite. Niveles `static` de exhibición (sin presión de tiempo, muchas celdas) pueden pedir bonos grandes (ej. 20-25) para que una partida completa acumule varios cientos de semillas — ver "Semillas extra abundantes" más abajo. |

**Tamaño proporcional (pedido explícito del usuario — corrige un error real de la v1 de
`gen_worldcup_pack.py`, que usaba 22-50 columnas por nivel sin relación entre sí, dando
bloques de tamaño muy inconsistente entre figuras del mismo pack):** pensar `grid_cols`
como una subdivisión de la celda normal del tablero (`Constants.GRID_COLS = 7`), no como un
número libre. `Constants.STATIC_LEVEL_DEFAULT_SUBDIVISION = 2` → **`grid_cols = 14` es el
tamaño ESTÁNDAR** para la mayoría de las figuras de un pack — mantiene el tamaño de bloque
visualmente consistente entre niveles del mismo pack. Excepción documentada: figuras que
necesitan más ancho para leerse bien (texto, escenas panorámicas como una cancha completa)
pueden usar subdivisión 3 (`grid_cols = 21`) — pero esto debe ser la excepción, no la
norma; NO variar `grid_cols` nivel a nivel "a ojo" como hacía la v1. `grid_rows` sí varía
libremente según la proporción natural de cada figura (a igual `grid_cols`, una figura alta
como un trofeo simplemente pide más `grid_rows` que una ancha como una portería) — lo que
se mantiene constante es el TAMAÑO DE CELDA (columnas), no el alto.

Ver PASO 2 para cómo rasterizar una figura de alta resolución (geometría pura — círculos,
rectángulos, perfiles paramétricos por fila — o `tools/gen_worldcup_pack.py` como
referencia de un caso con Pillow para texto). Preferir geometría pura (funciones
matemáticas de `(col,row) -> dentro/fuera de la figura`) sobre ASCII a mano en este nivel
de resolución — a 14+ columnas dibujar el ASCII celda por celda ya no es práctico.

**Elementos decorativos (pedido explícito: "que no se vean tan vacíos"):** una figura
sola dentro de su bounding box suele dejar mucho margen vacío alrededor. Sembrar 2-5
acentos chicos (ej. una mini-estrella de 5 celdas en cruz) en el margen, sin superponerse a
la silueta principal — ver `_add_decorations()` en `tools/gen_worldcup_pack.py` como
referencia. Dejar `MARGIN_CELLS` (2 celdas) de padding entre el borde del `grid_cols` x
`grid_rows` y el bounding box real de la figura, para que estos acentos tengan dónde ir sin
quedar pegados al borde del canvas.

**Puntos de entrada (pedido explícito: "que el jugador acierte a ese punto para entrar a
la figura y poder destruirla desde adentro"):** en vez de sembrar power-ups SOLO en el
fondo/huecos fuera de la silueta, reemplazar algunas celdas realmente INTERIORES de la
figura (celdas con sus 4 vecinos —arriba/abajo/izq/der— también rellenos, es decir
inalcanzables en línea recta desde afuera) por `lemon`/`seed_extra`/`laser` en vez de
`totopo`. El jugador tiene que abrirse paso destruyendo bloques hasta llegar exactamente a
esa celda para "entrar" — ver `_interior_entry_points()` en `tools/gen_worldcup_pack.py`.
No todas las figuras tienen celdas interiores así (un marco delgado como una portería o un
patrón muy fragmentado como una bandera a cuadros puede no tener ninguna) — está bien que
esas figuras terminen con 0 puntos de entrada, no forzarlo artificialmente.

**Dos tipos de pack — declarar SIEMPRE cuál(es) usa un pack nuevo, pedido explícito del
usuario:**

| Tipo | Mecanismo | Cuándo usarlo |
|---|---|---|
| 1. Bloques descendentes | `row_queue` (o `cells` de baja resolución que se desplaza igual, sin `static`) | Dificultad progresiva, presión de tiempo real, "survival" temático. |
| 2. Imagen fija | `"static": true` | Mostrar una figura/escena reconocible de una vez, sin presión de tiempo — pensado para packs visuales (ver Mundial). |

Un pack se registra en `Constants.LEVEL_PACKS` (`{"prefix":..., "name_key":...}`) — al
crear un pack nuevo, decidir explícitamente (y documentar en el mensaje de la skill al
usuario) si es tipo 1, tipo 2, o una mezcla, ANTES de generar contenido. No asumir "imagen
fija" solo porque el pack anterior (Mundial) lo usó — el tipo es una decisión de diseño por
pack, no un default global.

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
  derrota, y ya no hace falta calcular a mano si la figura "cabe" en pantalla: BoardManager
  auto-escala el tamaño de celda para que `grid_cols`×`grid_rows` siempre quepa en el área
  de juego (y centra el resultado), sin importar cuántas filas se declaren. Elegir
  `grid_rows` según la proporción NATURAL de la figura a `grid_cols` fijo (ver "Tamaño
  proporcional" en PASO 1) — no como un intento de controlar el tamaño final en pantalla.
- **Filas totales (dificultad progresiva, `row_queue`)**: como cada fila se revela recién
  cuando se consume la anterior, el total de filas NO reduce el margen turno a turno —
  define cuánto dura el nivel. `tools/gen_levels.py::total_rows_for_level()` usa nivel 1 =
  10 filas, +3 por nivel siguiente, con un TOPE de 50 filas (alcanzado en el nivel 15) —
  el tope evita que los niveles más altos de un roster grande tomen cientos de turnos; de
  ahí en adelante la dificultad escala por HP/variedad de bloques, no por duración. Seguir
  esa curva para niveles nuevos de este tipo salvo que se pida otra.
- **HP (niveles-figura, `cells`, no-`static`)**: **CORREGIDO — ya NO usar HP bajo fijo.**
  La guía original de este documento decía "1-3 fijo, el objetivo es la satisfacción de
  despejar la forma, no la dificultad" — eso es exactamente lo que causó un bug real
  reportado por el usuario ("en el pack de navidad todos los bloques tienen 1"): sin
  variedad real, se siente plano/roto, no "satisfactorio". Usar el MISMO criterio que
  `row_queue` (ver abajo): `cells_from_ascii(art, kind="totopo", level_number=N, fill=...,
  rng=...)` sortea `random_totopo_hp(N, rng)` por celda — nunca un valor fijo. Para un
  pack SIN número de nivel propio (ej. temático, como el navideño), elegir un
  `LEVEL_EQUIVALENT` explícito como referencia (nivel 20 para el pack navideño, pedido
  explícito del usuario) y usar `starting_seeds_for_level(LEVEL_EQUIVALENT)` — NUNCA un
  valor de semillas a mano sin relación con el HP elegido, mismo error ya cometido antes
  con el pack Mundial. Si el nivel-figura SÍ pertenece al roster numérico (ej. niveles
  95-100 del template, figuras hechas a mano), usar su propio número de nivel real, no uno
  inventado.
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
- **HP (niveles `static`)**: variado, sorteado — nunca fijo, mismo criterio que
  `row_queue`. **NO usar el rango del nivel 100** (60-300, el tope de la campaña) como
  default — el pack Mundial lo probó y el usuario pidió bajarlo, primero a nivel 50 y
  después a nivel 30 (dos rondas de ajuste tras jugarlo) — usar
  `totopo_hp_min_for_level(30)`/`totopo_hp_max_for_level(30)` de `tools/gen_levels.py`
  (25-123 al momento de escribir esto) como punto de partida para packs nuevos, no el
  nivel 100 ni el 50. Como no hay condición de derrota, "difícil" solo significa "toma más
  turnos", no "imposible" — pedir un nivel de referencia más alto (50, 75, 100) sigue
  siendo válido si el usuario lo pide explícitamente para un pack más desafiante. **Sesgar
  hacia golpes baratos** (pedido explícito del usuario tras jugar el pack Mundial: "la
  mayoría de bloques no deberían requerir tantos golpes... si no, cada partida se vuelve
  larga y tediosa") — NO usar `rng.randint(HP_MIN, HP_MAX)` uniforme; usar una distribución
  sesgada tipo `_random_hp()` en `tools/gen_worldcup_pack.py` (80% de probabilidad en la
  mitad BAJA del rango declarado, 20% en la mitad alta) para cualquier nivel `static` nuevo
  — sin este sesgo, el HP promedio uniforme hace que una partida sin condición de derrota
  se sienta larga. El rango declarado (HP_MIN/HP_MAX) sigue siendo el mismo, solo cambia
  qué tan seguido se sortea cada extremo.
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
3. Si el nivel tiene `name`, agregar la key de traducción a `assets/translations/translations.txt` (es/en/pt_BR/fr — ver skill `/mobile-i18n` para el formato CSV con comillas si el texto lleva comas). **`name` es visible en juego, no solo metadata**: el HUD lo muestra junto al número ("Nivel 107 · Copa del Mundo", `LABEL_LEVEL_NUMBER_NAMED`) y `PackLevelsScreen` lo usa en el texto del botón ("2. Copa del Mundo") — para niveles-figura o de pack, siempre dar un `name` corto y descriptivo (ayuda al jugador a reconocer qué representa la figura, pedido explícito del usuario), no dejarlo vacío salvo que el nivel sea genérico (roster numérico sin figura).
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
- [ ] `hp` presente en totopo/queso/salsa/triangle; `corner` presente en triangle; `orientation` de laser (si se usa) es `"horizontal"`, `"vertical"` o `"both"`.
- [ ] `starting_seeds` entero > 0.
- [ ] Contenido dentro de ~6 filas (niveles-figura, `cells`) o cola de filas balanceada según `tools/gen_levels.py::total_rows_for_level()` (dificultad progresiva, `row_queue`) — NO aplica a niveles `static` (sin límite de filas).
- [ ] `row_queue[][]` sin campo `row` (implícito); duplicados validados por columna dentro de cada fila, no por posición global.
- [ ] Si `static: true`: `grid_cols` Y `grid_rows` presentes y > 0; `col`/`row` validados contra `grid_cols`/`grid_rows`, no contra `Constants.GRID_COLS`/`MOLCAJETE_ROW`; sin `row_queue`; `grid_cols` sigue la convención de subdivisión (14 estándar, 21 solo si la figura lo justifica), no un número arbitrario.
- [ ] Si el pack es nuevo: se declaró explícitamente qué tipo(s) usa (bloques descendentes / imagen fija / mezcla) antes de generar contenido, y se registró en `Constants.LEVEL_PACKS`.
- [ ] `python3 tools/validate_level.py` sin errores.
- [ ] `manifest.json` actualizado (no regenerado desde cero) — `tools/gen_levels.py::main()` ya preserva packs existentes si se corre, pero mejor no correrlo sin necesidad.
- [ ] Si tiene `name`, la key existe en `assets/translations/translations.txt` para los 4 idiomas.
- [ ] GUT completo en verde (en particular `test_level_manifest_integrity.gd`).

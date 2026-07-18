---
name: feature
description: Implementa una nueva feature siguiendo el protocolo PLAN→IMPL→VALIDATE→SANITY→DOC con todas las reglas anti-alucinación del proyecto.
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
---

## /feature [nombre-de-la-feature] — Protocolo completo de implementación

Sigue cada paso en orden. No saltar ninguno. No marcar "done" hasta que VALIDATE sea GREEN.

---

### PASO A — PLAN

Antes de escribir una línea de código:

1. **Referencia competitiva** — para cualquier feature de gameplay, buscar cómo juegos del mismo género resuelven el mismo problema:
   - Leer `CLAUDE.md` o `idea-base.md` para identificar el género y plataforma del proyecto actual.
   - WebSearch: `"[mecánica a implementar] [género del juego] game"` + `"top [género] games [mecánica] best practices"`
   - Anotar: ¿qué valores usan? ¿qué patrones son estándar en el género? ¿qué podríamos hacer distinto?
   - Si la feature es puramente técnica (arquitectura, bug fix, UI interna), omitir este sub-paso.

2. **Leer** todos los archivos que serán modificados (`Read` tool).
3. **Listar** exactamente:
   - Archivos a crear
   - Archivos a modificar (con qué función/sección)
   - Señales nuevas en EventBus (si aplica)
   - Tests a agregar
4. **Verificar** que la feature:
   - Usa EventBus para comunicación cross-feature (NUNCA `get_parent()` ni rutas hardcodeadas)
   - Tiene una sola responsabilidad por script
   - No duplica lógica que ya existe en otro archivo
5. **Confirmar** que no hay conflictos con autoloads existentes:
   - `ls addons/` antes de importar cualquier addon
   - Verificar que no se crea `class_name X` si ya existe autoload `X`

---

### PASO B — IMPL

Código mínimo. Solo lo que la feature requiere. Sin over-engineering.

#### Reglas de tipado (OBLIGATORIO)
```gdscript
# CORRECTO — siempre tipado estático
var speed: float = 200.0
func take_damage(amount: int) -> void:
    pass

# PROHIBIDO — falla gdlint y causa errores silenciosos en producción
var speed = 200.0
func take_damage(amount):
    pass
```

#### Anti-patrones conocidos (CRÍTICO — releer antes de implementar)

| # | Trampa | Solución |
|---|---|---|
| 1 | `const ITEMS: Array[T] = [...]` | `const ITEMS: Array = [...]` (arrays tipados inválidos como const) |
| 2 | `class_name X` + autoload `X` | Usar solo uno; singletons de constantes SIN `class_name` |
| 3 | `change_scene_to_file()` en `_ready()` | `.call_deferred("change_scene_to_file", path)` siempre |
| 4 | `extends NombreDeClase` en headless | `extends "res://ruta/A.gd"` si A no es autoload |
| 5 | Preload const minúscula | `const EnemyBasicGd := preload(...)` — gdlint regla `load-constant-name` |
| 6 | `for id: Variant in dict.keys()` | Dejar sin tipo: `for id in dict.keys()` |
| 7 | `add_child()` en callback de física | `call_deferred(&"add_child", node)` siempre |
| 8 | `_panel.hide()` ignorado en CanvasLayer | Llamar en `_ready()` Y en el handler correspondiente |
| 9 | Nodo UI no responde con árbol pausado | `process_mode = PROCESS_MODE_ALWAYS` |
| 10 | `class_name` como tipo en otro script | Usar clase base como tipo (`Area2D`, `Node2D`); asignar props con `set(&"prop", val)` |
| 11 | Inventar métodos de API de Godot | Verificar en docs antes de usar cualquier función no confirmada |
| 12 | `get_node()` con ruta larga hardcodeada | Usar `@onready var` o señales |
| 13 | Crear `.tscn` antes de tener el script | Crear script primero, escena después |
| 14 | Autoloads en orden incorrecto | Constants → EventBus → GameManager → SaveManager → AudioManager |
| 15 | Señal no desconectada en nodo dinámico | `_exit_tree()` siempre desconecta señales de nodos que se instancian/destruyen |
| 16 | Modificar base EnemyBase directamente | Heredar: `EnemyBase → EnemyTank`, nunca tocar la base |
| 17 | Valores hardcodeados en scripts | Toda constante de gameplay va en `Constants.gd` |

#### Nomenclatura
- Clases: `PascalCase` (antes de `extends`)
- Variables/funciones: `snake_case`
- Constantes: `SCREAMING_SNAKE_CASE`
- Señales: `snake_case` en pasado (`enemy_destroyed`)
- Archivos: `snake_case` (`enemy_tank.gd`)
- Parámetros privados: prefijo `_` (`var _state`)

#### Estructura EventBus
```gdscript
# Declarar en EventBus.gd bajo la sección correcta
signal feature_event_happened(param: Type)

# Emitir desde el emisor
EventBus.feature_event_happened.emit(value)

# Suscribir en _ready() del receptor
EventBus.feature_event_happened.connect(_on_feature_event_happened)

# Desuscribir en nodos dinámicos
func _exit_tree() -> void:
    EventBus.feature_event_happened.disconnect(_on_feature_event_happened)
```

---

### PASO C — VALIDATE

```bash
# Gate 1 — lint
gdlint src/ tests/

# Gate 2 — tests
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -gexit -glog=2 2>&1
```

**Si cualquier gate falla → corregir antes de continuar. No avanzar.**

Tests nuevos requeridos por toda feature:
- Caso normal (happy path)
- Borde mínimo
- Borde máximo
- Entrada inválida / estado incorrecto

---

### PASO D — SANITY

Verificar que las features existentes no se rompieron:
- ¿Los tests anteriores siguen en verde? (cubierto por VALIDATE)
- ¿EventBus no tiene señales duplicadas?
- ¿Los autoloads siguen en el orden correcto?
- ¿Ningún archivo existente tiene nuevas referencias a nodos que podrían no existir?

---

### PASO E — DOC

Actualizar SIEMPRE (no esperar a que el usuario lo pida):

1. **`idea-base.md`** — sección "Mejoras Implementadas": agregar entrada con `## NombreFeature ✅` y descripción técnica
2. **`CLAUDE.md`** — si la feature cambia arquitectura, señales, o adds a la lista de pendientes
3. **Memoria del proyecto** — actualizar `project_guacblaster.md` si cambia arquitectura, señales clave, o estado del juego

La feature NO está terminada hasta que la documentación esté actualizada.

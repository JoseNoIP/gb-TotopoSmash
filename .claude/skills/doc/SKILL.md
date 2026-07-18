---
name: doc
description: Documenta los cambios recientes en idea-base.md, CLAUDE.md y las memorias del proyecto. Ejecutar al cerrar cualquier tarea.
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
---

## /doc — Documentar cambios del proyecto

Sincroniza los tres niveles de documentación con los cambios que se acaban de implementar. Este paso es OBLIGATORIO al cerrar cualquier tarea — no esperar a que el usuario lo pida.

---

### Paso 1 — Revisar qué cambió

```bash
git diff --name-only HEAD
git diff HEAD
```

Identificar: qué archivos se modificaron, qué señales/funciones se agregaron, qué constantes cambiaron, qué tests se añadieron.

---

### Paso 2 — Actualizar `idea-base.md`

Archivo: `idea-base.md` (raíz del repo).

- Leer el archivo completo con `Read` antes de editar.
- Agregar una entrada en la sección **"Mejoras Implementadas"**:

```markdown
## NombreFeature ✅
- Descripción técnica de qué hace y cómo funciona.
- Constantes relevantes, señales usadas, archivos principales.
- Comportamiento esperado desde la perspectiva del jugador.
```

- Si la feature era un pendiente, moverla de "Pendientes" a "Mejoras Implementadas".
- Si agrega nuevos pendientes, registrarlos en la sección correspondiente.

---

### Paso 3 — Actualizar `CLAUDE.md`

Archivo: `CLAUDE.md` (raíz del repo).

Actualizar SOLO si:
- Se agrega/modifica una señal en EventBus → actualizar tabla "Señales clave en EventBus"
- Se agrega un autoload → actualizar tabla "Autoloads registrados"
- Se descubre un nuevo anti-patrón → agregar a "Reglas Anti-Alucinación"
- Cambia un valor base del jugador → actualizar "Valores base del jugador"
- Se resuelve un pendiente → quitar de "Pendientes Documentados"
- Se agrega un nuevo skill o agente → actualizar sección "Skills y Agentes Disponibles"

No agregar información redundante que ya está en `idea-base.md`.

---

### Paso 4 — Actualizar memoria del proyecto

Buscar la memoria del proyecto:

```bash
find /Users/norb/.claude/projects -name "project_*.md" 2>/dev/null | grep -v GameTemplate | head -5
```

Actualizar si:
- Cambia la arquitectura (nuevos sistemas, cambios a GameManager, EventBus)
- Se agregan/eliminan features implementadas
- Cambian señales clave del EventBus
- Hay nuevas reglas anti-alucinación aprendidas
- Cambian los pendientes

---

### Paso 5 — Propagar al template (si aplica)

**Ruta del template:** `/Users/norb/Dockers/gb-GameTemplate`

Si el cambio es **genérico** (aplica a cualquier juego Godot 4 móvil, no solo a este juego), propagarlo al template en la misma sesión:

| Tipo de aprendizaje | Qué actualizar en el template |
|---|---|
| Nueva regla anti-alucinación o anti-patrón Godot | `CLAUDE.md` → sección Reglas Anti-Alucinación |
| Nuevo skill o agente | `.claude/skills/<nombre>/SKILL.md` o `.claude/.agents/<nombre>.md` |
| Bug de Godot / Android / CI | Skill correspondiente + `CLAUDE.md` si es regla general |
| Mejora al pipeline de assets | `.claude/skills/gen-ai-art/SKILL.md` + `tools/` |
| Mejora al proceso de i18n | `.claude/skills/mobile-i18n/SKILL.md` |
| Nuevo paso de FTUE/tutorial | `.claude/skills/new-game/SKILL.md` |

**Criterio:** Si la regla o el patrón evitaría un error en un juego futuro que parta del template, debe ir al template. Si es específico del juego actual (valores de balance, nombre de personaje, estructura de misiones propias), no propagarlo.

---

### Formato de confirmación al terminar

```
DOC — actualizado

idea-base.md : ✅ [nombre de la sección agregada/modificada]
CLAUDE.md    : ✅ / — (sin cambios necesarios)
memory       : ✅ / — (sin cambios necesarios)
template     : ✅ [qué se propagó] / — (cambio específico del juego)
```

---
name: validate
description: Run gdlint + GUT tests and report GREEN / BLOCKED status.
disable-model-invocation: true
allowed-tools:
  - Bash
---

## /validate — Pipeline de validación

Ejecuta los dos gates obligatorios del proyecto y reporta el resultado.

### Paso 1 — gdlint

```bash
gdlint src/ tests/
```

- Si hay errores: reportar cada línea y marcar **BLOQUEADO**.
- Si pasa limpio: continuar al paso 2.

### Paso 2 — GUT headless

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -gexit -glog=2 2>&1
```

- Leer el resumen final: número de tests passed / failed / errors.
- Si hay failures o errors: reportar cuáles y marcar **BLOQUEADO**.
- Si todos pasan: marcar **GREEN**.

### Formato de salida obligatorio

```
VALIDATE — <timestamp>

gdlint : PASS (0 errores)   |   FAIL (N errores)
GUT    : PASS (N tests ok)  |   FAIL (X fallos)

Estado : ✅ GREEN  |  ❌ BLOQUEADO

[si BLOQUEADO, listar errores específicos aquí]
```

No hacer ningún cambio de código desde este skill. Solo reportar.

### Después de GREEN — DOC obligatorio

Si el estado es GREEN y hubo cambios de código en esta sesión, ejecutar el paso DOC **sin esperar a que el usuario lo pida**:

1. `idea-base.md` — agregar o actualizar la sección de la feature/fix implementado
2. `CLAUDE.md` — actualizar si cambiaron señales, autoloads, anti-patrones o pendientes
3. `memory/project_guacblaster.md` — actualizar si cambió arquitectura, features, señales o pendientes

Una sesión de trabajo NO está cerrada hasta que la documentación esté actualizada.

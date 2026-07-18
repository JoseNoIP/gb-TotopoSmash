# Skill: /mobile-i18n

Agrega soporte multi-idioma a un juego Godot 4 móvil. Implementación probada en GuacBlaster Survivor (julio 2026).

Usa este skill cuando:
- Quieres que el juego esté en más de un idioma
- Recibirás usuarios en mercados distintos (Latinoamérica, EEUU, Brasil, Europa)

---

## Decisiones de diseño

### Idiomas recomendados para mercado hispanohablante + global

| Locale | Prioridad | Nota |
|---|---|---|
| `es` | 1 — default | Mercado principal |
| `en` | 2 | Alcance global |
| `pt_BR` | 3 | Brasil (mercado móvil enorme) |
| `fr` | 4 | Europa francófona |

**Chino y japonés** requieren fuente especial (el tema de Godot no incluye esos glifos por defecto). Solo añadir si tienes fuente que los soporte o está en el scope del proyecto.

### Detección del idioma

| Opción | Cuándo usar |
|---|---|
| **Manual siempre** (pantalla de selección) | Si el juego tiene personaje cultural fuerte o mercado específico. Recomendado. |
| Auto por locale del dispositivo | Si el juego es genérico y quieres reducir fricción en el onboarding |

---

## Arquitectura

```
assets/translations/translations.csv   ← fuente de verdad única
src/core/LocalizationManager.gd        ← autoload, parsea CSV en runtime
src/scenes/LanguageSelectScreen.gd     ← primera ejecución
src/scenes/Main.gd                     ← enruta a selector o menú principal
```

**¿Por qué CSV y no archivos `.translation` binarios?**
- Los `.translation` requieren que Godot los importe con el editor (headless CI no puede).
- El CSV se parsea en runtime con `FileAccess.get_csv_line()` — cero pasos manuales.

---

## Implementación paso a paso

### 1. Crear el archivo de traducciones

`assets/translations/translations.txt` — extensión `.txt` obligatoria (ver anti-alucinación #5):
```csv
keys,es,en,pt_BR,fr
BTN_PLAY,JUGAR,PLAY,JOGAR,JOUER
BTN_BACK,VOLVER,BACK,VOLTAR,RETOUR
TITLE_SETTINGS,CONFIGURACIÓN,SETTINGS,CONFIGURAÇÕES,PARAMÈTRES
```

Reglas del CSV:
- Primera fila: `keys` + un código de locale por columna
- Primera columna: clave en SCREAMING_SNAKE_CASE
- Usar `[BR]` como placeholder para saltos de línea (se reemplaza por `\n` en runtime)
- Sin BOM en el archivo

### 2. LocalizationManager.gd (autoload — **SIN** class_name)

```gdscript
extends Node
## Carga traducciones de CSV en runtime. NO añadir class_name — es autoload (regla #10).

const CSV_PATH: String = "res://assets/translations/translations.txt"
const DEFAULT_LOCALE: String = "es"
const SUPPORTED_LOCALES: Array = ["es", "en", "pt_BR", "fr"]

func _ready() -> void:
    _load_csv()
    var lang: String = SaveManager.get_language()
    if lang.is_empty() or not lang in SUPPORTED_LOCALES:
        lang = DEFAULT_LOCALE
    TranslationServer.set_locale(lang)

func set_language(lang: String) -> void:
    if not lang in SUPPORTED_LOCALES:
        return
    SaveManager.set_language(lang)
    TranslationServer.set_locale(lang)

func get_current_language() -> String:
    return TranslationServer.get_locale()

func _load_csv() -> void:
    var file := FileAccess.open(CSV_PATH, FileAccess.READ)
    if file == null:
        return
    var header: PackedStringArray = file.get_csv_line()
    # header[0] = "keys", header[1..N] = locale codes
    var locale_cols: Array = []
    var translations: Array = []
    for i: int in range(1, header.size()):
        var locale: String = header[i].strip_edges()
        locale_cols.append(locale)
        var t: Translation = Translation.new()
        t.locale = locale
        translations.append(t)
    while not file.eof_reached():
        var row: PackedStringArray = file.get_csv_line()
        if row.size() < 2 or row[0].is_empty():
            continue
        var key: String = row[0].strip_edges()
        for i: int in locale_cols.size():
            if i + 1 >= row.size():
                continue
            var val: String = row[i + 1].replace("[BR]", "\n")
            translations[i].add_message(key, val)
    for t: Translation in translations:
        TranslationServer.add_translation(t)
    file.close()
```

### 3. SaveManager — añadir get/set_language

```gdscript
func get_language() -> String:
    return _data.get("language", "") as String

func set_language(lang: String) -> void:
    _data["language"] = lang
    _save()
```

### 4. project.godot — registrar autoload

Añadir **después** de SaveManager (necesita `SaveManager.get_language()`):
```ini
LocalizationManager="*res://src/core/LocalizationManager.gd"
```

### 5. LanguageSelectScreen (primera ejecución)

Muestra botones de idioma solo en la primera ejecución (cuando `SaveManager.get_language() == ""`):

```gdscript
# Main.gd — enrutador inicial
func _ready() -> void:
    if SaveManager.get_language().is_empty():
        get_tree().change_scene_to_file.call_deferred("res://src/scenes/LanguageSelectScreen.tscn")
    else:
        get_tree().change_scene_to_file.call_deferred("res://src/scenes/MainMenu.tscn")
```

### 6. SettingsScreen — selector de idioma para cambiar después

Añadir fila de idioma con botón ▶ que cicla entre locales:
```gdscript
func _on_lang_next_pressed() -> void:
    var current: String = LocalizationManager.get_current_language()
    var idx: int = LANG_IDS.find(current)
    idx = (idx + 1) % LANG_IDS.size()
    LocalizationManager.set_language(LANG_IDS[idx])
    _lang_label.text = tr(LANG_KEYS[idx])
```

### 7. Reemplazar todos los strings hardcodeados

En todos los scripts UI:
```gdscript
# ANTES
title.text = "CONFIGURACIÓN"

# DESPUÉS
title.text = tr(&"TITLE_SETTINGS")
```

Usar `&"KEY"` (StringName) — más eficiente que `tr("KEY")` (String) al llamarlo en `_process`.

---

## Anti-alucinación (reglas para futuros juegos)

1. **NO** añadir `class_name` a `LocalizationManager` — es un autoload (conflicto fatal, regla CLAUDE.md #10).
2. **NO** usar archivos `.translation` binarios en CI/CD — requieren import del editor.
3. **NO** asumir que `TranslationServer` tiene las traducciones en `_ready()` de otros scripts — `LocalizationManager` debe estar antes en el orden de autoloads.
4. Los saltos de línea en CSV rompan el parser — usar `[BR]` como placeholder y reemplazar en `_load_csv()`.
5. **NO usar extensión `.csv` para el archivo de traducciones** — Bug conocido de Godot ([#38957](https://github.com/godotengine/godot/issues/38957)): los `.csv` son excluidos del PCK incluso con `include_filter="*.csv"` porque Godot los clasifica internamente como recursos de traducción procesados. **Usar extensión `.txt`** y añadir `include_filter="*.txt"` en `export_presets.cfg`. El contenido puede seguir siendo CSV válido (`get_csv_line()` funciona igual sobre `.txt`).
6. Los idiomas con glifos no-latinos (chino, japonés, árabe) requieren fuente separada en el tema de Godot. No los añadir si no hay fuente compatible disponible.

---

## Checklist

- [ ] `assets/translations/translations.csv` creado con todas las claves
- [ ] `LocalizationManager.gd` registrado en `project.godot` DESPUÉS de SaveManager
- [ ] `SaveManager` tiene `get_language()` / `set_language()`
- [ ] `src/scenes/Main.gd` (o escena de entrada) enruta al selector si `language == ""`
- [ ] `LanguageSelectScreen.gd` llama `LocalizationManager.set_language()` + navega a MainMenu
- [ ] `SettingsScreen` tiene fila de idioma con botón ▶ para cambiar después
- [ ] Todos los strings visibles al usuario usan `tr(&"KEY")`
- [ ] `gdlint src/` pasa a 0 errores

---

## Estructura de claves recomendada

```
# Botones comunes
BTN_PLAY, BTN_BACK, BTN_RETRY, BTN_CONTINUE, BTN_BUY, BTN_SELECT

# Títulos de pantallas
TITLE_MAIN_MENU, TITLE_SETTINGS, TITLE_UPGRADES, TITLE_ACHIEVEMENTS

# HUD
HUD_SCORE, HUD_LEVEL, HUD_BOSS_IN, HUD_WAVE

# Resultado
VICTORY_TITLE, GAME_OVER_TITLE, LABEL_SCORE, LABEL_BEST, LABEL_GOLD_EARNED

# Ajustes
SETTINGS_SOUND, SETTINGS_VIBRATION, SETTINGS_SENSITIVITY, SETTINGS_LANGUAGE

# Tutorial
TUTORIAL_HINT, TUTORIAL_TAP
```

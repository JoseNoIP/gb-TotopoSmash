extends Node
## Carga traducciones desde CSV en runtime (ver /mobile-i18n). NO llevar `class_name` —
## es autoload (regla CLAUDE.md #10). Autoload DESPUÉS de SaveManager (necesita
## SaveManager.get_language() en _ready()).
##
## Extensión .txt, no .csv: Godot excluye .csv del PCK aunque se declare en
## include_filter (bug #38957) porque lo trata como recurso de traducción procesado.
## El contenido sigue siendo CSV válido — FileAccess.get_csv_line() funciona igual.

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
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
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

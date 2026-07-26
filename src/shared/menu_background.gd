extends RefCounted
## Fondo compartido de pantallas de menú (imagen de IA + scrim oscuro para legibilidad) —
## antes duplicado en MainMenu.gd/LanguageSelectScreen.gd; extraído acá al agregarse una
## tercera pantalla (UpgradeShopScreen) con el mismo patrón exacto. Fallback a ColorRect
## plano si el asset todavía no existe (ver /gen-ai-art). El fondo del tablero de juego
## real NUNCA debe usar esto (GDD sección 5: debe quedarse plano para resaltar las
## trayectorias de las semillas) — solo pantallas de menú/consulta.
## Uso: const MenuBackgroundGd := preload("res://src/shared/menu_background.gd")
##      MenuBackgroundGd.build(self)

const MENU_BG_PATH: String = "res://assets/sprites/backgrounds/menu_bg.png"


static func build(parent: Control) -> void:
	if not ResourceLoader.exists(MENU_BG_PATH):
		var flat_bg: ColorRect = ColorRect.new()
		flat_bg.color = Constants.COLOR_BG_BOARD
		flat_bg.position = Vector2.ZERO
		flat_bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
		flat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(flat_bg)
		return

	var bg: TextureRect = TextureRect.new()
	bg.texture = load(MENU_BG_PATH)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2.ZERO
	bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.4)
	scrim.position = Vector2.ZERO
	scrim.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scrim)

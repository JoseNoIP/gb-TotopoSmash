extends RefCounted
## Estilo compartido para paneles tipo "modal" (overlays construidos con PanelContainer:
## SettingsScreen, PauseScreen, GameOverScreen, LevelCompleteScreen, panel del tutorial).
##
## Bug real reportado jugando: el `PanelContainer` sin estilo propio usa el panel semi-
## transparente por defecto del tema de Godot — sobre un fondo con detalle (ej. el fondo
## de MainMenu, una imagen de IA), el texto del modal se mezclaba visualmente con lo que
## había DETRÁS y quedaba ilegible. Aplicar SIEMPRE a cualquier PanelContainer usado como
## overlay/modal, sin excepción:
##
##   const ModalStyleGd := preload("res://src/shared/modal_style.gd")
##   _panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())

const CORNER_RADIUS: int = 12
const BG_ALPHA: float = 0.97  ## casi 100% opaco — nunca dejar ver el fondo real detrás


static func opaque_panel(bg_color: Color = Constants.COLOR_BG_BOARD) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, BG_ALPHA)
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	return style

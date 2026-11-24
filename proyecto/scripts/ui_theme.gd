extends Node

## Tema único de la interfaz. Reúne la paleta, la tipografía y los estilos que
## antes estaban duplicados en cada escena. `apply()` se llama al entrar en un
## menú o en el HUD y sustituye cualquier tema local para que todas las pantallas
## compartan el mismo lenguaje visual.
##
## Criterio del paquete A: el chrome (barras, tarjetas, navegación) es navy
## plano con un hairline; el borde grueso de pegatina y la sombra dura se
## reservan a la acción principal. El amarillo solo marca recompensas (monedas,
## récord, medalla), el cian la ruta/torneo y el coral lo destructivo.

const FONT: FontFile = preload("res://ui/fonts/Baloo2-Variable.ttf")

# Paleta tomada de los mapas: cobalto de los muros, azul de cielo, cian de
# las losas/hielo, oro de las barandillas, naranja de lava y coral del abismo.
# Los nombres históricos se conservan para no romper las escenas existentes.
const INK := Color("#06183B")

const CREAM := Color("#EDF9FF")

const PLUM := Color("#0A2A61")

const PLUM_DARK := Color("#061838")

const ROYAL := Color("#0B3A82")

## Superficie del chrome: un paso por encima del panel, sin borde blanco.
const SURFACE := Color("#12356B")

const SURFACE_HOVER := Color("#1A4680")

const BLUE := Color("#0D6FE8")

const YELLOW := Color("#FFD23F")

const YELLOW_HOVER := Color("#FFE37A")

const PINK := Color("#FF5B1A")

const PINK_HOVER := Color("#FF874D")

const CYAN := Color("#16D9F1")

const CYAN_HOVER := Color("#6CF0FF")

const MINT := Color("#5BE3A6")

const CORAL := Color("#FF3D5A")

var theme: Theme

var _display_font: FontVariation

var _body_font: FontVariation

var _control_font: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_display_font = _make_font(800)
	_body_font = _make_font(600)
	_control_font = _make_font(700)
	theme = _build()
	get_tree().root.theme = theme


## Aplica el tema a un árbol de UI. También normaliza la tipografía: todo el
## texto usa Baloo 2, los títulos llevan el peso display y los textos pequeños
## suben a un mínimo legible a 720p.
func apply(root: Control) -> void:
	if root == null:
		return
	_apply(root)


func _make_font(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {"wght": weight}
	return font


func _apply(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.theme = theme
		if control is Label:
			var size := control.get_theme_font_size("font_size")
			if size < 14:
				control.add_theme_font_size_override("font_size", 14)
			control.add_theme_font_override("font", _display_font if size >= 28 else _body_font)
		elif control is Button:
			# Los estilos locales duplicados tapaban el tema común. Se retiran
			# para que cada botón use su variante semántica y el contraste sea
			# el mismo en todas las pantallas.
			for style in ["normal", "hover", "pressed", "focus", "disabled"]:
				control.remove_theme_stylebox_override(style)
			for color in [
				"font_color",
				"font_hover_color",
				"font_pressed_color",
				"font_focus_color",
				"font_disabled_color",
				"font_outline_color"
			]:
				control.remove_theme_color_override(color)
			control.remove_theme_constant_override("outline_size")
			var size := control.get_theme_font_size("font_size")
			var minimum := 14 if control.theme_type_variation == &"NavButton" else 15
			if size < minimum:
				control.add_theme_font_size_override("font_size", minimum)
			var display := control.theme_type_variation in [
				&"PrimaryButton", &"ActionCard", &"InfoCard", &"PillButton"
			]
			control.add_theme_font_override("font", _display_font if display else _control_font)
		elif control is ProgressBar:
			control.remove_theme_stylebox_override("background")
			control.remove_theme_stylebox_override("fill")
		elif control is HSlider:
			control.remove_theme_stylebox_override("slider")
			control.remove_theme_stylebox_override("grabber_area")
			control.remove_theme_stylebox_override("grabber_area_highlight")
		elif control is RichTextLabel:
			control.add_theme_font_override("normal_font", _body_font)
			control.add_theme_font_override("bold_font", _display_font)
	for child in node.get_children():
		_apply(child)


func _build() -> Theme:
	var result := Theme.new()
	result.default_font = _body_font
	result.default_font_size = 17
	result.set_color("font_color", "Label", CREAM)
	result.set_constant("outline_size", "Label", 0)
	result.set_color("font_outline_color", "Label", Color(0.02, 0.06, 0.16, 0.9))
	result.set_stylebox("panel", "PanelContainer", _chrome())
	result.set_stylebox("panel", "Panel", _chrome())
	# Barras compactas (monedas, ficha del jugador): menos aire que un panel.
	result.set_type_variation("ChromeBar", "PanelContainer")
	result.set_stylebox("panel", "ChromeBar", _box(PLUM, 1, Color(CREAM, 0.14), 14, 16, 10))
	# Insignia de monedas: la barra compacta es el propio botón, sin panel de
	# fondo ni capa transparente encima. Así toda la pastilla recibe el clic.
	result.set_type_variation("CoinButton", "Button")
	result.set_stylebox("normal", "CoinButton", _box(PLUM, 1, Color(CREAM, 0.14), 14, 16, 10))
	result.set_stylebox(
		"hover", "CoinButton", _box(PLUM.lightened(0.1), 1, Color(CREAM, 0.3), 14, 16, 10)
	)
	result.set_stylebox(
		"pressed", "CoinButton", _box(PLUM_DARK, 1, Color(CREAM, 0.2), 14, 16, 10)
	)
	result.set_stylebox("focus", "CoinButton", _focus(14))
	result.set_color("font_color", "CoinButton", Color(CREAM, 0.92))
	result.set_color("font_hover_color", "CoinButton", CREAM)
	result.set_color("font_pressed_color", "CoinButton", CREAM)
	result.set_color("font_focus_color", "CoinButton", CREAM)
	result.set_font_size("font_size", "CoinButton", 15)
	# Teclas del tutorial: una pastilla pequeña, no un botón que parezca pulsable.
	result.set_type_variation("KeyCap", "PanelContainer")
	result.set_stylebox("panel", "KeyCap", _box(SURFACE, 1, Color(CREAM, 0.2), 8, 10, 5))

	# Botón base: acción secundaria callada. El amarillo ya no es un botón.
	_quiet_button(result, "Button", SURFACE, SURFACE_HOVER, PLUM_DARK, CREAM, 16, 12)
	result.set_color("font_disabled_color", "Button", Color(CREAM, 0.4))
	result.set_stylebox("disabled", "Button", _box(PLUM_DARK, 1, Color(CREAM, 0.1), 12, 20, 11))

	# Variantes semánticas. Solo la primaria lleva pegatina con sombra.
	_sticker_button(result, "PrimaryButton", PINK, PINK_HOVER, INK, 18, 16)
	_variation(result, "InfoButton", CYAN, CYAN_HOVER, INK, 17)
	result.set_stylebox("normal", "InfoButton", _box(CYAN, 1, Color(CREAM, 0.5), 12, 20, 10))
	result.set_stylebox("hover", "InfoButton", _box(CYAN_HOVER, 1, Color(CREAM, 0.7), 12, 20, 10))
	result.set_stylebox("pressed", "InfoButton", _box(CYAN, 1, Color(CREAM, 0.7), 12, 20, 14))
	_quiet_button(
		result, "GhostButton", Color(0, 0, 0, 0), Color(CREAM, 0.08), Color(CREAM, 0.14),
		CREAM, 16, 12
	)
	result.set_stylebox(
		"normal", "GhostButton", _box(Color(0, 0, 0, 0), 1, Color(CREAM, 0.22), 12, 20, 10)
	)
	result.set_stylebox(
		"hover", "GhostButton", _box(Color(CREAM, 0.08), 1, Color(CREAM, 0.32), 12, 20, 10)
	)
	result.set_stylebox(
		"pressed", "GhostButton", _box(Color(CREAM, 0.14), 1, Color(CREAM, 0.4), 12, 20, 14)
	)
	_quiet_button(
		result, "DangerButton", Color(0, 0, 0, 0), Color(CORAL, 0.12), Color(CORAL, 0.2),
		CORAL, 15, 12
	)
	result.set_stylebox(
		"normal", "DangerButton", _box(Color(0, 0, 0, 0), 1, Color(CORAL, 0.5), 12, 16, 9)
	)
	result.set_stylebox(
		"hover", "DangerButton", _box(Color(CORAL, 0.12), 1, Color(CORAL, 0.8), 12, 16, 9)
	)
	result.set_stylebox(
		"pressed", "DangerButton", _box(Color(CORAL, 0.2), 1, CORAL, 12, 16, 13)
	)

	# Navegación: enlaces de texto. El chrome no compite con el personaje.
	result.set_type_variation("NavButton", "Button")
	result.set_stylebox(
		"normal", "NavButton", _box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 10, 12, 8)
	)
	result.set_stylebox(
		"hover", "NavButton", _box(Color(CREAM, 0.08), 0, Color(0, 0, 0, 0), 10, 12, 8)
	)
	result.set_stylebox(
		"pressed", "NavButton", _box(Color(CREAM, 0.14), 0, Color(0, 0, 0, 0), 10, 12, 8)
	)
	result.set_stylebox("focus", "NavButton", _focus(10))
	result.set_color("font_color", "NavButton", Color(CREAM, 0.78))
	result.set_color("font_hover_color", "NavButton", CREAM)
	result.set_color("font_focus_color", "NavButton", CREAM)
	result.set_color("font_pressed_color", "NavButton", CREAM)
	result.set_font_size("font_size", "NavButton", 14)

	# Nodos de la ruta de temporada: superficie callada, no botón de color. El
	# seleccionado se hunde y el lobby le añade un subrayado oro.
	result.set_type_variation("RouteButton", "Button")
	result.set_stylebox(
		"normal", "RouteButton", _box(Color(SURFACE, 0.55), 1, Color(CREAM, 0.12), 10, 10, 8)
	)
	result.set_stylebox(
		"hover",
		"RouteButton",
		_box(Color(SURFACE_HOVER, 0.85), 1, Color(CREAM, 0.24), 10, 10, 8)
	)
	result.set_stylebox(
		"pressed", "RouteButton", _box(PLUM_DARK, 1, Color(CREAM, 0.2), 10, 10, 8)
	)
	result.set_stylebox("focus", "RouteButton", _focus(10))
	result.set_color("font_color", "RouteButton", CREAM)
	result.set_color("font_hover_color", "RouteButton", CREAM)
	result.set_color("font_focus_color", "RouteButton", CREAM)
	result.set_color("font_pressed_color", "RouteButton", CREAM)
	result.set_font_size("font_size", "RouteButton", 15)

	# Tarjetas de modo: la clásica es la acción; el torneo es información.
	_sticker_button(result, "ActionCard", PINK, PINK_HOVER, INK, 20, 20)
	result.set_stylebox("normal", "ActionCard", _box(PINK, 4, CREAM, 20, 24, 16, true, 4))
	result.set_stylebox("hover", "ActionCard", _box(PINK_HOVER, 4, CREAM, 20, 24, 16, true, 5))
	result.set_stylebox(
		"pressed", "ActionCard", _box(Color("#D9480F"), 4, CREAM, 20, 24, 22, true, 1)
	)
	_quiet_button(
		result, "InfoCard", PLUM, SURFACE, PLUM_DARK, CREAM, 20, 20
	)
	result.set_stylebox("normal", "InfoCard", _box(PLUM, 2, CYAN, 20, 24, 16))
	result.set_stylebox("hover", "InfoCard", _box(SURFACE, 2, CYAN_HOVER, 20, 24, 16))
	result.set_stylebox("pressed", "InfoCard", _box(PLUM_DARK, 2, CYAN, 20, 24, 22))

	_variation(result, "PillButton", CYAN, CYAN_HOVER, INK, 15)

	# Controles.
	result.set_stylebox("background", "ProgressBar", _box(PLUM_DARK, 1, Color(CREAM, 0.18), 6, 0, 0))
	result.set_stylebox("fill", "ProgressBar", _box(CYAN, 0, Color(0, 0, 0, 0), 6, 0, 0))
	result.set_color("font_color", "ProgressBar", CREAM)
	result.set_font_size("font_size", "ProgressBar", 14)
	# El margen vertical da altura al rail: sin él el StyleBox mide 0 px y solo
	# se ve el punto del grabber.
	result.set_stylebox("slider", "HSlider", _box(PLUM_DARK, 1, Color(CREAM, 0.18), 6, 0, 6))
	result.set_stylebox(
		"grabber_area", "HSlider", _box(CYAN, 0, Color(0, 0, 0, 0), 6, 0, 6)
	)
	result.set_stylebox(
		"grabber_area_highlight", "HSlider", _box(CYAN_HOVER, 0, Color(0, 0, 0, 0), 6, 0, 6)
	)

	# El margen del estilo es lo que da ancho a la barra: sin él, el ScrollContainer
	# la coloca a 0 px y el contenido parece cortado sin aviso.
	result.set_stylebox(
		"scroll", "VScrollBar", _box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 8, 4, 4)
	)
	result.set_stylebox(
		"grabber", "VScrollBar", _box(Color(CREAM, 0.4), 0, Color(0, 0, 0, 0), 8, 4, 4)
	)
	result.set_stylebox(
		"grabber_highlight",
		"VScrollBar",
		_box(Color(CREAM, 0.65), 0, Color(0, 0, 0, 0), 8, 4, 4)
	)
	result.set_stylebox(
		"grabber_pressed", "VScrollBar", _box(YELLOW, 0, Color(0, 0, 0, 0), 8, 4, 4)
	)

	var sep := StyleBoxLine.new()
	sep.color = Color(CREAM, 0.12)
	sep.thickness = 1
	result.set_stylebox("separator", "HSeparator", sep)

	# Escala tipográfica reutilizable.
	result.set_font_size("font_size", "Label", 17)
	result.set_constant("line_spacing", "Label", 4)
	return result


func _variation(
	result: Theme, name: String, normal: Color, hover: Color, ink: Color, font_size: int
) -> void:
	result.set_type_variation(name, "Button")
	result.set_stylebox("normal", name, _box(normal, 1, Color(CREAM, 0.4), 12, 20, 10))
	result.set_stylebox("hover", name, _box(hover, 1, Color(CREAM, 0.6), 12, 20, 10))
	result.set_stylebox("pressed", name, _box(normal, 1, Color(CREAM, 0.6), 12, 20, 14))
	result.set_stylebox("focus", name, _focus(12))
	result.set_color("font_color", name, ink)
	result.set_color("font_hover_color", name, ink)
	result.set_color("font_focus_color", name, ink)
	result.set_color("font_pressed_color", name, ink)
	result.set_font_size("font_size", name, font_size)


func _quiet_button(
	result: Theme,
	name: String,
	normal: Color,
	hover: Color,
	pressed: Color,
	ink: Color,
	font_size: int,
	radius: int
) -> void:
	if name != "Button":
		result.set_type_variation(name, "Button")
	result.set_stylebox("normal", name, _box(normal, 1, Color(CREAM, 0.16), radius, 20, 11))
	result.set_stylebox("hover", name, _box(hover, 1, Color(CREAM, 0.3), radius, 20, 11))
	result.set_stylebox("pressed", name, _box(pressed, 1, Color(CREAM, 0.4), radius, 20, 15))
	result.set_stylebox("focus", name, _focus(radius))
	result.set_color("font_color", name, ink)
	result.set_color("font_hover_color", name, ink)
	result.set_color("font_focus_color", name, ink)
	result.set_color("font_pressed_color", name, ink)
	result.set_font_size("font_size", name, font_size)


func _sticker_button(
	result: Theme, name: String, normal: Color, hover: Color, ink: Color, font_size: int, radius: int
) -> void:
	result.set_type_variation(name, "Button")
	result.set_stylebox("normal", name, _box(normal, 4, CREAM, radius, 22, 12, true, 4))
	result.set_stylebox("hover", name, _box(hover, 4, CREAM, radius, 22, 12, true, 5))
	result.set_stylebox("pressed", name, _box(normal, 4, CREAM, radius, 22, 18, true, 1))
	result.set_stylebox("focus", name, _focus(radius))
	result.set_color("font_color", name, ink)
	result.set_color("font_hover_color", name, ink)
	result.set_color("font_focus_color", name, ink)
	result.set_color("font_pressed_color", name, ink)
	result.set_font_size("font_size", name, font_size)


func _chrome() -> StyleBoxFlat:
	return _box(PLUM, 1, Color(CREAM, 0.14), 20, 24, 24)


func _box(
	bg: Color,
	border: int,
	border_color: Color,
	radius: int,
	margin_h: float,
	margin_v: float,
	shadow: bool = false,
	shadow_offset: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = border
	box.border_width_top = border
	box.border_width_right = border
	box.border_width_bottom = border
	box.border_color = border_color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = maxi(radius - 2, 4)
	box.corner_radius_bottom_right = radius + 2
	box.corner_radius_bottom_left = maxi(radius - 2, 4)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	if shadow:
		box.shadow_color = Color(0.01, 0.04, 0.12, 0.45)
		box.shadow_size = 4
		box.shadow_offset = Vector2(0, shadow_offset)
	return box


func _focus(radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = YELLOW
	box.corner_radius_top_left = radius + 2
	box.corner_radius_top_right = radius + 2
	box.corner_radius_bottom_right = radius + 2
	box.corner_radius_bottom_left = radius + 2
	box.expand_margin_left = 2
	box.expand_margin_top = 2
	box.expand_margin_right = 2
	box.expand_margin_bottom = 2
	return box

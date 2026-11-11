extends Node

## Tema único de la interfaz. Reúne la paleta, la tipografía y los estilos que
## antes estaban duplicados en cada escena. `apply()` se llama al entrar en un
## menú o en el HUD y sustituye cualquier tema local para que todas las pantallas
## compartan el mismo lenguaje visual.

const FONT: FontFile = preload("res://ui/fonts/Baloo2-Variable.ttf")
# Paleta tomada de los mapas: cobalto de los muros, azul de cielo, cian de
# las losas/hielo, oro de las barandillas, naranja de lava y coral del abismo.
# Los nombres históricos se conservan para no romper las escenas existentes.
const INK := Color("#06183B")
const CREAM := Color("#EDF9FF")
const PLUM := Color("#0A2A61")
const PLUM_DARK := Color("#061838")
const ROYAL := Color("#0B3A82")
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_display_font = _make_font(800)
	_body_font = _make_font(600)
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
			# para que cada botón use su variante semántica (primaria, info,
			# fantasma o pill) y el contraste sea el mismo en todas las pantallas.
			for style in ["normal", "hover", "pressed", "focus", "disabled"]:
				control.remove_theme_stylebox_override(style)
			for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
				control.remove_theme_color_override(color)
			control.remove_theme_constant_override("outline_size")
			var size := control.get_theme_font_size("font_size")
			var minimum := 13 if control.theme_type_variation == &"NavButton" else 15
			if size < minimum:
				control.add_theme_font_size_override("font_size", minimum)
			control.add_theme_font_override("font", _display_font)
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
	result.default_font_size = 18
	result.set_color("font_color", "Label", CREAM)
	result.set_constant("outline_size", "Label", 0)
	result.set_color("font_outline_color", "Label", Color(0.02, 0.06, 0.16, 0.9))
	result.set_stylebox("panel", "PanelContainer", _box(PLUM, 5, CREAM, 26, 26, 22))
	result.set_stylebox("panel", "Panel", _box(PLUM, 5, CREAM, 26, 26, 22))

	# Botón base: acción secundaria amarilla.
	_button_styles(result, "Button", YELLOW, YELLOW_HOVER, PINK, INK, 16)
	result.set_stylebox("focus", "Button", _focus())
	result.set_stylebox("disabled", "Button", _box(Color("#10233F"), 2, Color(1, 1, 1, 0.35), 16, 20, 10))
	result.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.55))

	# Variantes semánticas.
	_variation(result, "PrimaryButton", PINK, PINK_HOVER, INK, 18)
	_variation(result, "InfoButton", CYAN, CYAN_HOVER, INK, 18)
	_variation(result, "GhostButton", Color(0.02, 0.08, 0.18, 0.55), Color(0.03, 0.18, 0.36, 0.85), CREAM, 16)
	result.set_type_variation("NavButton", "Button")
	result.set_stylebox("normal", "NavButton", _box(ROYAL, 3, CREAM, 14, 12, 8))
	result.set_stylebox("hover", "NavButton", _box(BLUE, 4, CREAM, 14, 12, 8))
	result.set_stylebox("pressed", "NavButton", _box(PINK, 3, CREAM, 14, 12, 8))
	result.set_stylebox("focus", "NavButton", _focus())
	result.set_color("font_color", "NavButton", CREAM)
	result.set_color("font_hover_color", "NavButton", CREAM)
	result.set_color("font_focus_color", "NavButton", CREAM)
	result.set_color("font_pressed_color", "NavButton", INK)
	result.set_font_size("font_size", "NavButton", 13)
	_variation(result, "PillButton", CYAN, CYAN_HOVER, INK, 15)
	_variation(result, "DangerButton", CORAL, Color("#FF7185"), INK, 18)

	# Chips compactos del selector de circuito: menos margen que un botón
	# normal para que los cinco nombres quepan en la fila.
	result.set_type_variation("ChipButton", "Button")
	_button_styles(result, "ChipButton", YELLOW, YELLOW_HOVER, PINK, INK, 15)
	result.set_stylebox("normal", "ChipButton", _box(YELLOW, 4, CREAM, 17, 8, 6))
	result.set_stylebox("hover", "ChipButton", _box(YELLOW_HOVER, 5, CREAM, 17, 8, 6))
	result.set_stylebox("pressed", "ChipButton", _box(PINK, 4, CREAM, 17, 8, 6))
	result.set_stylebox("focus", "ChipButton", _focus())

	# Controles.
	result.set_stylebox("background", "ProgressBar", _box(PLUM_DARK, 2, CREAM, 9, 0, 0))
	result.set_stylebox("fill", "ProgressBar", _box(CYAN, 0, Color(0, 0, 0, 0), 9, 0, 0))
	result.set_color("font_color", "ProgressBar", CREAM)
	result.set_font_size("font_size", "ProgressBar", 14)
	# El margen vertical da altura al rail: sin él el StyleBox mide 0 px y solo
	# se ve el punto del grabber.
	result.set_stylebox("slider", "HSlider", _box(PLUM_DARK, 2, CREAM, 9, 0, 5))
	result.set_stylebox("grabber_area", "HSlider", _box(CYAN, 0, Color(0, 0, 0, 0), 9, 0, 5))
	result.set_stylebox("grabber_area_highlight", "HSlider", _box(CYAN_HOVER, 0, Color(0, 0, 0, 0), 9, 0, 5))

	result.set_stylebox("scroll", "VScrollBar", _box(Color(0.02, 0.08, 0.18), 0, Color(0, 0, 0, 0), 8, 0, 0))
	result.set_stylebox("grabber", "VScrollBar", _box(Color(1, 1, 1, 0.35), 0, Color(0, 0, 0, 0), 8, 0, 0))
	result.set_stylebox("grabber_highlight", "VScrollBar", _box(Color(1, 1, 1, 0.55), 0, Color(0, 0, 0, 0), 8, 0, 0))
	result.set_stylebox("grabber_pressed", "VScrollBar", _box(YELLOW, 0, Color(0, 0, 0, 0), 8, 0, 0))

	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.18)
	sep.thickness = 2
	result.set_stylebox("separator", "HSeparator", sep)

	# Escala tipográfica reutilizable.
	result.set_font_size("font_size", "Label", 18)
	result.set_constant("line_spacing", "Label", 4)
	return result


func _variation(result: Theme, name: String, normal: Color, hover: Color, ink: Color, font_size: int) -> void:
	result.set_type_variation(name, "Button")
	_button_styles(result, name, normal, hover, PINK, ink, font_size)
	result.set_stylebox("focus", name, _focus())


func _button_styles(result: Theme, type: String, normal: Color, hover: Color, pressed: Color, ink: Color, font_size: int) -> void:
	result.set_stylebox("normal", type, _box(normal, 4, CREAM, 17, 20, 10))
	result.set_stylebox("hover", type, _box(hover, 5, CREAM, 17, 20, 10))
	# Al pulsar, el texto baja y la sombra desaparece: el botón se hunde.
	var down := _box(pressed, 4, CREAM, 17, 20, 16)
	down.shadow_offset = Vector2(0, 0)
	result.set_stylebox("pressed", type, down)
	result.set_stylebox("focus", type, _focus())
	result.set_color("font_color", type, ink)
	result.set_color("font_hover_color", type, ink)
	result.set_color("font_focus_color", type, ink)
	result.set_color("font_pressed_color", type, ink)
	result.set_font_size("font_size", type, font_size)


func _box(bg: Color, border: int, border_color: Color, radius: int, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = border
	box.border_width_top = border
	box.border_width_right = border
	box.border_width_bottom = border
	box.border_color = border_color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = maxi(radius - 4, 4)
	box.corner_radius_bottom_right = radius + 4
	box.corner_radius_bottom_left = maxi(radius - 2, 4)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	box.shadow_color = Color(0.01, 0.04, 0.12, 0.38)
	box.shadow_size = 0
	box.shadow_offset = Vector2(0, 4)
	return box


func _focus() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = CREAM
	box.corner_radius_top_left = 20
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_right = 22
	box.corner_radius_bottom_left = 18
	return box

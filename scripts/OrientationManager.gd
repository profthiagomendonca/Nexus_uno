extends Node

var canvas_layer: CanvasLayer
var overlay: ColorRect
var label: Label

func _ready():
	# Funciona mesmo se o jogo estiver pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Criar CanvasLayer no topo de tudo
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	add_child(canvas_layer)
	
	# Fundo escuro com blur sci-fi
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.04, 0.08, 0.98) # Azul escuro sci-fi opaco
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)
	
	# Centralizar conteúdo
	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 35)
	center.add_child(vbox)
	
	# Desenhar ícone do celular rotacionando via Stylebox
	var phone_rect = Panel.new()
	phone_rect.custom_minimum_size = Vector2(70, 120)
	phone_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_left = 3
	style.border_width_top = 8
	style.border_width_right = 3
	style.border_width_bottom = 8
	style.border_color = Color(0.2, 0.8, 1.0, 1.0) # Ciano Neon
	style.set_corner_radius_all(8)
	phone_rect.add_theme_stylebox_override("panel", style)
	phone_rect.pivot_offset = Vector2(35, 60)
	vbox.add_child(phone_rect)
	
	# Tween de animação para girar o ícone
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(phone_rect, "rotation", deg_to_rad(90), 0.8)
	tween.tween_interval(0.4)
	tween.tween_property(phone_rect, "rotation", deg_to_rad(0), 0.8)
	tween.tween_interval(0.4)
	
	# Texto de aviso
	label = Label.new()
	label.text = "POR FAVOR, GIRE SEU APARELHO\nDEITE O CELULAR (MODO PAISAGEM)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1.0))
	
	var font = load("res://assets/Orbitron.ttf")
	if font:
		label.add_theme_font_override("font", font)
	
	vbox.add_child(label)
	
	overlay.hide()

func _process(_delta):
	var size = get_viewport().get_visible_rect().size
	
	# Mostrar aviso apenas se a altura for maior que a largura (Modo Retrato)
	if size.y > size.x:
		overlay.show()
	else:
		overlay.hide()

extends Control

@onready var buttons = [
	$Center/VBox/HBox/Btn1,
	$Center/VBox/HBox/Btn2,
	$Center/VBox/HBox/Btn3,
	$Center/VBox/HBox/Btn4
]
@onready var start_btn = $Center/StartBtn

var sb_normal: StyleBoxFlat
var sb_selected: StyleBoxFlat

func _ready():
	# Estilo tecnológico Normal (Neon Branco)
	sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0, 0, 0, 0.4)
	sb_normal.set_corner_radius_all(10)
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = Color(1.0, 1.0, 1.0, 1.0) # Borda Branca Forte
	sb_normal.shadow_color = Color(1.0, 1.0, 1.0, 0.3)
	sb_normal.shadow_size = 10 # Glow Branco
	
	# Estilo tecnológico Selecionado (Neon Azul)
	sb_selected = StyleBoxFlat.new()
	sb_selected.bg_color = Color(0.1, 0.5, 0.9, 0.7)
	sb_selected.set_corner_radius_all(10)
	sb_selected.border_width_left = 3
	sb_selected.border_width_top = 3
	sb_selected.border_width_right = 3
	sb_selected.border_width_bottom = 3
	sb_selected.border_color = Color(0.4, 0.9, 1.0, 1.0)
	sb_selected.shadow_color = Color(0, 0.7, 1.0, 0.6)
	sb_selected.shadow_size = 15 # Glow Azul Forte

	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.add_theme_stylebox_override("normal", sb_normal)
		btn.add_theme_stylebox_override("hover", sb_selected)
		btn.add_theme_stylebox_override("pressed", sb_selected)
		btn.pressed.connect(_on_opponent_selected.bind(i + 1))
		btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
		btn.pivot_offset = btn.size / 2.0
	
	# Botão Iniciar com glow maior
	start_btn.add_theme_stylebox_override("normal", sb_selected)
	start_btn.add_theme_stylebox_override("hover", sb_selected.duplicate())
	start_btn.get_theme_stylebox("hover").bg_color = Color(0.2, 0.7, 1.0, 0.9)
	start_btn.pressed.connect(_on_start_pressed)
	start_btn.mouse_entered.connect(_on_btn_hover.bind(start_btn, true))
	start_btn.mouse_exited.connect(_on_btn_hover.bind(start_btn, false))
	start_btn.pivot_offset = start_btn.size / 2.0
	
	$Music.finished.connect($Music.play)
	
	_play_tech_pulse()
	_on_opponent_selected(1)

func _play_tech_pulse():
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(start_btn, "scale", Vector2(1.03, 1.03), 1.0)
	tween.tween_property(start_btn, "scale", Vector2(0.97, 0.97), 1.0)

func _on_btn_hover(btn: Button, is_hover: bool):
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_hover:
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.5)
		btn.modulate = Color(1.2, 1.2, 1.5)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0) if btn.modulate != Color(1.2, 1.2, 1.2) else Vector2(1.2, 1.2), 0.5)
		btn.modulate = Color.WHITE if btn.get_theme_stylebox("normal") == sb_normal else Color(1.2, 1.2, 1.2)

func _on_opponent_selected(count: int):
	GameSettings.opponent_count = count
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i + 1 == count:
			btn.add_theme_stylebox_override("normal", sb_selected)
			btn.scale = Vector2(1.2, 1.2)
			btn.modulate = Color(1.2, 1.2, 1.2)
		else:
			btn.add_theme_stylebox_override("normal", sb_normal) # Garante que volta para o neon branco
			btn.scale = Vector2(1.0, 1.0)
			btn.modulate = Color.WHITE

func _on_start_pressed():
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(start_btn, "scale", Vector2(1.8, 1.8), 0.6)
	tween.tween_property(start_btn, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://scenes/UnoGame.tscn")

extends Control

@onready var buttons = [
	$Center/VBox/HBox/Btn1,
	$Center/VBox/HBox/Btn2,
	$Center/VBox/HBox/Btn3,
	$Center/VBox/HBox/Btn4
]
@onready var start_btn = $Center/StartBtn

func _ready():
	# Configurar botões de quantidade
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.pressed.connect(_on_opponent_selected.bind(i + 1))
		btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
		btn.pivot_offset = btn.size / 2.0
	
	start_btn.pressed.connect(_on_start_pressed)
	start_btn.mouse_entered.connect(_on_btn_hover.bind(start_btn, true))
	start_btn.mouse_exited.connect(_on_btn_hover.bind(start_btn, false))
	start_btn.pivot_offset = start_btn.size / 2.0
	
	# Seleção padrão (1 oponente)
	_on_opponent_selected(1)

func _on_btn_hover(btn: Button, is_hover: bool):
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hover:
		tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2)
		btn.z_index = 1
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
		btn.z_index = 0

func _on_opponent_selected(count: int):
	GameSettings.opponent_count = count
	
	# Destacar botão selecionado
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i + 1 == count:
			btn.modulate = Color(1.0, 0.2, 0.2) # Vermelho vibrante
			btn.scale = Vector2(1.1, 1.1)
		else:
			btn.modulate = Color.WHITE
			btn.scale = Vector2(1.0, 1.0)

func _on_start_pressed():
	# Efeito de transição simples
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/UnoGame.tscn")

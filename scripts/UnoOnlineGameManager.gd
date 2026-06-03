extends Node2D

@onready var hand_container = $UI/Hand/Cards
@onready var opponent_hand_container = $UI/OpponentHand/Cards
@onready var discard_pile_view = $UI/Board/Piles/DiscardPile
@onready var draw_pile_view = $UI/Board/Piles/DrawPileContainer/DrawPile
@onready var message_label = $UI/Message
@onready var color_selector = $UI/ColorSelector
@onready var target_selector = $UI/TargetSelector
@onready var target_grid = $UI/TargetSelector/VBox/Grid
@onready var nexus_button = $UI/NexusButton
@onready var poll_timer = %PollTimer

var card_scene_path = "res://scenes/Carta.tscn"
var card_script_path = "res://scripts/CardUI.gd"

var current_top_card: CardData
var my_player_name: String = ""
var my_player_index: int = -1
var current_turn_index: int = -1
var total_players: int = 0
var draw_stack: int = 0
var game_direction: int = 1
var finished_players: Array = []
var player_names: Array = []

var waiting_for_selection: bool = false
var has_drawn_this_turn: bool = false
var last_seen_version: int = -1
var local_action_in_progress: bool = false
var my_nexus_called: bool = false

func _ready():
	my_player_name = FirebaseManager.player_name
	
	# Conectar botões de cores
	$UI/ColorSelector/VBox/Grid/Btn_Yellow.pressed.connect(_on_color_selected.bind(11, Color(1.0, 0.8, 0.0)))
	$UI/ColorSelector/VBox/Grid/Btn_Green.pressed.connect(_on_color_selected.bind(16, Color(0.2, 0.8, 0.2)))
	$UI/ColorSelector/VBox/Grid/Btn_Red.pressed.connect(_on_color_selected.bind(1, Color(0.8, 0.2, 0.2)))
	$UI/ColorSelector/VBox/Grid/Btn_Blue.pressed.connect(_on_color_selected.bind(17, Color(0.2, 0.6, 1.0)))
	
	# Conectar sinais de rede
	FirebaseManager.room_updated.connect(_on_room_updated)
	FirebaseManager.room_not_found.connect(_on_room_lost)
	
	poll_timer.timeout.connect(_on_poll_timeout)
	poll_timer.start()
	
	# Primeira busca imediata
	_on_poll_timeout()

func _on_poll_timeout():
	if local_action_in_progress or waiting_for_selection:
		return
	FirebaseManager.fetch_room_state()

func _on_room_updated(data: Dictionary):
	if local_action_in_progress or waiting_for_selection:
		return
		
	var server_version = data.get("state_version", 0)
	if server_version <= last_seen_version:
		return # Evitar redesenhar se já estamos atualizados
		
	last_seen_version = server_version
	
	# Verificar se o jogo terminou
	var status = data.get("status", "")
	if status == "ended":
		_show_game_over_menu(data.get("winner", "Ninguém"))
		return
		
	# Mapear jogadores
	player_names = FirebaseManager.clean_array(data.get("players", []))
	total_players = player_names.size()
	my_player_index = player_names.find(my_player_name)
	current_turn_index = data.get("current_turn_index", 0)
	
	# Sincronizar variáveis de partida
	draw_stack = data.get("draw_stack", 0)
	game_direction = data.get("game_direction", 1)
	finished_players = FirebaseManager.clean_array(data.get("finished_players", []))
	
	# Sincronizar carta do topo
	current_top_card = FirebaseManager.deserialize_card(data.get("current_top_card", {}))
	update_board_visual()
	
	# Atualizar mão local
	var hands_dict = data.get("player_hands", {})
	var my_hand_data = hands_dict.get(my_player_name, [])
	var deserialized_hand = FirebaseManager.deserialize_deck(my_hand_data)
	update_local_hand_visual(deserialized_hand)
	
	# Atualizar mãos dos oponentes
	update_opponents_visual(hands_dict, data.get("nexus_safe", {}))
	
	# Exibir ações recentes no centro
	var last_action = data.get("last_action", {})
	if last_action.has("message"):
		var msg_txt = last_action.get("message", "")
		# Se foi um grito de Nexus, reproduz o efeito visual na tela
		if last_action.get("type", "") == "nexus":
			_play_nexus_effect(last_action.get("player", "Alguém"))
		
		# Não sobrescrever mensagens locais importantes
		if not waiting_for_selection:
			message_label.text = msg_txt
			
	# Processar turnos
	_check_turn_status()

func _check_turn_status():
	if finished_players.has(my_player_name):
		nexus_button.hide()
		if current_turn_index == my_player_index:
			_pass_turn()
		else:
			var active_player = player_names[current_turn_index] if current_turn_index < player_names.size() else "Outro"
			message_label.text = "Você terminou! Assistindo à partida... (Vez de %s...)" % active_player
		return

	if current_turn_index == my_player_index:
		if draw_stack > 0:
			message_label.text = "SUA VEZ! Acumule com +2/+4 ou compre o stack (+%d)!" % draw_stack
		else:
			message_label.text = "SUA VEZ!"
	else:
		var active_player = player_names[current_turn_index] if current_turn_index < player_names.size() else "Outro"
		message_label.text = "Vez de %s..." % active_player
		
	# Atualizar visibilidade do botão Nexus de forma centralizada
	if _should_show_nexus_button():
		nexus_button.show()
	else:
		nexus_button.hide()

func update_board_visual():
	for child in discard_pile_view.get_children():
		child.queue_free()
	var scene = load(card_scene_path)
	var top_ui = scene.instantiate()
	var script = load(card_script_path)
	if script:
		top_ui.set_script(script)
	discard_pile_view.add_child(top_ui)
	top_ui.setup(current_top_card)
	top_ui.scale = Vector2(0.8, 0.8)

func update_local_hand_visual(new_hand: Array):
	# Limpar e reconstruir para garantir sincronia correta
	for child in hand_container.get_children():
		child.queue_free()
		
	for card_data in new_hand:
		var scene = load(card_scene_path)
		var card_ui = scene.instantiate()
		var script = load(card_script_path)
		if script:
			card_ui.set_script(script)
		hand_container.add_child(card_ui)
		card_ui.setup(card_data)
		card_ui.gui_input.connect(_on_card_input.bind(card_ui))
		
	reorganize_hand()

func update_opponents_visual(hands_dict: Dictionary, nexus_safe: Dictionary):
	for child in opponent_hand_container.get_children():
		child.queue_free()
		
	for i in range(player_names.size()):
		if i == my_player_index:
			continue
			
		var opt_name = player_names[i]
		var opt_hand = hands_dict.get(opt_name, [])
		var is_active = (current_turn_index == i)
		var is_finished = finished_players.has(opt_name)
		
		# VBox do oponente
		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 0)
		opponent_hand_container.add_child(box)
		
		# Nome do jogador
		var name_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.6)
		style.set_corner_radius_all(5)
		if is_active:
			style.bg_color = Color(0, 0.4, 0.8, 0.8)
			style.border_width_bottom = 2
			style.border_color = Color(0, 1, 1, 1)
		name_panel.add_theme_stylebox_override("panel", style)
		box.add_child(name_panel)
		
		var name_label = Label.new()
		name_label.text = opt_name
		if is_finished:
			name_label.text += " (Fim)"
		# Se não estiver seguro no Nexus (UNO)
		elif opt_hand.size() == 1 and not nexus_safe.get(opt_name, false):
			name_label.text += " ⚠️"
			
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_panel.add_child(name_label)
		
		# Visibilidade do botão Nexus é gerenciada de forma centralizada em _check_turn_status()
			
		# Cartas
		var stack_area = Control.new()
		stack_area.custom_minimum_size = Vector2(80, 30)
		box.add_child(stack_area)
		
		var card_count = opt_hand.size()
		var card_spacing = min(12.0, 60.0 / max(1, card_count))
		var total_width = (card_count - 1) * card_spacing
		var start_x = (80 - total_width) / 2.0 - 28
		
		for j in range(card_count):
			var scene = load(card_scene_path)
			var card_ui = scene.instantiate()
			var script = load(card_script_path)
			if script:
				card_ui.set_script(script)
			stack_area.add_child(card_ui)
			card_ui.setup(null, true)
			card_ui.scale = Vector2(0.4, 0.4)
			card_ui.position = Vector2(start_x + (j * card_spacing), -65)

func reorganize_hand():
	var cards = hand_container.get_children()
	var count = cards.size()
	if count == 0:
		return
	var screen_width = get_viewport_rect().size.x
	var spacing = min(75, (screen_width - 250) / count)
	var total_width = spacing * (count - 1)
	var start_x = (screen_width / 2.0) - (total_width / 2.0)
	for i in range(count):
		var card = cards[i]
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", Vector2(start_x + (i * spacing) - 80, 20), 0.4)
		tween.tween_property(card, "rotation", 0.0, 0.4)
		card.z_index = i

func _on_card_input(event: InputEvent, card_ui: Control):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_turn_index != my_player_index or waiting_for_selection or local_action_in_progress:
			return
			
		var card_data = card_ui.get("data")
		
		if draw_stack > 0:
			# Só pode jogar se for acumular +2 ou +4
			if card_data.type == CardData.CardType.WILD_DRAW_FOUR or card_data.type == CardData.CardType.DRAW_TWO:
				play_card(card_ui)
			else:
				message_label.text = "Acumule com +2/+4 ou compre do monte!"
			return

		if card_data.is_match(current_top_card):
			play_card(card_ui)

func play_card(card_ui: Control):
	local_action_in_progress = true
	var played_data = card_ui.get("data")
	
	# Remover localmente
	hand_container.remove_child(card_ui)
	card_ui.queue_free()
	reorganize_hand()
	
	current_top_card = played_data
	update_board_visual()
	
	# Verificar se ativamos efeitos de escolha de cor ou alvo
	if played_data.type == CardData.CardType.WILD or played_data.type == CardData.CardType.WILD_DRAW_FOUR:
		waiting_for_selection = true
		color_selector.show()
	elif played_data.type == CardData.CardType.SWAP_HANDS:
		if check_win_local():
			# Se foi a última carta, venceu direto
			_push_play_action(played_data, "venceu o jogo!")
		else:
			waiting_for_selection = true
			_show_target_selector()
	else:
		# Cartas normais ou de efeito direto (+2, SKIP, REVERSE)
		var effect_msg = _get_card_action_message(played_data)
		_apply_special_effects(played_data)
		
		# Avançar turno
		if check_win_local():
			_push_win_state()
		else:
			current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
			_push_play_action(played_data, effect_msg)

func _get_card_action_message(card: CardData) -> String:
	var symb = card.symbol if card.type == CardData.CardType.ELEMENT else ""
	match card.type:
		CardData.CardType.SKIP: return "pulou a vez do próximo!"
		CardData.CardType.REVERSE: return "inverteu o sentido do jogo!"
		CardData.CardType.DRAW_TWO: return "jogou +2!"
		CardData.CardType.WILD: return "jogou um Coringa!"
		CardData.CardType.WILD_DRAW_FOUR: return "jogou um Cadeia +4!"
		CardData.CardType.SWAP_HANDS: return "jogou Ligação Covalente (Troca de Mãos)!"
		_: return "jogou %s (%s)!" % [card.name, symb]

func _apply_special_effects(card: CardData):
	match card.type:
		CardData.CardType.SKIP:
			# Pula um jogador adicional
			current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
		CardData.CardType.REVERSE:
			if total_players == 2:
				current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
			else:
				game_direction *= -1
		CardData.CardType.DRAW_TWO:
			draw_stack += 2
		CardData.CardType.WILD_DRAW_FOUR:
			draw_stack += 4

func _on_color_selected(group_id: int, color: Color):
	waiting_for_selection = false
	color_selector.hide()
	
	current_top_card.group = group_id
	current_top_card.color_override = color
	
	var color_name = "Nova Família"
	if group_id == 1: color_name = "Vermelho"
	elif group_id == 11: color_name = "Amarelo"
	elif group_id == 16: color_name = "Verde"
	elif group_id == 17: color_name = "Azul"
	
	_apply_special_effects(current_top_card)
	
	if check_win_local():
		_push_win_state()
	else:
		current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
		_push_play_action(current_top_card, "escolheu a família %s!" % color_name)

func _show_target_selector():
	target_selector.show()
	for child in target_grid.get_children():
		child.queue_free()
		
	var glass = load("res://resources/GlassStyleBox.tres")
	var font = load("res://assets/Orbitron.ttf")
	
	for i in range(player_names.size()):
		if i == my_player_index or finished_players.has(player_names[i]):
			continue
			
		var btn = Button.new()
		btn.text = player_names[i]
		btn.custom_minimum_size = Vector2(120, 50)
		if glass: btn.add_theme_stylebox_override("normal", glass)
		if font: btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		
		btn.pressed.connect(_on_target_player_selected.bind(player_names[i]))
		target_grid.add_child(btn)

func _on_target_player_selected(target_name: String):
	waiting_for_selection = false
	target_selector.hide()
	
	# Trocar mãos no Firebase
	var room = FirebaseManager.current_room_data
	var hands = room.get("player_hands", {})
	
	# Obter a mão atual do jogador local (sem a carta de troca já jogada)
	var my_hand_serialized = []
	for card_ui in hand_container.get_children():
		my_hand_serialized.append(FirebaseManager.serialize_card(card_ui.get("data")))
		
	var temp = my_hand_serialized
	hands[my_player_name] = hands[target_name]
	hands[target_name] = temp
	
	current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
	
	# Enviar toda a atualização de uma vez
	var update = {
		"player_hands": hands,
		"current_top_card": FirebaseManager.serialize_card(current_top_card),
		"discard_pile": room.get("discard_pile", []) + [FirebaseManager.serialize_card(current_top_card)],
		"current_turn_index": current_turn_index,
		"last_action": {
			"type": "swap",
			"player": my_player_name,
			"message": "%s trocou de mãos com %s!" % [my_player_name, target_name]
		}
	}
	
	var success = await FirebaseManager.update_room_state(update)
	if not success:
		_handle_update_failure()
		return
	local_action_in_progress = false

func _on_draw_pile_pressed():
	if current_turn_index != my_player_index or waiting_for_selection or local_action_in_progress:
		return
		
	local_action_in_progress = true
	var room = FirebaseManager.current_room_data
	
	if draw_stack > 0:
		# Comprar stack de punição
		message_label.text = "Você comprou %d cartas de punição!" % draw_stack
		var hands = room.get("player_hands", {})
		var my_hand = hands.get(my_player_name, [])
		
		for i in range(draw_stack):
			var card = draw_card_from_deck(room)
			if card:
				my_hand.append(FirebaseManager.serialize_card(card))
				
		hands[my_player_name] = my_hand
		
		# Avançar o turno
		current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
		
		var update = {
			"player_hands": hands,
			"deck": room.get("deck", []),
			"discard_pile": room.get("discard_pile", []),
			"draw_stack": 0,
			"current_turn_index": current_turn_index,
			"last_action": {
				"type": "draw",
				"player": my_player_name,
				"message": "%s comprou %d cartas!" % [my_player_name, draw_stack]
			}
		}
		
		var success = await FirebaseManager.update_room_state(update)
		if not success:
			_handle_update_failure()
			return
		local_action_in_progress = false
	else:
		if has_drawn_this_turn:
			# Passar a vez caso já tenha comprado
			_pass_turn()
		else:
			# Comprar uma única carta
			var hands = room.get("player_hands", {})
			var my_hand = hands.get(my_player_name, [])
			var card = draw_card_from_deck(room)
			
			if card:
				my_hand.append(FirebaseManager.serialize_card(card))
				hands[my_player_name] = my_hand
				
				# Verificar se dá match
				if card.is_match(current_top_card) or card.type == CardData.CardType.WILD or card.type == CardData.CardType.WILD_DRAW_FOUR:
					message_label.text = "Match perfeito! Você pode jogar ou passar."
					has_drawn_this_turn = true
					
					# Atualizar apenas a mão no Firebase para que outros vejam a compra
					var update = {
						"player_hands": hands,
						"deck": room.get("deck", []),
						"discard_pile": room.get("discard_pile", []),
						"last_action": {
							"type": "draw",
							"player": my_player_name,
							"message": "%s comprou uma carta." % my_player_name
						}
					}
					var success = await FirebaseManager.update_room_state(update)
					if not success:
						_handle_update_failure()
						return
					local_action_in_progress = false
				else:
					# Passar automaticamente se não der match
					message_label.text = "Carta sem match. Passou a vez."
					current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
					has_drawn_this_turn = false
					
					var update = {
						"player_hands": hands,
						"deck": room.get("deck", []),
						"discard_pile": room.get("discard_pile", []),
						"current_turn_index": current_turn_index,
						"last_action": {
							"type": "draw_pass",
							"player": my_player_name,
							"message": "%s comprou e passou a vez." % my_player_name
						}
					}
					var success = await FirebaseManager.update_room_state(update)
					if not success:
						_handle_update_failure()
						return
					local_action_in_progress = false
			else:
				local_action_in_progress = false

func _pass_turn():
	local_action_in_progress = true
	has_drawn_this_turn = false
	current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished_players)
	
	var update = {
		"current_turn_index": current_turn_index,
		"last_action": {
			"type": "pass",
			"player": my_player_name,
			"message": "%s passou a vez." % my_player_name
		}
	}
	var success = await FirebaseManager.update_room_state(update)
	if not success:
		_handle_update_failure()
		return
	local_action_in_progress = false

func draw_card_from_deck(room: Dictionary) -> CardData:
	var deck = FirebaseManager.clean_array(room.get("deck", []))
	if deck.is_empty():
		# Reembaralhar pilha de descarte (menos o topo)
		var discard = FirebaseManager.clean_array(room.get("discard_pile", []))
		var top = room.get("current_top_card", {})
		var new_deck = []
		for card_dict in discard:
			if card_dict.get("atomic_number") != top.get("atomic_number") or card_dict.get("type") != top.get("type"):
				new_deck.append(card_dict)
		new_deck.shuffle()
		room["deck"] = new_deck
		room["discard_pile"] = [top]
		deck = new_deck
		_show_color_change_message("Baralho reembaralhado!")
		
	if deck.is_empty():
		return null
		
	var serialized = deck.pop_back()
	return FirebaseManager.deserialize_card(serialized)

func check_win_local() -> bool:
	return hand_container.get_child_count() == 0

func _push_win_state():
	var room = FirebaseManager.current_room_data
	var finished = FirebaseManager.clean_array(room.get("finished_players", []))
	if not finished.has(my_player_name):
		finished.append(my_player_name)
		
	var hands = room.get("player_hands", {})
	hands[my_player_name] = [] # Garante que a mão do vencedor fique vazia no banco!
	
	# Se todos os jogadores (ou todos menos um) terminaram
	if finished.size() >= total_players - 1:
		# Fim de Jogo!
		var update = {
			"status": "ended",
			"winner": finished[0],
			"finished_players": finished,
			"player_hands": hands,
			"current_top_card": FirebaseManager.serialize_card(current_top_card),
			"discard_pile": room.get("discard_pile", []) + [FirebaseManager.serialize_card(current_top_card)],
			"last_action": {
				"type": "win",
				"player": my_player_name,
				"message": "Fim de jogo! %s venceu a partida!" % finished[0]
			}
		}
		var success = await FirebaseManager.update_room_state(update)
		if not success:
			_handle_update_failure()
			return
	else:
		# Próximo turno
		current_turn_index = get_next_turn_index(current_turn_index, game_direction, total_players, finished)
		var update = {
			"finished_players": finished,
			"player_hands": hands,
			"current_top_card": FirebaseManager.serialize_card(current_top_card),
			"discard_pile": room.get("discard_pile", []) + [FirebaseManager.serialize_card(current_top_card)],
			"current_turn_index": current_turn_index,
			"last_action": {
				"type": "finish",
				"player": my_player_name,
				"message": "%s acabou suas cartas!" % my_player_name
			}
		}
		var success = await FirebaseManager.update_room_state(update)
		if not success:
			_handle_update_failure()
			return
		
	local_action_in_progress = false

func _push_play_action(card: CardData, action_desc: String):
	var room = FirebaseManager.current_room_data
	var hands = room.get("player_hands", {})
	
	# Obter cartas atuais da mão visual para sincronizar no servidor
	var current_hand_serialized = []
	for card_ui in hand_container.get_children():
		current_hand_serialized.append(FirebaseManager.serialize_card(card_ui.get("data")))
		
	hands[my_player_name] = current_hand_serialized
	
	# Se sobrou 1 carta, define se estamos salvos pelo botão clicado previamente
	var nexus_safe = room.get("nexus_safe", {})
	if current_hand_serialized.size() == 1:
		nexus_safe[my_player_name] = my_nexus_called
	else:
		nexus_safe[my_player_name] = false
	my_nexus_called = false
		
	var update = {
		"player_hands": hands,
		"current_top_card": FirebaseManager.serialize_card(current_top_card),
		"discard_pile": room.get("discard_pile", []) + [FirebaseManager.serialize_card(current_top_card)],
		"current_turn_index": current_turn_index,
		"game_direction": game_direction,
		"draw_stack": draw_stack,
		"nexus_safe": nexus_safe,
		"last_action": {
			"type": "play",
			"player": my_player_name,
			"message": "%s %s" % [my_player_name, action_desc]
		}
	}
	
	var success = await FirebaseManager.update_room_state(update)
	if not success:
		_handle_update_failure()
		return
	local_action_in_progress = false

# --- A Regra do Nexus! ---

func _on_nexus_pressed():
	nexus_button.hide()
	var room = FirebaseManager.current_room_data
	var hands = room.get("player_hands", {})
	var nexus_safe = room.get("nexus_safe", {})
	
	# Caso A: Você tem 1 ou 2 cartas na mão e quer se salvar
	if hand_container.get_child_count() <= 2:
		if hand_container.get_child_count() == 2:
			my_nexus_called = true
			_play_nexus_effect(my_player_name)
			return
		else:
			nexus_safe[my_player_name] = true
			var update = {
				"nexus_safe": nexus_safe,
				"last_action": {
					"type": "nexus",
					"player": my_player_name,
					"message": "NEXUS! %s declarou uma carta restando!" % my_player_name
				}
			}
			var success = await FirebaseManager.update_room_state(update)
			if not success:
				_handle_update_failure()
			return
			
	# Caso B: Denunciar outro jogador com 1 carta vulnerável
	for player in player_names:
		if player == my_player_name:
			continue
		var player_hand = hands.get(player, [])
		if player_hand.size() == 1 and not nexus_safe.get(player, false):
			show_message("Você pegou %s sem Nexus!" % player)
			
			for i in range(4):
				var card = draw_card_from_deck(room)
				if card:
					player_hand.append(FirebaseManager.serialize_card(card))
			
			hands[player] = player_hand
			nexus_safe[player] = true
			
			var update = {
				"player_hands": hands,
				"deck": room.get("deck", []),
				"discard_pile": room.get("discard_pile", []),
				"nexus_safe": nexus_safe,
				"last_action": {
					"type": "nexus_punish",
					"player": my_player_name,
					"message": "NEXUS! %s puniu %s por não avisar (+4)!" % [my_player_name, player]
				}
			}
			var success = await FirebaseManager.update_room_state(update)
			if not success:
				_handle_update_failure()
				return
			break

func _play_nexus_effect(who: String):
	var fx = Label.new()
	fx.text = "NEXUS! (%s)" % who
	fx.add_theme_font_size_override("font_size", 40)
	fx.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	
	var screen_size = get_viewport_rect().size
	fx.custom_minimum_size = Vector2(500, 100)
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fx.position = Vector2(screen_size.x / 2.0 - 250, screen_size.y / 2.0 - 50)
	fx.pivot_offset = Vector2(250, 50)
	
	var font = load("res://assets/Orbitron.ttf")
	if font: fx.add_theme_font_override("font", font)
	
	$UI.add_child(fx)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fx.scale = Vector2(0.1, 0.1)
	tween.tween_property(fx, "scale", Vector2(1.2, 1.2), 0.8)
	tween.tween_property(fx, "position:y", fx.position.y - 120, 1.5).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(fx, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	
	get_tree().create_timer(1.5).timeout.connect(func(): fx.queue_free())

# --- Mensagens Flutuantes e Game Over ---

func _show_color_change_message(text_str: String):
	var msg = Label.new()
	msg.text = text_str
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.position = Vector2(50, 260)
	$UI.add_child(msg)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(msg, "position:y", msg.position.y - 30, 2.0)
	tween.tween_property(msg, "modulate:a", 0.0, 2.0)
	get_tree().create_timer(2.0).timeout.connect(func(): msg.queue_free())

func _show_game_over_menu(winner: String):
	poll_timer.stop()
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 250)
	panel.add_theme_stylebox_override("panel", load("res://resources/GlassStyleBox.tres"))
	
	var screen_size = get_viewport_rect().size
	panel.position = Vector2(screen_size.x / 2.0 - 200, screen_size.y / 2.0 - 125)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "FIM DE JOGO!\n\nVencedor:\n" + winner
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	var font = load("res://assets/Orbitron.ttf")
	if font: label.add_theme_font_override("font", font)
	vbox.add_child(label)
	
	var btn = Button.new()
	btn.text = "VOLTAR AO MENU"
	btn.custom_minimum_size = Vector2(250, 50)
	btn.add_theme_stylebox_override("normal", load("res://resources/GlassStyleBox.tres"))
	btn.add_theme_font_size_override("font_size", 18)
	if font: btn.add_theme_font_override("font", font)
	
	btn.pressed.connect(func():
		FirebaseManager.leave_room()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	vbox.add_child(btn)
	
	$UI.add_child(panel)

func _on_room_lost():
	poll_timer.stop()
	message_label.text = "A conexão com a sala foi perdida."
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func show_message(text: String):
	message_label.text = text

func get_next_turn_index(current_idx: int, dir: int, players_count: int, finished: Array) -> int:
	var next_idx = (current_idx + dir) % players_count
	if next_idx < 0:
		next_idx = players_count - 1
	var loops = 0
	while finished.has(player_names[next_idx]) and loops < players_count:
		next_idx = (next_idx + dir) % players_count
		if next_idx < 0:
			next_idx = players_count - 1
		loops += 1
	return next_idx

func _handle_update_failure():
	# Forçar reversão local em caso de erro no salvamento do estado
	message_label.text = "Falha de rede! Sincronizando com o servidor..."
	local_action_in_progress = false
	waiting_for_selection = false
	if color_selector:
		color_selector.hide()
	if target_selector:
		target_selector.hide()
		
	# Espera um curto intervalo e puxa a verdade do servidor para restaurar o estado visual correto
	await get_tree().create_timer(1.0).timeout
	FirebaseManager.fetch_room_state()

func _should_show_nexus_button() -> bool:
	if finished_players.has(my_player_name):
		return false
		
	# Caso 1: É o meu turno e tenho exatamente 2 cartas (vou jogar a penúltima)
	if current_turn_index == my_player_index and hand_container.get_child_count() == 2:
		return true
		
	# Caso 2: Tenho exatamente 1 carta na mão (já joguei e quero me salvar)
	if hand_container.get_child_count() == 1:
		var room = FirebaseManager.current_room_data
		var nexus_safe = room.get("nexus_safe", {})
		if not nexus_safe.get(my_player_name, false):
			return true
			
	# Caso 3: Algum oponente está com 1 carta na mão e não está seguro (podemos punir)
	var room = FirebaseManager.current_room_data
	var hands = room.get("player_hands", {})
	var nexus_safe = room.get("nexus_safe", {})
	for player in player_names:
		if player != my_player_name and not finished_players.has(player):
			var player_hand = hands.get(player, [])
			if player_hand.size() == 1 and not nexus_safe.get(player, false):
				return true
				
	return false

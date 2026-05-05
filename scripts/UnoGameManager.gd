extends Node2D

@onready var deck_manager = $DeckManager
@onready var hand_container = $UI/Hand/Cards
@onready var opponent_hand_container = $UI/OpponentHand/Cards
@onready var discard_pile_view = $UI/Board/Piles/DiscardPile
@onready var draw_pile_view = $UI/Board/Piles/DrawPileContainer/DrawPile
@onready var message_label = $UI/Message
@onready var color_selector = $UI/ColorSelector
@onready var target_selector = $UI/TargetSelector
@onready var target_grid = $UI/TargetSelector/VBox/Grid
@onready var nexus_button = $UI/NexusButton

var card_scene_path = "res://scenes/Carta.tscn"
var card_script_path = "res://scripts/CardUI.gd"

var current_top_card: CardData
var current_turn_index = 0 # 0 = Jogador, 1+ = Robôs
var total_players = 2
var opponent_hands: Array = [] # Array de Arrays[CardData]
var draw_stack = 0
var nexus_called = false
var game_direction = 1 # 1 para frente, -1 para trás
var waiting_for_selection = false
var has_drawn_this_turn = false
var has_drawn_this_turn = false
var finished_players: Array[int] = [] 

func _ready():
	var database = PeriodicDatabase.new()
	deck_manager.create_deck(database.get_all_elements())
	total_players = GameSettings.opponent_count + 1
	
	# Conectar botões de cores
	$UI/ColorSelector/VBox/Grid/Btn_Yellow.pressed.connect(_on_color_selected.bind(11, Color(1, 0.8, 0)))
	$UI/ColorSelector/VBox/Grid/Btn_Green.pressed.connect(_on_color_selected.bind(16, Color(0.2, 0.8, 0.2)))
	$UI/ColorSelector/VBox/Grid/Btn_Red.pressed.connect(_on_color_selected.bind(1, Color(0.8, 0.2, 0.2)))
	$UI/ColorSelector/VBox/Grid/Btn_Blue.pressed.connect(_on_color_selected.bind(17, Color(0.2, 0.6, 1)))
	
	start_game()

func start_game():
	# Inicializar mãos para todos os jogadores
	opponent_hands.clear()
	for i in range(total_players):
		if i == 0: # Jogador
			for j in range(7): add_card_to_hand(deck_manager.draw_card())
		else: # Robôs
			var bot_hand: Array[CardData] = []
			for j in range(7): bot_hand.append(deck_manager.draw_card())
			opponent_hands.append(bot_hand)
	
	current_top_card = deck_manager.draw_card()
	while current_top_card.type != CardData.CardType.ELEMENT:
		deck_manager.discard_card(current_top_card)
		current_top_card = deck_manager.draw_card()
	
	update_board_visual()
	reorganize_hand()
	reorganize_opponent_hand()

func add_card_to_hand(card_data: CardData):
	if not card_data: return
	var scene = load(card_scene_path)
	var card_ui = scene.instantiate()
	var script = load(card_script_path)
	if script: card_ui.set_script(script)
	hand_container.add_child(card_ui)
	card_ui.setup(card_data)
	card_ui.gui_input.connect(_on_card_input.bind(card_ui))
	reorganize_hand()

func _on_card_input(event: InputEvent, card_ui: Control):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_turn_index != 0: return
		var card_data = card_ui.get("data")
		
		if draw_stack > 0:
			if card_data.type == CardData.CardType.WILD_DRAW_FOUR or card_data.type == CardData.CardType.DRAW_TWO:
				play_card(card_ui)
			else:
				message_label.text = "Acumule ou compre o stack!"
			return

		if card_data.is_match(current_top_card):
			play_card(card_ui)

func play_card(card_ui: Control):
	var played_data = card_ui.get("data")
	
	if hand_container.get_child_count() == 2:
		nexus_button.show()
		nexus_called = false
		get_tree().create_timer(2.0).timeout.connect(func(): nexus_button.hide())
	
	hand_container.remove_child(card_ui)
	card_ui.queue_free()
	
	deck_manager.discard_card(current_top_card)
	current_top_card = played_data
	
	update_board_visual()
	reorganize_hand()
	
	if played_data.type == CardData.CardType.WILD or played_data.type == CardData.CardType.WILD_DRAW_FOUR:
		waiting_for_selection = true
		color_selector.position = Vector2(101, 158)
		color_selector.show()
	elif played_data.type == CardData.CardType.SWAP_HANDS:
		waiting_for_selection = true
		_show_target_selector()
	else:
		process_special_effect(played_data, 0)
		if check_win_condition(): return
		next_turn()

func _show_target_selector():
	for child in target_grid.get_children(): child.queue_free()
	for i in range(1, total_players):
		if finished_players.has(i): continue
		var btn = Button.new()
		btn.text = "Robô " + str(i)
		btn.custom_minimum_size = Vector2(100, 50)
		btn.pressed.connect(_on_target_selected.bind(i))
		target_grid.add_child(btn)
	
	# Colocando na mesma posição da mensagem
	target_selector.position = Vector2(101, 158)
	target_selector.show()

func _on_target_selected(bot_idx: int):
	target_selector.hide()
	waiting_for_selection = false
	swap_with_player(bot_idx)
	if check_win_condition(): return
	next_turn()

func _on_color_selected(group_id: int, color: Color):
	current_top_card.group = group_id
	current_top_card.color_override = color
	color_selector.hide()
	waiting_for_selection = false
	update_board_visual()
	
	var color_name = "Nova Família"
	if group_id == 1: color_name = "Vermelho"
	elif group_id == 11: color_name = "Amarelo"
	elif group_id == 16: color_name = "Verde"
	elif group_id == 17: color_name = "Azul"
	_show_color_change_message("Você escolheu:\n" + color_name)
	
	if check_win_condition(): return
	next_turn()
func start_bot_turn(bot_index: int):
	if finished_players.has(bot_index):
		next_turn()
		return

	# Mostrar botão Nexus se o robô estiver com 1 carta e você puder denunciar
	var bot_hand = opponent_hands[bot_index - 1]
	if bot_hand.size() == 1:
		nexus_button.show()
		nexus_called = false
		get_tree().create_timer(1.2).timeout.connect(func(): nexus_button.hide())

	# Mensagem fixa no centro
	message_label.text = "Robô " + str(bot_index) + " pensando..."
	
	await get_tree().create_timer(1.5).timeout
	


	# Penalidade Nexus para o Jogador se for o turno do próximo robô e ele não avisou
	if hand_container.get_child_count() == 1 and not nexus_called:
		nexus_button.hide() # Trava o botão para não ser clicado tardiamente
		message_label.text = "Robô te pegou! Compre +4."
		for i in range(4): add_card_to_hand(deck_manager.draw_card())
		await get_tree().create_timer(1.5).timeout

	var valid_card_index = -1
	for i in range(bot_hand.size()):
		var card = bot_hand[i]
		if draw_stack > 0:
			if card.type == CardData.CardType.WILD_DRAW_FOUR or card.type == CardData.CardType.DRAW_TWO:
				valid_card_index = i
				break
		elif card.is_match(current_top_card):
			valid_card_index = i
			break
			
	if valid_card_index != -1:
		var card_data = bot_hand[valid_card_index]
		bot_hand.remove_at(valid_card_index)
		deck_manager.discard_card(current_top_card)
		current_top_card = card_data
		
		if card_data.type == CardData.CardType.WILD or card_data.type == CardData.CardType.WILD_DRAW_FOUR:
			var choices = [
				{"g": 1, "c": Color(0.8, 0.2, 0.2), "n": "Vermelho (Alcalinos)"},
				{"g": 11, "c": Color(1, 0.8, 0), "n": "Amarelo (Metais)"},
				{"g": 16, "c": Color(0.2, 0.8, 0.2), "n": "Verde (Não-metais)"},
				{"g": 17, "c": Color(0.2, 0.6, 1.0), "n": "Azul (Halogênios)"}
			]
			var choice = choices.pick_random()
			card_data.group = choice["g"]
			card_data.color_override = choice["c"]
			
			update_board_visual()
			reorganize_opponent_hand()
			process_special_effect(card_data, bot_index)
			
			_show_color_change_message("Robô escolheu:\n" + choice["n"])
			await get_tree().create_timer(2.0).timeout
		else:
			update_board_visual()
			reorganize_opponent_hand()
			process_special_effect(card_data, bot_index)
			
		if bot_hand.size() == 1:
			nexus_button.show()
			nexus_called = false
			get_tree().create_timer(2.0).timeout.connect(func(): nexus_button.hide())
		
		if bot_hand.size() == 0:
			finished_players.append(bot_index)
			message_label.text = "Robô " + str(bot_index) + " terminou!"
			await get_tree().create_timer(1.5).timeout
		
		if check_win_condition(): return
		next_turn()
	else:
		if draw_stack > 0:
			message_label.text = "Robô " + str(bot_index) + " comprou " + str(draw_stack) + " cartas!"
			for i in range(draw_stack): bot_hand.append(deck_manager.draw_card())
			draw_stack = 0
		else:
			message_label.text = "Robô " + str(bot_index) + " comprou uma carta."
			bot_hand.append(deck_manager.draw_card())
		
		reorganize_opponent_hand()
		await get_tree().create_timer(1.0).timeout
		next_turn()

func _get_bot_ui_position(bot_index: int) -> Vector2:
	var screen_width = get_viewport_rect().size.x
	var bot_spacing = screen_width / (opponent_hands.size() + 1)
	return Vector2(bot_spacing * bot_index, 50)

func process_special_effect(card: CardData, player_idx: int):
	match card.type:
		CardData.CardType.SKIP:
			_advance_turn()
		CardData.CardType.REVERSE:
			if total_players == 2:
				_advance_turn()
			else:
				game_direction *= -1
		CardData.CardType.DRAW_TWO:
			draw_stack += 2
		CardData.CardType.WILD_DRAW_FOUR:
			draw_stack += 4
		CardData.CardType.SWAP_HANDS:
			var next_idx = (player_idx + game_direction) % total_players
			if next_idx < 0: next_idx = total_players - 1
			# Pula jogadores que já terminaram na troca
			while finished_players.has(next_idx) and finished_players.size() < total_players - 1:
				next_idx = (next_idx + game_direction) % total_players
				if next_idx < 0: next_idx = total_players - 1
			
			if player_idx == 0: swap_with_player(next_idx)
			elif next_idx == 0: swap_with_player(player_idx)
			else: swap_bots(player_idx, next_idx)

func swap_with_player(bot_idx):
	var player_data: Array[CardData] = []
	for card_ui in hand_container.get_children():
		player_data.append(card_ui.get("data"))
		card_ui.queue_free()
	var bot_hand = opponent_hands[bot_idx - 1]
	opponent_hands[bot_idx - 1] = player_data
	for data in bot_hand: add_card_to_hand(data)
	reorganize_hand()
	reorganize_opponent_hand()

func swap_bots(b1, b2):
	var temp = opponent_hands[b1-1]
	opponent_hands[b1-1] = opponent_hands[b2-1]
	opponent_hands[b2-1] = temp
	reorganize_opponent_hand()

func _on_draw_pile_pressed():
	if current_turn_index != 0 or waiting_for_selection: return
	
	if draw_stack > 0:
		message_label.text = "Você comprou " + str(draw_stack) + " cartas de punição!"
		for i in range(draw_stack): add_card_to_hand(deck_manager.draw_card())
		draw_stack = 0
		await get_tree().create_timer(1.5).timeout
		next_turn()
	else:
		if has_drawn_this_turn:
			next_turn()
		else:
			var drawn_card = deck_manager.draw_card()
			add_card_to_hand(drawn_card)
			has_drawn_this_turn = true
			
			if drawn_card.is_match(current_top_card) or drawn_card.type == CardData.CardType.WILD or drawn_card.type == CardData.CardType.WILD_DRAW_FOUR:
				message_label.text = "Jogue a carta comprada ou clique no baralho de novo para passar a vez."
			else:
				message_label.text = "A carta não serve. Passando a vez..."
				await get_tree().create_timer(1.5).timeout
				next_turn()

func reorganize_hand():
	var cards = hand_container.get_children()
	var count = cards.size()
	if count == 0: return
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

func reorganize_opponent_hand():
	for child in opponent_hand_container.get_children(): child.queue_free()
	var screen_width = get_viewport_rect().size.x
	var bot_spacing = screen_width / (opponent_hands.size() + 1)
	
	for i in range(opponent_hands.size()):
		var bot_idx = i + 1
		var bot_x = bot_spacing * bot_idx
		var bot_hand = opponent_hands[i]
		
		# Calcula um espaçamento dinâmico para não vazar a mão do robô
		var max_width = 120.0
		var card_spacing = min(15.0, max_width / max(1, bot_hand.size()))
		
		# Adicionar Nome do Robô
		var name_label = Label.new()
		name_label.text = "Robô " + str(bot_idx)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(bot_x - 50, 40) # Abaixo das cartas
		name_label.add_theme_font_size_override("font_size", 16)
		if finished_players.has(bot_idx):
			name_label.text += " (Finalizou)"
			name_label.modulate = Color(0.5, 1, 0.5)
		opponent_hand_container.add_child(name_label)
		
		for j in range(bot_hand.size()):
			var scene = load(card_scene_path)
			var card_ui = scene.instantiate()
			var script = load(card_script_path)
			if script: card_ui.set_script(script)
			opponent_hand_container.add_child(card_ui)
			card_ui.setup(null, true)
			card_ui.scale = Vector2(0.4, 0.4)
			card_ui.position = Vector2(bot_x - 30 + (j * card_spacing), -40)
			card_ui.z_index = j

func update_board_visual():
	for child in discard_pile_view.get_children(): child.queue_free()
	var scene = load(card_scene_path)
	var top_ui = scene.instantiate()
	var script = load(card_script_path)
	if script: top_ui.set_script(script)
	discard_pile_view.add_child(top_ui)
	top_ui.setup(current_top_card)
	top_ui.rotation = deg_to_rad(randf_range(-10, 10))
	top_ui.scale = Vector2(0.8, 0.8)

func _advance_turn():
	current_turn_index = (current_turn_index + game_direction) % total_players
	if current_turn_index < 0: current_turn_index = total_players - 1
	# Pula se o jogador já terminou
	if finished_players.has(current_turn_index):
		_advance_turn()

func next_turn():
	_advance_turn()
	
	# Posição travada via script conforme solicitado (puxado levemente para esquerda)
	message_label.position = Vector2(85, 158)
	message_label.add_theme_font_size_override("font_size", 20) # Reduzido para não sobrepor
	
	if current_turn_index == 0:
		message_label.text = "SUA VEZ!"
	else:
		start_bot_turn(current_turn_index)

func _on_nexus_pressed():
	nexus_button.hide()
	_play_nexus_effect()
	
	if hand_container.get_child_count() == 1:
		nexus_called = true # Jogador se salva
		return
		
	# Verifica se algum robô tem 1 carta e pune imediatamente
	for i in range(opponent_hands.size()):
		if opponent_hands[i].size() == 1:
			for c in range(4): opponent_hands[i].append(deck_manager.draw_card())
			reorganize_opponent_hand()
			return

func _play_nexus_effect():
	var fx = Label.new()
	fx.text = "NEXUS!"
	fx.add_theme_font_size_override("font_size", 100)
	fx.add_theme_font_size_override("font_weight", 800)
	fx.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	fx.add_theme_color_override("font_shadow_color", Color(0, 0.5, 1.0, 0.5))
	fx.add_theme_constant_override("shadow_outline_size", 15)
	
	var screen_size = get_viewport_rect().size
	# Centralizar
	fx.position = Vector2(screen_size.x / 2.0 - 200, screen_size.y / 2.0 - 50)
	fx.pivot_offset = Vector2(200, 50)
	$UI.add_child(fx)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fx.scale = Vector2(0.1, 0.1)
	tween.tween_property(fx, "scale", Vector2(1.5, 1.5), 0.8)
	tween.tween_property(fx, "position:y", fx.position.y - 100, 1.5).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(fx, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	
	get_tree().create_timer(1.5).timeout.connect(func(): fx.queue_free())

func _show_color_change_message(text_str: String):
	var msg = Label.new()
	msg.text = text_str
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Coloca no canto esquerdo, puxado mais para a direita (X de 50 para 110)
	msg.position = Vector2(110, 260)
	$UI.add_child(msg)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(msg, "position:y", msg.position.y - 30, 2.0)
	tween.tween_property(msg, "modulate:a", 0.0, 2.0)
	get_tree().create_timer(2.0).timeout.connect(func(): msg.queue_free())

func check_win_condition() -> bool:
	if hand_container.get_child_count() == 0:
		if not finished_players.has(0):
			finished_players.append(0)
			message_label.text = "Muito bem! Você venceu."
			get_tree().paused = true
			_show_game_over_menu()
			return true
	
	# Verifica se sobrou apenas um perdedor
	if finished_players.size() >= total_players - 1:
		if not finished_players.has(0):
			message_label.text = "Que pena, você perdeu!"
		else:
			message_label.text = "FIM DE JOGO!"
		get_tree().paused = true
		_show_game_over_menu()
		return true
		
	return false

func _show_game_over_menu():
	var btn = Button.new()
	btn.text = "Jogar Novamente"
	btn.custom_minimum_size = Vector2(180, 50)
	btn.add_theme_font_size_override("font_size", 20)
	
	# Coloca o botão de recomeçar na lateral esquerda (mesma área do ColorSelector)
	btn.position = Vector2(140, 200)
	
	# IMPORTANTE: Permite que o botão seja clicado mesmo com o jogo pausado
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	
	$UI.add_child(btn)

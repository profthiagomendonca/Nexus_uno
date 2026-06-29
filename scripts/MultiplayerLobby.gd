extends Control

@onready var setup_screen = %SetupScreen
@onready var lobby_screen = %LobbyScreen
@onready var edit_name = %EditName
@onready var edit_code = %EditCode
@onready var create_room_btn = %CreateRoomBtn
@onready var join_room_btn = %JoinRoomBtn
@onready var start_game_btn = %StartGameBtn
@onready var leave_room_btn = %LeaveRoomBtn
@onready var back_button = %BackButton
@onready var room_title = %RoomTitle
@onready var players_container = %PlayersContainer
@onready var message_label = %MessageLabel
@onready var poll_timer = %PollTimer

var style_player: StyleBoxFlat
var font_orbitron: FontFile
var game_started_triggered: bool = false

func _ready():
	# Configurar estilo premium para a lista de jogadores
	style_player = StyleBoxFlat.new()
	style_player.bg_color = Color(0, 0, 0, 0.4)
	style_player.border_width_left = 4
	style_player.border_color = Color(0.2, 0.8, 1.0, 0.8) # Borda neon ciano
	style_player.set_corner_radius_all(5)
	style_player.content_margin_left = 15
	style_player.content_margin_top = 8
	style_player.content_margin_bottom = 8
	
	font_orbitron = load("res://assets/Orbitron.ttf")
	
	# Restaurar último apelido se houver
	edit_name.text = GameSettings.get("player_name_cache") if "player_name_cache" in GameSettings else ""
	if edit_name.text.is_empty():
		edit_name.text = "nome_jogador"
		
	# Conectar sinais dos botões
	back_button.pressed.connect(_on_back_pressed)
	create_room_btn.pressed.connect(_on_create_room_pressed)
	join_room_btn.pressed.connect(_on_join_room_pressed)
	leave_room_btn.pressed.connect(_on_leave_room_pressed)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	
	# Corrigir teclado virtual no mobile web
	edit_name.gui_input.connect(_on_line_edit_gui_input.bind(edit_name, "Digite seu Apelido:"))
	edit_code.gui_input.connect(_on_line_edit_gui_input.bind(edit_code, "Digite o Código da Sala:"))
	
	# Conectar Timer de Polling
	poll_timer.timeout.connect(_on_poll_timeout)
	
	# Conectar sinais do Firebase
	FirebaseManager.room_updated.connect(_on_room_updated)
	FirebaseManager.room_not_found.connect(_on_room_not_found)
	FirebaseManager.game_started.connect(_on_game_started)
	
	# Garantir tela inicial correta
	show_setup_screen()
	
	# Música loop
	$Music.finished.connect($Music.play)

func show_setup_screen():
	setup_screen.show()
	lobby_screen.hide()
	back_button.show()
	poll_timer.stop()
	message_label.text = ""

func show_lobby_screen(code: String):
	setup_screen.hide()
	lobby_screen.show()
	back_button.hide() # Não deixa voltar diretamente sem sair da sala
	room_title.text = "SALA: " + code
	
	# Salvar nome no cache
	GameSettings.set("player_name_cache", edit_name.text)
	
	# Ativar o polling
	poll_timer.start()
	_on_poll_timeout() # Buscar estado inicial imediatamente

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_create_room_pressed():
	var name_text = edit_name.text.strip_edges()
	if name_text.is_empty():
		show_message("Por favor, digite um apelido!", Color(1.0, 0.4, 0.4))
		return
		
	create_room_btn.disabled = true
	show_message("Criando sala no Firebase...", Color(0.2, 0.8, 1.0))
	
	var code = await FirebaseManager.create_room(name_text)
	create_room_btn.disabled = false
	
	if not code.is_empty():
		show_lobby_screen(code)
	else:
		show_message("Erro ao criar sala. Verifique a internet.", Color(1.0, 0.4, 0.4))

func _on_join_room_pressed():
	var name_text = edit_name.text.strip_edges()
	var code_text = edit_code.text.strip_edges()
	
	if name_text.is_empty():
		show_message("Por favor, digite um apelido!", Color(1.0, 0.4, 0.4))
		return
	if code_text.is_empty() or code_text.length() != 4:
		show_message("Código de sala inválido (deve ter 4 dígitos)!", Color(1.0, 0.4, 0.4))
		return
		
	join_room_btn.disabled = true
	show_message("Conectando à sala " + code_text + "...", Color(0.2, 0.8, 1.0))
	
	var success = await FirebaseManager.join_room(code_text, name_text)
	join_room_btn.disabled = false
	
	if success:
		show_lobby_screen(code_text)
	else:
		show_message("Sala não encontrada, cheia ou jogo em andamento.", Color(1.0, 0.4, 0.4))

func _on_leave_room_pressed():
	show_message("Saindo da sala...", Color(0.2, 0.8, 1.0))
	await FirebaseManager.leave_room()
	show_setup_screen()

func _on_poll_timeout():
	FirebaseManager.fetch_room_state()

func _on_room_updated(data: Dictionary):
	# Limpar lista anterior
	for child in players_container.get_children():
		child.queue_free()
		
	var players = FirebaseManager.clean_array(data.get("players", []))
	
	# Exibir jogadores com estilo premium
	for i in range(players.size()):
		var player_name = players[i]
		var panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", style_player)
		
		# Destacar se for o host ou se for você mesmo
		var display_style = style_player.duplicate()
		if player_name == data.get("host", ""):
			display_style.border_color = Color(1.0, 0.8, 0.2, 0.9) # Borda dourada para o Host
		elif player_name == FirebaseManager.player_name:
			display_style.border_color = Color(0.2, 1.0, 0.5, 0.9) # Borda verde para o jogador local
		panel.add_theme_stylebox_override("panel", display_style)
		
		var label = Label.new()
		label.text = player_name
		if player_name == data.get("host", ""):
			label.text += " (Host)"
		if player_name == FirebaseManager.player_name:
			label.text += " (Você)"
			
		label.add_theme_font_size_override("font_size", 16)
		if font_orbitron:
			label.add_theme_font_override("font", font_orbitron)
			
		panel.add_child(label)
		players_container.add_child(panel)
		
	# Habilitar ou ocultar o botão de iniciar partida
	if FirebaseManager.is_host:
		start_game_btn.show()
		start_game_btn.disabled = (players.size() < 2) # Exige ao menos 2 jogadores
	else:
		start_game_btn.hide()

func _on_room_not_found():
	# Se fomos desconectados ou a sala foi apagada
	if lobby_screen.visible:
		show_setup_screen()
		show_message("A sala foi fechada pelo criador.", Color(1.0, 0.4, 0.4))

func _on_start_game_pressed():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Host: Start game pressed')")
	start_game_btn.disabled = true
	show_message("Inicializando partida online...", Color(0.2, 1.0, 0.5))
	
	# Gerar estado de jogo inicial (Somente o Host faz isso)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Host: Creating initial game state')")
	var game_state = create_initial_game_state()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Host: Initial game state created')")
	
	# Atualizar no Firebase
	var success = await FirebaseManager.update_room_state(game_state)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Host: update_room_state success=' + '" + str(success) + "')")
	if success:
		_on_game_started()
	else:
		show_message("Erro ao iniciar jogo. Tente novamente.", Color(1.0, 0.4, 0.4))
		start_game_btn.disabled = false

func _on_game_started():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Host: _on_game_started triggered=' + '" + str(game_started_triggered) + "')")
	if game_started_triggered:
		return
	game_started_triggered = true
	poll_timer.stop() # Parar polling do lobby
	# Mudar para a cena de jogo online
	var err = get_tree().change_scene_to_file("res://scenes/UnoOnlineGame.tscn")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Host: change_scene_to_file code=' + '" + str(err) + "')")

func show_message(text: String, color: Color = Color.WHITE):
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)

# --- Geração de Estado Inicial do UNO ---
# Usamos o banco de dados de cartas para sortear as mãos iniciais e o topo
func create_initial_game_state() -> Dictionary:
	var database = PeriodicDatabase.new()
	var deck_manager_script = load("res://scripts/DeckManager.gd")
	var temp_deck_manager = Node.new()
	temp_deck_manager.set_script(deck_manager_script)
	add_child(temp_deck_manager)
	
	temp_deck_manager.create_deck(database.get_all_elements())
	
	var deck = []
	for card in temp_deck_manager.deck:
		deck.append(card)
		
	temp_deck_manager.queue_free()
	
	# Distribuir mãos
	var players = FirebaseManager.clean_array(FirebaseManager.current_room_data.get("players", []))
	var player_hands = {}
	
	for player in players:
		var hand = []
		for j in range(7):
			var drawn = deck.pop_back()
			if drawn:
				hand.append(FirebaseManager.serialize_card(drawn))
		player_hands[player] = hand
		
	# Carta do topo descartada (deve ser um elemento simples)
	var top_card = deck.pop_back()
	while top_card.type != CardData.CardType.ELEMENT:
		deck.insert(0, top_card) # Devolve pro fundo
		top_card = deck.pop_back()
		
	# Montar o estado
	var state = {
		"status": "playing",
		"deck": FirebaseManager.serialize_deck(deck),
		"discard_pile": [FirebaseManager.serialize_card(top_card)],
		"current_top_card": FirebaseManager.serialize_card(top_card),
		"player_hands": player_hands,
		"current_turn_index": 0,
		"game_direction": 1,
		"draw_stack": 0,
		"finished_players": [],
		"last_action": {
			"type": "start",
			"player": "System",
			"message": "Partida Iniciada!"
		}
	}
	
	return state

func _on_line_edit_gui_input(event: InputEvent, line_edit: LineEdit, title_prompt: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if OS.has_feature("web"):
			var is_mobile = JavaScriptBridge.eval("/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)")
			if is_mobile:
				line_edit.release_focus() # Evita cursor piscando sem teclado
				var result = JavaScriptBridge.eval("prompt('" + title_prompt + "', '" + line_edit.text + "')")
				if result != null:
					var final_text = str(result).strip_edges()
					if line_edit == edit_code:
						line_edit.text = final_text.to_upper()
					else:
						line_edit.text = final_text



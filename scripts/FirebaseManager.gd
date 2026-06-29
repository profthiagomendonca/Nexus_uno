extends Node

const DATABASE_URL = "https://nexus-uno-default-rtdb.firebaseio.com/"

var player_name: String = ""
var room_code: String = ""
var is_host: bool = false

# Dicionário local com os dados da sala atualizada
var current_room_data: Dictionary = {}

# Sinais para avisar outras partes do jogo
signal room_updated(data: Dictionary)
signal room_not_found
signal game_started

# Função auxiliar para limpar e ordenar arrays vindos do Firebase (que podem vir como dicionários)
func clean_array(val) -> Array:
	if val == null:
		return []
	if val is Array:
		return val
	if val is Dictionary:
		var keys = val.keys()
		var int_keys = []
		for k in keys:
			if str(k).is_valid_int():
				int_keys.append(str(k).to_int())
		int_keys.sort()
		var arr = []
		for k_int in int_keys:
			arr.append(val[str(k_int)])
		return arr
	return []

func _ready():
	# Configurar o processamento mesmo quando pausado se necessário
	process_mode = Node.PROCESS_MODE_ALWAYS

# Função genérica para chamadas HTTP com suporte a retentativas automáticas
func firebase_request(path: String, method: HTTPClient.Method, data: Variant = null) -> Variant:
	var max_retries = 3
	var attempt = 0
	
	while attempt < max_retries:
		var http_request = HTTPRequest.new()
		add_child(http_request)
		
		var url = DATABASE_URL + path
		var request_method = method
		
		# Em navegadores de exportações Web (HTML5), métodos PATCH e DELETE podem ser bloqueados ou travar.
		# O Firebase suporta a substituição do método via parâmetro de consulta "?x-http-method-override=PATCH" ou "?x-http-method-override=DELETE" usando POST.
		if request_method == HTTPClient.METHOD_PATCH:
			url += "?x-http-method-override=PATCH"
			request_method = HTTPClient.METHOD_POST
		elif request_method == HTTPClient.METHOD_DELETE:
			url += "?x-http-method-override=DELETE"
			request_method = HTTPClient.METHOD_POST
			
		var headers = ["Content-Type: application/json"]
		var json_str = ""
		if data != null:
			json_str = JSON.stringify(data)
			
		print("firebase_request: Sending request to path: ", path, " | original_method: ", method, " | actual_method: ", request_method, " | attempt: ", attempt)
			
		var error = http_request.request(url, headers, request_method, json_str)
		if error != OK:
			print("firebase_request: request failed to initiate. error: ", error)
			http_request.queue_free()
			attempt += 1
			if attempt < max_retries:
				await (Engine.get_main_loop() as SceneTree).create_timer(0.3).timeout
			continue
			
		var result = await http_request.request_completed
		var response_code = result[1]
		var response_headers = result[2]
		var body = result[3]
		
		print("firebase_request: request completed. response_code: ", response_code)
			
		http_request.queue_free()
		
		if response_code >= 200 and response_code < 300:
			var response_str = body.get_string_from_utf8()
			if response_str == "null" or response_str == "":
				return null
			var json = JSON.new()
			var parse_err = json.parse(response_str)
			if parse_err == OK:
				return json.data
			else:
				attempt += 1
				if attempt < max_retries:
					await (Engine.get_main_loop() as SceneTree).create_timer(0.3).timeout
				continue
		else:
			attempt += 1
			if attempt < max_retries:
				await (Engine.get_main_loop() as SceneTree).create_timer(0.3).timeout
			else:
				return {"error": "Erro HTTP", "code": response_code}
				
	return {"error": "Falha de conexão após retentativas"}

# --- Lógica de Lobbies/Salas ---

# Cria uma sala no Firebase com um código de 4 dígitos
func create_room(host_name: String) -> String:
	player_name = host_name
	is_host = true
	
	# Gerar código de 4 dígitos aleatório
	randomize()
	room_code = str(randi_range(1000, 9999))
	
	var initial_state = {
		"status": "waiting",
		"host": host_name,
		"players": [host_name],
		"state_version": 1
	}
	
	var path = "rooms/" + room_code + ".json"
	var response = await firebase_request(path, HTTPClient.METHOD_PUT, initial_state)
	
	if response is Dictionary and response.has("error"):
		room_code = ""
		is_host = false
		return ""
		
	return room_code

# Entra em uma sala existente
func join_room(target_code: String, joining_name: String) -> bool:
	player_name = joining_name
	is_host = false
	room_code = target_code
	
	var path = "rooms/" + room_code + ".json"
	var room = await firebase_request(path, HTTPClient.METHOD_GET)
	
	if room == null or (room is Dictionary and room.has("error")):
		room_code = ""
		return false
		
	var status = room.get("status", "")
	if status != "waiting":
		room_code = ""
		return false
		
	var players = clean_array(room.get("players", []))
	if players.size() >= 4:
		room_code = ""
		return false
		
	players.append(joining_name)
	
	# Usar PUT para salvar a lista de jogadores limpa para truncar corretamente no Firebase
	await firebase_request("rooms/" + room_code + "/players.json", HTTPClient.METHOD_PUT, players)
	
	var update_data = {
		"state_version": room.get("state_version", 1) + 1
	}
	
	var response = await firebase_request(path, HTTPClient.METHOD_PATCH, update_data)
	if response is Dictionary and response.has("error"):
		room_code = ""
		return false
		
	return true

# Deleta ou sai da sala
func leave_room():
	if room_code.is_empty():
		return
		
	var path = "rooms/" + room_code + ".json"
	if is_host:
		# Host deleta a sala inteira
		await firebase_request(path, HTTPClient.METHOD_DELETE)
	else:
		# Player normal se remove da lista
		var room = await firebase_request(path, HTTPClient.METHOD_GET)
		if room is Dictionary and not room.has("error"):
			var players = clean_array(room.get("players", []))
			players.erase(player_name)
			
			# Salva a lista de jogadores limpa via PUT para truncar corretamente
			await firebase_request("rooms/" + room_code + "/players.json", HTTPClient.METHOD_PUT, players)
			
			var update_data = {
				"state_version": room.get("state_version", 1) + 1
			}
			await firebase_request(path, HTTPClient.METHOD_PATCH, update_data)
			
	room_code = ""
	is_host = false
	player_name = ""
	current_room_data = {}

# Atualiza a sala inteira (ou campos específicos)
func update_room_state(data: Dictionary) -> bool:
	print("FirebaseManager: update_room_state called")
	if room_code.is_empty():
		return false
	
	# Sempre incrementa o state_version
	var next_version = current_room_data.get("state_version", 0) + 1
	data["state_version"] = next_version
	
	var path = "rooms/" + room_code + ".json"
	print("FirebaseManager: sending PATCH request to path: ", path)
	var response = await firebase_request(path, HTTPClient.METHOD_PATCH, data)
	print("FirebaseManager: PATCH request complete")
		
	if response is Dictionary and response.has("error"):
		print("FirebaseManager: PATCH request returned error: ", response.get("error"))
		return false
		
	# Atualizar os dados locais imediatamente para não ficar desatualizado
	var old_status = current_room_data.get("status", "waiting")
	for key in data:
		current_room_data[key] = data[key]
	var new_status = current_room_data.get("status", "waiting")
	
	if old_status == "waiting" and new_status == "playing":
		print("FirebaseManager: Emitting game_started")
		emit_signal("game_started")
		
	return true

# Consulta o estado atual da sala
func fetch_room_state() -> Dictionary:
	if room_code.is_empty():
		return {}
		
	var path = "rooms/" + room_code + ".json"
	var response = await firebase_request(path, HTTPClient.METHOD_GET)
	
	if response == null:
		emit_signal("room_not_found")
		return {}
		
	if response is Dictionary:
		if response.has("error"):
			return {}
		
		# Limpar arrays conhecidos para evitar que o Firebase os retorne como Dicionários
		if response.has("players"):
			response["players"] = clean_array(response["players"])
		if response.has("finished_players"):
			response["finished_players"] = clean_array(response["finished_players"])
		if response.has("deck"):
			response["deck"] = clean_array(response["deck"])
		if response.has("discard_pile"):
			response["discard_pile"] = clean_array(response["discard_pile"])
		
		# Limpar também as mãos individuais dos jogadores em player_hands
		if response.has("player_hands") and response["player_hands"] is Dictionary:
			var hands = response["player_hands"]
			for p_name in hands:
				hands[p_name] = clean_array(hands[p_name])
		
		# Detecta transição de status de "waiting" para "playing" para emitir sinal
		var old_status = current_room_data.get("status", "waiting")
		var new_status = response.get("status", "waiting")
		
		current_room_data = response
		emit_signal("room_updated", current_room_data)
		
		if old_status == "waiting" and new_status == "playing":
			emit_signal("game_started")
			
		return response
		
	return {}

# --- Funções de Sincronização de Cartas ---

func serialize_card(card: CardData) -> Dictionary:
	if not card:
		return {}
	return {
		"type": card.type,
		"atomic_number": card.atomic_number,
		"symbol": card.symbol,
		"name": card.name,
		"group": card.group,
		"period": card.period,
		"color": [card.color.r, card.color.g, card.color.b, card.color.a],
		"curiosity": card.curiosity,
		"color_override": [card.color_override.r, card.color_override.g, card.color_override.b, card.color_override.a]
	}

func deserialize_card(dict: Dictionary) -> CardData:
	if dict.is_empty():
		return null
	var card = CardData.new()
	card.type = dict.get("type", CardData.CardType.ELEMENT) as CardData.CardType
	card.atomic_number = dict.get("atomic_number", 0)
	card.symbol = dict.get("symbol", "")
	card.name = dict.get("name", "")
	card.group = dict.get("group", 0)
	card.period = dict.get("period", 0)
	
	var c_arr = dict.get("color", [1.0, 1.0, 1.0, 1.0])
	card.color = Color(c_arr[0], c_arr[1], c_arr[2], c_arr[3])
	
	card.curiosity = dict.get("curiosity", "")
	
	var co_arr = dict.get("color_override", [0.0, 0.0, 0.0, 0.0])
	card.color_override = Color(co_arr[0], co_arr[1], co_arr[2], co_arr[3])
	
	return card

func serialize_deck(deck: Array) -> Array:
	var serialized = []
	for card in deck:
		serialized.append(serialize_card(card))
	return serialized

func deserialize_deck(serialized_deck: Variant) -> Array:
	var clean_deck_arr = clean_array(serialized_deck)
	var deck = []
	for card_dict in clean_deck_arr:
		if card_dict is Dictionary:
			deck.append(deserialize_card(card_dict))
	return deck

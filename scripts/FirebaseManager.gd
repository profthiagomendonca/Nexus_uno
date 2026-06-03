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

func _ready():
	# Configurar o processamento mesmo quando pausado se necessário
	process_mode = Node.PROCESS_MODE_ALWAYS

# Função genérica para chamadas HTTP
func firebase_request(path: String, method: HTTPClient.Method, data: Variant = null) -> Variant:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var url = DATABASE_URL + path
	var headers = ["Content-Type: application/json"]
	var json_str = ""
	if data != null:
		json_str = JSON.stringify(data)
		
	var error = http_request.request(url, headers, method, json_str)
	if error != OK:
		http_request.queue_free()
		return {"error": "Falha ao iniciar requisição"}
		
	var result = await http_request.request_completed
	var response_code = result[1]
	var response_headers = result[2]
	var body = result[3]
	
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
			return {"error": "Falha ao processar JSON"}
	else:
		return {"error": "Erro HTTP", "code": response_code}

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
		
	var players = room.get("players", [])
	if players.size() >= 4:
		room_code = ""
		return false
		
	players.append(joining_name)
	
	var update_data = {
		"players": players,
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
			var players = room.get("players", [])
			players.erase(player_name)
			var update_data = {
				"players": players,
				"state_version": room.get("state_version", 1) + 1
			}
			await firebase_request(path, HTTPClient.METHOD_PATCH, update_data)
			
	room_code = ""
	is_host = false
	player_name = ""
	current_room_data = {}

# Atualiza a sala inteira (ou campos específicos)
func update_room_state(data: Dictionary) -> bool:
	if room_code.is_empty():
		return false
	
	# Sempre incrementa o state_version
	var next_version = current_room_data.get("state_version", 0) + 1
	data["state_version"] = next_version
	
	var path = "rooms/" + room_code + ".json"
	var response = await firebase_request(path, HTTPClient.METHOD_PATCH, data)
	if response is Dictionary and response.has("error"):
		return false
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

func deserialize_deck(serialized_deck: Array) -> Array:
	var deck = []
	for card_dict in serialized_deck:
		if card_dict is Dictionary:
			deck.append(deserialize_card(card_dict))
	return deck

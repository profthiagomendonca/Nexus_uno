extends Node

var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []

signal deck_reshuffled

func create_deck(elements_data: Dictionary):
	deck.clear()
	
	var families = [
		{"name": "Alcalinos", "group": 1, "color": Color(0.8, 0.2, 0.2)},
		{"name": "Metais", "group": 11, "color": Color(1, 0.8, 0)},
		{"name": "Não-metais", "group": 16, "color": Color(0.2, 0.8, 0.2)},
		{"name": "Halogênios", "group": 17, "color": Color(0.2, 0.6, 1.0)}
	]
	
	# Organizar elementos por grupo para fácil acesso
	var elements_by_group = {}
	for atomic_num in elements_data:
		var e = elements_data[atomic_num].duplicate()
		var g = e["group"]
		if not elements_by_group.has(g):
			elements_by_group[g] = []
		elements_by_group[g].append(e)
		# Adicionar nº atômico aos dados para facilitar
		e["atomic_number"] = atomic_num

	for family in families:
		var group_id = family["group"]
		var available_elements = elements_by_group.get(group_id, [])
		
		# Gerar 10 cartas de elemento por família (Períodos 0-9 no Uno original, aqui simularemos)
		for i in range(10):
			var count = 1 if i == 0 else 2
			for c in range(count):
				var card = CardData.new()
				card.type = CardData.CardType.ELEMENT
				
				# Tenta pegar um elemento real da tabela, ou usa um genérico se não houver
				if available_elements.size() > 0:
					var element_data = available_elements[i % available_elements.size()]
					card.name = element_data["name"]
					card.symbol = element_data["symbol"]
					card.atomic_number = element_data["atomic_number"]
					card.period = element_data["period"]
					card.curiosity = element_data.get("curiosity", "")
				else:
					card.name = family["name"] + " " + str(i)
					card.symbol = family["name"][0] + str(i)
					card.period = i if i > 0 else 1
				
				card.group = group_id
				card.color = family["color"]
				deck.append(card)
		
		for c in range(2):
			_add_special_card(CardData.CardType.SKIP, "BLOQUEIO", family)
			_add_special_card(CardData.CardType.REVERSE, "INVERSÃO", family)
			_add_special_card(CardData.CardType.DRAW_TWO, "REAÇÃO +2", family)
		_add_special_card(CardData.CardType.SWAP_HANDS, "LIGAÇÃO\nCOVALENTE", family)

	# Cartas Coringa (Wild)
	for c in range(4):
		_add_wild_card(CardData.CardType.WILD, "Catalisador", Color(1, 1, 1))
		_add_wild_card(CardData.CardType.WILD_DRAW_FOUR, "Cadeia +4", Color(1, 1, 1))
		
	deck.shuffle()
	print("Baralho pronto com ", deck.size(), " cartas.")

func _add_special_card(type, card_name, family):
	var card = CardData.new()
	card.type = type
	card.name = card_name
	card.group = family["group"]
	card.color = family["color"]
	deck.append(card)

func _add_wild_card(type, card_name, color):
	var card = CardData.new()
	card.type = type
	card.name = card_name
	card.color = color
	deck.append(card)

func draw_card() -> CardData:
	if deck.is_empty():
		reshuffle_discard_pile()
	return deck.pop_back()

func discard_card(card: CardData):
	discard_pile.append(card)

func reshuffle_discard_pile():
	if discard_pile.size() > 1:
		var top_card = discard_pile.pop_back()
		deck = discard_pile.duplicate()
		deck.shuffle()
		discard_pile = [top_card]
		deck_reshuffled.emit()
		print("Baralho reembaralhado com ", deck.size(), " cartas.")

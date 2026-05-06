extends Resource
class_name CardData

enum CardType { ELEMENT, SKIP, REVERSE, DRAW_TWO, WILD, WILD_DRAW_FOUR, SWAP_HANDS }

@export var type: CardType = CardType.ELEMENT
@export var atomic_number: int = 0
@export var symbol: String = ""
@export var name: String = ""
@export var group: int = 0
@export var period: int = 0
@export var color: Color = Color.WHITE
@export var curiosity: String = ""

@export var color_override: Color = Color.TRANSPARENT

func is_match(other: CardData) -> bool:
	# Se a carta que estou tentando jogar é um Coringa, ela sempre pode ser jogada
	if type == CardType.WILD or type == CardType.WILD_DRAW_FOUR:
		return true
	
	# Se a carta no topo é um Coringa, ela agora tem uma cor (group) definida.
	# O match deve ser feito pela cor ou pelo tipo.
	
	# Mesma família (cor)
	if group > 0 and group == other.group:
		return true
		
	# Mesmo período (número)
	if period > 0 and period == other.period:
		return true
		
	# Mesmo tipo especial (ex: SWAP sobre SWAP, SKIP sobre SKIP)
	if type != CardType.ELEMENT and type == other.type:
		return true
		
	return false

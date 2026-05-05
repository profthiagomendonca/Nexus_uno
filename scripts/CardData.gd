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
	if type == CardType.WILD or type == CardType.WILD_DRAW_FOUR or type == CardType.SWAP_HANDS or \
	   other.type == CardType.WILD or other.type == CardType.WILD_DRAW_FOUR or other.type == CardType.SWAP_HANDS:
		return true
		
	if group > 0 and group == other.group:
		return true
		
	if period > 0 and period == other.period:
		return true
		
	if type != CardType.ELEMENT and type == other.type:
		return true
		
	return false

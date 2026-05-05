extends Control
class_name CardUI

@onready var symbol_label = $Margin/Content/CenterArea/Symbol
@onready var name_label = $Margin/Content/Name
@onready var atomic_number_label = $Margin/Content/TopRow/AtomicNumber
@onready var curiosity_label = $Margin/Content/Curiosity
@onready var period_top_label = $Margin/Content/TopRow/PeriodTop
@onready var period_bottom_label = $Margin/Content/BottomRow/PeriodBottom
@onready var special_value_label = $Margin/Content/TopRow/SpecialValue
@onready var group_label = $Margin/Content/GroupLabel
@onready var background = $Background
@onready var border = $Border
@onready var icon_rect = $Margin/Content/CenterArea/Icon
@onready var center_text = $Margin/Content/CenterArea/CenterText
@onready var back_visual = $Back

var noble_gas_icon = "res://assets/Icone_gas_nobre.png"
var exothermic_icon = "res://assets/Icone_reacao_exotermica.png"
var reverse_icon = "res://assets/Icone_reverso.png"
var wild_icon = "res://assets/Icone_coringa.png"
var chain_reaction_icon = "res://assets/Icone_reacao_cadeia.png"
var swap_icon = "res://assets/Icone_troca_mao.png"
var card_back_texture = "res://assets/Verso_carta.png"

var data: CardData
var is_back: bool = false

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if data: update_ui()

func setup(card_data: CardData, show_as_back: bool = false):
	data = card_data
	is_back = show_as_back
	if is_inside_tree(): update_ui()

func update_ui():
	if is_back:
		back_visual.texture = load(card_back_texture)
		back_visual.show()
		background.hide()
		border.hide()
		$Margin.hide()
		return

	if not data: return
	
	back_visual.hide()
	background.show()
	border.show()
	$Margin.show()
	special_value_label.hide()
	center_text.hide()
	icon_rect.hide()
	group_label.show()
	
	# Configurações de Texto
	period_top_label.text = str(data.period) if data.period > 0 else ""
	period_bottom_label.text = period_top_label.text
	group_label.text = _get_group_name(data.group)
	
	if data.type == CardData.CardType.ELEMENT:
		symbol_label.text = data.symbol
		name_label.text = data.name
		name_label.add_theme_font_size_override("font_size", 16)
		curiosity_label.text = data.curiosity
		curiosity_label.show()
		atomic_number_label.text = str(data.atomic_number)
		atomic_number_label.show()
		icon_rect.hide()
		symbol_label.show()
	else:
		symbol_label.hide()
		name_label.text = data.name
		name_label.add_theme_font_size_override("font_size", 22) # Nome maior para especiais
		curiosity_label.hide()
		atomic_number_label.hide()
		icon_rect.show()
		
		var tex_path = ""
		match data.type:
			CardData.CardType.SKIP: tex_path = noble_gas_icon
			CardData.CardType.REVERSE: tex_path = reverse_icon
			CardData.CardType.DRAW_TWO:
				tex_path = exothermic_icon
				special_value_label.text = "+2"
				special_value_label.show()
			CardData.CardType.WILD: tex_path = wild_icon
			CardData.CardType.WILD_DRAW_FOUR:
				tex_path = ""
				center_text.text = "+4"
				center_text.show()
				icon_rect.hide()
				special_value_label.text = "+4"
				special_value_label.show()
			CardData.CardType.SWAP_HANDS:
				tex_path = swap_icon
				special_value_label.text = "TROCA"
				special_value_label.show()
			
		if tex_path != "": icon_rect.texture = load(tex_path)
		
	var card_color = data.color
	if data.color_override != Color.TRANSPARENT:
		card_color = data.color_override
		
	if border is Panel:
		var stylebox = border.get_theme_stylebox("panel").duplicate()
		if stylebox is StyleBoxFlat:
			stylebox.border_color = card_color
			stylebox.shadow_color = card_color
			stylebox.shadow_color.a = 0.5
			border.add_theme_stylebox_override("panel", stylebox)

func _get_group_name(g_id: int) -> String:
	match g_id:
		1: return "Alcalinos"
		2: return "Alcalino-terrosos"
		11: return "Metais"
		13: return "Boro"
		14: return "Carbono"
		15: return "Nitrogênio"
		16: return "Não-metais"
		17: return "Halogênios"
		18: return "Gases Nobres"
		_: return ""

func _on_mouse_entered():
	if is_back: return
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
	tween.parallel().tween_property(self, "position:y", -30, 0.2)
	z_index = 100 

func _on_mouse_exited():
	if is_back: return
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(self, "position:y", 0, 0.2)
	z_index = 0

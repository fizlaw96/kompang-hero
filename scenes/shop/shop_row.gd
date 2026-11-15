extends PanelContainer

const Levels := preload("res://scripts/levels.gd")

signal buy_pressed(item: Dictionary, price: int)

@onready var buy: Button = $Margin/Row/BuyButton


func setup(item: Dictionary) -> void:
	var id: String = item.id
	var is_shield := id == "shield"
	var lv := int(Save.shields) if is_shield else int(Save.upgrades[id])
	var maxed := (not is_shield) and lv >= int(item.max)
	var price := int(item.prices[0]) if is_shield else int(item.prices[mini(lv, int(item.max) - 1)])

	$Margin/Row/Info/Name.text = item.name
	$Margin/Row/Info/Desc.text = item.desc
	if is_shield:
		$Margin/Row/Info/Effect.text = Levels.shop_effect(id, 1)
		$Margin/Row/Info/Status.text = "Owned: %d shield%s" % [lv, "" if lv == 1 else "s"]
	else:
		$Margin/Row/Info/Effect.text = ("MAX: " + Levels.shop_effect(id, lv)) if maxed else ("Next: " + Levels.shop_effect(id, lv + 1))
		$Margin/Row/Info/Status.text = "Level %d / %d" % [lv, int(item.max)]
	buy.text = "MAXED" if maxed else "BUY  %d" % price
	buy.disabled = maxed
	buy.pressed.connect(func() -> void: buy_pressed.emit(item, price))

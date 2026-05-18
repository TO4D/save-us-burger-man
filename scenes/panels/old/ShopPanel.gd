extends Control

signal open_shop_requested

@onready var open_shop_button: Button = $OpenShopButton
@onready var money_label: Label = $MoneyLabel

func _ready() -> void:
	open_shop_button.pressed.connect(_on_open_shop_pressed)
	GameState.money_changed.connect(_on_money_changed)
	BusinessDay.business_state_changed.connect(_on_business_state_changed)
	_update_money_display()
	_update_button_visibility()
	

func on_show(_data: Dictionary = {}) -> void:
	_update_money_display()
	_update_button_visibility()

func _update_money_display() -> void:
	money_label.text = "%d Gold" % GameState.money
	
func _update_button_visibility() -> void:
	open_shop_button.visible = not BusinessDay.is_open

func _on_money_changed(_new_amount: int) -> void:
	_update_money_display()

func _on_business_state_changed(_is_open: bool) -> void:
	_update_button_visibility()

func _on_open_shop_pressed() -> void:
	print("[ShopPanel] 영업 개시 요청")
	open_shop_requested.emit()

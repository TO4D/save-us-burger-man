extends Control

signal report_confirmed

@onready var customers_served_label: Label = $Content/CustomersServedLabel
@onready var customers_missed_label: Label = $Content/CustomersMissedLabel
@onready var customers_declined_label: Label = $Content/CustomersDeclinedLabel
@onready var morning_revenue_label: Label = $Content/MorningRevenueLabel
@onready var lunch_revenue_label: Label = $Content/LunchRevenueLabel
@onready var evening_revenue_label: Label = $Content/EveningRevenueLabel
@onready var total_revenue_label: Label = $Content/TotalRevenueLabel
@onready var confirm_button: Button = $Content/ConfirmButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)

func on_show(_data: Dictionary = {}) -> void:
	_update_report()

func _update_report() -> void:
	customers_served_label.text = "처리한 손님: %d명" % GameState.todays_customers_served
	customers_missed_label.text = "놓친 손님: %d명" % GameState.todays_customers_missed
	customers_declined_label.text = "거절한 손님: %d명" % GameState.todays_customers_declined


	var morning_rev = BusinessDay.revenue_by_slot.get(BusinessDay.TimeSlot.MORNING, 0)
	var lunch_rev = BusinessDay.revenue_by_slot.get(BusinessDay.TimeSlot.LUNCH, 0)
	var evening_rev = BusinessDay.revenue_by_slot.get(BusinessDay.TimeSlot.EVENING, 0)

	morning_revenue_label.text = "아침: %d Gold" % morning_rev
	lunch_revenue_label.text = "점심: %d Gold" % lunch_rev
	evening_revenue_label.text = "저녁: %d Gold" % evening_rev
	total_revenue_label.text = "총 매출: %d Gold" % GameState.todays_revenue
	
func _on_confirm_pressed() -> void:
	print("[DailyReport] 확인 - 가게 화면으로")
	report_confirmed.emit()

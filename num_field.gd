@tool
class_name NumField
extends HBoxContainer

signal value_changed(new_value)

@export var json_key : String
@export var field_name : String:
	set(with):
		field_name = with
		if has_node("Label"): $Label.text = field_name

var value : int:
	set(with):
		value = clamp(with, min_value, max_value)
		$SpinBox.value = value
		emit_signal("value_changed",value)

@export var min_value : int:
	set(with):
		min_value = with
		$SpinBox.min_value = min_value
@export var max_value : int:
	set(with):
		max_value = with
		$SpinBox.max_value = max_value


func _ready():
	$Label.text = field_name
	$SpinBox.value_changed.connect(_on_spinbox_changed)
	value_changed.connect(Global._on_tmb_updated.bind(json_key))


func _on_spinbox_changed(new_value):
	value = new_value

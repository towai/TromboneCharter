@tool
class_name NumField
extends HBoxContainer

signal value_changed(new_value)

@export var json_key : String
@export var field_name : String:
	set(with):
		field_name = with
		if has_node("Label"): $Label.text = field_name

@export var is_float : bool:
	set(with):
		is_float = with
		if !has_node("SpinBox"): return
		if is_float:
			# if step is 0 it rounds regardless, might be a godot bug
			# 0.001 is seemingly as low as it'll let me go
			$SpinBox.rounded = false
			$SpinBox.step = 0.001
		else:
			$SpinBox.rounded = true
			$SpinBox.step = 1
			$SpinBox.value = int(value)

@export var value : float:
	set(with):
		#print("float set ",with)
		value = clamp(with, min_value, max_value)
		if !is_float: value = int(value)
		if !has_node("SpinBox"): return
		$SpinBox.value = value
		emit_signal("value_changed",value)

@export var min_value : float:
	set(with):
		min_value = with
		if !has_node("SpinBox"): return
		$SpinBox.min_value = min_value
@export var max_value : float:
	set(with):
		max_value = with
		if !has_node("SpinBox"): return
		$SpinBox.max_value = max_value


func _ready():
	$Label.text = field_name
	$SpinBox.value_changed.connect(_on_spinbox_changed)
	if !Engine.is_editor_hint(): value_changed.connect(Global._on_tmb_updated.bind(json_key))


func _on_spinbox_changed(new_value):
	value = new_value


func _on_spin_box_gui_input(_e) -> void:
	emit_signal("gui_input",_e)

@tool
class_name NumField
extends HBoxContainer

signal value_changed(new_value)

@onready var line_edit = $SpinBox.get_line_edit()

@export var json_key : String
@export var field_name : String:
	set(with):
		field_name = with
		if has_node("Label"): $Label.text = field_name

@export var is_float : bool:
	set(with):
		is_float = with
		if !has_node("SpinBox"): return # in startup
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
		value = clamp(with, min_value, max_value)
		if !is_float: value = int(value)
		if !has_node("SpinBox"): return
		$SpinBox.value = value
		value_changed.emit(value)

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


func _ready() -> void:
	$Label.text = field_name
	$SpinBox.value_changed.connect(_on_spinbox_value_changed)
	line_edit.gui_input.connect(_gui_input)
	if !Engine.is_editor_hint(): value_changed.connect(Global._on_tmb_updated.bind(json_key))


func _gui_input(event: InputEvent) -> void:
	event = event as InputEventKey
	if event == null: return
	if event.is_action_pressed("ui_accept"): line_edit.release_focus()


func _on_spinbox_value_changed(new_value) -> void: value = new_value

# TODO is this even used?
func _on_spin_box_gui_input(event:InputEvent) -> void: gui_input.emit(event)

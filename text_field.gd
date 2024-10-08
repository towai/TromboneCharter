@tool
class_name TextField
extends HBoxContainer

@export var json_key : String
@export var field_name : String
var value : String:
	get: return $TextEntry.text
	set(string):
		value = string
		if !has_node("TextEntry"): return
		$TextEntry.text = string
		if is_inside_tree(): Global.tmb_updated.emit()

func _ready() -> void: $Label.text = field_name

func _gui_input(event: InputEvent) -> void:
	event = event as InputEventKey
	if event == null: return
	if event.keycode == KEY_ENTER: $TextEntry.release_focus()

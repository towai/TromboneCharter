@tool
class_name TextField
extends HBoxContainer

@export var json_key : String
@export var field_name : String:
	set(with):
		field_name = with
		# needed else it tries to do this on load before the child exists
		if has_node("Label"): $Label.text = field_name
var value : String:
	get: return $TextEntry.text
	set(string):
		value = string
		$TextEntry.text = string

func _ready():
	$Label.text = field_name

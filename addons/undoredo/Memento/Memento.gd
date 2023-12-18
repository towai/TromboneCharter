@tool
class_name Memento
extends Node

var _state: Dictionary = {}

func _init(state: Dictionary):
	_state = state

func get_state():
	return _state

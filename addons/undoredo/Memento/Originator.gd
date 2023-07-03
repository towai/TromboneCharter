@tool
class_name MementoOriginator
extends Node

var _state := {}

func get_state():
#	"A `getter` for the objects state"
	return _state

func set_state(state: Dictionary):
	_state = state

func get_memento() -> Memento:
#	"A `getter` for the objects state but packaged as a Memento"
	return Memento.new(_state)

func set_memento(memento: Memento):
	_state = memento.get_state()

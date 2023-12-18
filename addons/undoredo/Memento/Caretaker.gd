@tool
class_name MementoCaretaker
extends Node

var _originator
var _undos := []
var _redos := []

# Guardian. Provides a narrow interface to the mementos
func _init(originator):
	_originator = originator

func create():
	# "Store a new Memento of the Originators current state"
	var memento = _originator.get_memento()
	_undos.append(memento)

func undo():
	var memento = _undos.pop_back()
	_redos.push_back(memento)
	_originator.set_memento(memento)
	
func redo():
	var memento = _redos.pop_back()
	_undos.push_back(memento)
	_originator.set_memento(memento)

func can_undo():
	return not _undos.is_empty()

func can_redo() -> int:
	return not _redos.is_empty()

func clear():
	_undos = []
	_redos = []

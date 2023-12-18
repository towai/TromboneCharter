@tool
extends Node

signal undone
signal redone

@export var target: Node = null
var originator
var caretaker

func _enter_tree():
	originator = MementoOriginator.new()
	caretaker = MementoCaretaker.new(originator)
	if not target:
		target = get_parent()

func save_state(state: Dictionary):
	originator.set_state(state)
	caretaker.create()

func undo():
	if caretaker.can_undo():
		caretaker.undo()
		var state = originator.get_memento().get_state()
		if not apply_to_parent(state):
			undo()
		emit_signal("undone", state)
	
	return false
	
func redo():
	if caretaker.can_redo():
		caretaker.redo()
		var state = originator.get_memento().get_state()
		if not apply_to_parent(state):
			redo()
		emit_signal("redone", state)

	return false

func can_undo():
	return caretaker.can_undo()

func can_redo():
	return caretaker.can_redo()

func clear():
	caretaker = MementoCaretaker.new(originator)

func apply_to_parent(state: Dictionary):
	var changed = false
	for key in state:
		if target[key] != state[key]:
			changed = true
		target[key] = state[key]

	return changed

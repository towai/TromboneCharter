extends Node2D

"""
Store the state after the properties are changed.
Undoing will keep the latest change, and it can be undone then redone.
Example: 
Increment to 4, undo, the 4 is kept and can be redone, if you undo down to 3, you can redo back to 4.

You should store the initial state to allow you to undo all the way to the original state.
"""

var counter = 0

func _ready():
	# Store the initial state
	$Undoer.save_state({"counter":counter})
	$Label.text = str(counter)

func _on_undo_button_pressed():
	$Undoer.undo()
	update_label()

func _on_redo_button_pressed():
	$Undoer.redo()
	update_label()

func _on_increment_button_pressed():
	counter += 1
	$Undoer.save_state({"counter":counter})
	update_label()

func _on_decrement_button_pressed():
	counter -= 1
	$Undoer.save_state({"counter":counter})
	update_label()

func update_label():
	$Label.text = str(counter)

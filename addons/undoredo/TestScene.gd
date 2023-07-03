extends Node2D

"""
Store the state before the properties are changed.
Undoing will essentially discard the latest change.
Example: 
Increment to 4, undo, the 4 is now discarded and can't be redone, you can only redo up to 3
"""

var counter = 0

func _ready():
	$Label.text = str(counter)

func _on_undo_button_pressed():
	$Undoer.undo()
	update_label()

func _on_redo_button_pressed():
	$Undoer.redo()
	update_label()

func _on_increment_button_pressed():
	$Undoer.save_state({"counter":counter})
	counter += 1
	update_label()

func _on_decrement_button_pressed():
	$Undoer.save_state({"counter":counter})
	counter -= 1
	update_label()

func update_label():
	$Label.text = str(counter)

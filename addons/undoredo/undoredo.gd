@tool
extends EditorPlugin


func _enter_tree():
	# Initialization of the plugin goes here.
	add_custom_type("Undoer", "Memento", preload("Undoer.gd"), preload("icon.svg"))


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("MementoOriginator")
	remove_custom_type("MementoCaretaker")
	remove_custom_type("MementoState")


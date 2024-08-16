class_name SaveCheck # asks user if unsaved changes need saving
extends ConfirmationDialog

var grammar : String
var plural := "edits"
var unsaved_changes : int :
	set(value) :
		if value < 0:
			grammar = "ahead of"
		else:
			grammar = "behind"
		if abs(value) == 1:
			plural = "edit"
		unsaved_changes = value

func _ready():
	cancel_button_text = "Wait, Go Back"
	ok_button_text = "Continue"

func save_checker():
	unsaved_changes = Global.save_point - Global.revision
	if unsaved_changes:
		dialog_text = "There are unsaved changes.\nYou are %s %s %s your last save." % [abs(unsaved_changes),plural,grammar]
	else:
		dialog_text = "All set. Happy boning!"

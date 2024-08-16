class_name SaveCheck # asks user if unsaved changes need saving
extends ConfirmationDialog

enum {
	RISKY_QUIT,
	RISKY_NEW,
	RISKY_LOAD,
}
static var risky_action := RISKY_QUIT
static var grammar : String
static var plural := "edits"
static var unsaved_changes : int:
	set(value):
		grammar = "ahead of" if value < 0 else "behind"
		plural = "edit" if abs(value) == 1 else "edits"
		unsaved_changes = value
	get: # refresh on access!
		unsaved_changes = Global.save_point - Global.revision
		return unsaved_changes
signal confirm_new
signal confirm_load


func _ready():
	cancel_button_text = "Wait, Go Back"
	ok_button_text = "Continue"
	about_to_popup.connect(_set_text)
	confirmed.connect(_confirm)


func _set_text():
	match risky_action:
			RISKY_QUIT: dialog_text = "Really quit and discard unsaved changes?"
			RISKY_NEW:  dialog_text = "Really discard your chart and unsaved changes?"
			RISKY_LOAD: dialog_text = "Really load a new chart and discard unsaved changes?"
	dialog_text += "\n\nYou are %s %s %s your last save." % [abs(unsaved_changes),plural,grammar]


func _confirm():
	match risky_action:
			RISKY_QUIT: get_tree().quit()
			RISKY_NEW:  confirm_new.emit()
			RISKY_LOAD: confirm_load.emit()

class_name BindEdit
extends PanelContainer

var rebinding := false

const CONFLICT_COLOR := Color(0.18,0.16,0.05,0.6)
const KeyBind = EditorOpts.KeyBind
var bind: KeyBind
var can_rebind : bool:
	get: return bind.rebindable && !(bind.action.begins_with("ui"))
	set(_v): assert(false)
# we have a vbox to display multi key bindings,
# but any multi-key bindings are builtin ones we don't need or want to rebind
@onready var button : Button = $HBC/VBC/Button
@onready var label : Label = $HBC/Label
static var normal_button_color : Color # doesn't start out null, starts out black?? see doc
var opts_dialog : EditorOpts

signal rebind_signal # TODO bad convention-breaking name

func init_values(caller:EditorOpts,_bind:KeyBind):
	opts_dialog = caller
	bind = _bind

func _ready() -> void:
	label.text = bind.friendly_name
	button.disabled = !can_rebind
	if normal_button_color == Color.BLACK:
		normal_button_color = button.get("theme_override_styles/normal").bg_color
	
	if get_index() % 2:
		var panel : StyleBoxFlat = get("theme_override_styles/panel")
		panel.bg_color = Color.TRANSPARENT
	
	_set_button_text()


func _set_button_text():
	if bind.events.is_empty(): # BUG recolor doesn't work on rebind timeout for some reason
		button.set("theme_override_colors/font_color",Color(0.5,0.5,0.5))
		button.set("theme_override_colors/font_focus_color",Color(0.5,0.5,0.5))
		button.text = "∅"
	
	else:
		button.set("theme_override_colors/font_color",Color.WHITE)
		button.set("theme_override_colors/font_focus_color",Color.WHITE)
		for j in bind.events.size(): match j:
			0: button.text = EditorOpts.get_key_as_text(bind.events[0])
			_:
				var new_button = button.duplicate()
				new_button.text = EditorOpts.get_key_as_text(bind.events[j])
				get_node("HBC/VBC").add_child(new_button)


func _on_button_pressed() -> void:
	if opts_dialog.waiting_for_input: return
	
	opts_dialog.waiting_for_input = true
	button.set_pressed_no_signal(true)
	rebinding = true
	opts_dialog.conflict_advise.text = "Press Backspace or Escape to cancel binding."
	
	button.text = "."
	for i in 5:
		get_tree().create_timer(1.0).timeout.connect(rebind_signal.emit)
		await rebind_signal
		if !rebinding:
			_end_rebind()
			return
		button.text += " ."
	
	get_tree().create_timer(1.0).timeout.connect(rebind_signal.emit)
	await rebind_signal
	_end_rebind()


func _end_rebind(): 
	button.set_pressed_no_signal(false)
	_set_button_text()
	
	opts_dialog.waiting_for_input = false
	opts_dialog.refresh_potential_conflicts()


func _input(event: InputEvent) -> void:
	if !rebinding: return
	
	var keyevent := event as InputEventKey
	if keyevent == null: return
	
	# BUG you can still manage to bind something to esc/backspace,
	#     but as of right now i don't know exactly what causes it to slip through
	if keyevent.keycode == KEY_BACKSPACE || keyevent.keycode == KEY_ESCAPE: # allow bailing
		rebinding = false
		rebind_signal.emit()
	
	if keyevent.pressed: return # getting keyup allows chorded binds!
	
	keyevent.pressed = true
	match bind.keytype: # keep the events clean
		KeyBind.KEY_PHYSICAL:
			keyevent.keycode = 0
			keyevent.unicode = 0
		KeyBind.KEY_UNICODE:
			keyevent.keycode = 0
			keyevent.physical_keycode = 0
		KeyBind.SECRET_THIRD_THING: assert(false,"we don't use this keytype, something went wrong")
	if bind.events.is_empty(): bind.events.append(keyevent)
	else: bind.remap(keyevent)
	rebinding = false
	rebind_signal.emit()

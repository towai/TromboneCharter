class_name EditorOpts
extends Window

const builtin_bindings : PackedStringArray = [ "ui_accept", "ui_select", "ui_cancel",
"ui_focus_next", "ui_focus_prev", "ui_left", "ui_right", "ui_up", "ui_down", "ui_page_up",
"ui_page_down", "ui_home", "ui_end", "ui_cut", #"ui_copy", "ui_paste", "ui_undo", "ui_redo",
"ui_text_completion_query", "ui_text_completion_accept", "ui_text_completion_replace",
"ui_text_newline", "ui_text_newline_blank", "ui_text_newline_above", "ui_text_indent",
"ui_text_dedent", "ui_text_backspace", "ui_text_backspace_word", "ui_text_backspace_word.macos",
"ui_text_backspace_all_to_left", "ui_text_backspace_all_to_left.macos", "ui_text_delete",
"ui_text_delete_word", "ui_text_delete_word.macos", "ui_text_delete_all_to_right",
"ui_text_delete_all_to_right.macos", "ui_text_caret_left", "ui_text_caret_word_left",
"ui_text_caret_word_left.macos", "ui_text_caret_right", "ui_text_caret_word_right",
"ui_text_caret_word_right.macos", "ui_text_caret_up", "ui_text_caret_down",
"ui_text_caret_line_start", "ui_text_caret_line_start.macos", "ui_text_caret_line_end",
"ui_text_caret_line_end.macos", "ui_text_caret_page_up",  "ui_text_caret_page_down",
"ui_text_caret_document_start", "ui_text_caret_document_start.macos", "ui_text_caret_document_end",
"ui_text_caret_document_end.macos", "ui_text_caret_add_below", "ui_text_caret_add_below.macos",
"ui_text_caret_add_above", "ui_text_caret_add_above.macos","ui_text_scroll_up",
"ui_text_scroll_up.macos", "ui_text_scroll_down", "ui_text_scroll_down.macos", "ui_text_select_all",
"ui_text_select_word_under_caret", "ui_text_select_word_under_caret.macos",
"ui_text_add_selection_for_next_occurrence", "ui_text_skip_selection_for_next_occurrence",
"ui_text_clear_carets_and_selection", "ui_text_toggle_insert_mode", "ui_menu", "ui_text_submit",
"ui_graph_duplicate", "ui_graph_delete", "ui_filedialog_up_one_level", "ui_filedialog_refresh",
"ui_filedialog_show_hidden", "ui_swap_input_direction", ]

const special : PackedStringArray = [ # don't allow rebinding these shortcuts
	"save_chart", "save_chart_as", "new_chart", "load_chart"
]
const bind_edit_scene = preload("res://bind_edit.tscn")
@onready var conflict_advise : Label = %ConflictAdvise

var waiting_for_input := false

var keybinds : Array[KeyBind] = []
class KeyBind: # TODO EditorOpts probably shouldn't own this
	var events: Array[InputEventKey] ## can be null!
	var action: String ## Name of the action in the input map.
	var friendly_name: String ## Name that will show up in the dialog.
	var rebindable := true
	var keytype: int ## null if event is null!
	## Need to keep track of this to know what value to set.
	## Unicode keys are used for ones on alphanumeric keys which may stand for something relevant
	## Physical keys are used for modifiers that (generally) live on Shift/Ctrl/Alt
	enum { KEY_PHYSICAL, KEY_UNICODE, SECRET_THIRD_THING }
	
	func _init(action_name:String):
		action = action_name
		# only care to support 1 bind but redo has multiple... aagh
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: events.append(event)
		
		friendly_name = action.to_snake_case().capitalize().replace("Hold","(Hold)")
		if action in special || action.begins_with("ui"): rebindable = false
		if action.begins_with("ui"): friendly_name = friendly_name.substr(3)
		
		if events.is_empty(): return
		events = events # only care to support 1 bind per bind but builtins have multiple...
		
		var key_as_text : String = events[0].as_text_physical_keycode() 
		if key_as_text.contains("(Unset)"):
			key_as_text = events[0].as_text_key_label()
			keytype = KEY_UNICODE
		if key_as_text.contains("(Unset)"):
			keytype = SECRET_THIRD_THING # "Keycode (Latin Equivalent)", only used by builtins
		else: keytype = KEY_PHYSICAL
	func remap(event:InputEventKey):
		InputMap.action_erase_event(action,events[0])
		InputMap.action_add_event(action,event)
		events[0] = event

# TODO EditorOpts probably shouldn't own this
static func get_key_as_text(event:InputEventKey) -> String:
	if event == null: return "∅"
	var keycode := event.as_text_physical_keycode()
	if keycode.contains("(Unset)"): keycode = event.as_text_key_label()
	if keycode.contains("(Unset)"): keycode = event.as_text_keycode()
	return keycode.replace("+"," + ")


func _ready() -> void:
	await get_tree().process_frame # give cfg the chance to load first
	for action in InputMap.get_actions():
		if action in builtin_bindings: continue
		keybinds.append(KeyBind.new(action))
	for i in keybinds.size():
		var bind : KeyBind = keybinds[i]
		if bind.keytype == KeyBind.SECRET_THIRD_THING: print(bind.friendly_name)
		var new_bind_edit : BindEdit = bind_edit_scene.instantiate()
		new_bind_edit.init_values(self,bind)
		# sort the non-rebindable ones to the end
		if bind.action.begins_with("ui"): %BindList.call_deferred("add_child",new_bind_edit)
		else: %BindList.add_child(new_bind_edit)
		#print(bind.friendly_name,"\t:\t",get_keycode(bind.event))
	refresh_potential_conflicts()

func _process(_delta: float) -> void: pass

func _input(_event: InputEvent) -> void: pass


func has_potential_conflict(caller:BindEdit) -> Array[BindEdit]:
	if caller.bind.events.is_empty(): return []
	
	var conflicts : Array[BindEdit] = []
	for child in %BindList.get_children():
		var bedit := child as BindEdit
		
		if bedit == null || bedit == caller || bedit.bind.events.is_empty(): continue
		if bedit.bind.events[0].is_match(caller.bind.events[0],true):
			conflicts.append(bedit)
	
	return conflicts

## Returns whether any conflicts were found in the keybind list.
func refresh_potential_conflicts() -> bool:
	var clean_binds : Array[BindEdit] = []
	for child in %BindList.get_children(): clean_binds.append(child)
	var dirty_binds : Array[BindEdit] = []
	
	for bedit in clean_binds:
		var conflicts = has_potential_conflict(bedit)
		if !conflicts.is_empty():
			dirty_binds.append_array(conflicts)
			dirty_binds.append(bedit)
		
		while dirty_binds.count(bedit) > 1: dirty_binds.erase(bedit)
	
	for bedit in dirty_binds:
		clean_binds.erase(bedit)
		bedit.button.get("theme_override_styles/normal").bg_color = BindEdit.CONFLICT_COLOR
	
	for bedit in clean_binds:
		bedit.button.get("theme_override_styles/normal").bg_color = BindEdit.normal_button_color
	
	if !dirty_binds.is_empty():
		conflict_advise.text = "Potential key conflict found. This may be fine, or may not be. You're the expert."
	else: conflict_advise.text = " "
	
	return !dirty_binds.is_empty()

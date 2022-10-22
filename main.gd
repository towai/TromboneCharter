extends Control


var tmb : TMBInfo:
	get: return Global.working_tmb
	set(value): Global.working_tmb = value
signal chart_loaded
var popup_location : Vector2i:
	get: return DisplayServer.window_get_position(0) + (Vector2i.ONE * 100)
@onready var cfg = ConfigFile.new()


func _ready():
	DisplayServer.window_set_min_size(Vector2(1120,540))
	$Instructions.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var err = cfg.load("user://config.cfg")
	if err:
		print(error_string(err))
		return
	$LoadDialog.current_dir = cfg.get_value("Config","saved_dir")
	print($SaveDialog.current_path)
	_on_new_chart_confirmed()


func _on_description_text_changed(): tmb.description = %Description.text

func _on_refresh_button_pressed(): emit_signal("chart_loaded")

func _on_help_button_pressed(): show_popup($Instructions)


func show_popup(window:Window):
	window.position = popup_location
	window.show()


func _on_new_chart_pressed(): show_popup($NewChartConfirm)
func _on_new_chart_confirmed():
	tmb = TMBInfo.new()
	print("new tmb")
	emit_signal("chart_loaded")


func _on_load_chart_pressed(): show_popup($LoadDialog)
func _on_load_dialog_file_selected(path):
	print("Load tmb from %s" % path)
	var err = tmb.load_from_file(path)
	if err:
		print("Chart load failed")
		return
	cfg.set_value("Config","saved_dir",$LoadDialog.current_dir)
	$SaveDialog.current_dir = $LoadDialog.current_dir
	$SaveDialog.current_path = $LoadDialog.current_path
	try_cfg_save()
	emit_signal("chart_loaded")


func _on_save_chart_pressed():
	tmb.lyrics = %LyricsEditor.package_lyrics()
	if Input.is_key_pressed(KEY_SHIFT):
		tmb.save_to_file($SaveDialog.current_path,$SaveDialog.current_dir)
	else: show_popup($SaveDialog)
func _on_save_dialog_file_selected(path):
	tmb.save_to_file(path,$SaveDialog.current_dir)
	cfg.set_value("Config","saved_dir",$SaveDialog.current_dir)
	try_cfg_save()


func try_cfg_save():
		if !cfg.has_section("Config"): return
		var err = cfg.save("user://config.cfg")
		if err:
			print("Oh noes")
			print(error_string(err))


func _on_copy_button_pressed():
	if %CopyTarget.value + Global.settings.section_length > tmb.endpoint: return
	if Input.is_key_pressed(KEY_SHIFT):
		_on_copy_confirmed()
		return
	$CopyConfirm.show()

func _on_copy_confirmed():
	var start = Global.settings.section_start
	var length = Global.settings.section_length
	
	var notes = tmb.find_all_notes_in_section(start,length)
	if notes.is_empty():
		print("empy")
		return
	
	var copy_target = Global.settings.section_target
	
	# now checked when you hit the button, so shouldn't be possible to reach this
	# keeping it anyway
	if copy_target + length > tmb.endpoint: return
	
	tmb.clear_section(copy_target,length)
	for note in notes:
		note[TMBInfo.NOTE_BAR] += copy_target
		tmb.notes.append(note)
	emit_signal("chart_loaded")

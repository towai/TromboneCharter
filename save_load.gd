class_name SaveLoad
extends Node
# TODO does this really need to be a Node rather than an Object?
const bindables : PackedStringArray = [
	"toggle_playback", "toggle_insert_taps", "toggle_slide_prop", "toggle_snap_pitch",
	"toggle_snap_time", "hold_drag_playhead", "hold_insert_taps", "hold_slide_prop",
	"hold_snap_pitch", "hold_snap_time", "edit_mode", "select_mode", "lyrics_mode",
]
@onready var main : Node = get_parent():
	set(_v): assert(false,"We're inseparable!")
var cfg:ConfigFile:
	get: return main.cfg
	set(_v): assert(false,"I don't own that!")
var tmb:TMBInfo:
	get: return main.tmb
	set(_v): assert(false,"I don't own that!")
static var loading := false

# TODO  - ton of functions called from main that we should own instead
#		- this should own chart_loaded signal but i'm not fixing it right now!
func on_load_dialog_file_selected(path:String):
	print("Load tmb from %s" % path)
	var dir = path.substr(0,path.rfind("/"))
	if dir == path: dir = path.substr(0,path.rfind("\\"))
	var err = tmb.load_from_file(path)
	if err:
		%ErrorPopup.dialog_text = "TMB load failed.\n%s" % TMBInfo.load_result_string(err)
		main.show_popup(%ErrorPopup)
		return dir
	###Dew reset u/r variables
	Global.clear_future_edits(true)
	###
	%SaveDialog.current_dir = dir
	%SaveDialog.current_path = path
	cfg.set_value("Config","saved_dir", dir)
	main.try_cfg_save()
	return dir


func validate_win_path(path:String):
	if path[1] == ':': return path
	print("driveless path %s" % path)
	var drive : String
	var saved_dir = cfg.get_value("Config","saved_dir")
	if saved_dir == null:
		%Alert.alert("no saved dir in config! did you delete it?",
				Vector2(12, %ViewSwitcher.global_position.y + 38),
				Alert.LV_ERROR)
		return path
	if saved_dir[1] != ':':
		print("couldn't get drive letter from saved directory in cfg file!")
		return path
	drive = saved_dir.substr(0,saved_dir.find('/'))
	if drive == saved_dir:
		print("Saved dir in cfg uses backslashes -- user manually edited cfg file?")
		drive = saved_dir.substr(0,saved_dir.find('\\'))
	return drive + path


func save_tmb_to_file(filename : String) -> int:
	print("try to save tmb to %s" % filename)
	var f = FileAccess.open(filename,FileAccess.WRITE)
	if f == null:
		var err = FileAccess.get_open_error()
		print(error_string(err))
		return err
	
	var dict := tmb.to_dict()
	f.store_string(JSON.stringify(dict))
	print("finished saving")
	return OK


func try_cfg_save():
	print("try cfg save")
	if !cfg.has_section("Config"): return
	# start afresh in case of bind name change or deletion
	if cfg.has_section("Binds"): cfg.erase_section("Binds")
	
	for child in %BindList.get_children():
		var bedit : BindEdit = child as BindEdit
		if bedit == null: assert(false)
		if !bedit.can_rebind: continue
		
		if !bedit.bind.events.is_empty():
			cfg.set_value("Binds",bedit.bind.action, bedit.bind.events[0])
		else: cfg.set_value("Binds",bedit.bind.action, "") # make sure it's there
	#"snap_pitch","snap_time","propagate_slide_changes","note_tooltips"
	cfg.set_value("Config","propagate_slide_changes",%PropagateChanges.button_pressed)
	cfg.set_value("Config","note_tooltips", %NoteTooltips.button_pressed)
	cfg.set_value("Config","build_waveform",%BuildWaveform.button_pressed)
	cfg.set_value("Config","hi_res_wave",   %HiResWave.button_pressed)
	cfg.set_value("Config","preview_type",  %PreviewType.selected)
	cfg.set_value("Config","draw_microtones",  %DrawMicrotones.button_pressed)
	
	var err = cfg.save("user://config.cfg")
	if err:
		print("Oh noes")
		print(error_string(err))


func try_load_cfg_values() -> PackedInt64Array:
	loading = true
	var errs : PackedInt64Array = []
	for key in cfg.get_section_keys("Config"):
		match key:
			"saved_dir": continue
			"propagate_slide_changes","note_tooltips":
				Global.settings.set(key, cfg.get_value("Config",key))
			"build_waveform": %BuildWaveform.set("button_pressed",cfg.get_value("Config",key))
			"hi_res_wave": %HiResWave.set("button_pressed",cfg.get_value("Config",key))
			"preview_type": %PreviewType.set("selected",cfg.get_value("Config",key))
			"draw_microtones": %DrawMicrotones.set("button_pressed",cfg.get_value("Config",key))
			_:
				print("cfg: unknown key ",key)
				errs.append(ERR_INVALID_DATA)
	errs.append( try_load_binds() )
	loading = false
	return errs


func try_load_binds() -> int:
	if !cfg.has_section("Binds"):
		print("no binds saved yet")
		return ERR_DOES_NOT_EXIST
	var rebinds := cfg.get_section_keys("Binds")
	if rebinds != bindables:
		print("something weird has happened")
		return ERR_INVALID_DATA
	else:
		for rebind in rebinds:
			InputMap.action_erase_events(rebind)
			if cfg.get_value("Binds",rebind) is InputEventKey:
				InputMap.action_add_event(rebind,cfg.get_value("Binds",rebind))
	return OK

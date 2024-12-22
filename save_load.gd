class_name SaveLoad
extends Node
# we have nodes connecting their signals to this via the scene tree therefore a node this shall be.
# it would also be very cumbersome to have to get references to all the nodes it's using via %
const bindables : PackedStringArray = [
	"toggle_playback", "toggle_insert_taps", "toggle_slide_prop", "toggle_snap_pitch",
	"toggle_snap_time", "hold_drag_playhead", "hold_insert_taps", "hold_slide_prop",
	"hold_snap_pitch", "hold_snap_time", "hold_drag_selection", "edit_mode", "lyrics_mode",
]
const mnemonic_binds : PackedInt64Array = [
	KEY_SPACE, KEY_NONE, KEY_NONE, KEY_P,
	KEY_T, KEY_SHIFT, KEY_ALT, KEY_ALT,
	KEY_SHIFT, KEY_CTRL, KEY_S, KEY_E, KEY_L,
]
const cluster_binds : PackedInt64Array = [ # negative indicates Shift modifier
	KEY_SPACE, KEY_NONE, KEY_NONE, -KEY_F,
	-KEY_D, KEY_SHIFT, KEY_A, KEY_A,
	KEY_F, KEY_D, KEY_S, KEY_E, KEY_R,
]
@onready var main : Node = get_parent():
	set(_v): assert(false,"We're inseparable!")
var cfg : ConfigFile:
	get: return main.cfg
	set(_v): assert(false,"I don't own that!")
var tmb : TMBInfo:
	get: return main.tmb
	set(_v): assert(false,"I don't own that!")
var settings : Settings:
	get: return main.settings
	set(_v): assert(false,"I don't own that!")
const settings_properties := [ "propagate_slide_changes","note_tooltips","paste_behavior",
	"return_playhead", ]
static var loading := false
var default_cfg : ConfigFile:
	get: return main.default_cfg
	set(value): main.default_cfg = value
# TODO replace with a better solution?
var last_used_drive_letter := ""


func _ready() -> void: Global.saveload = self


func generate_default_cfg() -> void:
	default_cfg = ConfigFile.new()
	for action in bindables:
		var events = InputMap.action_get_events(action)
		@warning_ignore("incompatible_ternary") # i know what i'm doing but thanks for the reminder
		default_cfg.set_value("Binds",action,"" if events.is_empty() else events[0])
	# use the untouched scene tree for other settings
	default_cfg.set_value("Config","build_waveform",%BuildWaveform.button_pressed)
	default_cfg.set_value("Config","hi_res_wave",   %HiResWave.button_pressed)
	default_cfg.set_value("Config","preview_type",  %PreviewType.selected)
	for setting in settings_properties:
		default_cfg.set_value("Config",setting,settings.get(setting))


# TODO  - ton of functions called from main that we should own instead
#		- this should own chart_loaded signal but i'm not fixing it right now!
func on_load_dialog_file_selected(path:String) -> String:
	print("Load tmb from %s" % path)
	var dir = path.substr(0,path.rfind("/"))
	if dir == path: dir = path.substr(0,path.rfind("\\"))
	var err = tmb.load_from_file(path)
	if err:
		%ErrorPopup.dialog_text = "TMB load failed.\n%s" % TMBInfo.load_result_string(err)
		main.show_popup(%ErrorPopup)
		return dir
	### Dew reset u/r variables
	Global.clear_future_edits(true)
	###
	%SaveDialog.current_dir = dir
	%SaveDialog.current_path = path
	cfg.set_value("Config","saved_dir", dir)
	main.try_cfg_save()
	return dir


func validate_win_path(path:String) -> String:
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


func try_cfg_save() -> void:
	print("try cfg save")
	if !cfg.has_section("Config"): return
	# start afresh in case of bind name change or deletion or reorder
	if cfg.has_section("Binds"): cfg.erase_section("Binds")
	
	for child in %BindList.get_children():
		var bedit : BindEdit = child as BindEdit
		if bedit == null: assert(false)
		if !bedit.can_rebind: continue
		
		if !bedit.bind.events.is_empty():
			cfg.set_value("Binds",bedit.bind.action, bedit.bind.events[0])
		else: cfg.set_value("Binds",bedit.bind.action, "") # make sure it's there
	cfg.set_value("Config","hi_res_wave",   %HiResWave.button_pressed)
	cfg.set_value("Config","preview_type",  %PreviewType.selected)
	cfg.set_value("Config","draw_microtones",  %DrawMicrotones.button_pressed)
	for setting in settings_properties: cfg.set_value("Config",setting,settings.get(setting))
	
	var err = cfg.save("user://config.cfg")
	if err:
		print("Oh noes")
		print(error_string(err))


func try_load_cfg_values(config:ConfigFile) -> PackedInt64Array:
	loading = true
	var errs : PackedInt64Array = []
	for key in config.get_section_keys("Config"):
		match key:
			"saved_dir": continue
			"build_waveform": %BuildWaveform.set("button_pressed",config.get_value("Config",key))
			"hi_res_wave": %HiResWave.set("button_pressed",config.get_value("Config",key))
			"preview_type": %PreviewType.set("selected",config.get_value("Config",key))
			"draw_microtones": %DrawMicrotones.set("button_pressed",config.get_value("Config",key))
			_:
				if key in settings_properties: Global.settings.set(key, config.get_value("Config",key))
				else:
					print("cfg: unknown key ",key)
					errs.append(ERR_INVALID_DATA)
	errs.append( try_load_binds(config) )
	loading = false
	return errs


func try_load_binds(config:ConfigFile) -> int:
	if !config.has_section("Binds"):
		print("no binds saved yet")
		return ERR_DOES_NOT_EXIST
	
	var rebinds := config.get_section_keys("Binds")
	if rebinds != bindables:
		print("something weird has happened")
		return ERR_INVALID_DATA
	
	for rebind in rebinds:
		InputMap.action_erase_events(rebind)
		if config.get_value("Binds",rebind) is InputEventKey:
			InputMap.action_add_event(rebind,config.get_value("Binds",rebind))
	
	%EditorOpts.refresh_bind_list()
	return OK


func try_load_bind_preset(preset:PackedInt64Array) -> void:
	for i in bindables.size():
		var action = bindables[i]
		var keycode = preset[i]
		
		for bedit in %BindList.get_children():
			bedit = bedit as BindEdit
			if bedit.bind.action == action:
				var event = InputEventKey.new()
				event.shift_pressed = (keycode < 0)
				match bedit.bind.keytype:
					EditorOpts.KeyBind.KEY_PHYSICAL: event.physical_keycode = abs(keycode)
					EditorOpts.KeyBind.KEY_UNICODE:  event.unicode = abs(keycode)
					EditorOpts.KeyBind.SECRET_THIRD_THING:
						assert(false,"we don't use this keytype, something went wrong")
				bedit.bind.update_input_map(event)
	
	%EditorOpts.refresh_bind_list()


func _on_mnemonic_binds_pressed() -> void: try_load_bind_preset(mnemonic_binds)
func _on_cluster_binds_pressed() -> void: try_load_bind_preset(cluster_binds)

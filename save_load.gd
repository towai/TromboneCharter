class_name SaveLoad
extends Node

@onready var main : Node = get_parent()
var cfg:ConfigFile:
	get: return main.cfg
	set(value): assert(false)
var tmb:TMBInfo:
	get: return main.tmb
	set(value): assert(false)

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
		return
		
	if saved_dir[1] != ':':
		print("couldn't get drive letter from saved directory in cfg file!")
		return
	drive = saved_dir.substr(0,saved_dir.find('/'))
	if drive == saved_dir:
		print("Saved dir in cfg uses backslashes -- user manually edited cfg file?")
		drive = saved_dir.substr(0,saved_dir.find('\\'))
	path = drive + path


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

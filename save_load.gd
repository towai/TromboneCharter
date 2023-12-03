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

# TODO remove this whole thing once properly deprecated
func load_wav_or_convert_ogg(dir:String) -> int:
	var err = main.try_to_load_wav(dir + "/song.wav")
	if err:
		print("No wav loaded -- %s" % error_string(err))
		if %Settings.convert_ogg:
			print("try to convert song.ogg to wav")
			DirAccess.open(dir)
			err = DirAccess.get_open_error()
			if err:
				print("DirAccess error : %s" % error_string(err))
				return err
			var oggpath := dir + "/song.ogg"
			if !FileAccess.file_exists(oggpath):
				print("song.ogg not present in the tmb's folder")
				return ERR_FILE_NOT_FOUND
			err = Global.ffmpeg_worker.try_to_convert_ogg(oggpath)
			if !err:
				var wav_err = main.try_to_load_wav(dir + "/song.wav")
				if wav_err: print("ffmpeg success but couldn't load resulting wav?")
			else: # redundant to print explanation, label tells us if ffmpeg's missing
				print("conversion failed: " + error_string(err))
				return err
	
	%WAVLoadedLabel.text = "song.wav loaded!" if %TrackPlayer.stream != null \
			else "no ffmpeg!" if err == -1 else "no song.wav loaded!"
	return err


func validate_win_path(path:String):
	if path[1] == ':': return path
	print("driveless path %s" % path)
	var drive : String
	var saved_dir = cfg.get_value("Config","saved_dir")
	if saved_dir == null:
		$Alert.alert("no saved dir in config! did you delete it?",
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


func save_tmb_to_file(filename : String, dir : String) -> int:
	print("try to save tmb to %s" % filename)
	var f = FileAccess.open(filename,FileAccess.WRITE)
	if f == null:
		var err = FileAccess.get_open_error()
		print(error_string(err))
		return err
	
	var dict := tmb.to_dict(dir)
	f.store_string(JSON.stringify(dict))
	print("finished saving")
	return OK

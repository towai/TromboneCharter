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


func load_wav_or_convert_ogg(dir:String):
	var err = main.try_to_load_wav(dir + "/song.wav")
	if err:
		print("No wav loaded -- %s" % error_string(err))
		if %Settings.convert_ogg:
			print("try to convert song.ogg to wav")
			DirAccess.open(dir)
			err = DirAccess.get_open_error()
			if err:
				print("DirAccess error : %s" % error_string(err))
				return
			if !FileAccess.file_exists(dir + "/song.ogg"):
				print("song.ogg not present in the tmb's folder")
				return
			err = main.try_to_convert_ogg(dir + "/song.ogg")
			if !err:
				var wav_err = main.try_to_load_wav(dir + "/song.wav")
				if wav_err: print("ffmpeg success but couldn't load resulting wav?")
			else: # redundant to print explanation, label tells us if ffmpeg's missing
				print("conversion failed: " + error_string(err))
	
	%WAVLoadedLabel.text = "song.wav loaded!" if %WavPlayer.stream != null \
			else "no ffmpeg!" if err == -1 else "no song.wav loaded!"


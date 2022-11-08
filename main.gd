extends Control


var tmb : TMBInfo:
	get: return Global.working_tmb
	set(value): Global.working_tmb = value
signal chart_loaded
var popup_location : Vector2i:
	get: return DisplayServer.window_get_position(0) + (Vector2i.ONE * 100)
@onready var cfg = ConfigFile.new()


func _ready():
	DisplayServer.window_set_min_size(Vector2(1256,540))
	$Instructions.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$ErrorPopup.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var err = cfg.load("user://config.cfg")
	if err:
		print("Couldn't load config: %s" % error_string(err))
		show_popup($Instructions) # probably first load
		return
	
	var argv : PackedStringArray = OS.get_cmdline_args()
	if !argv.is_empty() && argv[0].ends_with(".tmb"):
		var path = argv[0]
		var dir = argv[0].substr(0,argv[0].rfind("/"))
		if dir == path: dir = argv[0].substr(0,argv[0].rfind("\\"))
		print("%s passed in as tmb" % path)
		$LoadDialog.current_dir = dir
		_on_load_dialog_file_selected(path)
		return
	
	$LoadDialog.current_dir = cfg.get_value("Config","saved_dir")
	
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
	%Settings.use_custom_colors = false
	%WavPlayer.stream = null
	print("new tmb")
	emit_signal("chart_loaded")


func _on_load_chart_pressed(): show_popup($LoadDialog)
func _on_load_dialog_file_selected(path):
	print("Load tmb from %s" % path)
	var dir = path.substr(0,path.rfind("/"))
	if dir == path: dir = path.substr(0,path.rfind("\\"))
	var err = tmb.load_from_file(path)
	if err:
		$ErrorPopup.dialog_text = "TMB load failed.\n%s" % TMBInfo.load_result_string(err)
		show_popup($ErrorPopup)
		return
	
	$SaveDialog.current_dir = dir
	$SaveDialog.current_path = path
	cfg.set_value("Config","saved_dir", dir)
	try_cfg_save()
	
	%WavPlayer.stream = null
	emit_signal("chart_loaded")
	if %Settings.load_wav_on_chart_load:
		err = try_to_load_wav(dir + "/song.wav")
		if err:
			print("No wav loaded -- %s" % error_string(err))
			if %Settings.convert_ogg:
				print("Try to convert song.ogg")
				DirAccess.open(dir)
				err = DirAccess.get_open_error()
				if err:
					print("DirAccess error : %s" % error_string(err))
					return
				err = try_to_convert_ogg(dir + "/song.ogg")
				if !err:
					var wav_err = try_to_load_wav(dir + "/song.wav")
					if wav_err: print("no ffmpeg error but couldn't load wav??")
				else: print("ogg->wav conversion result %d (-1 means ffmpeg was not found)"
						% err)
	
	%WAVLoadedLabel.text = "song.wav loaded!" if %WavPlayer.stream != null \
			else "no ffmpeg!" if err == -1 else "no song.wav loaded!"
	


func try_to_load_wav(path:String) -> int:
	print("Try load wav from %s" % path)
	var f = FileAccess.open(path,FileAccess.READ)
	if f == null:
		var err = FileAccess.get_open_error()
		return err
	
	var stream := AudioLoader.loadfile(path, false) as AudioStreamWAV
	if stream == null :
		print("stream null?")
		return ERR_FILE_CANT_READ
	elif stream.data == null || stream.data.is_empty():
		print("no data?")
		return ERR_FILE_CANT_READ
	
	%WavPlayer.stream = stream
	return OK


func try_to_convert_ogg(path:String) -> int:
	var dir = path.substr(0,path.rfind("/"))
	if dir == path: dir = path.substr(0,path.rfind("\\"))
	var args = PackedStringArray([
			"-i",
			'%s' % path,
			'%s' % (dir + "/song.wav")
			])
	print(args)
	var output = []
	var err = OS.execute("ffmpeg",args,output,true,true)
	print(output[0].c_unescape())
	print(output.size())
	return err


func _on_save_chart_pressed():
	tmb.lyrics = %LyricsEditor.package_lyrics()
	if Input.is_key_pressed(KEY_SHIFT):
		_on_save_dialog_file_selected($SaveDialog.current_path)
	else: show_popup($SaveDialog)

func _on_save_dialog_file_selected(path:String):
	if path[1] != ':':
		print("driveless path %s" % path)
		var drive : String
		var saved_dir = cfg.get_value("Config","saved_dir")
		if saved_dir == null:
			$Alert.alert("couldn't save! you tried to break it on purpose didn't you",
					Vector2(12, %ViewSwitcher.global_position.y + 38),
					Alert.LV_ERROR)
			return
			
		if saved_dir[1] != ':':
			print("Fuck shit!!")
			return
		drive = saved_dir.substr(0,saved_dir.find('/'))
		if drive == saved_dir:
			print("Cock backslash")
			drive = saved_dir.substr(0,saved_dir.find('\\'))
		path = drive + path
	var err = tmb.save_to_file(path,$SaveDialog.current_dir)
	if err == OK:
		$Alert.alert("chart saved!", Vector2(12, %ViewSwitcher.global_position.y + 38),
				Alert.LV_SUCCESS)
	else: 
		$Alert.alert("couldn't save to %s! %s" % [path, error_string(err)],
				Vector2(72, %NewChart.global_position.y + 20),
				Alert.LV_ERROR, 2)
		return
	var dir = path.substr(0,path.rfind("/"))
	cfg.set_value("Config", "saved_dir", dir)
	try_cfg_save()
	
	if !%Settings.load_wav_on_chart_load: return
	err = try_to_load_wav(dir + "/song.wav")
	if err != OK:
		print("No wav loaded -- %s" % error_string(err))


func try_cfg_save():
	print("try cfg save")
	if !cfg.has_section("Config"): return
	var err = cfg.save("user://config.cfg")
	if err:
		print("Oh noes")
		print(error_string(err))


func _on_copy_button_pressed():
	if %CopyTarget.value + Global.settings.section_length > tmb.endpoint:
		$Alert.alert("Can't copy -- would run past the chart endpoint!",
				Vector2(%SectionSelection.position.x - 12, %Settings.position.y - 12),
				Alert.LV_ERROR)
		return
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
	
	tmb.clear_section(copy_target,length)
	for note in notes:
		note[TMBInfo.NOTE_BAR] += copy_target
		tmb.notes.append(note)
	emit_signal("chart_loaded")

extends Control

@onready var cfg = ConfigFile.new()
@onready var saveload : SaveLoad = $SaveLoad
@onready var settings : Settings = %Settings
@onready var ffmpeg_worker : FFmpegWorker = Global.ffmpeg_worker
signal chart_loaded
var tmb : TMBInfo:
	get: return Global.working_tmb
	set(value): Global.working_tmb = value
var popup_location : Vector2i:
	get: return DisplayServer.window_get_position(0) + (Vector2i.ONE * 100)


func _ready():
	DisplayServer.window_set_min_size(Vector2(1256,540))
	$Instructions.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$ErrorPopup.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var err = cfg.load("user://config.cfg")
	if err:
		print("Couldn't load config: %s" % error_string(err))
		show_popup($Instructions) # probably first load
	
	var argv : PackedStringArray = OS.get_cmdline_args()
	if !argv.is_empty() && argv[0].ends_with(".tmb"):
		var path = argv[0]
		var dir = argv[0].substr(0,argv[0].rfind("/"))
		if dir == path: dir = argv[0].substr(0,argv[0].rfind("\\"))
		print("%s passed in as tmb" % path)
		$LoadDialog.current_dir = dir
		_on_load_dialog_file_selected(path)
		return
	
	$LoadDialog.current_dir = cfg.get_value("Config","saved_dir") if !err else "."
	
	_on_new_chart_confirmed()


func _input(event):
	event = event as InputEventKey
	if event == null: return
	if event.pressed && event.keycode == KEY_S && Input.is_key_pressed(KEY_CTRL):
		_on_save_chart_pressed()


func _on_description_text_changed(): tmb.description = %Description.text

func _on_refresh_button_pressed(): emit_signal("chart_loaded")

func _on_help_button_pressed(): show_popup($Instructions)

func _on_ffmpeg_help_pressed(): show_popup($FFmpegInstructions)


func show_popup(window:Window):
	window.position = popup_location
	window.show()


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


func _on_new_chart_pressed(): show_popup($NewChartConfirm)
func _on_new_chart_confirmed():
	tmb = TMBInfo.new()
	%Settings.use_custom_colors = false
	%WavPlayer.stream = null
	print("new tmb")
	emit_signal("chart_loaded")


func _on_load_chart_pressed(): show_popup($LoadDialog)
func _on_load_dialog_file_selected(path:String):
	var dir = saveload.on_load_dialog_file_selected(path)
	%WavPlayer.stream = null
	emit_signal("chart_loaded")
	if settings.load_wav_on_chart_load: saveload.load_wav_or_convert_ogg(dir)
	if %BuildWaveform.button_pressed: %WavePreview.build_wave_preview()


func _on_save_chart_pressed():
	tmb.lyrics = %LyricsEditor.package_lyrics()
	if Input.is_key_pressed(KEY_SHIFT):
		_on_save_dialog_file_selected($SaveDialog.current_path)
	else: show_popup($SaveDialog)


func _on_save_dialog_file_selected(path:String):
	if OS.get_name() == "Windows": saveload.validate_win_path(path)
	
	var err = saveload.save_tmb_to_file(path,$SaveDialog.current_dir)
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
	tmb.notes.sort_custom(func(a,b): return a[TMBInfo.NOTE_BAR] < b[TMBInfo.NOTE_BAR])
	emit_signal("chart_loaded")

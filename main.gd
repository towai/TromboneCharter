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


func _on_new_chart_pressed(): show_popup($NewChartConfirm)
func _on_new_chart_confirmed():
	tmb = TMBInfo.new()
	%Settings.use_custom_colors = false
	%TrackPlayer.stream = null
	print("new tmb")
	emit_signal("chart_loaded")


func _on_load_chart_pressed(): show_popup($LoadDialog)
func _on_load_dialog_file_selected(path:String) -> void:
	var dir = saveload.on_load_dialog_file_selected(path)
	%TrackPlayer.stream = null
	emit_signal("chart_loaded")
	if settings.load_stream_upon_chart_io:
		var err = try_to_load_stream(dir)
		if err: print("No stream loaded -- %s" % error_string(err))
	if %BuildWaveform.button_pressed: %WavePreview.build_wave_preview()


func _on_save_chart_pressed():
	tmb.lyrics = %LyricsEditor.package_lyrics()
	if Input.is_key_pressed(KEY_SHIFT):
		_on_save_dialog_file_selected($SaveDialog.current_path)
	else: show_popup($SaveDialog)


func _on_save_dialog_file_selected(path:String) -> void:
	if OS.get_name() == "Windows": saveload.validate_win_path(path)
	
	var err = saveload.save_tmb_to_file(path)
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
	
	if !%Settings.load_stream_upon_chart_io: return
	else:
		err = try_to_load_stream(dir)
		if err: print("No stream loaded -- %s" % error_string(err))

#region AudioLoading
# TODO should we perhaps give the TrackPlayer a script and give it these?
func try_to_load_ogg(path:String) -> int:
	print("Try load ogg from %s" % path)
	var f = FileAccess.open(path,FileAccess.READ)
	if f == null: return FileAccess.get_open_error()
	
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null || stream.packet_sequence.packet_data.is_empty():
		print("Ogg load: stream null/no data?")
		return ERR_FILE_CANT_READ
	
	%TrackPlayer.stream = stream
	return OK

# TODO deprecate entirely in favor of Ogg runtime loading (godot/commit/e391eae)
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
	
	%TrackPlayer.stream = stream
	return OK


func try_to_load_stream(dir) -> int:
	var err : int
	if Global.version == "4.2":
		err = try_to_load_ogg(dir + "/song.ogg")
		if err:
			print("%s -- maybe there's only a .wav"
					% error_string(err))
			err = saveload.load_wav_or_convert_ogg(dir)
	else: err = saveload.load_wav_or_convert_ogg(dir)
	return err
#endregion


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


func _on_rich_text_label_meta_clicked(meta):
	var data = JSON.parse_string(meta)
	if not data:
		OS.shell_open(str(meta))
	elif data.has('note'): %Chart.jump_to_note(data['note'], true)
	# DisplayServer is a bit of a weird place to have this but it's the window management ig
	elif data.has('hash'): DisplayServer.clipboard_set(data['hash'])
	else: print("meta clicked and idk what to do, here's the data: %s" % data)

# For some reason I have to manually handle resizing the window contents to fit the window size.
func _on_diff_calc_about_to_popup():
	$DiffCalc/PanelContainer.set_size($DiffCalc.size)

func _on_diff_calc_win_size_changed():
	$DiffCalc/PanelContainer.set_size($DiffCalc.size)

func _on_diff_calc_win_close_requested():
	$DiffCalc.visible = false

func _on_diff_ok_button_pressed():
	$DiffCalc.visible = false

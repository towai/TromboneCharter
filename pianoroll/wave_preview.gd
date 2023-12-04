extends Control

#TODO: remove w_image
@onready var w_image := Image.new()
@onready var chart : Node = get_parent()
var cfg : ConfigFile:
	get: return get_tree().get_current_scene().cfg
	set(_v): assert(false)
var ffmpeg_worker : FFmpegWorker:
	get: return Global.ffmpeg_worker
	set(_v): assert(false)
var rects : Array[TextureRect] = []
var song_length : float:
	get:
		if !%TrackPlayer.stream: return 0.0
		return %TrackPlayer.stream.get_length()
var stream_length_in_beats : float:
	get: return Global.time_to_beat(song_length)
	set(_v): assert(false)
var bpm : float:
	get: return Global.working_tmb.tempo
	set(_v): assert(false)
var build_hires_wave : bool:
	get: return %HiResWave.button_pressed
	set(_v): assert(false)
var wave_is_hires := false


func calc_rects_amount() -> int:
	var divided_by = 81.92 if build_hires_wave else 163.84
	var amount = ceil(song_length / divided_by) + 1
	return amount

func clear_wave_preview():
	for i in rects.size(): rects[i].free()
	rects = []

func build_wave_preview():
	if !Global.ffmpeg_worker.ffmpeg_exists:
		print("Roses are chrominance blue\nWater is chrominance red\nYou can't make a waveform preview without ffmpeg")
		return
	
	print(song_length)
	wave_is_hires = build_hires_wave

	%BuildWaveform.disabled = true
	%HiResWave.disabled = true
	%PreviewType.disabled = true
	%PreviewGenLabel.visible = true

	var textures : Array = []

	for i in calc_rects_amount():
		var result =  await do_ffmpeg_convert(cfg.get_value("Config","saved_dir"),i,%PreviewType.selected)
		if !result:
			print("Done in %d steps" % i)
			break
		else:
			textures.append(result)
		
	if rects:
		clear_wave_preview()

	for i in textures.size():
		var rect = TextureRect.new()
		add_child(rect)
		rects.append(rect)
		rect.texture = ImageTexture.create_from_image(textures[i])
	
	%BuildWaveform.disabled = false
	%HiResWave.disabled = false
	%PreviewType.disabled = false
	%PreviewGenLabel.visible = false

	await get_tree().process_frame
	calculate_width()


func do_ffmpeg_convert(dir:String,idx:int=0,type:int=0) -> Image:
	print("building waveform...%d" % idx)
	
	var thread = Thread.new()
	var start := idx * 163.84
	var end := start + 163.84
	
	if build_hires_wave:
		start /= 2
		end /= 2
	
	if song_length < start: return null
	if song_length < end: end = song_length

	var wavechunkpath := '%s/wav%d.png' % [dir,idx]

	var callable = Callable(ffmpeg_worker, "draw_wavechunk")

	thread.start(callable.bind(start,end,dir,build_hires_wave,type,idx))
	while thread.is_alive():
		await get_tree().process_frame
	var err = thread.wait_to_finish()
	thread = null
	if err:
		print("tried to run ffmpeg, got error code %d | %s" % [err,error_string(err)])
		return null
	
#	err = w_image.load(wavechunkpath)
#	if err:
#		print(error_string(err))
#		return
	var img = Image.load_from_file(wavechunkpath)
	DirAccess.remove_absolute(wavechunkpath)
	return img


func calculate_width():
	# natural size, before scaling, aka song length in ms (*2 if hi-res wave)
	var width := get_size().x
	if width == 0: # no preview exists
		scale.x = 1.0
		return
	
	var true_width : float = (song_length * chart.bar_spacing) / (60.0 / bpm)
#	if wave_is_hires: true_width /= 2
	
	var scalefactor : float = (true_width / width)
	
	scale.x = max(scalefactor,0.001)

func _on_preview_type_item_selected(_index:int) -> void:
	if %BuildWaveform.button_pressed:
		build_wave_preview()

func _on_build_waveform_toggled(toggled_on: bool) -> void:
	if toggled_on:
		build_wave_preview()
	else:
		clear_wave_preview()

func _on_hi_res_wave_toggled(_toggled_on:bool) -> void:
	if %BuildWaveform.button_pressed:
		build_wave_preview()

func _process(_delta): pass
func _draw(): pass
func _input(_event): pass

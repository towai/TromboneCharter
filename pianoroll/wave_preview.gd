extends Control

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
		if !%WavPlayer.stream: return 0.0
		return %WavPlayer.stream.get_length()
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


func _ready():
	# max song length = 16 * 163.84s = 43m40s
	# in reality, this is for 21m50s max at high resolution (1/200s per h-pixel)
	for i in 16:
		var rect = TextureRect.new()
		add_child(rect)
		rects.append(rect)


func build_wave_preview():
	if !Global.ffmpeg_worker.ffmpeg_exists:
		print("Hey!! You can't make a waveform preview without ffmpeg!")
		return
	print(song_length)
	wave_is_hires = build_hires_wave
	
	for i in rects.size(): rects[i].texture = null
	for i in rects.size():
		var result = do_ffmpeg_convert(cfg.get_value("Config","saved_dir"),i)
		if !result:
			print("Done in %d steps" % i)
			break
	
	await(get_tree().process_frame)
	calculate_width()


func do_ffmpeg_convert(dir:String,idx:int=0) -> bool:
	print("building waveform...%d" % idx)
	
	var start := idx * 163.84
	var end := start + 163.84
	
	if build_hires_wave:
		start /= 2
		end /= 2
	
	if song_length < start: return false
	if song_length < end: end = song_length
	
	var wavechunkpath := '%s/wav%d.png' % [dir,idx]
	
	var err = ffmpeg_worker.draw_wavechunk(start,end,dir,build_hires_wave,idx)
	if err:
		print("tried to run ffmpeg, got error code %d | %s" % [err,error_string(err)])
		return false
	
#	err = w_image.load(wavechunkpath)
#	if err:
#		print(error_string(err))
#		return
	w_image = Image.load_from_file(wavechunkpath)
	rects[idx].texture = ImageTexture.create_from_image(w_image)
	DirAccess.remove_absolute(wavechunkpath)
	return true


func calculate_width():
	# natural size, before scaling, aka song length in ms (*2 if hi-res wave)
	var width := get_size().x
	if width == 0: # no preview exists
		scale.x == 1.0
		return
	
	var true_width : float = (song_length * chart.bar_spacing) / (60.0 / bpm)
#	if wave_is_hires: true_width /= 2
	
	var scalefactor : float = (true_width / width)
	
	scale.x = max(scalefactor,0.001)


func _process(_delta): pass
func _draw(): pass
func _input(_event): pass

extends Control

@onready var w_image := Image.new()
@onready var chart : Node = get_parent()
@onready var cfg : ConfigFile = get_tree().get_current_scene().cfg:
	get: return get_tree().get_current_scene().cfg
	set(value): assert(false)
var rects : Array[TextureRect] = []
var song_length : float:
	get:
		if !%WavPlayer.stream: return 0.0
		return %WavPlayer.stream.get_length()
var stream_length_in_beats : float:
	get: return Global.time_to_beat(song_length)
	set(value): assert(false)
var bpm : float:
	get: return Global.working_tmb.tempo
	set(value): assert(false)
var build_hires_wave := true
var wave_is_hires := false


func _ready():
	# max song length = 16 * 163.84s = 43m40s
	# in reality, this is for 21m50s max at high resolution (1/200s per h-pixel)
	for i in 16:
		var rect = TextureRect.new()
		add_child(rect)
		rects.append(rect)

func build_wave_preview():
	print(song_length)
	wave_is_hires = build_hires_wave
	for i in rects.size(): ffmpeg_convert(cfg.get_value("Config","saved_dir"),i)
	calculate_width()

# give this to ffmpeg worker
func ffmpeg_convert(dir:String,idx:int=0):
	print("building waveform...%d" % idx)
	rects[idx].texture = null
	
	var start := (idx * 163.84) + 0.0
	var end := (idx * 163.84) + 163.84
	if song_length < start: return
	if song_length < end:
		end = song_length
		print("end @ %.3f" % end)
		print(((end - start) * 100))
	if build_hires_wave:
		start /= 2
		end /= 2
	
	var wavechunkpath := '%s/wav%d.png' % [dir,idx]
	
	var command : PackedStringArray = [ "-ss", '%.3f' % start, "-to", '%.3f' % end,
					"-i", '%s' % (dir + '/song.wav'),
					'-lavfi',
					'showwavespic=s=%dx1024:colors=ff8000|0080ff' % ((end - start) * 100),
					wavechunkpath
				]
	print(command)
	var out : PackedStringArray = []
	
	var err = OS.execute("ffmpeg",command,out,false,true)
	if !out.is_empty():
		print("got a out put ?")
		if !out[0].is_empty(): print(out)
	if err: print(error_string(err))
	
	err = w_image.load(wavechunkpath)
	if err:
		print(error_string(err))
		return
	rects[idx].texture = ImageTexture.create_from_image(w_image)
	DirAccess.remove_absolute(wavechunkpath)


func calculate_width():
	# natural size, before scaling.
	# in effect, aggregate width of all child rects, aka song length in ms
	var width := get_size().x
	
	
	var true_width : float = (song_length * chart.bar_spacing) / (60.0 / bpm)
	if wave_is_hires: true_width /= 2
	# this extra number really shouldn't need to be here!
	var scalefactor : float = (true_width / width)
	
	scale.x = max(scalefactor,0.001)

func _process(delta): queue_redraw()
func _draw():
	draw_line(Vector2.ZERO,size,Color.BLUE)
	draw_circle(Vector2.ONE * 300,3,Color.RED)


func _input(event):
	if !(event is InputEventKey): return
	if event.pressed: match event.keycode:
#		KEY_BRACKETLEFT:  size.x += 64
#		KEY_BRACKETRIGHT: size.x -= 64
		_: pass
	

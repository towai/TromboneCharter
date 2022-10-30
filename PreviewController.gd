extends Node


var is_playing : bool = false
var song_position : float = -1.0
@onready var chart : Control = %Chart
@onready var settings : Settings = %Settings
@onready var player : AudioStreamPlayer = %TrombPlayer
@onready var metronome : AudioStreamPlayer = %MetronomePlayer
@onready var wavplayer : AudioStreamPlayer = %WavPlayer


func _ready(): pass


func _do_preview():
	if chart.tmb == null:
		print("null tmb")
		return
	is_playing = true
	# actually an int but i don't want weird shit happening when i try to do math on it
	var bpm : float = chart.tmb.tempo
	var time : float
	@warning_ignore(unused_variable)
	var previous_time : float
	var last_position : float
	var initial_time : float = Time.get_ticks_msec() / 1000.0
	var startpoint_in_stream : float = settings.section_start / (bpm / 60.0)
	wavplayer.play(startpoint_in_stream)
	while is_playing:
		time = Time.get_ticks_msec() / 1000.0
		var elapsed_time = time - initial_time
		
		song_position = elapsed_time * (bpm / 60.0) + settings.section_start
		if song_position > settings.section_start + settings.section_length \
				|| Input.is_key_pressed(KEY_ESCAPE): break
		
		if int(last_position) != int(song_position) && %MetroChk.button_pressed:
			metronome.play()
		last_position = song_position
		
		var note : Array = _find_note_overlapping_bar(song_position)
		if note.is_empty():
			player.stop()
			await(get_tree().process_frame)
			continue
		
		var pitch = Global.pitch_to_scale(note[TMBInfo.NOTE_PITCH_START] / Global.SEMITONE)
		var end_pitch = note[TMBInfo.NOTE_PITCH_START] + note[TMBInfo.NOTE_PITCH_DELTA]
		end_pitch = Global.pitch_to_scale(end_pitch / Global.SEMITONE)
		
		var pos_in_note = (song_position - note[TMBInfo.NOTE_BAR]) / note[TMBInfo.NOTE_LENGTH]
		# i don't know why, but using smoothstep in setting pitch_scale doesn't work
		# so we do it out here
		pos_in_note = smoothstep(0, 1, pos_in_note)
		
		player.pitch_scale = lerp(pitch,end_pitch,pos_in_note)
		if !player.playing: player.play()
		previous_time = time
		await(get_tree().process_frame)
	is_playing = false
	wavplayer.stop()
	player.stop()
	song_position = -1.0
	chart.queue_redraw()


func _find_note_overlapping_bar(time:float):
	# TODO  ( optimization )
	#	If we ensure that notes are always in the array in chronological order,
	#	we can break early the first time we encounter a note that starts after `time`
	for note in chart.tmb.notes:
		var end_bar = note[TMBInfo.NOTE_BAR] + note[TMBInfo.NOTE_LENGTH]
		if time >= note[TMBInfo.NOTE_BAR] && time <= end_bar:
			return note
	return []

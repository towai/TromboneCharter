extends Node


const TAP_NOTE_TIME := 0.1
@onready var chart : Control = %Chart
@onready var settings : Settings = %Settings
@onready var player : AudioStreamPlayer = %TrombPlayer
@onready var metronome : AudioStreamPlayer = %MetronomePlayer
@onready var StreamPlayer : AudioStreamPlayer = %TrackPlayer
var is_playing : bool = false
var song_position : float = -1.0
var saved_song_position : float = -1.0
var tmb : TMBInfo

var force_note := false
var forced_note : float = 0.0



func _ready() -> void: pass


func _do_preview() -> void:
	if chart.tmb == null: assert(false,"null tmb") # this should never happen
	else: tmb = chart.tmb
	if is_playing: # toggle_playback was pressed to stop playback
		is_playing = false
		%PreviewButton.text = "Preview"
		
		await get_tree().process_frame
		if %PlaybackEndBehavior.button_pressed:
			settings.playhead_pos = saved_song_position
			%PlayheadHandle.update_pos(saved_song_position)
		
		return
	is_playing = true
	
	var bpm : float = tmb.tempo
	var time : float
	var _previous_time : float
	var last_position : float
	var initial_time : float = Time.get_ticks_msec() / 1000.0
	var startpoint_in_stream : float = Global.beat_to_time(settings.playhead_pos)
	var start_beat : float = settings.playhead_pos
	saved_song_position = start_beat
	if settings.section_length:
		startpoint_in_stream = Global.beat_to_time(settings.section_start)
		start_beat = settings.section_start
	var slide_start : float
	var _note_ons : Array[float] = []
	for note in tmb.notes: _note_ons.append(note[TMBInfo.NOTE_BAR])
	
	StreamPlayer.play(startpoint_in_stream)
	%PreviewButton.text = "Stop"
	while is_playing:
		time = Time.get_ticks_msec() / 1000.0
		var elapsed_time = time - initial_time
		
		song_position = elapsed_time * (bpm / 60.0) + start_beat
		if (settings.section_length && song_position > settings.section_start + settings.section_length):
			break
		if song_position >= settings.length.value:
			break
		
		if int(last_position) != int(song_position) && %MetroChk.button_pressed:
			metronome.play()
		last_position = song_position
		
		var note : Array = _find_note_overlapping_bar(song_position)
		if note.is_empty() && !force_note:
			player.stop()
			await(get_tree().process_frame)
			continue
		elif !note.is_empty() && force_note && (note[TMBInfo.NOTE_PITCH_START] != forced_note):
			force_note = false
			player.stop()
		elif !force_note && Note.array_is_tap(note):
			forced_note = note[TMBInfo.NOTE_PITCH_START]
			force_note = true
			get_tree().create_timer(TAP_NOTE_TIME).timeout.connect(_end_force_note)
		
		var pitch : float = Global.pitch_to_scale(forced_note / Global.SEMITONE) if force_note \
				else Global.pitch_to_scale(note[TMBInfo.NOTE_PITCH_START] / Global.SEMITONE)
		var end_pitch : float = -1 if force_note \
				else note[TMBInfo.NOTE_PITCH_START] + note[TMBInfo.NOTE_PITCH_DELTA]
		end_pitch = Global.pitch_to_scale(end_pitch / Global.SEMITONE)
		
		var pos_in_note = 0 if force_note \
				else (song_position - note[TMBInfo.NOTE_BAR]) / note[TMBInfo.NOTE_LENGTH]
		# i don't know why, but using smoothstep in setting pitch_scale doesn't work
		# so we do it out here
		pos_in_note = Global.smootherstep(0, 1, pos_in_note)
		
		# sort of kind of emulate the audible slide limit in the actual game
		player.pitch_scale = clamp(lerp(pitch,end_pitch,pos_in_note),
				Global.pitch_to_scale(slide_start - 12.0),
				Global.pitch_to_scale(slide_start + 12.0)
				)
		if !player.playing:
			player.play()
			slide_start = note[TMBInfo.NOTE_PITCH_START] / Global.SEMITONE
		
		_previous_time = time
		await(get_tree().process_frame)
	
	is_playing = false
	%PreviewButton.text = "Preview"
	
	StreamPlayer.stop()
	player.stop()

	if !settings.section_length: settings.playhead_pos = song_position
	
	song_position = -1.0
	chart.queue_redraw()

# TODO smarter handling of this: get a reference so we can extend taps more properly
# Current handling means that quick taps on the same note sound like one unbroken note
func _find_note_overlapping_bar(time:float) -> Array:
	for note in tmb.notes:
		# we sort the array by note-on every time we make an edit, so we can break early
		if time < note[TMBInfo.NOTE_BAR]: break
		var end_bar = note[TMBInfo.NOTE_BAR] + note[TMBInfo.NOTE_LENGTH]
		if time >= note[TMBInfo.NOTE_BAR] && time <= end_bar: return note
	return []


func _find_matching_by_note_on(note_ons:Array[float],time:float) -> Array:
	for i in note_ons.size():
		var on = note_ons[i]
		if time < on: break
		var end_bar = on + tmb.notes[i][TMBInfo.NOTE_LENGTH]
		if time >= on && time <= end_bar: return tmb.notes[i]
	return []


func _end_force_note() -> void: force_note = false

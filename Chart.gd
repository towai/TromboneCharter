extends Control

const scrollbar_height : float = 8
var bar_spacing : int:
	get: return tmb.savednotespacing * %ZoomLevel.value
var tmb : TMBInfo
var middle_c_y : float:
	get: return (key_height * 13.0) + (key_height / 2.0)
var key_height : float:
	get: return (size.y + scrollbar_height) / Global.NUM_KEYS
var current_subdiv : float:
	get: return 1.0 / %TimingSnap.value
func height_to_pitch(height:float):
	return ((height - middle_c_y) / key_height) * Global.SEMITONE
func pitch_to_height(pitch:float):
	return middle_c_y - ((pitch / Global.SEMITONE) * key_height)
func x_to_bar(x:float): return x / bar_spacing
func bar_to_x(bar:float): return bar * bar_spacing
var note_scn = preload("res://note.tscn")
# IDK why i gave this and Global both a ref but now i gotta live with it
var settings : Settings:
	get: return Global.settings
@onready var main = get_tree().get_current_scene()
@onready var player : AudioStreamPlayer = main.find_child("AudioStreamPlayer")
@onready var measure_font : Font = ThemeDB.get_fallback_font()
var bar_font : Font
var draw_targets : bool:
	get: return %ShowMouseTargets.button_pressed
var doot_enabled : bool = true


func doot(pitch:float):
	if !doot_enabled || %PreviewController.is_playing: return
	player.pitch_scale = Global.pitch_to_scale(pitch / Global.SEMITONE)
	player.play()
	await(get_tree().create_timer(0.1).timeout)
	player.stop()


func _ready():
	bar_font = measure_font.duplicate()
	
	tmb = Global.working_tmb
	main.chart_loaded.connect(_on_tmb_loaded)
	Global.tmb_updated.connect(_on_tmb_updated)
	%TimingSnap.value_changed.connect(timing_snap_changed)


func _process(_delta): if %PreviewController.is_playing: queue_redraw()


func to_snapped(pos:Vector2):
	var new_bar = x_to_bar( pos.x )
	var timing_snap = 1.0 / settings.timing_snap
	var pitch = -height_to_pitch( pos.y )
	var pitch_snap = Global.SEMITONE / settings.pitch_snap
	return Vector2(
		clamp(
			snapped( new_bar, timing_snap ),
			0, tmb.endpoint
			),
		clamp(
			snapped( pitch, pitch_snap, ),
			Global.SEMITONE * -13, Global.SEMITONE * 13
			)
		)
func to_unsnapped(pos:Vector2):
	return Vector2(
		x_to_bar(pos.x),
		-height_to_pitch(pos.y)
	)


func timing_snap_changed(_value:float): queue_redraw()


func _on_tmb_loaded():
	# this reference should theoretically never change but let's anyway
	tmb = Global.working_tmb
	for child in get_children():
		if !(child is Note): continue
		child.touching_notes.clear()
		child.queue_free()
	doot_enabled = false
	for note in tmb.notes:
		add_note(false,
				note[TMBInfo.NOTE_BAR],
				note[TMBInfo.NOTE_LENGTH],
				note[TMBInfo.NOTE_PITCH_START],
				note[TMBInfo.NOTE_PITCH_DELTA]
		)
	doot_enabled = %DootToggle.button_pressed
	print("ASDF")
	_on_tmb_updated()
	print("HJKL")


func add_note(start_drag:bool, bar:float, length:float, pitch:float, pitch_delta:float = 0.0):
		var new_note = note_scn.instantiate()
		new_note.bar = bar
		new_note.length = length
		new_note.pitch_start = pitch
		new_note.pitch_delta = pitch_delta
		new_note.position.x = bar_to_x(bar)
		new_note.position.y = pitch_to_height(pitch)
		new_note.dragging = Note.DRAG_INITIAL if start_drag else Note.DRAG_NONE
		if doot_enabled: doot(pitch)
		add_child(new_note)


func stepped_note_overlaps(time:float, length:float, exclude : Array = []) -> bool:
	var steps : int = ceil(length) * 8
	var step_length : float = length / steps
	for step in steps + 1:
		var step_time = step_length * step
		if Global.overlaps_any_note(time + step_time, exclude): return true
	return false


func _on_tmb_updated():
	custom_minimum_size.x = (tmb.endpoint + 1) * bar_spacing
	%SectionStart.max_value = tmb.endpoint - 1
	%SectionLength.max_value = max(1, tmb.endpoint - %SectionStart.value)
	%LyricBar.max_value = tmb.endpoint - 1
	%LyricsEditor._update_lyrics()
	for note in get_children():
		if !(note is Note): continue
		note.position.x = note.bar * bar_spacing
	queue_redraw()


func find_touching_notes(the_note:Note) -> Dictionary:
	var result := {}
	for note in get_children():
		if !(note is Note): continue
		if note == the_note: continue
		if the_note.bar == note.bar + note.length:
			result[Global.START_IS_TOUCHING] = note
		if the_note.bar + the_note.length == note.bar:
			result[Global.END_IS_TOUCHING] = note
	return result


func update_note_array():
	var new_array := []
	for note in get_children():
		if !(note is Note):
			continue
		if note.is_queued_for_deletion():
			continue
		var note_array := [
			note.bar, note.length, note.pitch_start, note.pitch_delta,
			note.pitch_start + note.pitch_delta
		]
		new_array.append(note_array)
	new_array.sort_custom(func(a,b): return a[0] < b[0])
	tmb.notes = new_array


func _draw():
	if tmb == null: return
	var section_rect = Rect2(bar_to_x(settings.section_start), 1,
			bar_to_x(settings.section_length), size.y)
	draw_rect(section_rect, Color(0.3, 0.9, 1.0, 0.1))
	draw_rect(section_rect, Color.CORNFLOWER_BLUE, false, 3.0)
	if %PreviewController.is_playing:
		draw_line(Vector2(bar_to_x(%PreviewController.song_position),0),
				Vector2(bar_to_x(%PreviewController.song_position),size.y),
				Color.CORNFLOWER_BLUE, 2)
	for i in tmb.endpoint + 1:
		draw_line(Vector2(i * bar_spacing, 0), Vector2(i * bar_spacing, size.y),
				Color(1,1,1,0.4) if i % tmb.timesig else Color.WHITE,
				1 if i % tmb.timesig else 2
		)
		var subdiv = %TimingSnap.value
		for j in subdiv:
			var k = 1.0 / subdiv
			var line = i + (k * j)
			draw_line(Vector2(line * bar_spacing, 0), Vector2(line * bar_spacing, size.y),
					Color(0.7,1,1,0.2)
			)
		if !(i % tmb.timesig):
			draw_string(ThemeDB.get_fallback_font(), Vector2(i * bar_spacing, 0) + Vector2(8, 16),
					str(i / tmb.timesig), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string(ThemeDB.get_fallback_font(), Vector2(i * bar_spacing, 0) + Vector2(8, 32),
					str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_line(Vector2(bar_to_x(%CopyTarget.value), 0),
				Vector2(bar_to_x(%CopyTarget.value), size.y),
				Color.ORANGE_RED, 2.0)


func _gui_input(event):
	event = event as InputEventMouseButton
	if event == null || %PreviewController.is_playing: return
	if event.pressed && event.button_index == MOUSE_BUTTON_LEFT:
		var new_note_pos : Vector2
		
		if settings.snap_time: new_note_pos.x = to_snapped(event.position).x
		else: new_note_pos.x = to_unsnapped(event.position).x
		if stepped_note_overlaps(new_note_pos.x, current_subdiv): return
		
		
		if settings.snap_pitch: new_note_pos.y = to_snapped(event.position).y
		else: new_note_pos.y = clamp(to_unsnapped(event.position).y,
				Global.SEMITONE * -13, Global.SEMITONE * 13)
		
		add_note(true, new_note_pos.x, current_subdiv, new_note_pos.y)


func _notification(what):
	match what:
		NOTIFICATION_RESIZED:
			for note in get_children(): if note is Note: note._update()


func _on_doot_toggle_toggled(toggle): doot_enabled = toggle


func _on_show_targets_toggled(toggle):
	draw_targets = toggle
	for note in get_children(): note.queue_redraw()
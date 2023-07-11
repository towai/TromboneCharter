extends Control

const scrollbar_height : float = 8
var scroll_position : float:
	get: return %ChartView.scroll_horizontal
var scroll_end : float:
	get: return scroll_position + %ChartView.size.x
var bar_spacing : int:
	get: return tmb.savednotespacing * %ZoomLevel.value
@onready var tmb : TMBInfo:
	get: return Global.working_tmb
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
@onready var player : AudioStreamPlayer = %TrombPlayer
@onready var measure_font : Font = ThemeDB.get_fallback_font()
var bar_font : Font
var draw_targets : bool:
	get: return %ShowMouseTargets.button_pressed
var doot_enabled : bool = true
var _update_queued := false
var clearing_notes := false
var counter = 0
var new_note : Note
var new_array := []
var main_stack := []
var drag_available := false

func doot(pitch:float):
	if !doot_enabled || %PreviewController.is_playing: return
	@warning_ignore("static_called_on_instance")
	player.pitch_scale = Global.pitch_to_scale(pitch / Global.SEMITONE)
	player.play()
	await(get_tree().create_timer(0.1).timeout)
	player.stop()


func _ready():
	bar_font = measure_font.duplicate()
	main.chart_loaded.connect(_on_tmb_loaded)
	Global.tmb_updated.connect(_on_tmb_updated)
	%TimingSnap.value_changed.connect(timing_snap_changed)


func _on_scroll_change():
	await(get_tree().process_frame)
	redraw_notes()

func _unhandled_key_input(event):
	var shift = event as InputEventWithModifiers
	if !shift.shift_pressed && Input.is_action_just_pressed("ui_undo") && Global.revision > -1:
		Global.UR[0] = 1
		print("undo!")
		update_note_array()
	if Input.is_action_just_pressed("ui_redo"):
		print("redo!")
		Global.UR[0] = 2
		Global.UR[1] = 0
		if Global.revision + 3 <= Global.a_array.size() :
			Global.UR[1] = 2
		elif Global.revision + 2 <= Global.a_array.size() :
			Global.UR[1] = 1
		else :
			Global.UR[0] = 0
			print("wait, don't redo.")
		update_note_array()

func redraw_notes():
	for child in get_children():
		if child is Note:
			if child.is_in_view:
				child.show()
				child.queue_redraw()
			else: child.hide()


func _process(_delta):
	if _update_queued: _do_tmb_update()
	if %PreviewController.is_playing: queue_redraw()

func _on_tmb_updated(): _update_queued = true

func _do_tmb_update():
	custom_minimum_size.x = (tmb.endpoint + 1) * bar_spacing
	%SectionStart.max_value = tmb.endpoint - 1
	%SectionLength.max_value = max(1, tmb.endpoint - %SectionStart.value)
	%CopyTarget.max_value = tmb.endpoint - 1
	%LyricBar.max_value = tmb.endpoint - 1
	%LyricsEditor._update_lyrics()
	%Settings._update_handles()
	for note in get_children():
		if !(note is Note) || note.is_queued_for_deletion():
			continue
		note.position.x = note.bar * bar_spacing
	queue_redraw()
	_update_queued = false


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
	var children := get_children()
	clearing_notes = true
	for i in children.size():
		var child = children[-(i + 1)]
		if child is Note: child.queue_free()
	await(get_tree().process_frame)
	clearing_notes = false
	
	doot_enabled = false
	for note in tmb.notes:
		add_note(false,
			note[TMBInfo.NOTE_BAR],
			note[TMBInfo.NOTE_LENGTH],
			note[TMBInfo.NOTE_PITCH_START],
			note[TMBInfo.NOTE_PITCH_DELTA]
		)
	doot_enabled = %DootToggle.button_pressed
	_on_tmb_updated()


func add_note(start_drag:bool, bar:float, length:float, pitch:float, pitch_delta:float = 0.0):
	new_note = note_scn.instantiate()
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


func find_touching_notes(the_note:Note) -> Dictionary:
	var result := {}
	
	var prev_note = get_matching_note_off(the_note.bar,[the_note])
	if prev_note: result[Global.START_IS_TOUCHING] = prev_note
	
	var next_note = get_matching_note_on(the_note.end,[the_note])
	if next_note: result[Global.END_IS_TOUCHING] = next_note
	
	return result


func get_matching_note_on(time:float, exclude:Array = []): # -> Note or null
	for note in get_children():
		if !(note is Note) || (note in exclude): continue
		if abs(note.bar - time) < 0.01: return note
	return null


func get_matching_note_off(time:float, exclude:Array = []): # -> Note or null
	for note in get_children():
		if !(note is Note) || (note in exclude): continue
		if abs(note.end - time) < 0.01: return note
	return null
	

func update_note_array():
	new_array = []
	print("Hi, I'm Tom Scott, and today I'm here in func update_note_array()")
	#print(get_children())
	for note in get_children():
		if !(note is Note) || note.is_queued_for_deletion() || (Global.UR[0] > 0):
			continue
		var note_array := [
			note.bar, note.length, note.pitch_start, note.pitch_delta,
			note.pitch_start + note.pitch_delta
		]
		print(note_array)
		new_array.append(note_array)
		main_stack.append(note_array)
	print("added notes: ",Global.a_array)
	print("deleted notes: ",Global.d_array)
	print("new_array: ",new_array)
	new_array.sort_custom(func(a,b): return a[TMBInfo.NOTE_BAR] < b[TMBInfo.NOTE_BAR])
	tmb.notes = new_array
	print("tmb.notes: ",tmb.notes)
	
	if Global.UR[0] > 0 :
		UR_handler()

func UR_handler():
	print("UR!!! ",Global.UR[0])
	var passed_note = []
	
	
	
	if Global.UR[0] == 1 :
		print("UR Undo! ",Global.UR[0])
		
		if Global.a_array[Global.revision] == Global.respects :
			print("undo dragged")
			passed_note = Global.d_array[Global.revision]
			main_stack.remove_at(main_stack.find(Global.a_array[Global.revision-1]))
			Global.revision -= 2
			Global.UR[0] = 0
		
		elif Global.d_array[Global.revision] == Global.ratio :
			print("undo added")
			main_stack.remove_at(main_stack.find(Global.a_array[Global.revision]))
			Global.revision -= 1
			Global.UR[0] = 0
		
		elif Global.a_array[Global.revision] == Global.ratio :
			print("undo deleted")
			passed_note = Global.d_array[Global.revision]
			Global.revision -= 1
			Global.UR[0] = 0
		
		
		
	if Global.UR[0] == 2 :
		print("UR Redo! ",Global.UR[0])
		if Global.UR[1] == 2 :
			if Global.a_array[Global.revision+2] == Global.respects :
				print("redo dragged")
				passed_note = Global.a_array[Global.revision+1]
				main_stack.remove_at(main_stack.bsearch(Global.d_array[Global.revision+2]))
				Global.revision += 2
		
		if Global.UR[1] == 1:
			if Global.d_array[Global.revision+1] == Global.ratio :
				print("redo added")
				passed_note = Global.a_array[Global.revision+1]
				Global.revision += 1
		
			elif Global.a_array[Global.revision+1] == Global.ratio :
				print("redo deleted")
				main_stack.remove_at(main_stack.bsearch(Global.d_array[Global.revision+1]))
				Global.revision += 1
		Global.UR[0] = 0
		Global.UR[1] = 0
		update_note_array()
	print("main_stack: ",main_stack)
	Global.UR[0] = 0
	_on_tmb_updated()

func _draw():
	var font : Font = ThemeDB.get_fallback_font()
	if tmb == null: return
	var section_rect = Rect2(bar_to_x(settings.section_start), 1,
		bar_to_x(settings.section_length), size.y)
	draw_rect(section_rect, Color(0.3, 0.9, 1.0, 0.1))
	draw_rect(section_rect, Color.CORNFLOWER_BLUE, false, 3.0)
	if %PreviewController.is_playing:
		draw_line(Vector2(bar_to_x(%PreviewController.song_position),0),
			Vector2(bar_to_x(%PreviewController.song_position),size.y),
			Color.CORNFLOWER_BLUE, 2 )
	for i in tmb.endpoint + 1:
		draw_line(Vector2(i * bar_spacing, 0), Vector2(i * bar_spacing, size.y),
			Color(1,1,1,0.33) if i % tmb.timesig else Color.WHITE, 2
			)
		var subdiv = %TimingSnap.value
		for j in subdiv:
			if i == tmb.endpoint: break
			var k = 1.0 / subdiv
			var line = i + (k * j)
			draw_line(Vector2(line * bar_spacing, 0), Vector2(line * bar_spacing, size.y),
				Color(0.7,1,1,0.2), 1 )
		if !(i % tmb.timesig):
			@warning_ignore("integer_division")
			draw_string(font, Vector2(i * bar_spacing, 0) + Vector2(8, 16),
				str(i / tmb.timesig), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string(font, Vector2(i * bar_spacing, 0) + Vector2(8, 32),
				str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_line(Vector2(bar_to_x(%CopyTarget.value), 0),
			Vector2(bar_to_x(%CopyTarget.value), size.y),
			Color.ORANGE_RED, 2.0)
	redraw_notes()


func _gui_input(event):
	event = event as InputEventMouseButton
	if event == null || !event.pressed: return
	if event.button_index == MOUSE_BUTTON_LEFT && !%PreviewController.is_playing:
		@warning_ignore("unassigned_variable")
		var new_note_pos : Vector2
		
		if settings.snap_time: new_note_pos.x = to_snapped(event.position).x
		else: new_note_pos.x = to_unsnapped(event.position).x
		if stepped_note_overlaps(new_note_pos.x, current_subdiv): return
		
		
		if settings.snap_pitch: new_note_pos.y = to_snapped(event.position).y
		else: new_note_pos.y = clamp(to_unsnapped(event.position).y,
			Global.SEMITONE * -13, Global.SEMITONE * 13)
		
		add_note(true, new_note_pos.x, current_subdiv, new_note_pos.y)
	elif (event.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
		|| event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_on_scroll_change()


func _notification(what):
	match what:
		NOTIFICATION_RESIZED:
			for note in get_children():
				if note is Note && !note.is_queued_for_deletion():
					note._update()


func _on_doot_toggle_toggled(toggle): doot_enabled = toggle


func _on_show_targets_toggled(toggle):
	draw_targets = toggle
	for note in get_children(): note.queue_redraw()

class_name Note
extends Control

const BARHANDLE_SIZE := Vector2.ONE * 32
const ENDHANDLE_SIZE := Vector2.ONE * 24
const TAIL_HEIGHT := 16.0
var bar : float:
	set(value):
		bar = value
		_update()
var length : float:
	set(value):
		length = value
		_update()
var end: float:
	get: return bar + length
	set(value): length = value - bar
var pitch_start : float:
	set(value):
		if value != pitch_start && doot_enabled:
			chart.doot(value)
		pitch_start = value
		_update()
var pitch_delta : float:
	set(value):
		if value != pitch_delta && doot_enabled:
			chart.doot(pitch_start + value)
		pitch_delta = value
		_update()
var end_pitch : float:
	get: return pitch_start + pitch_delta
var higher_pitch : float:
	get: return min(end_height,0)
var scaled_length : float:
	get: return length * chart.bar_spacing
var end_height : float:
	get: return -((pitch_delta / Global.SEMITONE) * chart.key_height)
var visual_height : float:
	get: return abs(end_height)
var is_slide: bool:
	get: return pitch_delta != 0
var is_in_view : bool:
	get: return position.x + size.x >= chart.scroll_position \
			&& position.x <= chart.scroll_end
var dragging := 0
enum {
	DRAG_NONE,
	DRAG_BAR,
	DRAG_PITCH,
	DRAG_END,
	DRAG_INITIAL,
}
var drag_start := Vector2.ZERO
var old_bar : float
var old_pitch : float
var old_end_pitch : float

var doot_enabled : bool = false

@onready var chart = get_parent()

@onready var bar_handle = $BarHandle
@onready var pitch_handle = $PitchHandle
@onready var end_handle = $EndHandle

var touching_notes : Dictionary
var show_bar_handle : bool:
	get: return (touching_notes.get(Global.START_IS_TOUCHING) == null)
var show_end_handle : bool:
	get: return (touching_notes.get(Global.END_IS_TOUCHING) == null)
### Dew's variables ###
var starting_note : Array
var added : bool
var deleted : bool
var dragged : bool
var click := false


@onready var player : AudioStreamPlayer = get_tree().current_scene.find_child("AudioStreamPlayer")

# Called when the node enters the scene tree for the first time.
func _ready():
	for handle in [bar_handle, pitch_handle, end_handle]:
		handle.focus_entered.connect(grab_focus)
	
	bar_handle.size = BARHANDLE_SIZE
	bar_handle.position = -BARHANDLE_SIZE / 2
	
	pitch_handle.size = Vector2.DOWN * TAIL_HEIGHT
	
	end_handle.size = ENDHANDLE_SIZE
	
	update_touching_notes()
	_update()
	doot_enabled = true


func _process(_delta):
	if dragging: _process_drag()

func _gui_input(event):
	var key = event as InputEventKey
	
	if key != null && key.pressed:
		match key.keycode:
			KEY_DELETE:
				Global.revision += 1
				print("revision: ",Global.revision)
				Global.a_array.append(Global.ratio)
				Global.d_array.append([bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta])
				queue_free()
		return
	
	_on_handle_input(event,pitch_handle)


func _on_handle_input(event, which):
	var pitch_handle_position = -1 if Input.is_key_pressed(KEY_SHIFT) else 0
	move_child(pitch_handle, pitch_handle_position)
	event = event as InputEventMouseButton
	if event == null: return
	#print(starting_note)
	if event.pressed: match event.button_index:
		MOUSE_BUTTON_LEFT:
			if !click :
				starting_note = [bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]
				click = true
			old_bar = bar
			old_pitch = pitch_start
			old_end_pitch = end_pitch
			dragging = which
			drag_start = get_local_mouse_position()
			chart.doot(pitch_start if which != DRAG_END else end_pitch)
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
			starting_note = [bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]
			deleted = true
			print("that's deleting")
			Global.revision += 1
			#print("revision: ",Global.revision)
			Global.a_array.append(Global.ratio)
			Global.d_array.append(starting_note.duplicate())
			queue_free()


func _process_drag():
	if !(Input.get_mouse_button_mask() & MOUSE_BUTTON_LEFT):
		_end_drag()
		return
		
	match dragging:
		DRAG_BAR:
			dragged = true
			print("that bar's dragging")
			var new_time : float
			if Global.settings.snap_time:
				new_time = chart.to_snapped(chart.get_local_mouse_position()).x
			else: new_time = chart.to_unsnapped(chart.get_local_mouse_position()).x
			if new_time + length >= chart.tmb.endpoint:
				new_time = chart.tmb.endpoint - length
			
			var exclude = [old_bar]
			if !Input.is_key_pressed(KEY_ALT):
				if has_slide_neighbor(Global.END_IS_TOUCHING, end_pitch):
					exclude.append(touching_notes[Global.END_IS_TOUCHING].bar)
				
				if has_slide_neighbor(Global.START_IS_TOUCHING, pitch_start):
					exclude.append(touching_notes[Global.START_IS_TOUCHING].bar)
			
			if chart.stepped_note_overlaps(new_time,length,exclude):
				return
			
			bar = new_time
			_update()
			
		DRAG_PITCH:
			dragged = true
			print("that pitch's dragging")
			var new_pitch : float
			if Global.settings.snap_pitch:
				new_pitch = chart.to_snapped(
						chart.get_local_mouse_position() - Vector2(0, drag_start.y)
						).y
			else: new_pitch = chart.to_unsnapped(
						chart.get_local_mouse_position() - Vector2(0, drag_start.y)
						).y
			pitch_start = new_pitch
			
			doot_enabled = false
			if end_pitch > 13 * Global.SEMITONE:
				pitch_delta = (13 * Global.SEMITONE) - pitch_start
			if end_pitch < -13 * Global.SEMITONE:
				pitch_delta = -(13 * Global.SEMITONE) - pitch_start
			doot_enabled = true
			
		DRAG_END:
			dragged = true
			print("that end's dragging")
			var new_end : Vector2 = chart.to_unsnapped(chart.get_local_mouse_position()) \
							- Vector2(bar, pitch_start)
			
			new_end.x = min(chart.tmb.endpoint,
					new_end.x if !Global.settings.snap_time \
					else snapped(new_end.x, 1.0 / Global.settings.timing_snap)
					)
			
			var exclude = [old_bar]
			if has_slide_neighbor(Global.END_IS_TOUCHING, old_end_pitch) \
					&& !Input.is_key_pressed(KEY_ALT):
				exclude.append(touching_notes[Global.END_IS_TOUCHING].bar)
			
			if chart.stepped_note_overlaps(bar, new_end.x, exclude) \
					|| new_end.x <= 0 \
					|| new_end.x + bar > chart.tmb.endpoint:
				return
			
			new_end.y = new_end.y if !Global.settings.snap_pitch \
					else snapped(new_end.y, Global.SEMITONE / Global.settings.pitch_snap)
			new_end.y = clamp(new_end.y, (-13 * Global.SEMITONE) - pitch_start,
					(13 * Global.SEMITONE) - pitch_start)
			
			
			length = new_end.x
			pitch_delta = new_end.y
		DRAG_INITIAL:
			@warning_ignore("unassigned_variable")
			var new_pos : Vector2
			added = true
			print("that's a new note")
			if Global.settings.snap_time: new_pos.x = chart.to_snapped(chart.get_local_mouse_position()).x
			else: new_pos.x = chart.to_unsnapped(chart.get_local_mouse_position()).x
			
			if Global.settings.snap_pitch: new_pos.y = chart.to_snapped(chart.get_local_mouse_position()).y
			else: new_pos.y = chart.to_unsnapped(chart.get_local_mouse_position()).y
			new_pos.y = clamp(new_pos.y, (-13 * Global.SEMITONE), (13 * Global.SEMITONE))
			
			pitch_start = new_pos.y
			
			if chart.stepped_note_overlaps(new_pos.x,length,[old_bar]): return
			bar = new_pos.x
			
		DRAG_NONE: print("Not actually dragging? How tf was this reached")
		_: print("Drag == %d You fucked up somewhere!!" % dragging)


func _end_drag(): #this may be where we create our undo stack
	dragging = DRAG_NONE
	click = false
	#print("prior revision: ",Global.revision)
	var proper_note : Array = [bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]
	#print(starting_note)
	#print(proper_note)
	if starting_note != proper_note :
		if added || dragged :
			Global.revision += 1
			Global.a_array.append(proper_note)
			Global.d_array.append(Global.ratio)
			if dragged:
				Global.revision += 1
				Global.a_array.append(Global.respects)
				Global.d_array.append(starting_note.duplicate())
	print("current revision: ",Global.revision)
	
	_snap_near_pitches()
	if !Input.is_key_pressed(KEY_ALT):
		if has_slide_neighbor(Global.START_IS_TOUCHING, old_pitch):
			touching_notes[Global.START_IS_TOUCHING].receive_slide_propagation(Global.END_IS_TOUCHING)
		
		if has_slide_neighbor(Global.END_IS_TOUCHING, old_end_pitch):
			touching_notes[Global.END_IS_TOUCHING].receive_slide_propagation(Global.START_IS_TOUCHING)
	
	update_touching_notes()
	
	chart.update_note_array()


func _snap_near_pitches():
	var near_pitch_threshold = Global.SEMITONE / 12
	if touching_notes.has(Global.START_IS_TOUCHING):
		var neighbor : Note = touching_notes[Global.START_IS_TOUCHING]
		if abs(pitch_start - neighbor.end_pitch) <= near_pitch_threshold:
			pitch_start = neighbor.end_pitch
	if touching_notes.has(Global.END_IS_TOUCHING):
		var neighbor : Note = touching_notes[Global.END_IS_TOUCHING]
		if abs(end_pitch - neighbor.pitch_start) <= near_pitch_threshold:
			pitch_delta = neighbor.pitch_start - pitch_start


func has_slide_neighbor(direction:int,pitch:float):
	match direction:
		Global.START_IS_TOUCHING:
			return touching_notes.has(direction) && touching_notes[direction].end_pitch == pitch
		Global.END_IS_TOUCHING:
			return touching_notes.has(direction) && touching_notes[direction].pitch_start == pitch
	


func update_touching_notes():
	var old_prev_note = touching_notes.get(Global.START_IS_TOUCHING)
	var old_next_note = touching_notes.get(Global.END_IS_TOUCHING)
	touching_notes = chart.find_touching_notes(self)
	
	var prev_note = touching_notes.get(Global.START_IS_TOUCHING)
	match prev_note:
		null: if old_prev_note != null: old_prev_note.update_touching_notes()
		_:
			prev_note.touching_notes[Global.END_IS_TOUCHING] = self if bar >= 0 else null
			prev_note.end = bar
			prev_note.update_handle_visibility()
	
	var next_note = touching_notes.get(Global.END_IS_TOUCHING)
	match next_note:
		null: if old_next_note != null: old_next_note.update_touching_notes()
		_: 
			next_note.touching_notes[Global.START_IS_TOUCHING] = self if bar >= 0 else null
			next_note.bar = end
			next_note.update_handle_visibility()
	
	update_handle_visibility()


func receive_slide_propagation(from:int):
	doot_enabled = false
	match from:
		Global.START_IS_TOUCHING:
			var neighbor = touching_notes[from]
			var length_change = bar - neighbor.end
			var pitch_change = pitch_start - neighbor.end_pitch
			bar -= length_change
			length += length_change
			pitch_start -= pitch_change
			pitch_delta += pitch_change
		Global.END_IS_TOUCHING: 
			var neighbor = touching_notes[from]
			var length_change = end - neighbor.bar
			var pitch_change = end_pitch - neighbor.pitch_start
			length -= length_change
			pitch_delta -= pitch_change
		_: print("?????")
	if length <= 0: queue_free()
	doot_enabled = true



func update_handle_visibility():
	var prev_note = touching_notes.get(Global.START_IS_TOUCHING)
	var next_note = touching_notes.get(Global.END_IS_TOUCHING)
	
	if ((!show_bar_handle && bar != prev_note.end)
			|| (!show_end_handle && end != next_note.bar)):
		update_touching_notes()
	
	if !show_bar_handle:
		bar_handle.size.x = BARHANDLE_SIZE.x / 2
		bar_handle.position.x = 0
	else: 
		bar_handle.size.x = BARHANDLE_SIZE.x
		bar_handle.position.x = -BARHANDLE_SIZE.x / 2
	
	if !show_end_handle:
		end_handle.size.x = ENDHANDLE_SIZE.x / 2
	else:
		end_handle.size.x = ENDHANDLE_SIZE.x
	
	queue_redraw()


func _update(): #update visuals
	if chart == null: return
	position.x = chart.bar_to_x(bar)
	position.y = chart.pitch_to_height(pitch_start)
	
	end_handle.position = Vector2(scaled_length, end_height) - ENDHANDLE_SIZE / 2
	
	pitch_handle.size = Vector2(scaled_length, visual_height + TAIL_HEIGHT)
	pitch_handle.position = Vector2(0, higher_pitch - (TAIL_HEIGHT / 2) )
	
	size.x = scaled_length
	queue_redraw()


func _draw():
	if chart.draw_targets:
		draw_rect(Rect2(bar_handle.position,bar_handle.size),Color.WHITE,false)
		draw_rect(Rect2(pitch_handle.position,pitch_handle.size),Color.WHITE,false)
		draw_rect(Rect2(end_handle.position,end_handle.size),Color.WHITE,false)
	var start_color = chart.settings.start_color
	var end_color = chart.settings.end_color
	
	var _draw_bar_handle := func():
		var radius = BARHANDLE_SIZE.x / 2
		draw_circle(Vector2.ZERO, radius - 1.0, start_color)
		draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 36, Color.WHITE, 2.0, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color.BLACK, 1.0,true)
	
	var _draw_end_handle := func():
		var radius = ENDHANDLE_SIZE.x / 2
		var endhandle_position := Vector2(size.x,end_height)
		draw_circle(endhandle_position, radius - 1.0, end_color)
		draw_arc(endhandle_position, radius - 2.0, 0.0, TAU, 36, Color.WHITE, 2.0, true)
		draw_arc(endhandle_position, radius, 0.0, TAU, 36, Color.BLACK, 1.0,true)
	
	var _draw_tail := func():
		var y_array := []
		var col_array := []
		var num_points = 24
		for i in num_points:
			var weight := smoothstep(0, 1, float(i) / (num_points - 1))
			y_array.insert(i, weight)
			col_array.append(start_color.lerp(end_color,
			smoothstep(0, 1, smoothstep(0, 1, weight))))
		col_array.push_front(start_color)
		col_array.push_back(end_color)
		var colors = PackedColorArray(col_array)
		y_array.push_front(0.0)
		y_array.push_back(1.0)
		var points = PackedVector2Array()
		for idx in y_array.size():
			points.append(Vector2(
					(scaled_length * (float(idx) / (y_array.size() - 1))),
					end_height * y_array[idx])
			)
		if has_focus():
			for i in 8: # it's fine, only one of these has focus at a time
				draw_polyline(points, Color(0.5, 0.9, 1, 0.01 * i * i), 32 - (2 * i), true)
		draw_polyline(points, Color.BLACK, 16, true)
		draw_polyline(points, Color.WHITE, 12, true)
		draw_polyline_colors(points, colors, 6, true)
	
	_draw_tail.call()
	if show_bar_handle: _draw_bar_handle.call()
	if show_end_handle: _draw_end_handle.call()
	
"func grab_focus():
	super()
	queue_redraw()"


func _exit_tree():
	#print("exited tree!")
	bar = -69420.0
	#we need the bar number for our undo/redo, so we just grab the entire note earlier, in the two places that Note calls queue.free()
	if chart.clearing_notes: return
	update_touching_notes()
	chart.update_note_array()

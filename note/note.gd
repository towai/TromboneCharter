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
# n.b. a delta of 1e-18 or -1e-17 in a .tmb will round to 0 when parsed in with the JSON parser
# (see the note in the JSON class's doc) but still show in the game as a note with length. however,
# if this happens you definitely did that on purpose and on re-saving from charter
# the delta will become 0 (the note will become a tap note)
# if desired, this knowledge could be exploited to make the game not convert some notes to tap notes
# by giving them an imperceptible and inconsequential delta value (0.0001 is already only ~0.14¢)
var is_tap_note: bool:
	get: return length <= 0.0625 && !is_slide && touching_notes.is_empty()
	set(_v): assert(false)
var dragging := 0
enum {
	DRAG_NONE,
	DRAG_BAR,
	DRAG_PITCH,
	DRAG_END,
	DRAG_INITIAL,
}
enum { # TODO figure out better names for these
	END_IS_TOUCHING,
	START_IS_TOUCHING,
}

var doot_enabled : bool = false
# This will get assigned when uploading to TootTally
var tt_note_id : int = 0

@onready var chart = get_parent()

@onready var bar_handle = $BarHandle
@onready var pitch_handle = $PitchHandle
@onready var end_handle = $EndHandle

@onready var drag_helper = DragHelper.new(self)
@onready var slide_helper = SlideHelper.new(self)

var touching_notes : Dictionary:
	get: return slide_helper.touching_notes
	set(value): slide_helper.touching_notes = value
var show_bar_handle : bool:
	get: return (touching_notes.get(START_IS_TOUCHING) == null)
var show_end_handle : bool:
	get: return (touching_notes.get(END_IS_TOUCHING) == null
				&& (!is_tap_note || has_focus())
			)
var index_in_slide := 0 # for matching the new, improved look of slides in the game

### Dew's variables ###
var starting_note : Array #initial data of note-to-be-edited
var old_set := [] #Both old_set and note_set store up to three note ref/data arrays

var added : bool
var dragged : bool
var click := false

var neighbors : Dictionary
var note_set := [] #Both old_set and note_set store up to three note ref/data arrays
###

# cat rolls the most horrible solution ever, asked to leave the repo
func find_idx_in_slide() -> int:
	var left_neighbor : Note = touching_notes.get(START_IS_TOUCHING)
	
	match left_neighbor:
		null: index_in_slide = 0
		_:    index_in_slide = (left_neighbor.find_idx_in_slide() + 1)
	
	queue_redraw()
	return index_in_slide

func propagate_to_the_right(f:StringName,args:Array=[]):
	var right_neighbor : Note = touching_notes.get(END_IS_TOUCHING)
	
	match right_neighbor:
		null: return callv(f,args)
		_: return right_neighbor.propagate_to_the_right(f,args)


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
			KEY_DELETE, KEY_BACKSPACE:
				
				redo_check()
				#Dew stores note without deleting yet!!!!!
				Global.deleted = true
				Global.d_note = self
				print("that's deleting")
				
				Global.revision += 1
				Global.a_array.append(Global.ratio)
				Global.d_array.append([bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta])
				Global.changes.append(moved_notes([bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]))
				chart.update_note_array()
				### queue_free()
	


func _on_handle_input(event, which_handle):
	move_child(end_handle, -1 if is_tap_note else 0)
	move_child(pitch_handle, -1 if Input.is_key_pressed(KEY_SHIFT) else 0)
	
	event = event as InputEventMouseButton
	if event == null: return
	if event.pressed: match event.button_index:
		MOUSE_BUTTON_LEFT:
			
			#Dew marks note creation to avoid duplication and tracking of interim dragging data,
			#then stores both initial note data and ref/data array pair in starting_note and old_set, respectively.
			if !click :
				click = true
				starting_note = [bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]
				old_set = moved_notes(starting_note.duplicate())
			###
			dragging = which_handle
			drag_helper.init_drag()
			chart.doot(pitch_start if which_handle != DRAG_END else end_pitch)
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
			
			#Dew deleted note storage (self)
			redo_check()
			Global.deleted = true
			Global.d_note = self
			print("that's deleting")
			
			Global.revision += 1
			Global.a_array.append(Global.ratio)
			Global.d_array.append([bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta])
			Global.changes.append(moved_notes([bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]))
			chart.update_note_array()
			### queue_free()


func _process_drag():
	if !(Input.get_mouse_button_mask() & MOUSE_BUTTON_LEFT):
		_end_drag()
		return
	
	var drag_result = drag_helper.process_drag(dragging)
	# drag result will come back null if drag rejected due to note overlap
	if drag_result == null: return
	
	match dragging:
		DRAG_BAR: # → float
			
			#Dew statement
			dragged = true
			print("that bar's dragging")
			###
			
			bar = drag_result
		DRAG_PITCH:  # → float
			
			#Dew statement
			dragged = true
			print("that pitch's dragging")
			###
			
			pitch_start = drag_result
			
			doot_enabled = false
			if end_pitch > 13 * Global.SEMITONE:
				pitch_delta = (13 * Global.SEMITONE) - pitch_start
			if end_pitch < -13 * Global.SEMITONE:
				pitch_delta = -(13 * Global.SEMITONE) - pitch_start
			doot_enabled = true
		DRAG_END: # → Vector2
			
			#Dew statement
			dragged = true
			print("that end's dragging")
			###
			
			length = drag_result.x
			pitch_delta = drag_result.y
		DRAG_INITIAL: # → Vector2
			
			#Dew statement
			added = true
			print("that's a new note")
			###
			
			pitch_start = drag_result.y
			# editing notes butted up against each other would be too annoying
			# if we did this check first
			if chart.continuous_note_overlaps(drag_result.x,length,[drag_helper.old_bar]):
				return
			bar = drag_result.x
		_: print("Bad drag %d" % dragging)
	
	_update()


func _end_drag():
	dragging = DRAG_NONE
	#Dew note-changed check + drag-recording
	#Dragging/moving a note is effectively deleting the old placement of a note and adding the new placement.
	#We do this by marking every action with either an "L" array, for single-edit actions: adding and deleting;
	#or an "F" array, for the effective double-edit action: dragging. These are checked by the UR_handler() in chart.gd.
	click = false
	var proper_note : Array = [bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]
	if starting_note != proper_note : #if you did more than just click an existing note, then an edit was made
		redo_check()
		if dragged: #add a drag marker to a_array, and the initial data to d_array
			Global.revision += 1
			print(Global.revision)
			Global.changes.append(old_set)
			Global.a_array.append(Global.respects)
			Global.d_array.append(starting_note.duplicate(true))
			print(Global.revision,"m (change): ",Global.changes[Global.revision])
			
		if added: #add "add" marker to d_array, and final data to a_array
			Global.revision += 1
			print(Global.revision)
			slide_helper.pass_on_slide_propagation()
			Global.changes.append(moved_notes([bar,length,pitch_start,pitch_delta,pitch_start+pitch_delta]))
			Global.a_array.append(proper_note.duplicate(true))
			Global.d_array.append(Global.ratio)
			print(Global.revision,"a (change): ",Global.changes[Global.revision])
	###
	
	slide_helper.snap_near_pitches()
	if !Input.is_key_pressed(KEY_ALT):
		slide_helper.pass_on_slide_propagation()
	
	update_touching_notes()
	print("call end_drag from ",bar)
	print(propagate_to_the_right("find_idx_in_slide"))
	chart.update_note_array()


func _snap_near_pitches(): slide_helper.snap_near_pitches()


func has_slide_neighbor(direction:int,pitch:float):
	match direction:
		START_IS_TOUCHING:
			return touching_notes.has(direction) && touching_notes[direction].end_pitch == pitch
		END_IS_TOUCHING:
			return touching_notes.has(direction) && touching_notes[direction].pitch_start == pitch
	
	
#Dew remove future undo/redo chain when overwritten
func redo_check(): #Global.UR[2] stores number of available redos, so if it isn't 0 and an edit is made...
	if Global.UR[2] > 0 : #... gotta clear the chain of edits that existed in the now-overwritten future.
		Global.changes = Global.changes.slice(0,Global.revision+1,1,true)
		Global.a_array = Global.a_array.slice(0,Global.revision,1,true)
		Global.d_array = Global.d_array.slice(0,Global.revision,1,true)
		Global.UR[2] = 0
	return
	###
	
#Dew concatenates touching note ref/data array pairs into a nested array "note_set" = [next,prev,self]
func moved_notes(self_data): #can be used to retrieve data both before and after a note is moved
	note_set = []
	neighbors = slide_helper.find_touching_notes()
	for key in neighbors.keys() :
		var note = neighbors[key]
		note_set.append([note,[note.bar,note.length,note.pitch_start,note.pitch_delta,note.pitch_start+note.pitch_delta]])
	note_set.append([self,self_data])
	#appends self+data last to fit prev/next note enum
	return note_set

func update_touching_notes():
	slide_helper.update_touching_notes()
	update_handle_visibility()

func receive_slide_propagation(from:int):
	doot_enabled = false
	slide_helper.handle_slide_propagation(from)
	if length <= 0: queue_free()
	doot_enabled = true


func update_handle_visibility():
	var prev_note = touching_notes.get(START_IS_TOUCHING)
	var next_note = touching_notes.get(END_IS_TOUCHING)
	
	if ((prev_note != null && bar != prev_note.end)
			|| (next_note != null && end != next_note.bar)):
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


func _update():
	if chart == null: return
	position.x = chart.bar_to_x(bar)
	position.y = chart.pitch_to_height(pitch_start)
	
	size.x = scaled_length
	if !is_in_view: return
	
	resize_handles()
	
	queue_redraw()

func resize_handles() -> void:
	var scaledlength = scaled_length # only calculate once
	end_handle.position = Vector2(scaledlength, end_height) - ENDHANDLE_SIZE / 2
	
	pitch_handle.size = Vector2(scaledlength, visual_height + TAIL_HEIGHT)
	pitch_handle.position = Vector2(0, higher_pitch - (TAIL_HEIGHT / 2) )

func _draw():
	if chart.draw_targets:
		draw_rect(Rect2(bar_handle.position,bar_handle.size),Color.WHITE,false)
		draw_rect(Rect2(pitch_handle.position,pitch_handle.size),Color.WHITE,false)
		draw_rect(Rect2(end_handle.position,end_handle.size),Color.WHITE,false)
	var swap_colors : bool = (index_in_slide & 1)
	var start_color = chart.settings.start_color if !swap_colors else chart.settings.end_color
	var end_color = chart.settings.end_color if !swap_colors else chart.settings.start_color
	
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
		draw_polyline_colors(points, colors, 6, true)
	
	if !is_tap_note || has_focus():_draw_tail.call()
	if show_bar_handle: _draw_bar_handle.call()
	if show_end_handle: _draw_end_handle.call()


func _exit_tree():
	if chart.clearing_notes: return
	update_touching_notes()
	if Global.please_come_back:
		return
	else: chart.update_note_array()

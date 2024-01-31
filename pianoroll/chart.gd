extends Control

const scrollbar_height : float = 8

var scroll_position : float:
	get: return %ChartView.scroll_horizontal
var scroll_end : float:
	get: return scroll_position + %ChartView.size.x
var view_bounds: ViewBounds:
	get: return ViewBounds.new(x_to_bar(scroll_position),x_to_bar(scroll_end))
	set(_with): pass # would a function to set the scroll and zoom together be useful?
class ViewBounds:	# effectively a vector2 with nicer code completion
					# these values are in bars, not pixels
	var left: float
	var right:float
	var center: float:
		get: return (left + right) / 2.0
		set(_with): assert(false)
	func _init(left:float,right:float):
		self.left = left
		self.right = right

var bar_spacing : float = 1.0
#	get: return tmb.savednotespacing * %ZoomLevel.value
var middle_c_y : float:
	get: return (key_height * 13.0) + (key_height / 2.0)
var key_height : float:
	get: return (size.y + scrollbar_height) / Global.NUM_KEYS
var current_subdiv : float:
	get: return 1.0 / %TimingSnap.value
var note_scn = preload("res://note/note.tscn")
var settings : Settings:
	get: return Global.settings
var bar_font : Font
var draw_targets : bool:
	get: return %ShowMouseTargets.button_pressed
var doot_enabled : bool = true
var _update_queued := false
var clearing_notes := false
var prev_section_start : float = 0.0
func height_to_pitch(height:float):
	return ((height - middle_c_y) / key_height) * Global.SEMITONE
func pitch_to_height(pitch:float):
	return middle_c_y - ((pitch / Global.SEMITONE) * key_height)
func x_to_bar(x:float): return x / bar_spacing
func bar_to_x(bar:float): return bar * bar_spacing
@onready var main = get_tree().get_current_scene()
@onready var player : AudioStreamPlayer = %TrombPlayer
@onready var measure_font : Font = ThemeDB.get_fallback_font()
@onready var tmb : TMBInfo:
	get: return Global.working_tmb

### Dew's variables ###
var new_array := []
var post_UR_copy := []
var stack_short = 0 #number of revisions behind master array
var stuffing := false
var stuffed_note : Note
var drag_UR := false
###

var EDIT_MODE := 0
var SELECT_MODE := 1
var mouse_mode : int = EDIT_MODE
var show_preview : bool = false
var playhead_preview : float = 0.0

func doot(pitch:float):
	if !doot_enabled || %PreviewController.is_playing: return
	player.pitch_scale = Global.pitch_to_scale(pitch / Global.SEMITONE)
	player.play()
	await(get_tree().create_timer(0.1).timeout)
	player.stop()


func _ready():
	bar_font = measure_font.duplicate()
	main.chart_loaded.connect(_on_tmb_loaded)
	Global.tmb_updated.connect(_on_tmb_updated)
	%TimingSnap.value_changed.connect(timing_snap_changed)


func _process(_delta):
	if _update_queued: _do_tmb_update()
	if %PreviewController.is_playing: queue_redraw()


func _on_scroll_change():
	await(get_tree().process_frame)
	queue_redraw()
	redraw_notes()
	%WavePreview.calculate_width()

#Dew: Please come back from _exit_tree after removing child note from chart! I added a condition there and everything...
func filicide(child): #removes note from tree, returns to update_note_array()
	Global.deleted = false
	Global.please_come_back = true
	%Chart.remove_child(child)
	Global.please_come_back = false
	return
###

#Dew undo/redo shortcut handler: sets indicator values in UR array, then calls update_note_array()
func _unhandled_key_input(event):
	var shift = event as InputEventWithModifiers
	if !shift.shift_pressed && Input.is_action_just_pressed("ui_undo") && Global.revision > 0:
		print("REDOS PRE-UNDO: ",Global.UR[2])
		stack_short = Global.a_array.size() - Global.active_stack.size()
		Global.UR[0] = 1
		print("undo pressed!")
		update_note_array()
	if Input.is_action_just_pressed("ui_redo") && Global.UR[2] > 0:
		print("REDOS PRE-REDO: ",Global.UR[2])
		Global.UR[0] = 2
		Global.UR[1] = 2 #makes sure the UR handler doesn't seek beyond array size
		stack_short = Global.a_array.size() - Global.active_stack.size()
		if stack_short == 1 : #if it could go too far, set indicator
			Global.UR[1] = 1
		print("redo pressed!")
		update_note_array()
###

func redraw_notes():
	for child in get_children():
		if !(child is Note): continue
		if child.is_in_view:
			child.show()
			child.resize_handles()
			child.update_handle_visibility()
			#child.queue_redraw()
		else: child.hide()


func _on_tmb_updated():
	bar_spacing = tmb.savednotespacing * %ZoomLevel.value
	_update_queued = true

func _do_tmb_update():
	custom_minimum_size.x = (tmb.endpoint + 1) * bar_spacing
	%SectionStart.max_value = tmb.endpoint
	%SectionLength.max_value = max(1, tmb.endpoint - %SectionStart.value)
	%PlayheadPos.max_value = tmb.endpoint
	%LyricsEditor._update_lyrics()
	%Settings._update_handles()
	for note in get_children():
		if !(note is Note) || note.is_queued_for_deletion():
			continue
		note.position.x = note.bar * bar_spacing
		if !note.touching_notes.has(Note.END_IS_TOUCHING): note.find_idx_in_slide()
	queue_redraw()
	redraw_notes()
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

func stuff_note(note := [Note,[]]) : #note = reference/data array pairs stored in G.changes
	stuffing = true
	stuffed_note = note[0]
	add_note(false, note[1][0], note[1][1], note[1][2], note[1][3])
	return

func add_note(start_drag:bool, bar:float, length:float, pitch:float, pitch_delta:float = 0.0):
	var new_note : Note
	if !stuffing : #if not altering a moved note, create a new one as normal
		new_note = note_scn.instantiate()
	else: #if altering a moved note, use the reference!
		stuffing = false
		new_note = stuffed_note
	new_note.bar = bar
	new_note.length = length
	new_note.pitch_start = pitch
	new_note.pitch_delta = pitch_delta
	new_note.position.x = bar_to_x(bar)
	new_note.position.y = pitch_to_height(pitch)
	new_note.dragging = Note.DRAG_INITIAL if start_drag else Note.DRAG_NONE
	if doot_enabled: doot(pitch)
	add_child(new_note) #throws a C++ error when altering moved notes; need advice.
	new_note.grab_focus()

# move to ???
func continuous_note_overlaps(time:float, length:float, exclude : Array = []) -> bool:
	var is_in_range := func(value: float, range_start:float, range_end:float):
		return value > range_start && value < range_end
	
	for note in Global.working_tmb.notes:
		var bar = note[TMBInfo.NOTE_BAR]
		var end = note[TMBInfo.NOTE_BAR] + note[TMBInfo.NOTE_LENGTH]
		if bar in exclude: continue
		for value in [bar, end]:
			if is_in_range.call(value,time,time+length): return true
		# we need to test the middle of the note so that notes of the same length
		# don't think it's fine if they start and end at the same time
		for value in [time, time + length, time + (length / 2.0)]:
			if is_in_range.call(value,bar,end): return true
	
	return false


func update_note_array():
	if Global.deleted: #if we came here by deleting a note, let's remove it and reassess the chart as such
		filicide(Global.d_note)
	new_array = []
	print("Hi, I'm Tom Scott, and today I'm here in func update_note_array()")
	for note in get_children():
		if !(note is Note) || note.is_queued_for_deletion() || (Global.UR[0] > 0): #Dew added check for undo/redo
			continue
		var note_array := [
			note.bar, note.length, note.pitch_start, note.pitch_delta,
			note.pitch_start + note.pitch_delta
		]
		new_array.append(note_array)
	
	Global.active_stack = new_array
	print("added notes: ",Global.a_array)
	print("deleted notes: ",Global.d_array)
	#print("Global.active_stack: ",Global.active_stack)
	#print("Global.changes: ",Global.changes)
	
	new_array.sort_custom(func(a,b): return a[TMBInfo.NOTE_BAR] < b[TMBInfo.NOTE_BAR])
	tmb.notes = new_array
	

	###Dew directing traffic to undo/redo
	if Global.UR[0] > 0 :
		UR_handler()
	else :
		queue_redraw()
		redraw_notes()
	###


func jump_to_note(note: int, use_tt: bool = false):
	var count = 0
	var children = get_children()
	if not use_tt:
		children.sort_custom(func(a, b): return a.position.x < b.position.x)
	for child in children:
		if !(child is Note): continue
		count += 1
		if use_tt and note != child.tt_note_id:
			continue
		elif not use_tt and count != note:
			continue
		else:
			%ChartView.set_h_scroll(int(child.position.x - (%ChartView.size.x / 2)))
			redraw_notes()
			queue_redraw()
			child.grab_focus()
			break

func assign_tt_note_ids():
	var count = 0
	var children = %Chart.get_children()
	children.sort_custom(func(a, b): return a.position.x < b.position.x)
	for child in children:
		if !(child is Note): continue
		count += 1
		child.tt_note_id = count


	
#Dew's closest he will ever get to yandev levels of if/then incompetence. It's not *that* bad, but it feels clunky.
#Also Dew's undo/redo handler.
func UR_handler():
	print("UR!!! ",Global.UR[0])
	var passed_note = []
	drag_UR = false
	if Global.UR[0] == 1 :
		print("UR Undo! // UR[1]= ",Global.UR[1])
		if Global.revision > 1:
			if Global.a_array[Global.revision-2] == Global.respects :
				drag_UR = true
				print("undo dragged")
				passed_note = Global.d_array[Global.revision-2]
				for note in Global.changes[Global.revision-1] :
					stuff_note(note)
					
				Global.active_stack.remove_at(Global.active_stack.bsearch(Global.a_array[Global.revision-1]))
				Global.active_stack.append(passed_note)
				
				Global.revision -= 2
				Global.UR[0] = 0
				Global.UR[2] += 1
		if !drag_UR :
			if Global.d_array[Global.revision-1] == Global.ratio:
				print("undo added")
				filicide(Global.changes[Global.revision][-1][0])
				Global.active_stack.remove_at(Global.active_stack.bsearch(Global.a_array[Global.revision-1]))
				Global.revision -= 1
				Global.UR[0] = 0
				Global.UR[2] += 1
			
			elif Global.a_array[Global.revision-1] == Global.ratio:
				print("undo deleted: ", Global.changes)
				print("revision: ",   Global.revision)
				print("to be added: ",Global.changes[Global.revision])
				passed_note = Global.d_array[Global.revision-1]
				
				for note in Global.changes[Global.revision-1] :
					stuff_note(note)
				
				Global.revision -= 1
				Global.UR[0] = 0
				Global.UR[2] += 1
		
		print("active_stack: ",Global.active_stack)
		post_UR_copy = Global.active_stack
		post_UR_copy.sort_custom(func(a,b): return a[TMBInfo.NOTE_BAR] < b[TMBInfo.NOTE_BAR])
		tmb.notes = post_UR_copy
		
	if Global.UR[0] == 2 :
		print("UR Redo! // UR[1]= ",Global.UR[1])
		if Global.UR[1] == 2 :
			if Global.a_array[Global.revision] == Global.respects :
				drag_UR = true
				print("redo dragged")
				passed_note = Global.a_array[Global.revision+1]
				print("revision: ", Global.revision)
				
				for note in Global.changes[Global.revision+	2] :
					stuff_note(note)
				#print("a_stack changes note r_m: ",Global.a_array[Global.revision-1]," = ",Global.changes[Global.revision-1])
				Global.active_stack.remove_at(Global.active_stack.bsearch(Global.d_array[Global.revision]))
				Global.active_stack.append(passed_note)
				
				Global.revision += 2
				Global.UR[2] -= 1
			
		if Global.UR[1] != 0 && !drag_UR :
			if Global.d_array[Global.revision] == Global.ratio :
				print("redo added: ", Global.changes)
				print("revision: ",   Global.revision+1)
				print("to be added: ",Global.changes[Global.revision+1])
				passed_note = Global.a_array[Global.revision]
				
				for note in Global.changes[Global.revision+1] :
					stuff_note(note)
				
				Global.active_stack.append(passed_note)
				
				Global.revision += 1
				Global.UR[2] -= 1
				
			elif Global.a_array[Global.revision] == Global.ratio :
				print("redo deleted")
				filicide(Global.changes[Global.revision][-1][0])
				Global.active_stack.remove_at(Global.active_stack.bsearch(Global.d_array[Global.revision]))
				Global.revision += 1
				Global.UR[2] -= 1
				
		
		print("active_stack: ",Global.active_stack)
		Global.UR[1] = 0
		post_UR_copy = Global.active_stack.slice(0,Global.revision)
		post_UR_copy.sort_custom(func(a,b): return a[TMBInfo.NOTE_BAR] < b[TMBInfo.NOTE_BAR])
		tmb.notes = post_UR_copy
	print("REDOS LEFT: ",Global.UR[2])
	print("REDOS == STACK_SHORT: ",stack_short)
	print("Global.changes: ",Global.changes)
	
	Global.UR[0] = 0
	update_note_array()
###

func _draw():
	var font : Font = ThemeDB.get_fallback_font()
	if tmb == null: return
	if settings.section_length:
		var section_rect = Rect2(bar_to_x(settings.section_start), 1,
				bar_to_x(settings.section_length), size.y)
		draw_rect(section_rect, Color(0.3, 0.9, 1.0, 0.1))
		draw_rect(section_rect, Color.CORNFLOWER_BLUE, false, 3.0)
	if show_preview:
		var mouse_pos = get_local_mouse_position()
		if get_rect().has_point(mouse_pos):
			draw_line(Vector2(mouse_pos.x,0), Vector2(mouse_pos.x,size.y),
						Color.ORANGE_RED, 1 )
	if %PreviewController.is_playing:
		if settings.section_length:
			draw_line(Vector2(bar_to_x(%PreviewController.song_position),0),
					Vector2(bar_to_x(%PreviewController.song_position),size.y),
					Color.CORNFLOWER_BLUE, 2 )
		else:
			settings.playhead_pos = %PreviewController.song_position
	for i in tmb.endpoint + 1:
		var line_x = i * bar_spacing
		var next_line_x = (i + 1) * bar_spacing
		if (line_x < scroll_position) && (next_line_x < scroll_position): continue
		if line_x > scroll_end: break
		draw_line(Vector2(line_x, 0), Vector2(line_x, size.y),
				Color.WHITE if !(i % tmb.timesig)
				else Color(1,1,1,0.33) if bar_spacing > 20.0
				else Color(1,1,1,0.15), 2
			)
		var subdiv = %TimingSnap.value
		for j in subdiv:
			if i == tmb.endpoint || bar_spacing < 20.0: break
			if j == 0.0: continue
			var k = 1.0 / subdiv
			var line = i + (k * j)
			draw_line(Vector2(line * bar_spacing, 0), Vector2(line * bar_spacing, size.y),
					Color(0.7,1,1,0.2) if bar_spacing > 20.0
					else Color(0.7,1,1,0.1),
					1 )
		if !(i % tmb.timesig):
			draw_string(font, Vector2(i * bar_spacing, 0) + Vector2(8, 16),
					str(i / tmb.timesig), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string(font, Vector2(i * bar_spacing, 0) + Vector2(8, 32),
					str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_line(Vector2(bar_to_x(%PlayheadPos.value), 0),
				Vector2(bar_to_x(%PlayheadPos.value), size.y),
				Color.ORANGE_RED, 2.0)


func count_onscreen_notes() -> int:
	var accum := 0
	for child in get_children():
		if (child is Note && child.is_in_view): accum += 1
	return accum

func update_playhead(event):
	var bar = %Chart.x_to_bar(event.position.x)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Since the Chart node is currently handling this input event
				# Godot won't change the cursor shape when the playhead moves
				# so I'm manually setting it here
				mouse_default_cursor_shape = CURSOR_POINTING_HAND
				settings.playhead_pos = bar
			else:
				mouse_default_cursor_shape = CURSOR_ARROW
	elif event is InputEventMouseMotion:
		queue_redraw()
	# Forward the input event to the handle here otherwise the user will
	# need to re-click to move the playhead further.
	var mouse_pos = %PlayheadHandle.get_local_mouse_position()
	event.position = mouse_pos
	%PlayheadHandle._gui_input(event)

func _gui_input(event):
	if event is InputEventPanGesture:
		# Used for two finger scrolling on trackpads
		_on_scroll_change()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
		|| event.button_index == MOUSE_BUTTON_WHEEL_UP \
		|| event.button_index == MOUSE_BUTTON_WHEEL_LEFT \
		|| event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_on_scroll_change()
	if Input.is_key_pressed(KEY_SHIFT):
		update_playhead(event)
		return
	match mouse_mode:
		SELECT_MODE:
			# this isn't as clean as i'd like but i didn't want to rewrite everything
			var bar = %Chart.x_to_bar(event.position.x)
			if bar < 0:
				bar = 0
			if settings.snap_time: bar = snapped(bar, %Chart.current_subdiv)
			if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
				prev_section_start = bar
				settings.section_start = bar
				settings.section_length = 0
			elif event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
				prev_section_start = settings.section_start
			elif event is InputEventMouseMotion && event.pressure:
				if %Chart.x_to_bar(event.position.x) < prev_section_start:
					settings.section_length = prev_section_start - bar
					settings.section_start = bar
				else:
					settings.section_length = bar - settings.section_start
		EDIT_MODE: #Edit mode (default)
			event = event as InputEventMouseButton
			if event == null || !event.pressed: return
			if event.button_index == MOUSE_BUTTON_LEFT && !%PreviewController.is_playing:
				@warning_ignore("unassigned_variable")
				var new_note_pos : Vector2
				
				if settings.snap_time: new_note_pos.x = to_snapped(event.position).x
				else: new_note_pos.x = to_unsnapped(event.position).x
				
				# Current length of tap notes
				var note_length = 0.0625 if settings.tap_notes else current_subdiv
				
				if new_note_pos.x == tmb.endpoint: new_note_pos.x -= (1.0 / settings.timing_snap)
				if continuous_note_overlaps(new_note_pos.x, note_length): return
				
				if settings.snap_pitch: new_note_pos.y = to_snapped(event.position).y
				else: new_note_pos.y = clamp(to_unsnapped(event.position).y,
						Global.SEMITONE * -13, Global.SEMITONE * 13)
				
				add_note(true, new_note_pos.x, note_length, new_note_pos.y)
				%LyricsEditor.move_to_front()
				%PlayheadHandle.move_to_front()

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

func _on_mouse_exited():
	show_preview = false
	queue_redraw()


func _on_mouse_entered():
	if Input.is_key_pressed(KEY_SHIFT):
		show_preview = true
		queue_redraw()

class_name SlideHelper
extends Object

var owner : Note
var chart : Control:
	get: return owner.chart
var touching_notes : Dictionary = {}


func _init(caller:Note): owner = caller


func snap_near_pitches():
	var near_pitch_threshold = Global.SEMITONE / 12
	if touching_notes.has(Note.START_IS_TOUCHING):
		var neighbor : Note = touching_notes[Note.START_IS_TOUCHING]
		if abs(owner.pitch_start - neighbor.end_pitch) <= near_pitch_threshold:
			owner.pitch_start = neighbor.end_pitch
	if touching_notes.has(Note.END_IS_TOUCHING):
		var neighbor : Note = touching_notes[Note.END_IS_TOUCHING]
		if abs(owner.end_pitch - neighbor.pitch_start) <= near_pitch_threshold:
			owner.pitch_delta = neighbor.pitch_start - owner.pitch_start


func handle_slide_propagation(from:int):
	var neighbor = touching_notes[from]
	match from:
		Note.START_IS_TOUCHING:
			var length_change = owner.bar - neighbor.end
			var pitch_change = owner.pitch_start - neighbor.end_pitch
			owner.bar -= length_change
			owner.length += length_change
			owner.pitch_start -= pitch_change
			owner.pitch_delta += pitch_change
		Note.END_IS_TOUCHING:
			var length_change = owner.end - neighbor.bar
			var pitch_change = owner.end_pitch - neighbor.pitch_start
			owner.length -= length_change
			owner.pitch_delta -= pitch_change
		_: print("????? %s: Slide propagation from invalid neighbor %d" % [self,from])


func find_touching_notes() -> Dictionary:
	var result := {}
	
	var prev_note = get_matching_note_off(owner.bar,[owner])
	if prev_note: result[Note.START_IS_TOUCHING] = prev_note
	
	var next_note = get_matching_note_on(owner.end,[owner])
	if next_note: result[Note.END_IS_TOUCHING] = next_note
	
	return result


func get_matching_note_on(time:float, exclude:Array = []): # -> Note or null
	for note in chart.get_children():
		if !(note is Note) || (note in exclude): continue
		if abs(note.bar - time) < 0.01: return note
	return null
func get_matching_note_off(time:float, exclude:Array = []): # -> Note or null
	for note in chart.get_children():
		if !(note is Note) || (note in exclude): continue
		if abs(note.end - time) < 0.01: return note
	return null


func update_touching_notes():
	var old_prev_note = touching_notes.get(Note.START_IS_TOUCHING)
	var old_next_note = touching_notes.get(Note.END_IS_TOUCHING)
	touching_notes = find_touching_notes()
	
	var prev_note = touching_notes.get(Note.START_IS_TOUCHING)
	match prev_note:
		null: if old_prev_note != null: old_prev_note.update_touching_notes()
		_:
			prev_note.touching_notes[Note.END_IS_TOUCHING] = owner if owner.bar >= 0 \
					else null
			prev_note.end = owner.bar
			prev_note.update_handle_visibility()
	
	var next_note = touching_notes.get(Note.END_IS_TOUCHING)
	match next_note:
		null: if old_next_note != null: old_next_note.update_touching_notes()
		_: 
			next_note.touching_notes[Note.START_IS_TOUCHING] = owner if owner.bar >= 0 \
					else null
			next_note.bar = owner.end
			next_note.update_handle_visibility()
	
	owner.propagate_to_the_right("find_idx_in_slide",[])


func pass_on_slide_propagation():
	if has_slide_neighbor(Note.START_IS_TOUCHING, owner.drag_helper.old_pitch):
		touching_notes[Note.START_IS_TOUCHING].receive_slide_propagation(Note.END_IS_TOUCHING)
	
	if has_slide_neighbor(Note.END_IS_TOUCHING, owner.drag_helper.old_end_pitch):
		touching_notes[Note.END_IS_TOUCHING].receive_slide_propagation(Note.START_IS_TOUCHING)


func has_slide_neighbor(direction:int,pitch:float):
	match direction:
		Note.START_IS_TOUCHING:
			return touching_notes.has(direction) && touching_notes[direction].end_pitch == pitch
		Note.END_IS_TOUCHING:
			return touching_notes.has(direction) && touching_notes[direction].pitch_start == pitch


static func find_slide_neighbors(note:Note) -> Array:
	var neighbors := []
	if note.has_slide_neighbor(Note.END_IS_TOUCHING, note.end_pitch):
		neighbors.append(note.touching_notes[Note.END_IS_TOUCHING].bar)
	
	if note.has_slide_neighbor(Note.START_IS_TOUCHING, note.pitch_start):
		neighbors.append(note.touching_notes[Note.START_IS_TOUCHING].bar)
	return neighbors

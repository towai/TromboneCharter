class_name DragHelper
extends Object

var owner : Note
var chart:Control:
	get: return owner.chart
	set(_value): assert(false)
var old_bar : float
var old_end : float
var old_pitch : float
var old_end_pitch : float
var drag_start := Vector2.ZERO
var settings := Global.settings


func _init(caller:Note):
	owner = caller
	init_drag()


func init_drag():
	old_bar = owner.bar
	old_end = owner.end
	old_pitch = owner.pitch_start
	old_end_pitch = owner.end_pitch
	drag_start = owner.get_local_mouse_position()


func process_drag(drag_type=Note.DRAG_NONE):
	match drag_type:
		Note.DRAG_BAR:
			var new_time : float
			if Global.settings.snap_time:
				new_time = chart.to_snapped(chart.get_local_mouse_position()).x
			else: new_time = chart.to_unsnapped(chart.get_local_mouse_position()).x
			if new_time + owner.length >= chart.tmb.endpoint:
				new_time = chart.tmb.endpoint - owner.length
			
			var exclude = [old_bar]
			if settings.propagate_slide_changes:
				exclude.append_array(SlideHelper.find_slide_neighbors(owner))
			
			if chart.continuous_note_overlaps(new_time,owner.length,exclude): return(null)
			
			return(new_time)
			
			
		Note.DRAG_PITCH:
			var new_pitch : float
			if Global.settings.snap_pitch:
				new_pitch = chart.to_snapped(
						chart.get_local_mouse_position() - Vector2(0, drag_start.y)
						).y
			else: new_pitch = chart.to_unsnapped(
						chart.get_local_mouse_position() - Vector2(0, drag_start.y)
						).y
			return(new_pitch)
			
		Note.DRAG_END:
			var new_end : Vector2 = chart.to_unsnapped(chart.get_local_mouse_position()) \
							- Vector2(owner.bar, owner.pitch_start)
			
			new_end.x = min(chart.tmb.endpoint,
					new_end.x if !Global.settings.snap_time \
					else snapped(new_end.x, 1.0 / Global.settings.timing_snap)
					)
			
			var exclude = [old_bar]
			if owner.has_slide_neighbor(Note.END_IS_TOUCHING, old_end_pitch) \
					&& settings.propagate_slide_changes:
				exclude.append(owner.touching_notes[Note.END_IS_TOUCHING].bar)
			
			if chart.continuous_note_overlaps(owner.bar, new_end.x, exclude) \
					|| new_end.x <= 0 \
					|| new_end.x + owner.bar > chart.tmb.endpoint:
				return(null)
			
			new_end.y = new_end.y if !Global.settings.snap_pitch \
					else snapped(new_end.y, Global.SEMITONE / Global.settings.pitch_snap)
			new_end.y = clamp(new_end.y, (-13 * Global.SEMITONE) - owner.pitch_start,
					(13 * Global.SEMITONE) - owner.pitch_start)
			
			return(new_end)
			
		Note.DRAG_INITIAL:
			@warning_ignore("unassigned_variable")
			var new_pos : Vector2
			
			if Global.settings.snap_time: new_pos.x = chart.to_snapped(chart.get_local_mouse_position()).x
			else: new_pos.x = chart.to_unsnapped(chart.get_local_mouse_position()).x
			if new_pos.x + owner.length >= chart.tmb.endpoint:
				new_pos.x = chart.tmb.endpoint - owner.length
			
			if Global.settings.snap_pitch: new_pos.y = chart.to_snapped(chart.get_local_mouse_position()).y
			else: new_pos.y = chart.to_unsnapped(chart.get_local_mouse_position()).y
			new_pos.y = clamp(new_pos.y, (-13 * Global.SEMITONE), (13 * Global.SEMITONE))
			
			return(new_pos)
		_: print("passed drag helper invalid handle # %d !" % drag_type)

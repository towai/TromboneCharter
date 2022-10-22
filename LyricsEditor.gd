extends Control


var lyric_scn = preload("res://lyric.tscn")
@onready var chart = %Chart
var updated_this_frame := 0

func _ready():
	Global.tmb_updated.connect(_update_lyrics)


func _process(_delta):
	if updated_this_frame: print("lyrics: updated %d times this frame" % updated_this_frame)
	updated_this_frame = 0


func package_lyrics() -> Array:
	print("Packagesd")
	var result := []
	for lyric in get_children():
		if !(lyric is Lyric) || lyric.is_queued_for_deletion(): continue
		var dict := {
			"bar" = lyric.bar,
			"text" = lyric.text
		}
		result.append(dict)
	result.sort_custom(func(a, b): return (a.bar < b.bar))
	print("Packagesd")
	return result


func _add_lyric(bar:float,lyric:String):
	var new_lyric = lyric_scn.instantiate()
	new_lyric.text = lyric
	new_lyric.bar = bar
	add_child(new_lyric)


func _update_lyrics():
	for child in get_children():
		if !(child is Lyric): continue
		child.position.x = chart.bar_to_x(child.bar)
	updated_this_frame += 1


func _refresh_lyrics():
	
	var children = get_children()
	
	for i in children.size():
		var child = children[-(i + 1)]
		if child is Lyric && !child.is_queued_for_deletion():
			child.queue_free()
	
	for lyric in Global.working_tmb.lyrics:
		_add_lyric(lyric.bar,lyric.text)
	
	_update_lyrics()


func _on_show_lyrics_toggled(button_pressed):
	move_to_front()
	set_visible(button_pressed)


func _on_chart_loaded():
	_refresh_lyrics()
	print("finished lyrics refresh")
	move_to_front()


func _on_add_lyric_pressed(): _add_lyric(%LyricBar.value,"")


func _on_lyric_bar_value_changed(_value): queue_redraw()


func _draw():
	draw_rect(Rect2(Vector2.ZERO,size), Color(0, 0, 0, 0.15))
	var lyric_add_bar = chart.bar_to_x(%LyricBar.value)
	draw_line(Vector2.RIGHT * lyric_add_bar, Vector2(lyric_add_bar,size.y),
			Color(0.627451, 0.12549, 0.941176, 0.5), 8.0
			)


func _on_copy_lyrics_pressed():
	var lyrics_array : Array = Global.working_tmb.lyrics.duplicate(true)
	var copied_lyrics := []
	var section_start = Global.settings.section_start
	var section_length = Global.settings.section_length
	var copy_target = Global.settings.section_target
	
	var copy_offset = copy_target - section_start
	
	for lyric in lyrics_array:
		if lyric.bar < section_start || lyric.bar > section_start + section_length: continue
		var new_lyric : Dictionary = lyric.duplicate()
		new_lyric.bar += copy_offset
		if new_lyric.bar >= Global.working_tmb.endpoint: continue
		copied_lyrics.append(new_lyric)
	
	var any_collisions = true
	while any_collisions:
		for lyric in lyrics_array:
			var bar = lyric.bar
			var collision = false
			for new_lyric in copied_lyrics:
				if new_lyric.bar == bar:
					collision = true
					break
			if collision:
				lyrics_array.erase(lyric)
				break
			if lyric == lyrics_array.back(): any_collisions = false
	lyrics_array.append_array(copied_lyrics)
	
	Global.working_tmb.lyrics = lyrics_array
	_refresh_lyrics()

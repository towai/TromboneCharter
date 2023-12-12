extends Control


var lyric_scn = preload("res://lyric.tscn")
@onready var chart = %Chart
var _update_queued := false

func _ready():
	Global.tmb_updated.connect(_on_tmb_update)

func _on_tmb_update(): _update_queued = true

func _process(_delta): if _update_queued: _update_lyrics()


func package_lyrics() -> Array:
	var result := []
	for lyric in get_children():
		if !(lyric is Lyric) || lyric.is_queued_for_deletion(): continue
		var dict := {
			"bar" = lyric.bar,
			"text" = lyric.text
		}
		result.append(dict)
	result.sort_custom(func(a, b): return (a.bar < b.bar))
	return result


func _add_lyric(bar:float,lyric:String):
	var new_lyric = lyric_scn.instantiate()
	new_lyric.text = lyric
	new_lyric.bar = bar
	add_child(new_lyric)
	return new_lyric


func _update_lyrics():
	for child in get_children():
		if !(child is Lyric): continue
		child.position.x = chart.bar_to_x(child.bar)
	_update_queued = false


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
	%PlayheadHandle.move_to_front()
	set_visible(button_pressed)
	%CopyLyrics.disabled = !button_pressed


func _on_chart_loaded():
	_refresh_lyrics()
	move_to_front()
	%PlayheadHandle.move_to_front()


func _draw():
	draw_rect(Rect2(Vector2.ZERO,size), Color(0, 0, 0, 0.15))

func _gui_input(event):
	if Input.is_key_pressed(KEY_SHIFT):
		%Chart.update_playhead(event)
		return
	if event is InputEventMouseButton and event.double_click:
		var bar = %Chart.x_to_bar(event.position.x)
		if %Settings.snap_time: bar = snapped(bar, chart.current_subdiv)
		var new_lyric = _add_lyric(bar,"")
		new_lyric.line_edit.grab_focus()

func _on_copy_lyrics_pressed():
	Global.working_tmb.lyrics = package_lyrics()
	var lyrics_array : Array = Global.working_tmb.lyrics.duplicate(true)
	var copied_lyrics := []
	var section_start = Global.settings.section_start
	var section_length = Global.settings.section_length
	var copy_target = Global.settings.playhead_pos
	
	var copy_offset = copy_target - section_start
	
	for lyric in lyrics_array:
		if lyric.bar < section_start || lyric.bar > section_start + section_length: continue
		var new_lyric : Dictionary = lyric.duplicate()
		new_lyric.bar += copy_offset
		if new_lyric.bar >= Global.working_tmb.endpoint:
			%Alert.alert("Any more lyrics would go past the chart's endpoint!",
					Vector2(%SectionSelection.position.x - 12, %Settings.position.y - 12),
					Alert.LV_ERROR)
			break # lyrics are sorted into bar order in package_lyrics()
		copied_lyrics.append(new_lyric)
	
	var any_collisions = !lyrics_array.is_empty() && !copied_lyrics.is_empty()
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

extends ScrollContainer


func _ready() -> void: get_h_scroll_bar().scrolling.connect(_on_scroll_change)


func _on_scroll_change() -> void: %Chart._on_scroll_change()
func _on_pitch_snap_value_changed(_value) -> void: queue_redraw()


func _input(event: InputEvent) -> void:
	event = event as InputEventWithModifiers
	if event == null: return
	# Surpress scrolling when CTRL held to zoom
	match event.is_command_or_control_pressed():
		true: mouse_filter = MOUSE_FILTER_IGNORE
		false: mouse_filter = MOUSE_FILTER_PASS

func _draw() -> void:
	var key_height := size.y / Global.NUM_KEYS
	
	for i in Global.NUM_KEYS:
		var key : int = 13 - i
		if key in [13, -13]: continue
		@warning_ignore("narrowing_conversion")
		var key_center : int = key_height * i + (key_height / 2)
		@warning_ignore("narrowing_conversion")
		draw_line(Vector2i.DOWN * key_center, Vector2i(size.x,key_center),
				Color(1, 1, 1, 0.1) )
		if key in [ 12, 0, -12 ]:
			draw_polyline_colors(
					[Vector2.DOWN * key_center, Vector2(size.x,key_center)],
					[Color.WHITE, Color.TRANSPARENT], 3 )
		elif !(key in Global.BLACK_KEYS):
			draw_polyline_colors(
					[Vector2.DOWN * key_center, Vector2(size.x,key_center)],
					[Color(1, 1, 1, 0.5), Color.TRANSPARENT], 2, true )
		if i == 25: continue
		if %DrawMicrotones.button_pressed && %PitchSnap.value != 1:
			for subtone in %PitchSnap.value:
				draw_line(Vector2(0,key_center + (key_height / %PitchSnap.value * subtone)),
						Vector2(size.x,key_center + (key_height / %PitchSnap.value * subtone)),
						Color(1,1,1,0.1) )

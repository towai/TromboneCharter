extends ScrollContainer


func _draw():
	var key_height := size.y / Global.NUM_KEYS
	var guideline_length = size.x / 3
	for i in Global.NUM_KEYS:
		var key : int = 13 - i
		if key in [13, -13]: continue
		var key_center : int = key_height * i + (key_height / 2)
		draw_line(Vector2.DOWN * key_center, Vector2(size.x,key_center),
				Color(1, 1, 1, 0.25) )
		if key in [ 12, 0, -12 ]:
			draw_polyline_colors(
					[Vector2.DOWN * key_center, Vector2(guideline_length,key_center)],
					[Color.WHITE, Color.TRANSPARENT], 3
			)
		elif !(key in Global.BLACK_KEYS):
			draw_polyline_colors(
					[Vector2.DOWN * key_center, Vector2(guideline_length,key_center)],
					[Color(1, 1, 1, 0.5), Color.TRANSPARENT], 2, true
			)
		if i == 25: continue
		if %DrawMicrotones.button_pressed && %PitchSnap.value != 1:
			for subtone in %PitchSnap.value:
				draw_line(Vector2(0,key_center + (key_height / %PitchSnap.value * subtone)),
						Vector2(size.x,key_center + (key_height / %PitchSnap.value * subtone)),
						Color(1,1,1,0.1) )




func _on_pitch_snap_value_changed(_value): queue_redraw()

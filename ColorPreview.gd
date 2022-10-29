extends Control


func _ready(): get_tree().current_scene.chart_loaded.connect(queue_redraw)


func _on_colors_changed(_color:Color):
	queue_redraw()
	for note in %Chart.get_children():
		if note is Note && note.visible: note.queue_redraw()

func _draw():
	draw_line(Vector2(0,16),Vector2(size.x,16), Color.BLACK, 24)
	draw_line(Vector2(0,16),Vector2(size.x,16), Color.WHITE, 20)
	draw_polyline_colors(
		[Vector2(0,16), Vector2(size.x * 0.25,16), Vector2(size.x * 0.75,16), Vector2(size.x,16)],
		[%StartColor.color, %StartColor.color, %EndColor.color, %EndColor.color],
		14
	)

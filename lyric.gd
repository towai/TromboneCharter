class_name Lyric
extends Control

var dragging : bool = false
var bar : float:
	set(value):
		bar = value
		if chart != null: position.x = chart.bar_to_x(bar)
var text : String:
	set(value):
		text = value
#		if line_edit != null: line_edit.text = value
@onready var line_edit : LineEdit = $LineEdit
@onready var editor = get_parent()
@onready var chart = editor.chart
@onready var chart_view = chart.get_parent()

var is_in_view : bool:
	get: return position.x + size.x >= chart.scroll_position \
			&& position.x + line_edit.size.x <= chart.scroll_end

func _ready():
	line_edit.text = text
	position.x = chart.bar_to_x(bar)


func _draw():
	draw_polyline_colors([Vector2.ZERO,Vector2(0, size.y)],
			[Color.TRANSPARENT,Color.PURPLE],2.0
			)


func _on_line_edit_text_changed(new_text): text = new_text


func _on_delete_button_pressed():
	queue_free()
	Global.working_tmb.lyrics = editor.package_lyrics()
	editor._refresh_lyrics()


func _process(_delta):
	if !dragging: return
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		return
	var pos = chart.get_local_mouse_position()
	bar = chart.to_snapped(pos).x


func _on_drag_handle_gui_input(event):
	event = event as InputEventMouseButton
	if event == null || event.button_index != MOUSE_BUTTON_LEFT || !event.pressed:
		return
	dragging = true

func scroll_to_lyric(offset : float = 1.0):
	offset = chart.bar_to_x(offset)
	chart_view.set_h_scroll(int(position.x - offset))
	chart.redraw_notes()
	chart.queue_redraw()

func _on_line_edit_gui_input(event:InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed:
			return
		var snap_value = 1.0 / Global.settings.timing_snap
		match event.keycode:
			KEY_UP:
				bar += snap_value
			KEY_DOWN:
				bar -= snap_value
			KEY_ENTER:
				var new_lyric : Lyric
				var new_bar : float
				if editor.enter_mode == 0:
					var notes = chart.get_children()
					notes.sort_custom(func(a, b): return a.position.x < b.position.x)
					var next_note : Note
					for note in notes:
						if not note is Note: continue
						if note.bar > bar:
							next_note = note
							break
					if next_note:
						new_bar = next_note.bar
				if !new_bar:
					new_bar = snapped(bar + snap_value, snap_value)
					if new_bar >= Global.working_tmb.endpoint:
						return
				for lyric in editor.get_children():
					if lyric.bar == new_bar:
						if !lyric.is_in_view:
							lyric.scroll_to_lyric()
						lyric.line_edit.grab_focus()
						return
				new_lyric = editor._add_lyric(new_bar, "")
				if !new_lyric.is_in_view:
					new_lyric.scroll_to_lyric()
				new_lyric.line_edit.grab_focus()

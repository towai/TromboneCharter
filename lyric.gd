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


func _process(delta):
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



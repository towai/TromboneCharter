extends Control

var dragging := false
var grabby_hand := load("res://paw_open.svg")
var grabbing_hand := load("res://paw_closed.svg")
@onready var chart = %Chart
signal bar_changed(bar, ref)
signal double_clicked(bar)


func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	bar_changed.connect(%Settings.section_handle_dragged)

func _on_mouse_entered():
	Input.set_custom_mouse_cursor(
		grabbing_hand if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else grabby_hand,
		Input.CURSOR_POINTING_HAND, Vector2(9, 3)
	)
func _on_mouse_exited():
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)


func update_pos(bar:float): position.x = %Chart.bar_to_x(bar) - 3


func _gui_input(event):
	var bar = chart.x_to_bar(event.position.x + position.x)
	if %Settings.snap_time && !(self == %PlayheadHandle && !dragging):
		bar = snapped(bar, chart.current_subdiv)
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		var rect := Rect2(Vector2.ZERO, size)
		Input.set_custom_mouse_cursor(grabbing_hand if event.pressed
				else grabby_hand if rect.has_point(event.position)
				else null, # thankfully hotspot does not take effect on system cursors
				Input.CURSOR_POINTING_HAND, Vector2(9, 3))
		dragging = event.pressed
		if event.pressed && self == %PlayheadHandle: chart.show_preview = false 
		if event.double_click: emit_signal("double_clicked",bar)
	elif event is InputEventMouseMotion && dragging:
		set_bar(bar)


func set_bar(bar:float): emit_signal("bar_changed",bar,self)

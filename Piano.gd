extends Control

const border_color = Color(0.5, 0.5, 0.5)
var collapsed := false
@onready var keyboard = $Keys


func _ready():
	keyboard.redraw_board.connect(queue_redraw)


func _draw():
	var key_height := size.y / Global.NUM_KEYS
	for i in Global.NUM_KEYS:
		var key : int = 13 - i
		var key_color = Color.BLACK if Global.BLACK_KEYS.has(key) else Color.WHITE
#		draw_rect(Rect2(0, key_height * i, size.x, key_height), key_color, false,2)
		draw_bordered_rect(Rect2(0, key_height * i, size.x, key_height), key_color, 2)
		if key == keyboard.current_key:
			draw_rect(Rect2(0, key_height * i, size.x, key_height),Color(1, 1, 0, 0.3))


func draw_bordered_rect(rect:Rect2, color:Color, width : int):
	draw_rect(rect, color)
	draw_rect(rect, border_color, false, width)


func _on_button_pressed():
	collapsed = !collapsed
	custom_minimum_size.x = 64 if collapsed else 144

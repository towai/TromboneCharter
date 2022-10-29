extends Control

const border_color = Color(0.5, 0.5, 0.5)
var collapsed := true
@onready var keyboard = $Keys


func _ready():
	keyboard.redraw_board.connect(queue_redraw)
	resize()


func _draw():
	var key_height := size.y / Global.NUM_KEYS
	for i in Global.NUM_KEYS:
		var key : int = 13 - i
		var key_color = Color.BLACK if Global.BLACK_KEYS.has(key) else Color.WHITE
		draw_bordered_rect(Rect2(0, key_height * i, size.x, key_height), key_color, 3)
		if key == keyboard.current_key:
			draw_rect(Rect2(0, key_height * i, size.x, key_height),Color(1, 1, 0, 0.3))


func draw_bordered_rect(rect:Rect2, color:Color, width:float):
	draw_rect(rect, color)
	draw_rect(rect, border_color, false, width)


func _on_button_pressed():
	collapsed = !collapsed
	resize()

func resize():
	custom_minimum_size.x = 64 if collapsed else 144
	$Button.text = "< >" if collapsed else "> <"

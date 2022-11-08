class_name Alert extends Node2D

@onready var label : Label = $Label
var tween : Tween


enum {
	LV_ERROR,
	LV_SUCCESS,
}

const colors := {
	LV_ERROR: Color(1, 0.3, 0.4),
	LV_SUCCESS: Color(0.3, 1, 0.6),
}


func _ready(): modulate = Color.TRANSPARENT


func alert(text:String, pos:Vector2, lvl:int, duration : float = 1.5):
	position = pos
	label.text = text
	label.add_theme_color_override("font_color", colors[lvl])
	
	if lvl == LV_ERROR: %Chord.play()
	
	modulate = Color.WHITE
	if tween: tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self,"modulate",Color.TRANSPARENT,duration)
	await(tween.finished)
	

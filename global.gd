extends Node

signal tmb_updated
const SEMITONE := 13.75
const TWELFTH_ROOT_2 : float = pow( 2, (1.0 / 12.0) )
static func pitch_to_scale(pitch:float) -> float: return pow(TWELFTH_ROOT_2,pitch)
# range goes from -13 to 13, c3 to c5
const BLACK_KEYS = [
	-11, -9, -6,
	-4, -2,
	1, 3,
	6, 8, 10,
	13
]
const NUM_KEYS = 27
@onready var working_tmb = TMBInfo.new()
var settings : Settings
enum {
	END_IS_TOUCHING,
	START_IS_TOUCHING,
}


func overlaps_any_note(time:float, exclude : Array = []) -> bool:
	var bar : float
	var note_end : float
	for note in working_tmb.notes:
		bar = note[TMBInfo.NOTE_BAR]
		if bar in exclude:
			continue
		note_end = bar + note[TMBInfo.NOTE_LENGTH]
		if time > bar && time < note_end: return true
	return false


func _ready(): pass


func _on_tmb_updated(value,key:String):
	if key == "title": key = "name" # fix collision
	working_tmb.set(key,value)
	if key in ["notes","lyrics"]: return # don't print
	emit_signal("tmb_updated")

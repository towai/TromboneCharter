extends Node

signal tmb_updated
const SEMITONE := 13.75
const TWELFTH_ROOT_2 : float = pow( 2, (1.0 / 12.0) )
# mainly significant for updates to Ogg loading
@onready var version := "%d.%d" % [Engine.get_version_info().major,
								 Engine.get_version_info().minor]
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
@onready var ffmpeg_worker = FFmpegWorker.new(self)
var settings : Settings
func beat_to_time(beat:float) -> float: return beat / (working_tmb.tempo / 60.0)
func time_to_beat(time:float) -> float: return time * (60.0 / working_tmb.tempo)

### Dew's variables ###

var UR := [0,0,0]
	# 0   => normal operation
	# 1   => undo last action
	# 2   => redo last action
	#  ,0 => run no calculations //with addition of UR[2], should never be reached beyond initial declarations
	#  ,1 => run A/D calculations only (one step forward/backward in history)
	#  ,2 => run any calculation (one to two steps forward/backward in history)
	#  ,, => available redos

var changes := [[Note,[]]] #The nested array which stores all created notes and their data at time of revision, traversed by Global.revision

var revision = 0 #number of revisions made to chart since TODO: program start (should be since LOAD; need to reset variables on load)

var d_note : Note #note to be removed by del/r-click/m-click
var deleted = false #was a note deleted? if so, run chart.filicide(note) upon reaching update_note_array(), then continue updating the note
var please_come_back = false #if I remove a child, the note will run _exit_tree(), so I have to redirect the program back to update_note_array()

var ratio := ["L","L","L","L","L"] #data injected into a_array on deletion, d_array on addition, and d_array first on move
var respects := ["F","F","F","F","F"] #data injected into a_array second on move
var loaded := ["3","3","3","3","3"] #TODO: data injected into d_array for loaded notes

var a_array := [] #list of added notes, separated by ratios and respects, denoting deletions and moves in the history, respectively
var d_array := [] #list of deleted notes, separated by ratios denoting added notes in the history
var active_stack := [] #list of notes in tmb.notes, ordered by which revision it was added/edited during

var next_note_data := [] #TODO: HELP MEEEE: Trying to register a note deleted by dragging endpoint over a neighbor.
### Dew's variables ###

# shamelessly copied from wikiped https://en.wikipedia.org/wiki/Smoothstep#Variations
static func smootherstep(from:float, to:float, x:float) -> float:
	x = clamp((x - from) / (to - from), 0.0, 1.0)
	return x * x * x * (x * (x * 6 - 15) + 10)


func overlaps_any_note(time:float, exclude : Array = []) -> bool:
	var bar : float
	var note_end : float
	for note in working_tmb.notes:
		bar = note[TMBInfo.NOTE_BAR]
		if bar in exclude:
			continue
		note_end = bar + note[TMBInfo.NOTE_LENGTH]
		var bar_difference = abs(time - bar)
		var end_difference = abs(time - note_end)
		
		if (time > bar && time < note_end) \
				&& !(bar_difference < 0.01 || end_difference < 0.01):
#			print("start: +/-%.9f -- end: +/-%.9f" % [bar_difference, end_difference])
			return true
	return false


func _ready(): pass


func _on_tmb_updated(value,key:String):
	if key == "title": key = "name" # fix collision
	working_tmb.set(key,value)
	emit_signal("tmb_updated")

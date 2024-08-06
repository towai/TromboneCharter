extends Node

signal tmb_updated
const SEMITONE := 13.75
const TWELFTH_ROOT_2 : float = pow( 2, (1.0 / 12.0) )
# mainly significant for updates to Ogg loading
@onready var version := "%d.%d" % [Engine.get_version_info().major,
								 Engine.get_version_info().minor]
# range goes from -13 to 13, b3 to c#5
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
func pitch_to_scale(pitch:float) -> float: return pow(TWELFTH_ROOT_2,pitch)
func beat_to_time(beat:float) -> float: return beat / (working_tmb.tempo / 60.0)
func time_to_beat(time:float) -> float: return time * (60.0 / working_tmb.tempo)

###Dew's globals###
var revision = -1 	#unedited chart
var actions = []	#0 = add, 1 = delete, 2 = dragged, 3 = paste
var changes = []	#current timeline of past and future revisions in order; see below
var revision_format = [
	"ADD: [*[reference, old bar value]*]",
	"DEL: [*[reference, old bar value]*]",
	"DRAGGED SET: [*[reference_1, [list of 1's old data], [list of 1's new data]]*(, *[reference_n, [list of n's old data], [list of n's new data]]*)]",
	"PASTED SET: [*[overwritten_reference_1(, overwritten_reference_n)]*, *[pasted_reference_1(, pasted_reference_n)]*] (array of overwrittens can be empty)"
]
var in_ur := false

var fresh := false  #only true for notes that have been ADDED BY HAND and is set to false as soon as the note is added to timeline.
func clear_future_edits(wipe := false):
	#input will be Global.revision unless loading a fresh chart (wipe = true), in which case argument passed is -1.
	#remember that Global.revision is negative-one indexed, where -1 is a blank array of changes.
	if revision < actions.size()-1 || wipe:
		if wipe: revision = -1
		actions = actions.slice(0,revision+1)
		changes = changes.slice(0,revision+1)
	return

var clearing_notes := false #Set to true during the load of a new chart, wherein the notes of the previous chart, if any, are discarded.
var pasting := false #Set to true during the pasting of a copied selection, during which all created note refs are concatenated into p_sel.
var copy_data : Array #Stores the latest copied note data to insert into the chart via chart.add_note(...) on paste.
var pasted_selection : Array #Container for pasted-note refs, inserted into Global.changes on paste.
var overwritten_selection : Array #Container for paste-overwritten note refs, inserted into Global.changes when pasted.
###Dew's globals###

# shamelessly copied from wikiped https://en.wikipedia.org/wiki/Smoothstep#Variations
func smootherstep(from:float, to:float, x:float) -> float:
	x = clamp((x - from) / (to - from), 0.0, 1.0)
	return pow(x,3) * (x * (x * 6 - 15) + 10)


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

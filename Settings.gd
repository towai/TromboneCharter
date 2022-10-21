class_name Settings
extends PanelContainer

var tmb : TMBInfo:
	get: return Global.working_tmb
@onready var title		= %SongInfo.get_node("Title")
@onready var short_name = %SongInfo.get_node("ShortTitle")
@onready var author 	= %SongInfo.get_node("Author")
@onready var genre		= %SongInfo.get_node("Genre")
@onready var desc		= %SongInfo.get_node("Description")
@onready var length  = %SongInfo2.get_node("Length")
@onready var tempo	 = %SongInfo2.get_node("Tempo")
@onready var timesig = %SongInfo2.get_node("TimeSig")
@onready var year	 = %SongInfo2.get_node("Year")
@onready var diff	 = %SongInfo2.get_node("Diff")
@onready var notespc = %SongInfo2.get_node("NoteSpacing")

var values : Array:
	get: return [
		title,short_name,author,genre,desc,
		length,tempo,timesig,year,diff,notespc
	]

enum {
	VIEW_CHART_INFO,
	VIEW_EDIT_SETTINGS,
}

var current_view : int = VIEW_CHART_INFO
var zoom : float = 1.0
var propagate_changes : bool:
	get: return %PropagateChanges.button_pressed

var use_custom_colors : bool:
	get: return %UseColors.button_pressed
	set(value):
		%UseColors.button_pressed = value
var start_color : Color:
	get: return %StartColor.color
	set(value): %StartColor.color = value
var end_color : Color:
	get: return %EndColor.color
	set(value): %EndColor.color = value

var section_start : float:
	get: return %SectionStart.value
var section_length : float:
	get: return %SectionLength.value
var section_target : float:
	get: return %CopyTarget.value

var pitch_snap : int:
	get: return %PitchSnap.value
var snap_pitch : bool:
	get: return %PitchSnapChk.button_pressed

var timing_snap : int:
	get: return %TimingSnap.value
var snap_time : bool:
	get: return %TimeSnapChk.button_pressed


func _ready():
	Global.settings = self
	get_tree().get_current_scene().chart_loaded.connect(_update_values)
	_update_view()


func _update_values():
	title.value = tmb.title
	short_name.value = tmb.shortName
	author.value = tmb.author
	genre.value = tmb.genre
	desc.text = tmb.description
	
	length.value = tmb.endpoint
	tempo.value = tmb.tempo
	timesig.value = tmb.timesig
	year.value = tmb.year
	diff.value = tmb.difficulty
	notespc.value = tmb.savednotespacing
	%CopyTarget.max_value = tmb.endpoint - 1


func _on_view_switcher_pressed():
	current_view ^= 1 # check out this fun ligature in fira code
	_update_view()


func _update_view():
	match current_view:
		VIEW_CHART_INFO: 
			%LyricsTools.hide()
			%EditSettings.hide()
			%SectionSelection.hide()
			%ChartInfo.show()
			%ViewSwitcher.text = "Editor Settings"
		VIEW_EDIT_SETTINGS:
			%ChartInfo.hide()
			%LyricsTools.show()
			%EditSettings.show()
			%SectionSelection.show()
			%ViewSwitcher.text = "Chart Info"
		_: print("oh no!! what the fuck. settings view set to a wrong value")


func _on_zoom_level_changed(value:float):
	%ZoomLevel.tooltip_text = str(value)
	%Chart._on_tmb_updated()
	var zoom_change = value / zoom
	%ChartView.scroll_horizontal *= zoom_change
	zoom = value
func _on_zoom_reset_pressed(): %ZoomLevel.value = 1


func _on_section_start_value_changed(value):
	%SectionLength.max_value = max(1,tmb.endpoint - value)
	%Chart.queue_redraw()
func _on_section_length_value_changed(value): %Chart.queue_redraw()

func _on_copy_target_value_changed(value): %Chart.queue_redraw()

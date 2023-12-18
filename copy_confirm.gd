extends AcceptDialog

@onready var main : Node = get_parent()
@onready var template = dialog_text
var target: float
var data: Dictionary

func set_values(_target: float, _data: Dictionary):
	target = _target
	data = _data
	var overwrite_notes = main.tmb.find_all_notes_in_section(target,data.length)
	var to_overwrite = ("\nThis will overwrite %s notes!\n" % overwrite_notes.size()) if overwrite_notes else ""
	dialog_text = template % [data.notes.size(), to_overwrite]

func _on_copy_confirmed():
	var notes = data.notes
	if notes.is_empty():
		print("copy section empy")
		return
	
	main.tmb.clear_section(target,data.length)
	for note in notes:
		note[TMBInfo.NOTE_BAR] += target
		main.tmb.notes.append(note)
	main.tmb.notes.sort_custom(func(a,b): return a[TMBInfo.NOTE_BAR] < b[TMBInfo.NOTE_BAR])
	main.emit_signal("chart_loaded")
	%Alert.alert("Inserted %s notes from clipboard" % notes.size(), Vector2(%ChartView.global_position.x, 10),
				Alert.LV_SUCCESS)

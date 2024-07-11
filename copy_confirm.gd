extends AcceptDialog

@onready var main : Node = get_parent()
@onready var template = dialog_text
var target: float
var data: Dictionary

func set_values(_target: float, _data: Dictionary):
	target = _target
	data = _data
	var overwrite_notes = main.tmb.find_all_notes_in_section(target,data.length)
	print(overwrite_notes)
	var to_overwrite = ("\nThis will overwrite %s notes!\n" % overwrite_notes.size()) if overwrite_notes else ""
	dialog_text = template % [data.notes.size(), to_overwrite]

func _on_copy_confirmed():
	var notes = data.notes
	if notes.is_empty():
		print("copy section empy AFTER CONFIRMATION????")
		return
	#Dew save overwritten note data as array of note references by filtering the Note objects by bar
	Global.overwritten_selection = %Chart.get_children().filter(func(child) : if !(child is Note):
		return false
		else: return child.bar >= target && child.bar < target + data.length
		)
	
	%Chart.clearing_notes = true
	print("THESE SHOULD GO AWAY: ",Global.overwritten_selection)
	for note in Global.overwritten_selection:
		print(%Chart.clearing_notes)
		print(note.bar)
		%Chart.remove_child(note) #simply hides a select note rather than erasing it from the tree
	%Chart.clearing_notes = false
	
	Global.pasting = true
	Global.fresh = true
	Global.copied_selection = []
	for note in Global.copy_data:
		print("sup")
		print(note[0])
		%Chart.add_note(false,note[0]+target,note[1],note[2],note[3])
	Global.pasting = false
	Global.fresh = false
	
	print(Global.copied_selection)
	print(Global.overwritten_selection)
	Global.clear_future_edits()
	Global.actions.append(3)
	Global.changes.append([Global.overwritten_selection,Global.copied_selection]) #copie
	Global.revision += 1
	#print("terminal revision: ",Global.revision)
	
	for note in notes:
		note[TMBInfo.NOTE_BAR] += target
		main.tmb.notes.append(note)
	main.tmb.notes.sort_custom(func(a,b): return a[TMBInfo.NOTE_BAR] < b[TMBInfo.NOTE_BAR])
	#main.emit_signal("chart_loaded")
	Global.settings.section_length = 0
	%Alert.alert("Inserted %s notes from clipboard" % notes.size(), Vector2(%ChartView.global_position.x, 10),
				Alert.LV_SUCCESS)
	
	%Chart.update_note_array()

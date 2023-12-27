class_name TMBInfo
extends Node

# { bar, length, start_pitch, delta_pitch, end_pitch } all floats
enum {
	NOTE_BAR,
	NOTE_LENGTH,
	NOTE_PITCH_START,
	NOTE_PITCH_DELTA,
	NOTE_PITCH_END
}
enum LoadResult {
	SUCCESS,
	TMB_INVALID,
	FILE_ACCESS_ERROR,
}
var notes := []
# { bar:float, lyric:string }
var lyrics := []
var improv_zones := []
var bgdata := []
var title		:= ""
var shortName	:= ""
var author		:= ""
var genre		:= ""
var description := ""
var trackRef    := ""
var year		: int = 1999
var tempo		: float = 120
var endpoint	: int = 4
var timesig 	: int = 4
var difficulty	: int = 5
var savednotespacing : int = 120


func has_note_touching_endpoint() -> bool:
	if notes.is_empty(): return false
	var last_note = notes[-1]
	return (last_note[NOTE_BAR] + last_note[NOTE_LENGTH] == endpoint)


static func load_result_string(result:int) -> String:
	match result:
		LoadResult.SUCCESS: return "Loaded successfully"
		LoadResult.TMB_INVALID: return "Invalid TMB"
		LoadResult.FILE_ACCESS_ERROR: return "File access error (see console)"
		_: return "Unknown error %d" % result


func find_all_notes_in_section(start:float,length:float) -> Array:
	var result := []
	var note_array = notes.duplicate(true)
	var is_in_section := func(bar:float) -> bool:
		return (bar > start && bar < start + length)
	for note in note_array:
		var bar = note[NOTE_BAR]
		var end = bar + note[NOTE_LENGTH]
		if !is_in_section.call(bar) && !is_in_section.call(end): continue
		note[NOTE_BAR] -= start
		result.append(note)
	return result


func clear_section(start:float,length:float):
	var is_in_section := func(bar:float) -> bool:
		return (bar > start && bar < start + length)
	print("Clear section %d - %d" % [start,length + start])
	var note_array = notes.duplicate(true)
	
	var any_notes_left : bool = true
	while any_notes_left:
		for note in note_array:
			var bar = note[NOTE_BAR]
			var end = bar + note[NOTE_LENGTH]
			print("%d notes left" % note_array.size())
			if is_in_section.call(bar) || is_in_section.call(end):
				print("Erase note @ %.3f" % bar)
				note_array.erase(note)
				if note_array.is_empty(): any_notes_left = false
				break # start from the beginning of the array
			
			if note == note_array.back(): any_notes_left = false
	notes = note_array


func load_from_file(filename:String) -> int:
	var f = FileAccess.open(filename,FileAccess.READ)
	var err = f.get_open_error()
	if err:
		print(error_string(err))
		return LoadResult.FILE_ACCESS_ERROR
	
	var j = JSON.new()
	err = j.parse(f.get_as_text())
	if err:
		print("%s\t| line %d\t| %s" % [
				error_string(err), j.get_error_line() + 1, j.get_error_message()
		])
		return LoadResult.TMB_INVALID
	
	var data = j.data
	if typeof(data) != TYPE_DICTIONARY:
		print("JSON got back object of type %s" % typeof(data))
		return LoadResult.TMB_INVALID
	
	notes		= data.notes as Array[Dictionary]
	lyrics		= data.lyrics as Array[Dictionary]
	
	title		= data.name
	shortName	= data.shortName
	author		= data.author
	genre		= data.genre
	description = data.description
	trackRef    = data.trackRef
	
	year		= data.year
	tempo		= data.tempo
	endpoint	= data.endpoint
	timesig 	= data.timesig
	difficulty	= data.difficulty
	savednotespacing = data.savednotespacing

	if data.has('bgdata'):
		bgdata = data.bgdata
	else:
		bgdata = []
	if data.has('improv_zones') && data['improv_zones'] is Array:
		improv_zones = data.improv_zones
	else:
		improv_zones = []
	
	if data.has("note_color_start"):
		Global.settings.use_custom_colors = true
		Global.settings.start_color = Color(
			data["note_color_start"][0],
			data["note_color_start"][1],
			data["note_color_start"][2]
		)
		Global.settings.end_color = Color(
			data["note_color_end"][0],
			data["note_color_end"][1],
			data["note_color_end"][2]
		)
	
	return LoadResult.SUCCESS


func save_to_file(filename : String) -> int:
	print("try save tmb to %s" % filename)
	var f = FileAccess.open(filename,FileAccess.WRITE)
	if f == null:
		var err = FileAccess.get_open_error()
		print(error_string(err))
		return err
	
	var dict := to_dict()
	f.store_string(JSON.stringify(dict))
	print("finished saving")
	return OK

func to_dict() -> Dictionary:
	var dict := {}
	
	for value in Global.settings.values:
		if !(value is TextField || value is NumField): continue
		dict[value.json_key] = value.value
	
	for note in notes: if (note[NOTE_BAR] + note[NOTE_LENGTH]) > endpoint: notes.erase(note)
	for lyric in lyrics: if lyric.bar > endpoint: lyrics.erase(lyric)
	dict["description"] = description
	dict["notes"] = notes
	dict["lyrics"] = lyrics
	dict["improv_zones"] = improv_zones
	dict["bgdata"] = bgdata
	dict["UNK1"] = 0
	
	if Global.settings.use_custom_colors:
		var start_color =  Global.settings.start_color
		var end_color =  Global.settings.end_color
		dict["note_color_start"] = [
			start_color[0],
			start_color[1],
			start_color[2],
		]
		dict["note_color_end"] = [
			end_color[0],
			end_color[1],
			end_color[2],
		]
	
	return dict

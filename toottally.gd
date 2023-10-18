extends Button

@onready var main : Control = get_node("/root/Main")
@onready var diff_calc : Window = main.get_node("DiffCalc")
@onready var calc_contents : RichTextLabel = diff_calc.get_node("PanelContainer/VBoxContainer/PanelContainer/CalcInfo")

var template = """[font_size=25]TMB Information:[/font_size]
[font_size=20]Track Name: [b]{name}[/b][/font_size]

Note Hash: [b]{note_hash}[/b]
File Hash: [b]{file_hash}[/b]
Estimated Difficulty: [b]{difficulty}[/b]
Tap Rating: [b]{tap}[/b]
Aim Rating: [b]{aim}[/b]
Acc Rating: [b]{acc}[/b]
TT at 60% Maximum Percentage: [b]{base_tt}[/b]

[font_size=25]Rating Criteria Checks[/font_size] [url=\"https://toottally.com/ratingchecks/\"](?)[/url]"""
var table_header = "
[cell border=#fff padding=4,2,4,0][b]Type[/b][/cell]\
[cell border=#fff padding=4,2,4,0][b]Note ID[/b][/cell]\
[cell border=#fff padding=4,2,4,0][b]Timing[/b][/cell]\
[cell border=#fff padding=4,2,4,0][b]Value[/b][/cell][cell][/cell]"


func _on_toottally_request_completed(_result, response_code, _headers, body):
	table_header = "
[cell border=#fff padding=4,2,4,0][b]Type[/b][/cell]\
[cell border=#fff padding=4,2,4,0][b]Note ID[/b][/cell]\
[cell border=#fff padding=4,2,4,0][b]Timing[/b][/cell]\
[cell border=#fff padding=4,2,4,0][b]Value[/b][/cell][cell][/cell]"
	var info_template = """[i][font_size=24][b]{name}[/b][/font_size]\
[font_size=18] — TootTally Info[/font_size][/i]
[font_size=16]Note Hash: [b][url={"hash": "{note_hash}"}]\
[hint={note_hash}\n(Click to copy)]{short_note_hash}[/hint]\
[/url][/b]\t\t\
File Hash: [b][url={"hash": "{file_hash}"}]\
[hint={file_hash}\n(Click to copy)]{short_file_hash}[/hint]\
[/url][/b]
[/font_size]"""
	var diff_template = """
[table=3]
[cell][font_size=26]D[font_size=20]ifficulty[/font_size]⠀[/font_size][b]%s[/b][/cell]
[cell][/cell]
[cell][font_size=26]B[font_size=20]ase TT[/font_size] [/font_size][b]%s[/b][/cell]
[cell][left][font_size=16]T[/font_size]ap Rating\n[b]%s[/b][/left][/cell]
[cell][font_size=16]A[/font_size]im Rating\n[b]%s[/b][/cell]
[cell][right][font_size=16]A[/font_size]cc. Rating\n[b]%s[/b][/right][/cell]
[/table]
"""
	var rating_checks_header = """
[font_size=25]Rating Criteria Checks[/font_size] \
[hint="View explanation on TootTally website"]\
[url=\"https://toottally.com/ratingchecks/\"][font_size=16](?)[/font_size][/url][/hint]"""
	if response_code != HTTPClient.ResponseCode.RESPONSE_OK:
		push_error("An error occured while submitting to TootTally: Response Code %s" % response_code)
		%Alert.alert("Couldn't submit! Code %s" % response_code,
				Vector2(global_position.x + 20, global_position.y - 20),
				Alert.LV_ERROR, 2)
		disabled = false
		return
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var data = json.get_data()
	if data.get('error'):
		calc_contents.text = "[center]\n\n\n[font_size=25]Failed to process chart![/font_size]\n\n{error}".format(data)
		main.show_popup(diff_calc)
		disabled = false
		return
	data["short_note_hash"] = data['note_hash'].left(6) + ' ... ' + data['note_hash'].right(6)
	data["short_file_hash"] = data['file_hash'].left(6) + ' ... ' + data['file_hash'].right(6)
	var big_whole_part = func(value:float,size:int=20,places:int=4) -> String:
		var format_string : String = "[font_size=%s]%d[/font_size]" % [size,value]
		format_string += str(value).substr(str(value).find('.'),places + 1)
		return format_string
	calc_contents.text = info_template.format(data)
	calc_contents.text += (diff_template % [
			big_whole_part.call(data['difficulty']),
			big_whole_part.call(data['base_tt']),
			big_whole_part.call(data['tap']),
			big_whole_part.call(data['aim']),
			big_whole_part.call(data['acc']),
		])
	
	calc_contents.text += rating_checks_header
	var error_count = 0
	var error_table = ""
	var warn_count = 0
	var warn_table = ""
	for err in data["chart_errors"]:
		# a bit ugly but the line is stupidly long otherwise lol
		var row = "
[cell border=#fffa padding=4,2,4,0]{error_type}[/cell]\
[cell border=#fff7 padding=4,2,4,0][right]{note_id}[/right][/cell]\
[cell border=#fff7 padding=4,2,4,0]%.5f[/cell]\
[cell border=#fff7 padding=4,2,4,0]%.5f[/cell]\
[cell border=#fff8 padding=4,2,4,0][url={\"note\": {note_id}}]Jump to Note[/url][/cell]\
				".format(err) % [err['timing'],err['value']]
		match err["error_level"]:
			"Error":
				error_count += 1
				error_table += row
			"Warning":
				warn_count += 1
				warn_table += row
	if error_count > 0:
		calc_contents.text += \
				"\n\n[color=#DE7576]{0} error/s found![/color]\n\n[indent][table=5]{1}{2}\n[/table][/indent]".format(
				[error_count, table_header, error_table]
		)
	else:
		calc_contents.text += "\n0 error/s found!"
	if warn_count > 0:
		calc_contents.text += \
				"\n\n[color=#F5D64C]{0} warning/s found![/color]\n\n[indent][table=5]{1}{2}\n[/table][/indent]".format(
				[warn_count, table_header, warn_table]
		)
	else:
		calc_contents.text += "\n0 warnings/s found!"
	if error_count == 0 and warn_count == 0:
		calc_contents.text += "\n\n[center][rainbow sat=0.6][wave]Maximum Boner Levels Achieved"
	%Chart.assign_tt_note_ids()
	main.show_popup(diff_calc)
	disabled = false


func _on_toottally_upload_pressed():
	disabled = true
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_toottally_request_completed)
	var tmb_data = main.tmb.to_dict()
	var errors = []
	for key in tmb_data.keys():
		if tmb_data[key] is String and not tmb_data[key]:
			errors.append("Field [code]%s[/code] is empty!" % key)
		elif tmb_data[key] is int and key not in ["UNK1", "year"] and tmb_data[key] < 1:
			errors.append("Invaid value for [code]%s[/code]!" % key)
		elif key == "notes" and not tmb_data[key]:
			errors.append("There are no notes to process!")
	if errors:
		calc_contents.text = "[center]\n\n\n[font_size=25]Failed to process chart![/font_size]\n\n"
		for e in errors:
			calc_contents.text += "\n" + e
		main.show_popup(diff_calc)
		disabled = false
		return
	var chart_data = JSON.stringify(tmb_data)
	var dict = {"tmb": chart_data, "skip_save": true}
	var body = JSON.stringify(dict)
	var error = http_request.request(
		"https://toottally.com/api/upload/", 
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occured while submitting to TootTally: " + error)
		%Alert.alert("Couldn't submit! " + error,
				Vector2(global_position.x + 20, global_position.y - 20),
				Alert.LV_ERROR, 2)

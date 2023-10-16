extends Button

@onready var main : Control = get_node("/root/Main")
@onready var diff_calc : Window = main.get_node("DiffCalc")
@onready var calc_contents : RichTextLabel = diff_calc.get_node("PanelContainer/VBoxContainer/PanelContainer/CalcInfo")

var template = """[font_size=25]TMB Information[/font_size]

Track Name: [b]{name}[/b]
Note Hash: [b]{note_hash}[/b]
File Hash: [b]{file_hash}[/b]
Estimated Difficulty: [b]{difficulty}[/b]
Tap Rating: [b]{tap}[/b]
Aim Rating: [b]{aim}[/b]
Acc Rating: [b]{acc}[/b]
TT at 60% Maximum Percentage: [b]{base_tt}[/b]

[font_size=25]Rating Criteria Checks[/font_size]"""
var table_header = "[cell][b]Type[/b][/cell][cell][b]Note ID[/b][/cell][cell][b]Timing[/b][/cell][cell][b]Value[/b][/cell][cell][/cell]"


func _on_toottally_request_completed(_result, response_code, _headers, body):
	if response_code != HTTPClient.ResponseCode.RESPONSE_OK:
		push_error("An error occured while submitting to TootTally: Response Code %s" % response_code)
		%Alert.alert("Couldn't submit! Code %s" % response_code,
				Vector2(global_position.x - 30, global_position.y - 20),
				Alert.LV_ERROR, 2)
		disabled = false
		return
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var data = json.get_data()
	if data.get('error'):
		calc_contents.text = "[center]\n\n\n[font_size=25]Failed to process chart![/fontsize]\n\n{error}".format(data)
		disabled = false
		return
	calc_contents.text = template.format(data)
	var error_count = 0
	var error_table = ""
	var warn_count = 0
	var warn_table = ""
	for err in data["chart_errors"]:
		# a bit ugly but the line is stupidly long otherwise lol
		var cell = "\n[cell]{error_type}[/cell][cell]{note_id}[/cell][cell]{timing}[/cell]".format(err) \
			+ "[cell]{value}[/cell][cell][url={\"note\": {note_id}}]Jump to Note[/url][/cell]".format(err)
		match err["error_level"]:
			"Error":
				error_count += 1
				error_table += cell
			"Warning":
				warn_count += 1
				warn_table += cell
	if error_count > 0:
		calc_contents.text += "\n\n[color=#DE7576]{0} error/s found![/color]\n\n[table=5]{1}{2}\n[/table]".format(
			[error_count, table_header, error_table]
		)
	else:
		calc_contents.text += "\n\n0 error/s found!"
	if warn_count > 0:
		calc_contents.text += "\n\n[color=#F5D64C]{0} warning/s found![/color]\n\n[table=5]{1}{2}\n[/table]".format(
			[warn_count, table_header, warn_table]
		)
	else:
		calc_contents.text += "\n\n0 warnings/s found!"
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
	# TODO: Handle trackRef better
	var tmb_data = main.tmb.to_dict()
	if not tmb_data.trackRef:
		tmb_data.trackRef = "TromboneCharterProject"
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
				Vector2(global_position.x - 30, global_position.y - 20),
				Alert.LV_ERROR, 2)

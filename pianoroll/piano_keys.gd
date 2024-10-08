extends VBoxContainer

@onready var player : AudioStreamPlayer = %TrombPlayer
var current_key : int = 69
@warning_ignore("unused_signal")
signal redraw_board

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in Global.NUM_KEYS:
		var key = BaseButton.new()
		key.size_flags_horizontal = SIZE_EXPAND_FILL
		key.size_flags_vertical = SIZE_EXPAND_FILL
		add_child(key)
		key.button_down.connect(_on_key_down.bind(13 - i))
		key.button_up.connect(_on_key_up)
		key.mouse_entered.connect(_on_key_mouseover.bind(13 - i))
		key.mouse_exited.connect(_on_key_mouse_exit.bind(13 - i))

func _on_key_down(key:int) -> void:
	player.pitch_scale = Global.pitch_to_scale(key)
	player.play()
func _on_key_up() -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): player.stop()

func _on_key_mouseover(key:int) -> void:
	current_key = key
	redraw_board.emit()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		player.pitch_scale = Global.pitch_to_scale(key)
func _on_key_mouse_exit(key:int) -> void:
	if current_key != key:
		print("Mouse exited %d but only after entering %d -- do nothing" % [key, current_key])
		return
	current_key = 69
	redraw_board.emit()

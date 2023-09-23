class_name FFmpegWorker
extends Object

# do we even need this?
var owner : Node
func _init(caller:Node):
	owner = caller 
	var output := []
	var err = OS.execute("ffmpeg",["-version"],output)
	print(("FFmpeg | %d " % err) + error_string(err))
	if err: return
	print(output)


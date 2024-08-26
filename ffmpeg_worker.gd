class_name FFmpegWorker
extends Object

var ffmpeg_exists := false
var ffmpeg_path := "ffmpeg"


func _init() -> void: ffmpeg_exists = does_ffmpeg_exist()


func does_ffmpeg_exist() -> bool:
	var output : Array[String] = []
	var err = OS.execute(ffmpeg_path,["-version"],output)
	if err and OS.get_name() == "macOS":
		# OS.execute() on macOS cannot load custom PATH variables
		ffmpeg_path = "/opt/homebrew/bin/ffmpeg"
		err = OS.execute(ffmpeg_path,["-version"],output)
	print(("FFmpeg check: %d " % err) + error_string(err) + "(-1 means ffmpeg not found!)")
	if err: return false
	print(output[0].split("\r\n")[0].substr(0,21))
	return true


func draw_wavechunk(start:float,end:float,dir:String,hi_res:bool,type:int=0,idx:int=0) -> int:
	var wavechunkpath := '%s/wav%d.png' % [dir,idx]
	var chunkwidth := int((end - start) * 100) * (2 if hi_res else 1)
	var command : PackedStringArray = [ "-hide_banner", "-ss", "%.3f" % start, "-to", "%.3f" % end,
										"-y", "-i", "%s" % (dir + "/song.ogg"),"-lavfi"]
	if type == 1:
		command += PackedStringArray(["showspectrumpic=s=%dx442:legend=false" % chunkwidth,wavechunkpath])
	else:
		command += PackedStringArray(["showwavespic=s=%dx442:colors=ff8000|0080ff" % chunkwidth,wavechunkpath])
	var out := []
	
	var err = OS.execute(ffmpeg_path,command,out,true)
	if err:
		print(out[0])
	return err

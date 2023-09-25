class_name FFmpegWorker
extends Object

var owner : Node
var ffmpeg_exists := false
#signal ffmpeg_checked(what:bool)


func _init(caller:Node):
	owner = caller
	ffmpeg_exists = does_ffmpeg_exist()


static func does_ffmpeg_exist() -> bool:
	var output : Array[String] = []
	var err = OS.execute("ffmpeg",["-version"],output)
	print(("FFmpeg check: %d " % err) + error_string(err) + "(-1 means ffmpeg not found!)")
	if err: return false
	print(output[0].split("\r\n")[0].substr(0,21))
	return true


static func try_to_convert_ogg(path:String) -> int:
	var dir = path.substr(0,path.rfind("/"))
	if dir == path: dir = path.substr(0,path.rfind("\\"))
	var args = PackedStringArray([
			"-i",
			'%s' % path,
			'%s' % (dir + "/song.wav")
			])
	
	var output = []
	var err = OS.execute("ffmpeg",args,output,true,true)
	print(output[0].c_unescape())
	print(output.size())
	return err


func draw_wavechunk(start:float,end:float,dir:String,hi_res:bool,idx:int=0):
	var wavechunkpath := '%s/wav%d.png' % [dir,idx]
	var chunkwidth := int((end - start) * 100) * (2 if hi_res else 1)
	var command : PackedStringArray = [ "-ss", '%.3f' % start, "-to", '%.3f' % end,
					"-i", '%s' % (dir + '/song.wav'),
					'-lavfi',
					'showwavespic=s=%dx512:colors=ff8000|0080ff' % chunkwidth,
					wavechunkpath
				]
	var out := []
	
	var err = OS.execute("ffmpeg",command,out)
	print(out[0])
	return err

extends Node

class_name HeightMapLoader

signal height_loaded(x: int, y: int, image: Image)
signal height_failed(x: int, y: int, reason: String)

var zoom_level: int = 15
var user_agent: String = "GodotDroneSim/1.0"
var active_requests = {} # { "x_y": HTTPRequest }
var image_cache = {}   # { "x_y": Image }

func _ready():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("height_cache"):
		dir.make_dir("height_cache")

func request_tile(x: int, y: int):
	var key = "%d_%d" % [x, y]
	
	# 1. Check Memory Cache
	if image_cache.has(key):
		height_loaded.emit(x, y, image_cache[key])
		return
	
	# 2. Check Disk Cache
	var path_png = "user://height_cache/%s.png" % key
	if FileAccess.file_exists(path_png):
		var img = Image.new()
		if img.load(path_png) == OK:
			image_cache[key] = img
			height_loaded.emit(x, y, img)
			return
	
	# 3. Check Pending
	if active_requests.has(key):
		return
	
	# 4. Start Download (Terrarium tiles)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(x, y, http))
	active_requests[key] = http
	
	var url = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png" % [zoom_level, x, y]
	var err = http.request(url, ["User-Agent: " + user_agent])
	if err != OK:
		height_failed.emit(x, y, "HTTPRequest start failed: %d" % err)

func _on_request_completed(result, response_code, headers, body, x, y, http):
	var key = "%d_%d" % [x, y]
	active_requests.erase(key)
	http.queue_free()
	
	if response_code != 200:
		height_failed.emit(x, y, "HTTP %d" % response_code)
		return
	
	var img = Image.new()
	var err = img.load_png_from_buffer(body)
	if err != OK:
		height_failed.emit(x, y, "PNG decode failed: %d" % err)
		return
	
	var file_path = "user://height_cache/%s.png" % key
	img.save_png(file_path)
	image_cache[key] = img
	height_loaded.emit(x, y, img)

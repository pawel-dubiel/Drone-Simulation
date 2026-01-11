extends Node

class_name MapLoader

# Service to fetch satellite tiles on demand
# Uses "Slippy Map" tile coordinates (x, y, z)

signal tile_loaded(x: int, y: int, texture: Texture2D)

var zoom_level: int = 16
var user_agent: String = "GodotDroneSim/1.0"
var active_requests = {} # { "x_y": HTTPRequest }
var texture_cache = {}   # { "x_y": Texture2D }

func _ready():
	print("MapLoader: INITIALIZING ESRI SATELLITE MODE")
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("cache"):
		dir.make_dir("cache")
	
func request_tile(x: int, y: int):
	var key = "%d_%d" % [x, y]
	
	# 1. Check Memory Cache
	if texture_cache.has(key):
		tile_loaded.emit(x, y, texture_cache[key])
		return
	
	# 2. Check Disk Cache
	# Check JPG
	var path_jpg = "user://cache/%s.jpg" % key
	if FileAccess.file_exists(path_jpg):
		var img = Image.new()
		if img.load(path_jpg) == OK:
			var tex = ImageTexture.create_from_image(img)
			texture_cache[key] = tex
			tile_loaded.emit(x, y, tex)
			return
			
	# Check PNG
	var path_png = "user://cache/%s.png" % key
	if FileAccess.file_exists(path_png):
		var img = Image.new()
		if img.load(path_png) == OK:
			var tex = ImageTexture.create_from_image(img)
			texture_cache[key] = tex
			tile_loaded.emit(x, y, tex)
			return
	
	# 3. Check Pending
	if active_requests.has(key):
		return # Already downloading
	
	# 4. Start Download
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(x, y, http))
	active_requests[key] = http
	
	# Google Satellite (no labels) (Unofficial)
	var url = "https://mt1.google.com/vt/lyrs=s&x=%d&y=%d&z=%d&scale=2" % [x, y, zoom_level]
	print("MapLoader: Requesting ", url)
	
	var err = http.request(url, ["User-Agent: " + user_agent])
	if err != OK:
		print("MapLoader: HTTP Request Failed to Start: ", err)

func _on_request_completed(result, response_code, headers, body, x, y, http):
	var key = "%d_%d" % [x, y]
	active_requests.erase(key)
	http.queue_free()
	
	print("MapLoader: Response ", response_code, " for tile ", x, ",", y, " Body Size: ", body.size())
	
	if response_code == 200:
		var img = Image.new()
		
		# Try JPG first (most common for Satellite)
		var err = img.load_jpg_from_buffer(body)
		var ext = "jpg"
		
		# If JPG failed, try PNG
		if err != OK:
			err = img.load_png_from_buffer(body)
			ext = "png"
		
		if err == OK:
			var mip_err = img.generate_mipmaps()
			if mip_err != OK:
				push_error("MapLoader: Failed to generate mipmaps for tile %d,%d (err=%d)" % [x, y, mip_err])
				return
			# Save to Disk with correct extension
			var file_path = "user://cache/%s.%s" % [key, ext]
			if ext == "jpg": img.save_jpg(file_path)
			else: img.save_png(file_path)
			
			var tex = ImageTexture.create_from_image(img)
			texture_cache[key] = tex
			tile_loaded.emit(x, y, tex)
		else:
			print("MapLoader: Failed to decode image for tile ", x, ",", y, " (Tried JPG and PNG)")
	else:
		print("MapLoader: HTTP Error for tile ", x, ",", y, " Code: ", response_code)

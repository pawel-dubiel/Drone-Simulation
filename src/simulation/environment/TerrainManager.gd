extends Node3D

# Infinite Satellite Terrain Manager
# Aligns chunks to Real-World Web Mercator Tiles

@export var target_path: NodePath
@export var render_distance: int = 2 # Radius in chunks

# Paris Start Point (Eiffel Tower)
@export var start_lat: float = 48.8584
@export var start_lon: float = 2.2945

var target: Node3D
var active_chunks = {} # {Vector2i: TerrainChunk}
var map_loader: MapLoader
var height_loader: HeightMapLoader
var terrain_material: ShaderMaterial
var height_reference_ready: bool = false
var height_reference_meters: float = 0.0
var height_reference_tile: Vector2i
var height_reference_subtile: Vector2i
var height_reference_subtile_div: int

# Tile Logic
var zoom: int = 16
var height_zoom: int = 15
var tile_size_meters: float = 0.0 # Calculated at runtime
var origin_tile: Vector2i # The tile coordinate that corresponds to World(0,0,0)

func _ready():
	if target_path:
		target = get_node(target_path)
	
	map_loader = $MapLoader
	height_loader = $HeightMapLoader
	if !height_loader:
		push_error("TerrainManager: Missing HeightMapLoader node")
		return
	height_loader.zoom_level = height_zoom
	
	# 1. Calculate Tile Grid Properties
	var n = pow(2.0, zoom)
	var lat_rad = deg_to_rad(start_lat)
	
	# Tile X/Y for Start Location
	var xtile = int(floor(n * ((start_lon + 180.0) / 360.0)))
	var ytile = int(floor(n * (1.0 - (log(tan(lat_rad) + 1.0/cos(lat_rad)) / PI)) / 2.0))
	origin_tile = Vector2i(xtile, ytile)
	
	var height_diff = zoom - height_zoom
	height_reference_subtile_div = 1 << height_diff
	height_reference_tile = Vector2i(origin_tile.x >> height_diff, origin_tile.y >> height_diff)
	height_reference_subtile = Vector2i(origin_tile.x & (height_reference_subtile_div - 1), origin_tile.y & (height_reference_subtile_div - 1))
	
	# Calculate meters per tile at this latitude
	# Earth Circumference * cos(lat) / 2^zoom
	var earth_circ = 40075016.686
	tile_size_meters = earth_circ * cos(lat_rad) / n
	print("Tile Size: ", tile_size_meters, "m")
	
	if zoom < height_zoom:
		push_error("TerrainManager: height_zoom must be <= zoom (height_zoom=%d, zoom=%d)" % [height_zoom, zoom])
		return
	
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://src/simulation/environment/Terrain.gdshader")
	terrain_material.set_shader_parameter("max_height", 20.0)
	terrain_material.set_shader_parameter("min_height", -5.0)
	
	# 4. Start Loop
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_chunks)
	add_child(timer)
	
	height_loader.height_loaded.connect(_on_height_reference_loaded)
	height_loader.height_failed.connect(_on_height_reference_failed)
	height_loader.request_tile(height_reference_tile.x, height_reference_tile.y)

func _update_chunks():
	if !target: return
	if !height_reference_ready: return
	
	var pos = target.global_position
	
	# Which "Game Grid" cell are we in? (Each cell is 1 map tile size)
	# Since World(0,0,0) is the Top-Left corner of 'origin_tile'
	# We need to offset carefully. 
	# Actually, simpler: origin_tile is at pos (0,0).
	# +X in game is East (+TileX). +Z in game is South (+TileY).
	
	var chunk_x = int(floor(pos.x / tile_size_meters))
	var chunk_z = int(floor(pos.z / tile_size_meters))
	var center_chunk = Vector2i(chunk_x, chunk_z)
	
	var needed = []
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			needed.append(center_chunk + Vector2i(x, z))
	
	# Remove old
	var to_remove = []
	for k in active_chunks:
		if not k in needed:
			to_remove.append(k)
	
	for k in to_remove:
		active_chunks[k].queue_free()
		active_chunks.erase(k)
	
	# Add new
	for k in needed:
		if not active_chunks.has(k):
			_spawn_chunk(k)

func _spawn_chunk(game_coord: Vector2i):
	# Calculate Real World Tile Coordinate
	var real_tile_x = origin_tile.x + game_coord.x
	var real_tile_y = origin_tile.y + game_coord.y
	
	var height_diff = zoom - height_zoom
	var height_tile_x = real_tile_x >> height_diff
	var height_tile_y = real_tile_y >> height_diff
	var height_sub_x = real_tile_x & ((1 << height_diff) - 1)
	var height_sub_y = real_tile_y & ((1 << height_diff) - 1)
	
	var chunk = TerrainChunk.new()
	add_child(chunk)
	
	# Set position in world
	chunk.position = Vector3(game_coord.x * tile_size_meters, 0, game_coord.y * tile_size_meters)
	
	chunk.setup(
		real_tile_x,
		real_tile_y,
		height_tile_x,
		height_tile_y,
		height_sub_x,
		height_sub_y,
		height_diff,
		tile_size_meters,
		1.0,
		height_reference_meters,
		terrain_material,
		map_loader,
		height_loader
	)
	active_chunks[game_coord] = chunk

func _on_height_reference_loaded(x, y, img: Image):
	if x != height_reference_tile.x or y != height_reference_tile.y:
		return
	if height_reference_ready:
		return
	
	var center_uv = (Vector2(height_reference_subtile) + Vector2(0.5, 0.5)) / float(height_reference_subtile_div)
	center_uv.x = clamp(center_uv.x, 0.0, 1.0)
	center_uv.y = clamp(center_uv.y, 0.0, 1.0)
	
	var px = int(round(center_uv.x * float(img.get_width() - 1)))
	var py = int(round(center_uv.y * float(img.get_height() - 1)))
	var c = img.get_pixel(px, py)
	height_reference_meters = _decode_terrarium_height(c)
	height_reference_ready = true
	height_loader.height_loaded.disconnect(_on_height_reference_loaded)
	height_loader.height_failed.disconnect(_on_height_reference_failed)
	_update_chunks()

func _on_height_reference_failed(x, y, reason: String):
	if x == height_reference_tile.x and y == height_reference_tile.y:
		push_error("TerrainManager: Failed to load reference height tile %d,%d (%s)" % [x, y, reason])

func _decode_terrarium_height(c: Color) -> float:
	var r = int(c.r * 255.0 + 0.5)
	var g = int(c.g * 255.0 + 0.5)
	var b = int(c.b * 255.0 + 0.5)
	return (float(r) * 256.0 + float(g) + float(b) / 256.0) - 32768.0

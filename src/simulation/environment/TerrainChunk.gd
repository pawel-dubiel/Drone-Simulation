extends StaticBody3D

class_name TerrainChunk

var chunk_coord: Vector2i # This is now the Global Tile Coordinate (X, Y)
var size_meters: float
var height_scale: float
var map_loader: MapLoader
var height_loader: HeightMapLoader
var height_tile: Vector2i
var height_subtile: Vector2i
var height_subtile_div: int
var height_reference_meters: float

var mesh_instance: MeshInstance3D

func setup(tile_x: int, tile_y: int, height_tile_x: int, height_tile_y: int, height_sub_x: int, height_sub_y: int, height_diff: int, size: float, h_scale: float, height_ref_meters: float, material: Material, loader: MapLoader, heightmap_loader: HeightMapLoader):
	chunk_coord = Vector2i(tile_x, tile_y)
	height_tile = Vector2i(height_tile_x, height_tile_y)
	height_subtile = Vector2i(height_sub_x, height_sub_y)
	height_subtile_div = 1 << height_diff
	size_meters = size
	height_scale = h_scale
	height_reference_meters = height_ref_meters
	map_loader = loader
	height_loader = heightmap_loader
	
	# Create Mesh
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	if material:
		# Create unique material for this chunk (so we can set its own texture)
		var my_mat = material.duplicate()
		# Set a "Loading" color (Magenta) to debug missing textures
		my_mat.set_shader_parameter("color_grass", Color(1, 0, 1))
		mesh_instance.material_override = my_mat
		
		if map_loader:
			map_loader.tile_loaded.connect(_on_tile_loaded)
			map_loader.request_tile(tile_x, tile_y)
	
	if !height_loader:
		push_error("TerrainChunk: Missing HeightMapLoader")
		queue_free()
		return
	
	height_loader.height_loaded.connect(_on_height_loaded)
	height_loader.height_failed.connect(_on_height_failed)
	height_loader.request_tile(height_tile.x, height_tile.y)

func _on_tile_loaded(x, y, tex):
	if x == chunk_coord.x and y == chunk_coord.y:
		print("TerrainChunk: Applying texture ", x, ",", y, " Size: ", tex.get_width(), "x", tex.get_height())
		var mat = mesh_instance.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("map_texture", tex)
			mat.set_shader_parameter("use_map_texture", true)
			# Reset base color just in case
			mat.set_shader_parameter("color_grass", Color(0.1, 0.25, 0.05))

func _on_height_loaded(x, y, img: Image):
	if x == height_tile.x and y == height_tile.y:
		_generate_mesh(img)

func _on_height_failed(x, y, reason: String):
	if x == height_tile.x and y == height_tile.y:
		push_error("TerrainChunk: Height tile failed for %d,%d (%s)" % [x, y, reason])
		queue_free()

func _generate_mesh(height_img: Image):
	var resolution = 32 # Vertices per side (Total 32*32 = 1024 verts)
	var step = size_meters / (resolution - 1)
	var min_h = INF
	var max_h = -INF
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for z in range(resolution):
		for x in range(resolution):
			# UV is standard 0-1 for the single tile texture
			var uv = Vector2(float(x) / (resolution-1), float(z) / (resolution-1))
			st.set_uv(uv)
			
			var height_uv = (uv / float(height_subtile_div)) + (Vector2(height_subtile) / float(height_subtile_div))
			height_uv.x = clamp(height_uv.x, 0.0, 1.0)
			height_uv.y = clamp(height_uv.y, 0.0, 1.0)
			
			var px = int(round(height_uv.x * float(height_img.get_width() - 1)))
			var py = int(round(height_uv.y * float(height_img.get_height() - 1)))
			var c = height_img.get_pixel(px, py)
			var h = (_decode_terrarium_height(c) - height_reference_meters) * height_scale
			if h < min_h: min_h = h
			if h > max_h: max_h = h
			
			# Vertex Pos (Local 0 to size)
			var vx = x * step
			var vz = z * step
			
			# Center the mesh visually around (0,0) of the node?
			# No, let's keep pivot at corner for easier grid math, 
			# but we must offset the NODE position in Manager.
			st.add_vertex(Vector3(vx, h, vz))
	
	# Indices
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var tl = z * resolution + x
			var tr = z * resolution + (x + 1)
			var bl = (z + 1) * resolution + x
			var br = (z + 1) * resolution + (x + 1)
			
			st.add_index(tl)
			st.add_index(tr)
			st.add_index(bl)
			st.add_index(tr)
			st.add_index(br)
			st.add_index(bl)
	
	st.generate_normals()
	var mesh = st.commit()
	mesh_instance.mesh = mesh
	
	# Physics
	var shape = mesh.create_trimesh_shape()
	var col = CollisionShape3D.new()
	col.shape = shape
	add_child(col)

func _decode_terrarium_height(c: Color) -> float:
	var r = int(c.r * 255.0 + 0.5)
	var g = int(c.g * 255.0 + 0.5)
	var b = int(c.b * 255.0 + 0.5)
	return (float(r) * 256.0 + float(g) + float(b) / 256.0) - 32768.0

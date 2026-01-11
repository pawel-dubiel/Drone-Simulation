extends Camera3D

@export var target_path: NodePath
@export var follow_speed: float = 4.0
@export var look_speed: float = 6.0
@export var base_offset: Vector3 = Vector3(0, 1.5, 4.0)
@export var max_offset_lag: float = 2.0
@export var base_fov: float = 75.0
@export var max_fov_boost: float = 20.0

var target: Node3D

# We need to track velocity manually since the visual node doesn't have physics velocity
var prev_pos: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO

func _ready():
	set_as_top_level(true)
	if target_path:
		target = get_node(target_path)
		prev_pos = target.global_position

func _process(delta):
	if !target: return
	
	# Calculate velocity from visual movement
	var current_pos = target.global_position
	if delta > 0:
		velocity = (current_pos - prev_pos) / delta
	prev_pos = current_pos
	
	var speed = velocity.length()
	var speed_factor = clamp(speed / 30.0, 0.0, 1.0)
	
	# Yaw tracking
	var target_yaw = target.rotation.y
	var yaw_basis = Basis(Vector3.UP, target_yaw)
	
	var current_offset_z = base_offset.z + (max_offset_lag * speed_factor)
	var final_offset = Vector3(base_offset.x, base_offset.y, current_offset_z)
	var desired_pos = target.global_position + (yaw_basis * final_offset)
	desired_pos.y -= velocity.y * 0.1 
	
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	
	var look_target = target.global_position
	var target_transform = global_transform.looking_at(look_target, Vector3.UP)
	var target_rotation = Quaternion(target_transform.basis)
	var current_rotation = Quaternion(global_transform.basis)
	
	var next_rotation = current_rotation.slerp(target_rotation, look_speed * delta)
	global_transform.basis = Basis(next_rotation)
	
	var target_fov = base_fov + (max_fov_boost * speed_factor)
	fov = lerp(fov, target_fov, 2.0 * delta)

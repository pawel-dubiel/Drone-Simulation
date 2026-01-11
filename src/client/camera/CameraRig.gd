extends Node3D

class_name CameraRig

# A robust, detached camera system.
# It can follow any Node3D, but has optimized logic for DroneVisuals.

@export var target_path: NodePath

@export_group("Follow Settings")
@export var base_distance: float = 6.0
@export var height_offset: float = 4.0
@export var follow_stiffness: float = 3.0   # Lower = Lazier/Smoother, Higher = Tighter
@export var look_stiffness: float = 5.0     # How fast it rotates to look at target
@export var distance_lag_factor: float = 0.15 # How many meters to pull back per m/s of speed

@export_group("Dynamic Effects")
@export var fov_base: float = 75.0
@export var fov_max_boost: float = 35.0     # Zoom out significantly at high speed
@export var look_ahead_factor: float = 0.5  # Look this many seconds ahead based on velocity

@export_group("Top-Down Settings")
@export var top_down_height: float = 40.0
@export var top_down_fov: float = 55.0

var _target_node: Node3D
var _camera: Camera3D
var _top_down_enabled: bool = false
var _has_toggle_action: bool = false

func _ready():
	_camera = $Camera3D
	if target_path:
		_target_node = get_node(target_path)
	
	# Detach from parent to move freely in world space
	set_as_top_level(true)
	
	# Initialize position if target exists
	if _target_node:
		var target_pos = _target_node.global_position
		# Start behind the target
		global_position = target_pos - _target_node.basis.z * base_distance + Vector3.UP * height_offset
		look_at(target_pos, Vector3.UP)
	
	_has_toggle_action = InputMap.has_action("camera_toggle_topdown")
	if !_has_toggle_action:
		push_error("CameraRig: Missing InputMap action 'camera_toggle_topdown'. Configure it in Project Settings > Input Map.")

func _process(delta):
	if !_target_node: return
	
	if _has_toggle_action and Input.is_action_just_pressed("camera_toggle_topdown"):
		_top_down_enabled = !_top_down_enabled
	
	# 1. Gather Target Data
	var target_pos = _target_node.global_position
	var target_vel = Vector3.ZERO
	
	# If the target exposes velocity (like our DroneVisuals), use it.
	if "current_velocity" in _target_node:
		target_vel = _target_node.current_velocity
	
	var speed = target_vel.length()
	# Normalize speed for effects (0 to 30 m/s typical max)
	var speed_factor = clamp(speed / 40.0, 0.0, 1.0)
	
	# 2. Calculate Desired Position
	var desired_pos: Vector3
	if _top_down_enabled:
		desired_pos = target_pos + Vector3.UP * top_down_height
	else:
		# We want to be behind the drone based on its Heading (Yaw), not its Pitch.
		# We use the target's visual transform basis for smooth yaw.
		var target_yaw = _target_node.global_transform.basis.get_euler().y
		var yaw_basis = Basis(Vector3.UP, target_yaw)
		
		# Dynamic offset: Move further back and down slightly as speed increases
		# This creates the "pulling back" G-force effect.
		var dynamic_dist = base_distance + (speed * distance_lag_factor)
		var dynamic_height = height_offset + (speed * 0.02) # Rise slightly too
		
		# Calculate offset vector in world space (rotated by yaw)
		var offset_vec = Vector3(0, dynamic_height, dynamic_dist)
		desired_pos = target_pos + (yaw_basis * offset_vec)
	
	# 3. Apply Smoothing (Lerp)
	# Using lerp for a "spring-like" pull.
	# Frame-rate independent lerp factor: 1 - exp(-decay * dt)
	var pos_t = 1.0 - exp(-follow_stiffness * delta)
	global_position = global_position.lerp(desired_pos, pos_t)
	
	# 4. Look At Logic
	# Look ahead of the drone to anticipate where it's going.
	var look_target = target_pos + (target_vel * look_ahead_factor)
	var up_vec = Vector3.UP
	if _top_down_enabled:
		look_target = target_pos
		up_vec = Vector3.FORWARD
	
	# Create target rotation
	# We interpolate the LookAt rotation for smooth panning
	var target_xform = global_transform.looking_at(look_target, up_vec)
	var q_curr = Quaternion(global_transform.basis)
	var q_next = Quaternion(target_xform.basis)
	
	var rot_t = 1.0 - exp(-look_stiffness * delta)
	global_transform.basis = Basis(q_curr.slerp(q_next, rot_t))
	
	# 5. FOV Effects
	# Smoothly interpolate FOV
	if _camera:
		var target_fov = fov_base + (speed_factor * fov_max_boost)
		if _top_down_enabled:
			target_fov = top_down_fov
		# Use a very slow lerp for FOV so it doesn't pump wildly
		var fov_t = 1.0 - exp(-2.0 * delta)
		_camera.fov = lerp(_camera.fov, target_fov, fov_t)

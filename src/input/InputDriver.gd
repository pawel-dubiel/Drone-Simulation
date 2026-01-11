extends Node

class_name InputDriver

# HARDWARE ABSTRACTION LAYER
# Responsibility: Normalize hardware inputs (Keyboard, Gamepad) into a standardized Command Struct.
# Knows about: Godot Input API.
# Does NOT know about: Network, SignalBroker, Drones, Physics.

signal input_generated(cmd: Dictionary)

@export var sensitivity_pitch: float = 1.0
@export var sensitivity_roll: float = 1.0
@export var sensitivity_yaw: float = 1.0

var _throttle: float = 0.0

func _ready():
	_setup_key_maps()

func _setup_key_maps():
	var actions = {
		"drone_throttle_up": [KEY_SPACE],
		"drone_throttle_down": [KEY_SHIFT],
		"drone_yaw_left": [KEY_LEFT],
		"drone_yaw_right": [KEY_RIGHT],
		"drone_pitch_forward": [KEY_W],
		"drone_pitch_backward": [KEY_S],
		"drone_roll_left": [KEY_A],
		"drone_roll_right": [KEY_D],
		"drone_reset": [KEY_R]
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var ev = InputEventKey.new()
				ev.keycode = key
				InputMap.action_add_event(action, ev)

func _process(delta):
	# 1. Read Hardware
	var throttle_dir = 0.0
	if Input.is_action_pressed("drone_throttle_up"): throttle_dir = 1.0
	elif Input.is_action_pressed("drone_throttle_down"): throttle_dir = -1.0
	
	var reset = Input.is_action_just_pressed("drone_reset")
	if reset:
		_throttle = 0.0
	
	_throttle += throttle_dir * delta * 0.8
	_throttle = clamp(_throttle, 0.0, 1.0)
	
	var pitch = Input.get_axis("drone_pitch_forward", "drone_pitch_backward")
	var roll = Input.get_axis("drone_roll_left", "drone_roll_right")
	var yaw = Input.get_axis("drone_yaw_right", "drone_yaw_left")
	
	# 2. Package Data (Standardized Command Struct)
	var cmd = {
		"throttle": _throttle,
		"pitch": pitch,
		"roll": roll,
		"yaw": yaw,
		"reset": reset,
		"timestamp": Time.get_ticks_msec()
	}
	
	# 3. Emit Local Signal (The PilotUplink will pick this up)
	input_generated.emit(cmd)
extends Node3D

# Client-Side Visualizer
# Dumb terminal. Just renders what the server says.

@onready var body_mesh = $Body
@onready var rotors = {
	"FL": $Arm1/Rotor1,
	"FR": $Arm1/Rotor2,
	"BL": $Arm2/Rotor3,
	"BR": $Arm2/Rotor4
}

# Public properties for Camera/Audio to read
var current_velocity: Vector3 = Vector3.ZERO
var current_rotation_rate: Vector3 = Vector3.ZERO # Euler rates if needed

# Interpolation buffer
var target_pos: Vector3 = Vector3.ZERO
var target_rot: Quaternion = Quaternion.IDENTITY

func _ready():
	SignalBroker.simulation_state_snapshot.connect(_on_state_update)
	set_process(true)

func _on_state_update(snapshot: Dictionary):
	target_pos = snapshot.position
	target_rot = snapshot.rotation
	current_velocity = snapshot.velocity
	
	# Update Audio and Rotor Spin immediately (visual effects don't need strict physics sync)
	var rpms = snapshot.motor_rpms
	_update_rotor_effects(rpms)

func _process(delta):
	# Interpolate transform for smooth 60fps rendering even if physics tick is different
	global_position = global_position.lerp(target_pos, 20.0 * delta)
	global_transform.basis = Basis(Quaternion(global_transform.basis).slerp(target_rot, 20.0 * delta))

func _update_rotor_effects(rpms: Dictionary):
	# Map simulation IDs to Visual Nodes
	# Sim: FL, FR, BL, BR
	# My Visual Scene structure (reused from old scene):
	# Arm1 has Rotor1(FL?), Rotor2(FR?) -> I need to match these correctly.
	# Let's assume standard order or just use index.
	# Actually, better to explicitly map in the scene, but for now:
	
	_apply_rotor_visual("FL", rpms.get("FL", 0))
	_apply_rotor_visual("FR", rpms.get("FR", 0))
	_apply_rotor_visual("BL", rpms.get("BL", 0))
	_apply_rotor_visual("BR", rpms.get("BR", 0))

func _apply_rotor_visual(id, speed):
	# find node
	var node = rotors.get(id)
	if !node: return
	
	# Spin
	node.rotate_y(speed * 0.5) # Speed factor
	
	# Audio (If attached to rotor)
	var audio = node.get_node_or_null("Audio")
	if audio:
		if !audio.playing and speed > 0.05: audio.play()
		audio.pitch_scale = 0.8 + speed * 1.7
		audio.volume_db = -25 + speed * 25

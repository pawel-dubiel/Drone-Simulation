extends RigidBody3D

# The Authoritative Physics Entity
# No Meshes (except invisible collision). No Audio.
# Runs the simulation loop.

@export var flight_computer: FlightComputer

# Motor Simulators
var motors = {}

func _ready():
	# Create motor sims programmatically or find them
	motors["FL"] = _create_motor(true)
	motors["FR"] = _create_motor(false)
	motors["BL"] = _create_motor(false)
	motors["BR"] = _create_motor(true)
	
	# Physics params
	mass = 1.0
	gravity_scale = 1.0 
	linear_damp = 1.0  
	angular_damp = 2.0

func _create_motor(cw: bool) -> MotorSim:
	var m = MotorSim.new()
	m.is_clockwise = cw
	add_child(m)
	return m

func _physics_process(delta):
	# 1. Check Reset
	if flight_computer.check_reset():
		global_transform.origin = Vector3(0, 2, 0)
		rotation = Vector3.ZERO
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	
	# 2. Get Motor Commands from Flight Computer
	var motor_cmds = flight_computer.compute_motor_outputs(rotation, angular_velocity, delta)
	
	# 3. Apply Physics
	var snapshot_rpms = {}
	
	for id in motors:
		var sim = motors[id]
		var cmd = motor_cmds.get(id, 0.0)
		
		var output = sim.update(cmd, delta)
		
		# Apply Force/Torque
		# We need to know where the motor is relative to center.
		# For this pure sim, we can hardcode the arm positions or look up a config.
		# Let's use standard X config offsets (+/- 0.5)
		var offset = Vector3.ZERO
		if id == "FL": offset = Vector3(-0.5, 0.0, -0.5)
		if id == "FR": offset = Vector3(0.5, 0.0, -0.5)
		if id == "BL": offset = Vector3(-0.5, 0.0, 0.5)
		if id == "BR": offset = Vector3(0.5, 0.0, 0.5)
		
		# Rotate offset by body rotation to get global offset vector
		var global_offset = global_transform.basis * offset
		
		# Force is UP relative to body
		var force_vec = global_transform.basis.y * output.thrust
		apply_force(force_vec, global_offset)
		
		# Torque is Y axis relative to body
		var torque_vec = global_transform.basis.y * output.torque
		apply_torque(torque_vec)
		
		snapshot_rpms[id] = output.rpm

	# 4. Broadcast State Snapshot
	var snapshot = {
		"position": global_position,
		"rotation": global_transform.basis.get_rotation_quaternion(), # Send Quat for interpolation
		"velocity": linear_velocity,
		"motor_rpms": snapshot_rpms
	}
	SignalBroker.simulation_state_snapshot.emit(snapshot)

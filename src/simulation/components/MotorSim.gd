extends Node3D

class_name MotorSim

# Simulates a single brushless motor physics
# Calculates Thrust and Torque based on commanded speed
# Does NOT handle audio or visuals (that's client side)

@export var max_thrust: float = 10.0 # Newtons (TWR ~4:1 for 1kg drone, gravity ~9.8N)
@export var torque_coeff: float = 0.5
@export var responsiveness: float = 20.0
@export var is_clockwise: bool = true

var current_rpm_normalized: float = 0.0

func update(commanded_pct: float, dt: float) -> Dictionary:
	# Simulate Motor Inertia
	current_rpm_normalized = lerp(current_rpm_normalized, commanded_pct, responsiveness * dt)
	if current_rpm_normalized < 0.01: current_rpm_normalized = 0.0
	
	var thrust = current_rpm_normalized * max_thrust
	var torque_dir = 1.0 if is_clockwise else -1.0
	var torque = current_rpm_normalized * torque_coeff * torque_dir
	
	return {
		"thrust": thrust,
		"torque": torque,
		"rpm": current_rpm_normalized # Exposed for audio/visuals
	}

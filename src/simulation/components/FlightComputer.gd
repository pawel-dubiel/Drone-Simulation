extends Node

class_name FlightComputer

# SIMULATION LOGIC CORE
# Responsibility: Calculate Motor Mixing based on current state and DESIRED input.
# Does NOT know about Networking or Input Hardware.

# PID Settings
@export var pitch_pid: Vector3 = Vector3(3.0, 0.0, 1.0) # P, I, D
@export var roll_pid: Vector3 = Vector3(3.0, 0.0, 1.0)
@export var yaw_pid: Vector3 = Vector3(2.0, 0.0, 0.5)
@export var max_tilt_angle: float = 0.6 # Radians

# Internal State (Registers)
var _in_throttle: float = 0.0
var _in_pitch: float = 0.0
var _in_roll: float = 0.0
var _in_yaw: float = 0.0
var _reset_flag: bool = false

# API: Called by RadioReceiver, AI, or Replay System
func set_control_inputs(thr: float, p: float, r: float, y: float, reset: bool):
	_in_throttle = thr
	_in_pitch = p
	_in_roll = r
	_in_yaw = y
	if reset:
		_reset_flag = true

# Internal Logic
func compute_motor_outputs(current_att: Vector3, angular_vel: Vector3, dt: float) -> Dictionary:
	var target_pitch = _in_pitch * max_tilt_angle
	var target_roll = -_in_roll * max_tilt_angle
	var target_yaw_rate = _in_yaw
	
	var cur_p = current_att.x
	var cur_r = current_att.z
	
	# Pitch PID
	var error_p = target_pitch - cur_p
	var d_term_p = -angular_vel.x * pitch_pid.z
	var pid_pitch = (error_p * pitch_pid.x) + d_term_p
	
	# Roll PID
	var error_r = target_roll - cur_r
	var d_term_r = -angular_vel.z * roll_pid.z
	var pid_roll = (error_r * roll_pid.x) + d_term_r
	
	# Yaw PID
	var pid_yaw = target_yaw_rate * yaw_pid.x - angular_vel.y * yaw_pid.z
	
	# Mixer
	var t = _in_throttle
	var m_fl = t + pid_pitch - pid_roll + pid_yaw
	var m_fr = t + pid_pitch + pid_roll - pid_yaw
	var m_bl = t - pid_pitch - pid_roll - pid_yaw
	var m_br = t - pid_pitch + pid_roll + pid_yaw
	
	# Deadzone safety
	if t < 0.05:
		return {"FL":0.0, "FR":0.0, "BL":0.0, "BR":0.0}
	
	return {
		"FL": clamp(m_fl, 0.0, 1.0),
		"FR": clamp(m_fr, 0.0, 1.0),
		"BL": clamp(m_bl, 0.0, 1.0),
		"BR": clamp(m_br, 0.0, 1.0)
	}

func check_reset():
	if _reset_flag:
		_reset_flag = false
		return true
	return false
extends Control

@onready var lbl_throttle = $Panel/VBoxContainer/Throttle
@onready var lbl_altitude = $Panel/VBoxContainer/Altitude
@onready var lbl_speed = $Panel/VBoxContainer/Speed
@onready var lbl_attitude = $Panel/VBoxContainer/Attitude

func _ready():
	SignalBroker.simulation_state_snapshot.connect(_on_state)
	SignalBroker.control_command_received.connect(_on_cmd)

func _on_cmd(thr, _p, _r, _y, _res):
	lbl_throttle.text = "THR: %d%%" % (thr * 100)

func _on_state(snap):
	var pos = snap.position
	var vel = snap.velocity
	var quat = snap.rotation
	
	lbl_altitude.text = "ALT: %.1fm" % pos.y
	lbl_speed.text = "SPD: %.1f m/s" % vel.length()
	
	var euler = quat.get_euler()
	lbl_attitude.text = "P:%.0f R:%.0f Y:%.0f" % [deg(euler.x), deg(euler.z), deg(euler.y)]

func deg(rad):
	return rad * 180.0 / PI

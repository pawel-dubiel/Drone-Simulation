extends Control

@onready var lbl_throttle = $Panel/VBoxContainer/Throttle
@onready var lbl_altitude = $Panel/VBoxContainer/Altitude
@onready var lbl_speed = $Panel/VBoxContainer/Speed
@onready var lbl_attitude = $Panel/VBoxContainer/Attitude
@onready var btn_clear_cache = $Panel/VBoxContainer/ClearCache

func _ready():
	SignalBroker.simulation_state_snapshot.connect(_on_state)
	SignalBroker.control_command_received.connect(_on_cmd)
	btn_clear_cache.pressed.connect(_on_clear_cache_pressed)

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

func _on_clear_cache_pressed():
	_clear_cache_dir("user://cache")
	_clear_cache_dir("user://height_cache")

func _clear_cache_dir(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("HUD: Cache dir missing: %s" % path)
		return
	
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			if dir.current_is_dir():
				dir.list_dir_end()
				push_error("HUD: Cache dir contains subdir: %s" % name)
				return
			var err = dir.remove(name)
			if err != OK:
				dir.list_dir_end()
				push_error("HUD: Failed to remove cache file %s/%s (err=%d)" % [path, name, err])
				return
		name = dir.get_next()
	dir.list_dir_end()

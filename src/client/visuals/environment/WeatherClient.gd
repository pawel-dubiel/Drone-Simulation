extends Node

class_name WeatherClient

# CLIENT COMPONENT
# Responsibility: Observe weather signals and apply them to the visual environment.
# NO simulation logic here.

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D
@export var sky_material: ShaderMaterial
@export var rain_particles: GPUParticles3D

func _ready():
	print("WeatherClient: Ready")
	SignalBroker.weather_state_changed.connect(_on_weather_state_changed)
	SignalBroker.weather_time_changed.connect(_on_time_changed)
	
	# Initial Visual Setup (Tonemapping, etc.)
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.glow_enabled = true
		env.glow_normalized = true

func _process(_delta):
	_update_rain_position()

func _on_weather_state_changed(data: Dictionary):
	# Apply Clouds
	if sky_material:
		sky_material.set_shader_parameter("cloud_coverage", data.get("cloud_coverage", 0.0))
	
	# Apply Rain
	if rain_particles:
		var rain_intensity = data.get("rain_intensity", 0.0)
		rain_particles.amount_ratio = clamp(rain_intensity, 0.0, 1.0)
		rain_particles.emitting = rain_intensity > 0.01

	# Apply Fog
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		var fog_enabled = data.get("fog_enabled", false)
		env.fog_enabled = fog_enabled
		if fog_enabled:
			var density = data.get("fog_density", 0.0)
			env.fog_density = density
			var vol_enabled = data.get("volumetric_fog_enabled", false)
			env.volumetric_fog_enabled = vol_enabled
			if vol_enabled:
				env.volumetric_fog_density = density * 0.5

	# Apply Sun
	if sun_light:
		var sun_dir = data.get("sun_direction", Vector3.DOWN)
		sun_light.global_transform.origin = Vector3.ZERO
		sun_light.look_at(-sun_dir, Vector3.UP)
		sun_light.light_color = data.get("sun_color", Color.WHITE)
		sun_light.light_energy = data.get("sun_energy", 1.0)

func _on_time_changed(_h, _m, _s, _month, _day):
	pass

func _update_rain_position():
	if not rain_particles: return
	var camera = get_viewport().get_camera_3d()
	if camera:
		var pos = camera.global_position
		pos.y += 10.0
		rain_particles.global_position = pos

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		print("WeatherClient: Key pressed (unhandled): ", event.keycode)
		match event.keycode:
			KEY_1: SignalBroker.weather_command_requested.emit("change_weather", 0) # CLEAR
			KEY_2: SignalBroker.weather_command_requested.emit("change_weather", 1) # PARTLY_CLOUDY
			KEY_3: SignalBroker.weather_command_requested.emit("change_weather", 2) # OVERCAST
			KEY_4: SignalBroker.weather_command_requested.emit("change_weather", 3) # RAINY
			KEY_5: SignalBroker.weather_command_requested.emit("change_weather", 4) # STORMY
			KEY_6: SignalBroker.weather_command_requested.emit("toggle_fog", null)
			KEY_7: SignalBroker.weather_command_requested.emit("toggle_volumetric", null)
			KEY_8: SignalBroker.weather_command_requested.emit("toggle_time", null)
			KEY_9: SignalBroker.weather_command_requested.emit("time_shift", -1.0)
			KEY_0: SignalBroker.weather_command_requested.emit("time_shift", 1.0)

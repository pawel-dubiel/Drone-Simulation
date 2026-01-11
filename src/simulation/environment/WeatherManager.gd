extends Node

class_name WeatherManager

# Enums for Weather Types
enum WeatherType {
	CLEAR,
	PARTLY_CLOUDY,
	OVERCAST,
	RAINY,
	STORMY
}

# Configuration
@export_group("References")
@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D
@export var sky_material: ShaderMaterial

@export_group("Settings")
@export var transition_speed: float = 0.5
@export var day_length_seconds: float = 120.0 # Just for reference if we add day/night cycle later
@export var enable_fog: bool = true
@export var enable_volumetric_fog: bool = false
@export_range(0.0, 24.0) var time_of_day: float = 12.0 # Hours 0-24
@export var animate_time: bool = true
@export var time_scale: float = 0.0002777 # 1.0 / 3600.0 (1 real sec = 1 game sec)
@export var use_system_time: bool = false # Sync with OS clock

signal time_changed(h: int, m: int, s: int, month: int, day: int)

# Internal State
var current_weather: WeatherType = WeatherType.CLEAR
var current_cloud_coverage: float = 0.0
var current_fog_density: float = 0.0
var current_sun_energy: float = 1.0
var current_rain_intensity: float = 0.0

# Targets
var target_cloud_coverage: float = 0.0
var target_fog_density: float = 0.0
var target_sun_energy: float = 1.0
var target_rain_intensity: float = 0.0

@onready var rain_particles: GPUParticles3D = $RainParticles

func _ready() -> void:
	# Configure High Quality Environment for Realism
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.glow_enabled = true
		env.glow_normalized = true
		env.glow_intensity = 1.0
		env.glow_strength = 0.9
		env.glow_bloom = 0.2
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		
	change_weather(WeatherType.PARTLY_CLOUDY, true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: change_weather(WeatherType.CLEAR)
			KEY_2: change_weather(WeatherType.PARTLY_CLOUDY)
			KEY_3: change_weather(WeatherType.OVERCAST)
			KEY_4: change_weather(WeatherType.RAINY)
			KEY_5: change_weather(WeatherType.STORMY)
			KEY_6: enable_fog = !enable_fog
			KEY_7: enable_volumetric_fog = !enable_volumetric_fog
			KEY_8: animate_time = !animate_time
			KEY_9: time_of_day -= 1.0
			KEY_0: time_of_day += 1.0

func _process(delta: float) -> void:
	if use_system_time:
		var time_dict = Time.get_time_dict_from_system()
		time_of_day = time_dict.hour + (time_dict.minute / 60.0) + (time_dict.second / 3600.0)
	elif animate_time:
		time_of_day += delta * time_scale
		if time_of_day >= 24.0:
			time_of_day -= 24.0
	
	_emit_time_signal()
	_update_sun_position()
	_interpolate_weather_values(delta)
	_apply_weather_values()
	_update_rain_position()

func _emit_time_signal() -> void:
	var total_seconds = time_of_day * 3600.0
	var h = int(total_seconds / 3600.0)
	var m = int((int(total_seconds) % 3600) / 60.0)
	var s = int(total_seconds) % 60
	
	var date_dict = _get_date_from_doy(WorldConfig.start_day_of_year)
	time_changed.emit(h, m, s, date_dict.month, date_dict.day)

func _get_date_from_doy(doy: int) -> Dictionary:
	var days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var current_month = 1
	var days_left = doy
	
	for days in days_in_month:
		if days_left <= days:
			return {"month": current_month, "day": days_left}
		days_left -= days
		current_month += 1
	return {"month": 12, "day": 31}

func _update_sun_position() -> void:
	if not sun_light: return
	
	# Astronomical Calculation for Sun Position
	# References: NOAA Solar Calculation or simple approximate formulas
	
	# 1. Calculate Declination of the Sun (delta)
	# Approx formula: delta = -23.44 * cos(360/365 * (N + 10))
	var N = float(WorldConfig.start_day_of_year)
	var declination = deg_to_rad(-23.44 * cos(deg_to_rad(360.0 / 365.0 * (N + 10.0))))
	
	# 2. Calculate Local Hour Angle (LHA)
	# 0 at solar noon. 15 degrees per hour.
	# Solar time approx = time_of_day (ignoring Equation of Time and Longitude correction for now for simplicity, or we can add it)
	# Adding Longitude correction: Solar Time = Standard Time + 4min * (Lon - LocalMeridian) + EqTime...
	# Let's stick to "Game Time is Solar Time" for simplicity, or just simple offset.
	var solar_time = time_of_day
	var lha_deg = (solar_time - 12.0) * 15.0
	var lha = deg_to_rad(lha_deg)
	
	# 3. Calculate Elevation (Altitude) - h
	# sin(h) = sin(lat)sin(delta) + cos(lat)cos(delta)cos(lha)
	var lat_rad = deg_to_rad(WorldConfig.latitude)
	var sin_h = sin(lat_rad) * sin(declination) + cos(lat_rad) * cos(declination) * cos(lha)
	var elevation = asin(clamp(sin_h, -1.0, 1.0))
	
	# 4. Calculate Azimuth - A
	# cos(A) = (sin(delta) - sin(lat)sin(h)) / (cos(lat)cos(h))
	var cos_a = (sin(declination) - sin(lat_rad) * sin(elevation)) / (cos(lat_rad) * cos(elevation) + 0.00001)
	var azimuth = acos(clamp(cos_a, -1.0, 1.0))
	
	# If LHA > 0 (afternoon), Azimuth is 360 - A (or similar, depending on convention)
	# Usually Azimuth is from North.
	# If lha > 0, Sun is to the West.
	if lha > 0.0:
		azimuth = 2.0 * PI - azimuth
		
	# 5. Convert Azimuth/Elevation to Godot Coordinates
	# Godot: Y is Up. -Z is North. +X is East.
	# Azimuth 0 = North (-Z).
	# Elevation 0 = Horizon.
	# We need a direction vector.
	
	# Standard spherical to cartesian (Z=North, X=East, Y=Up)
	# x = cos(elev) * sin(azimuth)  (East component)
	# z = -cos(elev) * cos(azimuth) (North component is -Z)
	# y = sin(elev)
	
	var sun_dir = Vector3(
		cos(elevation) * sin(azimuth),
		sin(elevation),
		-cos(elevation) * cos(azimuth)
	)
	
	# Set DirectionalLight rotation
	# Look at from origin to sun_dir? No, light points FROM sun.
	# So look_at from sun_dir to origin.
	# Or just look_at(sun_dir * -100)
	
	sun_light.global_transform.origin = Vector3.ZERO
	sun_light.look_at(-sun_dir, Vector3.UP)
	
	# Sun Color / Intensity Logic
	var sun_height = sun_dir.y # sin(elevation)
	
	if sun_height < -0.1:
		# Night
		sun_light.light_energy = 0.0
	else:
		# Day / Twilight
		var color_t: Color
		if sun_height < 0.1:
			# Sunrise/Sunset
			color_t = Color(1.0, 0.4, 0.2) # Orange
		elif sun_height < 0.3:
			# Morning/Evening
			color_t = Color(1.0, 0.9, 0.7)
		else:
			# Noon
			color_t = Color(1.0, 1.0, 0.95)
			
		var gradient_t = smoothstep(-0.1, 0.4, sun_height)
		var final_color = Color(1.0, 0.4, 0.2).lerp(Color(1.0, 1.0, 0.98), gradient_t)
		
		sun_light.light_color = final_color
		# Intensity ramps up
		sun_light.light_energy = current_sun_energy * smoothstep(-0.05, 0.1, sun_height)


func change_weather(new_weather: WeatherType, instant: bool = false) -> void:
	current_weather = new_weather
	match new_weather:
		WeatherType.CLEAR:
			target_cloud_coverage = 0.1
			target_fog_density = 0.0005
			target_sun_energy = 1.0
			target_rain_intensity = 0.0
		WeatherType.PARTLY_CLOUDY:
			target_cloud_coverage = 0.5
			target_fog_density = 0.002
			target_sun_energy = 0.9
			target_rain_intensity = 0.0
		WeatherType.OVERCAST:
			target_cloud_coverage = 0.9
			target_fog_density = 0.01
			target_sun_energy = 0.5
			target_rain_intensity = 0.0
		WeatherType.RAINY:
			target_cloud_coverage = 0.95
			target_fog_density = 0.02
			target_sun_energy = 0.3
			target_rain_intensity = 0.5
		WeatherType.STORMY:
			target_cloud_coverage = 1.0
			target_fog_density = 0.04
			target_sun_energy = 0.1
			target_rain_intensity = 1.0
	
	if instant:
		current_cloud_coverage = target_cloud_coverage
		current_fog_density = target_fog_density
		current_sun_energy = target_sun_energy
		current_rain_intensity = target_rain_intensity

func _interpolate_weather_values(delta: float) -> void:
	var t = delta * transition_speed
	current_cloud_coverage = lerp(current_cloud_coverage, target_cloud_coverage, t)
	current_fog_density = lerp(current_fog_density, target_fog_density, t)
	current_sun_energy = lerp(current_sun_energy, target_sun_energy, t)
	current_rain_intensity = lerp(current_rain_intensity, target_rain_intensity, t)

func _apply_weather_values() -> void:
	if sky_material:
		sky_material.set_shader_parameter("cloud_coverage", current_cloud_coverage)
	
	if world_environment and world_environment.environment:
		world_environment.environment.fog_enabled = enable_fog
		if enable_fog:
			world_environment.environment.fog_density = current_fog_density
			world_environment.environment.volumetric_fog_enabled = enable_volumetric_fog
			if enable_volumetric_fog:
				world_environment.environment.volumetric_fog_density = current_fog_density * 0.5
				world_environment.environment.volumetric_fog_emission_energy = 0.0

func _update_rain_position() -> void:
	if not rain_particles:
		return
		
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Keep rain above camera
		var pos = camera.global_position
		pos.y += 10.0
		rain_particles.global_position = pos
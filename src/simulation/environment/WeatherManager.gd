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

func _process(delta: float) -> void:
	_interpolate_weather_values(delta)
	_apply_weather_values()
	_update_rain_position()

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
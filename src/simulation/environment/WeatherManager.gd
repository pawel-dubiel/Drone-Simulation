extends Node

class_name WeatherManager

# SIMULATION COMPONENT
# Responsibility: Calculate weather states and sun positions based on time/date.
# Broadcasters: weather_time_changed, weather_state_changed.
# NO direct references to Environment, Lights, or Materials.

# Enums for Weather Types
enum WeatherType {
	CLEAR,
	PARTLY_CLOUDY,
	OVERCAST,
	RAINY,
	STORMY
}

# Configuration
@export_group("Settings")
@export var transition_speed: float = 0.5
@export var enable_fog: bool = true
@export var enable_volumetric_fog: bool = false
@export_range(0.0, 24.0) var time_of_day: float = 12.0 # Hours 0-24
@export var animate_time: bool = true
@export var time_scale: float = 0.0002777 # 1.0 / 3600.0 (1 real sec = 1 game sec)
@export var use_system_time: bool = false # Sync with OS clock

# Internal Simulation State
var current_weather: WeatherType = WeatherType.CLEAR
var current_cloud_coverage: float = 0.0
var current_fog_density: float = 0.0
var current_sun_energy: float = 1.0
var current_rain_intensity: float = 0.0

# Calculated Sun State
var sun_direction: Vector3 = Vector3.DOWN
var sun_color: Color = Color.WHITE
var sun_energy: float = 1.0

# Targets for interpolation
var target_cloud_coverage: float = 0.0
var target_fog_density: float = 0.0
var target_sun_energy: float = 1.0
var target_rain_intensity: float = 0.0

func _ready() -> void:
	print("WeatherManager: Ready")
	change_weather(WeatherType.PARTLY_CLOUDY, true)
	SignalBroker.weather_command_requested.connect(_on_weather_command)

func _on_weather_command(command: String, value: Variant) -> void:
	print("WeatherManager: Command received: ", command, " (", value, ")")
	match command:
		"change_weather": change_weather(value as WeatherType)
		"toggle_fog": enable_fog = !enable_fog
		"toggle_volumetric": enable_volumetric_fog = !enable_volumetric_fog
		"toggle_time": animate_time = !animate_time
		"time_shift": time_of_day += value as float

func _process(delta: float) -> void:
	if use_system_time:
		var time_dict = Time.get_time_dict_from_system()
		time_of_day = time_dict.hour + (time_dict.minute / 60.0) + (time_dict.second / 3600.0)
	elif animate_time:
		time_of_day += delta * time_scale
		if time_of_day >= 24.0:
			time_of_day -= 24.0
	
	_emit_time_signal()
	_update_sun_logic()
	_interpolate_weather_values(delta)
	_broadcast_state()

func _emit_time_signal() -> void:
	var total_seconds = time_of_day * 3600.0
	var h = int(total_seconds / 3600.0)
	var m = int((int(total_seconds) % 3600) / 60.0)
	var s = int(total_seconds) % 60
	
	var date_dict = _get_date_from_doy(WorldConfig.start_day_of_year)
	SignalBroker.weather_time_changed.emit(h, m, s, date_dict.month, date_dict.day)

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

func _update_sun_logic() -> void:
	var N = float(WorldConfig.start_day_of_year)
	var declination = deg_to_rad(-23.44 * cos(deg_to_rad(360.0 / 365.0 * (N + 10.0))))
	var lha = deg_to_rad((time_of_day - 12.0) * 15.0)
	var lat_rad = deg_to_rad(WorldConfig.latitude)
	var sin_h = sin(lat_rad) * sin(declination) + cos(lat_rad) * cos(declination) * cos(lha)
	var elevation = asin(clamp(sin_h, -1.0, 1.0))
	var cos_a = (sin(declination) - sin(lat_rad) * sin(elevation)) / (cos(lat_rad) * cos(elevation) + 0.00001)
	var azimuth = acos(clamp(cos_a, -1.0, 1.0))
	if lha > 0.0: azimuth = 2.0 * PI - azimuth
	
	sun_direction = Vector3(cos(elevation) * sin(azimuth), sin(elevation), -cos(elevation) * cos(azimuth))
	
	var sun_height = sun_direction.y
	if sun_height < -0.1:
		sun_energy = 0.0
	else:
		var gradient_t = smoothstep(-0.1, 0.4, sun_height)
		sun_color = Color(1.0, 0.4, 0.2).lerp(Color(1.0, 1.0, 0.98), gradient_t)
		sun_energy = target_sun_energy * smoothstep(-0.05, 0.1, sun_height)

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

func _broadcast_state() -> void:
	var state = {
		"weather_type": current_weather,
		"cloud_coverage": current_cloud_coverage,
		"rain_intensity": current_rain_intensity,
		"fog_enabled": enable_fog,
		"fog_density": current_fog_density,
		"volumetric_fog_enabled": enable_volumetric_fog,
		"sun_direction": sun_direction,
		"sun_color": sun_color,
		"sun_energy": sun_energy
	}
	SignalBroker.weather_state_changed.emit(state)

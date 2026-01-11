extends Node

# Centralized World Configuration
# Use this for shared location and time data across systems (Weather, Terrain, etc.)

# Default: Innsbruck, Austria (Alps)
@export_group("Geolocation")
@export var latitude: float = 47.2692
@export var longitude: float = 11.4041

# Default: June 21st (Summer Solstice)
@export_group("Date")
@export_range(1, 365) var start_day_of_year: int = 172

extends Node

# Global Event Bus acting as the "Network" backbone
# In a real networked game, this would be replaced by RPC calls

# --- Command Channel (Client -> Server) ---
# Emitted by Input/RadioLink, received by FlightComputer
signal control_command_received(throttle: float, pitch: float, roll: float, yaw: float, reset: bool)

# --- State Channel (Server -> Client) ---
# Emitted by Physics/Simulation, received by Visuals/HUD
# snapshot dictionary contains: position, rotation, velocity, motor_rpms (Array), battery, etc.
signal simulation_state_snapshot(snapshot: Dictionary)

# --- Weather Channel ---
signal weather_time_changed(h: int, m: int, s: int, month: int, day: int)
signal weather_state_changed(weather_type: int, cloud_coverage: float, rain_intensity: float)

# Config/Meta events
signal debug_log(msg: String)

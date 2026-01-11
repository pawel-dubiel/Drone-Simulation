extends Node

class_name DroneRadioReceiver

# SERVER COMPONENT
# Responsibility: Listen to the "Radio Frequency" (SignalBroker) and feed the Flight Computer.
# This represents the RX hardware on the drone.

@export var flight_computer: FlightComputer

func _ready():
	# In a multiplayer game, we would subscribe to a specific channel ID
	SignalBroker.control_command_received.connect(_on_radio_packet)

func _on_radio_packet(thr, p, r, y, reset):
	if flight_computer:
		flight_computer.set_control_inputs(thr, p, r, y, reset)

extends Node

class_name PilotUplink

# CLIENT NETWORK BRIDGE
# Responsibility: Take local input commands and transmit them over the "Network" (SignalBroker).
# Can be expanded to simulate packet loss, latency, or encoding.

@export var input_driver: InputDriver

func _ready():
	if input_driver:
		input_driver.input_generated.connect(_on_input_generated)

func _on_input_generated(cmd: Dictionary):
	# Here we effectively "Serialize" the command to the network
	SignalBroker.control_command_received.emit(
		cmd.throttle,
		cmd.pitch,
		cmd.roll,
		cmd.yaw,
		cmd.reset
	)

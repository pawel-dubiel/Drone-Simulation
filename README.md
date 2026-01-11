# Godot Drone Simulation

A modular, event-driven flight simulation focused on realistic environment rendering and physics-based drone flight. The project uses a decoupled architecture where simulation components and client-side visuals communicate through a centralized event bus.

## Features

### Environment & Weather
- **Dynamic Sky & Sun**: Physically-based sun rendering with accurate angular size (0.53°) and atmospheric scattering approximations.
- **Solar Position Algorithm**: Sun position is calculated based on Latitude, Longitude, and Day of Year (Summer/Winter solstices).
- **Satellite Terrain**: Infinite terrain generation using Web Mercator tiles, with dynamic render distance scaling based on flight altitude.
- **Weather System**: Interpolated transitions between weather states (Clear, Overcast, Rainy, Stormy) affecting fog, light intensity, and cloud coverage.

### Physics & Control
- **RigidBody3D Flight**: Authoritative physics-based drone simulation using motor thrust and torque vectors.
- **Input Abstraction**: Hardware inputs are normalized into a standard command struct before being transmitted to the flight computer.
- **Digital Twin Architecture**: Simulation state is broadcast via signals, allowing UI and visuals to remain decoupled from physics.

## Project Structure

- `src/core/`: Centralized configuration (`WorldConfig`) and event bus (`SignalBroker`).
- `src/simulation/`: Authoritative logic (Drone physics, Terrain management, Weather states).
- `src/client/`: Visuals, HUD, Camera, and Audio.
- `src/input/`: Hardware abstraction layer.

## Controls

### Flight
- **W / S**: Pitch Forward / Backward
- **A / D**: Roll Left / Right
- **Left / Right Arrows**: Yaw
- **Space / Shift**: Throttle Up / Down
- **R**: Reset Simulation

### Environment (Debug)
- **1 - 5**: Change Weather (Clear -> Stormy)
- **6**: Toggle Fog
- **7**: Toggle Volumetric Fog
- **8**: Toggle Time Animation
- **9 / 0**: Decrease / Increase Time (-/+ 1 hour)

## Configuration

Global simulation parameters like Geolocation and Date can be modified in `src/core/WorldConfig.gd`.
- Default Location: Innsbruck, Austria (47.27N, 11.40E)
- Default Date: June 21st (Summer Solstice)

shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.35, 0.46, 0.71);
uniform vec3 sky_horizon_color : source_color = vec3(0.64, 0.75, 0.85);
uniform vec3 ground_bottom_color : source_color = vec3(0.15, 0.17, 0.18);
uniform vec3 ground_horizon_color : source_color = vec3(0.32, 0.35, 0.38);

uniform float sun_angle_max = 30.0;
uniform float sun_curve : hint_range(0.0, 1.0) = 0.15;

uniform sampler2D cloud_texture;
uniform sampler2D cloud_texture2;
uniform vec2 cloud_direction = vec2(0.5, 0.0);
uniform vec2 cloud_direction2 = vec2(0.3, 0.4);
uniform float cloud_scale = 1.0;
uniform float cloud_speed = 0.02;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.8;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float horizon_fade_size = 0.2;

void sky() {
	float v_angle = acos(EYEDIR.y); // 0 at zenith, PI at nadir
	float blend = clamp(1.0 - (v_angle / (PI * 0.5)), 0.0, 1.0); // 1 at top, 0 at horizon

	// Simple Day/Night Gradient
	vec3 sky_color = mix(sky_horizon_color, sky_top_color, clamp(blend, 0.0, 1.0));
	vec3 ground_color = mix(ground_horizon_color, ground_bottom_color, clamp((v_angle - PI * 0.5) / (PI * 0.5), 0.0, 1.0));
	
	vec3 final_color = mix(ground_color, sky_color, step(0.0, EYEDIR.y));
	
	// Smooth horizon transition
	float horizon_blur = smoothstep(-0.1, 0.1, EYEDIR.y);
	final_color = mix(ground_color, sky_color, horizon_blur);

	// Clouds (Plane mapped to sphere top)
	if (EYEDIR.y > 0.0) {
		vec2 uv = EYEDIR.xz / (EYEDIR.y + 0.2); // Simple projection
		float time = TIME * cloud_speed;
		
		vec2 uv1 = uv * cloud_scale + time * cloud_direction;
		vec2 uv2 = uv * cloud_scale * 0.5 + time * cloud_direction2;
		
		float noise1 = texture(cloud_texture, uv1).r;
		float noise2 = texture(cloud_texture2, uv2).r;
		
		float combined_noise = mix(noise1, noise2, 0.5);
		
		// Cloud coverage threshold
		float cloud_mask = smoothstep(1.0 - cloud_coverage, (1.0 - cloud_coverage) + 0.1, combined_noise);
		
		// Horizon fade for clouds
		float cloud_fade = smoothstep(0.0, horizon_fade_size, EYEDIR.y);
		
		vec3 cloud_final_color = mix(cloud_color, vec3(0.5), 0.1); // Slight shading
		
		final_color = mix(final_color, cloud_final_color, cloud_mask * cloud_opacity * cloud_fade);
	}

	// Sun
	float sun_dist = distance(EYEDIR, LIGHT0_DIRECTION);
	float sun_mask = 1.0 - smoothstep(0.0, 0.05, sun_dist);
	final_color += sun_mask * LIGHT0_COLOR * 2.0; // Add sun disk

	COLOR = final_color;
}

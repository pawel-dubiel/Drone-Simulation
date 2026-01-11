shader_type spatial;

// Simple procedural terrain shader
// Mixes colors based on height and slope

uniform float min_height = 0.0;
uniform float max_height = 20.0;

uniform vec3 color_grass : source_color = vec3(0.1, 0.25, 0.05);
uniform vec3 color_rock : source_color = vec3(0.15, 0.15, 0.15);
uniform vec3 color_snow : source_color = vec3(0.9, 0.9, 0.95);
uniform vec3 color_dirt : source_color = vec3(0.2, 0.15, 0.1);

uniform sampler2D map_texture : source_color, filter_linear_mipmap;
uniform bool use_map_texture = false;
uniform vec2 map_uv_scale = vec2(1.0, 1.0);

varying float v_height;
varying vec3 v_normal;
varying vec2 v_uv;

void vertex() {
	v_height = VERTEX.y;
	v_normal = NORMAL;
	v_uv = UV;
}

void fragment() {
	// 1. Slope Calculation (Dot product with UP vector)
	float slope = dot(v_normal, vec3(0.0, 1.0, 0.0));
	
	// 2. Base Color Mixing
	vec3 albedo_out = color_grass;
	
	// Height-based mixing
	float height_factor = (v_height - min_height) / (max_height - min_height);
	
	// Rock on steep slopes
	float rock_mask = smoothstep(0.7, 0.5, slope); 
	
	// Snow at peaks
	float snow_mask = smoothstep(0.7, 0.9, height_factor);
	snow_mask *= smoothstep(0.4, 0.6, slope); 
	
	// Mix Procedural
	albedo_out = mix(albedo_out, color_rock, rock_mask);
	albedo_out = mix(albedo_out, color_snow, snow_mask);
	
	// Simple noise overlay
	float noise = fract(sin(dot(UV * 50.0, vec2(12.9898, 78.233))) * 43758.5453);
	albedo_out *= (0.9 + noise * 0.2);

	// 3. Apply Map Texture (if available)
	if (use_map_texture) {
		vec3 map_color = texture(map_texture, v_uv * map_uv_scale).rgb;
		
		// Output RAW map texture.
		ALBEDO = map_color;
		
		ROUGHNESS = 1.0; 
		SPECULAR = 0.0;
	} else {
		ALBEDO = albedo_out;
		ROUGHNESS = 0.9;
		SPECULAR = 0.1;
	}
}

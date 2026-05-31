// Involute Gear Shader - Physical Material
extern float N;            // Tooth count
extern float rb;           // Base circle
extern float ra;           // Addendum
extern float rf;           // Dedendum
extern float m;            // Module
extern float rotation;     // Rotation
extern vec2 center;        // Screen center
extern float inv_alpha_p;  
extern float half_thick_p; 
extern vec2 light_pos;     // Light position for specular calculation

#define PI 3.14159265359

float inv(float a) { return tan(a) - a; }

// Calculate detailed tooth occlusion value (0 or 1)
float get_gear_shape(float r, float abs_theta) {
    if (r < rf) return 1.0;
    if (r > ra) return 0.0;
    if (r >= rb) {
        float alpha = acos(rb / r);
        float current_half_thick = half_thick_p + inv_alpha_p - inv(alpha);
        return step(abs_theta, current_half_thick);
    } else {
        float base_half_thick = half_thick_p + inv_alpha_p;
        return step(abs_theta, base_half_thick);
    }
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 p = screen_coords - center;
    float r = length(p);
    float delta = fwidth(r);

    if (r > ra + delta) discard;

    float theta = atan(p.y, p.x) - rotation;
    float tooth_angle = 2.0 * PI / N;
    float local_theta = mod(theta + tooth_angle * 0.5, tooth_angle) - tooth_angle * 0.5;
    float abs_theta = abs(local_theta);

    // 1. Base shape
    float mask = get_gear_shape(r, abs_theta);

    // 2. Fake normals (Normal Mapping)
    // Estimate normal direction by sampling surrounding shape to create edge bevel effect
    float e = 1.0;
    float nx = get_gear_shape(r, abs(local_theta + e/r)) - get_gear_shape(r, abs(local_theta - e/r));
    float ny = get_gear_shape(r + e, abs_theta) - get_gear_shape(r - e, abs_theta);
    vec3 normal = normalize(vec3(nx, ny, 0.5)); // 0.5 is the plane's Z component

    // 3. Calculate lighting
    vec3 light_dir = normalize(vec3(light_pos - screen_coords, 100.0));
    float diff = max(dot(normal, light_dir), 0.0);
    
    // Specular highlight
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    vec3 half_dir = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_dir), 0.0), 32.0);

    // 4. Material detail: wear and imperfections (Noise)
    float noise = fract(sin(dot(screen_coords, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 base_color = color.rgb * (0.9 + 0.1 * noise);

    // 5. Combine color
    // Base color + ambient + diffuse + specular
    vec3 final_color = base_color * (0.4 + 0.6 * diff) + vec3(0.8) * spec;
    
    // Shaft hole handling
    float hole_r = rf * 0.3;
    float final_alpha = mask * smoothstep(ra, ra-delta, r) * smoothstep(hole_r, hole_r+delta, r);

    return vec4(final_color, final_alpha * color.a);
}
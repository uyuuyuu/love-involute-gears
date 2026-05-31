// 2D Volumetric Light Shader - Final Fix
extern vec2 light_pos;     // Mouse screen pixel coordinates
extern Image occlusion;    // Occlusion map
extern vec2 screen_res;    // Screen resolution
extern vec3 light_color;   // Light color

#define SAMPLES 80         // Sample steps
#define DECAY 0.98         // Decay
#define DENSITY 0.8        // Increase density to extend light rays
#define WEIGHT 0.05        // Weight

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // 1. Calculate UV coordinates of current pixel and light source [0, 1]
    vec2 uv = screen_coords / screen_res;
    vec2 light_uv = light_pos / screen_res;

    // 2. Calculate step vector from current pixel toward light source
    // Note: we trace from pixel back toward light; if we hit white on the way, pixel is occluded
    vec2 delta = (uv - light_uv) * (1.0 / float(SAMPLES)) * DENSITY;
    vec2 coord = uv;

    float light_accum = 1.0; // Default: fully lit
    float illumination_decay = 1.0;
    float visibility = 1.0;

    // 3. Ray march: detect occlusion from current point toward light
    for (int i = 0; i < SAMPLES; i++) {
        coord -= delta;

        // Sample occlusion map. R > 0.5 means obstacle at this point
        float occ = Texel(occlusion, coord).r;

        // Core logic: if we hit an obstacle on the path to the light,
        // the current pixel's visibility drops significantly
        if (occ > 0.5) {
            // Further from light = stronger occlusion feel
            visibility *= 0.85;
        }
    }

    // 4. Calculate base radial emission from light
    float dist = length(screen_coords - light_pos);
    // Boost close-range light, reduce distant light
    float atten = 500.0 / (500.0 + dist * dist * 0.001 + dist);

    // 5. Combine final color
    // Base light intensity * path visibility * attenuation
    vec3 final_rgb = light_color * visibility * atten * 2.0;
    
    return vec4(final_rgb, 1.0);
}
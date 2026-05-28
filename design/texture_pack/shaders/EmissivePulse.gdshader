shader_type spatial;
render_mode cull_back, blend_mix;

uniform sampler2D albedo_tex : source_color;
uniform vec2 uv_scale = vec2(2.0, 2.0);
uniform vec3 emission_tint = vec3(0.1, 0.5, 1.0);
uniform float emission_strength = 0.5;

void fragment() {
    vec2 uv = UV * uv_scale;
    vec4 tex = texture(albedo_tex, uv);
    float pulse = 0.5 + 0.5 * sin(TIME * 2.0);
    ALBEDO = tex.rgb;
    EMISSION = tex.rgb * emission_tint * (emission_strength * (0.6 + pulse));
    ROUGHNESS = 0.4;
    METALLIC = 0.2;
}

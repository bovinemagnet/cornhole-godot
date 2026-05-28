shader_type spatial;
render_mode cull_back, blend_mix;

uniform sampler2D albedo_tex : source_color;
uniform vec2 uv_scale = vec2(2.0, 2.0);
uniform vec2 scroll_speed = vec2(0.02, 0.01);
uniform float roughness_value = 0.15;

void fragment() {
    vec2 uv = UV * uv_scale + TIME * scroll_speed;
    vec4 tex = texture(albedo_tex, uv);
    ALBEDO = tex.rgb;
    ROUGHNESS = roughness_value;
    METALLIC = 0.0;
}

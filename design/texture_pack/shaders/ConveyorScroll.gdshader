shader_type spatial;
render_mode cull_back, blend_mix;

uniform sampler2D albedo_tex : source_color;
uniform vec2 uv_scale = vec2(2.0, 2.0);
uniform vec2 scroll_speed = vec2(0.12, 0.0);

void fragment() {
    vec2 uv = UV * uv_scale + TIME * scroll_speed;
    vec4 tex = texture(albedo_tex, uv);
    ALBEDO = tex.rgb;
    ROUGHNESS = 0.55;
    METALLIC = 0.8;
}

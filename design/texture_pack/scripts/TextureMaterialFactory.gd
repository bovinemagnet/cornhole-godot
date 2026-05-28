extends RefCounted
class_name TextureMaterialFactory

static func create_material(base_path: String, tex_def: Dictionary) -> Material:
    var tex_path := base_path.path_join(tex_def.get("albedo_texture", ""))
    var shader_type := tex_def.get("material", {}).get("shader", "standard")
    var uv_scale_arr = tex_def.get("material", {}).get("uv_scale", [1.0, 1.0])
    var uv_scale := Vector3(float(uv_scale_arr[0]), float(uv_scale_arr[1]), 1.0)
    var albedo_tex := load(tex_path)
    if shader_type == "scrolling_water":
        var mat := ShaderMaterial.new()
        mat.shader = load(base_path.path_join("shaders/ScrollingWater.gdshader"))
        mat.set_shader_parameter("albedo_tex", albedo_tex)
        mat.set_shader_parameter("uv_scale", Vector2(uv_scale_arr[0], uv_scale_arr[1]))
        return mat
    if shader_type == "conveyor_scroll":
        var mat2 := ShaderMaterial.new()
        mat2.shader = load(base_path.path_join("shaders/ConveyorScroll.gdshader"))
        mat2.set_shader_parameter("albedo_tex", albedo_tex)
        mat2.set_shader_parameter("uv_scale", Vector2(uv_scale_arr[0], uv_scale_arr[1]))
        return mat2
    if shader_type == "emissive_pulse":
        var mat3 := ShaderMaterial.new()
        mat3.shader = load(base_path.path_join("shaders/EmissivePulse.gdshader"))
        mat3.set_shader_parameter("albedo_tex", albedo_tex)
        mat3.set_shader_parameter("uv_scale", Vector2(uv_scale_arr[0], uv_scale_arr[1]))
        return mat3
    var mat_std := StandardMaterial3D.new()
    mat_std.albedo_texture = albedo_tex
    mat_std.roughness = float(tex_def.get("material", {}).get("roughness", 1.0))
    mat_std.metallic = float(tex_def.get("material", {}).get("metallic", 0.0))
    mat_std.uv1_scale = uv_scale
    return mat_std

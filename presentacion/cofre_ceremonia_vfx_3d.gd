class_name CofreCeremoniaVfx3D
extends RefCounted

static func abanico(color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var a: float = lerpf(-0.95, 0.95, i / 7.0)
		var b: float = lerpf(-0.95, 0.95, (i + 1) / 7.0)
		st.set_color(Color(color, 0.35))
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(color, 0.0))
		st.add_vertex(Vector3(sin(a) * 1.25, cos(a) * 1.6, 0))
		st.add_vertex(Vector3(sin(b) * 1.25, cos(b) * 1.6, 0))
	m.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

static func aro(color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for vuelta in 2:
		for k in 120:
			for j in 2:
				var a: float = (k + j) * TAU / 120.0
				var r: float = 0.63 + (0.035 if vuelta == 1 else -0.035) * cos(a * 12)
				im.surface_set_uv(Vector2((k + j) / 120.0, vuelta))
				im.surface_add_vertex(Vector3(cos(a) * r, sin(a) * r, 0))
	im.surface_end()
	m.mesh = im
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, blend_add, cull_disabled; uniform vec4 color : source_color; uniform float progreso = 0.0; void fragment(){ ALBEDO = color.rgb; ALPHA = step(UV.x, progreso) * 0.85; }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", color)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

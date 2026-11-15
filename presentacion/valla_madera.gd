class_name VallaMadera
## Material de madera para la valla modular de Meshy (presentacion/valla_madera.gdshader): uno por malla, compartido.
##   mi.material_override = VallaMadera.material(mi.mesh)

const SHADER := preload("res://presentacion/valla_madera.gdshader")
const CORTEZA := "res://arte/texturas_madera/corteza_metasequoia_128.jpg"
const ALTO := "res://arte/texturas_madera/corteza_metasequoia_alto_128.png"
static var _por_textura := {}


static func material(malla: Mesh) -> Material:
	var original := malla.surface_get_material(0) as BaseMaterial3D
	if original == null or not ResourceLoader.exists(CORTEZA):
		return null
	var tex := original.albedo_texture
	if not _por_textura.has(tex):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("textura", tex)
		m.set_shader_parameter("corteza", load(CORTEZA))
		if ResourceLoader.exists(ALTO):
			m.set_shader_parameter("alto_corteza", load(ALTO))
		_por_textura[tex] = m
	return _por_textura[tex]

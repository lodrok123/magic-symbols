class_name SombraContacto3D
extends RefCounted
## La sombra de contacto: una mancha oscura y suave bajo todo lo que está en el suelo (Fase 14.2 · e).
##
## POR QUÉ ESTÁ APARTE. La maqueta ya dibujaba una elipse bajo cada pieza del decorado (`prueba_test2.gd`, `_construir_sombras`), pero con el
## borde duro y solo para los ids de una tabla; las piezas de puzle (`PiezaPuzle3D`) y las piezas nuevas de Meshy no la tenían. Las dos
## cosas usan ahora ESTE material, para que se vean iguales: en Echoes of Wisdom la sombra es una mancha que se funde con el suelo y
## ancla la pieza sin dibujar un contorno.
##
## POR QUÉ NO SSAO NI DECAL. Los dos solo existen en Forward+ y el proyecto también se prueba en Compatibilidad; un quad con un
## degradado radial se ve igual en ambos y cuesta una llamada de dibujo (MultiMesh).

## `dureza` 0 = degradado desde el centro hasta el borde · 1 = borde duro (el aspecto antiguo: disco plano).
const CODIGO: String = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform float alfa : hint_range(0.0, 1.0) = 0.34;
uniform float dureza : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color : source_color = vec3(0.04, 0.07, 0.05);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		discard;
	}
	// Centro denso y borde que se funde: 1 en el medio, 0 en el borde. La dureza empuja la curva hacia el disco plano.
	float suave = 1.0 - smoothstep(0.0, 1.0, r2);
	ALBEDO = color;
	ALPHA = alfa * mix(suave, 1.0, dureza);
}
"""


## El material compartido. `alfa` es la opacidad en el centro (0,34: algo más que el 0,30 del disco duro, porque el degradado
## promedia menos oscuro) y `dureza` cuánto se parece al disco antiguo.
static func material(alfa: float = 0.34, dureza: float = 0.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = -1       # primero: el resto de decals y la hierba se dibujan encima
	mat.set_shader_parameter("alfa", alfa)
	mat.set_shader_parameter("dureza", dureza)
	return mat


## Un cuadrado de lado 1 tumbado (el radio de cada sombra lo pone la escala de cada instancia).
static func malla(mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	q.material = mat
	return q


## Una sombra suelta (para una sola pieza, p. ej. las de PiezaPuzle3D): MeshInstance3D hijo de `padre`, a la altura `y` local, con los
## diámetros `diametro_x` y `diametro_z` (el del suelo de la pieza, algo más grande: la mancha asoma por los lados).
static func poner(padre: Node3D, diametro_x: float, diametro_z: float, y: float = 0.01, alfa: float = 0.34) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "sombra_contacto"
	mi.mesh = malla(material(alfa))
	mi.scale = Vector3(diametro_x, 1.0, diametro_z)
	mi.position = Vector3(0.0, y, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi

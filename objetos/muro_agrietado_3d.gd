class_name MuroAgrietado3D
extends Area3D

## MURO AGRIETADO (bloque 2 de la revisión EoW, 23/10). Un bloque de piedra que tapa su casilla y se ROMPE: con `golpes` impactos de TIERRA
## (2 de serie) o de una vez con una EXPLOSIÓN (Barril3D: está en el grupo `explosionable`). Al romperse se deshace por celdas, suelta polvo
## y piedrecitas, libera la casilla y emite `roto`. Lo demás (fuego, agua, rayo…) no le hace nada y lo atraviesa el borde de luz
## (`spell_reacts` solo dice que sí a la tierra), pero la casilla es sólida: los proyectiles se paran en ella igual.
##
## EL ASPECTO lo da un shader propio (sin textura): sillares de piedra con juntas y GRIETAS de Voronoi en coordenadas del objeto. Ya nace con
## algunas (se lee como «esto se puede romper», como los muros agrietados de EoW, cuyo material `Crack` pinta la grieta por encima); cada
## golpe de tierra abre más y el muro tiembla. Al romperse, el mismo disolver por celdas del material común (Ocluso3D, V6).
##
## CON MODELO (la Cueva, 23/10): si existe la pieza `muro_agrietado` (el bloque de sillares de la lámina de Tripo), se usa ella con el
## material común (que sabe deshacerse por celdas) y las grietas van en una CAPA encima (`material_overlay`, `CODIGO_CAPA`). Sin el modelo,
## la caja con el shader de arriba, como antes.
##
## Se coloca desde un mapa con `; pieza <id> muro <x> <y> [golpes=<n>]` (escenas/puzle.gd) o con `preparar` desde código.

signal roto

const ALTO: float = 1.6
const GRIETAS_INICIO: float = 0.3       ## las que tiene sin tocar
const T_DESHACER: float = 0.7

const CODIGO: String = """
shader_type spatial;
uniform vec3 piedra : source_color = vec3(0.60, 0.57, 0.52);
uniform vec3 junta : source_color = vec3(0.33, 0.31, 0.28);
uniform vec3 fondo_grieta : source_color = vec3(0.12, 0.10, 0.09);
uniform vec4 brillo_grieta : source_color = vec4(1.0, 0.72, 0.4, 1.0);
uniform float grietas : hint_range(0.0, 1.0) = 0.3;
uniform float disolver : hint_range(0.0, 1.0) = 0.0;
uniform float alto = 1.6;
varying vec3 po;

float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
// x = id de la celda, y = distancia al punto, z = distancia al borde.
vec3 voronoi(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				float d = length(g + h33(ip + g) - fp);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = h31(ip + g + 17.0);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(id, d1, d2 - d1);
}

void vertex() {
	po = VERTEX;
}

void fragment() {
	// Deshacerse por celdas (como el disolver del decorado): lo alto se va antes; las que están a punto, brillan.
	vec3 vd = voronoi(po / 0.22);
	float altura = clamp(po.y / alto + 0.5, 0.0, 1.0);
	float vida = mix(vd.x, 1.0 - altura, 0.3);
	float resto = vida - disolver * 1.2;
	if (disolver > 0.0 && resto < 0.0) {
		discard;
	}
	// Sillares: hiladas de 0,4 m, cada una desplazada media pieza; juntas oscuras y algo de ruido de valor.
	float fila = floor((po.y + 10.0) / 0.4);
	vec2 q = vec2(po.x + po.z + fila * 0.33, po.y + 10.0) / vec2(0.66, 0.4);
	vec2 f = fract(q);
	float en_junta = 1.0 - smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x) * 0.66, min(f.y, 1.0 - f.y) * 0.4));
	float matiz = h31(vec3(floor(q), fila)) * 0.12 - 0.06;
	vec3 c = piedra * (1.0 + matiz);
	c = mix(c, junta, en_junta * 0.8);
	// GRIETAS: bordes de Voronoi grandes; las celdas con id menor que `grietas` muestran su borde (más golpes, más celdas). Una segunda escala,
	// más fina, solo cuando ya está muy agrietado.
	vec3 vg = voronoi(po / 0.45 + vec3(3.1, 0.0, 7.3));
	float g1 = (1.0 - smoothstep(0.0, 0.06, vg.z)) * step(vg.x, grietas);
	vec3 vf = voronoi(po / 0.2 + vec3(11.0, 5.0, 2.0));
	float g2 = (1.0 - smoothstep(0.0, 0.05, vf.z)) * step(vf.x, max(grietas - 0.5, 0.0) * 1.5);
	float grieta = max(g1, g2 * 0.8);
	c = mix(c, fondo_grieta, grieta);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// Dentro de la grieta, un fulgor terroso muy leve (la pista de que se rompe), y el borde de lo que se deshace.
	vec3 em = brillo_grieta.rgb * grieta * 0.35 * grietas;
	if (disolver > 0.0) {
		em += brillo_grieta.rgb * (1.0 - smoothstep(0.0, 0.2, resto)) * 2.0;
	}
	EMISSION = em;
}
"""

## Las grietas sobre el MODELO: una capa encima (material_overlay) con los mismos bordes de Voronoi que la caja, oscuras y con un fulgor terroso.
const CODIGO_CAPA: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform float grietas : hint_range(0.0, 1.0) = 0.3;
uniform vec4 fondo_grieta : source_color = vec4(0.10, 0.08, 0.07, 1.0);
uniform vec4 brillo_grieta : source_color = vec4(1.0, 0.72, 0.4, 1.0);
varying vec3 po;

float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
vec3 voronoi(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				float d = length(g + h33(ip + g) - fp);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = h31(ip + g + 17.0);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(id, d1, d2 - d1);
}

void vertex() {
	po = VERTEX * length(MODEL_MATRIX[0].xyz);
}

void fragment() {
	vec3 vg = voronoi(po / 0.45 + vec3(3.1, 0.0, 7.3));
	float g1 = (1.0 - smoothstep(0.0, 0.06, vg.z)) * step(vg.x, grietas);
	vec3 vf = voronoi(po / 0.2 + vec3(11.0, 5.0, 2.0));
	float g2 = (1.0 - smoothstep(0.0, 0.05, vf.z)) * step(vf.x, max(grietas - 0.5, 0.0) * 1.5);
	float grieta = max(g1, g2 * 0.8);
	ALBEDO = fondo_grieta.rgb;
	EMISSION = brillo_grieta.rgb * grieta * 0.35 * grietas;
	ALPHA = grieta * 0.9;
}
"""

var celda: Vector2i = Vector2i.ZERO
var golpes: int = 2                     ## impactos de tierra que aguanta
var recibidos: int = 0
var roto_ya: bool = false
var grietas: float = GRIETAS_INICIO     ## las grietas que se ven ahora (0..1)
var _cuerpo: Node3D = null
var _mat: ShaderMaterial = null         ## la caja (sin modelo)
var _capa: ShaderMaterial = null        ## las grietas encima del modelo
var _mats_modelo: Array[ShaderMaterial] = []
var _mundo: Node = null


## `mundo` = la maqueta (da el modelo con su escala de `Pieza3D.MEDIDA_ANCHO`); sin ella se carga `arte/piezas/muro_agrietado.tscn`.
func preparar(p_celda: Vector2i, p_golpes: int = 2, mundo: Node = null) -> void:
	_mundo = mundo
	celda = p_celda
	golpes = maxi(p_golpes, 1)
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	Terreno3D.bloquear_celda(celda)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	add_to_group("explosionable")
	var ancho: float = Terreno3D.casilla * 0.96
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ancho, ALTO, ancho)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(forma)
	if _poner_modelo():
		return
	var sh := Shader.new()
	sh.code = CODIGO
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("alto", ALTO)
	_mat.set_shader_parameter("grietas", GRIETAS_INICIO)
	_cuerpo = MeshInstance3D.new()
	_cuerpo.name = "muro"
	var b := BoxMesh.new()
	b.size = Vector3(ancho, ALTO, ancho)
	_cuerpo.mesh = b
	_cuerpo.material_override = _mat
	_cuerpo.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(_cuerpo)


## El modelo de sillares con el material común y la capa de grietas. false si no hay modelo.
func _poner_modelo() -> bool:
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", "muro_agrietado") as Node3D
	if n == null and ResourceLoader.exists("res://arte/piezas/muro_agrietado.tscn"):
		var escena: PackedScene = load("res://arte/piezas/muro_agrietado.tscn") as PackedScene
		n = escena.instantiate() as Node3D if escena != null else null
	if n == null:
		return false
	n.name = "muro"
	add_child(n)
	_cuerpo = n
	_mats_modelo = Ocluso3D.convertir_nodo(n)
	var sh := Shader.new()
	sh.code = CODIGO_CAPA
	_capa = ShaderMaterial.new()
	_capa.shader = sh
	_capa.set_shader_parameter("grietas", grietas)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = _capa
	return true


func _poner_grietas(v: float) -> void:
	grietas = v
	if _capa != null:
		_capa.set_shader_parameter("grietas", v)
	if _mat != null:
		_mat.set_shader_parameter("grietas", v)


func _poner_disolver(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("disolver", v)
	for m in _mats_modelo:
		Ocluso3D.poner_disolver(m, v)
	if _mats_modelo.is_empty() and _mat == null and _cuerpo != null:
		_cuerpo.scale = Vector3.ONE * maxf(1.0 - v, 0.01)        # sin material común (Ocluso sin preparar): se encoge


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data == null or roto_ya or not rune_data.tags.has("tierra"):
		return
	recibidos += 1
	if recibidos >= golpes:
		romper()
		return
	_agrietar(float(recibidos) / float(golpes))


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return rune_data != null and not roto_ya and rune_data.tags.has("tierra")


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## Barril3D: una explosión al alcance lo rompe de una vez.
func recibir_explosion(_punto: Vector3) -> void:
	romper()


## --- Romperse ---

func romper() -> void:
	if roto_ya:
		return
	roto_ya = true
	collision_layer = 0                     # el nodo se queda (los puzles lo consultan), pero ya no se golpea
	remove_from_group("explosionable")
	Terreno3D.liberar_celda(celda)
	Sfx.play(self, "derrumbe")
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 1.1)
	_poner_grietas(1.0)
	if _cuerpo != null and _capa != null:
		for g in _cuerpo.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).material_overlay = null      # la capa no se deshace con las celdas: fuera
	var tw: Tween = create_tween()
	tw.tween_method(_poner_disolver, 0.0, 1.0, T_DESHACER).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _cuerpo.visible = false)
	roto.emit()


## Abre más grietas (`fraccion` 0..1 de los golpes que lleva) y tiembla un instante.
func _agrietar(fraccion: float) -> void:
	_poner_grietas(lerpf(GRIETAS_INICIO, 0.85, fraccion))
	Sfx.play(self, "tierra")
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 0.5)
	var base: Vector3 = _cuerpo.position
	var tw: Tween = create_tween()
	for i in range(4):
		tw.tween_property(_cuerpo, "position", base + Vector3(randf_range(-0.04, 0.04), 0.0, randf_range(-0.04, 0.04)), 0.04)
	tw.tween_property(_cuerpo, "position", base, 0.04)

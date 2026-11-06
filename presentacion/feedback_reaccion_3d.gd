class_name FeedbackReaccion3D
extends RefCounted

## E2 (6/11/2026, docs/PROPUESTAS_COMBATE_2026-11-06.md bloque E): la reacción tiene SU PROPIO destello y SU PROPIO sonido, aparte de los del golpe.
## Fallo que evita: cuando saltaba «congela» o «electrocuta» sobre un enemigo, lo único que se oía y veía era lo mismo que un golpe cualquiera (la reacción, que es la recompensa
## clave del combate, no se distinguía de un golpe flojo).
## Escucha `Mundo3D.reaccion(nombre, punto, nodo)` (la misma señal que `ReaccionesVfx3D` y `TintaReaccion`; se engancha desde `ReaccionesVfx3D.conectar`, así que donde esté
## el efecto de la reacción está también este). Por cada reacción sobre un ENEMIGO pinta un anillo y un disco de destello en el suelo, del color de la previsión
## (`PrevisionReaccion3D.ESTILO`, para que lo que se vio antes de soltar el hechizo sea lo que se ve al saltar) y, en las reacciones fuertes, suena un tintineo con un tono por familia.
## NO toca el rótulo de texto: ese vive en `Combate3D._numero` (archivo ajeno a este encargo). Ver el informe: ahí habría que usar `color_de(aviso)` y una escala mayor.

static var ACTIVO: bool = true                 ## false = ni anillo ni sonido (los avisos de las reacciones siguen su camino)
static var RADIO_ANILLO: float = 0.45          ## u: radio del anillo al nacer (× el peso de la familia); crece hasta ESCALA_FIN veces
static var ESCALA_FIN: float = 1.9
static var T_ANILLO: float = 0.38              ## s que tarda el anillo en abrirse y apagarse
static var ALFA_ANILLO: float = 0.95
static var ALFA_DESTELLO: float = 0.55         ## opacidad del disco que parpadea en el centro
static var T_DESTELLO: float = 0.14            ## s que dura ese disco
static var ALTO_SUELO: float = 0.09            ## u sobre los pies: lo justo para que no se funda con el suelo
static var SONIDO: String = "ping_debil"       ## PENDIENTE DE SONIDO PROPIO: no hay un tintineo de «reacción»; se reutiliza el de debilidad cambiando el tono por familia (TONOS)

## aviso de `Mundo3D.REACCIONES` -> [clave de PrevisionReaccion3D.ESTILO, peso del anillo, tono del tintineo (0 = sin sonido: la reacción es frecuente y suave)].
const FAMILIAS: Dictionary = {
	"prendido":      ["prende", 1.0, 0.85],
	"apagado_agua":  ["apaga", 1.0, 1.0],
	"consumido":     ["arde", 0.8, 0.0],
	"mojado":        ["moja", 0.8, 0.0],
	"secado":        ["seca", 0.8, 0.0],
	"congelado":     ["congela", 1.25, 1.55],
	"derretido":     ["derrite", 1.0, 1.15],
	"electrocutado": ["electrocuta", 1.25, 1.3],
	"hundido":       ["hunde", 1.25, 0.7],
	"aturdido":      ["aturde", 1.0, 1.1],
	"empujado":      ["empuja", 0.8, 0.0],
	"roto":          ["rompe_x2", 1.35, 1.7],      # 6/11 bloque B: el remate suena más agudo que el congelado (1,55)
	"llamarada":     ["llamarada", 1.25, 0.9],
	"cegado":        ["ciega", 0.9, 0.0],
	"enraizado":     ["enraiza", 1.1, 0.8],        # 6/11 R3: tono grave, de raíz que agarra (la clave «enraiza» debe existir en PrevisionReaccion3D.ESTILO)
}

## Lo último que se hizo, para las pruebas: {aviso, estilo, color, tono, anillo}.
static var ultimo: Dictionary = {}
static var cuenta: int = 0
static var _fx: Node3D = null


## Se engancha a `reaccion` de `mundo` (idempotente). Devuelve false si no tiene la señal.
static func conectar(mundo: Object, padre_fx: Node3D) -> bool:
	if mundo == null or not mundo.has_signal("reaccion"):
		return false
	_fx = padre_fx
	var f := Callable(FeedbackReaccion3D, "_al_reaccionar")
	if not mundo.is_connected("reaccion", f):
		mundo.connect("reaccion", f)
	return true


static func _al_reaccionar(nombre: String, punto: Vector3, nodo: Node = null) -> void:
	reaccion(nombre, punto, nodo, _fx)


## Color de la reacción `aviso` (el de la previsión). Blanco si no se conoce.
static func color_de(aviso: String) -> Color:
	if not FAMILIAS.has(aviso):
		return Color.WHITE
	return PrevisionReaccion3D._color(String((FAMILIAS[aviso] as Array)[0]))


## Hace el feedback de la reacción `aviso` sobre `nodo`. Solo para enemigos (las piezas ya tienen su efecto). Devuelve lo hecho ({} si nada).
static func reaccion(aviso: String, punto: Vector3, nodo: Node, padre_fx: Node3D = null) -> Dictionary:
	if not ACTIVO or not FAMILIAS.has(aviso) or not (nodo is Combate3D) or not is_instance_valid(nodo):
		return {}
	var fam: Array = FAMILIAS[aviso]
	var col: Color = color_de(aviso)
	var tono: float = float(fam[2])
	var hecho: Dictionary = {"aviso": aviso, "estilo": String(fam[0]), "color": col, "tono": tono, "anillo": float(fam[1]) * RADIO_ANILLO}
	ultimo = hecho
	cuenta += 1
	var c: Node3D = nodo as Node3D
	if c.is_inside_tree():
		if tono > 0.0:
			Sfx.play(c, SONIDO, tono)
		var padre: Node3D = padre_fx if padre_fx != null and is_instance_valid(padre_fx) and padre_fx.is_inside_tree() else (c.get_parent() as Node3D)
		if padre != null and padre.is_inside_tree():
			_dibujar(padre, Vector3(c.global_position.x, c.global_position.y + ALTO_SUELO, c.global_position.z), col, float(hecho["anillo"]))
	return hecho


static func _dibujar(padre: Node3D, pos: Vector3, col: Color, radio: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true                                   # se ve aunque el cuerpo del enemigo lo tape un poco
	m.albedo_color = Color(col, ALFA_ANILLO)
	var t := TorusMesh.new()
	t.inner_radius = radio - 0.06
	t.outer_radius = radio
	t.rings = 32
	t.ring_segments = 4
	t.material = m
	var anillo := MeshInstance3D.new()
	anillo.mesh = t
	anillo.scale = Vector3(1.0, 0.05, 1.0)
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(anillo)
	anillo.global_position = pos
	var tw: Tween = anillo.create_tween()
	tw.set_parallel(true)
	tw.tween_property(anillo, "scale", Vector3(ESCALA_FIN, 0.05, ESCALA_FIN), T_ANILLO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, T_ANILLO).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(anillo.queue_free)
	var md := StandardMaterial3D.new()
	md.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	md.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	md.no_depth_test = true
	md.albedo_color = Color(col.lerp(Color.WHITE, 0.4), ALFA_DESTELLO)
	var d := CylinderMesh.new()
	d.top_radius = radio * 0.9
	d.bottom_radius = radio * 0.9
	d.height = 0.02
	d.material = md
	var disco := MeshInstance3D.new()
	disco.mesh = d
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(disco)
	disco.global_position = pos
	var tw2: Tween = disco.create_tween()
	tw2.tween_property(md, "albedo_color:a", 0.0, T_DESTELLO).set_ease(Tween.EASE_OUT)
	tw2.tween_callback(disco.queue_free)

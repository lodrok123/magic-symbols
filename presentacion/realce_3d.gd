class_name Realce3D
extends Node
## RESALTADO DE LO QUE REACCIONA (bloque 2 de la revisión EoW, 23/10). Mientras el libro está abierto o se apunta un hechizo, los objetos
## que reaccionarían a ese hechizo se marcan con un borde de luz (fresnel) que late despacio; el que está bajo el punto apuntado, más fuerte.
##
## POR QUÉ. EoW tiene pasadas de contorno (`pfx_outline`, `edge_color`): en un puzle lo difícil no es lanzar, es saber QUÉ reacciona. Aquí se
## responde con el mismo contrato de los hechizos: un objeto se resalta si es un Area3D de `Lanzador3D.CAPA_REACTIVO` con `on_spell_hit` y,
## si hay página preparada, su `spell_reacts(runa)` dice que sí. Así una página de fuego enseña braseros y setos, y una de agua los tótems
## de agua; con el libro abierto (aún sin elegir) se ve todo lo que reacciona a algo. Los enemigos (`combate3d`) no se resaltan.
##
## CÓMO. Un `material_overlay` (el modelo se dibuja otra vez, sumando el borde) en las mallas del objeto: no toca sus materiales. Si una malla ya
## lleva otro overlay (la costra de hielo, la cuerda que arde, el mojado de una pieza de fuego), se respeta y esa malla no se resalta.
## Se monta una vez por escena (`montar`) y no cuesta nada mientras no se apunta.

static var activo: bool = true

const RADIO_CASILLAS: float = 6.0       ## lo que está más lejos del jugador no se resalta (6 casillas: el alcance máximo de una flecha)
const FUERZA: float = 0.6               ## borde de lo que reacciona
const FUERZA_APUNTADO: float = 1.0      ## borde de lo que está bajo el punto apuntado
const RADIO_APUNTADO: float = 0.8       ## casillas: a cuánto del punto apuntado cuenta como «apuntado»
const COLOR: Color = Color(1.0, 0.92, 0.7)
const CADA_BUSCAR: float = 1.0          ## s entre búsquedas de objetos (se crean y se rompen pocas veces)

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform float fuerza = 0.0;
void fragment() {
	// Con la cámara casi cenital casi todas las caras miran a cámara y el fresnel solo no se ve: un velo suave en todo el modelo y el
	// borde más marcado encima.
	float borde = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	float late = 0.75 + 0.25 * sin(TIME * 4.0);
	ALBEDO = color.rgb;
	ALPHA = clamp((0.18 + borde) * fuerza * late, 0.0, 1.0);
}
"""

var _lanz: Lanzador3D = null
var _raiz: Node = null
var _shader: Shader = null
var _candidatos: Array[Area3D] = []
var _t_buscar: float = 0.0
var _puestos: Dictionary = {}           ## Area3D -> ShaderMaterial (el overlay que le hemos puesto)


## Lo cuelga de `raiz` (la escena) y lo engancha al lanzador. Devuelve el nodo.
static func montar(lanz: Lanzador3D, raiz: Node) -> Realce3D:
	var r := Realce3D.new()
	r.name = "Realce3D"
	r._lanz = lanz
	r._raiz = raiz
	raiz.add_child(r)
	return r


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = CODIGO
	process_mode = Node.PROCESS_MODE_ALWAYS       # el libro abierto ralentiza (y una pantalla puede pausar): el borde se pone igual


func _process(delta: float) -> void:
	var encendido: bool = activo and _lanz != null and is_instance_valid(_lanz) and (_lanz.modo_lanzar or _lanz.libro_abierto())
	if not encendido:
		if not _puestos.is_empty():
			_quitar_todo()
		_t_buscar = CADA_BUSCAR             # al volver a encender, busca enseguida
		return
	_t_buscar += delta
	if _t_buscar >= CADA_BUSCAR:
		_t_buscar = 0.0
		_buscar()
	var runa: RuneData = null
	if _lanz.modo_lanzar and _lanz._preparado.has("rune"):
		runa = _lanz._preparado["rune"] as RuneData
	var casilla: float = Terreno3D.casilla
	var pj: Vector3 = _lanz.jugador.position if _lanz.jugador != null else Vector3.ZERO
	var apuntado: Vector3 = _lanz._punto_vivo if _lanz.modo_lanzar else Vector3.INF
	var vivos: Dictionary = {}
	for o in _candidatos:
		if not is_instance_valid(o) or not o.is_inside_tree() or (o.collision_layer & Lanzador3D.CAPA_REACTIVO) == 0:
			continue
		var d: Vector3 = o.global_position - pj
		d.y = 0.0
		if d.length() > RADIO_CASILLAS * casilla:
			continue
		if runa != null and o.has_method("spell_reacts") and not bool(o.call("spell_reacts", runa, Vector3.ZERO)):
			continue
		var da: Vector3 = o.global_position - apuntado
		da.y = 0.0
		var fuerza: float = FUERZA_APUNTADO if apuntado != Vector3.INF and da.length() <= RADIO_APUNTADO * casilla else FUERZA
		_poner(o, fuerza)
		vivos[o] = true
	for o in _puestos.keys():
		if not vivos.has(o):
			_quitar(o)


## Todo lo que puede recibir un hechizo: Area3D de la capa de reactivos con `on_spell_hit`, menos los enemigos.
func _buscar() -> void:
	_candidatos.clear()
	if _raiz == null or not is_instance_valid(_raiz):
		return
	for n in _raiz.find_children("*", "Area3D", true, false):
		var a: Area3D = n as Area3D
		if (a.collision_layer & Lanzador3D.CAPA_REACTIVO) == 0 or not a.has_method("on_spell_hit"):
			continue
		if a.is_in_group("combate3d") or a.is_in_group("goblins"):
			continue
		_candidatos.append(a)


func _poner(o: Area3D, fuerza: float) -> void:
	var mat: ShaderMaterial = _puestos.get(o)
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("color", COLOR)
		_puestos[o] = mat
		for m in o.find_children("*", "GeometryInstance3D", true, false):
			var g: GeometryInstance3D = m as GeometryInstance3D
			if g.material_overlay == null:
				g.material_overlay = mat
	mat.set_shader_parameter("fuerza", fuerza)


func _quitar(o: Object) -> void:
	var mat: ShaderMaterial = _puestos.get(o)
	_puestos.erase(o)
	if mat == null or not is_instance_valid(o):
		return
	for m in (o as Node).find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = m as GeometryInstance3D
		if g.material_overlay == mat:
			g.material_overlay = null


func _quitar_todo() -> void:
	for o in _puestos.keys():
		_quitar(o)
	_puestos.clear()

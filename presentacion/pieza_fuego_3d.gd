class_name PiezaFuego3D
extends Node3D

## PIEZAS DEL LABORATORIO DE FUEGO (Fase 14.5 · T6 c/d, 16/10, Pipeline). Cuerda, contador, leña, hoguera, caldera, antorchas, baldosa falsa y
## escudo del goblin, dibujados con primitivas mientras no existan los modelos de Meshy (prompts: `arte/meshy/PROMPTS_LAB_FUEGO.md`).
## Con modelos de Meshy: las 17 salen de dos láminas separadas (`res://arte/meshy/fuego/fuego_medieval.glb` y `fuego_rustic.glb`, un nodo por pieza con su
## id, ya orientadas, a escala y con el origen puesto; ARTE §14). También vale un GLB suelto `res://arte/meshy/fuego/<id>.glb` (se escala a la medida de abajo).
## Sin ninguno de los dos cae a las primitivas: el Juego llama igual en los tres casos. Mismo método que `PiezaPuzle3D` (diario 98 y 106).
##
## Uso:   var p := PiezaFuego3D.crear("caldera_cuerpo"); padre.add_child(p); p.poner_calor(0.5)
##        PiezaFuego3D.crear(id, {"modelos": false})  fuerza las primitivas;  PiezaFuego3D.usar_modelos = false lo hace para todas.
##
## ORIGEN: el centro de la BASE (y = 0 el suelo), salvo `cuerda_tensa` y `cuerda_cabo`, que cuelgan de su nudo (el origen es el punto de agarre y
## el cuerpo va hacia −Y) y `goblin_escudo_*`, cuyo origen es el centro del disco. Frente hacia +Z. Unidades de juego (la casilla mide 2,3; la jugadora ~1).
##
## ESTADOS (lo que el Juego llama; todo es visual, no cambia colisiones ni lógica):
##   caldera_cuerpo   poner_calor(f)        0 fría · 0,5 caliente · 1 al rojo (hierro que se pone rojo oscuro, brillo y una luz)
##   caldera_medidor  poner_calor(f)        sube el índice; el tubo se llena del color del calor
##   goblin_escudo    poner_estado(e)       "entero" | "ardiendo" | "quemado" (los dos GLB/mallas están siempre; se muestra el que toca)
##   contador_placa   poner_cuenta(n, de)   enciende `n` de los `de` huecos (por defecto 4)
##   fogata_lenos     poner_lenos(n)        muestra de 0 a 3 leños
##   antorcha_*       poner_llama(si)       llama y luz de la antorcha (el Juego puede poner la suya; esto es la del Pipeline)
##   baldosa_falsa    caer()                se hunde y desaparece (dura `T_CAER` s) y emite `terminado`
##   cualquiera       PiezaFuego3D.mojado(nodo, si)   oscurece y moja cualquier visual (el seto mojado, 12 s en `Reactivo3D.esta_mojado`)

signal terminado

const RUTA: String = "res://arte/meshy/fuego/"
## Qué lámina trae cada pieza (el nodo de la lámina se llama como el id).
const HOJA: Dictionary = {
	"caldera_hogar": "fuego_medieval", "caldera_cuerpo": "fuego_medieval", "goblin_escudo_quemado": "fuego_medieval", "goblin_escudo_entero": "fuego_medieval",
	"antorcha_pared": "fuego_medieval", "antorcha_pie": "fuego_medieval", "caldera_medidor": "fuego_medieval", "baldosa_falsa": "fuego_medieval",
	"caldera_indice": "fuego_medieval",
	"fogata_apagada": "fuego_rustic", "cuerda_poste": "fuego_rustic", "contador_placa": "fuego_rustic", "cuerda_caida": "fuego_rustic",
	"fogata_lenos": "fuego_rustic", "cuerda_tensa": "fuego_rustic", "cuerda_cabo": "fuego_rustic", "leno": "fuego_rustic",
}
const T_CAER: float = 0.5

## Medida de cada pieza (X, Y, Z) en unidades de juego y por dónde se escala el modelo ("alto" o "ancho"). Son las de los prompts.
const MEDIDA: Dictionary = {
	"cuerda_poste": [Vector3(0.5, 1.9, 0.3), "alto"], "cuerda_tensa": [Vector3(0.14, 1.3, 0.14), "alto"],
	"cuerda_cabo": [Vector3(0.14, 0.35, 0.14), "alto"], "cuerda_caida": [Vector3(1.1, 0.12, 0.9), "ancho"],
	"contador_placa": [Vector3(1.6, 0.65, 0.2), "ancho"],
	"leno": [Vector3(0.5, 0.14, 0.14), "ancho"], "fogata_apagada": [Vector3(1.4, 0.35, 1.4), "ancho"], "fogata_lenos": [Vector3(0.7, 0.9, 0.7), "alto"],
	"caldera_cuerpo": [Vector3(1.2, 0.9, 1.2), "ancho"], "caldera_hogar": [Vector3(1.8, 0.25, 1.8), "ancho"],
	"caldera_medidor": [Vector3(0.3, 1.4, 0.25), "alto"], "caldera_indice": [Vector3(0.14, 0.14, 0.05), "ancho"],
	"antorcha_pared": [Vector3(0.3, 0.5, 0.9), "largo"], "antorcha_pie": [Vector3(0.45, 1.6, 0.45), "alto"],
	"baldosa_falsa": [Vector3(2.0, 0.2, 2.0), "ancho"],
	"goblin_escudo_entero": [Vector3(0.55, 0.55, 0.1), "ancho"], "goblin_escudo_quemado": [Vector3(0.55, 0.55, 0.1), "ancho"],
}

const C_MADERA: Color = Color(0.62, 0.45, 0.25)
const C_MADERA_OSC: Color = Color(0.40, 0.30, 0.20)
const C_MADERA_CLARA: Color = Color(0.86, 0.72, 0.50)
const C_PIEDRA: Color = Color(0.68, 0.68, 0.64)
const C_PIEDRA_OSC: Color = Color(0.45, 0.45, 0.44)
const C_HIERRO: Color = Color(0.26, 0.27, 0.31)
const C_SOGA: Color = Color(0.80, 0.68, 0.46)
const C_CARBON: Color = Color(0.13, 0.11, 0.10)
const C_CENIZA: Color = Color(0.56, 0.56, 0.54)
const C_LATON: Color = Color(0.92, 0.72, 0.26)
const C_ROJO_CALOR: Color = Color(0.95, 0.2, 0.05)

## Dónde están las cosas en el MODELO de Meshy (medido en la malla ya a escala): la punta de las antorchas, los cuatro huecos del contador y la ranura
## del medidor. Las primitivas llevan los suyos en su propio código.
const PUNTA_MODELO: Dictionary = {"antorcha_pared": Vector3(0.0, 0.85, 0.16), "antorcha_pie": Vector3(0.07, 1.6, -0.05)}
const HUECOS_MODELO: Array = [-0.44, -0.14, 0.17, 0.45]       ## x de los huecos del contador (y 0,28, z 0,2)
const RANURA_MODELO: Vector3 = Vector3(0.0, 0.22, 0.0)         ## base de la ranura del medidor; mide 0,9 de alto

static var usar_modelos: bool = true
static var _escenas: Dictionary = {}          ## id -> PackedScene o null (GLB suelto; se mira el disco una sola vez por id)
static var _mallas: Dictionary = {}           ## id -> Mesh o null (de las láminas; se leen una sola vez)

var id: String = ""
var medida: Vector3 = Vector3.ONE
var con_modelo: bool = false                  ## true si esta pieza salió del GLB de Meshy
var calor: float = 0.0
var estado: String = ""
var _mat_calor: Array[StandardMaterial3D] = []
var _luz: OmniLight3D = null
var _llama: Node3D = null
var _tw: Tween = null


## Nombres de pieza que sabe dibujar.
static func ids() -> PackedStringArray:
	return PackedStringArray(MEDIDA.keys())


static func existe(p_id: String) -> bool:
	return MEDIDA.has(p_id)


## Crea la pieza `p_id` (null si no existe). `opciones`: {"modelos": false} para forzar las primitivas.
static func crear(p_id: String, opciones: Dictionary = {}) -> PiezaFuego3D:
	if not MEDIDA.has(p_id):
		push_warning("PiezaFuego3D: no conozco la pieza «%s»" % p_id)
		return null
	var p := PiezaFuego3D.new()
	p.id = p_id
	p.name = p_id
	p.medida = (MEDIDA[p_id] as Array)[0]
	if usar_modelos and bool(opciones.get("modelos", true)):
		p.con_modelo = p._montar_modelo()
	if not p.con_modelo:
		p._montar_primitivas()
	p._preparar_estados()
	return p


## ¿Hay modelo para esta pieza (en su lámina o como GLB suelto)? Se cachea; sirve para el catálogo y las pruebas.
static func hay_modelo(p_id: String) -> bool:
	return malla_modelo(p_id) != null or _escena_suelta(p_id) != null


## El `Mesh` de la pieza en su lámina (ya orientado, a escala y con el origen puesto), o null si la lámina no existe o no trae ese nodo.
static func malla_modelo(p_id: String) -> Mesh:
	if _mallas.has(p_id):
		return _mallas[p_id]
	var hoja: String = String(HOJA.get(p_id, ""))
	var ruta: String = "%s%s.glb" % [RUTA, hoja]
	if hoja != "" and ResourceLoader.exists(ruta):
		var ps: PackedScene = load(ruta) as PackedScene
		if ps != null:
			var raiz: Node = ps.instantiate()
			for n in raiz.get_children():
				if n is MeshInstance3D:
					_mallas[String(n.name)] = (n as MeshInstance3D).mesh
			raiz.queue_free()
	if not _mallas.has(p_id):
		_mallas[p_id] = null
	return _mallas[p_id]


static func _escena_suelta(p_id: String) -> PackedScene:
	if not _escenas.has(p_id):
		var ruta: String = "%s%s.glb" % [RUTA, p_id]
		_escenas[p_id] = load(ruta) as PackedScene if ResourceLoader.exists(ruta) else null
	return _escenas[p_id]


# ---------------------------------------------------------------------------------------------------------------------------------
# Modelo de Meshy
# ---------------------------------------------------------------------------------------------------------------------------------

func _montar_modelo() -> bool:
	var malla: Mesh = malla_modelo(id)
	if malla != null:
		var mi := MeshInstance3D.new()
		mi.name = "modelo"
		mi.mesh = malla
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		return true
	if _escena_suelta(id) == null:
		return false
	var m: Node3D = _escena_suelta(id).instantiate() as Node3D
	if m == null:
		return false
	var caja: AABB = _caja_de(m, Transform3D.IDENTITY)
	if caja.size.length() < 0.0001:
		m.queue_free()
		return false
	var cfg: Array = MEDIDA[id]
	var ajuste: String = String(cfg[1])
	var k: float
	match ajuste:
		"alto": k = medida.y / maxf(caja.size.y, 0.0001)
		"largo": k = maxf(medida.x, maxf(medida.y, medida.z)) / maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
		_: k = medida.x / maxf(caja.size.x, 0.0001)
	m.scale = Vector3.ONE * k
	# Origen en el centro de la base (cuerda_tensa y cuerda_cabo cuelgan de su nudo: el origen es el extremo de arriba).
	var cuelga: bool = id == "cuerda_tensa" or id == "cuerda_cabo"
	var centrado: bool = id.begins_with("goblin_escudo")      # el escudo tiene el origen en su centro (el agarre), no en la base
	var ancla_y: float = caja.end.y if cuelga else (caja.position.y + caja.size.y * 0.5 if centrado else caja.position.y)
	m.position = Vector3(-(caja.position.x + caja.size.x * 0.5) * k, -ancla_y * k, -(caja.position.z + caja.size.z * 0.5) * k)
	m.name = "modelo"
	add_child(m)
	return true


func _caja_de(n: Node, acum: Transform3D) -> AABB:
	var r := AABB()
	var primero: bool = true
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		r = t * (n as MeshInstance3D).mesh.get_aabb()
		primero = false
	for h in n.get_children():
		var c: AABB = _caja_de(h, t)
		if c.size.length() > 0.0:
			r = c if primero else r.merge(c)
			primero = false
	return r


# ---------------------------------------------------------------------------------------------------------------------------------
# Primitivas
# ---------------------------------------------------------------------------------------------------------------------------------

static func _mat(c: Color, rug: float = 0.9, emision: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rug
	if emision > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emision
	return m


func _malla(nombre: String, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, padre: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	(padre if padre != null else self).add_child(mi)
	return mi


func _cil(nombre: String, r_alto: float, r_bajo: float, h: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, seg: int = 14, padre: Node3D = null) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_alto
	c.bottom_radius = r_bajo
	c.height = h
	c.radial_segments = seg
	return _malla(nombre, c, mat, pos, rot, padre)


func _esf(nombre: String, r: float, mat: Material, pos: Vector3, esc: Vector3 = Vector3.ONE, padre: Node3D = null) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	var mi: MeshInstance3D = _malla(nombre, s, mat, pos, Vector3.ZERO, padre)
	mi.scale = esc
	return mi


func _caja(nombre: String, tam: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, padre: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = tam
	return _malla(nombre, b, mat, pos, rot, padre)


func _toro(nombre: String, r_int: float, r_ext: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, padre: Node3D = null) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_int
	t.outer_radius = r_ext
	t.rings = 20
	t.ring_segments = 8
	return _malla(nombre, t, mat, pos, rot, padre)


func _montar_primitivas() -> void:
	match id:
		"cuerda_poste": _p_cuerda_poste()
		"cuerda_tensa": _p_cuerda_tensa()
		"cuerda_cabo": _p_cuerda_cabo()
		"cuerda_caida": _p_cuerda_caida()
		"contador_placa": _p_contador()
		"leno": _p_leno()
		"fogata_apagada": _p_fogata_apagada()
		"fogata_lenos": _p_fogata_lenos()
		"caldera_cuerpo": _p_caldera_cuerpo()
		"caldera_hogar": _p_caldera_hogar()
		"caldera_medidor": _p_medidor()
		"caldera_indice": _p_indice()
		"antorcha_pared": _p_antorcha_pared()
		"antorcha_pie": _p_antorcha_pie()
		"baldosa_falsa": _p_baldosa_falsa()
		"goblin_escudo_entero": _p_escudo(false)
		"goblin_escudo_quemado": _p_escudo(true)


## Cuerda: el poste de horca con un brazo hacia +X y una anilla de hierro de la que cuelga la cuerda (a x = 0,28, como en `Cuerda3D`).
func _p_cuerda_poste() -> void:
	var madera: StandardMaterial3D = _mat(C_MADERA_OSC)
	_cil("poste", 0.10, 0.14, 1.9, madera, Vector3(0.0, 0.95, 0.0), Vector3.ZERO, 10)
	_caja("brazo", Vector3(0.42, 0.10, 0.10), madera, Vector3(0.18, 1.82, 0.0))
	_caja("correa", Vector3(0.05, 0.14, 0.14), _mat(C_MADERA_CLARA), Vector3(0.02, 1.82, 0.0))
	_toro("anilla", 0.03, 0.07, _mat(C_HIERRO, 0.5), Vector3(0.28, 1.74, 0.0), Vector3(90.0, 0.0, 0.0))
	var piedra: StandardMaterial3D = _mat(C_PIEDRA)
	for i in 4:
		var a: float = i * TAU / 4.0 + 0.4
		_esf("piedra_%d" % i, 0.09, piedra, Vector3(cos(a) * 0.2, 0.05, sin(a) * 0.2), Vector3(1.0, 0.65, 1.0))


## Cuerda tensa: del nudo (origen) hacia abajo, recta, con el garfio al final.
func _p_cuerda_tensa() -> void:
	var soga: StandardMaterial3D = _mat(C_SOGA)
	_cil("cuerda", 0.07, 0.07, 1.2, soga, Vector3(0.0, -0.62, 0.0), Vector3.ZERO, 8)
	_esf("nudo", 0.09, soga, Vector3(0.0, -0.02, 0.0))
	_cil("garfio", 0.05, 0.05, 0.14, _mat(C_HIERRO, 0.5), Vector3(0.0, -1.27, 0.0), Vector3.ZERO, 8)


## Cabo: lo que queda colgando tras cortar la cuerda, con la punta chamuscada.
func _p_cuerda_cabo() -> void:
	_esf("nudo", 0.09, _mat(C_SOGA), Vector3(0.0, -0.02, 0.0))
	_cil("cabo", 0.07, 0.07, 0.2, _mat(C_SOGA), Vector3(0.0, -0.12, 0.0), Vector3.ZERO, 8)
	_cil("punta", 0.07, 0.05, 0.1, _mat(C_CARBON), Vector3(0.0, -0.27, 0.0), Vector3.ZERO, 8)


## Cuerda caída: un rollo en el suelo y un cabo suelto con la punta quemada.
func _p_cuerda_caida() -> void:
	var soga: StandardMaterial3D = _mat(C_SOGA)
	_toro("rollo", 0.16, 0.32, soga, Vector3(-0.2, 0.06, 0.0))
	_toro("rollo_2", 0.14, 0.26, soga, Vector3(-0.2, 0.1, 0.0))
	_cil("cabo", 0.06, 0.06, 0.7, soga, Vector3(0.28, 0.06, 0.18), Vector3(0.0, 0.0, 90.0), 8)
	_cil("punta", 0.06, 0.04, 0.12, _mat(C_CARBON), Vector3(0.66, 0.06, 0.18), Vector3(0.0, 0.0, 90.0), 8)
	_cil("garfio", 0.05, 0.05, 0.14, _mat(C_HIERRO, 0.5), Vector3(-0.55, 0.06, 0.1), Vector3(0.0, 0.0, 90.0), 8)


## Placa del contador: una losa con cuatro huecos redondos vacíos. `poner_cuenta` enciende gemas dentro de los huecos.
func _p_contador() -> void:
	var piedra: StandardMaterial3D = _mat(C_PIEDRA)
	_caja("losa", Vector3(1.6, 0.45, 0.2), piedra, Vector3(0.0, 0.425, 0.0))
	_caja("pata_i", Vector3(0.22, 0.2, 0.18), _mat(C_PIEDRA_OSC), Vector3(-0.6, 0.1, 0.0))
	_caja("pata_d", Vector3(0.22, 0.2, 0.18), _mat(C_PIEDRA_OSC), Vector3(0.6, 0.1, 0.0))
	for i in 4:
		var x: float = -0.6 + i * 0.4
		_toro("aro_%d" % i, 0.085, 0.12, _mat(C_PIEDRA_OSC), Vector3(x, 0.45, 0.105), Vector3(90.0, 0.0, 0.0))
		_cil("hueco_%d" % i, 0.085, 0.085, 0.02, _mat(C_CARBON), Vector3(x, 0.45, 0.101), Vector3(90.0, 0.0, 0.0), 14)
	_esf("musgo", 0.12, _mat(Color(0.45, 0.62, 0.32)), Vector3(-0.7, 0.2, 0.1), Vector3(1.6, 0.4, 0.8))


## Leño suelto, tumbado en el suelo (eje X), con las dos testas claras.
func _p_leno() -> void:
	_cil("tronco", 0.07, 0.07, 0.5, _mat(C_MADERA), Vector3(0.0, 0.07, 0.0), Vector3(0.0, 0.0, 90.0), 10)
	for s in [-1.0, 1.0]:
		_cil("testa_%d" % int(s), 0.062, 0.062, 0.012, _mat(C_MADERA_CLARA), Vector3(0.251 * s, 0.07, 0.0), Vector3(0.0, 0.0, 90.0), 10)


func _p_fogata_apagada() -> void:
	var piedra: StandardMaterial3D = _mat(C_PIEDRA)
	for i in 9:
		var a: float = i * TAU / 9.0
		_esf("piedra_%d" % i, 0.17, piedra, Vector3(cos(a) * 0.55, 0.12, sin(a) * 0.55), Vector3(1.1, 0.8, 1.0))
	_cil("ceniza", 0.5, 0.52, 0.06, _mat(C_CENIZA), Vector3(0.0, 0.04, 0.0), Vector3.ZERO, 16)
	var carbon: StandardMaterial3D = _mat(C_CARBON)
	for i in 3:
		var a2: float = i * TAU / 3.0 + 0.5
		_cil("tizon_%d" % i, 0.05, 0.05, 0.5, carbon, Vector3(cos(a2) * 0.15, 0.1, sin(a2) * 0.15), Vector3(0.0, rad_to_deg(-a2), 80.0), 8)


## Tres leños en tipi, atados arriba. Se muestran con `poner_lenos(n)` (por defecto los tres).
func _p_fogata_lenos() -> void:
	var madera: StandardMaterial3D = _mat(C_MADERA)
	for i in 3:
		var a: float = i * TAU / 3.0
		var l: MeshInstance3D = _cil("leno_%d" % i, 0.07, 0.08, 0.95, madera, Vector3(cos(a) * 0.17, 0.43, sin(a) * 0.17), Vector3(0.0, 0.0, 0.0), 9)
		# Se inclinan hacia el centro: la parte alta de los tres se junta.
		l.rotation = Vector3(sin(a) * 0.3, 0.0, -cos(a) * 0.3)
	_toro("atadura", 0.015, 0.075, _mat(C_SOGA), Vector3(0.0, 0.78, 0.0), Vector3.ZERO)


## Caldera de hierro: panza, borde grueso, dos asas y tres patas. Abierta por arriba y con el interior oscuro. Su hierro es el que se pone rojo.
func _p_caldera_cuerpo() -> void:
	var hierro: StandardMaterial3D = _mat(C_HIERRO, 0.55)
	_mat_calor.append(hierro)
	_esf("panza", 0.58, hierro, Vector3(0.0, 0.48, 0.0), Vector3(1.0, 0.78, 1.0))
	_toro("borde", 0.46, 0.6, hierro, Vector3(0.0, 0.82, 0.0))
	_cil("interior", 0.5, 0.5, 0.02, _mat(C_CARBON), Vector3(0.0, 0.8, 0.0), Vector3.ZERO, 18)
	for s in [-1.0, 1.0]:
		_toro("asa_%d" % int(s), 0.025, 0.1, hierro, Vector3(0.62 * s, 0.7, 0.0), Vector3(0.0, 90.0, 0.0))
	for i in 3:
		var a: float = i * TAU / 3.0 + 0.5
		_cil("pata_%d" % i, 0.07, 0.1, 0.26, hierro, Vector3(cos(a) * 0.38, 0.13, sin(a) * 0.38), Vector3.ZERO, 8)
	for i in 8:
		var a2: float = i * TAU / 8.0
		_esf("remache_%d" % i, 0.03, hierro, Vector3(cos(a2) * 0.6, 0.74, sin(a2) * 0.6))


func _p_caldera_hogar() -> void:
	var piedra: StandardMaterial3D = _mat(C_PIEDRA)
	_cil("base", 0.88, 0.9, 0.22, piedra, Vector3(0.0, 0.11, 0.0), Vector3.ZERO, 16)
	for i in 10:
		var a: float = i * TAU / 10.0
		_esf("canto_%d" % i, 0.13, piedra, Vector3(cos(a) * 0.85, 0.12, sin(a) * 0.85), Vector3(1.2, 0.9, 1.0))
	_cil("ceniza", 0.62, 0.62, 0.03, _mat(C_CARBON), Vector3(0.0, 0.225, 0.0), Vector3.ZERO, 16)
	var carbon: StandardMaterial3D = _mat(C_CARBON)
	for i in 3:
		var a2: float = i * TAU / 3.0
		_cil("tizon_%d" % i, 0.06, 0.06, 0.5, carbon, Vector3(cos(a2) * 0.25, 0.27, sin(a2) * 0.25), Vector3(90.0, rad_to_deg(-a2), 0.0), 8)


## Medidor de calor: pilar con una ranura alta con un tubo de vidrio, cinco marcas y un casquete de latón. Por dentro sube `calor`.
func _p_medidor() -> void:
	_caja("pilar", Vector3(0.3, 1.4, 0.25), _mat(C_PIEDRA), Vector3(0.0, 0.7, 0.0))
	_caja("ranura", Vector3(0.1, 1.0, 0.04), _mat(C_CARBON), Vector3(0.0, 0.72, 0.125))
	var vidrio := StandardMaterial3D.new()
	vidrio.albedo_color = Color(0.75, 0.9, 1.0, 0.28)
	vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vidrio.roughness = 0.1
	_cil("tubo", 0.035, 0.035, 1.0, vidrio, Vector3(0.0, 0.72, 0.15), Vector3.ZERO, 10)
	for i in 5:
		_caja("marca_%d" % i, Vector3(0.1, 0.025, 0.02), _mat(C_PIEDRA_OSC), Vector3(0.1, 0.32 + i * 0.2, 0.128))
	_cil("tapa", 0.1, 0.12, 0.08, _mat(C_LATON, 0.4), Vector3(0.0, 1.44, 0.0), Vector3.ZERO, 10)
	_esf("musgo", 0.12, _mat(Color(0.45, 0.62, 0.32)), Vector3(0.1, 0.06, 0.05), Vector3(1.6, 0.4, 1.0))
	# El relleno que sube con el calor: un cilindro fino dentro del tubo, de 0 a 1 de alto (se escala en `poner_calor`).
	var rel := _mat(C_ROJO_CALOR, 0.4, 1.4)
	var m: MeshInstance3D = _cil("relleno", 0.026, 0.026, 1.0, rel, Vector3(0.0, 0.22, 0.15), Vector3.ZERO, 8)
	m.scale = Vector3(1.0, 0.01, 1.0)
	m.visible = false


## Índice del medidor: una anillita de latón (la coloca el motor: sube y baja por el medidor).
func _p_indice() -> void:
	_toro("anillo", 0.045, 0.07, _mat(C_LATON, 0.4), Vector3(0.0, 0.0, 0.0), Vector3(90.0, 0.0, 0.0))
	_caja("flecha", Vector3(0.05, 0.03, 0.03), _mat(C_LATON, 0.4), Vector3(0.08, 0.0, 0.0))


## Antorcha de pared: placa de piedra, abrazadera de hierro y mango con la cabeza empapada en brea. Hacia +Z; el origen, en la placa.
func _p_antorcha_pared() -> void:
	_caja("placa", Vector3(0.3, 0.3, 0.06), _mat(C_PIEDRA), Vector3(0.0, 0.25, 0.0))
	_toro("abrazadera", 0.045, 0.09, _mat(C_HIERRO, 0.5), Vector3(0.0, 0.3, 0.12), Vector3(0.0, 0.0, 0.0))
	var mango: MeshInstance3D = _cil("mango", 0.04, 0.045, 0.8, _mat(C_MADERA_OSC), Vector3(0.0, 0.42, 0.4), Vector3(-65.0, 0.0, 0.0), 8)
	mango.name = "mango"
	_esf("cabeza", 0.09, _mat(C_CARBON), Vector3(0.0, 0.67, 0.66), Vector3(1.0, 1.3, 1.0))


func _p_antorcha_pie() -> void:
	_cil("base", 0.1, 0.22, 0.3, _mat(C_PIEDRA), Vector3(0.0, 0.15, 0.0), Vector3.ZERO, 10)
	_cil("poste", 0.04, 0.05, 1.1, _mat(C_MADERA_OSC), Vector3(0.0, 0.85, 0.0), Vector3.ZERO, 8)
	_cil("copa", 0.14, 0.08, 0.16, _mat(C_HIERRO, 0.5), Vector3(0.0, 1.46, 0.0), Vector3.ZERO, 10)
	_esf("cabeza", 0.11, _mat(C_CARBON), Vector3(0.0, 1.56, 0.0), Vector3(1.0, 1.2, 1.0))


## Baldosa falsa: la losa llana con una grieta en aspa grabada (dos hendiduras oscuras). Mismo tamaño y mismo tono que la segura.
func _p_baldosa_falsa() -> void:
	_caja("losa", Vector3(2.0, 0.2, 2.0), _mat(C_PIEDRA), Vector3(0.0, 0.1, 0.0))
	var grieta: StandardMaterial3D = _mat(C_CARBON)
	_caja("grieta_a", Vector3(2.3, 0.012, 0.07), grieta, Vector3(0.0, 0.2, 0.0), Vector3(0.0, 45.0, 0.0))
	_caja("grieta_b", Vector3(2.3, 0.012, 0.07), grieta, Vector3(0.0, 0.2, 0.0), Vector3(0.0, -45.0, 0.0))
	_caja("fisura", Vector3(0.8, 0.012, 0.04), grieta, Vector3(0.45, 0.2, -0.55), Vector3(0.0, 20.0, 0.0))


## Escudo redondo del goblin, de cara a +Z (disco = cilindro con el eje en Z). `quemado` = tablas negras, sin pintura y con un mordisco.
func _p_escudo(quemado: bool) -> void:
	var tablas: StandardMaterial3D = _mat(C_CARBON if quemado else C_MADERA)
	var aro: StandardMaterial3D = _mat(Color(0.2, 0.2, 0.22) if quemado else Color(0.5, 0.36, 0.28), 0.5)
	var rot: Vector3 = Vector3(90.0, 0.0, 0.0)
	_cil("tablas", 0.27, 0.27, 0.08, tablas, Vector3(0.0, 0.0, 0.0), rot, 14)
	_toro("aro", 0.25, 0.29, aro, Vector3(0.0, 0.0, 0.0), rot)
	if not quemado:
		_caja("franja", Vector3(0.55, 0.1, 0.01), _mat(Color(0.65, 0.28, 0.2)), Vector3(0.0, 0.0, 0.046), Vector3(0.0, 0.0, 25.0))
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.09
	cono.height = 0.09
	cono.radial_segments = 10
	_malla("pua", cono, _mat(C_HIERRO, 0.4), Vector3(0.0, 0.0, 0.085), rot)
	if quemado:
		# El trozo comido por el fuego: un hueco oscuro en el borde (lo que queda es la tabla ennegrecida) y el borde roto.
		_cil("mordisco", 0.12, 0.12, 0.09, _mat(Color(0.05, 0.05, 0.05)), Vector3(0.2, -0.14, 0.0), rot, 10)
		_caja("grieta", Vector3(0.3, 0.012, 0.01), _mat(Color(0.04, 0.04, 0.04)), Vector3(-0.1, 0.12, 0.046), Vector3(0.0, 0.0, 30.0))


# ---------------------------------------------------------------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------------------------------------------------------------

func _preparar_estados() -> void:
	match id:
		"caldera_cuerpo":
			if con_modelo:
				_mat_calor = _materiales_propios()
				_emision_con_textura(_mat_calor)
			poner_calor(0.0)
		"caldera_medidor":
			if con_modelo:
				var rel := _mat(C_ROJO_CALOR, 0.4, 1.4)
				var m: MeshInstance3D = _caja("relleno", Vector3(0.1, 1.0, 0.08), rel, RANURA_MODELO)
				m.scale = Vector3(1.0, 0.01, 1.0)
				m.visible = false
			poner_calor(0.0)
		"goblin_escudo_entero":
			poner_estado("entero")
		"fogata_lenos":
			poner_lenos(3)
		"contador_placa":
			poner_cuenta(0)


## Los materiales de esta instancia, duplicados (si no, cambiar uno cambiaría todas las piezas iguales). Valen los del modelo de Meshy
## (override por superficie) y los de las primitivas (`material_override`, que MANDA sobre el de superficie: hay que sustituir ese).
func _materiales_propios() -> Array[StandardMaterial3D]:
	var r: Array[StandardMaterial3D] = []
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		if m.material_override is StandardMaterial3D:
			var d: StandardMaterial3D = (m.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.material_override = d
			r.append(d)
			continue
		for s in range(m.mesh.get_surface_count()):
			var base: Material = m.get_active_material(s)
			if base is StandardMaterial3D:
				var d2: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.set_surface_override_material(s, d2)
				r.append(d2)
	return r


## Con modelo la emisión sigue la textura (el hierro se pone rojo, las juntas y los remaches no se vuelven una mancha plana).
func _emision_con_textura(mats: Array[StandardMaterial3D]) -> void:
	for m in mats:
		m.emission_texture = m.albedo_texture


## Caldera: 0 fría · 0,5 caliente · 1 al rojo. El hierro se ve cada vez más rojo oscuro y emite luz; el medidor sube. Sin lógica: la decide `Caldera3D`.
func poner_calor(f: float) -> void:
	calor = clampf(f, 0.0, 1.0)
	if id == "caldera_cuerpo":
		var rojo: Color = C_HIERRO.lerp(C_ROJO_CALOR, clampf(calor * 1.1, 0.0, 1.0))
		for m in _mat_calor:
			m.emission_enabled = calor > 0.02
			m.emission = C_ROJO_CALOR
			m.emission_energy_multiplier = calor * calor * (1.2 if not con_modelo else 0.55)
			if not con_modelo:
				m.albedo_color = rojo
			else:
				m.albedo_color = Color.WHITE.lerp(Color(1.0, 0.62, 0.5), calor)     # la textura de hierro se calienta hacia el rojo sin lavarse
		_luz_calor()
	elif id == "caldera_medidor":
		var rel: MeshInstance3D = get_node_or_null("relleno") as MeshInstance3D
		if rel != null:
			rel.visible = calor > 0.02
			rel.scale = Vector3(1.0, maxf(calor, 0.01), 1.0)
			var h: float = 0.9 if con_modelo else 1.0
			rel.scale = Vector3(1.0, maxf(calor, 0.01) * h, 1.0)
			rel.position.y = 0.22 + calor * h * 0.5      # mide `h`: escalado, queda centrado a mitad de su alto
			(rel.material_override as StandardMaterial3D).albedo_color = Color(0.5, 0.75, 1.0).lerp(C_ROJO_CALOR, calor)
			(rel.material_override as StandardMaterial3D).emission = (rel.material_override as StandardMaterial3D).albedo_color


func _luz_calor() -> void:
	if calor <= 0.05:
		if _luz != null:
			_luz.queue_free()
			_luz = null
		return
	if _luz == null:
		_luz = OmniLight3D.new()
		_luz.name = "luz_calor"
		_luz.light_color = Color(1.0, 0.42, 0.15)
		_luz.omni_range = 2.4
		_luz.shadow_enabled = false
		_luz.position = Vector3(0.0, 1.0, 0.0)
		add_child(_luz)
		LuzTitila3D.aplicar(_luz, 0.5)     # brasa: titila menos que una llama
	_luz.light_energy = calor * 1.3


## Escudo del goblin: "entero", "ardiendo" (entero oscurecido, brasa en las tablas, parpadea) o "quemado" (la malla quemada).
## Con modelos: el Juego pide `goblin_escudo_entero` y `goblin_escudo_quemado` por separado; aquí solo se oscurece el entero.
func poner_estado(e: String) -> void:
	estado = e
	if id != "goblin_escudo_entero":
		return
	if _tw != null:
		_tw.kill()
		_tw = null
	var nuevos: bool = _mat_calor.is_empty()
	var mats: Array[StandardMaterial3D] = _mat_calor if not nuevos else _materiales_propios()
	_mat_calor = mats
	if nuevos and con_modelo:
		_emision_con_textura(mats)
	match e:
		"ardiendo":
			for m in mats:
				m.emission_enabled = true
				m.emission = Color(0.9, 0.3, 0.08)
				m.emission_energy_multiplier = 0.5 if not con_modelo else 0.18
				m.albedo_color = m.albedo_color.darkened(0.35 if not con_modelo else 0.55)
			var f: float = 1.0 if not con_modelo else 0.3       # con modelo la emisión sigue la textura y se satura antes
			_tw = create_tween().set_loops()
			_tw.tween_method(func(k: float) -> void:
				for m in mats:
					m.emission_energy_multiplier = k, 0.3 * f, 0.9 * f, 0.25)
			_tw.tween_method(func(k: float) -> void:
				for m in mats:
					m.emission_energy_multiplier = k, 0.9 * f, 0.3 * f, 0.25)
		_:
			for m in mats:
				m.emission_enabled = false


## Contador: enciende `n` de los `de` huecos con una gema cálida (las crea la primera vez). Sin gemas = los huecos vacíos.
func poner_cuenta(n: int, de: int = 4) -> void:
	if id != "contador_placa":
		return
	for i in range(de):
		var g: MeshInstance3D = get_node_or_null("gema_%d" % i) as MeshInstance3D
		var x: float = -0.6 + i * (1.2 / maxf(de - 1.0, 1.0))
		var pos := Vector3(x, 0.45, 0.11)
		if con_modelo:
			pos = Vector3(float(HUECOS_MODELO[mini(i, HUECOS_MODELO.size() - 1)]), 0.28, 0.2)
		if g == null:
			g = _esf("gema_%d" % i, 0.075 if not con_modelo else 0.06, _mat(Color(1.0, 0.62, 0.2), 0.3, 2.2), pos)
		g.visible = i < n


func poner_lenos(n: int) -> void:
	if id != "fogata_lenos":
		return
	if con_modelo:
		visible = n > 0           # el modelo es el haz entero, atado: no se puede quitar un leño suelto
		return
	for i in 3:
		var l: Node3D = get_node_or_null("leno_%d" % i) as Node3D
		if l != null:
			l.visible = i < n


## Llama y luz de una antorcha (apagada = sin nada). Usa el kit de efectos; el Juego puede poner la suya y no llamar a esto.
func poner_llama(si: bool) -> void:
	if _llama != null:
		_llama.queue_free()
		_llama = null
	if not si or (id != "antorcha_pared" and id != "antorcha_pie"):
		return
	_llama = Node3D.new()
	_llama.name = "llama"
	_llama.position = PUNTA_MODELO[id] if con_modelo else (Vector3(0.0, 0.67, 0.66) if id == "antorcha_pared" else Vector3(0.0, 1.62, 0.0))
	add_child(_llama)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.28)
	luz.light_energy = 1.2
	luz.omni_range = 3.2
	luz.shadow_enabled = false
	_llama.add_child(luz)
	VfxKit3D.elemento = "fuego"
	VfxKit3D.particulas(_llama, Vector3(0.0, 0.05, 0.0), 14, 0.7, 0.2, 0.5, false, true, 0.05, 1.0, Vector3.UP, 25.0)
	VfxKit3D.parpadeo(luz)


## Baldosa falsa: se hunde y se desvanece en `T_CAER` s.
func caer() -> void:
	if id != "baldosa_falsa":
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 1.5, T_CAER).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation:x", deg_to_rad(12.0), T_CAER)
	tw.chain().tween_callback(func() -> void:
		visible = false
		terminado.emit())


# ---------------------------------------------------------------------------------------------------------------------------------
# Mojado (seto, barril o lo que sea)
# ---------------------------------------------------------------------------------------------------------------------------------

## Oscurece y moja todo lo que cuelga de `nodo` sin tocar sus materiales (usa `material_overlay`: una capa translúcida azul-gris encima).
## `si` = false la quita. Es lo que pidió el Juego para el seto que `Reactivo3D.esta_mojado()` (diario 100, «Para el Pipeline» 2).
static func mojado(nodo: Node, si: bool) -> void:
	if nodo == null:
		return
	poner_capa(nodo, capa_mojada() if si else null)


const ALFA_MOJADO: float = 0.38

## La capa de «mojado»: azul-gris oscura, translúcida, con el brillo húmedo. `alfa` más alto = más oscura (el escudo del goblin la pide más fuerte, y la aclara al secarse).
static func capa_mojada(alfa: float = ALFA_MOJADO) -> StandardMaterial3D:
	var capa := StandardMaterial3D.new()
	capa.albedo_color = Color(0.12, 0.2, 0.3, alfa)
	capa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	capa.roughness = 0.15            # el brillo húmedo
	capa.metallic_specular = 0.9
	return capa


## Pone `capa` (o la quita con null) como `material_overlay` de todas las mallas de `nodo`.
static func poner_capa(nodo: Node, capa: Material) -> void:
	var lista: Array = nodo.find_children("*", "MeshInstance3D", true, false)
	if nodo is MeshInstance3D:
		lista.append(nodo)
	for n in lista:
		(n as GeometryInstance3D).material_overlay = capa

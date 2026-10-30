class_name Colmena3D
extends Area3D

## COLMENA (F1 de docs/PLAN_BASE_DATOS.md §3.2, 29/10; pieza nueva de Puzle3D: `; pieza <id> colmena <x> <y>`). Una colmena colgada de un árbol. Premia pensar el elemento:
##   · VIENTO  la descuelga: cae el PANAL al suelo (`panal` 1–2, lo dice `reactivos_mapa.tsv`) y la colmena queda vacía. Una sola vez (la flag `<nivel>.colmena.<id>` sobrevive a recargar y guardar).
##   · FUEGO   la quema: una NUBE DE VENENO de 3 s alrededor (si la jugadora está dentro, `Jugador3D.envenenar`) y NADA de panal; también gasta la flag.
## Cualquier otro elemento no hace nada. Una colmena ya usada (flag puesta al montar) nace vacía.
##
## ASPECTO: primitivas (una gota de cera dorada colgando de una rama) hasta que el Pipeline dibuje la pieza `colmena` (docs/DIARIO.md, petición): si existe
## `res://arte/piezas/colmena.tscn` se enseña ella en su lugar. No bloquea su casilla (cuelga de un árbol que sí lo hace).
##
## Es un reactivo de hechizos como el resto (capa `Lanzador3D.CAPA_REACTIVO`, `on_spell_hit` / `spell_reacts` / `carried_element` / `nivel_altura`).

signal panal_cae
signal arde

const ALTO_COLGADA: float = 1.4          ## u sobre el suelo a la que cuelga (los hechizos vuelan a ~1 u: la esfera de acierto, de 0,7 u de radio, cubre de 0,7 a 2,1)
const RADIO_HIT: float = 0.7
const T_NUBE: float = 3.0                ## s que dura la nube de veneno
const RADIO_NUBE: float = 1.5            ## u alrededor de la colmena donde envenena
const VENENO_DPS: float = 3.0            ## el mismo veneno que la bola del chamán (BolaVeneno3D)
const VENENO_S: float = 3.0
const FLAG_TROZO: String = "colmena"     ## el trozo de en medio de `<nivel>.colmena.<id>`
const COLOR_CERA: Color = Color(0.95, 0.76, 0.3)
const COLOR_NUBE: Color = Color(0.45, 0.75, 0.25, 0.35)

var celda: Vector2i = Vector2i.ZERO
var nivel: String = ""
var estado: String = "colgada"           ## colgada · vacia (cayó el panal) · ardiendo · quemada
var colgada: bool = true                 ## condición de Puzle3D: sigue colgando con su panal
var soltado: Array = []                  ## lo que soltó al caer el panal ([{que, n}]; vacío si ardió)
var envenenadas: int = 0                 ## veces que la nube envenenó a la jugadora (las pruebas)
var _visual: Node3D = null
var _nube: NubeVeneno3D = null            ## F4: la nube de verdad (`NubeVeneno3D`), hija de la colmena y llamada «nube_veneno»
var _t_nube: float = 0.0


func preparar(p_celda: Vector2i, p_nivel: String = "") -> void:
	celda = p_celda
	nivel = p_nivel
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


## `<nivel>.colmena.<id>` en minúsculas y con «_» donde no valga otra cosa.
static func flag_de(p_nivel: String, id: String) -> String:
	return "%s.%s.%s" % [_limpio(p_nivel), FLAG_TROZO, _limpio(id)]


static func _limpio(t: String) -> String:
	var r: String = ""
	for ch in t.to_lower():
		r += ch if ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_") else "_"
	return r if r != "" else "x"


func flag() -> String:
	return flag_de(nivel, String(name))


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	add_to_group("colmena")
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO_HIT
	forma.shape = esfera
	forma.position = Vector3(0.0, ALTO_COLGADA, 0.0)
	add_child(forma)
	_poner_visual()
	if nivel != "" and Flags.i().tiene(flag()):
		_dejar_vacia(false)
	set_process(false)


func _poner_visual() -> void:
	var ruta: String = "res://arte/piezas/colmena.tscn"
	if ResourceLoader.exists(ruta):
		var n: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
		if n != null:
			n.name = "modelo"
			add_child(n)
			_visual = n
			return
	var raiz := Node3D.new()
	raiz.name = "modelo"
	var rama := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.04
	cil.bottom_radius = 0.05
	cil.height = 0.5
	var mrama := StandardMaterial3D.new()
	mrama.albedo_color = Color(0.36, 0.25, 0.16)
	cil.material = mrama
	rama.mesh = cil
	rama.position = Vector3(0.0, ALTO_COLGADA + 0.45, 0.0)
	raiz.add_child(rama)
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "panal"
	var es := SphereMesh.new()
	es.radius = 0.28
	es.height = 0.62
	es.radial_segments = 10
	es.rings = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR_CERA
	m.roughness = 0.6
	es.material = m
	cuerpo.mesh = es
	cuerpo.position = Vector3(0.0, ALTO_COLGADA, 0.0)
	raiz.add_child(cuerpo)
	add_child(raiz)
	_visual = raiz


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	match Objetos.elemento_de(rune_data):
		"viento":
			caer_panal()
		"fuego":
			arder()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null or estado != "colgada":
		return false
	var e: String = Objetos.elemento_de(rune_data)
	return e == "viento" or e == "fuego"


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## --- Las dos reacciones ---

func _punto_suelo() -> Vector3:
	return Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


## VIENTO: se descuelga el panal. Devuelve lo que cayó ([] si ya no colgaba).
func caer_panal() -> Array:
	if estado != "colgada":
		return []
	var fila: Dictionary = Botin.fila_reactivo("colmena", "viento")
	soltado = Botin.desde_texto(String(fila.get("botin", "panal:1-2")))
	_dejar_vacia(true)
	if nivel != "":
		Flags.i().poner(flag(), "caida")
	var padre: Node3D = get_parent() as Node3D
	if padre != null:
		Botin.soltar(padre, _punto_suelo(), soltado)
	panal_cae.emit()
	return soltado


## FUEGO: arde. Nube de veneno T_NUBE s y nada de panal.
func arder() -> bool:
	if estado != "colgada":
		return false
	estado = "ardiendo"
	colgada = false
	soltado = []
	if nivel != "":
		Flags.i().poner(flag(), "quemada")
	_t_nube = T_NUBE
	_poner_nube()
	if _visual != null:
		_visual.visible = false
	Mundo3D.avisar_reaccion("prendido", global_position if is_inside_tree() else position, self)
	arde.emit()
	set_process(true)
	return true


func _dejar_vacia(con_efecto: bool) -> void:
	estado = "vacia"
	colgada = false
	var panal: Node3D = _visual.get_node_or_null("panal") as Node3D if _visual != null else null
	if panal != null:
		panal.visible = false
	elif _visual != null and not con_efecto:
		_visual.scale = Vector3.ONE * 0.6


## F4 (29/10): la nube provisional de F1 (una esfera y un radio comprobado aquí) es ahora una `NubeVeneno3D` real: envenena con los números de la tabla, el viento la empuja y la dispersa, y se guarda en la partida.
## Dura `T_NUBE` s (lo que cuenta `_t_nube`) y cubre `RADIO_NUBE` u alrededor de la colmena.
func _poner_nube() -> void:
	_nube = NubeVeneno3D.crear(self, global_position if is_inside_tree() else position, T_NUBE, RADIO_NUBE / Terreno3D.casilla)
	_nube.name = "nube_veneno"
	if get_parent() is Node3D and is_inside_tree():
		VfxPuzle3D.vapor(get_parent() as Node3D, global_position + Vector3(0.0, ALTO_COLGADA * 0.5, 0.0), 1.4)


## ¿Está la jugadora dentro de la nube ahora? (en horizontal a ≤ RADIO_NUBE y a una altura parecida)
func jugadora_en_nube() -> bool:
	var j: Jugador3D = Botin.jugador_de(self)
	if j == null or j.muerto:
		return false
	var d: Vector3 = j.global_position - global_position
	return Vector2(d.x, d.z).length() <= RADIO_NUBE and absf(d.y) <= ALTO_COLGADA + 0.5


func _process(delta: float) -> void:
	if estado != "ardiendo":
		set_process(false)
		return
	_t_nube -= delta
	if _nube != null and is_instance_valid(_nube):
		envenenadas = _nube.envenenadas
	if _t_nube <= 0.0:
		estado = "quemada"
		if _nube != null and is_instance_valid(_nube):
			_nube.retirar()
		_nube = null
		set_process(false)

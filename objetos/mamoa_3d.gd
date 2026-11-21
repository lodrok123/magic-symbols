class_name Mamoa3D
extends Node3D

## MÁMOA · la casilla de la que vuelve el mouro (enemigos/mouro_espectro_3d.gd). Dueño: Juego.
##
## Qué es: un brocal de pozo (arte/modelos/brocal_pozo.glb) metido en una casilla. Mientras está ABIERTA, el mouro espectro que la tiene por casa vuelve de ella cada vez que lo derriban
## (hasta REBROTES_MAX veces). Tapándola, el bucle se corta: es la salida «lista» del enemigo del glifo ᛉ (permanencia: «vuelve de la tumba mientras la mámoa siga abierta»).
##
## Cuándo se considera TAPADA (se mira la casilla cada INTERVALO_REVISION s; `revisar()` la mira en el acto):
##   · hay encima un `BloqueEmpujable3D` (el bloque de piedra o hielo que se empuja hasta ella),
##   · hay encima un volumen sólido o pisable de un hechizo VIVO: la tierra construida (`_bloques`), una plataforma de tierra, una columna o una solidez V2 (muro de tierra, de hielo…),
##   · o alguien la tapa a mano con `tapar_a_mano()` (la acción de una regla de puzle, o la pieza de la losa). `destapar_a_mano()` lo deshace.
## Al taparse se ve la losa con musgo (arte/modelos/losa_musgo.glb) sobre el brocal; al destaparse se quita. Señales `tapada` y `destapada` en cada cambio.
##
## `agrietar()` es el estado FINAL: lo llama el mouro al gastar su último rebrote. Desde entonces el mouro ya no vuelve aunque la mámoa siga abierta (señal `agrietada`; no se deshace).
##
## RELIQUIAS: si la tapan MIENTRAS hay un mouro dentro (latente, a la espera de volver: `entrar_mouro`), se sella con él y suelta el tesoro (tabla `reliquias` de nucleo/datos/botin_tablas.tsv)
## encima de la losa. Una sola vez por mámoa.
##
## Decisiones: la casilla NO se bloquea (`Terreno3D.bloquear_celda`): un bloque empujable tiene que poder llegar a ella, y el mouro reaparece en ella. El brocal es bajo; quien quiera
## que no se pise lo pone con una pieza aparte. Si falta el GLB, la mámoa funciona igual, solo que sin dibujo.

signal tapada
signal destapada
signal agrietada

const BROCAL: String = "res://arte/modelos/brocal_pozo.glb"
const LOSA: String = "res://arte/modelos/losa_musgo.glb"
const TABLA_RELIQUIAS: String = "reliquias"      ## la fila `nada` de la tabla la pide `nucleo/botin.gd`
const INTERVALO_REVISION: float = 0.25           ## s entre dos miradas a la casilla
const ANCHO_BROCAL: float = 1.7                  ## u: lo que ocupa el brocal en planta (la casilla mide 2,3)
const ANCHO_LOSA: float = 1.95                   ## u: la losa lo cubre y sobra un poco
const COLOR_HUMO: Color = Color(0.62, 0.66, 0.72, 0.55)
## 21/11 (Pablo: «el núcleo sería tapar la tumba con ALGO»; «llenándola levemente con agua»): además del bloque y de los hechizos de tierra/hielo, la tapa
##   · CUALQUIER COSA SÓLIDA en su casilla (lo que la bloquea en `Terreno3D`: una roca o un bloque empujados, un barril, una caja o un jarrón…) o un cogible soltado encima;
##   · el AGUA: si su casilla queda MOJADA (un hechizo de agua que da en el suelo, un charco que llega) o HELADA, el pozo se INUNDA y queda tapado para siempre (`inundada`).
##     Una flecha que solo pasa por encima no moja el suelo: no cuenta. Se ve el agua dentro del brocal.
const ESTADOS_INUNDAN: Array = ["mojada", "helada"]
const COLOR_AGUA_POZO: Color = Color(0.18, 0.42, 0.55, 0.85)
const FRACCION_ALTO_AGUA: float = 0.8          ## a qué altura del brocal queda la lámina de agua
const RADIO_AGUA: float = 0.42                 ## fracción de ANCHO_BROCAL que tapa el disco de agua (el hueco del pozo)
const COLOR_GRIETA: Color = Color(0.05, 0.04, 0.05)

var celda: Vector2i = Vector2i.ZERO
var abierta: bool = true                         ## false = tapada
var esta_agrietada: bool = false                 ## estado final (no se llama `agrietada`: así se llama la señal)
var lanz: Lanzador3D = null                      ## el lanzador cuyos hechizos pueden tapar; si es null se busca el del grupo `spellcaster`
var mundo: Node3D = null
var reliquias_soltadas: bool = false             ## ya soltó el tesoro (una sola vez)
var botin_soltado: Array = []                    ## lo que soltó (las pruebas lo leen)
var humo_activo: bool = false                    ## está avisando de un rebrote (las pruebas lo leen)
var _a_mano: bool = false
var _dentro: Array = []                          ## los mouros latentes que esperan volver por aquí
var _brocal: Node3D = null
var _losa: Node3D = null
var _grieta: MeshInstance3D = null
var _humo: CPUParticles3D = null
var _t_humo: float = 0.0
var _t: float = 0.0
var _alto_brocal: float = 0.6
var inundada: bool = false                       ## 21/11: el agua la llenó: tapada para siempre
var por_que_tapada: String = ""                  ## qué la tapó la última vez (pruebas y diario): a_mano · agua · bloque · algo · hechizo
var _agua: MeshInstance3D = null

signal inundada_ahora


## Crea una mámoa en la casilla `c`. `p_mundo` = el mundo (donde cae el botín); `p_padre` = de qué nodo se cuelga (el decorado del mapa; sin él, del mundo). `p_agrietada` = nace ya agrietada;
## `p_tapada` = nace tapada (un puzle la abre con `destapar_a_mano()`).
static func crear(p_mundo: Node3D, c: Vector2i, p_agrietada: bool = false, p_tapada: bool = false, p_padre: Node = null) -> Mamoa3D:
	var m := Mamoa3D.new()
	m.name = "Mamoa_%d_%d" % [c.x, c.y]
	m.celda = c
	m.mundo = p_mundo
	m.esta_agrietada = p_agrietada
	m._a_mano = p_tapada
	m.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	(p_padre if p_padre != null else p_mundo).add_child(m, true)
	return m


func _ready() -> void:
	add_to_group("mamoa3d")
	_brocal = _cargar(BROCAL, ANCHO_BROCAL)
	if _brocal != null:
		_alto_brocal = _alto_de(_brocal)
	_losa = _cargar(LOSA, ANCHO_LOSA)
	if _losa != null:
		_losa.position.y += _alto_brocal                 # la losa descansa sobre el brocal
		_losa.visible = false
	_construir_grieta()
	_construir_humo()
	revisar()
	if esta_agrietada:
		_grieta.visible = true


func _physics_process(delta: float) -> void:
	if _t_humo > 0.0:
		_t_humo -= delta
		if _t_humo <= 0.0:
			cancelar_humo()
	_t -= delta
	if _t <= 0.0:
		_t = INTERVALO_REVISION
		revisar()


## =====================================================================================================
##  Tapada o abierta
## =====================================================================================================

## Lo que levanta el brocal sobre el suelo (u), medido del modelo al cargarlo. Lo lee el mouro para salir POR ENCIMA de las piedras (`MouroEspectro3D.altura_surgir`).
func alto_brocal() -> float:
	return _alto_brocal


## Mira la casilla AHORA y cambia de estado si hace falta (emite `tapada` / `destapada`).
func revisar() -> void:
	if not inundada and _agua_en_casilla():
		inundar()
	por_que_tapada = "a_mano" if _a_mano else ("agua" if inundada else ("bloque" if _bloque_encima() else ("algo" if _algo_encima() else ("hechizo" if _hechizo_encima() else ""))))
	_poner(por_que_tapada != "")


## El pozo se llena de agua: tapado para siempre (se ve la lámina de agua dentro del brocal).
func inundar() -> void:
	if inundada:
		return
	inundada = true
	if _agua == null:
		_construir_agua()
	_agua.visible = true
	inundada_ahora.emit()
	PlayLog.event("mamoa_inundada", {"celda": [celda.x, celda.y]})


## ¿Está mojada (o helada) su casilla? Es el estado del SUELO: solo lo pone el agua que llega al suelo.
func _agua_en_casilla() -> bool:
	var e: EstadosSuelo3D = Terreno3D.estados
	if e == null:
		return false
	for est in ESTADOS_INUNDAN:
		if e.tiene(celda, String(est)):
			return true
	return false


## ¿Hay algo sólido en su casilla? Lo que la bloquea para `Terreno3D` (rocas y bloques empujados, barriles, cajas, jarrones…) o un cogible suelto encima.
func _algo_encima() -> bool:
	if Terreno3D.bloqueada(celda):
		return true
	if not is_inside_tree():
		return false
	var en_brazos: Array = []                                    # lo que alguien lleva encima no tapa (aunque pase por encima)
	for c in get_tree().get_nodes_in_group(PistaProximidad.GRUPO):
		if c is CargarObjeto3D and (c as CargarObjeto3D).objeto != null:
			en_brazos.append((c as CargarObjeto3D).objeto)
	for n in get_tree().get_nodes_in_group("cogible"):
		if n is Node3D and is_instance_valid(n) and (n as Node3D).is_inside_tree() and not en_brazos.has(n) \
				and Terreno3D.celda_de((n as Node3D).global_position) == celda:
			return true
	return false


func _construir_agua() -> void:
	_agua = MeshInstance3D.new()
	_agua.name = "AguaPozo"
	var disco := CylinderMesh.new()
	disco.top_radius = ANCHO_BROCAL * RADIO_AGUA
	disco.bottom_radius = ANCHO_BROCAL * RADIO_AGUA
	disco.height = 0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_AGUA_POZO
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic_specular = 0.9
	disco.material = mat
	_agua.mesh = disco
	_agua.position = Vector3(0.0, _alto_brocal * FRACCION_ALTO_AGUA, 0.0)
	_agua.visible = false
	add_child(_agua)


func tapar_a_mano() -> void:
	_a_mano = true
	revisar()


func destapar_a_mano() -> void:
	_a_mano = false
	revisar()


func _poner(cubierta: bool) -> void:
	if cubierta == (not abierta):
		return
	abierta = not cubierta
	if _losa != null:
		_losa.visible = cubierta and (por_que_tapada == "a_mano")      # 21/11: la losa es la tapa «de puzle»; con agua se ve el agua y con algo encima, ese algo
	if cubierta:
		cancelar_humo()
		tapada.emit()
		if not _dentro.is_empty():
			_soltar_reliquias()                              # se sella con el mouro dentro: el tesoro cae encima
	else:
		destapada.emit()


func _bloque_encima() -> bool:
	return BloqueEmpujable3D.en(celda) != null


func _lanzador() -> Lanzador3D:
	if lanz != null and is_instance_valid(lanz):
		return lanz
	if is_inside_tree():
		lanz = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D
	return lanz


## ¿Hay encima un volumen sólido o pisable de un hechizo vivo (tierra o hielo)? Se lee de las listas del lanzador: las entradas se quitan solas cuando el hechizo se acaba, y con ellas se destapa.
func _hechizo_encima() -> bool:
	var lz: Lanzador3D = _lanzador()
	if lz == null:
		return false
	for b in lz._bloques:                                    # tierra construida: {celda, niveles, ...}
		if b is Dictionary and (b as Dictionary).get("celda", Vector2i(-9999, -9999)) == celda and int((b as Dictionary).get("niveles", 1)) > 0:
			return true
	for p in lz._plataformas_tierra:                         # plataformas de tierra: {celdas, nodo, resta}
		if (p.get("celdas", []) as Array).has(celda):
			return true
	for c in lz._columnas:                                   # columnas de barrera: {celda, niveles, ...}
		if c is Dictionary and (c as Dictionary).get("celda", Vector2i(-9999, -9999)) == celda:
			return true
	for s in lz._solideces_v2:                               # muros de tierra / hielo (SolidezV2)
		if is_instance_valid(s) and (s as Lanzador3D.SolidezV2).celdas.has(celda):
			return true
	return false


## =====================================================================================================
##  Agrietada, mouros dentro, reliquias
## =====================================================================================================

## Estado final: el mouro ya no vuelve de aquí aunque siga abierta. Se llama una vez; las demás no hacen nada.
func agrietar() -> void:
	if esta_agrietada:
		return
	esta_agrietada = true
	if _grieta != null:
		_grieta.visible = true
	cancelar_humo()
	agrietada.emit()
	PlayLog.event("mamoa_agrietada", {"celda": [celda.x, celda.y]})


## Un mouro se ha deshecho y volverá por aquí: si la tapan antes de que vuelva, queda sellado con él.
func entrar_mouro(m: Node) -> void:
	if not _dentro.has(m):
		_dentro.append(m)


func salir_mouro(m: Node) -> void:
	_dentro.erase(m)


func mouros_dentro() -> int:
	return _dentro.size()


## El tesoro de la tumba, una sola vez, encima de la mámoa.
func _soltar_reliquias() -> void:
	if reliquias_soltadas:
		return
	reliquias_soltadas = true
	var lista: Array = Botin.tirar(TABLA_RELIQUIAS)
	botin_soltado = lista
	Botin.soltar(mundo if mundo != null else get_parent(), position, lista)
	PlayLog.event("mamoa_reliquias", {"celda": [celda.x, celda.y], "n": lista.size()})


## =====================================================================================================
##  Humo de aviso: «de aquí vuelve»
## =====================================================================================================

## Humo que sube del pozo `segundos` s (los 4 s que tarda el mouro en volver). Un VFX barato: partículas de CPU.
func humo_rebrote(segundos: float) -> void:
	if _humo == null:
		return
	_humo.emitting = true
	humo_activo = true
	_t_humo = segundos


func cancelar_humo() -> void:
	humo_activo = false
	_t_humo = 0.0
	if _humo != null:
		_humo.emitting = false


func _construir_humo() -> void:
	_humo = CPUParticles3D.new()
	_humo.name = "Humo"
	_humo.emitting = false
	_humo.amount = 16
	_humo.lifetime = 1.6
	_humo.direction = Vector3.UP
	_humo.spread = 25.0
	_humo.initial_velocity_min = 0.5
	_humo.initial_velocity_max = 0.9
	_humo.gravity = Vector3(0.0, 0.15, 0.0)
	_humo.scale_amount_min = 0.7
	_humo.scale_amount_max = 1.4
	var esfera := SphereMesh.new()
	esfera.radius = 0.12
	esfera.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = COLOR_HUMO
	esfera.material = mat
	_humo.mesh = esfera
	_humo.position = Vector3(0.0, _alto_brocal, 0.0)
	add_child(_humo)


func _construir_grieta() -> void:
	_grieta = MeshInstance3D.new()
	_grieta.name = "Grieta"
	var caja := BoxMesh.new()
	caja.size = Vector3(0.07, 0.03, ANCHO_BROCAL * 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_GRIETA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	caja.material = mat
	_grieta.mesh = caja
	_grieta.position = Vector3(0.0, _alto_brocal + 0.02, 0.0)
	_grieta.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	_grieta.visible = false
	add_child(_grieta)


## =====================================================================================================
##  Dibujo: el GLB ajustado a la casilla (se mide su caja y se escala para que mida `ancho` en planta, apoyado en el suelo y centrado)
## =====================================================================================================

func _cargar(ruta: String, ancho: float) -> Node3D:
	if not ResourceLoader.exists(ruta):
		push_warning("Mamoa3D: falta %s." % ruta)
		return null
	var escena: PackedScene = load(ruta) as PackedScene
	if escena == null:
		return null
	var raiz := Node3D.new()
	var modelo: Node3D = escena.instantiate() as Node3D
	raiz.add_child(modelo)
	var caja: AABB = _caja_modelo(modelo)
	if caja.size.x > 0.0001 or caja.size.z > 0.0001:
		var s: float = ancho / maxf(caja.size.x, caja.size.z)
		modelo.scale = Vector3.ONE * s
		modelo.position = Vector3(-(caja.position.x + caja.size.x * 0.5) * s, -caja.position.y * s, -(caja.position.z + caja.size.z * 0.5) * s)
		raiz.set_meta("alto", caja.size.y * s)
	add_child(raiz)
	return raiz


func _alto_de(raiz: Node3D) -> float:
	return float(raiz.get_meta("alto", 0.6))


## La caja de las mallas de `raiz` en el espacio de `raiz` (sin su propia transformación), o un AABB vacío.
static func _caja_modelo(raiz: Node3D) -> AABB:
	var res := AABB()
	var hay: bool = false
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t: Transform3D = Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != raiz:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var c: AABB = t * mi.mesh.get_aabb()
		res = c if not hay else res.merge(c)
		hay = true
	return res

class_name GuardianBarrera3D
extends Area3D

## GUARDIÁN (28/10, la Gruta Batida; docs/GRUTA_BATIDA.md §2): un tótem antiguo con ᛜ tallado que LEVANTA LA BARRERA en sus MARCAS (losas rúnicas del suelo, a cualquier
## distancia: tras una reja, al otro lado del agua). Es la forma de enseñar la barrera ANTES de dársela a la jugadora, como el cristal enseña el pulso antes de ᚱ:
##   · `cada` > 0: LATE solo cada `cada` s (con `cerca` > 0, solo si la jugadora está a `cerca` casillas o menos: que lo vea);
##   · `cada` = 0: DORMIDO, lo despierta un hechizo que le da (la barrera lleva el elemento de ese hechizo; sin elemento, el suyo).
## La barrera es LA DEL JUGADOR, la misma receta (`elemento + ᛜ`, `Lanzador3D.lanzar_receta`): misma figura, mismo sonido, mismos segundos. Así, cuando el cofre dé ᛜ, se reconoce.
## Al levantarla, su runa se enciende del color del elemento y un hilo de luz (HiloLuz3D, tenue en reposo) corre del tótem a cada marca; la barrera nace cuando llega.
## `roto=si`: el tótem caído junto a una marca sin dueño (el sitio donde la jugadora tiene que poner SU barrera). No hace nada ni bloquea.
## Se coloca con `; pieza <id> guardian <x> <y> en=<casillas> [cada=<s>] [elemento=fuego] [cerca=<casillas>] [roto=si]` (escenas/puzle.gd). Bloquea su casilla (salvo roto).

signal levanta(elemento: String)

const ENFRIAR: float = 1.2              ## s mínimos entre dos barreras (un hechizo continuo no lo convierte en una metralleta)
const FASE_INICIAL: float = 1.5         ## s hasta el primer latido
const T_HILO: float = 0.45              ## s que tarda la luz del tótem a la marca (la barrera nace al llegar)
const T_DESTELLO: float = 1.4           ## s que tarda en apagarse la runa
const ENERGIA_RUNA: float = 3.0
const ENERGIA_REPOSO: float = 0.0           ## el tótem en reposo, sin brillo (la marca y el hilo ya dicen dónde actúa)
const ALTO_CUERPO: float = 1.7
const ANCHO_CUERPO: float = 0.8
const ALTO_HILO: float = 0.07           ## u sobre el suelo
const RUNAS: Dictionary = {"fuego": "fire", "agua": "water", "viento": "wind", "tierra": "earth", "rayo": "lightning", "hielo": "ice"}
const COLOR_REPOSO: Color = Color(0.95, 0.75, 0.35)

var celda: Vector2i = Vector2i.ZERO
var marcas: Array = []                  ## Vector2i: dónde nace la barrera
var cada: float = 0.0
var elemento: String = "fuego"
var cerca: float = 0.0
var roto: bool = false
var levantadas: int = 0                 ## cuántas veces ha levantado la barrera (las pruebas)
var ultimo_elemento: String = ""
var destello: float = 0.0
var _mundo: Node = null
var _t: float = FASE_INICIAL
var _enfriando: float = 0.0
var _color: Color = COLOR_REPOSO
var _mats: Array[StandardMaterial3D] = []
var _mats_marca: Array[StandardMaterial3D] = []
var _hilos: Array = []
var _luz: OmniLight3D = null


func preparar(p_celda: Vector2i, p_marcas: Array, p_cada: float = 0.0, p_elemento: String = "fuego", p_cerca: float = 0.0, p_roto: bool = false, mundo: Node = null) -> void:
	celda = p_celda
	marcas = p_marcas.duplicate()
	cada = maxf(p_cada, 0.0)
	elemento = p_elemento if RUNAS.has(p_elemento) else "fuego"
	cerca = maxf(p_cerca, 0.0)
	roto = p_roto
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)
	if not roto:
		Terreno3D.bloquear_celda(celda)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = 0 if roto else Lanzador3D.CAPA_REACTIVO
	if not roto:
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(ANCHO_CUERPO, ALTO_CUERPO, ANCHO_CUERPO)
		forma.shape = caja
		forma.position = Vector3(0.0, ALTO_CUERPO * 0.5, 0.0)
		add_child(forma)
	_dibujar()
	set_process(not roto)


func _dibujar() -> void:
	var n: Node3D = BrilloPulso3D.modelo("totem_runico", _mundo)
	if n == null:
		var cuerpo := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.55, ALTO_CUERPO, 0.55)
		cuerpo.mesh = caja
		cuerpo.position.y = ALTO_CUERPO * 0.5
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.42, 0.38)
		cuerpo.material_override = m
		n = Node3D.new()
		n.add_child(cuerpo)
	n.name = "modelo"
	if roto:
		# caído de lado, al pie de su marca: se lee como «aquí hubo uno»
		n.rotation = Vector3(0.0, 0.6, PI * 0.47)
		n.position = Vector3(0.0, 0.25, 0.0)
	add_child(n)
	_mats = _materiales_que_brillan(n)
	if not roto:
		_luz = OmniLight3D.new()
		_luz.omni_range = 4.0
		_luz.light_energy = 0.0
		_luz.shadow_enabled = false
		_luz.position = Vector3(0.0, 1.3, 0.0)
		add_child(_luz)
	# Las marcas: una losa rúnica por casilla, a ras de suelo (no bloquean), y el hilo tenue que las une al tótem.
	for c in marcas:
		var losa: Node3D = BrilloPulso3D.modelo("losa_runas_ovalo", _mundo)
		if losa == null:
			var mi := MeshInstance3D.new()
			var cil := CylinderMesh.new()
			cil.top_radius = Terreno3D.casilla * 0.32
			cil.bottom_radius = Terreno3D.casilla * 0.34
			cil.height = 0.06
			mi.mesh = cil
			var mm := StandardMaterial3D.new()
			mm.albedo_color = Color(0.5, 0.47, 0.42)
			mi.material_override = mm
			losa = Node3D.new()
			losa.add_child(mi)
		losa.name = "marca_%d_%d" % [(c as Vector2i).x, (c as Vector2i).y]
		add_child(losa)
		losa.global_position = Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i)) + Vector3(0.0, 0.02, 0.0)
		_mats_marca.append_array(_materiales_que_brillan(losa))
		if not roto:
			var hilo := HiloLuz3D.new()
			hilo.name = "hilo_%d_%d" % [(c as Vector2i).x, (c as Vector2i).y]
			hilo.top_level = true                       # sus puntos son del mundo: colgado del tótem sin esto se sumaría su posición
			add_child(hilo)
			hilo.global_transform = Transform3D.IDENTITY
			var a: Vector3 = global_position + Vector3(0.0, ALTO_HILO, 0.0)
			var b: Vector3 = Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i)) + Vector3(0.0, ALTO_HILO, 0.0)
			hilo.preparar([a, a.lerp(b, 0.5), b], COLOR_REPOSO)
			_hilos.append(hilo)
	_pintar()


## Duplica los materiales del modelo para poder encenderlos sin tocar los de las demás piezas.
func _materiales_que_brillan(raiz: Node) -> Array[StandardMaterial3D]:
	var res: Array[StandardMaterial3D] = []
	var pila: Array = [raiz]
	while not pila.is_empty():
		var nodo: Node = pila.pop_back()
		pila.append_array(nodo.get_children())
		if not (nodo is MeshInstance3D):
			continue
		var mi: MeshInstance3D = nodo as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var base: Material = mi.get_active_material(i)
			if not (base is StandardMaterial3D):
				continue
			var m: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.emission_enabled = true
			mi.set_surface_override_material(i, m)
			res.append(m)
	return res


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	var e: String = Objetos.elemento_de(rune_data)
	levantar(e if RUNAS.has(e) else elemento)


func spell_reacts(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return not roto and _enfriando <= 0.0


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, 1.1, 0.0))


## --- Levantar la barrera ---

## Enciende la runa, manda la luz por los hilos y, al llegar, levanta la barrera de `elem` en cada marca. false si está enfriando (o roto).
func levantar(elem: String = "") -> bool:
	if roto or _enfriando > 0.0 or marcas.is_empty():
		return false
	var e: String = elem if RUNAS.has(elem) else elemento
	_enfriando = ENFRIAR
	_t = cada
	levantadas += 1
	ultimo_elemento = e
	destello = 1.0
	_color = Vfx3D.COLOR.get(e, COLOR_REPOSO) if Vfx3D.COLOR.has(e) else COLOR_REPOSO
	for h in _hilos:
		if is_instance_valid(h):
			(h as HiloLuz3D).viajar(T_HILO)
	Sfx.play(self, "sello_ok")
	levanta.emit(e)
	if is_inside_tree():
		get_tree().create_timer(T_HILO).timeout.connect(_barrera.bind(e))
	return true


func _barrera(e: String) -> void:
	if not is_inside_tree():
		return
	var lanz: Lanzador3D = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D
	if lanz == null:
		return
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % RUNAS[e]) as RuneData
	for c in marcas:
		var receta := Lanzador3D.Receta3D.new(Vector2.RIGHT)
		receta.apply("barrera")
		var hacia: Vector3 = Terreno3D.centro_de(c as Vector2i, 0.0) - Terreno3D.centro_de(celda, 0.0)
		hacia.y = 0.0
		var dir: Vector3 = hacia.normalized() if hacia.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
		lanz.lanzar_receta(receta, rune, Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i)), dir)


func _jugadora_cerca() -> bool:
	if cerca <= 0.0:
		return true
	var j: Node3D = Puzle3D.jugador_nodo(get_tree(), _mundo)
	return j != null and Vector2(Terreno3D.celda_de(j.global_position) - celda).length() <= cerca + 0.01


func _process(delta: float) -> void:
	if _enfriando > 0.0:
		_enfriando = maxf(_enfriando - delta, 0.0)
	if cada > 0.0:
		_t -= delta
		if _t <= 0.0:
			if _jugadora_cerca():
				levantar(elemento)
			else:
				_t = 0.5
	if destello > 0.0:
		destello = maxf(destello - delta / T_DESTELLO, 0.0)
		_pintar()


func _pintar() -> void:
	var e: float = destello * destello
	var col: Color = COLOR_REPOSO.lerp(_color, minf(destello * 2.0, 1.0))
	for m in _mats:
		m.emission = col
		m.emission_energy_multiplier = (ENERGIA_REPOSO if not roto else 0.0) + ENERGIA_RUNA * e
	for m in _mats_marca:
		m.emission = col
		m.emission_energy_multiplier = (0.25 if not roto else 0.05) + ENERGIA_RUNA * e
	if _luz != null:
		_luz.light_color = col
		_luz.light_energy = 1.8 * e

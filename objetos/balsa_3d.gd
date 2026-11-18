class_name Balsa3D
extends Node3D

## BALSA (18/11/2026, puzle «Foso con cofre flotante» del laboratorio de agua). Una plataforma de tablones que descansa en el FONDO del foso y FLOTA cuando el agua de su casilla llega a `calado` u: sube con la
## superficie y entonces DERIVA, de casilla en casilla, por la `ruta` (la casilla de reposo es la de la pieza; la última de la ruta es el MUELLE, junto a la pasarela) a `vel` u/s. Solo avanza hacia una casilla
## si ahí hay agua suficiente (`calado`): si el foso se seca a medias se queda varada y se hunde donde esté; al volver el agua sigue. Al llegar al muelle queda ATRACADA (`atracada` = true, señal `atraca`; sigue
## atracada aunque luego se hunda). El agua la mueve la simulación (AguaSim3D), no un temporizador: sin agua, no hay balsa que se mueva.
##
## NO es el `Flotador3D` (un RigidBody con sondas que necesita colisión en el suelo y deja el rumbo a la corriente: aquí hace falta un recorrido garantizado y que no dependa de la física). Toma de él la idea de
## leer la superficie de la simulación (`superficie_en`) y la profundidad mínima para que cuente como agua que sostiene.
##
## LLEVA UN COFRE (`llevar(nodo)`; en el mapa, `cofre=<id de una pieza cofre>`): el cofre pasa a ser hijo de la balsa, así que se mueve con ella; cada vez que cambia de casilla se mueve también la casilla que
## bloquea. Para que no se abra desde el fondo del foso vacío, el cofre de la pieza lleva `abre_si=<id de la balsa>.atracada`: hasta que la balsa llega al muelle está sellado (el foso vacío se puede bajar y
## trepar, no es una pared: el sello es lo que lo hace inalcanzable). Pieza `balsa` del mapa (escenas/puzle.gd); dueño: Juego.

signal atraca                       ## llegó al muelle
signal a_flote(si: bool)            ## empieza a flotar (true) o se hunde (false)

const CALADO_DEFECTO: float = 0.2   ## u de agua en su casilla para flotar (hundirse: la mitad, para no parpadear)
const VEL_DEFECTO: float = 1.5      ## u/s de deriva
const SUBE_U_S: float = 0.6         ## u/s a los que sube o baja con la superficie
const ALTO_TABLON: float = 0.14
const LADO: float = 1.7
const BALANCEO_U: float = 0.03      ## cuánto cabecea al flotar
const COTA_LLEGADA: float = 0.03    ## u a las que se da por llegada a una casilla

var ruta: Array[Vector2i] = []      ## ruta[0] = reposo; ruta.back() = muelle
var calado: float = CALADO_DEFECTO
var vel: float = VEL_DEFECTO
var flota: bool = false
var atracada: bool = false
var indice: int = 0                 ## en qué casilla de la ruta está (la última que alcanzó)
var cofre: Node3D = null
var varada: bool = false            ## flota pero la casilla siguiente no tiene agua bastante

var _y_actual: float = 0.0
var _t: float = 0.0
var _celda_cofre: Vector2i = Vector2i(-9999, -9999)


## `p_ruta`: las casillas por las que pasa, la primera es el reposo. Se llama ANTES de colgarla del árbol.
func preparar(p_ruta: Array, p_calado: float = CALADO_DEFECTO, p_vel: float = VEL_DEFECTO) -> void:
	ruta.clear()
	for c in p_ruta:
		ruta.append(c as Vector2i)
	if ruta.is_empty():
		ruta.append(Vector2i.ZERO)
	calado = maxf(p_calado, 0.02)
	vel = maxf(p_vel, 0.1)
	indice = 0
	_y_actual = _y_reposo(ruta[0])
	position = Terreno3D.centro_de(ruta[0], _y_actual)


func _ready() -> void:
	add_to_group("balsa")
	_construir()
	set_physics_process(true)


func celda_actual() -> Vector2i:
	return ruta[indice]


## Altura de la balsa tumbada en el fondo de la casilla `c`.
func _y_reposo(c: Vector2i) -> float:
	return Terreno3D.y_pies(c) + 0.03


func _agua() -> AguaSim3D:
	return Terreno3D.agua_sim


func _profundidad(c: Vector2i) -> float:
	var a: AguaSim3D = _agua()
	return a.profundidad_casilla(c) if a != null else 0.0


## Los tablones (dos capas cruzadas) con dos travesaños y unas cuerdas de las que se ve que flota. Primitivas.
func _construir() -> void:
	var madera := StandardMaterial3D.new()
	madera.albedo_color = Color(0.5, 0.34, 0.18)
	madera.roughness = 0.9
	var oscura := StandardMaterial3D.new()
	oscura.albedo_color = Color(0.3, 0.2, 0.1)
	oscura.roughness = 0.95
	for i in range(4):
		var t := MeshInstance3D.new()
		t.name = "Tablon%d" % i
		var b := BoxMesh.new()
		b.size = Vector3(LADO, ALTO_TABLON * 0.5, LADO * 0.23)
		t.mesh = b
		t.material_override = madera
		t.position = Vector3(0.0, ALTO_TABLON * 0.25, -LADO * 0.375 + LADO * 0.25 * float(i))
		add_child(t)
	for i in range(2):
		var v := MeshInstance3D.new()
		v.name = "Travesano%d" % i
		var b2 := BoxMesh.new()
		b2.size = Vector3(LADO * 0.14, ALTO_TABLON * 0.5, LADO)
		v.mesh = b2
		v.material_override = oscura
		v.position = Vector3(-LADO * 0.3 + LADO * 0.6 * float(i), ALTO_TABLON * 0.72, 0.0)
		add_child(v)


## El cofre pasa a ir encima de la balsa. `nodo` es el nodo del cofre (CofrePuzle); se queda donde el cofre ya estaba (la casilla de reposo).
func llevar(nodo: Node3D) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	cofre = nodo
	if is_inside_tree() and nodo.is_inside_tree():
		nodo.reparent(self, false)
	else:
		if nodo.get_parent() != null:
			nodo.get_parent().remove_child(nodo)
		add_child(nodo)
	nodo.position = Vector3(0.0, ALTO_TABLON * 0.9, 0.0)
	nodo.rotation = Vector3.ZERO
	_celda_cofre = Vector2i(-9999, -9999)
	_mover_bloqueo()


## La casilla bloqueada por el cofre sigue a la balsa (si no, quedaría un obstáculo invisible en el reposo y el muelle libre).
func _mover_bloqueo() -> void:
	if cofre == null or not is_instance_valid(cofre) or not cofre.has_method("_colision"):
		return
	var c: Vector2i = celda_actual()
	if c == _celda_cofre:
		return
	if _celda_cofre != Vector2i(-9999, -9999) or bool(cofre.get("_bloqueada")):
		cofre.call("_colision", false)
	cofre.set("celda", c)
	if not bool(cofre.get("es_oculto")):
		cofre.call("_colision", true)
	_celda_cofre = c


func _physics_process(delta: float) -> void:
	_t += delta
	var c: Vector2i = celda_actual()
	var d: float = _profundidad(c)
	var antes: bool = flota
	if flota:
		flota = d >= calado * 0.5
	else:
		flota = d >= calado
	if flota != antes:
		a_flote.emit(flota)
	# Altura: en el fondo, o sobre la superficie de su casilla.
	var y_obj: float = _y_reposo(c) + (d if flota else 0.0)
	_y_actual = move_toward(_y_actual, y_obj, SUBE_U_S * delta)
	var p: Vector3 = Terreno3D.centro_de(c, 0.0)
	var meta_x: float = p.x
	var meta_z: float = p.z
	varada = false
	if flota and not atracada and indice < ruta.size() - 1:
		var sig: Vector2i = ruta[indice + 1]
		if _profundidad(sig) >= calado:
			var q: Vector3 = Terreno3D.centro_de(sig, 0.0)
			var aqui := Vector2(position.x, position.z)
			var nuevo: Vector2 = aqui.move_toward(Vector2(q.x, q.z), vel * delta)
			position.x = nuevo.x
			position.z = nuevo.y
			if nuevo.distance_to(Vector2(q.x, q.z)) <= COTA_LLEGADA:
				indice += 1
				_mover_bloqueo()
				if indice >= ruta.size() - 1:
					atracada = true
					atraca.emit()
		else:
			varada = true
	elif not flota or atracada:
		# Parada (hundida o en el muelle): se queda centrada en su casilla.
		var aqui2 := Vector2(position.x, position.z)
		var nuevo2: Vector2 = aqui2.move_toward(Vector2(meta_x, meta_z), vel * delta)
		position.x = nuevo2.x
		position.z = nuevo2.y
	position.y = _y_actual + (BALANCEO_U * sin(_t * 2.2) if flota else 0.0)
	rotation.z = (0.03 * sin(_t * 1.7)) if flota else 0.0
	rotation.x = (0.025 * sin(_t * 1.3 + 1.0)) if flota else 0.0


## Fracción 0..1 del recorrido hecho (las pruebas y el HUD).
func progreso() -> float:
	if ruta.size() <= 1:
		return 1.0
	return float(indice) / float(ruta.size() - 1)

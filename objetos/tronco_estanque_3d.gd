class_name TroncoEstanque3D
extends Node3D

## TRONCO DEL ESTANQUE (Juego, 16/10; Bosque 01, «V T» de la hoja). Yace en el fondo del estanque vacío. Cuando el agua lo llena, el tronco
## SUBE con ella hasta quedar a ras del suelo de las orillas, atravesado sobre el cauce: ese es el paso (su «versión activada»).
##
## Cómo se sabe que el agua sube: se lee la profundidad de SU casilla en la simulación (`AguaSim3D.profundidad_casilla`); no hay señal ni
## tiempo fijo. A `PROF_ABRE` el tronco ya está arriba y la casilla pasa a letra `b` (puente) y se libera, como `PruebaTest2._al_tender_losa`.
## Una vez arriba se queda: el estanque no se vacía (el manantial del mapa es finito y la cuenca, cerrada).
##
## No es un Flotador3D (RigidBody3D con sondas): ese pide colisión de suelo en el nivel. Esto es una subida dirigida y siempre sale igual.
## Modelo: `tronco_estanque` de `PiezaBosque3D` (origen en el centro del eje, tumbado a lo largo de +X, 2,6 × 0,65 × 0,79; ARTE §18). Es el mismo en el fondo y a ras
## (sube, no hay otra versión). Si falta la lámina `bosque_orilla.glb`, vuelve al cilindro provisional de siempre (RADIO 0,3).

signal paso_abierto

const RADIO: float = 0.3
const RADIO_MODELO: float = 0.327        ## u: medio alto del modelo (medido en su malla: de −0,327 a +0,327 sobre el eje); es más grueso que el cilindro
const LARGO: float = 2.6                 ## u: cruza la casilla del cauce (2,3) y apoya en las dos orillas
const PROF_ABRE: float = 0.45            ## u de agua en su casilla a la que ya flota a ras
const VEL_SUBIDA: float = 1.2            ## u/s como mucho (suave aunque el agua suba de golpe)
const COLOR_CORTEZA: Color = Color(0.36, 0.25, 0.16)

var mundo: Variant = null
var celda: Vector2i = Vector2i.ZERO
var abierto: bool = false
var _y_fondo: float = 0.0
var _y_arriba: float = 0.0
var _tronco: MeshInstance3D = null
var _semieje: Vector3 = Vector3.RIGHT      ## dirección horizontal (unitaria) a lo largo de la cual yace

## 22/10 (cauce hondo): con el cauce seco ahora se anda por el fondo, donde yace el tronco, y el jugador (que se mueve por casillas, sin físicas) lo
## ATRAVESABA: la malla le tapaba el cuerpo. Mientras no esté bierto, el tronco es un obstáculo: no se entra en su caja salvo que los pies
## estén por encima de su cara de arriba. Abierto, el paso va a ras del suelo (casilla ) y ya no estorba.
const MARGEN_JUGADOR: float = 0.25          ## u: lo que se engorda su caja para el cuerpo del jugador
const TOLERANCIA_TREPA: float = 0.1         ## u: pies a esta altura (o más) de la cara de arriba = lo pisa por encima
static var activo: TroncoEstanque3D = null


## `eje`: a lo largo de qué dirección horizontal yace (por defecto, de oeste a este). Se coloca en el centro de `p_celda`.
func preparar(p_mundo: Variant, p_celda: Vector2i, eje: Vector3 = Vector3.RIGHT) -> void:
	mundo = p_mundo
	celda = p_celda
	var c: Vector3 = Terreno3D.centro_de(p_celda, 0.0)
	var modelo: MeshInstance3D = PiezaBosque3D.crear("tronco_estanque")
	var r: float = RADIO_MODELO if modelo != null else RADIO      # el origen es el eje: el tronco mide ±r por arriba y por abajo
	_y_fondo = Terreno3D.alto_agua - Terreno3D.LECHO_AGUA + r + 0.03
	_y_arriba = Terreno3D.alto_suelo - r + 0.04              # su cara superior casi a ras del suelo de las orillas
	position = Vector3(c.x, _y_fondo, c.z)
	var e: Vector3 = Vector3(eje.x, 0.0, eje.z).normalized()
	_semieje = e
	activo = self
	if modelo != null:
		# El modelo yace a lo largo de +X: basta girarlo sobre Y para que quede a lo largo de `eje`.
		_tronco = modelo
		_tronco.name = "tronco"
		_tronco.rotation.y = atan2(-e.z, e.x)
		add_child(_tronco)
		set_process(true)
		return
	var cil := CylinderMesh.new()
	cil.top_radius = RADIO
	cil.bottom_radius = RADIO
	cil.height = LARGO
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CORTEZA
	mat.roughness = 0.95
	cil.material = mat
	_tronco = MeshInstance3D.new()
	_tronco.name = "tronco"
	_tronco.mesh = cil
	# Un cilindro yace a lo largo de su Y local: se gira para que quede a lo largo de `eje`.
	_tronco.basis = Basis(Vector3.UP.cross(e).normalized(), PI * 0.5) if absf(e.dot(Vector3.UP)) < 0.99 else Basis.IDENTITY
	add_child(_tronco)
	set_process(true)


func _process(delta: float) -> void:
	if Terreno3D.agua_sim == null:
		return
	var prof: float = Terreno3D.agua_sim.profundidad_casilla(celda)
	var t: float = clampf(prof / PROF_ABRE, 0.0, 1.0)
	var y_obj: float = lerpf(_y_fondo, _y_arriba, t)
	position.y = move_toward(position.y, y_obj, VEL_SUBIDA * delta)
	if not abierto and t >= 1.0 and absf(position.y - _y_arriba) < 0.05:
		abierto = true
		Terreno3D.poner_letra(celda, "b")
		if mundo != null:
			mundo.call("_liberar", celda)
		paso_abierto.emit()
		set_process(false)


## ¿Choca con el tronco el jugador que está (o va a estar) en p (XZ) con los pies a y_pies? Solo si el tronco aún no está abierto.
func bloquea(p: Vector3, y_pies: float) -> bool:
	if abierto or not is_inside_tree():
		return false
	var r: float = RADIO_MODELO if (_tronco != null and not (_tronco.mesh is CylinderMesh)) else RADIO
	if y_pies >= position.y + r - TOLERANCIA_TREPA:
		return false
	var d: Vector3 = Vector3(p.x - position.x, 0.0, p.z - position.z)
	var a: float = d.dot(_semieje)
	var l: float = absf(d.dot(Vector3.UP.cross(_semieje)))
	return absf(a) <= LARGO * 0.5 and l <= r + MARGEN_JUGADOR


## Versión estática para quien no tiene el nodo (Jugador3D): false si no hay tronco.
static func bloquea_a(p: Vector3, y_pies: float) -> bool:
	return activo != null and is_instance_valid(activo) and activo.bloquea(p, y_pies)


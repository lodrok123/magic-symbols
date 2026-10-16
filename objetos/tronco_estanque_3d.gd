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
## PROVISIONAL (modelo): cilindro con corteza; falta el modelo del tronco con su versión hundida y la activada.

signal paso_abierto

const RADIO: float = 0.3
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


## `eje`: a lo largo de qué dirección horizontal yace (por defecto, de oeste a este). Se coloca en el centro de `p_celda`.
func preparar(p_mundo: Variant, p_celda: Vector2i, eje: Vector3 = Vector3.RIGHT) -> void:
	mundo = p_mundo
	celda = p_celda
	var c: Vector3 = Terreno3D.centro_de(p_celda, 0.0)
	_y_fondo = Terreno3D.alto_agua - Terreno3D.LECHO_AGUA + RADIO + 0.03
	_y_arriba = Terreno3D.alto_suelo - RADIO + 0.04          # su cara superior casi a ras del suelo de las orillas
	position = Vector3(c.x, _y_fondo, c.z)
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
	var e: Vector3 = Vector3(eje.x, 0.0, eje.z).normalized()
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

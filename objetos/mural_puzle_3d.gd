class_name MuralPuzle3D
extends Node3D

## MURAL TAPADO DE BARRO (F15 del laboratorio de fuego, 20/11/2026). Una losa de piedra en el SUELO (en una casilla) que lleva grabada la PISTA de un puzle (aquí: el orden de los braseros, ver `SecuenciaBraseros3D`)
## y que nace TAPADA por una costra de barro: no se ve nada hasta que el AGUA la limpia. Cuando la casilla de la losa se moja (`EstadosSuelo3D`: lo que deja la LÍNEA de agua (ᛁ, el haz) al pasar por encima; o un charco de verdad en la simulación) el barro se deshace con un chorrito de agua sucia y la pista queda a la vista PARA SIEMPRE (`limpio_ya`; señal `limpio`). La acción `limpiar` del mapa hace lo mismo (el botón del laboratorio).
##
## QUÉ SE VE una vez limpia: un plano de la sala en miniatura (a escala de la casilla `ESCALA_CASILLA` por casilla, centrado en el centro de las casillas pedidas) con un punto rojo-naranja por brasero y su NÚMERO (1 = el
## primero que se enciende). El barro es una caja de tierra encima del grabado; el grabado ya está debajo desde el principio (se ve en cuanto se retira el barro). Con `flag` (si la hay) se acuerda de que se limpió.
##
## Se coloca desde un mapa con `; pieza <id> mural <x> <y> de=<x,y+x,y+…> [flag=<nombre>]` (escenas/puzle.gd): x,y es la casilla de la losa; `de` = las casillas que se marcan, EN ORDEN (las mismas que la `secuencia`).
## Señal `limpio`; condiciones `limpio`|`tapado`; acción `limpiar`. No bloquea su casilla (se pisa).

signal limpio

const LADO_LOSA: float = 1.9                ## u
const ALTO_LOSA: float = 0.07
const ESCALA_CASILLA: float = 0.36          ## u del plano por casilla del mapa
const MAX_LADO_PLANO: float = 1.5           ## u: lado máximo del plano grabado (se reduce la escala si no cabe)
const COLOR_PIEDRA: Color = Color(0.5, 0.47, 0.43)
const COLOR_BARRO: Color = Color(0.31, 0.2, 0.1)
const COLOR_PUNTO: Color = Color(1.0, 0.36, 0.08)       ## rojo-naranja, nunca amarillo
const T_LIMPIAR: float = 1.3
const CADA_MIRA: float = 0.2
const AGUA_MIN: float = 0.02                ## u de agua en la casilla de la losa (simulación) que cuentan como mojada

var celda: Vector2i = Vector2i.ZERO
var orden: Array = []                        ## las casillas marcadas, en orden
var flag: String = ""
var limpio_ya: bool = false
var limpiando: bool = false
var _t_mira: float = 0.0
var _barro: MeshInstance3D = null
var _grabado: Node3D = null


## Se llama ANTES de colgarlo del árbol.
func preparar(p_celda: Vector2i, p_orden: Array, p_flag: String = "") -> void:
	celda = p_celda
	orden = p_orden
	flag = p_flag
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)


func _ready() -> void:
	_construir()
	if flag != "" and Flags.i().tiene(flag):
		limpio_ya = true                      # partida cargada: ya estaba limpia
		_barro.visible = false
	set_process(true)


func _process(delta: float) -> void:
	if limpio_ya or limpiando:
		return
	_t_mira -= delta
	if _t_mira > 0.0:
		return
	_t_mira = CADA_MIRA
	if _mojada():
		limpiar()


## ¿Le ha llegado agua a la losa? Su casilla mojada (`EstadosSuelo3D`: lo que deja la LÍNEA de agua, el haz, al pasar por encima) o con agua de verdad en la simulación (el charco de una flecha que cae en ella).
func _mojada() -> bool:
	if Terreno3D.estados != null and Terreno3D.estados.tiene(celda, "mojada"):
		return true
	return Terreno3D.agua_sim != null and Terreno3D.agua_sim.profundidad_casilla(celda) >= AGUA_MIN


## Limpia el mural (lo que hace el agua). Una sola vez.
func limpiar() -> void:
	if limpio_ya or limpiando:
		return
	limpiando = true
	if is_inside_tree():
		Sfx.play(self, "chapoteo")
		if get_parent() is Node3D:
			VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.15, 0.0), 0.8)
	var tw: Tween = create_tween()
	tw.tween_property(_barro, "scale", Vector3(1.0, 0.05, 1.0), T_LIMPIAR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_acabar_de_limpiar)
	limpio_ya = true                          # a efectos de las reglas, limpio desde ya: la costra se va en `T_LIMPIAR` s
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	limpio.emit()


func _acabar_de_limpiar() -> void:
	limpiando = false
	if _barro != null:
		_barro.visible = false


## ¿Se ve la pista? (el barro ya se ha ido del todo: lo que ve la jugadora.)
func pista_a_la_vista() -> bool:
	return limpio_ya and not limpiando and _barro != null and not _barro.visible


# ---------------------------------------------------------------------------------------------------------------------
#  Dibujo (primitivas)
# ---------------------------------------------------------------------------------------------------------------------

func _material(color: Color, rugoso: float = 0.9, brillo: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugoso
	if brillo > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = brillo
	return m


func _construir() -> void:
	var losa := MeshInstance3D.new()
	losa.name = "Losa"
	var bm := BoxMesh.new()
	bm.size = Vector3(LADO_LOSA, ALTO_LOSA, LADO_LOSA)
	losa.mesh = bm
	losa.material_override = _material(COLOR_PIEDRA)
	losa.position = Vector3(0.0, ALTO_LOSA * 0.5, 0.0)
	add_child(losa)
	_grabado = Node3D.new()
	_grabado.name = "Grabado"
	_grabado.position = Vector3(0.0, ALTO_LOSA + 0.004, 0.0)
	add_child(_grabado)
	_dibujar_plano()
	# El barro: una costra que cubre la losa y el grabado.
	_barro = MeshInstance3D.new()
	_barro.name = "Barro"
	var bb := BoxMesh.new()
	bb.size = Vector3(LADO_LOSA + 0.06, 0.1, LADO_LOSA + 0.06)
	_barro.mesh = bb
	_barro.material_override = _material(COLOR_BARRO, 1.0)
	_barro.position = Vector3(0.0, ALTO_LOSA + 0.05, 0.0)
	add_child(_barro)


## El plano en miniatura: un punto y un número por casilla de `orden`, relativos al centro de todas ellas.
func _dibujar_plano() -> void:
	if orden.is_empty():
		return
	var minx: int = (orden[0] as Vector2i).x
	var maxx: int = minx
	var miny: int = (orden[0] as Vector2i).y
	var maxy: int = miny
	for c in orden:
		minx = mini(minx, (c as Vector2i).x)
		maxx = maxi(maxx, (c as Vector2i).x)
		miny = mini(miny, (c as Vector2i).y)
		maxy = maxi(maxy, (c as Vector2i).y)
	var esc: float = minf(ESCALA_CASILLA, MAX_LADO_PLANO / float(maxi(maxi(maxx - minx, maxy - miny), 1)))
	var cx: float = float(minx + maxx) * 0.5
	var cy: float = float(miny + maxy) * 0.5
	for i in range(orden.size()):
		var c: Vector2i = orden[i]
		var p := Vector3((float(c.x) - cx) * esc, 0.0, (float(c.y) - cy) * esc)
		var punto := MeshInstance3D.new()
		punto.name = "Punto%d" % (i + 1)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.13
		cm.bottom_radius = 0.13
		cm.height = 0.008
		punto.mesh = cm
		punto.material_override = _material(COLOR_PUNTO, 0.6, 1.2)
		punto.position = p
		_grabado.add_child(punto)
		var num := Label3D.new()
		num.name = "Numero%d" % (i + 1)
		num.text = str(i + 1)
		num.font_size = 64
		num.pixel_size = 0.004
		num.outline_size = 10
		num.modulate = Color(1.0, 0.9, 0.8)
		num.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		num.position = p + Vector3(0.0, 0.012, 0.0)
		num.double_sided = false
		_grabado.add_child(num)

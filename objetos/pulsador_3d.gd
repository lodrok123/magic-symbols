class_name Pulsador3D
extends Area3D

## PULSADOR (Fase 13.8 · laboratorio de puzles de agua, 15/10, Juego). El DISPARADOR genérico de un puzle (escenas/puzle.gd, 12.3:
## Disparador → Condición → Acción): algo que el jugador activa y que avisa con `pulsado`. Quien lo escucha decide qué pasa.
##
## Tres modos, los tres que pidió Pablo para probar cada puzle por varias vías:
##   · "magia":     un BOTÓN de piedra: lo activa CUALQUIER hechizo que lo golpee (contrato on_spell_hit del Lanzador3D).
##   · "agua":      igual, pero solo reacciona al agua (una planta que hay que regar, una pila que hay que llenar).
##   · "presencia": una PLACA en el suelo: se activa cuando el jugador (o un cuerpo apuntado en `cuerpos`) está en su casilla y
##                  emite `soltado` cuando se va. Sin colisión de hechizos: un hechizo la sobrevuela.
## `rearme` s: 0 = se dispara UNA vez (un botón de piedra que se hunde); > 0 = vuelve a estar disponible pasados esos segundos.
## Quién pisa: el jugador se busca por el Lanzador3D del árbol (grupo "spellcaster" → `jugador`), que es cómo lo encuentran las
## pruebas; así la placa no depende de la maqueta.
##
## Qué NO hace: no abre puertas ni mueve agua. Solo avisa. Se dibuja solo (cilindro o losa) para no depender de ninguna pieza.

signal pulsado(modo: String)
signal soltado

const MODOS: Array = ["magia", "agua", "presencia"]
const COLOR: Dictionary = {"magia": Color(0.85, 0.3, 0.25), "agua": Color(0.3, 0.6, 1.0), "presencia": Color(0.95, 0.8, 0.3)}
const RADIO_BOTON: float = 0.42
const ALTO_BOTON: float = 0.9
const GROSOR_PLACA: float = 0.1
const CADA: float = 0.1                    ## s entre dos lecturas de presencia
const PLACA_CUEVA: String = "res://arte/piezas/placa_presion_cueva.tscn"   ## la losa con anillo y runa de la hoja D2 (1,8 × 1,8, 0,2 de alto)
const HUNDIDO_PLACA: float = 0.04          ## cuánto baja la placa al pisarla

var modo: String = "magia"
var celda: Vector2i = Vector2i.ZERO
var rearme: float = 0.0
var cuerpos: Array = []                    ## Node3D extra que también pisan la placa (un tronco, un goblin…)
var etiqueta: String = ""                  ## rótulo fijo sobre el pulsador (16/10, Pablo: «no entiendo el puzle»); "" = el del modo; "-" = ninguno
var modelo: String = ""                    ## 23/10: «cueva» = la placa de piedra de la Cueva (PLACA_CUEVA) en vez de la losa ocre; solo en modo presencia
var activo: bool = false                   ## pulsado y aún sin rearmar (o pisado)
var veces: int = 0                         ## cuántas veces se ha disparado (para las pruebas)
var _t_rearme: float = 0.0
var _t_lectura: float = 0.0
var _cuerpo: Node3D = null                 ## la losa o el botón (un MeshInstance3D) o, con `modelo`, la escena de la placa
var _mat: StandardMaterial3D = null


func preparar(p_celda: Vector2i, p_modo: String = "magia", p_rearme: float = 0.0) -> void:
	celda = p_celda
	modo = p_modo if MODOS.has(p_modo) else "magia"
	rearme = p_rearme
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = 0 if modo == "presencia" else Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	if modo == "presencia":
		caja.size = Vector3(Terreno3D.casilla * 0.8, GROSOR_PLACA, Terreno3D.casilla * 0.8)
		forma.position = Vector3(0.0, GROSOR_PLACA * 0.5, 0.0)
	else:
		caja.size = Vector3(RADIO_BOTON * 2.2, ALTO_BOTON, RADIO_BOTON * 2.2)
		forma.position = Vector3(0.0, ALTO_BOTON * 0.5, 0.0)
	forma.shape = caja
	add_child(forma)
	_dibujar()
	if etiqueta == "":
		etiqueta = {"magia": "CUALQUIER MAGIA", "agua": "SOLO AGUA", "presencia": "PÍSAME"}[modo]
	if etiqueta != "-":
		var rot := Label3D.new()
		rot.text = etiqueta
		rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rot.font_size = 30
		rot.outline_size = 8
		rot.pixel_size = 0.005
		rot.modulate = COLOR[modo].lightened(0.35)
		rot.position = Vector3(0.0, (ALTO_BOTON if modo != "presencia" else 0.0) + 0.75, 0.0)
		add_child(rot)
	set_process(true)


func _dibujar() -> void:
	if modo == "presencia" and modelo == "cueva" and ResourceLoader.exists(PLACA_CUEVA):
		_cuerpo = (load(PLACA_CUEVA) as PackedScene).instantiate() as Node3D
		add_child(_cuerpo)
		return
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR[modo]
	_mat.roughness = 0.6
	var cuerpo_malla := MeshInstance3D.new()
	_cuerpo = cuerpo_malla
	if modo == "presencia":
		var losa := BoxMesh.new()
		losa.size = Vector3(Terreno3D.casilla * 0.8, GROSOR_PLACA, Terreno3D.casilla * 0.8)
		cuerpo_malla.mesh = losa
		cuerpo_malla.position = Vector3(0.0, GROSOR_PLACA * 0.5, 0.0)
	else:
		var base := CylinderMesh.new()
		base.top_radius = RADIO_BOTON * 1.3
		base.bottom_radius = RADIO_BOTON * 1.4
		base.height = ALTO_BOTON * 0.55
		var pie := MeshInstance3D.new()
		pie.mesh = base
		var mp := StandardMaterial3D.new()
		mp.albedo_color = Color(0.45, 0.45, 0.48)
		pie.material_override = mp
		pie.position = Vector3(0.0, ALTO_BOTON * 0.275, 0.0)
		add_child(pie)
		var boton := CylinderMesh.new()
		boton.top_radius = RADIO_BOTON
		boton.bottom_radius = RADIO_BOTON
		boton.height = ALTO_BOTON * 0.45
		cuerpo_malla.mesh = boton
		cuerpo_malla.position = Vector3(0.0, ALTO_BOTON * 0.55 + ALTO_BOTON * 0.225, 0.0)
	cuerpo_malla.material_override = _mat
	add_child(cuerpo_malla)


## --- Contrato con los hechizos (magia y agua) ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if spell_reacts(rune_data):
		_disparar(modo)
	elif rune_data != null:
		# 15/10 (Pablo: «pulsando este botón no pasa nada»): un golpe que NO vale también se contesta, para que se sepa que ha llegado.
		_rechazar("YA PULSADO" if activo else ("SOLO AGUA" if modo == "agua" else "NO"))


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null or modo == "presencia" or activo:
		return false
	if modo == "agua":
		return rune_data.tags.has("agua")
	return true


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 0 if modo == "presencia" else 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, ALTO_BOTON if modo != "presencia" else GROSOR_PLACA, 0.0))


## Para las pruebas y los botones de la interfaz: dispararlo sin hechizo.
func pulsar() -> void:
	if not activo:
		_disparar(modo)


func _disparar(como: String) -> void:
	activo = true
	veces += 1
	_t_rearme = rearme
	if _cuerpo != null:
		_cuerpo.position.y -= 0.12 if modo != "presencia" else HUNDIDO_PLACA
		if _mat != null:
			_mat.emission_enabled = true
			_mat.emission = COLOR[modo]
			_mat.emission_energy_multiplier = 0.8
	_rotulo("PISADA" if modo == "presencia" else "¡CLIC!", Color(0.7, 1.0, 0.7))
	pulsado.emit(como)


## Feedback de un golpe que no activa: el botón tiembla, se enciende gris un instante y dice por qué (rótulo que se desvanece).
func _rechazar(motivo: String) -> void:
	if _cuerpo == null or _mat == null or not is_inside_tree():
		return
	var tw: Tween = create_tween()
	tw.tween_property(_cuerpo, "position:x", 0.05, 0.05).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cuerpo, "position:x", -0.05, 0.05)
	tw.tween_property(_cuerpo, "position:x", 0.0, 0.05)
	var col: Color = _mat.albedo_color
	_mat.albedo_color = Color(0.8, 0.8, 0.8)
	tw.parallel().tween_property(_mat, "albedo_color", col, 0.35)
	_rotulo(motivo, Color(1.0, 0.85, 0.6))


## Un rótulo que sube y se desvanece sobre el pulsador (feedback que se ve desde la cámara del juego).
func _rotulo(texto: String, color: Color) -> void:
	if not is_inside_tree():
		return
	var rot := Label3D.new()
	rot.text = texto
	rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rot.font_size = 40
	rot.outline_size = 8
	rot.pixel_size = 0.005
	rot.modulate = color
	rot.position = Vector3(0.0, ALTO_BOTON + 0.5, 0.0)
	add_child(rot)
	var tr: Tween = create_tween()
	tr.tween_property(rot, "position:y", ALTO_BOTON + 1.2, 1.0)
	tr.parallel().tween_property(rot, "modulate:a", 0.0, 1.0)
	tr.tween_callback(rot.queue_free)


func _rearmar() -> void:
	activo = false
	if _cuerpo != null:
		_cuerpo.position.y += 0.12 if modo != "presencia" else HUNDIDO_PLACA
		if _mat != null:
			_mat.emission_enabled = false
	if modo == "presencia":
		soltado.emit()


func _process(delta: float) -> void:
	if modo == "presencia":
		_t_lectura -= delta
		if _t_lectura <= 0.0:
			_t_lectura = CADA
			var pisada: bool = _alguien_encima()
			if pisada and not activo:
				_disparar("presencia")
			elif not pisada and activo:
				_rearmar()
		return
	if activo and rearme > 0.0:
		_t_rearme -= delta
		if _t_rearme <= 0.0:
			_rearmar()


func _alguien_encima() -> bool:
	for n in cuerpos:
		if is_instance_valid(n) and Terreno3D.celda_de((n as Node3D).global_position) == celda:
			return true
	# 27/10: lo que PESA (el bloque de tierra de un hechizo, grupo «peso») también la pisa: la barrera de tierra puesta a distancia sujeta una placa.
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("peso"):
			if n is Node3D and is_instance_valid(n) and Terreno3D.celda_de((n as Node3D).global_position) == celda:
				return true
	for grupo in ["spellcaster", "player"]:
		var lanz: Node = get_tree().get_first_node_in_group(grupo)
		if lanz != null and lanz.get("jugador") != null:
			var j: Node3D = lanz.get("jugador") as Node3D
			# El muñeco (`pj`) es el que anda; Jugador3D solo adopta su posición cuando lo mueven desde fuera (15/10: la placa no notaba
			# al jugador andando, solo al teletransportarlo).
			var quien: Node3D = (j.get("pj") as Node3D) if j.get("pj") != null else j
			return Terreno3D.celda_de(quien.global_position) == celda
	return false

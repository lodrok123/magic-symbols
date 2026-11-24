class_name Aguja3D
extends Area3D

## AGUJA DE VÍA (24/11/2026, puzles de vagoneta). En una casilla de vía donde la vía se abre en Y: un TRONCO y dos RAMALES (`a` y `b`).
## Una palanca al lado de la vía la cambia de un ramal al otro:
##   · E a su lado (a ≤ ALCANCE_USAR u, como el prisma; un rótulo «E · cambiar vía» sale sobre la palanca al acercarse), o la acción `cambiar` de una
##     regla (un botón, un brasero…). 24/11 (playtest de Pablo): los hechizos ya NO la cambian («no es claro»);
##   · la palanca es el detonador del pack Lost Cave con su asa inclinada hacia el ramal puesto; una flecha de color en el suelo lo repite.
## La vagoneta que llega RODANDO por el tronco sigue por el ramal puesto; llegando por un ramal, sale por el tronco. Empujada a mano, desde la aguja
## solo sale por el ramal puesto o por el tronco. No bloquea su casilla.
##
## Mapa: `; pieza <id> aguja <x> <y> a=<n|e|s|o> b=<n|e|s|o> [tronco=<n|e|s|o>]` (escenas/puzle.gd). Nace puesta en `a`. Sin `tronco`, es el lado opuesto a `a`.

signal cambia(ramal: String)

const ALTO_PALANCA: float = 0.9
const T_ENFRIAR: float = 0.35                  ## s entre dos cambios (un haz continuo no la vuelve loca)
const COLOR_A: Color = Color(0.95, 0.75, 0.25)
const COLOR_B: Color = Color(0.3, 0.75, 0.95)

static var _por_celda: Dictionary = {}         ## Vector2i -> Aguja3D

var celda: Vector2i = Vector2i.ZERO
var ramal_a: Vector2i = Vector2i(0, -1)
var ramal_b: Vector2i = Vector2i(1, 0)
var tronco: Vector2i = Vector2i(0, 1)
var en_b: bool = false
var cambios: int = 0                           ## las pruebas
var _t: float = 0.0
var _flecha: MeshInstance3D = null
var _palanca: MeshInstance3D = null
var _mat_palanca: StandardMaterial3D = null


static func en(c: Vector2i) -> Aguja3D:
	var a: Aguja3D = _por_celda.get(c, null) as Aguja3D
	return a if a != null and is_instance_valid(a) else null


func preparar(p_celda: Vector2i, a: String, b: String, p_tronco: String = "") -> void:
	celda = p_celda
	ramal_a = Vagoneta3D._dir_de(a) if Vagoneta3D._dir_de(a) != Vector2i.ZERO else Vector2i(0, -1)
	ramal_b = Vagoneta3D._dir_de(b) if Vagoneta3D._dir_de(b) != Vector2i.ZERO else Vector2i(1, 0)
	tronco = Vagoneta3D._dir_de(p_tronco) if Vagoneta3D._dir_de(p_tronco) != Vector2i.ZERO else -ramal_a
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	_por_celda[celda] = self


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_mask = 0
	collision_layer = 0                            # 24/11 (Pablo): solo con E; los hechizos ya no la cambian (no es blanco)
	# La palanca, a un lado de la vía (en la esquina entre el tronco y el ramal b).
	var S: float = Terreno3D.casilla
	var esquina: Vector3 = (Vector3(float(-tronco.x), 0.0, float(-tronco.y)) * -0.38 + Vector3(float(ramal_b.x - ramal_a.x), 0.0, float(ramal_b.y - ramal_a.y)).normalized() * 0.38) * S
	_pos_mando = esquina
	var esquina_det: Vector3 = esquina * (ESQUINA_DETONADOR / 0.38)
	if _poner_detonador(esquina_det):
		_pos_mando = esquina_det
		_flecha_y_listo()
		return
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.25, 0.4)
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.3, 0.28, 0.27)
	bm.material = mb
	base.mesh = bm
	base.position = esquina + Vector3(0.0, 0.125, 0.0)
	add_child(base)
	_palanca = MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.045
	pm.bottom_radius = 0.06
	pm.height = ALTO_PALANCA
	_mat_palanca = StandardMaterial3D.new()
	_mat_palanca.emission_enabled = true
	_mat_palanca.emission_energy_multiplier = 0.6
	pm.material = _mat_palanca
	_palanca.mesh = pm
	_palanca.position = esquina + Vector3(0.0, 0.25 + ALTO_PALANCA * 0.45, 0.0)
	add_child(_palanca)
	_flecha_y_listo()


## 24/11 (Pablo: «cambia la palanca por alguno de los nuevos assets»): en el pack no hay palanca; la hace el DETONADOR de mina (`lost_blastingmachine`),
## más grande. Su asa en T (vástago y barra, dos islas sueltas de su malla, por encima de la caja) se separa y BASCULA hacia el ramal puesto.
## La caja se gira para que su asa se incline a lo largo de los ramales (a un lado el `a`, al otro el `b`). false si el pack no está (vale la de primitivas).
const DETONADOR: String = "res://arte/lostcave/piezas/lost_blastingmachine.tscn"
const ESCALA_DETONADOR: float = 2.6
const ESQUINA_DETONADOR: float = 0.5           ## fracción de casilla desde el centro, hacia el tronco y hacia el ramal b: fuera de los raíles
const ALTO_ASA: float = 0.3                    ## (unidades de su malla) lo que está por encima es el asa
const INCLINA_ASA: float = 0.55                ## rad que se inclina el asa hacia el ramal puesto
var _asa: Node3D = null
var _pos_mando: Vector3 = Vector3.ZERO

func _poner_detonador(esquina: Vector3) -> bool:
	if not ResourceLoader.exists(DETONADOR):
		return false
	var n: Node3D = (load(DETONADOR) as PackedScene).instantiate() as Node3D
	var malla: MeshInstance3D = n.get_node_or_null("modelo/malla") as MeshInstance3D
	if malla == null or malla.mesh == null:
		n.free()
		return false
	var caja_idx := PackedInt32Array()
	var asa_idx := PackedInt32Array()
	var pivote: Vector3 = Vector3(INF, INF, INF)
	for isla in MallaIslas.islas(malla.mesh):
		var c: AABB = isla["caja"]
		if c.get_center().y > ALTO_ASA:
			asa_idx.append_array(isla["idx"])
			pivote = Vector3(c.get_center().x, minf(pivote.y, c.position.y), 0.0)
		else:
			caja_idx.append_array(isla["idx"])
	if asa_idx.is_empty():
		n.free()
		return false
	var mando := Node3D.new()
	mando.name = "palanca"
	mando.position = esquina
	mando.scale = Vector3.ONE * ESCALA_DETONADOR
	# Su X local, a lo largo de los ramales (de a hacia b): el asa se inclina a +X con el ramal b y a −X con el a.
	var eje := Vector2(float(ramal_b.x - ramal_a.x), float(ramal_b.y - ramal_a.y))
	if eje.length() < 0.01:
		eje = Vector2(1.0, 0.0)
	mando.rotation.y = atan2(-eje.y, eje.x)
	add_child(mando)
	var base := Node3D.new()
	base.transform = malla.transform           # la de la pieza: escala 0,68 y centrado
	mando.add_child(base)
	var mc := MeshInstance3D.new()
	mc.mesh = MallaIslas.malla_de(malla.mesh, caja_idx)
	Vagoneta3D._copiar_materiales(malla, mc)   # el material del pack va en la pieza, no en la malla: sin esto sale blanco
	base.add_child(mc)
	_asa = Node3D.new()
	_asa.name = "asa"
	_asa.position = pivote
	base.add_child(_asa)
	var ma := MeshInstance3D.new()
	ma.mesh = MallaIslas.malla_de(malla.mesh, asa_idx, pivote)
	Vagoneta3D._copiar_materiales(malla, ma)
	_asa.add_child(ma)
	n.free()
	Ocluso3D.convertir_nodo(mando)
	_asa.rotation.z = -INCLINA_ASA if en_b else INCLINA_ASA
	return true


func _flecha_y_listo() -> void:
	_flecha = MeshInstance3D.new()
	var fm := PrismMesh.new()
	fm.size = Vector3(0.5, 0.6, 0.04)
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = Color(1, 1, 1, 0.85)
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.material = mf
	_flecha.mesh = fm
	add_child(_flecha)
	_pintar()


func _exit_tree() -> void:
	if _por_celda.get(celda, null) == self:
		_por_celda.erase(celda)


func _process(delta: float) -> void:
	_t = maxf(_t - delta, 0.0)
	# El aviso «E» sobre la palanca, solo con la jugadora al lado.
	if _aviso == null:
		_aviso = Label3D.new()
		_aviso.text = "E · cambiar vía"
		_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_aviso.no_depth_test = true
		_aviso.font_size = 40
		_aviso.pixel_size = 0.006
		_aviso.outline_size = 10
		_aviso.modulate = Color(1.0, 0.92, 0.6)
		_aviso.position = _pos_mando + Vector3(0.0, ALTO_PALANCA + 0.7, 0.0)
		add_child(_aviso)
	var j: Node3D = Puzle3D.jugador_nodo(get_tree(), null) if is_inside_tree() else null
	var cerca: bool = false
	if j != null:
		var d: Vector3 = j.global_position - global_position
		d.y = 0.0
		cerca = d.length() <= ALCANCE_USAR
	_aviso.visible = cerca


var _aviso: Label3D = null


func ramal() -> Vector2i:
	return ramal_b if en_b else ramal_a


## Saliendo de la aguja hacia `d`: vale el ramal puesto y el tronco.
func deja_salir(d: Vector2i) -> bool:
	return d == ramal() or d == tronco


## Llegando DESDE el lado `de` (dirección que apunta hacia donde se viene): por el tronco sigue el ramal puesto; por un ramal, sale por el tronco.
func salida_desde(de: Vector2i) -> Vector2i:
	return ramal() if de == tronco else tronco


func cambiar() -> void:
	if _t > 0.0:
		return
	_t = T_ENFRIAR
	en_b = not en_b
	cambios += 1
	_pintar()
	Sfx.play(self, "boton")
	cambia.emit("b" if en_b else "a")


func _pintar() -> void:
	var d: Vector2i = ramal()
	var col: Color = COLOR_B if en_b else COLOR_A
	if _mat_palanca != null:
		_mat_palanca.albedo_color = col
		_mat_palanca.emission = col
	if _palanca != null:
		_palanca.rotation = Vector3(0.0, 0.0, 0.45 if en_b else -0.45)
	if _asa != null and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(_asa, "rotation:z", -INCLINA_ASA if en_b else INCLINA_ASA, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _flecha != null:
		# La flecha tumbada en el suelo, de la aguja hacia el ramal puesto.
		_flecha.position = Vector3(float(d.x), 0.0, float(d.y)) * Terreno3D.casilla * 0.3 + Vector3(0.0, 0.12, 0.0)
		_flecha.rotation = Vector3(-PI * 0.5, atan2(-float(d.x), -float(d.y)), 0.0)
		(_flecha.mesh as PrismMesh).material.set("albedo_color", Color(col.r, col.g, col.b, 0.85))


# --- E a su lado (24/11, Pablo en el playtest: «¿cómo cambio la dirección?»): como el prisma, a ≤ ALCANCE_USAR u -------------

const ALCANCE_USAR: float = 2.7


func _unhandled_input(ev: InputEvent) -> void:
	if not ev.is_action_pressed("interactuar", false):        # E (o lo que tenga asignado «interactuar»), sin repetición
		return
	var j: Node3D = Puzle3D.jugador_nodo(get_tree(), null)
	if j == null:
		return
	var d: Vector3 = j.global_position - global_position
	d.y = 0.0
	if d.length() <= ALCANCE_USAR:
		cambiar()
		get_viewport().set_input_as_handled()


# --- contrato con los hechizos: ya no le hacen nada (24/11, Pablo: solo con E). Sin capa de colisión, ni siquiera es blanco ---------------

func on_spell_hit(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, _hechizo: Hechizo = null) -> void:
	pass


func spell_reacts(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, _hechizo: Hechizo = null) -> bool:
	return false


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 0

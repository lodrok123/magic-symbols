class_name Aguja3D
extends Area3D

## AGUJA DE VÍA (24/11/2026, puzles de vagoneta). En una casilla de vía donde la vía se abre en Y: un TRONCO y dos RAMALES (`a` y `b`).
## Una palanca al lado de la vía la cambia de un ramal al otro:
##   · un golpe de cualquier hechizo a la palanca (`on_spell_hit`), o la acción `cambiar` de una regla (un botón, un brasero…);
##   · una flecha en el suelo y el color de la palanca dicen qué ramal está puesto.
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
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	# La palanca, a un lado de la vía (en la esquina entre el tronco y el ramal b), y su caja de golpe.
	var S: float = Terreno3D.casilla
	var esquina: Vector3 = (Vector3(float(-tronco.x), 0.0, float(-tronco.y)) * -0.38 + Vector3(float(ramal_b.x - ramal_a.x), 0.0, float(ramal_b.y - ramal_a.y)).normalized() * 0.38) * S
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(0.5, ALTO_PALANCA + 0.3, 0.5)
	forma.shape = caja
	forma.position = esquina + Vector3(0.0, (ALTO_PALANCA + 0.3) * 0.5, 0.0)
	add_child(forma)
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
	if _flecha != null:
		# La flecha tumbada en el suelo, de la aguja hacia el ramal puesto.
		_flecha.position = Vector3(float(d.x), 0.0, float(d.y)) * Terreno3D.casilla * 0.3 + Vector3(0.0, 0.12, 0.0)
		_flecha.rotation = Vector3(-PI * 0.5, atan2(-float(d.x), -float(d.y)), 0.0)
		(_flecha.mesh as PrismMesh).material.set("albedo_color", Color(col.r, col.g, col.b, 0.85))


# --- contrato con los hechizos: cualquier golpe cambia la aguja -------------------------------------------------------

func on_spell_hit(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, _hechizo: Hechizo = null) -> void:
	cambiar()


func spell_reacts(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, _hechizo: Hechizo = null) -> bool:
	return true


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 0

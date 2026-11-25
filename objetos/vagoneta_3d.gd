class_name Vagoneta3D
extends BloqueEmpujable3D

## VAGONETA EN RAÍLES (24/11/2026, Pablo: «puzzles con la carretilla: moverla de un punto a otro siguiendo unos raíles», «variantes tanto con
## mecanismos como moviéndola manualmente»). Es un BloqueEmpujable3D (mismo empuje con peso, misma placa, mismo «nunca se atasca») que SOLO
## pisa las casillas de su vía (`rieles`):
##   · A MANO: la jugadora la empuja andando como la piedra, una casilla por empujón, siempre por la vía. En una curva, se cambia de lado y se
##     sigue empujando en la dirección nueva.
##   · POR MECANISMO: la acción `rodar` (de una regla: un botón, un brasero, una placa…) la lanza; RUEDA sola, a la velocidad del empuje, y sigue
##     la vía en las curvas hasta el final o hasta chocar. Si choca contra un MURO AGRIETADO, lo rompe (señal `choca`).
##   · AGUJAS (`Aguja3D`, pieza `aguja`): en un cruce en Y, la aguja decide por qué ramal sigue; rodando la obedece, y a mano solo se puede
##     salir de la aguja hacia el ramal elegido (o volver por el tronco).
## Pesa 3 en las placas de peso (como el bloque de piedra). No tiende las vetas (no es piedra). Si nada la mueve ya, vuelve a su casilla de partida.
##
## Mapa: `; pieza <id> vagoneta <x> <y> rieles=<celdas> [sentido=n|e|s|o]` (escenas/puzle.gd). `sentido` = hacia dónde rueda con `rodar` sin argumento
## (sin él, hacia el único lado con vía; en medio de una vía, hacia el norte o el este). La casilla de la pieza tiene que ser de la vía.

signal choca(celda: Vector2i)

const MODELO: String = "res://arte/lostcave/piezas/lost_trolley_a.tscn"   ## la vagoneta del pack Lost Cave (fuera de git); sin ella, una caja de madera
const ESCALA_MODELO: float = 1.0
const ALTO_RIEL: float = 0.06
const ANCHO_VIA: float = 0.62                 ## fracción de casilla entre los dos carriles
const COLOR_RIEL: Color = Color(0.36, 0.33, 0.32)
const COLOR_TRAVIESA: Color = Color(0.42, 0.29, 0.17)

var rieles: Dictionary = {}                    ## Vector2i -> true: las casillas de la vía
var sentido: Vector2i = Vector2i.ZERO
var rodando: bool = false
var choques: int = 0                           ## las pruebas
var _via: Node3D = null


func preparar_via(p_celda: Vector2i, p_rieles: Array, p_sentido: String, mundo: Node = null) -> void:
	rieles.clear()
	for c in p_rieles:
		rieles[c as Vector2i] = true
	rieles[p_celda] = true
	preparar(p_celda, "piedra", mundo)
	material = "vagoneta"
	_piedras.erase(p_celda)                    # no tiende vetas
	peso_valor = 3
	sentido = _dir_de(p_sentido)
	if sentido == Vector2i.ZERO:
		sentido = _sentido_libre()


func _ready() -> void:
	super._ready()
	if _cuerpo != null and is_instance_valid(_cuerpo):
		_cuerpo.queue_free()
		_cuerpo = null
	if not _poner_modelo():
		_poner_caja_madera()
	_dibujar_via.call_deferred()


func _exit_tree() -> void:
	super._exit_tree()
	if _via != null and is_instance_valid(_via):
		_via.queue_free()


static func _dir_de(s: String) -> Vector2i:
	return {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "o": Vector2i(-1, 0)}.get(s, Vector2i.ZERO)


## Sin `sentido`: hacia el único vecino de vía (un extremo); si hay varios, el primero de norte, este, sur, oeste.
func _sentido_libre() -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if rieles.has(celda + d):
			return d
	return Vector2i(0, -1)


# --- aspecto ---------------------------------------------------------------------------------------------------------

## 24/11 (Pablo, playtest: «las ruedas deben ir paralelas a las vías; anima las ruedas»): el modelo del pack es UNA malla. Sus ruedas y ejes son islas sueltas
## dentro de ella; se recortan (`_partir_malla`, una vez por modelo) en una malla de la CAJA y una por pieza que GIRA, cada una con el pivote en su centro.
## El modelo rueda a lo largo de su X: `_giro` lo orienta según la vía (0° si la vía va de este a oeste, 90° si va de norte a sur).
func _poner_modelo() -> bool:
	if not ResourceLoader.exists(MODELO):
		return false
	var escena: PackedScene = load(MODELO) as PackedScene
	if escena == null:
		return false
	var n: Node3D = escena.instantiate() as Node3D
	var malla: MeshInstance3D = n.get_node_or_null("modelo/malla") as MeshInstance3D
	if malla == null or malla.mesh == null:
		n.free()
		return false
	var partes: Dictionary = _partir_malla(malla.mesh)
	var raiz := Node3D.new()
	raiz.name = "vagoneta"
	raiz.scale = Vector3.ONE * ESCALA_MODELO
	add_child(raiz)
	_giro = Node3D.new()
	_giro.name = "giro"
	raiz.add_child(_giro)
	var base := Node3D.new()                   # la transformación de la malla en su pieza (escala 0,68 y el centrado)
	base.name = "malla"
	base.transform = malla.transform
	_giro.add_child(base)
	var caja := MeshInstance3D.new()
	caja.name = "caja"
	caja.mesh = partes["caja"]
	_copiar_materiales(malla, caja)
	base.add_child(caja)
	_ruedas.clear()
	for r in partes["ruedas"]:
		var piv := Node3D.new()
		piv.name = "rueda"
		piv.position = r[1]
		base.add_child(piv)
		var mr := MeshInstance3D.new()
		mr.mesh = r[0]
		_copiar_materiales(malla, mr)
		piv.add_child(mr)
		_ruedas.append(piv)
	_radio_rueda = float(partes["radio"]) * malla.transform.basis.get_scale().x * ESCALA_MODELO
	n.free()
	_cuerpo = raiz
	Ocluso3D.convertir_nodo(raiz)
	_giro.rotation.y = _yaw_de(_eje_de_via(celda))
	_pos_antes = global_position if is_inside_tree() else position
	return true


static func _copiar_materiales(de: MeshInstance3D, a: MeshInstance3D) -> void:
	a.material_override = de.material_override
	for s in de.get_surface_override_material_count():
		if de.get_surface_override_material(s) != null and s < a.get_surface_override_material_count():
			a.set_surface_override_material(s, de.get_surface_override_material(s))


## La malla partida: {caja: ArrayMesh, ruedas: [[ArrayMesh centrada en su eje, centro]], radio: radio de rueda (unidades de la malla)}. En caché por malla.
## Una pieza que GIRA es una isla de triángulos casi redonda de perfil (ancho ≈ alto en X e Y), baja (centro por debajo de ALTO_EJE) y no más
## ancha que una rueda: las cuatro ruedas y los dos ejes. Lo demás es la caja.
const ALTO_EJE: float = 0.32
static var _cache_partes: Dictionary = {}

static func _partir_malla(m: Mesh) -> Dictionary:
	if _cache_partes.has(m.resource_path + str(m.get_instance_id())):
		return _cache_partes[m.resource_path + str(m.get_instance_id())]
	var caja_idx := PackedInt32Array()
	var ruedas: Array = []
	var radio: float = 0.2
	for isla in MallaIslas.islas(m):
		var c: AABB = isla["caja"]
		var redonda: bool = absf(c.size.x - c.size.y) <= 0.1 * maxf(c.size.x, c.size.y) + 0.005
		if redonda and c.get_center().y < ALTO_EJE and maxf(c.size.x, c.size.y) <= 0.6:
			ruedas.append([MallaIslas.malla_de(m, isla["idx"], c.get_center()), c.get_center()])
			if c.size.y > 0.2:
				radio = c.size.y * 0.5
		else:
			caja_idx.append_array(isla["idx"])
	var res: Dictionary = {"caja": MallaIslas.malla_de(m, caja_idx), "ruedas": ruedas, "radio": radio}
	_cache_partes[m.resource_path + str(m.get_instance_id())] = res
	return res


## Eje de la vía en la casilla `c`: (1,0) si sigue de este a oeste, (0,1) si de norte a sur (en una curva, el primero que tenga).
func _eje_de_via(c: Vector2i) -> Vector2i:
	if rieles.has(c + Vector2i(1, 0)) or rieles.has(c + Vector2i(-1, 0)):
		if not (rieles.has(c + Vector2i(0, 1)) or rieles.has(c + Vector2i(0, -1))):
			return Vector2i(1, 0)
	if rieles.has(c + Vector2i(0, 1)) or rieles.has(c + Vector2i(0, -1)):
		return Vector2i(0, 1)
	return Vector2i(1, 0)


## El giro del modelo (rueda a lo largo de su X) para ir por un eje: 0 a lo largo de X, 90° a lo largo de Z. Es simétrico: 0 y 180° valen igual.
static func _yaw_de(d: Vector2i) -> float:
	return 0.0 if d.x != 0 else PI * 0.5


# --- movimiento a la vista: giro, ruedas y sonido (24/11, playtest de Pablo) ---------------------------------------------

const T_GIRO_CURVA: float = 0.18              ## s que tarda en orientarse al tomar una curva
const VEL_SONIDO_MIN: float = 0.08            ## u/s por debajo de las cuales se calla la rodadura
var _giro: Node3D = null
var _ruedas: Array = []
var _radio_rueda: float = 0.14
var _angulo_ruedas: float = 0.0
var _pos_antes: Vector3 = Vector3.ZERO
var _rodadura: AudioStreamPlayer3D = null
var _t_quieta: float = 0.0
var _dir_antes: Vector2i = Vector2i.ZERO


func _process(delta: float) -> void:
	super._process(delta)
	_animar(delta)


func _animar(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	var ahora: Vector3 = global_position
	var paso: Vector3 = ahora - _pos_antes
	_pos_antes = ahora
	paso.y = 0.0
	var vel: float = paso.length() / delta
	# Orientación: hacia donde va (en marcha) o según la vía de su casilla (quieta). Ángulo más corto, módulo 180°.
	if _giro != null:
		var objetivo: float = _yaw_de(_dir) if moviendo and _dir != Vector2i.ZERO else _yaw_de(_eje_de_via(celda))
		var dif: float = wrapf(objetivo - _giro.rotation.y, -PI * 0.5, PI * 0.5)
		_giro.rotation.y += dif * clampf(delta / T_GIRO_CURVA, 0.0, 1.0)
		# Ruedas: giran lo que avanza a lo largo del eje del modelo (en contra si va hacia atrás).
		if not _ruedas.is_empty() and vel > 0.001:
			var eje: Vector3 = _giro.global_transform.basis.x.normalized()
			_angulo_ruedas -= paso.dot(eje) / maxf(_radio_rueda, 0.01)
			for piv in _ruedas:
				(piv as Node3D).rotation.z = _angulo_ruedas
	# 25/11 (Pablo): traqueteo seco con roce por debajo. Arrancar no chirría;
	# el chirrido se reserva a las curvas y no domina la rodadura en recta.
	if vel > VEL_SONIDO_MIN:
		_t_quieta = 0.0
		if _rodadura == null or not is_instance_valid(_rodadura):
			_rodadura = Sfx3D.ambiente(self, "vagoneta_rueda")
		if _rodadura != null and is_instance_valid(_rodadura):
			_rodadura.pitch_scale = clampf(0.55 + vel * 0.45, 0.55, 1.5)
			_rodadura.volume_db = float(Sfx.AJUSTES.get("vagoneta_rueda", Sfx3D.AMBIENTES["vagoneta_rueda"]["db"])) + linear_to_db(clampf(vel / VEL_EMPUJE, 0.25, 1.0))
		if moviendo and _dir_antes != Vector2i.ZERO and _dir != _dir_antes:
			Sfx3D.play(self, "vagoneta_chirrido", -6.0)
	else:
		_t_quieta += delta
		if _t_quieta > 0.12 and _rodadura != null:
			Sfx3D.parar(_rodadura)
			_rodadura = null
	if moviendo:
		_dir_antes = _dir
	elif _t_quieta > 0.12:
		_dir_antes = Vector2i.ZERO


## El traqueteo: la rueda pasa una junta de raíl en cada casilla.
func _acabar_casilla() -> void:
	super._acabar_casilla()
	if rodando:
		_dir = _siguiente(celda, _dir)
	Sfx3D.play(self, "vagoneta_junta", 0.0 if rodando else -5.0, 1.15 if rodando else 0.9)


## Empujada a mano tampoco suena a piedra arrastrada (el «arrastre» del bloque): suena su rodadura (`_animar`).
func empujar(dir: Vector2i, con_jugadora: bool = false, impulso: bool = false) -> bool:
	var ok: bool = super.empujar(dir, con_jugadora, impulso)
	if ok and _sonido != null:
		Sfx3D.parar(_sonido)
		_sonido = null
	return ok


func _poner_caja_madera() -> void:
	var m := MeshInstance3D.new()
	m.name = "vagoneta"
	var b := BoxMesh.new()
	b.size = Vector3(Terreno3D.casilla * 0.7, 0.9, Terreno3D.casilla * 0.85)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.33, 0.2)
	mat.roughness = 0.9
	b.material = mat
	m.mesh = b
	m.position = Vector3(0.0, 0.55, 0.0)
	add_child(m)
	_cuerpo = m


## La vía: por cada casilla, medio tramo (dos carriles y una traviesa) hacia cada vecino que también es vía. Va en el padre: no se mueve con la vagoneta.
func _dibujar_via() -> void:
	var padre: Node = get_parent()
	if padre == null:
		return
	_via = Node3D.new()
	_via.name = "Via_" + String(name)
	padre.add_child(_via)
	var S: float = Terreno3D.casilla
	var mat_r := StandardMaterial3D.new()
	mat_r.albedo_color = COLOR_RIEL
	mat_r.metallic = 0.6
	mat_r.roughness = 0.45
	var mat_t := StandardMaterial3D.new()
	mat_t.albedo_color = COLOR_TRAVIESA
	mat_t.roughness = 0.95
	for c_v in rieles.keys():
		var c: Vector2i = c_v
		var centro: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
		for d in DIRS:
			if not rieles.has(c + d):
				continue
			var eje: Vector3 = Vector3(float(d.x), 0.0, float(d.y))
			var lado: Vector3 = Vector3(-eje.z, 0.0, eje.x)
			for s in [-1.0, 1.0]:
				var riel := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.07, ALTO_RIEL, S * 0.5 + 0.035) if d.x == 0 else Vector3(S * 0.5 + 0.035, ALTO_RIEL, 0.07)
				bm.material = mat_r
				riel.mesh = bm
				riel.position = centro + eje * S * 0.25 + lado * (s * S * ANCHO_VIA * 0.5) + Vector3(0.0, 0.05 + ALTO_RIEL * 0.5, 0.0)
				_via.add_child(riel)
			var trav := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(S * (ANCHO_VIA + 0.2), 0.05, 0.16) if d.x == 0 else Vector3(0.16, 0.05, S * (ANCHO_VIA + 0.2))
			tm.material = mat_t
			trav.mesh = tm
			trav.position = centro + eje * S * 0.3 + Vector3(0.0, 0.03, 0.0)
			_via.add_child(trav)


# --- la vía manda ----------------------------------------------------------------------------------------------------

## Solo entra en casillas de su vía; y saliendo de una aguja, solo por su ramal elegido o por el tronco.
func _casilla_libre(c: Vector2i, ref: Vector2i) -> bool:
	if not rieles.has(c) or not rieles.has(ref):
		return false
	var ag: Aguja3D = Aguja3D.en(ref)
	if ag != null and not ag.deja_salir(c - ref):
		return false
	return super._casilla_libre(c, ref)


## Rodando, al llegar a una casilla elige por dónde sigue: lo que diga la aguja; si no, recto; si no, el único otro vecino de vía (una curva).
func _siguiente(c: Vector2i, d: Vector2i) -> Vector2i:
	var ag: Aguja3D = Aguja3D.en(c)
	if ag != null:
		return ag.salida_desde(-d)
	if rieles.has(c + d):
		return d
	var otros: Array = []
	for x in DIRS:
		if x != -d and rieles.has(c + x):
			otros.append(x)
	return otros[0] if otros.size() == 1 else d


func _libre_mas_alla() -> bool:
	if not rodando:
		return super._libre_mas_alla()
	var d: Vector2i = _siguiente(_destino, _dir)
	return _casilla_libre(_destino + d, _destino)


## 24/11 (Pablo, playtest de la aguja: «la vagoneta sale demasiado rápido: a la velocidad a la que la empujas»): lanzada va a la MISMA velocidad que
## empujada (BloqueEmpujable3D.VEL_EMPUJE, con su arranque y su frenada). Siempre «lenta»; rodando, se da por empujada sin parar (`_sostenido`)
## y encadena casilla tras casilla hasta el final de la vía o hasta chocar.
func _es_lento() -> bool:
	return true


func _sostenido() -> bool:
	return rodando or super._sostenido()


## La pone a rodar sola por la vía (el MECANISMO). `dir` = "n", "e", "s", "o" o "" (su `sentido`). false si no puede salir.
func rodar(dir: String = "") -> bool:
	var d: Vector2i = _dir_de(dir) if dir != "" else sentido
	if moviendo:
		return false
	rodando = true
	if not empujar(d, false, true):
		rodando = false
		return false
	return true


func _parar() -> void:
	var venia: bool = rodando
	rodando = false
	super._parar()
	if not venia:
		return
	# Rodando contra un muro agrietado: lo rompe.
	var delante: Vector2i = celda + _dir
	var muro: MuroAgrietado3D = _muro_en(delante)
	choques += 1
	if muro != null and not muro.roto_ya:
		muro.romper()
	Sfx3D.play(self, "vagoneta_choque")
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 0.5)
	choca.emit(delante)


func _muro_en(c: Vector2i) -> MuroAgrietado3D:
	if not is_inside_tree():
		return null
	# Primero los hermanos (Puzle3D cuelga muro y vagoneta del mismo contenedor); si no, todo el árbol.
	var padre: Node = get_parent()
	var donde: Array = padre.get_children() if padre != null else []
	for pasada in 2:
		for n in donde:
			if n is MuroAgrietado3D and (n as MuroAgrietado3D).celda == c:
				return n as MuroAgrietado3D
		donde = get_tree().root.find_children("*", "", true, false)
	return null


# --- «nunca atascada»: delante tiene que haber VÍA; detrás basta suelo donde plantarse --------------------------------

## Atascada = en ningún sentido hay vía libre delante y suelo libre detrás para empujarla. En una curva no lo está (se rodea y se empuja en
## la dirección nueva); en el final de una vía sin suelo detrás, sí: si no está sobre una placa, a los 3 s vuelve a su casilla de partida
## (por ejemplo, la que tomó el ramal equivocado de una aguja).
func _perdido() -> bool:
	for d in DIRS:
		if rieles.has(celda + d) and _libre_de_obra(celda + d) and _libre_de_obra(celda - d):
			return false
	return true

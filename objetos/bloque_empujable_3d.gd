class_name BloqueEmpujable3D
extends Area3D

## BLOQUE EMPUJABLE (27/10, docs/EMPUJAR_BLOQUES.md). Un bloque que la jugadora EMPUJA andando contra él (Jugador3D, 0,35 s apretando) o que el VIENTO se lleva. Ocupa una casilla y pesa:
## bloquea el paso (jugadora, enemigos, flechas: `Terreno3D.bloquear_celda`, la misma solidez que el muro agrietado), pisa las placas (grupo `peso`, como el bloque de tierra del hechizo) y está en el
## grupo `empujable`, por el que lo encuentra Jugador3D. No usa `Terreno3D.fijar_altura`: se mueve.
##
## PESO (28/10): nada de tweens con ease. La piedra arranca costosa (`T_ARRANQUE`), va a `VEL_EMPUJE` constante y solo frena (`T_FRENADO`) al final de la última casilla; si la jugadora sigue apretando encadena la
## siguiente sin parar. La jugadora va pegada al bloque mientras `acoplado` (lo gestiona Jugador3D).
## DOS MATERIALES
##   · `piedra`: avanza a `VEL_EMPUJE` (≈ 2,3 s por casilla). Modelo `bloque_enlace` (el bloque de la Cueva). Un bloque de piedra sobre el HUECO de una veta (`Pulso3D.enlaces`) lo
##     TIENDE: el pulso cruza (`piedra_en(c)` lo lee `Pulso3D.enlace_tendido`).
##   · `hielo`: arranca igual (media casilla pegado a la jugadora) y luego se suelta y RESBALA casilla a casilla (≈ 0,25 s cada una, `VEL_HIELO`) hasta que la siguiente no esté libre: se para en seco contra lo que sea (pared, otro bloque, una barrera de tierra, un
##     enemigo, la jugadora) y suena un golpe. No conduce el pulso. Cubo translúcido azulado.
##
## Cada paso bloquea la casilla DESTINO al empezar y libera la de origen al acabar: nunca hay un hueco por el que colarse. Mientras se mueve no acepta otro empujón. Al terminar un movimiento completo
## emite `movido(celda)`.
##
## `puede_moverse(dir)`: la casilla destino está en el mapa, no está bloqueada, no es agua ni lava, no está a otro nivel (una barrera de tierra la sube: obstáculo), y no hay otro bloque, ni un
## enemigo vivo, ni la jugadora.
##
## VIENTO: un hechizo de viento (`on_spell_hit`) lo empuja en la dirección cardinal dominante del impacto (respeta `puede_moverse`). Los demás elementos no le hacen nada: no se rompe ni se funde.
##
## NO SE GUARDA su posición: al recargar el nivel vuelve a su casilla del mapa. Y para que NUNCA quede atascado sin remedio: un bloque que ya no se puede mover en ninguna dirección (contra una pared
## al final de una pista, tras pasarse de la placa) y que no está sirviendo (ni sobre una placa ni sobre un hueco de veta) se DESHACE a los `T_PERDIDO` s y vuelve a formarse en su casilla del mapa.
##
## Se coloca desde un mapa con `; pieza <id> bloque <x> <y> [material=piedra|hielo]` (escenas/puzle.gd) o con `preparar` desde código.

signal movido(celda: Vector2i)
signal paso_dado(celda: Vector2i, vel: float)      ## al llegar al centro de CADA casilla (también al encadenar sin parar); `vel` = u/s con que pasa
signal reaparecio

const MODELO_PIEDRA: String = "bloque_enlace"
## --- PESO (28/10, Pablo: «movimientos lentos y sostenidos»): cifras para afinar de oído ---
const VEL_EMPUJE: float = 1.0           ## u/s a la que va la piedra (≈ 2,3 s por casilla; la jugadora anda a 1,6)
const T_ARRANQUE: float = 0.4           ## s que tarda en alcanzar VEL_EMPUJE desde parado
const T_FRENADO: float = 0.3            ## s de frenado suave al final de la última casilla
const VEL_HIELO: float = 9.2            ## u/s del hielo ya suelto (≈ 0,25 s por casilla)
const T_SUELTA_HIELO: float = 0.15      ## s que tarda el hielo en pasar de VEL_EMPUJE a VEL_HIELO al soltarse
const T_FRENADO_HIELO: float = 0.12     ## s de frenado «al chocar» del hielo
const MEDIA_CASILLA: float = 0.5        ## fracción de casilla que el hielo va pegado a la jugadora antes de soltarse
const VEL_MIN: float = 0.3              ## u/s: suelo de la velocidad al frenar (llega al centro de la casilla sin quedarse a arrastrarse)
const T_PERDIDO: float = 3.0            ## s que aguanta un bloque perdido antes de volver a formarse en su casilla
const ALTO: float = 1.5                 ## u: alto de la caja que se golpea con hechizos
const ESCALA_PIEDRA: Vector3 = Vector3(1.55, 1.9, 1.55)      ## el modelo mide 1,0 × 0,7 × 1,0 (una losa): se ensancha y se alza hasta parecer un bloque en una casilla de 2,3
const LADO_HIELO: float = 1.56
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Registro de los bloques por casilla (la que ocupan o acaban de reservar). Solo para consultas entre bloques y para el pulso.
static var _ocupadas: Dictionary = {}       ## Vector2i -> BloqueEmpujable3D
static var _piedras: Dictionary = {}        ## Vector2i -> BloqueEmpujable3D (piedra en reposo en esa casilla)

var celda: Vector2i = Vector2i.ZERO
var origen: Vector2i = Vector2i.ZERO    ## su casilla del mapa
var material: String = "piedra"
var moviendo: bool = false
var empujones: int = 0                  ## empujones aceptados (las pruebas)
var pasos: int = 0                      ## casillas recorridas en total (las pruebas)
var ultimo_paro: Vector2i = Vector2i.ZERO
var _dir: Vector2i = Vector2i.ZERO
var _destino: Vector2i = Vector2i.ZERO
var _cuerpo: Node3D = null
var _mundo: Node = null
var _t_perdido: float = 0.0
var _t_vigilar: float = 0.0
var vel: float = 0.0                    ## u/s actuales del bloque
var acoplado: bool = false              ## la jugadora va pegada a él (Jugador3D pone su posición con la del bloque)
var _s: float = 0.0                     ## u recorridas dentro de la casilla en curso
var _x_total: float = 0.0               ## u recorridas desde que empezó el movimiento
var _con_jugadora: bool = false
var _decidido: bool = false
var _frenando: bool = false
var _a_freno: float = 0.0
var _sost_frame: int = -99
var _sost_dir: Vector2i = Vector2i.ZERO
var _sonido: AudioStreamPlayer3D = null


## `mundo` = la maqueta (da el modelo con su escala); sin ella se carga `arte/piezas/bloque_enlace.tscn`.
func preparar(p_celda: Vector2i, p_material: String = "piedra", mundo: Node = null) -> void:
	_mundo = mundo
	celda = p_celda
	origen = p_celda
	material = p_material if p_material == "hielo" else "piedra"
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	Terreno3D.bloquear_celda(celda)
	_registrar(celda)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	add_to_group("peso")
	add_to_group("empujable")
	var ancho: float = Terreno3D.casilla * 0.9
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ancho, ALTO, ancho)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(forma)
	if material == "hielo":
		_poner_hielo()
	elif not _poner_piedra():
		_poner_caja_piedra()


func _exit_tree() -> void:
	if _sonido != null and is_instance_valid(_sonido):
		_sonido.queue_free()
	for c in _ocupadas.keys():
		if _ocupadas[c] == self:
			_ocupadas.erase(c)
	for c in _piedras.keys():
		if _piedras[c] == self:
			_piedras.erase(c)


## ¿Hay un bloque de PIEDRA quieto en esta casilla? (lo lee `Pulso3D.enlace_tendido`: sobre el hueco de una veta, la tiende.)
static func piedra_en(c: Vector2i) -> bool:
	return _piedras.has(c)


## El bloque (cualquiera) que ocupa o ha reservado esta casilla, o null.
static func en(c: Vector2i) -> BloqueEmpujable3D:
	return _ocupadas.get(c, null) as BloqueEmpujable3D


func _registrar(c: Vector2i) -> void:
	_ocupadas[c] = self
	if material == "piedra" and not moviendo:
		_piedras[c] = self


func _olvidar(c: Vector2i) -> void:
	if _ocupadas.get(c, null) == self:
		_ocupadas.erase(c)
	if _piedras.get(c, null) == self:
		_piedras.erase(c)


# ---------------------------------------------------------------------------------------------------------------------
#  Aspecto
# ---------------------------------------------------------------------------------------------------------------------

## El bloque de la Cueva (`bloque_enlace`) con el material común (que lo oscurece y lo desvanece como el resto de piezas). false si no hay modelo.
func _poner_piedra() -> bool:
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", MODELO_PIEDRA) as Node3D
	if n == null and ResourceLoader.exists("res://arte/piezas/%s.tscn" % MODELO_PIEDRA):
		var escena: PackedScene = load("res://arte/piezas/%s.tscn" % MODELO_PIEDRA) as PackedScene
		n = escena.instantiate() as Node3D if escena != null else null
	if n == null:
		return false
	n.name = "bloque"
	n.scale = ESCALA_PIEDRA
	add_child(n)
	_cuerpo = n
	Ocluso3D.convertir_nodo(n)
	return true


## Sin modelo: una caja gris.
func _poner_caja_piedra() -> void:
	var m := MeshInstance3D.new()
	m.name = "bloque"
	var b := BoxMesh.new()
	b.size = Vector3(LADO_HIELO, ALTO, LADO_HIELO)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52)
	mat.roughness = 0.95
	b.material = mat
	m.mesh = b
	m.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(m)
	_cuerpo = m


## El hielo: un cubo translúcido azulado, liso y con un fulgor frío (no hay textura de hielo en `arte/suelo_meshy`).
func _poner_hielo() -> void:
	var m := MeshInstance3D.new()
	m.name = "bloque"
	var b := BoxMesh.new()
	b.size = Vector3(LADO_HIELO, LADO_HIELO, LADO_HIELO)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.86, 1.0, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.metallic_specular = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.65, 1.0)
	mat.emission_energy_multiplier = 0.25
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.5
	b.material = mat
	m.mesh = b
	m.position = Vector3(0.0, LADO_HIELO * 0.5, 0.0)
	add_child(m)
	_cuerpo = m


# ---------------------------------------------------------------------------------------------------------------------
#  Empujar (28/10: sensación de PESO, Pablo; ver docs/EMPUJAR_BLOQUES.md)
# ---------------------------------------------------------------------------------------------------------------------

## ¿Cabe el bloque en la casilla vecina en esa dirección cardinal?
func puede_moverse(dir: Vector2i) -> bool:
	if absi(dir.x) + absi(dir.y) != 1:
		return false
	return _casilla_libre(celda + dir, celda)


## `ref` = la casilla desde la que se mira (la altura no puede cambiar respecto a ella).
func _casilla_libre(c: Vector2i, ref: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.bloqueada(c) or Terreno3D.es_agua(c):
		return false
	# Una barrera de tierra (altura ≥ 1) o una cornisa: otro nivel. No se sube ni se cae.
	if Terreno3D.altura_en(c) != Terreno3D.altura_en(ref):
		return false
	if _ocupadas.has(c) and _ocupadas[c] != self:
		return false
	if _hay_enemigo(c) or _jugadora_en(c):
		return false
	return true


func _hay_enemigo(c: Vector2i) -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and n is Combate3D and not (n as Combate3D).muerto and Terreno3D.celda_de((n as Combate3D).global_position) == c:
			return true
	return false


## La jugadora (su muñeco `pj`, el que anda de verdad: ver Pulsador3D._alguien_encima) en esa casilla.
func _jugadora_en(c: Vector2i) -> bool:
	if not is_inside_tree():
		return false
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	if lanz == null:
		lanz = get_tree().get_first_node_in_group("player")
	if lanz == null or lanz.get("jugador") == null:
		return false
	var j: Node3D = lanz.get("jugador") as Node3D
	var quien: Node3D = (j.get("pj") as Node3D) if j.get("pj") != null else j
	return Terreno3D.celda_de(quien.global_position) == c


## Lo empuja en `dir`. false si no puede o ya se está moviendo. `con_jugadora`: la empuja Jugador3D, que va PEGADA a él mientras `acoplado` (ella pone su posición con la del bloque).
## Perfil de la piedra: arranca desde 0 durante `T_ARRANQUE` s hasta `VEL_EMPUJE`, sigue a esa velocidad y solo frena (`T_FRENADO` s) al final de una casilla si ya nadie aprieta o la
## siguiente no está libre; si sigue apretando y hay sitio, ENCADENA la siguiente casilla sin parar. El hielo arranca igual (media casilla pegado a ella) y luego se suelta y resbala a `VEL_HIELO`.
func empujar(dir: Vector2i, con_jugadora: bool = false) -> bool:
	if moviendo or not puede_moverse(dir):
		return false
	empujones += 1
	moviendo = true
	_dir = dir
	_t_perdido = 0.0
	_con_jugadora = con_jugadora
	acoplado = con_jugadora
	vel = 0.0
	_x_total = 0.0
	_iniciar_casilla(0.0)
	if material == "piedra":
		_sonido = Sfx3D.ambiente(self, "arrastre")      # un arrastre en bucle mientras se mueve
	else:
		Sfx.play(self, "rodar")
	return true


## El empujón sostenido: Jugador3D lo llama cada fotograma mientras sigue apretando hacia donde va el bloque. Sin esto, la casilla en curso se acaba frenando.
func sostener(dir: Vector2i) -> void:
	_sost_frame = Engine.get_process_frames()
	_sost_dir = dir


func _sostenido() -> bool:
	return Engine.get_process_frames() - _sost_frame <= 2 and _sost_dir == _dir


func _iniciar_casilla(resto: float) -> void:
	_destino = celda + _dir
	Terreno3D.bloquear_celda(_destino)      # el destino se bloquea ANTES de mover: nadie se cuela
	_ocupadas[_destino] = self
	_piedras.erase(celda)                   # en marcha ya no tiende ningún hueco
	_s = resto
	_decidido = false
	_frenando = false


func _libre_mas_alla() -> bool:
	return _casilla_libre(_destino + _dir, _destino)


func _process(delta: float) -> void:
	if moviendo:
		_mover(minf(delta, 0.1))
		return
	if celda == origen:
		_t_perdido = 0.0
		return
	_t_vigilar -= delta
	if _t_vigilar > 0.0:
		return
	_t_vigilar = 0.25
	if _perdido() and not _sirviendo():
		_t_perdido += 0.25
		if _t_perdido >= T_PERDIDO:
			_reaparecer()
	else:
		_t_perdido = 0.0


func _mover(dt: float) -> void:
	var S: float = Terreno3D.casilla
	var piedra: bool = material == "piedra"
	var obj: float = VEL_EMPUJE if (piedra or _x_total < MEDIA_CASILLA * S) else VEL_HIELO
	if _frenando:
		vel = maxf(sqrt(maxf(2.0 * _a_freno * (S - _s), 0.0)), VEL_MIN)      # deceleración constante: la velocidad sale de lo que queda hasta el centro
	elif vel < obj:
		var acel: float = VEL_EMPUJE / T_ARRANQUE if obj <= VEL_EMPUJE else (VEL_HIELO - VEL_EMPUJE) / T_SUELTA_HIELO
		vel = minf(vel + acel * dt, obj)
	acoplado = _con_jugadora and (piedra or _x_total < MEDIA_CASILLA * S)
	var ds: float = vel * dt
	_s += ds
	_x_total += ds
	# ¿Hay que empezar a frenar? Se decide una vez por casilla, justo antes de llegar al final.
	if not _decidido and not _frenando:
		var t_f: float = T_FRENADO if piedra else T_FRENADO_HIELO
		if _s + vel * dt * 1.5 >= S - vel * t_f * 0.5:
			_decidido = true
			if not (_libre_mas_alla() and (not piedra or _sostenido())):
				_frenando = true
				_a_freno = vel * vel / (2.0 * maxf(S - _s, 0.02))
	if _s >= S - 0.0005:
		var resto: float = maxf(_s - S, 0.0)
		_acabar_casilla()
		if _frenando or not puede_moverse(_dir):
			_parar()
			return
		_iniciar_casilla(resto)
	_colocar()


func _colocar() -> void:
	var d := Vector3(float(_dir.x), 0.0, float(_dir.y))
	var a: Vector3 = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	var f: float = clampf(_s / Terreno3D.casilla, 0.0, 1.0)
	position = a + d * _s
	position.y = lerpf(a.y, Terreno3D.y_pies(_destino), f)


func _acabar_casilla() -> void:
	var anterior: Vector2i = celda
	celda = _destino
	pasos += 1
	Terreno3D.liberar_celda(anterior)       # la casilla que deja queda libre para ella justo cuando el bloque ya ha pasado a la siguiente
	_olvidar(anterior)
	_ocupadas[celda] = self
	paso_dado.emit(celda, vel)


func _parar() -> void:
	vel = 0.0
	acoplado = false
	moviendo = false
	ultimo_paro = celda
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	_registrar(celda)
	if _sonido != null:
		Sfx3D.parar(_sonido)
		_sonido = null
	if material == "hielo":
		Sfx.play(self, "clavar")            # el golpe seco al pararse
		if get_parent() is Node3D:
			VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 0.35)
	movido.emit(celda)


# ---------------------------------------------------------------------------------------------------------------------
#  Contrato con los hechizos: solo el viento
# ---------------------------------------------------------------------------------------------------------------------

## 28/10 · A2 (previsión): qué le haría este hechizo al bloque AHORA, sin moverlo: {} si nada (no es viento, no hay dirección, se está moviendo o no cabe), o
## {reaccion: "mueve", dir: Vector2i, destino: Vector2i (la casilla en que acabaría: una más; el HIELO resbala hasta que algo lo para)}. `on_spell_hit` empuja con esto.
func reaccion_a(rune_data: RuneData, direccion: Vector3) -> Dictionary:
	if rune_data == null or not rune_data.tags.has("viento") or moviendo:
		return {}
	var d: Vector2i = dir_cardinal(direccion)
	if d == Vector2i.ZERO or not puede_moverse(d):
		return {}
	var destino: Vector2i = celda + d
	if material == "hielo":
		while _casilla_libre(destino + d, destino):
			destino += d
	return {"reaccion": "mueve", "dir": d, "destino": destino}


func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO) -> void:
	var r: Dictionary = reaccion_a(rune_data, direccion)
	if not r.is_empty():
		empujar(r["dir"] as Vector2i)


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return rune_data != null and rune_data.tags.has("viento")


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## La dirección cardinal dominante (la componente mayor, en X o en Z) de un vector del mundo. ZERO si es nulo.
static func dir_cardinal(v: Vector3) -> Vector2i:
	if Vector2(v.x, v.z).length() < 0.01:
		return Vector2i.ZERO
	if absf(v.x) >= absf(v.z):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.z > 0.0 else -1)


# ---------------------------------------------------------------------------------------------------------------------
#  Que nunca quede atascado sin remedio
# ---------------------------------------------------------------------------------------------------------------------


## ¿Ya no hay manera de moverlo? Hace falta, en alguna dirección, casilla libre delante Y sitio detrás donde plantarse. Lo temporal (una barrera de tierra) no cuenta como pared.
func _perdido() -> bool:
	for d in DIRS:
		if _libre_de_obra(celda + d) and _libre_de_obra(celda - d):
			return false
	return true


func _libre_de_obra(c: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.es_agua(c):
		return false
	if Terreno3D.altura_en(c) >= 1:
		return Terreno3D.altura_en(c) == Terreno3D.altura_en(celda)      # una barrera de tierra pasa: lo que la hace pared es otra cosa
	if Terreno3D.bloqueada(c):
		return false
	return not (_ocupadas.has(c) and _ocupadas[c] != self)


## ¿Está donde tiene que estar? Sobre el hueco de una veta (piedra) o sobre una placa de presencia.
func _sirviendo() -> bool:
	if material == "piedra" and Pulso3D.enlaces.has(celda):
		return true
	var padre: Node = get_parent()
	if padre != null:
		for n in padre.get_children():
			if n is Pulsador3D and (n as Pulsador3D).celda == celda and (n as Pulsador3D).modo == "presencia":
				return true
	return false


## Se deshace (polvo o escarcha) y vuelve a formarse en su casilla del mapa, si está libre; si no, lo reintenta.
func _reaparecer() -> void:
	if not _casilla_de_origen_libre():
		_t_perdido = T_PERDIDO - 1.0
		return
	var aqui: Vector3 = global_position
	var viejo: Vector2i = celda
	Terreno3D.liberar_celda(viejo)
	_olvidar(viejo)
	celda = origen
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	Terreno3D.bloquear_celda(celda)
	_registrar(celda)
	_t_perdido = 0.0
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, aqui + Vector3(0.0, 0.1, 0.0), 0.8)
		VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 0.8)
	Sfx.play(self, "derrumbe")
	reaparecio.emit()


func _casilla_de_origen_libre() -> bool:
	return not Terreno3D.bloqueada(origen) and not (_ocupadas.has(origen) and _ocupadas[origen] != self) and not _hay_enemigo(origen) and not _jugadora_en(origen)

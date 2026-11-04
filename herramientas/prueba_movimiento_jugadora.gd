extends "res://herramientas/escenario_base.gd"
## MOVIMIENTO DE LA JUGADORA (4/11, Pablo tras jugar el Bosque 02). Sin ventana, sobre la escena real del Bosque 02 (el Jugador3D real, su Pj3D real, el terreno horneado), a 30 fps fijos:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_movimiento_jugadora.gd
## El `_process` del jugador se llama a mano (un fotograma = DT) con el Input real (mover_* y «correr»), así que los fotogramas contados son exactos.
##   1 RAMPA   andar → correr tarda T_ANDAR_A_CORRER (0,3 s) y correr → andar T_CORRER_A_ANDAR (0,15 s), sin saltos; el clip (walk/run) y `corre_real` siguen la velocidad real, no la tecla
##   2 GIRO    el cuerpo gira a ≤ VEL_GIRO_ANDAR °/s: 45° y 90° se notan (no son un salto) y acaban; 180° es un giro continuo por UN solo lado; el giro mantiene el lado a ~180°
##   3 CABEZA  la cabeza se adelanta al cuerpo (hacia donde va a girar, con tope ±CABEZA_MAX), el HUESO de la cabeza gira de verdad en ese sentido y vuelve al centro
##   4 ROCAS   un tronco bajo (troncos_apilados, 12,33) no bloquea y se sube encima; el tronco del puzle (22,24) sigue bloqueando
##   5 APUNTAR la dirección lógica (`_mirada`, la del lanzamiento) es la del rumbo al instante; la voltereta sigue girando de golpe

const RUTA_B02: String = "res://escenas/PruebaBosque02.tscn"
const DT: float = 1.0 / 30.0

var _paradas: int = 0


func _escenario() -> void:
	Misiones.nuevo()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_B02, true)
	if maqueta == null or jugador == null:
		return
	jugador.set_process(false)
	await _rampa()
	await _giros()
	await _cabeza()
	await _rocas()
	await _apuntar()
	_teclas(false, false, false, false, false)


# ---------------------------------------------------------------------------------------------------------------------
#  Utilidades
# ---------------------------------------------------------------------------------------------------------------------

func _teclas(adel: bool, atras: bool, izq: bool, der: bool, corre: bool) -> void:
	for par in [["mover_adelante", adel], ["mover_atras", atras], ["mover_izquierda", izq], ["mover_derecha", der], ["correr", corre]]:
		if bool(par[1]):
			Input.action_press(String(par[0]))
		else:
			Input.action_release(String(par[0]))


## Un fotograma de juego: el _process del jugador con DT y luego el fotograma del motor (Pj3D, esqueleto…).
func _fotograma() -> void:
	jugador._process(DT)
	await process_frame


func _pj() -> Pj3D:
	return jugador.get("pj") as Pj3D


## Pone a la jugadora quieta en una casilla abierta de la pradera (16..27, 12..21), mirando al norte y con todo a cero.
func _a_la_pradera() -> void:
	_teclas(false, false, false, false, false)
	colocar_jugador(Vector2i(21, 16))
	jugador.vel_suelo = Vector3.ZERO
	jugador.vel_marcha = -1.0
	jugador.corre_real = false
	jugador.corriendo = false
	jugador._vel_hielo = Vector3.ZERO
	jugador.en_suelo = true
	jugador.vy = 0.0
	jugador._t_roll = 0.0
	await avanzar(2)


func _yaw_pj() -> float:
	return _pj().rotation.y


func _objetivo_yaw() -> float:
	var m: Vector3 = jugador._mirada
	return atan2(m.x, m.z)


# ---------------------------------------------------------------------------------------------------------------------
#  1 · Rampa
# ---------------------------------------------------------------------------------------------------------------------

func _rampa() -> void:
	await _a_la_pradera()
	var va: float = float(jugador._vel_andar)
	var vc: float = float(jugador._vel_correr)
	# andar 1 s hasta estabilizar
	_teclas(true, false, false, false, false)
	var prev: Vector3 = jugador.position
	var v_andar: float = 0.0
	for i in range(30):
		await _fotograma()
		v_andar = Vector2(jugador.position.x - prev.x, jugador.position.z - prev.z).length() / DT
		prev = jugador.position
		if i % 10 == 9:
			colocar_jugador(Vector2i(21, 16))
			prev = jugador.position
	_ok("1 andando, la velocidad real es la de andar (%.2f u/s)" % v_andar, absf(v_andar - va) < 0.1, "esperado %.2f" % va)
	_ok("1 andando, el clip es walk y corre_real es false", _pj().animacion_actual == "walk" and not jugador.corre_real, _pj().animacion_actual)
	# pulsa correr: velocidad por fotograma
	_teclas(true, false, false, false, true)
	var vel: Array = []
	var distancia: float = 0.0
	var f_entra: int = -1
	var clip_run: int = -1
	for i in range(20):
		prev = jugador.position
		await _fotograma()
		var d: float = Vector2(jugador.position.x - prev.x, jugador.position.z - prev.z).length()
		distancia += d
		vel.append(d / DT)
		if f_entra < 0 and jugador.corre_real:
			f_entra = i + 1
		if clip_run < 0 and _pj().animacion_actual == "run":
			clip_run = i + 1
		if i == 9:
			colocar_jugador(Vector2i(21, 16))
	var salto_max: float = 0.0
	var monotona: bool = true
	for i in range(1, vel.size()):
		salto_max = maxf(salto_max, float(vel[i]) - float(vel[i - 1]))
		if float(vel[i]) < float(vel[i - 1]) - 0.02 and float(vel[i - 1]) < vc - 0.05:
			monotona = false
	var f95: int = -1
	for i in range(vel.size()):
		if float(vel[i]) >= va + 0.95 * (vc - va):
			f95 = i + 1
			break
	_ok("1 correr: la 1.ª velocidad tras pulsar no salta a tope (%.2f u/s; antes ~2,0 con la aceleración del suelo)" % float(vel[0]), float(vel[0]) < va + 0.3, "andar %.2f" % va)
	_ok("1 correr: la rampa sube sin saltos (máx +%.2f u/s por fotograma) y sin bajar" % salto_max, salto_max < 0.2 and monotona)
	_ok("1 correr: llega al 95 %% de la velocidad de correr en %d fotogramas (%.2f s; meta %.2f s)" % [f95, float(f95) * DT, Jugador3D.T_ANDAR_A_CORRER], f95 >= 8 and f95 <= 12)
	_ok("1 correr: acaba en %.2f u/s (correr = %.2f)" % [float(vel[19]), vc], absf(float(vel[19]) - vc) < 0.05)
	_ok("1 corre_real pasa a true a los %d fotogramas (no con la tecla: ≥ 4) y el clip run a los %d" % [f_entra, clip_run], f_entra >= 4 and f_entra <= 9 and clip_run >= 4 and clip_run <= 10, "")
	# suelta correr (sigue andando)
	colocar_jugador(Vector2i(21, 16))
	_teclas(true, false, false, false, false)
	var vel2: Array = []
	var f_sale: int = -1
	var clip_walk: int = -1
	for i in range(14):
		prev = jugador.position
		await _fotograma()
		vel2.append(Vector2(jugador.position.x - prev.x, jugador.position.z - prev.z).length() / DT)
		if f_sale < 0 and not jugador.corre_real:
			f_sale = i + 1
		if clip_walk < 0 and _pj().animacion_actual == "walk":
			clip_walk = i + 1
	var f_andar: int = -1
	for i in range(vel2.size()):
		if float(vel2[i]) <= va + 0.05:
			f_andar = i + 1
			break
	_ok("1 soltar correr: vuelve a la velocidad de andar en %d fotogramas (%.2f s; meta %.2f s)" % [f_andar, float(f_andar) * DT, Jugador3D.T_CORRER_A_ANDAR], f_andar >= 3 and f_andar <= 7)
	_ok("1 soltar correr: corre_real pasa a false a los %d fotogramas y el clip walk a los %d (no a la vez que la tecla: ≥ 2)" % [f_sale, clip_walk], f_sale >= 2 and f_sale <= 6 and clip_walk >= 2 and clip_walk <= 7)
	# los pasos siguen a la velocidad real: distancia entre pasos andar/correr según corre_real
	jugador._dist_paso = 0.0
	_ok("1 la distancia entre pasos sale de corre_real (andar %.2f · correr %.2f)" % [Jugador3D.DIST_PASO_ANDAR, Jugador3D.DIST_PASO_CORRER], Jugador3D.DIST_PASO_CORRER > Jugador3D.DIST_PASO_ANDAR)
	# parada: quieta, la meta es la de andar (el siguiente arranque corriendo empieza gradual)
	_teclas(false, false, false, false, true)
	for i in range(12):
		await _fotograma()
	_ok("1 quieta con «correr» pulsada, la rampa baja a andar (%.2f)" % float(jugador.vel_marcha), absf(float(jugador.vel_marcha) - va) < 0.01)
	_teclas(false, false, false, false, false)


# ---------------------------------------------------------------------------------------------------------------------
#  2 · Giro del cuerpo
# ---------------------------------------------------------------------------------------------------------------------

## Deja a la jugadora andando en una dirección y estable; devuelve el yaw del cuerpo.
func _estabilizar(adel: bool, atras: bool, izq: bool, der: bool) -> void:
	_teclas(adel, atras, izq, der, false)
	for i in range(24):
		await _fotograma()
		if i % 6 == 5:
			colocar_jugador(Vector2i(21, 16))


## Cambia las teclas y registra, fotograma a fotograma, lo que falta por girar (°, con signo) y el giro por fotograma.
## Devuelve {"resto": [...], "paso": [...], "cabeza": [...], "inicial": °}.
func _girar_a(adel: bool, atras: bool, izq: bool, der: bool, fotogramas: int) -> Dictionary:
	var yaw0: float = _yaw_pj()
	_teclas(adel, atras, izq, der, false)
	var resto: Array = []
	var paso: Array = []
	var cabeza: Array = []
	var prev: float = yaw0
	var inicial: float = 0.0
	for i in range(fotogramas):
		await _fotograma()
		var o: float = _objetivo_yaw()
		if i == 0:
			inicial = rad_to_deg(angle_difference(yaw0, o))
		resto.append(rad_to_deg(angle_difference(_yaw_pj(), o)))
		paso.append(rad_to_deg(angle_difference(prev, _yaw_pj())))
		cabeza.append(_pj().cabeza_giro_actual())
		prev = _yaw_pj()
		if i % 8 == 7:
			colocar_jugador(Vector2i(21, 16))
	return {"resto": resto, "paso": paso, "cabeza": cabeza, "inicial": inicial}


func _primero_bajo(lista: Array, umbral: float) -> int:
	for i in range(lista.size()):
		if absf(float(lista[i])) < umbral:
			return i + 1
	return -1


func _giros() -> void:
	await _a_la_pradera()
	var tope: float = Jugador3D.VEL_GIRO_ANDAR * DT * 1.02
	# --- 90° ---
	await _estabilizar(true, false, false, false)
	var g90: Dictionary = await _girar_a(false, false, false, true, 20)
	var r90: Array = g90["resto"]
	var p90: Array = g90["paso"]
	var ini90: float = float(g90["inicial"])
	var max_paso: float = 0.0
	for p in p90:
		max_paso = maxf(max_paso, absf(float(p)))
	_ok("2 90°: el cambio de rumbo medido es de %.0f°" % ini90, absf(absf(ini90) - 90.0) < 3.0)
	_ok("2 90°: el primer fotograma gira %.1f° (se nota: ≥ 5°) pero no salta (resto %.1f°)" % [float(p90[0]), float(r90[0])], absf(float(p90[0])) >= 5.0 and absf(float(r90[0])) > 50.0)
	_ok("2 90°: ningún fotograma pasa de %.1f° (%.0f °/s; el más rápido gira %.1f°)" % [tope, Jugador3D.VEL_GIRO_ANDAR, max_paso], max_paso <= tope)
	var f90: int = _primero_bajo(r90, 5.0)
	_ok("2 90°: acaba (< 5°) en %d fotogramas (%.2f s)" % [f90, float(f90) * DT], f90 >= 3 and f90 <= 14)
	# --- 45° (adelante+derecha desde adelante-solo → vuelvo antes a adelante) ---
	await _estabilizar(true, false, false, false)
	var g45: Dictionary = await _girar_a(true, false, false, true, 20)
	var r45: Array = g45["resto"]
	var f45: int = _primero_bajo(r45, 3.0)
	_ok("2 45°: el cambio de rumbo medido es de %.0f°" % float(g45["inicial"]), absf(absf(float(g45["inicial"])) - 45.0) < 3.0)
	_ok("2 45°: se nota (no es un salto: en el 1.er fotograma quedan %.1f° de 45) y acaba en %d fotogramas" % [absf(float(r45[0])), f45], absf(float(r45[0])) > 15.0 and absf(float(r45[0])) < 42.0 and f45 >= 3 and f45 <= 14)
	# --- 180° ---
	await _estabilizar(true, false, false, false)
	var g180: Dictionary = await _girar_a(false, true, false, false, 24)
	var p180: Array = g180["paso"]
	var lado: float = signf(float(p180[0]))
	var mismo_lado: bool = true
	var max180: float = 0.0
	for p in p180:
		if absf(float(p)) > 0.5 and signf(float(p)) != lado:
			mismo_lado = false
		max180 = maxf(max180, absf(float(p)))
	var f180: int = _primero_bajo(g180["resto"], 5.0)
	_ok("2 180° (%.0f°): gira siempre por el mismo lado, sin vaivén" % float(g180["inicial"]), mismo_lado and absf(absf(float(g180["inicial"])) - 180.0) < 3.0)
	_ok("2 180°: es un giro (%d fotogramas = %.2f s; no un teletransporte: ≥ 6) y acaba en < 0,7 s; máx %.1f°/fotograma" % [f180, float(f180) * DT, max180], f180 >= 6 and f180 <= 21 and max180 <= tope)
	# --- a ~180° no cambia de lado: gira en la función sola ---
	var solo := Pj3D.new()
	root.add_child(solo)
	solo._yaw = 0.0
	for i in range(3):
		solo.girar_hacia(Vector3(sin(deg_to_rad(170.0)), 0.0, cos(deg_to_rad(170.0))), DT, Jugador3D.VEL_GIRO_ANDAR)    # +170°: gira hacia +
	var yaw_a: float = rad_to_deg(solo._yaw)
	solo.girar_hacia(Vector3(sin(deg_to_rad(yaw_a - 170.0)), 0.0, cos(deg_to_rad(yaw_a - 170.0))), DT, Jugador3D.VEL_GIRO_ANDAR)       # ahora el destino queda a −170° del cuerpo
	var yaw_b: float = rad_to_deg(solo._yaw)
	_ok("2 casi de espaldas (−170°) con un giro en curso hacia + : sigue hacia + (%.1f° → %.1f°) en vez de volver de golpe" % [yaw_a, yaw_b], yaw_b > yaw_a)
	solo.queue_free()
	_teclas(false, false, false, false, false)


# ---------------------------------------------------------------------------------------------------------------------
#  3 · Cabeza
# ---------------------------------------------------------------------------------------------------------------------

## Guiñada del hueso Head en el mundo respecto a la del cuerpo (°). `_eje_cara` es el eje local del hueso que apunta a la cara con la jugadora quieta (se elige una vez, en reposo).
var _eje_cara: Vector3 = Vector3.BACK


var _pose_cabeza: Transform3D = Transform3D.IDENTITY     ## pose global FINAL (con los modificadores) del hueso de la cabeza: solo existe dentro de skeleton_updated; get_bone_global_pose fuera da la del clip a pelo


func _al_actualizar() -> void:
	var sk: Skeleton3D = _pj()._esqueleto()
	_pose_cabeza = sk.get_bone_global_pose(_hueso_cabeza())


func _hueso_cabeza() -> int:
	var sk: Skeleton3D = _pj()._esqueleto()
	for k in range(sk.get_bone_count()):
		if sk.get_bone_name(k).ends_with("Head"):
			return k
	return -1


func _elegir_eje_cara() -> void:
	var pj: Pj3D = _pj()
	var sk: Skeleton3D = pj._esqueleto()
	if not sk.skeleton_updated.is_connected(_al_actualizar):
		sk.skeleton_updated.connect(_al_actualizar)
	await process_frame
	await process_frame
	var b: Basis = (sk.global_transform * _pose_cabeza).basis.orthonormalized()
	var adelante: Vector3 = Basis(Vector3.UP, pj.rotation.y) * Vector3.BACK
	var d_mejor: float = -2.0
	for eje in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var d: float = (b * eje).dot(adelante)
		if d > d_mejor:
			d_mejor = d
			_eje_cara = eje


func _cabeza_mundo() -> float:
	var pj: Pj3D = _pj()
	var sk: Skeleton3D = pj._esqueleto()
	var b: Basis = (sk.global_transform * _pose_cabeza).basis.orthonormalized()
	var w: Vector3 = b * _eje_cara
	return rad_to_deg(angle_difference(pj.rotation.y, atan2(w.x, w.z)))

func _cabeza() -> void:
	await _a_la_pradera()
	var pj: Pj3D = _pj()
	await _estabilizar(true, false, false, false)
	await _elegir_eje_cara()
	var reposo: float = _cabeza_mundo()
	# gira 90° y mira cabeza lógica y hueso
	_teclas(false, false, false, true, false)
	var maxima: float = 0.0
	var f_adelanto: int = -1
	var coincide: bool = true
	var lista_c: Array = []
	var lista_h: Array = []
	for i in range(14):
		await _fotograma()
		var c: float = pj.cabeza_giro_actual()
		var h: float = _cabeza_mundo() - reposo
		h = rad_to_deg(angle_difference(0.0, deg_to_rad(h)))
		maxima = maxf(maxima, absf(c))
		lista_c.append(c)
		lista_h.append(h)
		var resto: float = absf(rad_to_deg(angle_difference(pj.rotation.y, _objetivo_yaw())))
		if f_adelanto < 0 and absf(c) >= 25.0:
			f_adelanto = i + 1
		if i > 1 and i < 6 and absf(c) > 20.0 and (signf(h) != signf(c) or absf(h - c) > 12.0):
			coincide = false
		if i % 6 == 5:
			colocar_jugador(Vector2i(21, 16))
	var ci_resto0: float = float(lista_c[1])
	_ok("3 la cabeza se adelanta: ≥ 25° al fotograma %d, cuando el cuerpo aún no ha llegado (máx %.1f° ≤ %.0f°)" % [f_adelanto, maxima, Pj3D.CABEZA_MAX], f_adelanto > 0 and f_adelanto <= 4 and maxima <= Pj3D.CABEZA_MAX + 0.01)
	_ok("3 el HUESO de la cabeza gira de verdad y en el mismo sentido (lógica %s / hueso %s)" % [_fmt(lista_c.slice(1, 6)), _fmt(lista_h.slice(1, 6))], coincide)
	# vuelta al centro: sigue andando recto hacia la derecha
	for i in range(18):
		await _fotograma()
		if i % 6 == 5:
			colocar_jugador(Vector2i(21, 16))
	_ok("3 con el cuerpo ya orientado, la cabeza vuelve al centro (%.2f°)" % pj.cabeza_giro_actual(), absf(pj.cabeza_giro_actual()) < 1.0)
	# 180°: tope
	var g: Dictionary = await _girar_a(false, false, true, false, 12)
	var m180: float = 0.0
	for c in g["cabeza"]:
		m180 = maxf(m180, absf(float(c)))
	_ok("3 en un giro de 180° la cabeza llega al tope y no pasa de él (%.1f° de ±%.0f°)" % [m180, Pj3D.CABEZA_MAX], m180 > Pj3D.CABEZA_MAX - 8.0 and m180 <= Pj3D.CABEZA_MAX + 0.01)
	# quieta: vuelve al centro y deja de girar
	_teclas(false, false, false, false, false)
	for i in range(30):
		await _fotograma()
	_ok("3 quieta, la cabeza está en el centro (%.2f°) y el hueso a %.1f° de su reposo" % [pj.cabeza_giro_actual(), absf(_cabeza_mundo() - reposo)], absf(pj.cabeza_giro_actual()) < 0.1)


func _fmt(l: Array) -> String:
	var s: PackedStringArray = PackedStringArray()
	for v in l:
		s.append("%.0f" % float(v))
	return ",".join(s)


# ---------------------------------------------------------------------------------------------------------------------
#  4 · Rocas bajas frente al tronco del puzle
# ---------------------------------------------------------------------------------------------------------------------

## Camina en +X desde `desde` hasta `hasta` (u) por la línea z = `z` a pasos de 5 cm con _mover_con_choque + _vertical. Devuelve {x_final, y_max, y_base}.
func _cruzar_x(desde: float, hasta: float, z: float, celda: Vector2i) -> Dictionary:
	var y_base: float = Terreno3D.y_pies(celda)
	jugador.position = Vector3(desde, y_base, z)
	_pj().position = jugador.position
	jugador._ultima = jugador.position
	jugador.en_suelo = true
	jugador.vy = 0.0
	var y_max: float = y_base
	var x: float = desde
	var bloqueada_en: float = INF
	while x < hasta:
		var antes: float = jugador.position.x
		jugador._mover_con_choque(Vector3(0.05, 0.0, 0.0))
		jugador._vertical(DT, false)
		jugador._ultima = jugador.position
		_pj().position = jugador.position
		y_max = maxf(y_max, jugador.position.y)
		if jugador.position.x - antes < 0.001:
			bloqueada_en = jugador.position.x
			break
		x = jugador.position.x
	return {"x_final": jugador.position.x, "y_max": y_max, "y_base": y_base, "bloqueada_en": bloqueada_en}


func _rocas() -> void:
	# --- el tronco bajo (troncos_apilados, 0,45 u) en (12,33): no bloquea la casilla, y se sube encima ---
	var c_bajo := Vector2i(12, 33)
	var lista: Variant = Terreno3D.realces.get(c_bajo)
	_ok("4 hay realces (piedras y troncos bajos) en el terreno: %d casillas" % Terreno3D.realces.size(), Terreno3D.realces.size() > 0)
	_ok("4 la casilla del tronco bajo (12,33) no está bloqueada", not Terreno3D.bloqueada(c_bajo))
	_ok("4 …y no es parcial (no queda ningún cuerpo ahí)", not Terreno3D.es_parcial(c_bajo))
	if lista != null:
		var reg: Vector4 = (lista as Array)[0]
		var r: Dictionary = await _cruzar_x(reg.x - 1.4, reg.x + 1.4, reg.y, c_bajo)
		_ok("4 el tronco bajo: se cruza entero (x final %.2f de %.2f)" % [float(r["x_final"]), reg.x + 1.4], float(r["x_final"]) >= reg.x + 1.35)
		_ok("4 el tronco bajo: sube encima (+%.2f u sobre el suelo; realce máx %.2f)" % [float(r["y_max"]) - float(r["y_base"]), reg.w], float(r["y_max"]) - float(r["y_base"]) >= 0.1 and float(r["y_max"]) - float(r["y_base"]) <= 0.45)
		await avanzar(1)
		_ok("4 y al bajar vuelve al suelo (y %.3f / suelo %.3f)" % [jugador.position.y, float(r["y_base"])], absf(jugador.position.y - float(r["y_base"])) < 0.01)
	else:
		_ok("4 hay un realce en la casilla del tronco bajo (12,33)", false)
	# --- las piedras (decorado que ya no bloquea): se sube también ---
	var c_pie := Vector2i(31, 7)
	var l2: Variant = Terreno3D.realces.get(c_pie)
	if l2 != null:
		var reg2: Vector4 = (l2 as Array)[0]
		var r2: Dictionary = await _cruzar_x(reg2.x - 1.0, reg2.x + 1.0, reg2.y, c_pie)
		_ok("4 las piedras (31,7): se cruzan (x final %.2f) y se sube encima (+%.2f u)" % [float(r2["x_final"]), float(r2["y_max"]) - float(r2["y_base"])], float(r2["x_final"]) >= reg2.x + 0.95 and float(r2["y_max"]) - float(r2["y_base"]) >= 0.08)
	# --- el tronco del puzle (22,24) sigue cerrando el pasillo ---
	var c_tronco := Vector2i(22, 24)
	_ok("4 el tronco del puzle (22,24) sigue bloqueando su casilla", Terreno3D.bloqueada(c_tronco))
	var centro: Vector3 = Terreno3D.centro_de(c_tronco, 0.0)
	var r3: Dictionary = await _cruzar_x(centro.x - 3.0, centro.x + 2.0, centro.z, Vector2i(21, 24))
	_ok("4 el tronco del puzle: no se atraviesa (se para en x %.2f, antes del centro %.2f; hizo falta %.2f)" % [float(r3["x_final"]), centro.x, float(r3["bloqueada_en"])], float(r3["bloqueada_en"]) < centro.x and float(r3["x_final"]) < centro.x)
	_ok("4 …ni se sube encima (y máx +%.2f)" % (float(r3["y_max"]) - float(r3["y_base"])), float(r3["y_max"]) - float(r3["y_base"]) < 0.05)
	# el umbral
	_ok("4 umbral ColisionPieza.ALTO_MIN_SOLIDO = %.2f u: troncos_apilados (%.2f) sin cuerpo, tocón (%.2f) con cuerpo" % [ColisionPieza.ALTO_MIN_SOLIDO, float(Pieza3D.MEDIDA["troncos_apilados"]), float(Pieza3D.MEDIDA["tocon"])],
		Pieza3D.cascos_colision("troncos_apilados").is_empty() and not Pieza3D.cascos_colision("tocon").is_empty())


# ---------------------------------------------------------------------------------------------------------------------
#  5 · Apuntar y voltereta
# ---------------------------------------------------------------------------------------------------------------------

func _apuntar() -> void:
	await _a_la_pradera()
	var pj: Pj3D = _pj()
	await _estabilizar(true, false, false, false)
	_teclas(false, false, false, true, false)
	await _fotograma()
	var m: Vector3 = jugador._mirada
	var o: float = atan2(m.x, m.z)
	var resto: float = absf(rad_to_deg(angle_difference(pj.rotation.y, o)))
	_ok("5 al cambiar de rumbo la dirección lógica (`_mirada`, la del lanzamiento) ya es la nueva mientras el modelo aún gira (le quedan %.0f°)" % resto, resto > 30.0 and absf(m.length() - 1.0) < 0.01)
	# mirar_hacia (apuntar con el ratón) sigue siendo el giro de siempre y deja la dirección lógica puesta
	_teclas(false, false, false, false, false)
	jugador.mirar_hacia(Vector3(-1, 0, 0))
	_ok("5 mirar_hacia fija la dirección (%s)" % str(jugador.mirada()), jugador.mirada().is_equal_approx(Vector3(-1, 0, 0)))
	# voltereta: gira de golpe
	jugador._roll_cd = 0.0
	jugador._iniciar_voltereta(Vector3(0, 0, 1))
	await _fotograma()
	var yaw_r: float = rad_to_deg(angle_difference(pj.rotation.y, atan2(0.0, 1.0)))
	_ok("5 la voltereta orienta el cuerpo de golpe hacia donde rueda (a %.1f° del rumbo)" % absf(yaw_r), absf(yaw_r) < 1.0)
	_teclas(false, false, false, false, false)

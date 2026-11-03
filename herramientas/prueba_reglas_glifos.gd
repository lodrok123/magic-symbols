extends SceneTree
## LAS CINCO REGLAS GENERALES DE COMBINAR GLIFOS (3/11/2026, decisión de Pablo «R1…R5»), medidas sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_reglas_glifos.gd
## No hay recetas escritas a mano en la lógica: salen de propiedades del Hechizo (solidez, velocidad, copias, retorna, crece, semiejes). Aquí cada regla se mide con fuego Y con agua (y con tierra o rayo, para ver que es general):
##   R1 · ᛇ sobre algo con FORMA = la forma viaja. ᚲ ᛜ ᛁ ᛁ ᛇ: NO sale una bola; el volumen se desplaza, su SolidezV2 está en las casillas nuevas y no en las viejas, y lo que encuentra se golpea y se empuja.
##   R2 · ᛃ sobre lo que viaja = el camino incluye la VUELTA. ᚲ ᛜ ᛁ ᛁ ᛇ ᛃ: el volumen vuelve al lanzador (y vuelve a golpear lo que cruza).
##   R3 · ᛃ SIN flecha y con ᚠ = las copias ORBITAN. ᚲ ᚠ ᚠ ᛃ: tantos orbes como copias, a la distancia del radio, con el ángulo avanzando; las ᛁ abren el radio; con ᚨ un orbe sale disparado contra un enemigo.
##   R4 · ᛏ + ᚷ = crece de ABAJO ARRIBA y ELEVA lo que haya dentro. ᛚ ᛏ ᛏ ᛏ ᚷ: la altura sube con el tiempo y quien está dentro sube con ella.
##   R5 · ᚷ golpea AL CRECER (onda expansiva por casillas nuevas) y el agua que crece ESTALLA en área. ᛚ ᚷ ᚷ ⧖.
## Y los contraejemplos: ᚲ ᛇ sigue siendo la bola de siempre; ᛜ ᛁ sigue siendo un muro quieto; ᛃ sin copias sigue dando eco; ᛚ ᛏ ᛏ ᛏ (sin ᚷ) no alza nada.

class MundoFalso extends Node3D:
	var _lado: int = 24
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

class JugadorFalso extends Jugador3D:
	pass

## Un enemigo de mentira: del grupo `combate3d`, anota lo que le pasa (golpes con su hora, empujes, a qué altura lo alzan).
class Enemigo extends Node3D:
	var muerto: bool = false
	var golpes: Array = []
	var empujes: int = 0
	var ultimo_empuje: Vector3 = Vector3.ZERO
	var alto_pedido: float = 0.0
	var periodicos: int = 0
	func _init() -> void:
		add_to_group("combate3d")
	func on_spell_hit(_rune: RuneData, _dir: Vector3 = Vector3.ZERO, _hechizo: Hechizo = null) -> void:
		golpes.append(Time.get_ticks_msec())
	func push(d: Vector3, _f: float) -> void:
		empujes += 1
		ultimo_empuje = d
	func elevar(alto: float, _dt: float = 0.0) -> void:
		alto_pedido = alto
	func receive_damage(_d: Variant) -> void:
		periodicos += 1

const LADO: int = 24
const ORIGEN_C: Vector2i = Vector2i(4, 10)
const CASILLA: float = 2.3
const DT: float = 1.0 / 60.0
const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "rayo": "lightning"}

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: JugadorFalso = null
var _runas: Dictionary = {}
var _t0: int = 0
var _linaje: Object = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	for e in ELEMENTOS:
		_runas[e] = load("res://nucleo/%s_rune.tres" % ELEMENTOS[e]) as RuneData
	await _propiedades()
	await _r1_r2()
	await _r1_sola_y_contraejemplos()
	await _r3()
	await _r4()
	await _r5_por_casillas()
	await _r5_estallido()
	await _altura_sin_tope()
	await _linea_mas_larga()
	await _previsiones()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# =====================================================================================================
#  Mundo y ayudas
# =====================================================================================================

func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = JugadorFalso.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(ORIGEN_C, Terreno3D.y_pies(ORIGEN_C))          # quien lanza está en la casilla de origen
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	Lanzador3D.montar_agua_sim()


func _origen() -> Vector3:
	return Lanzador3D.centro_de(ORIGEN_C, Terreno3D.y_pies(ORIGEN_C) + 0.8)


func _hz(el: String, glifos: Dictionary, cambios: Dictionary = {}) -> Hechizo:
	var h: Hechizo = Hechizo.construir(_runas[el], glifos, 1.0)
	if not cambios.is_empty():
		h.con(cambios)
	return h


## Un enemigo de mentira en la casilla `c` (dx, dz casillas desde el origen), con un desvío en u.
func _enemigo(dx: float, dz: float = 0.0) -> Enemigo:
	var e := Enemigo.new()
	_m.add_child(e)
	var o: Vector3 = Lanzador3D.centro_de(ORIGEN_C, Terreno3D.y_pies(ORIGEN_C))
	e.position = o + Vector3(dx * CASILLA, 0.0, dz * CASILLA)
	return e


func _lanzar(h: Hechizo) -> HechizoVivo:
	_t0 = Time.get_ticks_msec()                       # antes de crear: la primera tanda (t = 0) ya golpea dentro de `crear`
	var hv: HechizoVivo = HechizoVivo.crear(h, _origen(), Vector3.RIGHT, _l, null, {}, true)
	_linaje = hv.linaje
	return hv


## Espera (en tiempo real, los temporizadores de la lógica lo son) hasta `t` s desde el lanzamiento.
func _hasta(t: float) -> void:
	var falta: float = t - float(Time.get_ticks_msec() - _t0) / 1000.0
	if falta > 0.0:
		await create_timer(falta).timeout


## Las casillas con SolidezV2 de este lanzamiento ahora mismo.
func _solidas(_hv: Variant = null) -> Dictionary:
	var r: Dictionary = {}
	for s in _l._solideces_v2:
		if is_instance_valid(s) and not (s as Node).is_queued_for_deletion() and (s as Lanzador3D.SolidezV2).linaje == _linaje:
			for c in (s as Lanzador3D.SolidezV2).celdas:
				r[c] = true
	return r


func _bloquea(c: Vector2i) -> bool:
	return _l._barrera_en(Lanzador3D.centro_de(c, Terreno3D.y_pies(c) + 0.3), 0)


func _pasos(hv: HechizoVivo, n: int) -> void:
	for _i in range(n):
		hv.avanzar_volumen(DT)


func _cerca(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# =====================================================================================================
#  Las propiedades que deciden cada regla (sin nombrar glifos ni elementos en la lógica)
# =====================================================================================================

func _propiedades() -> void:
	for el in ELEMENTOS:
		var muro_va: Hechizo = _hz(el, {"barrera": 1, "linea_x": 2, "flecha": 1})
		_ok("%s · ᛜ ᛁ ᛁ ᛇ: volumen_viaja (R1), NO proyectil (alcance %.1f m, solidez %.2f, velocidad %.2f)" % [el, muro_va.distancia_max, muro_va.solidez, muro_va.velocidad], muro_va.volumen_viaja and not muro_va.proyectil and muro_va.velocidad > 0.0)
		var bola: Hechizo = _hz(el, {"flecha": 1})
		_ok("%s · ᛇ solo: sigue siendo un proyectil (bola), no un volumen que viaja" % el, bola.proyectil and not bola.volumen_viaja and is_equal_approx(bola.escala_vuelo, Hechizo.ESCALA_PROYECTIL))
		_ok("%s · ᛜ ᛁ ᛁ ᛇ: el muro que viaja se ve ENTERO (escala en vuelo 1), no la mitad de la bola" % el, is_equal_approx(muro_va.escala_vuelo, 1.0))
		var quieto: Hechizo = _hz(el, {"barrera": 1, "linea_x": 2})
		_ok("%s · ᛜ ᛁ ᛁ sin flecha: ni viaja ni es proyectil" % el, not quieto.volumen_viaja and not quieto.proyectil and not quieto.viaja)
		var orbita: Hechizo = _hz(el, {"repeticion": 2, "retorno": 1})
		_ok("%s · ᚠ ᚠ ᛃ: orbita con %d copias (R3); ᚠ ᚠ sin ᛃ no; ᛃ solo no" % [el, orbita.copias], orbita.orbita and orbita.copias == 3 and not _hz(el, {"repeticion": 2}).orbita and not _hz(el, {"retorno": 1}).orbita)
		_ok("%s · ᛃ con flecha no orbita aunque lleve copias" % el, not _hz(el, {"repeticion": 2, "retorno": 1, "flecha": 1}).orbita)
		var pilar: Hechizo = _hz(el, {"altura": 3, "pulso": 1})
		_ok("%s · ᛏ ᛏ ᛏ ᚷ: columna (R4); sin ᚷ no; ᚷ solo (esfera) no" % el, pilar.columna and not _hz(el, {"altura": 3}).columna and not _hz(el, {"pulso": 1}).columna)
	var explosion: Hechizo = _hz("agua", {"pulso": 2, "retardo": 1})
	_ok("agua · ᚷ ᚷ ⧖: estalla (R5) con radio %.2f casillas (tamaño final %.2f + margen)" % [explosion.radio_estallido, maxf(explosion.semieje_x, explosion.semieje_z)], explosion.estalla and explosion.radio_estallido > maxf(explosion.semieje_x, explosion.semieje_z))
	_ok("agua sin ᚷ no estalla; fuego con ᚷ no estalla (no es líquido); agua con ᚷ y ᛏ ᛏ ᛏ (pilar) no estalla", not _hz("agua", {"retardo": 1}).estalla and not _hz("fuego", {"pulso": 2, "retardo": 1}).estalla and not _hz("agua", {"altura": 3, "pulso": 1}).estalla)
	# lo que no usa estas combinaciones no cambia: ninguna receta suelta de las de antes cambia de naturaleza
	for combo in [{}, {"flecha": 1}, {"flecha": 2}, {"barrera": 1}, {"linea_x": 2}, {"altura": 2}, {"repeticion": 1}, {"rebote": 1, "flecha": 1}, {"pulso": 1}, {"retorno": 1, "flecha": 1}, {"perforar": 1, "flecha": 1}]:
		var h: Hechizo = _hz("fuego", combo)
		_ok("receta de siempre %s: ni volumen que viaja ni órbita (proyectil = velocidad > 0)" % str(combo), not h.volumen_viaja and not h.orbita and h.proyectil == (h.velocidad > 0.0))


# =====================================================================================================
#  R1 + R2 · ᛜ ᛁ ᛁ ᛇ (+ ᛃ): el muro viaja y vuelve
# =====================================================================================================

func _r1_r2() -> void:
	for el in ELEMENTOS:
		_montar()
		var h: Hechizo = _hz(el, {"barrera": 1, "linea_x": 2, "flecha": 1, "retorno": 1})
		var adelanto: float = Lanzador3D.GeometriaV2.adelanto(h.geo())
		var c_nace: Vector2i = ORIGEN_C + Vector2i(int(roundf(adelanto)), 0)          # donde está el volumen al nacer
		var celdas_ruta: Array = []
		for k in range(0, 3):
			celdas_ruta.append(c_nace + Vector2i(k, 0))
		var e_medio: Enemigo = _enemigo(float(celdas_ruta[1].x - ORIGEN_C.x))           # lo que encuentra: en la casilla del medio de la ida (se cruza al ir y al volver)
		var e_fin: Enemigo = _enemigo(float(celdas_ruta[2].x - ORIGEN_C.x))              # y otro al final de la ruta
		await process_frame                                                              # un fotograma antes de lanzar: el primero tras montar el mundo trae un delta enorme que adelantaría los temporizadores de la lógica
		var prep: HechizoVivo = HechizoVivo.preparar(h, _l)                           # la ruta, ANTES de lanzar (después `trazar` toparía con la solidez del propio muro)
		var evs: Array = prep.eventos_de(h.geo(), Vector2(_origen().x, _origen().z), Vector2.RIGHT)
		prep.free()
		var hv: HechizoVivo = _lanzar(h)
		_ok("%s R1 · ᛜ ᛁ ᛁ ᛇ ᛃ NO es proyectil-bola: no hay proyectil activo y casillas = %d" % [el, hv.casillas], not hv.proyectil and not hv.activo and hv.casillas > 0)
		var ida: Array = evs.filter(func(e: Dictionary) -> bool: return not bool(e.get("vuelta", false)))
		var vuelta: Array = evs.filter(func(e: Dictionary) -> bool: return bool(e.get("vuelta", false)))
		var alcance_m: float = 0.0
		for e in evs:
			alcance_m = maxf(alcance_m, (e["pos"] as Vector2).distance_to(Vector2(_origen().x, _origen().z)) / CASILLA)
		var ult: Dictionary = evs.back()
		_ok("%s R1 · la ruta del volumen llega a %.2f casillas (alcance %.1f) en %d pasos de ida" % [el, alcance_m, h.distancia_max, ida.size()], _cerca(alcance_m, h.distancia_max, 0.05) and ida.size() >= 3)
		_ok("%s R2 · el camino INCLUYE la vuelta (%d pasos) y acaba junto al lanzador (a %.2f casillas)" % [el, vuelta.size(), (ult["pos"] as Vector2).distance_to(Vector2(_origen().x, _origen().z)) / CASILLA],
			vuelta.size() >= 2 and bool(ult.get("vuelta", false)) and (ult["pos"] as Vector2).distance_to(Vector2(_origen().x, _origen().z)) < 0.1 * CASILLA)
		# --- medidas en el tiempo: la solidez acompaña al volumen ---
		await _hasta(0.15)
		var s0: Dictionary = _solidas(hv)
		_ok("%s R1 · al nacer, la solidez está en la casilla del volumen %s (no en la de quien lanza %s ni más lejos)" % [el, str(celdas_ruta[0]), str(ORIGEN_C)], s0.has(celdas_ruta[0]) and not s0.has(ORIGEN_C) and not s0.has(celdas_ruta[1]) and _bloquea(celdas_ruta[0]) and not _bloquea(celdas_ruta[1]), str(s0.keys()))
		await _hasta(0.8)
		var s1: Dictionary = _solidas(hv)
		_ok("%s R1 · tras avanzar una casilla la solidez está en la NUEVA %s y ya no en la vieja %s" % [el, str(celdas_ruta[1]), str(celdas_ruta[0])], s1.has(celdas_ruta[1]) and not s1.has(celdas_ruta[0]) and _bloquea(celdas_ruta[1]) and not _bloquea(celdas_ruta[0]), str(s1.keys()))
		await _hasta(1.35)
		var s2: Dictionary = _solidas(hv)
		_ok("%s R1 · al final de la ida la solidez está en %s y no en las anteriores" % [el, str(celdas_ruta[2])], s2.has(celdas_ruta[2]) and not s2.has(celdas_ruta[1]) and not s2.has(celdas_ruta[0]), str(s2.keys()))
		_ok("%s R1 · lo que encuentra se GOLPEA (medio %d, final %d golpes) y se EMPUJA en la dirección del avance (%d y %d empujes)" % [el, e_medio.golpes.size(), e_fin.golpes.size(), e_medio.empujes, e_fin.empujes],
			e_medio.golpes.size() >= 1 and e_fin.golpes.size() >= 1 and e_medio.empujes >= 1 and e_fin.empujes >= 1 and e_medio.ultimo_empuje.dot(Vector3.RIGHT) > 0.9)
		await _hasta(2.0)
		var s3: Dictionary = _solidas(hv)
		_ok("%s R2 · en la vuelta la solidez retrocede a %s (no se queda en el final %s)" % [el, str(celdas_ruta[1]), str(celdas_ruta[2])], s3.has(celdas_ruta[1]) and not s3.has(celdas_ruta[2]), str(s3.keys()))
		_ok("%s R2 · al volver vuelve a golpear lo que cruza (el del medio: %d golpes; el del final no se cruza de nuevo: %d)" % [el, e_medio.golpes.size(), e_fin.golpes.size()], e_medio.golpes.size() >= 2 and e_fin.golpes.size() == 1)
		await _hasta(2.45)
		var s4: Dictionary = _solidas(hv)
		_ok("%s R2 · de vuelta junto al lanzador la solidez está en %s (donde nació)" % [el, str(celdas_ruta[0])], s4.has(celdas_ruta[0]) and not s4.has(celdas_ruta[1]), str(s4.keys()))
		await _hasta(3.4)
		_ok("%s R2 · y acaba: ya no queda ninguna solidez de este hechizo" % el, _solidas(hv).is_empty())
		await process_frame


## R1 sin ᛃ (no vuelve) con fuego y agua, y los contraejemplos de R1: ᚲ ᛇ sigue siendo la bola, ᛜ ᛁ el muro quieto, ᛃ sin copias el eco.
func _r1_sola_y_contraejemplos() -> void:
	for el in ["fuego", "agua"]:
		_montar()
		var h: Hechizo = _hz(el, {"barrera": 1, "linea_x": 2, "flecha": 1})
		var e_medio: Enemigo = _enemigo(2.0)
		await process_frame
		var hv: HechizoVivo = _lanzar(h)
		var evs: Array = hv.eventos_de(h.geo(), Vector2(_origen().x, _origen().z), Vector2.RIGHT)
		_ok("%s R1 sin ᛃ · la ruta no tiene vuelta (%d pasos) y la copia tiene un solo hechizo vivo" % [el, evs.size()], evs.filter(func(e: Dictionary) -> bool: return bool(e.get("vuelta", false))).is_empty() and (evs[0] as Dictionary).has("ocupa"))
		await _hasta(1.5)
		var plantada: Dictionary = _solidas(hv)
		_ok("%s R1 sin ᛃ · el muro llegó al final, golpeó una vez (%d) y SE PLANTA allí (solidez en %s, como la barrera de ᛜ + ᛇ de siempre)" % [el, e_medio.golpes.size(), str(plantada.keys())], e_medio.golpes.size() == 1 and plantada.size() == 1 and plantada.has(ORIGEN_C + Vector2i(3, 0)))
		await _hasta(5.2)
		_ok("%s R1 sin ᛃ · …y se deshace al acabar su vida (persiste + permanencia, mínimo 2 s)" % el, _solidas(hv).is_empty())
	# --- ᚲ ᛇ: la bola de siempre ---
	for el in ["fuego", "agua"]:
		_montar()
		var hb: Hechizo = _hz(el, {"flecha": 1})
		var vb: HechizoVivo = _lanzar(hb)
		_ok("%s contraejemplo · ᛇ solo sigue siendo la bola de siempre: proyectil activo con velocidad %.2f u/s y sin solidez ni volumen que viaja" % [el, vb.v.length()], vb.proyectil and vb.activo and vb.v.length() > 1.0 and _solidas(vb).is_empty() and not vb.h.volumen_viaja)
		for _i in range(240):
			vb.paso(DT)
		_ok("%s contraejemplo · …y acaba por alcance (motivo %s)" % [el, vb.motivo_fin], not vb.activo and vb.motivo_fin == "alcance")
	# --- ᛜ ᛁ: muro quieto ---
	for el in ["fuego", "agua"]:
		_montar()
		var hq: Hechizo = _hz(el, {"barrera": 1, "linea_x": 2})
		var vq: HechizoVivo = _lanzar(hq)
		var c_muro: Vector2i = ORIGEN_C + Vector2i(1, 0)
		var antes: Dictionary = _solidas(vq)
		await _hasta(0.8)
		var despues: Dictionary = _solidas(vq)
		_ok("%s contraejemplo · ᛜ ᛁ sigue siendo un muro QUIETO: la solidez está en %s y no se mueve (%s → %s)" % [el, str(c_muro), str(antes.keys()), str(despues.keys())], antes.has(c_muro) and despues.has(c_muro) and antes.size() == despues.size() and not hq.volumen_viaja)
	# --- ᛃ sin copias: eco ---
	_montar()
	var he: Hechizo = _hz("agua", {"retorno": 1})
	var ve: HechizoVivo = _lanzar(he)
	await _hasta(0.8)
	_ok("agua contraejemplo · ᛃ sin copias sigue con ECO del impacto (ecos %d, órbita %s)" % [ve.ecos_de_retorno, str(not ve.orbes.is_empty())], ve.ecos_de_retorno == 1 and ve.orbes.is_empty() and not he.orbita)
	_montar()
	var he2: Hechizo = _hz("agua", {"repeticion": 1, "retorno": 1})
	var ve2: HechizoVivo = _lanzar(he2)
	await _hasta(0.8)
	_ok("agua contraejemplo · ᛃ con ᚠ ᚠ... ya no da eco: ahora orbita (ecos %d, orbes %d)" % [ve2.ecos_de_retorno, ve2.orbes.size()], ve2.ecos_de_retorno == 0 and ve2.orbes.size() == 2)


# =====================================================================================================
#  R3 · ᛃ sin flecha y con ᚠ: orbes
# =====================================================================================================

func _r3() -> void:
	for el in ["fuego", "agua", "rayo"]:
		_montar()
		var h: Hechizo = _hz(el, {"repeticion": 2, "retorno": 1})
		var e_borde: Enemigo = null
		var hv: HechizoVivo = _lanzar(h)
		var centro: Vector3 = _jug.position
		_ok("%s R3 · ᚲ ᚠ ᚠ ᛃ: %d orbes = %d copias y no hay proyectil ni eco (ecos %d)" % [el, hv.orbes.size(), h.copias, hv.ecos_de_retorno], hv.orbes.size() == h.copias and not hv.proyectil and hv.ecos_de_retorno == 0 and hv.casillas == h.copias)
		var radio_ok: bool = true
		for o in hv.orbes:
			radio_ok = radio_ok and _cerca(_plano((o as Dictionary)["p"] as Vector3, centro), hv.radio_orbita_u, 0.02)
		_ok("%s R3 · cada orbe está a %.2f u del lanzador (= radio de la órbita %.2f u = %.2f casillas)" % [el, _plano((hv.orbes[0] as Dictionary)["p"] as Vector3, centro), hv.radio_orbita_u, hv.radio_orbita_u / CASILLA], radio_ok)
		var a0: float = float((hv.orbes[0] as Dictionary)["ang"])
		var a1_0: float = float((hv.orbes[1] as Dictionary)["ang"])
		_pasos(hv, 30)                              # medio segundo
		var a1: float = float((hv.orbes[0] as Dictionary)["ang"])
		var esperado: float = TAU / HechizoVivo.ORBITA_VUELTA_S * 0.5
		_ok("%s R3 · el ángulo AVANZA %.3f rad en 0,5 s (esperado %.3f) y los orbes siguen a %.1f° entre sí" % [el, a1 - a0, esperado, rad_to_deg(a1_0 - a0)], _cerca(a1 - a0, esperado, 0.01) and _cerca(a1_0 - a0, TAU / float(h.copias), 0.001))
		var radio_ok2: bool = true
		for o in hv.orbes:
			radio_ok2 = radio_ok2 and _cerca(_plano((o as Dictionary)["p"] as Vector3, centro), hv.radio_orbita_u, 0.02)
		_ok("%s R3 · y siguen a la misma distancia mientras giran" % el, radio_ok2)
		# duración: persiste + permanencia (mínimo ORBITA_VIDA_MIN_S)
		var vida: float = clampf(h.persiste + h.permanencia, HechizoVivo.ORBITA_VIDA_MIN_S, Hechizo.LIM_VIDA_S)
		_pasos(hv, int((vida - 0.7) / DT))
		var vivos_antes: bool = bool((hv.orbes[0] as Dictionary)["activo"])
		_pasos(hv, int(1.0 / DT))
		_ok("%s R3 · duran %.1f s (persiste %.1f + permanencia %.1f): siguen vivos antes y se apagan después" % [el, vida, h.persiste, h.permanencia], vivos_antes and not bool((hv.orbes[0] as Dictionary)["activo"]))
		await process_frame
	# --- las ᛁ abren el radio ---
	_montar()
	var h_base: Hechizo = _hz("fuego", {"repeticion": 2, "retorno": 1})
	var h_ancha: Hechizo = _hz("fuego", {"repeticion": 2, "retorno": 1, "linea_x": 2})
	var h_mas: Hechizo = _hz("fuego", {"repeticion": 2, "retorno": 1, "linea_x": 3, "linea_z": 3})
	var r_base: float = _lanzar(h_base).radio_orbita_u
	_montar()
	var r_ancha: float = _lanzar(h_ancha).radio_orbita_u
	_montar()
	var r_mas: float = _lanzar(h_mas).radio_orbita_u
	_ok("R3 · las ᛁ ABREN el radio de la órbita: %.2f → %.2f → %.2f casillas (semiejes %.2f, %.2f, %.2f)" % [r_base / CASILLA, r_ancha / CASILLA, r_mas / CASILLA, h_base.semieje_x, h_ancha.semieje_x, h_mas.semieje_x], r_base < r_ancha and r_ancha < r_mas)
	# --- golpean lo que tocan en su vuelta ---
	for el in ["fuego", "agua"]:
		_montar()
		var h2: Hechizo = _hz(el, {"repeticion": 2, "retorno": 1})
		var hv2: HechizoVivo = _lanzar(h2)
		var radio_cas: float = hv2.radio_orbita_u / CASILLA
		var e_orbita: Enemigo = _enemigo(0.0, radio_cas)                      # sobre la órbita, a 90° del primer orbe: la alcanzan a los 0,5 s
		var e_lejos: Enemigo = _enemigo(0.0, radio_cas + 3.0)                 # fuera de ella: no lo toca ningún orbe
		_pasos(hv2, int(1.2 / DT))
		_ok("%s R3 · los orbes GOLPEAN lo que tocan en su vuelta (en la órbita: %d golpes, fuera: %d)" % [el, e_orbita.golpes.size(), e_lejos.golpes.size()], e_orbita.golpes.size() >= 1 and e_lejos.golpes.is_empty())
		var n1: int = e_orbita.golpes.size()
		_pasos(hv2, int(2.0 / DT))
		_ok("%s R3 · …y vuelven a golpearlo en la vuelta siguiente (%d → %d golpes)" % [el, n1, e_orbita.golpes.size()], e_orbita.golpes.size() > n1)
	# --- ᚨ: un orbe sale disparado contra un enemigo vivo cercano ---
	for el in ["fuego", "agua"]:
		_montar()
		var h3: Hechizo = _hz(el, {"repeticion": 2, "retorno": 1, "buscar": 1})
		var hv3: HechizoVivo = _lanzar(h3)
		var e_lejano: Enemigo = _enemigo(4.0, 0.0)                            # a 4 casillas: lejos de la órbita (1,2) y dentro del alcance de ᚨ (6)
		var hijos_antes: int = _l.get_children().filter(func(n: Node) -> bool: return n is HechizoVivo).size()
		_pasos(hv3, 3)
		var hijos: Array = _l.get_children().filter(func(n: Node) -> bool: return n is HechizoVivo and n != hv3)
		_ok("%s R3 + ᚨ · un orbe sale disparado (lanzados %d, orbes activos %d de %d, proyectiles nuevos %d)" % [el, hv3.orbes_lanzados, hv3.orbes.filter(func(o: Dictionary) -> bool: return bool(o["activo"])).size(), hv3.orbes.size(), hijos.size() - (hijos_antes - 1)],
			hv3.orbes_lanzados == 1 and hijos.size() == 1 and (hijos[0] as HechizoVivo).h.proyectil and (hijos[0] as HechizoVivo).h.profundidad == 1)
		var proy: HechizoVivo = hijos[0] as HechizoVivo
		for _i in range(240):
			if proy.activo:
				proy.paso(DT)
		_ok("%s R3 + ᚨ · …y alcanza al enemigo (golpes %d, fin «%s»)" % [el, e_lejano.golpes.size(), proy.motivo_fin], e_lejano.golpes.size() >= 1)
		_pasos(hv3, 10)
		_ok("%s R3 + ᚨ · sin segundo ᚨ no sale otro orbe (lanzados %d)" % [el, hv3.orbes_lanzados], hv3.orbes_lanzados == 1)
		await process_frame


# =====================================================================================================
#  R4 · ᛏ + ᚷ: crece de abajo arriba y eleva
# =====================================================================================================

func _r4() -> void:
	for el in ["agua", "fuego", "rayo"]:
		_montar()
		var h: Hechizo = _hz(el, {"altura": 3, "pulso": 1})
		var e_dentro: Enemigo = _enemigo(0.0)                      # en la casilla del pilar
		var e_fuera: Enemigo = _enemigo(0.0, 3.0)
		var hv: HechizoVivo = _lanzar(h)
		var y_final_u: float = h.semieje_y * CASILLA
		_ok("%s R4 · ᛏ ᛏ ᛏ ᚷ: el pilar nace a %.0f %% de su altura (%.2f u de %.2f u) y tarda %.2f s en crecer" % [el, h.escala_nace * 100.0, hv.altura_columna_u(), y_final_u, hv.tiempo_crecimiento],
			not hv.columna.is_empty() and hv.tiempo_crecimiento > 1.0 and hv.altura_columna_u() < y_final_u * 0.5)
		var altos: Array = []
		var vy_visto: float = 0.0
		var en_suelo_visto: bool = true
		for k in range(0, int((hv.tiempo_crecimiento + 0.3) / DT)):
			_pasos(hv, 1)
			if k == 5:
				vy_visto = _jug.vy
				en_suelo_visto = _jug.en_suelo
			if k % 25 == 0:
				altos.append([hv.altura_columna_u(), e_dentro.alto_pedido])
		var crece_siempre: bool = true
		for i in range(1, altos.size()):
			crece_siempre = crece_siempre and float(altos[i][0]) >= float(altos[i - 1][0]) - 0.0001
		_ok("%s R4 · la altura crece con el tiempo (u): %s y acaba en %.2f u (la entera)" % [el, str(altos.map(func(a: Array) -> float: return snappedf(float(a[0]), 0.01))), hv.altura_columna_u()], crece_siempre and float(altos[0][0]) < float(altos[altos.size() - 1][0]) and _cerca(hv.altura_columna_u(), y_final_u, 0.001))
		_ok("%s R4 · ELEVA lo que hay dentro: el enemigo es alzado (%s) con la cima (%.2f u) y el de fuera no (%.2f)" % [el, str(altos.map(func(a: Array) -> float: return snappedf(float(a[1]), 0.01))), hv.altura_columna_u(), e_fuera.alto_pedido],
			float(altos[0][1]) > 0.0 and float(altos[altos.size() - 1][1]) > float(altos[0][1]) and _cerca(e_dentro.alto_pedido, hv.altura_columna_u(), 0.01) and e_fuera.alto_pedido == 0.0)
		_ok("%s R4 · y la jugadora, que está dentro, sube con el salto de siempre (vy %.1f u/s, en_suelo %s)" % [el, vy_visto, str(en_suelo_visto)], vy_visto > 0.0 and not en_suelo_visto and hv.elevados > 0)
		await process_frame
	# --- sin ᚷ la altura nace entera y no alza nada; con ᚷ pero sin ᛏ tampoco es un pilar ---
	for el in ["agua", "fuego"]:
		_montar()
		var e: Enemigo = _enemigo(0.0)
		var hv2: HechizoVivo = _lanzar(_hz(el, {"altura": 3}))
		_pasos(hv2, 120)
		_ok("%s contraejemplo R4 · ᛏ ᛏ ᛏ sin ᚷ: no hay columna que crece ni alza nada (columna %d, alto pedido %.2f)" % [el, hv2.columna.size(), e.alto_pedido], hv2.columna.is_empty() and e.alto_pedido == 0.0 and hv2.elevados == 0)
		_montar()
		var e2: Enemigo = _enemigo(0.0)
		var hv3: HechizoVivo = _lanzar(_hz(el, {"pulso": 1}))
		_pasos(hv3, 120)
		_ok("%s contraejemplo R4 · ᚷ solo (una bola que crece): tampoco alza nada (alto pedido %.2f)" % [el, e2.alto_pedido], hv3.columna.is_empty() and e2.alto_pedido == 0.0)
	# --- la altura que se queda tras acabar: el enemigo baja solo (la retención de Combate3D) y se suelta al acabar la vida ---
	_montar()
	var e3: Enemigo = _enemigo(0.0)
	var hv4: HechizoVivo = _lanzar(_hz("agua", {"altura": 3, "pulso": 1}))
	var vida_col: float = float(hv4.columna["vida"])
	_pasos(hv4, int((vida_col + 0.5) / DT))
	var pedido_al_acabar: float = e3.alto_pedido
	_pasos(hv4, 30)
	_ok("agua R4 · al acabar la vida del pilar (%.2f s) deja de pedirle altura (sigue en %.2f u, no sube más)" % [vida_col, pedido_al_acabar], _cerca(e3.alto_pedido, pedido_al_acabar, 0.0001))


# =====================================================================================================
#  R5 · ᚷ golpea al crecer (por casillas nuevas) y el agua estalla
# =====================================================================================================

## Un volumen grande que crece (semieje 2 casillas con `crece`): cada fase gana casillas nuevas y golpea lo que hay en ellas, en orden de tiempo: una onda que se expande, no solo el golpe del nacimiento.
func _r5_por_casillas() -> void:
	for el in ["fuego", "agua"]:
		_montar()
		var h: Hechizo = _hz(el, {"pulso": 1}, {"semiejes.x": 2.0, "semiejes.z": 2.0})
		var hv_prep: HechizoVivo = HechizoVivo.preparar(h, _l)
		var evs: Array = hv_prep.eventos_de(h.geo(), Vector2(_origen().x, _origen().z), Vector2.RIGHT)
		hv_prep.free()
		_ok("%s R5 · ᚷ con un volumen de 2 casillas de semieje: %d tandas de casillas nuevas, la última a %.2f s (tiempo de crecer %.2f s)" % [el, evs.size(), float((evs.back() as Dictionary)["t"]), HechizoVivo.tiempo_de_crecer(h.crece, h.escala_nace, 2.0)], evs.size() >= 3)
		# un enemigo en una casilla de la primera tanda, otro de una intermedia y otro de la última
		var pos: Array = []
		for idx in [0, evs.size() / 2, evs.size() - 1]:
			var c: Vector2i = ((evs[idx] as Dictionary)["celdas"] as Array)[0]
			pos.append([c, float((evs[idx] as Dictionary)["t"])])
		var enemigos: Array = []
		for p in pos:
			enemigos.append(_enemigo(float((p[0] as Vector2i).x - ORIGEN_C.x), float((p[0] as Vector2i).y - ORIGEN_C.y)))
		await process_frame
		var hv: HechizoVivo = _lanzar(h)
		var horas: Array = [-999.0, -999.0, -999.0]
		var fin: float = float(pos[2][1]) + 0.5
		while float(Time.get_ticks_msec() - _t0) / 1000.0 < fin:
			await process_frame
			for i in range(3):
				if horas[i] < -900.0 and not (enemigos[i] as Enemigo).golpes.is_empty():
					horas[i] = float((enemigos[i] as Enemigo).golpes[0] - _t0) / 1000.0
		_ok("%s R5 · cada fase golpea las casillas NUEVAS que alcanza: golpes a %s s (tandas a %.2f / %.2f / %.2f s)" % [el, str(horas.map(func(x: float) -> float: return snappedf(x, 0.01))), float(pos[0][1]), float(pos[1][1]), float(pos[2][1])],
			horas[0] > -900.0 and horas[0] < 0.2 and horas[1] > horas[0] + 0.3 and horas[2] > horas[1] + 0.3 and horas[2] > 1.0)
		await process_frame


## ᛚ ᚷ ᚷ ⧖: el agua crece y ESTALLA al acabar: daño en área de su tamaño final (+ margen) que llega a un enemigo en el borde, fuera de las casillas del volumen, y no a uno más lejos.
func _r5_estallido() -> void:
	_montar()
	var h: Hechizo = _hz("agua", {"pulso": 2, "retardo": 1})
	var radio_u: float = h.radio_estallido * CASILLA
	var e_borde: Enemigo = _enemigo((radio_u + 0.3) / CASILLA, 0.0)               # en el borde del daño (radio + el radio del enemigo), fuera de la casilla del volumen
	var e_lejos: Enemigo = _enemigo((radio_u + HechizoVivo.RADIO_ENEMIGO_U + 1.0) / CASILLA, 0.0)
	await process_frame
	var hv: HechizoVivo = _lanzar(h)
	var t_est: float = h.retardo + hv._t_estallido()
	var hv_centro: Vector3 = hv._centro_volumen
	_ok("agua R5 · ᛚ ᚷ ᚷ ⧖: estalla a los %.2f s (retardo %.1f + vida) con radio %.2f casillas (%.2f u); el enemigo del borde está a %.2f u del centro" % [t_est, h.retardo, h.radio_estallido, radio_u, _plano(e_borde.position, hv._centro_volumen)], h.estalla)
	await _hasta(t_est - 0.3)
	_ok("agua R5 · antes de estallar no hay daño en área (borde %d golpes, estallidos %d)" % [e_borde.golpes.size(), hv.estallidos], hv.estallidos == 0 and e_borde.golpes.is_empty())
	await _hasta(t_est + 0.4)                                # (el hechizo se borra al estallar: era lo último que le quedaba, así que aquí ya no se lee su contador, solo lo que pasó a los enemigos)
	_ok("agua R5 · al estallar el daño en ÁREA llega al enemigo del borde, que está FUERA de las casillas del volumen (%d golpes, a %.2f u) y no al de fuera del radio (%d golpes)" % [e_borde.golpes.size(), _plano(e_borde.position, hv_centro), e_lejos.golpes.size()], e_borde.golpes.size() == 1 and e_lejos.golpes.is_empty() and Terreno3D.celda_de(e_borde.position) != ORIGEN_C)
	# --- sin ᚷ: el mismo hechizo (ᚲ... ᛚ ⧖) no estalla; con fuego tampoco ---
	for caso in [["agua", {"retardo": 1}], ["fuego", {"pulso": 2, "retardo": 1}]]:
		_montar()
		var hc: Hechizo = _hz(String(caso[0]), caso[1] as Dictionary)
		var e: Enemigo = _enemigo((hc.radio_estallido * CASILLA + 0.3) / CASILLA, 0.0)
		var hvc: HechizoVivo = _lanzar(hc)
		await _hasta(hc.retardo + 1.5)
		_ok("%s contraejemplo R5 · %s: no estalla (golpes al del borde %d)" % [String(caso[0]), str(caso[1]), e.golpes.size()], (not is_instance_valid(hvc) or hvc.estallidos == 0) and e.golpes.is_empty())


# =====================================================================================================
#  A · ᛏ altura SIN tope y con rendimiento decreciente; el rechazo por altura ya no existe
# =====================================================================================================

func _altura_sin_tope() -> void:
	var ys: Array = []
	var niveles: Array = []
	var saltos: Array = []
	for n in range(1, 7):
		var h: Hechizo = _hz("tierra", {"altura": n})
		ys.append(snappedf(h.semieje_y, 0.001))
		niveles.append(h.niveles)
		saltos.append(h.semieje_y - (_hz("tierra", {"altura": n - 1}).semieje_y))
	print("      TABLA ᛏ: n = 1..6 · semieje y = %s · niveles = %s" % [str(ys), str(niveles)])
	_ok("A · 1 ᛏ da lo de hoy (semieje 0,40, 1 nivel) y 3 ᛏ siguen dando 2 niveles", is_equal_approx(float(ys[0]), 0.4) and niveles[0] == 1 and niveles[2] == 2)
	var decrece: bool = true
	for i in range(1, saltos.size()):
		decrece = decrece and float(saltos[i]) < float(saltos[i - 1]) - 0.0001
	_ok("A · cada ᛏ siguiente suma MENOS que el anterior (aportes %s)" % str(saltos.map(func(x: float) -> float: return snappedf(x, 0.001))), decrece and is_equal_approx(float(saltos[0]), 0.3))
	_ok("A · sin tope: la altura sigue subiendo con cada ᛏ (6 ᛏ = %.3f) y 99 ᛏ se quedan en la asíntota %.2f, sin que nada la corte (límite de seguridad %.0f)" % [ys[5], _hz("tierra", {"altura": 99}).semieje_y, Hechizo.LIM_SEMIEJE_ALTO],
		float(ys[5]) > float(ys[4]) and _hz("tierra", {"altura": 99}).semieje_y > 2.09 and _hz("tierra", {"altura": 99}).semieje_y < 2.1001)
	# ya no se rechaza: ni el aviso, ni el lanzamiento (tierra de 6 ᛏ, un haz y una flecha de tierra con altura)
	var alto: Hechizo = _hz("tierra", {"altura": 6})
	_ok("A · el aviso de altura de un sólido alto ya no rechaza (%d niveles > %d subibles): «%s»" % [alto.niveles, Jugador3D.MAX_NIVELES_SUBIBLES, Lanzador3D.GeometriaV2.aviso_materia(alto.geo(), _runas["tierra"])], alto.niveles > Jugador3D.MAX_NIVELES_SUBIBLES and Lanzador3D.GeometriaV2.aviso_materia(alto.geo(), _runas["tierra"]) == "")
	_montar()
	var c_bloque: Vector2i = ORIGEN_C + Vector2i(2, 0)                                 # un sólido quieto nace donde se apunta, no bajo la jugadora
	var hv: HechizoVivo = HechizoVivo.crear(alto, Lanzador3D.centro_de(c_bloque, 0.0), Vector3.RIGHT, _l, null, {}, true)
	_ok("A · …y se LANZA y construye su bloque (casillas %d, altura %d niveles), que simplemente no es pisable (pisable a nivel 0: %s)" % [hv.casillas, Lanzador3D.altura_en(c_bloque), str(Terreno3D.pisable(c_bloque, 0, true, Jugador3D.MAX_NIVELES_SUBIBLES, false))], hv.casillas > 0 and Lanzador3D.altura_en(c_bloque) == alto.niveles and not Terreno3D.pisable(c_bloque, 0, true, Jugador3D.MAX_NIVELES_SUBIBLES, false))
	_montar()
	var flecha: HechizoVivo = _lanzar(_hz("tierra", {"altura": 6, "flecha": 1}))
	_ok("A · una flecha de tierra con ᛏ ᛏ ᛏ ᛏ ᛏ ᛏ (no construye nada al volar) sale (proyectil activo %s)" % str(flecha.activo), flecha.casillas > 0 and flecha.proyectil)
	var r_cons: String = ""
	_montar()
	r_cons = _l.puede_construir_en(ORIGEN_C + Vector2i(2, 0), 6, false)
	_ok("A · los demás motivos de rechazo de construcción siguen igual: «estás encima» («%s»), enemigo, cornisa" % _l.puede_construir_en(ORIGEN_C, 6, false), r_cons == "" and _l.puede_construir_en(ORIGEN_C, 6, false) == "estás encima")
	await process_frame


# =====================================================================================================
#  B · ᛁ más larga: la 1.ª alarga 1 casilla (semieje +0,50) y cada siguiente 0,5 casillas (+0,25)
# =====================================================================================================

func _linea_mas_larga() -> void:
	var xs: Array = []
	var anchos: Array = []
	var casillas_muro: Array = []
	for n in range(1, 7):
		var h: Hechizo = _hz("fuego", {"barrera": 1, "linea_x": n})
		xs.append(snappedf(h.semieje_x, 0.001))
		anchos.append(snappedf(2.0 * h.semieje_x, 0.01))
		var o := Vector2((float(ORIGEN_C.x) + 0.5) * CASILLA, (float(ORIGEN_C.y) + 0.5) * CASILLA)
		var celdas: Array = Lanzador3D.GeometriaV2.celdas(h.geo(), o, Vector2.RIGHT, CASILLA)
		var lado: Dictionary = {}
		for c in celdas:
			lado[(c as Vector2i).y] = true
		casillas_muro.append(lado.size())
	print("      TABLA ᛁ: n = 1..6 · semieje x = %s · ancho total = %s casillas · casillas de ancho del muro (ᛜ + ᛁ) = %s" % [str(xs), str(anchos), str(casillas_muro)])
	_ok("B · la 1.ª ᛁ alarga 1 casilla (semieje +0,50) y cada siguiente 0,5 casillas (+0,25): %s" % str(xs), xs == [0.6, 0.85, 1.1, 1.35, 1.6, 1.85])
	_ok("B · ᛜ + 5 ᛁ = muro de ≥ 3 casillas (%d) con los 6 glifos de una página; con 3 ᛁ ya (%d)" % [casillas_muro[4], casillas_muro[2]], int(casillas_muro[4]) >= 3 and int(casillas_muro[2]) >= 3 and int(casillas_muro[1]) == 1)
	var z: Hechizo = _hz("fuego", {"linea_z": 3})
	_ok("B · linea_z igual (fondo): 3 ᛁ = semieje z %.2f" % z.semieje_z, is_equal_approx(z.semieje_z, 1.1))
	# el HAZ no cambia: alcance 3 m + 1 m por ᛁ (tope 6)
	var alcances: Array = []
	for n in range(1, 7):
		alcances.append(_hz("fuego", {"linea_x": n}).alcance_haz)
	_ok("B · el alcance del HAZ no cambia: %s m (3 + 1 por ᛁ, tope 6)" % str(alcances), alcances == [3.0, 4.0, 5.0, 6.0, 6.0, 6.0])
	# el muro de 3 casillas nace delante y no se solapa con la jugadora
	_montar()
	var muro: Hechizo = _hz("fuego", {"barrera": 1, "linea_x": 5})
	var vm: HechizoVivo = _lanzar(muro)
	var delante: Vector2i = ORIGEN_C + Vector2i(1, 0)
	var s: Dictionary = _solidas(vm)
	_ok("B · ᛜ + 5 ᛁ: el muro nace DELANTE (%s) con 3 casillas de ancho y la jugadora (%s) no queda bloqueada: solideces %s" % [str(delante), str(ORIGEN_C), str(s.keys())],
		s.has(delante) and s.has(delante + Vector2i(0, 1)) and s.has(delante + Vector2i(0, -1)) and not _bloquea(ORIGEN_C) and muro.geo()["muro"])
	_ok("B · …y el toy MURO lo dibuja ancho: describir da figura MURO de %.2f m de semieje largo (3 casillas ≈ %.2f m)" % [float(FuegoToy.describir(muro, CASILLA)["x"]), 3.0 * CASILLA], int(FuegoToy.describir(muro, CASILLA)["figura"]) == FuegoToy.Figura.MURO and float(FuegoToy.describir(muro, CASILLA)["x"]) > 1.4 * CASILLA)
	await process_frame

# =====================================================================================================
#  La previsión en seco no se rompe con ninguna de las cinco
# =====================================================================================================

func _previsiones() -> void:
	_montar()
	for caso in [["fuego", {"barrera": 1, "linea_x": 2, "flecha": 1, "retorno": 1}], ["agua", {"repeticion": 2, "retorno": 1}], ["agua", {"altura": 3, "pulso": 1}], ["agua", {"pulso": 2, "retardo": 1}], ["rayo", {"barrera": 1, "linea_x": 2, "flecha": 1}], ["tierra", {"barrera": 1, "linea_x": 2, "flecha": 1, "retorno": 1}]]:
		var h: Hechizo = _hz(String(caso[0]), caso[1] as Dictionary)
		var prev: Dictionary = HechizoVivo.prever(h, _l, _origen(), Vector3.RIGHT)
		_ok("previsión %s %s: no se rompe (%d volúmenes, %d casillas de suelo)" % [String(caso[0]), str(caso[1]), (prev["volumenes"] as Array).size(), (prev["suelo"] as Array).size()], prev.has("golpes"))
	await process_frame

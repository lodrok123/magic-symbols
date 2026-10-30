extends SceneTree
## ORDEN Y UNICIDAD DE EVENTOS Y MOMENTOS DEL HECHIZO VIVO (H0 del PLAN_SISTEMA_HECHIZOS, 29/10), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_eventos_hechizo.gd
## Las 286 recetas de 0 a 3 glifos de los 10 glifos de `GLIFOS_PRUEBA` × los 6 elementos = 1716 hechizos se ejecutan con `HechizoVivo.crear(..., a_mano = true)` en un mundo falso de 20×20
## llano (el de `prueba_ejecucion_combinaciones`) y los proyectiles se avanzan con `paso(1/60)` hasta que acaban. Para cada HechizoVivo (el lanzado y sus hermanos de copia) afirma:
##   · cada nombre de `eventos_vistos` sale como mucho una vez, salvo `al_viajar` y `al_rebotar`;
##   · en `momentos_vistos`, «inicio» y «final» como mucho una vez y «continuo» ≤ `Sigils.MAX_DISPAROS_CONTINUOS`;
##   · `motivo_fin` de un proyectil ∈ {golpe, muro, suelo, alcance, tiempo, frenado, retorno};
##   · si hay acciones de momento final y es proyectil, `celdas_de_contacto` donde se paró no está vacío y sus casillas están en el mapa;
##   · H2 (29/10), los TRES FINALES: un tramo de proyectil acaba en exactamente UNO de {al_impactar, al_detenerse, al_expirar} (`finales_vistos`, que anota el evento tenga o no acciones):
##     al_impactar si `motivo_fin` es «golpe», al_detenerse en cualquier otro caso, y al_expirar nunca (es la extinción de lo que nace quieto: ahí ≤ 1). En `eventos_vistos` (solo lo que dispara
##     acciones) nunca hay dos de los tres. La ida y vuelta de `retorna` cuenta como UN tramo: el final de la ida no dispara nada (`_fin_de_ida`), solo el de la vuelta;
##   · el ORDEN DE DIBUJO no existe: con los glifos al revés, el Hechizo es idéntico y eventos y momentos (sin `t`) también.
## Y un bloque con casos concretos de ᚱ y de los tres finales (pared a 2 casillas, enemigo, ᚱ quieto, hechizo de laboratorio con acciones en cada final).

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var marcas: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		marcas.append([elemento, Terreno3D.celda_de(punto)])

## Un Hechizo cuyos glifos tienen todos el mismo momento (`momento_fijo`): para probar los momentos finos «impacto», «detencion» y «extincion», que ningún glifo usa todavía.
class HechizoFino extends Hechizo:
	var momento_fijo: String = "final"
	func momento_de(_glifo: String) -> String:
		return momento_fijo

const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const GLIFOS_PRUEBA: Array = ["linea_x", "linea_z", "altura", "flecha", "barrera", "repeticion", "rebote", "pulso", "raido", "permanencia"]
const MAX_GLIFOS: int = 3
const LADO: int = 20
const ORIGEN_C: Vector2i = Vector2i(6, 10)
const DT: float = 1.0 / 60.0
const MAX_PASOS: int = 3000
const MOTIVOS: PackedStringArray = ["golpe", "muro", "suelo", "alcance", "tiempo", "frenado", "retorno"]
const EVENTOS_REPETIBLES: PackedStringArray = ["al_viajar", "al_rebotar"]
const FINALES: PackedStringArray = ["al_impactar", "al_detenerse", "al_expirar"]
const MAX_EJEMPLOS: int = 4

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _tipos: Dictionary = {}
var _ejemplos: Dictionary = {}
var _ejecutados: int = 0
var _vivos_vistos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _anota(criterio: String, caso: String) -> void:
	_tipos[criterio] = int(_tipos.get(criterio, 0)) + 1
	var l: Array = _ejemplos.get(criterio, [])
	if l.size() < MAX_EJEMPLOS:
		l.append(caso)
	_ejemplos[criterio] = l


func _generar(nombres: Array, restante: int, desde: int, actual: Array, salida: Array) -> void:
	salida.append(actual.duplicate())
	if restante == 0:
		return
	for i in range(desde, nombres.size()):
		actual.append(nombres[i])
		_generar(nombres, restante - 1, i, actual, salida)
		actual.pop_back()


## Contadores de glifos; `al_reves` = insertados en orden inverso (el orden de dibujo).
func _contadores(combo: Array, al_reves: bool = false) -> Dictionary:
	var c: Dictionary = {}
	var seq: Array = combo.duplicate()
	if al_reves:
		seq.reverse()
	for n in seq:
		c[n] = int(c.get(n, 0)) + 1
	return c


func _initialize() -> void:
	await process_frame
	var t0: int = Time.get_ticks_msec()
	var runes: Dictionary = {}
	for e in ELEMENTOS:
		runes[e] = load("res://nucleo/%s_rune.tres" % e)
	if OS.get_cmdline_user_args().has("--solo-casos"):           # atajo para iterar: salta las 1716 y corre solo los casos concretos
		await _casos_raido(runes)
		await _casos_finales(runes)
		print("FALLOS: %d" % _fallos)
		quit(1 if _fallos > 0 else 0)
		return
	var combos: Array = []
	_generar(GLIFOS_PRUEBA, MAX_GLIFOS, 0, [], combos)
	print("recetas: %d (0 a %d glifos de %d) × %d elementos = %d hechizos" % [combos.size(), MAX_GLIFOS, GLIFOS_PRUEBA.size(), ELEMENTOS.size(), combos.size() * ELEMENTOS.size()])
	_ok("hay 286 recetas (1 + 10 + 55 + 220)", combos.size() == 286, "%d" % combos.size())
	for combo in combos:
		for e in ELEMENTOS:
			await _caso(runes[e], e, combo)
	_resumen(float(Time.get_ticks_msec() - t0) / 1000.0)
	await _casos_raido(runes)
	await _casos_finales(runes)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# =====================================================================================================
#  Mundo y ejecución (de prueba_ejecucion_combinaciones)
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
	_jug = Jugador3D.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), 1.0)
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	Lanzador3D.montar_agua_sim()


func _origen_de(h: Hechizo) -> Vector3:
	if h.en_punto:
		return Lanzador3D.centro_de(ORIGEN_C + Vector2i(2, 0), 0.0)
	return Lanzador3D.centro_de(ORIGEN_C, 0.0)


func _vivos() -> Array:
	var r: Array = []
	for n in _l.get_children():
		if n is HechizoVivo:
			r.append(n)
	return r


func _correr(vivos: Array) -> void:
	var pasos: int = 0
	while pasos < MAX_PASOS:
		var alguno: bool = false
		for v in vivos:
			if is_instance_valid(v) and (v as HechizoVivo).activo:
				(v as HechizoVivo).paso(DT)
				alguno = true
		if not alguno:
			return
		pasos += 1


## Un enemigo de Combate3D en la casilla `c` del mundo falso (como `prueba_hechizo_vivo`): quieto y congelado.
func _enemigo(c: Vector2i) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	_m.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, _m, _jug, _l)
	e.set_physics_process(false)
	e.altura = 0.85
	e.congelado = 99.0
	return e


## Lanza un Hechizo ya construido en un mundo nuevo, con una pared extra en `pared` y/o un enemigo en `enemigo` (Vector2i(-1, -1) = ninguno). Devuelve {h, v, vivos, enemigo}.
func _ejecutar_h(h: Hechizo, pared: Vector2i = Vector2i(-1, -1), enemigo: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	_montar()
	if pared.x >= 0:
		_m._bloqueadas[pared] = true
		_m._mapa[pared.y] = _m._mapa[pared.y].substr(0, pared.x) + "#" + _m._mapa[pared.y].substr(pared.x + 1)
	var e: Combate3D = _enemigo(enemigo) if enemigo.x >= 0 else null
	var v: HechizoVivo = HechizoVivo.crear(h, _origen_de(h), Vector3.RIGHT, _l, null, {}, true)
	var vivos: Array = _vivos()
	if h.velocidad > 0.0:
		_correr(vivos)
	_ejecutados += 1
	return {"h": h, "v": v, "vivos": vivos, "enemigo": e}


## Lanza y avanza los proyectiles hasta el final. Devuelve el hechizo y todos los HechizoVivo (el lanzado y sus hermanos).
func _ejecutar(rune: RuneData, combo: Array, al_reves: bool = false) -> Dictionary:
	_montar()
	var h: Hechizo = Hechizo.construir(rune, _contadores(combo, al_reves), 1.0)
	var v: HechizoVivo = HechizoVivo.crear(h, _origen_de(h), Vector3.RIGHT, _l, null, {}, true)
	var vivos: Array = _vivos()
	if h.velocidad > 0.0:
		_correr(vivos)
	_ejecutados += 1
	return {"h": h, "v": v, "vivos": vivos}


func _limpiar(r: Dictionary) -> void:
	for v in r["vivos"]:
		if is_instance_valid(v) and not (v as Node).is_queued_for_deletion():
			(v as Node).queue_free()
	await process_frame


func _momentos_sin_t(v: HechizoVivo) -> Array:
	var r: Array = []
	for m in v.momentos_vistos:
		var d: Dictionary = (m as Dictionary).duplicate()
		d.erase("t")
		r.append(d)
	return r


func _cuenta(lista: Array) -> Dictionary:
	var c: Dictionary = {}
	for x in lista:
		c[String(x)] = int(c.get(String(x), 0)) + 1
	return c


# =====================================================================================================
#  Las 1716
# =====================================================================================================

func _caso(rune: RuneData, elemento: String, combo: Array) -> void:
	var et: String = "%s %s" % [elemento, str(combo)]
	var r: Dictionary = _ejecutar(rune, combo)
	var h: Hechizo = r["h"]
	var vivos: Array = r["vivos"]
	for vv in vivos:
		var v: HechizoVivo = vv
		_vivos_vistos += 1
		# --- eventos: una vez cada uno (salvo viajar y rebotar) ---
		var por_evento: Dictionary = _cuenta(v.eventos_vistos)
		for nombre in por_evento:
			if int(por_evento[nombre]) > 1 and not EVENTOS_REPETIBLES.has(String(nombre)):
				_anota("evento repetido (cada uno, una vez)", "%s: %s ×%d" % [et, nombre, int(por_evento[nombre])])
		# --- momentos: inicio y final una vez; continuo ≤ tope ---
		var por_momento: Dictionary = {}
		for m in v.momentos_vistos:
			var nm: String = String((m as Dictionary)["momento"])
			por_momento[nm] = int(por_momento.get(nm, 0)) + 1
		for nm in [Sigils.MOMENTO_INICIO, Sigils.MOMENTO_FINAL]:
			if int(por_momento.get(nm, 0)) > 1:
				_anota("momento «inicio» o «final» repetido", "%s: %s ×%d" % [et, nm, int(por_momento[nm])])
		if int(por_momento.get(Sigils.MOMENTO_CONTINUO, 0)) > Sigils.MAX_DISPAROS_CONTINUOS:
			_anota("«continuo» pasa de MAX_DISPAROS_CONTINUOS", "%s: ×%d" % [et, int(por_momento[Sigils.MOMENTO_CONTINUO])])
		# --- H2: los tres finales (finales_vistos cuenta aunque el evento no tenga acciones; eventos_vistos solo cuenta los que disparan algo) ---
		var finales_con_acciones: int = 0
		for f in FINALES:
			finales_con_acciones += mini(int(por_evento.get(f, 0)), 1)
		if finales_con_acciones > 1:
			_anota("dos de los tres finales con acciones en un mismo hechizo", "%s: %s" % [et, str(v.eventos_vistos)])
		var n_finales: int = v.finales_vistos.size()
		if v.h.velocidad > 0.0:
			var esperado: String = "al_impactar" if v.motivo_fin == "golpe" else "al_detenerse"
			if not v.activo and (n_finales != 1 or String(v.finales_vistos[0]) != esperado):
				_anota("un proyectil acaba en exactamente UN final (impactar si golpe, detenerse si no)", "%s: «%s» → %s" % [et, v.motivo_fin, str(v.finales_vistos)])
			if int(por_evento.get("al_expirar", 0)) > 0:
				_anota("un proyectil ya no dispara al_expirar", et)
		elif n_finales > 1 or (n_finales == 1 and String(v.finales_vistos[0]) != "al_expirar"):
			_anota("lo que nace quieto: como mucho un final y es al_expirar", "%s: %s" % [et, str(v.finales_vistos)])
		# --- proyectil: motivo de fin y contacto del momento final ---
		if v.h.velocidad > 0.0:
			if v.activo:
				_anota("el proyectil acaba (no pasa de MAX_PASOS)", et)
			elif not MOTIVOS.has(v.motivo_fin):
				_anota("motivo_fin válido", "%s: «%s»" % [et, v.motivo_fin])
			if not v.activo and not v.h.acciones_en(Sigils.MOMENTO_FINAL).is_empty():
				var celdas: Array = v.celdas_de_contacto(v.p, v.v.normalized())
				if celdas.is_empty():
					_anota("celdas_de_contacto vacío con acciones de momento final", et)
				else:
					for c in celdas:
						if not Terreno3D.en_mapa(c as Vector2i):
							_anota("celdas_de_contacto fuera del mapa", "%s: %s" % [et, str(c)])
							break
	# --- orden de dibujo: con los glifos al revés, lo mismo (la 2.ª ejecución monta un mundo nuevo y libera el 1.º: se guarda antes lo que se compara) ---
	var v1: HechizoVivo = r["v"]
	var ev1: Array = v1.eventos_vistos.duplicate()
	var mo1: Array = _momentos_sin_t(v1)
	var dic1: Dictionary = h.a_diccionario()
	var n1: int = vivos.size()
	await _limpiar(r)
	var r2: Dictionary = _ejecutar(rune, combo, true)
	var h2: Hechizo = r2["h"]
	if dic1 != h2.a_diccionario():
		_anota("orden de dibujo: el Hechizo cambia", et)
	var v2: HechizoVivo = r2["v"]
	if ev1 != v2.eventos_vistos:
		_anota("orden de dibujo: eventos_vistos cambian", "%s: %s ≠ %s" % [et, str(ev1), str(v2.eventos_vistos)])
	if mo1 != _momentos_sin_t(v2):
		_anota("orden de dibujo: momentos_vistos cambian", "%s: %s ≠ %s" % [et, str(mo1), str(_momentos_sin_t(v2))])
	if n1 != (r2["vivos"] as Array).size():
		_anota("orden de dibujo: el nº de hermanos cambia", et)
	await _limpiar(r2)


func _resumen(seg: float) -> void:
	print("ejecutados: %d lanzamientos (%d hechizos vivos mirados) en %.1f s" % [_ejecutados, _vivos_vistos, seg])
	var criterios: Array = ["evento repetido (cada uno, una vez)", "momento «inicio» o «final» repetido", "«continuo» pasa de MAX_DISPAROS_CONTINUOS", "el proyectil acaba (no pasa de MAX_PASOS)",
		"motivo_fin válido", "celdas_de_contacto vacío con acciones de momento final", "celdas_de_contacto fuera del mapa", "orden de dibujo: el Hechizo cambia",
		"orden de dibujo: eventos_vistos cambian", "orden de dibujo: momentos_vistos cambian", "orden de dibujo: el nº de hermanos cambia",
		"dos de los tres finales con acciones en un mismo hechizo", "un proyectil acaba en exactamente UN final (impactar si golpe, detenerse si no)", "un proyectil ya no dispara al_expirar",
		"lo que nace quieto: como mucho un final y es al_expirar"]
	_ok("se ejecutaron 286 × 6 × 2 lanzamientos", _ejecutados == 286 * ELEMENTOS.size() * 2, "%d" % _ejecutados)
	for crit in criterios:
		var n: int = int(_tipos.get(crit, 0))
		_ok("%s (en %d casos)" % [crit, n], n == 0, "" if n == 0 else "p. ej. " + str(_ejemplos.get(crit, [])))


# =====================================================================================================
#  Casos concretos de ᚱ (con números)
# =====================================================================================================

func _casos_raido(runes: Dictionary) -> void:
	var fuego: RuneData = runes["fire"]
	# ᚱ + flecha: viaja → momento «final»: un solo momento «final», ninguno «inicio», un Pulso3D
	var r: Dictionary = _ejecutar(fuego, ["raido", "flecha"])
	var v: HechizoVivo = r["v"]
	var finales: int = 0
	var inicios: int = 0
	for m in v.momentos_vistos:
		finales += 1 if String((m as Dictionary)["momento"]) == Sigils.MOMENTO_FINAL else 0
		inicios += 1 if String((m as Dictionary)["momento"]) == Sigils.MOMENTO_INICIO else 0
	_ok("ᚱ + flecha de fuego: exactamente 1 momento «final» (%d), ninguno «inicio» (%d)" % [finales, inicios], finales == 1 and inicios == 0)
	_ok("ᚱ + flecha de fuego: un Pulso3D (%d) y el proyectil acaba (%s)" % [v.pulsos_soltados.size(), v.motivo_fin], v.pulsos_soltados.size() == 1 and not v.activo)
	await _limpiar(r)
	# ᚱ + barrera: persistente → «continuo» ≥ 1 y ningún «final» antes de acabar su vida (aquí no se avanza el reloj: solo el disparo inmediato)
	r = _ejecutar(fuego, ["raido", "barrera"])
	v = r["v"]
	var continuos: int = 0
	finales = 0
	for m in v.momentos_vistos:
		continuos += 1 if String((m as Dictionary)["momento"]) == Sigils.MOMENTO_CONTINUO else 0
		finales += 1 if String((m as Dictionary)["momento"]) == Sigils.MOMENTO_FINAL else 0
	_ok("ᚱ + barrera de fuego: «continuo» ≥ 1 (%d) y ningún «final» antes de acabar la vida (%d)" % [continuos, finales], continuos >= 1 and finales == 0)
	await _limpiar(r)
	# ᚱ sola: «inicio» una vez
	r = _ejecutar(fuego, ["raido"])
	v = r["v"]
	inicios = 0
	for m in v.momentos_vistos:
		inicios += 1 if String((m as Dictionary)["momento"]) == Sigils.MOMENTO_INICIO else 0
	_ok("ᚱ sola: «inicio» exactamente una vez (%d de %d momentos)" % [inicios, v.momentos_vistos.size()], inicios == 1 and v.momentos_vistos.size() == 1)
	await _limpiar(r)


# =====================================================================================================
#  Los tres finales, con números (H2)
# =====================================================================================================

## Cuántas marcas de suelo de ese estado dejó el mundo falso.
func _marcas_de(estado: String) -> int:
	var n: int = 0
	for mc in _m.marcas:
		n += 1 if String((mc as Array)[0]) == estado else 0
	return n


func _celdas_de_pulsos(v: HechizoVivo) -> Array:
	var r: Array = []
	for pu in v.pulsos_soltados:
		r.append_array((pu as Pulso3D).origenes)
	return r


## Casos concretos de los tres finales.
func _casos_finales(runes: Dictionary) -> void:
	var fuego: RuneData = runes["fire"]
	# 1 · ᚱ + flecha de fuego contra una pared a 2 casillas: «muro», 1 pulso, al_detenerse (con el pulso) y ningún al_impactar
	var r: Dictionary = _ejecutar_h(Hechizo.construir(fuego, _contadores(["raido", "flecha"]), 1.0), ORIGEN_C + Vector2i(2, 0))
	var v: HechizoVivo = r["v"]
	var cel: Array = _celdas_de_pulsos(v)
	_ok("finales · ᚱ + flecha contra pared a 2 casillas: motivo «muro» (%s), 1 pulso (%d), finales_vistos = %s" % [v.motivo_fin, v.pulsos_soltados.size(), str(v.finales_vistos)],
		v.motivo_fin == "muro" and v.pulsos_soltados.size() == 1 and v.finales_vistos == ["al_detenerse"])
	_ok("finales · … el pulso sale de la superficie de contacto (casillas %s, la de delante de la pared incluida)" % str(cel), cel.has(ORIGEN_C + Vector2i(1, 0)) and not cel.has(ORIGEN_C + Vector2i(3, 0)))
	await _limpiar(r)
	# 2 · lo mismo contra un enemigo en esa casilla: «golpe», al_impactar, 1 pulso desde la casilla del enemigo
	r = _ejecutar_h(Hechizo.construir(fuego, _contadores(["raido", "flecha"]), 1.0), Vector2i(-1, -1), ORIGEN_C + Vector2i(2, 0))
	v = r["v"]
	cel = _celdas_de_pulsos(v)
	_ok("finales · ᚱ + flecha contra un enemigo: motivo «golpe» (%s), 1 pulso (%d), finales_vistos = %s, el enemigo está herido (%.0f)" % [v.motivo_fin, v.pulsos_soltados.size(), str(v.finales_vistos), (r["enemigo"] as Combate3D).health],
		v.motivo_fin == "golpe" and v.pulsos_soltados.size() == 1 and v.finales_vistos == ["al_impactar"] and (r["enemigo"] as Combate3D).health < 100.0)
	_ok("finales · … y el pulso sale de la casilla del enemigo (%s)" % str(cel), cel.has(ORIGEN_C + Vector2i(2, 0)))
	await _limpiar(r)
	# 2b · 30/10 (playtest de Pablo: «el pulso debe nacer del punto de impacto»): flecha ×3 (4 casillas de alcance) + ᚱ contra un enemigo a 3 casillas: el Pulso3D arranca en la casilla del ENEMIGO,
	# ni en la del lanzador ni en la del final del alcance; y contra una pared a 3 casillas, en la casilla de delante de la pared (la de contacto).
	r = _ejecutar_h(Hechizo.construir(fuego, _contadores(["raido", "flecha", "flecha", "flecha"]), 1.0), Vector2i(-1, -1), ORIGEN_C + Vector2i(3, 0))
	v = r["v"]
	cel = _celdas_de_pulsos(v)
	_ok("finales · ᚱ + flecha×3 contra un enemigo a 3 casillas: el pulso arranca en SU casilla (%s) y no en la del lanzador ni en la del alcance (%s)" % [str(ORIGEN_C + Vector2i(3, 0)), str(cel)],
		v.motivo_fin == "golpe" and v.pulsos_soltados.size() == 1 and cel.has(ORIGEN_C + Vector2i(3, 0)) and not cel.has(ORIGEN_C) and not cel.has(ORIGEN_C + Vector2i(4, 0)))
	await _limpiar(r)
	r = _ejecutar_h(Hechizo.construir(fuego, _contadores(["raido", "flecha", "flecha", "flecha"]), 1.0), ORIGEN_C + Vector2i(3, 0))
	v = r["v"]
	cel = _celdas_de_pulsos(v)
	_ok("finales · ᚱ + flecha×3 contra una pared a 3 casillas: el pulso arranca en la superficie de contacto (%s) y no en la del lanzador" % str(cel), v.motivo_fin == "muro" and v.pulsos_soltados.size() == 1 and cel.has(ORIGEN_C + Vector2i(2, 0)) and not cel.has(ORIGEN_C))
	await _limpiar(r)
	# 3 · ᚱ quieto: el pulso sale al inicio y al_expirar (con una acción de laboratorio) salta UNA vez al acabar la vida, no antes
	var hq: Hechizo = Hechizo.construir(fuego, _contadores(["raido"]), 1.0).con({"eventos": {"al_expirar": [{"accion": "vfx", "nombre": "fin"}]}})
	r = _ejecutar_h(hq)
	v = r["v"]
	var finales: Array = v.finales_vistos                 # las listas sobreviven al nodo (se borra solo al acabar su vida)
	var eventos: Array = v.eventos_vistos
	var pulsos: Array = v.pulsos_soltados
	var antes: Array = finales.duplicate()
	var pulsos0: int = pulsos.size()
	await create_timer(hq.persiste + hq.permanencia + 0.4).timeout
	_ok("finales · ᚱ quieto: pulso al inicio (%d), sin final antes de acabar la vida (%s) y al_expirar una vez después (%s)" % [pulsos0, str(antes), str(finales)],
		pulsos0 == 1 and antes.is_empty() and finales == ["al_expirar"] and eventos.count("al_expirar") == 1 and pulsos.size() == 1)
	await _limpiar(r)
	# 4 · hechizo de laboratorio: al_detenerse deja suelo, al_impactar daña. Se compara con el MISMO hechizo sin eventos (el fuego ya marca y quema por sí solo): el suelo se mide con el estado «agua»,
	# que no hace daño, y el daño con la vida del enemigo de al lado de la pared. Contra la pared: suelo y nada de daño de más; contra un enemigo: daño de más y nada de suelo.
	var lab: Dictionary = {"eventos": {"al_detenerse": [{"accion": "estado_suelo", "estado": "agua", "radio": 1}], "al_impactar": [{"accion": "danar_area", "radio": 1}]}}
	var pared: Vector2i = ORIGEN_C + Vector2i(2, 0)
	r = _ejecutar_h(Hechizo.construir(fuego, {"flecha": 1}, 1.0), pared, ORIGEN_C + Vector2i(1, 1))
	var vida_base_muro: float = (r["enemigo"] as Combate3D).health
	await _limpiar(r)
	r = _ejecutar_h(Hechizo.construir(fuego, {"flecha": 1}, 1.0).con(lab), pared, ORIGEN_C + Vector2i(1, 1))
	v = r["v"]
	var vida_lab_muro: float = (r["enemigo"] as Combate3D).health
	var aguas: int = _marcas_de("agua")
	_ok("finales · lab, contra la pared: «%s», al_detenerse deja suelo (%d casillas de agua) y al_impactar no daña (vida %.0f, sin eventos %.0f)" % [v.motivo_fin, aguas, vida_lab_muro, vida_base_muro],
		v.motivo_fin == "muro" and v.finales_vistos == ["al_detenerse"] and aguas == 5 and is_equal_approx(vida_lab_muro, vida_base_muro))
	await _limpiar(r)
	r = _ejecutar_h(Hechizo.construir(fuego, {"flecha": 1}, 1.0), Vector2i(-1, -1), ORIGEN_C + Vector2i(2, 0))
	var vida_base_golpe: float = (r["enemigo"] as Combate3D).health
	await _limpiar(r)
	r = _ejecutar_h(Hechizo.construir(fuego, {"flecha": 1}, 1.0).con(lab), Vector2i(-1, -1), ORIGEN_C + Vector2i(2, 0))
	v = r["v"]
	var vida_lab_golpe: float = (r["enemigo"] as Combate3D).health
	aguas = _marcas_de("agua")
	_ok("finales · lab, contra un enemigo: «%s», al_impactar daña de más (vida %.0f, sin eventos %.0f) y al_detenerse no deja suelo (%d casillas de agua)" % [v.motivo_fin, vida_lab_golpe, vida_base_golpe, aguas],
		v.motivo_fin == "golpe" and v.finales_vistos == ["al_impactar"] and vida_lab_golpe < vida_base_golpe and aguas == 0)
	await _limpiar(r)
	# 5 · momento fino de un glifo: «impacto» solo en golpe, «detencion» solo al pararse sin golpear, «final» en los dos
	var fino := HechizoFino.new()
	fino.glifos = {"raido": 1}
	var casos: Array = [["golpe", "final", true], ["golpe", "impacto", true], ["golpe", "detencion", false], ["muro", "final", true], ["muro", "impacto", false], ["muro", "detencion", true],
		["alcance", "detencion", true], ["retorno", "detencion", true], ["extincion", "extincion", true], ["extincion", "final", true], ["extincion", "impacto", false], ["golpe", "inicio", false]]
	var bien: bool = true
	for c in casos:
		fino.momento_fijo = String(c[1])
		bien = bien and (not fino.acciones_en_fin(String(c[0])).is_empty()) == bool(c[2])
	fino.momento_fijo = "final"
	_ok("finales · acciones_en_fin resuelve el momento fino y el grueso («final» actúa en los tres)", bien)
	_ok("finales · acciones_en(\"final\") sigue devolviendo lo de siempre (1) y acciones_en(\"impacto\") no incluye el grueso", fino.acciones_en("final").size() == 1 and fino.acciones_en("impacto").is_empty())
	# 6 · orden fijo en los eventos: las acciones llevan el paso y el orden de su glifo y salen por ellos, no por el orden de la lista
	var ho: Hechizo = Hechizo.construir(fuego, {"flecha": 1}, 1.0).con({"eventos": {"al_nacer": [{"accion": "vfx", "nombre": "b", "paso": 5, "orden": 2}, {"accion": "vfx", "nombre": "a", "paso": 3, "orden": 9},
		{"accion": "vfx", "nombre": "c", "paso": 5, "orden": 2}, {"accion": "vfx", "nombre": "d"}]}})
	var hv: HechizoVivo = HechizoVivo.preparar(ho, _l)
	var nombres: Array = []
	for a in hv._ordenadas(ho.eventos["al_nacer"] as Array):
		nombres.append(String((a as Dictionary)["nombre"]))
	hv.free()
	_ok("finales · las acciones de un evento salen por (paso, orden, lista): %s" % str(nombres), nombres == ["d", "a", "b", "c"])

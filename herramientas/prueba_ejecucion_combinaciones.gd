extends SceneTree
## EJECUCIÓN DE LAS COMBINACIONES QUE EL JUGADOR PUEDE LANZAR (24/10, lote 1 de la auditoría de Hechizo; 05_auditoria_hechizo.md §B parte B), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_ejecucion_combinaciones.gd
## Las 165 recetas de 0 a 3 glifos de los 8 glifos que se pueden DIBUJAR hoy (flecha, barrera, linea_x, linea_z, altura, repeticion, rebote, pulso) × los 6 sellos (elementos) = 990 hechizos,
## más unos casos de ᚱ (que aún no se puede dibujar y por eso no entra en las 165) se ejecutan con `HechizoVivo.crear` en un mundo falso de 20×20 llano. El proyectil se avanza a mano (`paso(dt)`).
## Para cada uno afirma:
##   · casillas > 0, salvo el aviso de altura (un sólido de 2 niveles: tierra o hielo con ᛏᛏᛏ, que el libro no deja lanzar) que debe dar 0;
##   · copias vistas == copias (volumen: tandas con su propio centro al nacer; proyectil: un HechizoVivo por copia); el haz no tiene copias (ESPEC §3b);
##   · solidez > 0 → una SolidezV2 por cada manifestación (el proyectil la crea al pararse);
##   · ᚱ suelta su Pulso3D;
##   · cada flecha recorre ≥ 80 % de su `distancia_max` (`UMBRAL_ALCANCE`) o acaba en un obstáculo (muro, golpe): nunca «suelo» antes en terreno llano;
##   · ᚷ cambia algo medible respecto al MISMO hechizo sin ᚷ: las casillas, el nº de tandas, el tiempo de crecimiento (`tiempo_crecimiento`, el «tiempo_expansion» de la ESPEC §1.3) o el radio de acierto.
## Y un bloque aparte con las reglas nuevas del 24/10 (ᚠ en el proyectil, el par del volumen, el choque con SolidezV2, ᚷ en m/s). Se cuentan también los AVISOS que no son fallo pero Pablo debe saber.

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

const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const LADO: int = 20
const ORIGEN_C: Vector2i = Vector2i(6, 10)
const DT: float = 1.0 / 60.0
const MAX_GLIFOS_LIBRO: int = 3                 ## la lámina «bosque» tiene 3 huecos: un jugador lanza 3 glifos como máximo
const MAX_PASOS: int = 3000                     ## un proyectil que no acaba en 50 s a 60 pasos/s es un fallo
const UMBRAL_ALCANCE: float = 0.8               ## fracción de `distancia_max` que una flecha debe recorrer (si no acaba en un obstáculo)
const DIBUJABLES: Array = ["linea_x", "linea_z", "altura", "flecha", "barrera", "repeticion", "rebote", "pulso"]
## ᚱ no se puede dibujar (sin muestras en gesture_library.tres): no entra en las 165 y se prueba aparte.
const RECETAS_RAIDO: Array = [["raido"], ["raido", "flecha"], ["raido", "barrera"], ["raido", "linea_x"], ["raido", "altura"], ["raido", "flecha", "barrera"], ["raido", "repeticion", "flecha"], ["raido", "pulso", "linea_x"]]
const MAX_EJEMPLOS: int = 4

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _senales: Array = []
var _tipos: Dictionary = {}
var _ejemplos: Dictionary = {}
var _avisos: Dictionary = {}
var _ejemplos_aviso: Dictionary = {}
var _ejecutados: int = 0
var _grupos: Dictionary = {}                    ## las flechas que caen al suelo, por elemento y alcance (para ver el patrón de un vistazo)


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


func _aviso(aviso: String, caso: String) -> void:
	_avisos[aviso] = int(_avisos.get(aviso, 0)) + 1
	var l: Array = _ejemplos_aviso.get(aviso, [])
	if l.size() < MAX_EJEMPLOS:
		l.append(caso)
	_ejemplos_aviso[aviso] = l


func _generar(nombres: Array, restante: int, desde: int, actual: Array, salida: Array) -> void:
	salida.append(actual.duplicate())
	if restante == 0:
		return
	for i in range(desde, nombres.size()):
		actual.append(nombres[i])
		_generar(nombres, restante - 1, i, actual, salida)
		actual.pop_back()


func _contadores(combo: Array) -> Dictionary:
	var c: Dictionary = {}
	for n in combo:
		c[n] = int(c.get(n, 0)) + 1
	return c


## `nombre` repetido `n` veces (GDScript no multiplica arrays).
func _veces(nombre: String, n: int) -> Array:
	var r: Array = []
	for _i in range(n):
		r.append(nombre)
	return r


func _initialize() -> void:
	await process_frame
	var t0: int = Time.get_ticks_msec()
	var runes: Dictionary = {}
	for e in ELEMENTOS:
		runes[e] = load("res://nucleo/%s_rune.tres" % e)
	var combos: Array = []
	_generar(DIBUJABLES, MAX_GLIFOS_LIBRO, 0, [], combos)
	print("recetas lanzables: %d (0 a %d glifos de los %d dibujables) × %d sellos = %d hechizos · casilla = %.2f u" % [combos.size(), MAX_GLIFOS_LIBRO, DIBUJABLES.size(), ELEMENTOS.size(), combos.size() * ELEMENTOS.size(), Terreno3D.casilla])
	_ok("hay 165 recetas lanzables (1 + 8 + 36 + 120)", combos.size() == 165, "%d" % combos.size())
	for combo in combos:
		for e in ELEMENTOS:
			await _caso(runes[e], e, combo)
	for combo in RECETAS_RAIDO:
		for e in ELEMENTOS:
			await _caso(runes[e], e, combo)
	_resumen(combos.size(), float(Time.get_ticks_msec() - t0) / 1000.0)
	await _reglas_nuevas(runes)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# =====================================================================================================
#  Mundo y ejecución
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
	_senales.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, g: Dictionary, o: Vector3, d: Vector3, props: Dictionary) -> void: _senales.append([estado, el, g, o, d, props]))


func _origen_de(h: Hechizo) -> Vector3:
	# como en el juego: la barrera (en_punto) nace en el punto apuntado; aquí, 2 casillas delante (dentro del anillo de alcance de 3)
	if h.en_punto:
		return Lanzador3D.centro_de(ORIGEN_C + Vector2i(2, 0), 0.0)
	return Lanzador3D.centro_de(ORIGEN_C, 0.0)


func _rama_de(h: Hechizo) -> String:
	return "haz" if h.haz else ("proyectil" if h.velocidad > 0.0 else ("volumen_viaja" if h.viaja else "volumen_quieto"))


## Todos los HechizoVivo que cuelgan del lanzador (el lanzado y sus hermanos de copia).
func _vivos() -> Array:
	var r: Array = []
	for n in _l.get_children():
		if n is HechizoVivo:
			r.append(n)
	return r


## Avanza a mano todos los proyectiles hasta que acaben.
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


## Lanza un hechizo en un mundo nuevo y devuelve todo lo que se puede medir. `corre` = avanzar los proyectiles hasta el final.
func _ejecutar(rune: RuneData, combo: Array, corre: bool = true) -> Dictionary:
	_montar()
	var h: Hechizo = Hechizo.construir(rune, _contadores(combo), 1.0)
	var antes_sol: int = _l._solideces_v2.size()
	var origen: Vector3 = _origen_de(h)
	var v: HechizoVivo = HechizoVivo.crear(h, origen, Vector3.RIGHT, _l, null, {}, true)
	var vivos: Array = _vivos()
	var radio0: float = v._radio_u
	var tandas: int = 0
	var hora_ultima: float = 0.0
	var pos_nacer: Dictionary = {}
	if not _senales.is_empty():
		var evs: Array = (_senales[0][2] as Dictionary).get("eventos", [])
		tandas = evs.size()
		for ev in evs:
			var t_ev: float = float((ev as Dictionary)["t"])
			hora_ultima = maxf(hora_ultima, t_ev)
			if t_ev <= h.retardo + 0.001:
				pos_nacer[str((ev as Dictionary)["pos"])] = true
	if corre and h.velocidad > 0.0:
		_correr(vivos)
	_ejecutados += 1
	return {"h": h, "v": v, "vivos": vivos, "rama": _rama_de(h), "casillas": v.casillas, "solideces": _l._solideces_v2.size() - antes_sol,
		"sitios": pos_nacer.size(), "tandas": tandas, "hora_ultima": hora_ultima, "radio0": radio0, "t_crece": v.tiempo_crecimiento,
		"pulsos": _pulsos_de(vivos)}


func _pulsos_de(vivos: Array) -> int:
	var n: int = 0
	for v in vivos:
		if is_instance_valid(v):
			n += (v as HechizoVivo).pulsos_soltados.size()
	return n


## Libera lo que quedó de un caso (los HechizoVivo se van solos; los Pulso3D y las zonas, con el mundo en el siguiente `_montar`).
func _limpiar(r: Dictionary) -> void:
	for v in r["vivos"]:
		if is_instance_valid(v) and not (v as Node).is_queued_for_deletion():
			(v as Node).queue_free()
	await process_frame


# =====================================================================================================
#  Las 990 + ᚱ
# =====================================================================================================

func _caso(rune: RuneData, elemento: String, combo: Array) -> void:
	var et: String = "%s %s" % [elemento, str(combo)]
	var r: Dictionary = _ejecutar(rune, combo)
	var h: Hechizo = r["h"]
	var rama: String = r["rama"]
	var rechazado_altura: bool = Lanzador3D.GeometriaV2.aviso_materia(h.geo(), rune) != "" and rama != "haz" and rama != "proyectil"
	# --- casillas ---
	if rechazado_altura:
		if int(r["casillas"]) != 0:
			_anota("el sólido de 2 niveles se rechaza (casillas = 0)", et)
		await _limpiar(r)
		return
	if int(r["casillas"]) <= 0:
		_anota("casillas > 0", "%s (%s)" % [et, rama])
	# --- copias vistas == copias ---
	if h.copias > 1 and rama != "haz":
		var vistas: int = (r["vivos"] as Array).size() if rama == "proyectil" else int(r["sitios"])
		if vistas != h.copias:
			_anota("copias vistas == copias (%s)" % ("proyectil" if rama == "proyectil" else "volumen"), "%s: copias %d, vistas %d" % [et, h.copias, vistas])
	# --- solidez → SolidezV2 (una por manifestación) ---
	if h.solidez > 0.0:
		var esperadas: int = (r["vivos"] as Array).size() if rama == "proyectil" else 1
		if int(r["solideces"]) < esperadas:
			_anota("solidez → SolidezV2 (una por manifestación)", "%s: %d de %d" % [et, int(r["solideces"]), esperadas])
	# --- ᚱ suelta su pulso ---
	if h.resuena > 0.0 and int(r["pulsos"]) < 1:
		_anota("ᚱ suelta su Pulso3D", "%s (momento %s)" % [et, h.momento_de("raido")])
	# --- cada flecha recorre ≥ 80 % o acaba en un obstáculo ---
	if rama == "proyectil":
		for v in r["vivos"]:
			var hv: HechizoVivo = v
			if hv.activo:
				_anota("el proyectil acaba (no pasa de MAX_PASOS)", et)
				continue
			var recorrido_cas: float = hv.recorrido / Terreno3D.casilla
			var obstaculo: bool = hv.motivo_fin == "muro" or hv.motivo_fin == "golpe"
			if hv.motivo_fin == "suelo" and recorrido_cas < UMBRAL_ALCANCE * h.distancia_max and not obstaculo:
				_anota("la flecha no cae al suelo antes del %.0f %% de su alcance en llano" % (UMBRAL_ALCANCE * 100.0), "%s: %.2f de %.0f casillas (suelo)" % [et, recorrido_cas, h.distancia_max])
				var clave: String = "%s alcance %.0f m" % [elemento, h.distancia_max]
				_grupos[clave] = int(_grupos.get(clave, 0)) + 1
			elif not obstaculo and hv.motivo_fin != "suelo" and recorrido_cas < UMBRAL_ALCANCE * h.distancia_max:
				_anota("la flecha recorre ≥ 80 % de su alcance", "%s: %.2f de %.0f casillas (%s)" % [et, recorrido_cas, h.distancia_max, hv.motivo_fin])
	# --- ᚷ cambia algo medible respecto al mismo hechizo sin ᚷ ---
	if h.crece > 0.0 and rama == "haz":
		_aviso("ᚷ en un haz no hace nada (ESPEC §3b: «copias, rebotes y crece no cambian el haz») pero cobra tinta y recarga", et)
	elif h.crece > 0.0:
		var sin: Array = combo.filter(func(g: Variant) -> bool: return String(g) != "pulso")
		await _limpiar(r)
		var base: Dictionary = _ejecutar(rune, sin)
		var cambia: bool = int(r["casillas"]) != int(base["casillas"]) or int(r["tandas"]) != int(base["tandas"]) or not is_equal_approx(float(r["t_crece"]), float(base["t_crece"])) \
			or not is_equal_approx(float(r["radio0"]), float(base["radio0"])) or absf(float(r["hora_ultima"]) - float(base["hora_ultima"])) > 0.001
		if not cambia:
			_anota("ᚷ cambia algo medible respecto al mismo hechizo sin ᚷ", et)
		# casillas rasterizadas: ¿ᚷ cambió el reparto de casillas? (lo que de verdad se nota jugando; ver AVISO)
		if rama == "volumen_quieto" and int(r["tandas"]) == int(base["tandas"]) and int(r["casillas"]) == int(base["casillas"]):
			_aviso("ᚷ solo cambia el tiempo de crecimiento y el VFX: el volumen nunca llega a cruzar una casilla (semieje < 1 m)", et)
		await _limpiar(base)
		return
	await _limpiar(r)
	return


func _resumen(n_combos: int, seg: float) -> void:
	print("ejecutados: %d hechizos en %.1f s" % [_ejecutados, seg])
	var criterios: Array = ["casillas > 0", "el sólido de 2 niveles se rechaza (casillas = 0)", "copias vistas == copias (volumen)", "copias vistas == copias (proyectil)",
		"solidez → SolidezV2 (una por manifestación)", "ᚱ suelta su Pulso3D", "el proyectil acaba (no pasa de MAX_PASOS)",
		"la flecha no cae al suelo antes del %.0f %% de su alcance en llano" % (UMBRAL_ALCANCE * 100.0), "la flecha recorre ≥ 80 % de su alcance",
		"ᚷ cambia algo medible respecto al mismo hechizo sin ᚷ"]
	_ok("se ejecutaron las %d × 6 + %d × 6 combinaciones" % [n_combos, RECETAS_RAIDO.size()], _ejecutados >= (n_combos + RECETAS_RAIDO.size()) * ELEMENTOS.size(), "%d" % _ejecutados)
	for crit in criterios:
		var n: int = int(_tipos.get(crit, 0))
		_ok("%s (en %d casos)" % [crit, n], n == 0, "" if n == 0 else "p. ej. " + str(_ejemplos.get(crit, [])))
	if not _grupos.is_empty():
		print("      flechas que caen al suelo antes de tiempo, por elemento y alcance: %s" % str(_grupos))
	for aviso in _avisos:
		print("AVISO %s: %d casos · p. ej. %s" % [aviso, int(_avisos[aviso]), str(_ejemplos_aviso.get(aviso, []))])


# =====================================================================================================
#  Las reglas nuevas del 24/10 (una a una, con números)
# =====================================================================================================

func _reglas_nuevas(runes: Dictionary) -> void:
	var fuego: RuneData = runes["fire"]
	var cas: float = Terreno3D.casilla
	# --- A1 · ᚠ en el proyectil: copias hermanas en abanico de `dispersion` en total, separadas `separacion` ---
	for n_rep in [0, 1, 2, 3]:
		var combo: Array = ["flecha"] + _veces("repeticion", n_rep)
		var r: Dictionary = _ejecutar(fuego, combo, false)
		var h: Hechizo = r["h"]
		var vivos: Array = r["vivos"]
		_ok("A1 ᚠ×%d + flecha: salen %d proyectiles (los que dice `copias`)" % [n_rep, h.copias], vivos.size() == h.copias and int(r["casillas"]) == h.copias, "vivos %d · casillas %d" % [vivos.size(), int(r["casillas"])])
		if vivos.size() > 1:
			var primero: Vector3 = (vivos[0] as HechizoVivo).v.normalized()
			var ultimo: Vector3 = (vivos[vivos.size() - 1] as HechizoVivo).v.normalized()
			var abre: float = rad_to_deg(primero.angle_to(ultimo))
			_ok("A1 ᚠ×%d: el abanico abre `dispersion` grados EN TOTAL (%.1f° de %.1f°)" % [n_rep, abre, h.dispersion], absf(abre - h.dispersion) < 0.5, "%.2f°" % abre)
			var separados: bool = true
			for i in range(vivos.size()):
				for j in range(i + 1, vivos.size()):
					separados = separados and ((vivos[i] as HechizoVivo).p.distance_to((vivos[j] as HechizoVivo).p) > h.separacion * cas * 0.5)
			_ok("A1 ᚠ×%d: las copias nacen separadas de lado (≥ la mitad de `separacion` m)" % n_rep, separados)
			var mismo_golpe: bool = true
			for v in vivos:
				mismo_golpe = mismo_golpe and (v as HechizoVivo).h == h
			_ok("A1 ᚠ×%d: todas comparten el mismo Hechizo (el mismo golpe) y un solo linaje (%d vivos)" % [n_rep, (vivos[0] as HechizoVivo).linaje.vivos], mismo_golpe and (vivos[0] as HechizoVivo).linaje.vivos == vivos.size())
		await _limpiar(r)
	# el tope de vivos: el lanzamiento entero no pasa de MAX_VIVOS aunque se pidan más copias
	_montar()
	var muchas: Hechizo = Hechizo.construir(fuego, {"flecha": 1}, 1.0).con({"copias": 8})
	var lleno := HechizoVivo.Linaje.new()
	lleno.vivos = Hechizo.MAX_VIVOS - 3
	var vm: HechizoVivo = HechizoVivo.crear(muchas, _origen_de(muchas), Vector3.RIGHT, _l, lleno, {}, true)
	_ok("A1 respeta MAX_VIVOS: con 3 plazas libres de 8 copias salen 3 (%d)" % _vivos().size(), _vivos().size() == 3 and lleno.vivos == Hechizo.MAX_VIVOS and vm.casillas == 3)
	await _limpiar({"vivos": _vivos()})
	# --- A1b · ᚠ en un volumen quieto: ᚠ×1 → 2 casillas distintas, ᚠ×3 → 4 ---
	for n_rep in [0, 1, 2, 3]:
		var rv: Dictionary = _ejecutar(fuego, _veces("repeticion", n_rep), false)
		var copias_esperadas: int = n_rep + 1
		var celdas_distintas: int = int(rv["casillas"])
		_ok("A1b esfera + ᚠ×%d: %d copias ocupan %d casillas distintas (y %d tandas con su centro)" % [n_rep, copias_esperadas, celdas_distintas, int(rv["sitios"])], celdas_distintas == copias_esperadas and int(rv["sitios"]) == copias_esperadas)
		await _limpiar(rv)
	# también con la mano en una casilla cualquiera (no en el centro) y en diagonal: el reparto par no depende de dónde esté el origen
	var mal_pares: int = 0
	for dx in [0.0, 0.17, 0.5, 0.83]:
		for dy in [0.0, 0.31, 0.5, 0.99]:
			for dir in [Vector3.RIGHT, Vector3(0.0, 0.0, 1.0)]:
				_montar()
				var hp: Hechizo = Hechizo.construir(fuego, {"repeticion": 1}, 1.0)
				var o := Vector3((float(ORIGEN_C.x) + dx) * cas, 0.0, (float(ORIGEN_C.y) + dy) * cas)
				var vp: HechizoVivo = HechizoVivo.crear(hp, o, dir, _l, null, {}, true)
				if vp.casillas != 2:
					mal_pares += 1
				vp.queue_free()
	_ok("A1b ᚠ×1 da 2 casillas con la mano en 16 sitios distintos de la casilla y en dos direcciones (fallos %d)" % mal_pares, mal_pares == 0)
	# --- A2 · la flecha de tierra y de hielo llega a su alcance (impulso_salida) y sigue haciendo lo suyo donde cae ---
	await _flechas_de_tierra_y_hielo(runes)
	# --- A3 · el proyectil se para en una SolidezV2 de otro hechizo ---
	await _solidez_y_proyectil(runes)
	# --- A4 · ᚷ en m/s de radio ---
	await _crece_en_metros(runes)


## A2 (auditoría D-2): con gravedad 1 y sin `impulso_salida`, la flecha de tierra y de hielo caía al suelo a 0,70 casillas de las 2 de su alcance. Ahora lleva el impulso del agua adaptado a su gravedad.
## Se mide con la mano a la altura de los pies del esqueleto (0,2 u), a la de la jugadora (0,4 u) y a la de siempre (0,9 u). La tierra tiene que seguir levantando su bloque donde cae y el hielo helando.
func _flechas_de_tierra_y_hielo(runes: Dictionary) -> void:
	var cas: float = Terreno3D.casilla
	for elemento in ["earth", "ice"]:
		var rune: RuneData = runes[elemento]
		_ok("A2 %s: el .tres trae `impulso_salida` (%.2f m/s) y gravedad %.1f" % [elemento, float(Hechizo.construir(rune, {}, 1.0).impulso_salida), Hechizo.construir(rune, {}, 1.0).gravedad], Hechizo.construir(rune, {}, 1.0).impulso_salida > 0.0)
		for mano_u in [0.2, 0.4, Hechizo.ALTURA_MANO_U]:
			_montar()
			var h: Hechizo = Hechizo.construir(rune, {"flecha": 1}, 1.0)
			h.altura_salida = mano_u / cas
			var v: HechizoVivo = HechizoVivo.crear(h, _origen_de(h), Vector3.RIGHT, _l, null, {}, true)
			_correr([v])
			var rec: float = v.recorrido / cas
			_ok("A2 %s, mano a %.1f u: la flecha de 2 m llega a %.2f casillas y acaba por «alcance» (motivo «%s»)" % [elemento, mano_u, rec, v.motivo_fin], v.motivo_fin == "alcance" and rec >= h.distancia_max - 0.05)
			var fin: Vector2i = Terreno3D.celda_de(v.p)
			if mano_u == Hechizo.ALTURA_MANO_U:
				if elemento == "earth":
					_ok("A2 earth: …y construye su bloque donde cae (la casilla %s sube a altura %d)" % [str(fin), Lanzador3D.altura_en(fin)], Lanzador3D.altura_en(fin) >= 1)
				else:
					var helado: bool = false
					for marca in _m.marcas:
						helado = helado or (String(marca[0]) == "hielo" and marca[1] == fin)
					_ok("A2 ice: …y hiela donde cae (estado de suelo «hielo» en %s: %s; altura %d)" % [str(fin), str(helado), Lanzador3D.altura_en(fin)], helado and Lanzador3D.altura_en(fin) >= 1)
			await _limpiar({"vivos": _vivos()})


## Un muro con solidez ya levantado y una flecha que viaja contra él.
func _solidez_y_proyectil(runes: Dictionary) -> void:
	var fuego: RuneData = runes["fire"]
	var cas: float = Terreno3D.casilla
	var muro_c: Vector2i = ORIGEN_C + Vector2i(2, 0)
	for caso in ["sin rebote", "con rebote", "muro que refleja"]:
		_montar()
		var combo_muro: Array = ["barrera"] if caso != "muro que refleja" else ["barrera", "rebote"]
		var hm: Hechizo = Hechizo.construir(fuego, _contadores(combo_muro), 1.0)
		var vm: HechizoVivo = HechizoVivo.crear(hm, Lanzador3D.centro_de(muro_c, 0.0), Vector3.RIGHT, _l, null, {}, true)
		_ok("A3 [%s] el muro existe: una SolidezV2 en la casilla %s" % [caso, str(muro_c)], _l._solideces_v2.size() == 1 and (_l._solideces_v2[0] as Lanzador3D.SolidezV2).celdas.has(muro_c), "%d" % _l._solideces_v2.size())
		var zonas_antes: int = _l._zonas_v2.size()                 # el muro de fuego ya trae su propia zona de llamas: lo que cuenta es la que deja la flecha al chocar
		var flecha: Hechizo = Hechizo.construir(fuego, {"flecha": 3}, 1.0).con({"gravedad": 0.0})            # fuego: sin gravedad, recto; alcance 4 m
		if caso == "con rebote":
			flecha.con({"rebotes": 1})
		var fv: HechizoVivo = HechizoVivo.crear(flecha, Lanzador3D.centro_de(ORIGEN_C, 0.0), Vector3.RIGHT, _l, null, {}, true)
		var x_max: float = fv.p.x
		var pasos: int = 0
		while fv.activo and pasos < MAX_PASOS:
			fv.paso(DT)
			x_max = maxf(x_max, fv.p.x)
			pasos += 1
		var tope: float = float(muro_c.x) * cas                  # el borde izquierdo de la casilla del muro
		if caso == "sin rebote":
			_ok("A3 [%s] la flecha se PARA en el muro (motivo «muro», no pasa del borde de su casilla: x máx %.2f u de %.2f)" % [caso, x_max, tope + cas], fv.motivo_fin == "muro" and x_max < tope + cas * 0.5, "motivo %s" % fv.motivo_fin)
			_ok("A3 [%s] y aplica su materia donde choca (una zona de fuego más: %d → %d)" % [caso, zonas_antes, _l._zonas_v2.size()], _l._zonas_v2.size() == zonas_antes + 1)
		elif caso == "con rebote":
			_ok("A3 [%s] la flecha gasta su rebote y vuelve hacia atrás (rebotes usados %d, vx %.2f)" % [caso, fv.rebotes_usados, fv.v.x], fv.rebotes_usados == 1 and (fv.v.x < 0.0 or fv.motivo_fin != ""), "motivo %s" % fv.motivo_fin)
		else:
			_ok("A3 [%s] la flecha SIN rebotes propios es devuelta una vez por el muro que refleja (vx %.2f, sin gastar rebote: %d)" % [caso, fv.v.x, fv.rebotes_usados], fv.v.x < 0.0 and fv.rebotes_usados == 0 and fv._reflejado)
		await _limpiar({"vivos": _vivos()})
	# barrera + flecha: el proyectil levanta su muro al pararse y sus hermanas NO chocan con él
	_montar()
	var bf: Hechizo = Hechizo.construir(fuego, {"barrera": 1, "flecha": 1, "repeticion": 1}, 1.0).con({"gravedad": 0.0, "dispersion": 0.0, "separacion": 0.0})
	var o_bf: Vector3 = _origen_de(bf)
	var vbf: HechizoVivo = HechizoVivo.crear(bf, o_bf, Vector3.RIGHT, _l, null, {}, true)
	var hermanos: Array = _vivos()
	_correr(hermanos)
	var todos_alcance: bool = true
	for hv in hermanos:
		todos_alcance = todos_alcance and (hv as HechizoVivo).motivo_fin == "alcance"
	_ok("A3 barrera + flecha + ᚠ: las 2 copias llegan a su alcance sin chocar con el muro que la primera levantó (motivos %s, %d solideces)" % [str(hermanos.map(func(x: Variant) -> String: return (x as HechizoVivo).motivo_fin)), _l._solideces_v2.size()],
		todos_alcance and _l._solideces_v2.size() == 2 and vbf.casillas == 2)
	await _limpiar({"vivos": hermanos})


## ᚷ: m/s de radio.
func _crece_en_metros(runes: Dictionary) -> void:
	var fuego: RuneData = runes["fire"]
	# la fórmula de la ESPEC §1.3
	for caso in [[0.5, 1.1], [1.5, 1.1], [0.5, 0.35], [1.0, 2.0]]:
		var crece: float = caso[0]
		var semieje: float = caso[1]
		var h: Hechizo = Hechizo.construir(fuego, {}, 1.0).con({"crece": crece, "semiejes.x": semieje, "semiejes.z": semieje})
		_montar()
		var v: HechizoVivo = HechizoVivo.crear(h, _origen_de(h), Vector3.RIGHT, _l, null, {}, true)
		var esperado: float = (semieje - semieje * h.escala_nace) / crece
		_ok("A4 crece %.1f m/s con semieje %.2f m: tarda (s − s·escala_nace)/crece = %.3f s (mide %.3f)" % [crece, semieje, esperado, v.tiempo_crecimiento], absf(v.tiempo_crecimiento - esperado) < 0.001)
		await _limpiar({"vivos": _vivos()})
	# a doble velocidad de crecimiento, la mitad de tiempo; a doble tamaño, el doble (ya no es igual para todos los tamaños)
	var rapido: float = HechizoVivo.tiempo_de_crecer(1.0, 0.3, 1.0)
	var lento: float = HechizoVivo.tiempo_de_crecer(0.5, 0.3, 1.0)
	_ok("A4 el doble de crece, la mitad de tiempo (%.2f s y %.2f s)" % [rapido, lento], absf(lento - 2.0 * rapido) < 0.0001)
	_ok("A4 el doble de semieje, el doble de tiempo (antes tardaba lo mismo): %.2f s y %.2f s" % [HechizoVivo.tiempo_de_crecer(0.5, 0.3, 1.0), HechizoVivo.tiempo_de_crecer(0.5, 0.3, 2.0)], absf(HechizoVivo.tiempo_de_crecer(0.5, 0.3, 2.0) - 2.0 * HechizoVivo.tiempo_de_crecer(0.5, 0.3, 1.0)) < 0.0001)
	# un volumen grande: vuelve a rasterizar casillas cuando su radio cruza una casilla nueva, y acaba con las mismas que sin crecer
	var grande: Hechizo = Hechizo.construir(fuego, {}, 1.0).con({"crece": 0.5, "semiejes.x": 2.5, "semiejes.z": 0.1})
	_montar()
	var o: Vector3 = Lanzador3D.centro_de(ORIGEN_C, 0.0)
	var vg: HechizoVivo = HechizoVivo.preparar(grande, _l)
	var evs: Array = vg.eventos_de(grande.geo(), Vector2(o.x, o.z), Vector2.RIGHT)
	var sin_crecer: Hechizo = grande.copiar().con({"crece": 0.0})
	_montar()
	var vs: HechizoVivo = HechizoVivo.preparar(sin_crecer, _l)
	var evs0: Array = vs.eventos_de(sin_crecer.geo(), Vector2(o.x, o.z), Vector2.RIGHT)
	var celdas_crece: Dictionary = {}
	var horas_crecen: bool = true
	var t_prev: float = -1.0
	for ev in evs:
		horas_crecen = horas_crecen and float((ev as Dictionary)["t"]) >= t_prev
		t_prev = float((ev as Dictionary)["t"])
		for c in (ev as Dictionary)["celdas"]:
			celdas_crece[c] = true
	var celdas_quieto: Dictionary = {}
	for ev in evs0:
		for c in (ev as Dictionary)["celdas"]:
			celdas_quieto[c] = true
	_ok("A4 semieje 2,5 m: sin crecer 1 tanda (%d) y creciendo varias (%d), en orden de tiempo" % [evs0.size(), evs.size()], evs0.size() == 1 and evs.size() >= 3 and horas_crecen)
	_ok("A4 …cada tanda es una casilla nueva (rasteriza al cruzar una) y al final ocupa las mismas casillas que sin crecer (%d y %d)" % [celdas_crece.size(), celdas_quieto.size()], celdas_crece.size() == celdas_quieto.size() and (evs[0] as Dictionary)["celdas"].size() < celdas_quieto.size())
	var t_ult: float = float((evs.back() as Dictionary)["t"])
	_ok("A4 …y la última casilla nace ANTES del tiempo de crecimiento completo (%.2f s de %.2f s)" % [t_ult, vg.tiempo_crecimiento], t_ult <= vg.tiempo_crecimiento + 0.001 and vg.tiempo_crecimiento > 0.0)
	# el proyectil con crece: nace pequeño y crece en vuelo hasta el radio entero de semiejes_vuelo
	for crece in [0.0, 0.5]:
		_montar()
		var pr: Hechizo = Hechizo.construir(fuego, {"flecha": 1}, 1.0).con({"crece": crece, "semiejes.x": 1.0, "semiejes.z": 1.0, "gravedad": 0.0})
		var vp: HechizoVivo = HechizoVivo.crear(pr, _origen_de(pr), Vector3.RIGHT, _l, null, {}, true)
		var pleno: float = maxf(pr.semiejes_vuelo.x, pr.semiejes_vuelo.z) * Terreno3D.casilla
		var r0: float = vp._radio_u
		var t: float = 0.0
		while vp.activo and t < 1.0 and vp._radio_u < pleno:
			vp.paso(DT)
			t += DT
		if crece <= 0.0:
			_ok("A4 proyectil sin ᚷ: el radio de acierto es el entero desde el principio (%.3f u de %.3f)" % [r0, pleno], absf(r0 - pleno) < 0.0001 and vp.tiempo_crecimiento == 0.0)
		else:
			var t_esp: float = HechizoVivo.tiempo_de_crecer(crece, pr.escala_nace, pleno / Terreno3D.casilla)
			_ok("A4 proyectil con ᚷ %.1f: nace al %.0f %% de su radio (%.3f u) y llega al entero (%.3f u) en %.3f s (mide %.3f s)" % [crece, pr.escala_nace * 100.0, r0, pleno, t_esp, t],
				absf(r0 - pleno * pr.escala_nace) < 0.0001 and absf(vp._radio_u - pleno) < 0.0001 and absf(vp.tiempo_crecimiento - t_esp) < 0.001 and absf(t - t_esp) < 2.0 * DT)
		await _limpiar({"vivos": _vivos()})

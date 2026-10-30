extends SceneTree
## H5 (30/10; docs/PLAN_SISTEMA_HECHIZOS.md §3 H5): los cuatro glifos que activan campos del Hechizo que ya existían, sin ventana:
##   godot --headless --fixed-fps 60 --path . --script res://herramientas/prueba_glifos_nuevos.gd
##   ᚦ perforar (perfora +1, tope 3) · ᛃ retorno (retorna = true) · ᚨ buscar (busca +1, tope 3; 30/10: el cono se abre con cada glifo) · retardo = «carga» (+1 s, tope 3, semiejes ×1,2 y potencia ×1,25 por glifo; el proyectil espera quieto y el volumen nace tarde).
## Ninguno tiene muestras grabadas (Pablo las graba con G): se prueban por contadores, no dibujándolos. Mundo falso de 20×20 como el de `prueba_ejecucion_combinaciones`, con enemigos Combate3D
## en fila; el proyectil se avanza a mano (`paso(dt)`) y los golpes se cuentan mirando la vida de cada enemigo en cada paso.

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

const DT: float = 1.0 / 60.0
const LADO: int = 20
const SALIDA: Vector2i = Vector2i(5, 8)
const NUEVOS: Array = ["perforar", "retorno", "buscar", "retardo"]
const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const VIDA: float = 99999.0

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _senales: Array = []
var _fuego: RuneData = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_fuego = load("res://nucleo/fire_rune.tres")
	_datos()
	await _perforar()
	await _retorno()
	await _buscar()
	await _retardo()
	await _parejas()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar(jug_en: Vector2i = Vector2i(2, 2)) -> void:
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
	_jug.position = Lanzador3D.centro_de(jug_en, Terreno3D.y_pies(jug_en))
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	Lanzador3D.montar_agua_sim()
	_senales.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, g: Dictionary, o: Vector3, d: Vector3, props: Dictionary) -> void: _senales.append([estado, el, g, o, d, props]))


func _enemigo(c: Vector2i) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	_m.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, _m, _jug, _l)
	e.set_physics_process(false)
	e.altura = 0.85
	e.congelado = 99.0
	e.health = VIDA
	return e


func _origen(c: Vector2i = SALIDA) -> Vector3:
	return Lanzador3D.centro_de(c, Terreno3D.y_pies(c) + 0.8)


func _hz(glifos: Dictionary, rune: RuneData = null) -> Hechizo:
	return Hechizo.construir(rune if rune != null else _fuego, glifos, 1.0)


func _lanzar(h: Hechizo, dir: Vector3 = Vector3.RIGHT) -> HechizoVivo:
	return HechizoVivo.crear(h, _origen(), dir, _l, null, {}, true)


## Avanza a mano hasta que acabe y cuenta, por enemigo, cuántos pasos le bajaron la vida (= golpes recibidos). Devuelve los golpes de cada uno, en el orden dado.
func _correr_contando(v: HechizoVivo, enemigos: Array, max_pasos: int = 3000) -> Array:
	var golpes: Array = []
	var vidas: Array = []
	for e in enemigos:
		golpes.append(0)
		vidas.append((e as Combate3D).health)
	var n: int = 0
	while v.activo and n < max_pasos:
		v.paso(DT)
		n += 1
		for i in range(enemigos.size()):
			var e: Combate3D = enemigos[i]
			if e.health < float(vidas[i]) - 0.0001:
				golpes[i] = int(golpes[i]) + 1
			vidas[i] = e.health
	return golpes


# =====================================================================================================
#  Los datos: tabla, repertorio, libro
# =====================================================================================================

func _datos() -> void:
	for g in NUEVOS:
		_ok("%s: está en Sigils.GLIFOS, en GestureLibrary.SIGILS/RECORDABLE y en la BIBLIA como «sello»" % g,
			Sigils.GLIFOS.has(g) and GestureLibrary.SIGILS.has(g) and GestureLibrary.RECORDABLE.has(g) and (g == "retardo" or String(GestureLibrary.BIBLIA[g]["uso"]) == "sello"))
		_ok("%s: cuenta para el daño por defecto, tinta 0 y repertorio = su id" % g, Sigils.cuenta_dano(g) and float(Sigils.GLIFOS[g]["tinta"]["tope"]) == 0.0 and Sigils.repertorio_de(g) == g)
	_ok("PNG: perforar (thurisaz) y buscar (ansuz) sí; retorno (jera) no, el libro lo pinta con el trazo a mano", Sigils.GLYPHS.has("perforar") and Sigils.GLYPHS.has("buscar") and Sigils.GLYPHS.has("retardo") and not Sigils.GLYPHS.has("retorno"))
	_ok("thurisaz y ansuz ya no son runas «libres» sueltas de la BIBLIA (son perforar y buscar) y jera es retorno", not GestureLibrary.BIBLIA.has("thurisaz") and not GestureLibrary.BIBLIA.has("ansuz")
		and GestureLibrary.BIBLIA["retorno"]["nombre_runa"] == "jera" and GestureLibrary.BIBLIA["perforar"]["futhark"] == "ᚦ" and GestureLibrary.BIBLIA["buscar"]["futhark"] == "ᚨ")
	_ok("«retardo» ya no está aparcado (Receta3D.APARCADOS)", not Lanzador3D.Receta3D.APARCADOS.has("retardo") and Lanzador3D.Receta3D.APARCADOS.has("atraccion"))
	# los campos y sus topes
	var h1: Hechizo = _hz({"perforar": 1})
	var h5: Hechizo = _hz({"perforar": 5})
	_ok("perforar: perfora 1 con ᚦ, 3 con tres y se queda en 3 (tope) con cinco", h1.perfora == 1 and _hz({"perforar": 3}).perfora == 3 and h5.perfora == 3)
	_ok("retorno: retorna = true con uno y con dos (un segundo ᛃ no hace nada más)", _hz({"retorno": 1}).retorna and _hz({"retorno": 2}).retorna and not _hz({}).retorna
		and _hz({"retorno": 1}).a_diccionario() != null and _hz({"retorno": 2}).busca == _hz({"retorno": 1}).busca)
	_ok("buscar: busca 1 · 2 · 3 (tope con cinco; 30/10, antes 0,5 por glifo y tope 2)", is_equal_approx(_hz({"buscar": 1}).busca, 1.0) and is_equal_approx(_hz({"buscar": 2}).busca, 2.0) and is_equal_approx(_hz({"buscar": 5}).busca, 3.0))
	var c1: Hechizo = _hz({"flecha": 2, "retardo": 1})
	var c3: Hechizo = _hz({"flecha": 2, "retardo": 3})
	var c0: Hechizo = _hz({"flecha": 2})
	_ok("carga (retardo): +1 s, semiejes ×1,2^n y potencia ×1,25^n (30/10); el alcance no cambia", is_equal_approx(c1.retardo, 1.0) and is_equal_approx(c3.retardo, 3.0) and is_equal_approx(c1.semieje_x, c0.semieje_x * 1.2) and is_equal_approx(c3.semieje_y, c0.semieje_y * pow(1.2, 3.0)) and is_equal_approx(c1.potencia, 1.25) and is_equal_approx(c3.potencia, pow(1.25, 3.0)) and is_equal_approx(c3.distancia_max, c0.distancia_max), "x %.3f→%.3f · G %.3f" % [c0.semieje_x, c3.semieje_x, c3.potencia])
	_ok("carga sin flecha no cuenta como «viaja» ni quita el haz (no toca distancia_max): propiedades iguales y nombre «carga»", not _hz({"retardo": 2}).propiedades_usadas().has("viaja") and _hz({"retardo": 2}).distancia_max == 0.0 and Sigils.nombre_visible("retardo") == "carga" and Sigils.cuenta_dano("retardo"))
	_ok("retardo: 1 s · 2 s · 3 s (tope con cinco)", is_equal_approx(_hz({"retardo": 1}).retardo, 1.0) and is_equal_approx(_hz({"retardo": 2}).retardo, 2.0) and is_equal_approx(_hz({"retardo": 5}).retardo, 3.0))
	_ok("glifos_hasta_tope: perforar 3 · buscar 3 · retardo 3", Sigils.glifos_hasta_tope("perforar") == 3 and Sigils.glifos_hasta_tope("buscar") == 3 and Sigils.glifos_hasta_tope("retardo") == 3)
	_ok("recargas: perforar 1,5 · retorno 2,0 · buscar 1,5 · retardo 1,0 (+0,5 por glifo repetido)", is_equal_approx(Sigils.cooldown_v2({"perforar": 1}), 1.5) and is_equal_approx(Sigils.cooldown_v2({"retorno": 1}), 2.0)
		and is_equal_approx(Sigils.cooldown_v2({"buscar": 2}), 2.0) and is_equal_approx(Sigils.cooldown_v2({"retardo": 1}), 1.0))
	# nada de lo existente cambia: el hechizo sin glifos nuevos es el de siempre
	var f: Hechizo = _hz({"flecha": 2})
	_ok("una flecha sin glifos nuevos no perfora, no vuelve, no busca ni espera", f.perfora == 0 and not f.retorna and f.busca == 0.0 and f.retardo == 0.0)
	# momentos
	var todos: Hechizo = _hz({"perforar": 1, "retorno": 1, "buscar": 1, "retardo": 1, "flecha": 1})
	_ok("momentos: perforar continuo · retorno final · buscar continuo · retardo inicio (sin acción: no disparan nada propio)",
		todos.momento_de("perforar") == "continuo" and todos.momento_de("retorno") == "final" and todos.momento_de("buscar") == "continuo" and todos.momento_de("retardo") == "inicio" and todos.acciones_en("inicio").is_empty())
	# repertorio: las progresiones de pruebas los dan; la del juego normal no
	var prog: Dictionary = Lanzador3D.PROGRESIONES
	for k in ["todo", "pruebas"]:
		var gl: Array = prog[k]["glifos"]
		_ok("progresión «%s» incluye los cuatro" % k, gl.has("perforar") and gl.has("retorno") and gl.has("buscar") and gl.has("retardo"))
	for k in ["nivel1", "bosque", "barrera", "gruta"]:
		var gl2: Array = prog[k]["glifos"]
		_ok("progresión «%s» NO los da todavía (Pablo decide cuándo se ganan)" % k, not (gl2.has("perforar") or gl2.has("retorno") or gl2.has("buscar") or gl2.has("retardo")))
	Repertoire.activate_all()
	_ok("Repertoire.activate_all() los activa", Repertoire.sigil_active("perforar") and Repertoire.sigil_active("retorno") and Repertoire.sigil_active("buscar") and Repertoire.sigil_active("retardo"))
	# la receta del libro: ya no avisa «Aún sin uso» por retardo
	var receta := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for g in NUEVOS:
		receta.apply(g)
	_ok("la receta acepta los cuatro sin ignorar ninguno (ni «Aún sin uso»)", receta.ignorados.is_empty() and int(receta.contadores.get("retardo", 0)) == 1, str(receta.contadores))


# =====================================================================================================
#  ᚦ perforar
# =====================================================================================================

func _perforar() -> void:
	# fila de enemigos a una casilla de distancia en el camino de la flecha (alcance 6: flecha ×5)
	for n_perf in [0, 1, 3]:
		_montar()
		var fila: Array = []
		for x in range(7, 12):
			fila.append(_enemigo(Vector2i(x, 8)))
		var v: HechizoVivo = _lanzar(_hz({"flecha": 5, "perforar": n_perf}))
		var golpes: Array = _correr_contando(v, fila)
		var total: int = 0
		var tocados: int = 0
		for gcount in golpes:
			total += int(gcount)
			tocados += 1 if int(gcount) > 0 else 0
		var esperados: int = n_perf + 1
		_ok("perforar×%d + flecha: atraviesa %d y se para en el %dº (golpes %s, golpes_dados %d, motivo «%s»)" % [n_perf, n_perf, esperados, str(golpes), v.golpes_dados, v.motivo_fin],
			tocados == esperados and total == esperados and v.golpes_dados == esperados and v.motivo_fin == "golpe" and int(golpes[esperados - 1]) == 1 and (esperados >= golpes.size() or int(golpes[esperados]) == 0))
		await _limpiar(v)
	# sin enemigos suficientes: sigue hasta su alcance
	_montar()
	var dos: Array = [_enemigo(Vector2i(7, 8)), _enemigo(Vector2i(9, 8))]
	var v2: HechizoVivo = _lanzar(_hz({"flecha": 5, "perforar": 3}))
	var g2: Array = _correr_contando(v2, dos)
	_ok("perforar×3 con solo dos enemigos: hiere a los dos y sigue hasta el alcance (motivo «%s»)" % v2.motivo_fin, g2 == [1, 1] and v2.motivo_fin == "alcance")
	await _limpiar(v2)


# =====================================================================================================
#  ᛃ retorno
# =====================================================================================================

func _retorno() -> void:
	# contra un enemigo SIN perforar: la ida se para en el golpe, da la vuelta desde ahí y no vuelve a rozarlo (queda en el borde de su radio): UN golpe, y vuelve a la mano
	_montar(Vector2i(4, 8))
	var e0: Combate3D = _enemigo(Vector2i(8, 8))
	var v0: HechizoVivo = _lanzar(_hz({"flecha": 5, "retorno": 1}))
	var vio0: bool = false
	var vida_prev0: float = e0.health
	var golpes0: int = 0
	var n0: int = 0
	while v0.activo and n0 < 3000:
		v0.paso(DT)
		n0 += 1
		vio0 = vio0 or v0.volviendo
		if e0.health < vida_prev0 - 0.0001:
			golpes0 += 1
		vida_prev0 = e0.health
	_ok("retorno + flecha contra un enemigo: la ida se para en el golpe, da la vuelta (volviendo) y se recoge (motivo «%s», %d golpe)" % [v0.motivo_fin, golpes0], vio0 and golpes0 == 1 and v0.motivo_fin == "retorno")
	await _limpiar(v0)
	# con perforar la ida atraviesa al enemigo, llega a su alcance, vuelve y lo golpea OTRA vez: una en la ida y otra en la vuelta
	_montar(Vector2i(4, 8))
	var e: Combate3D = _enemigo(Vector2i(8, 8))
	var v: HechizoVivo = _lanzar(_hz({"flecha": 5, "perforar": 1, "retorno": 1}))
	var golpes: int = 0
	var golpes_ida: int = 0
	var vida_prev: float = e.health
	var n: int = 0
	while v.activo and n < 3000:
		var era_vuelta: bool = v.volviendo
		v.paso(DT)
		n += 1
		if e.health < vida_prev - 0.0001:
			golpes += 1
			golpes_ida += 0 if era_vuelta else 1
		vida_prev = e.health
	_ok("retorno + perforar + flecha: golpea dos veces al mismo enemigo, una en la ida y otra en la vuelta (%d en la ida, %d en total) y acaba «%s»" % [golpes_ida, golpes, v.motivo_fin],
		golpes == 2 and golpes_ida == 1 and v.motivo_fin == "retorno")
	await _limpiar(v)
	# sin enemigo: llega a su alcance, vuelve y se recoge en la mano
	_montar(Vector2i(4, 8))
	var v2: HechizoVivo = _lanzar(_hz({"flecha": 2, "retorno": 1}))
	var max_x: float = v2.p.x
	var n2: int = 0
	while v2.activo and n2 < 3000:
		v2.paso(DT)
		max_x = maxf(max_x, v2.p.x)
		n2 += 1
	_ok("retorno + flecha sin enemigos: va a su alcance (3 casillas, %.2f u), vuelve y se recoge (motivo «%s»)" % [max_x - _origen().x, v2.motivo_fin], v2.motivo_fin == "retorno" and absf((max_x - _origen().x) - 3.0 * Terreno3D.casilla) < 0.3)
	await _limpiar(v2)
	# dos ᛃ = uno
	_montar(Vector2i(4, 8))
	var e3: Combate3D = _enemigo(Vector2i(8, 8))
	var v3: HechizoVivo = _lanzar(_hz({"flecha": 5, "perforar": 1, "retorno": 2}))
	var g3: Array = _correr_contando(v3, [e3])
	_ok("retorno×2 hace lo mismo que retorno×1 (dos golpes, no cuatro): %s" % str(g3), g3 == [2] and v3.motivo_fin == "retorno")
	await _limpiar(v3)
	# 30/10 (decisión de Pablo): ᛃ sin flecha = «vuelve a la mano»: al acabar, el elemento se aplica también en la casilla del lanzador (quieto: al expirar; haz: al nacer). Sin ᛃ, esa casilla no cambia.
	var casilla_j: Vector2i = Vector2i(4, 8)
	var agua_total: Dictionary = {}                 # el agua no marca casillas: se mide el volumen que echa a AguaSim
	for caso in [["fire", {"retorno": 1}, true], ["fire", {}, false], ["water", {"linea_x": 1, "retorno": 1}, true], ["water", {"linea_x": 1}, false]]:
		_montar(casilla_j)
		var rn: RuneData = load("res://nucleo/%s_rune.tres" % caso[0])
		var q: HechizoVivo = _lanzar(_hz(caso[1], rn), Vector3.RIGHT)
		_ok("retorno sin flecha (%s %s): no es un proyectil y nace (no falla ni se cuelga)" % [caso[0], str(caso[1])], not q.proyectil and q.casillas > 0)
		var antes_m: int = 0
		for mc in _m.marcas:
			antes_m += 1 if (mc as Array)[1] == casilla_j else 0
		var vive: float = maxf(q.h.persiste, 0.0) + q.h.permanencia + 0.5
		var es_haz: bool = q.h.haz
		var t_e: float = 0.0
		while t_e < (0.3 if es_haz else vive):
			await create_timer(0.1).timeout
			t_e += 0.1
		var tras_m: int = 0
		for mc in _m.marcas:
			tras_m += 1 if (mc as Array)[1] == casilla_j else 0
		if caso[0] == "water":
			agua_total[bool(caso[2])] = q.retornos_a_mano if is_instance_valid(q) else 0
		else:
			_ok("retorno sin flecha (%s %s): %s en la casilla del lanzador (marcas %d → %d)" % [caso[0], str(caso[1]), "se aplica" if bool(caso[2]) else "no se aplica", antes_m, tras_m], (tras_m > antes_m) == bool(caso[2]))
		if is_instance_valid(q):
			await _limpiar(q)
	_ok("retorno sin flecha (agua + ᛁ, haz): aplica el agua también en la casilla del lanzador (%d veces con ᛃ y %d sin ᛃ)" % [int(agua_total.get(true, -1)), int(agua_total.get(false, -1))], int(agua_total.get(true, -1)) == 1 and int(agua_total.get(false, -1)) == 0)


# =====================================================================================================
#  ᚨ buscar
# =====================================================================================================

func _buscar() -> void:
	# a 30°: dx = 4, dz = 2 casillas del origen (26,6°) y a menos de 6 casillas
	_montar()
	var cerca: Combate3D = _enemigo(Vector2i(9, 10))
	var sin: HechizoVivo = _lanzar(_hz({"flecha": 4}))
	var g_sin: Array = _correr_contando(sin, [cerca])
	_ok("flecha sola: pasa de largo del enemigo a 27° (%s, motivo «%s»)" % [str(g_sin), sin.motivo_fin], g_sin == [0] and sin.motivo_fin != "golpe")
	await _limpiar(sin)
	for n_b in [1, 2]:
		_montar()
		var e: Combate3D = _enemigo(Vector2i(9, 10))
		var v: HechizoVivo = _lanzar(_hz({"flecha": 4, "buscar": n_b}))
		var dir0: Vector3 = v.v.normalized()
		var giro_max: float = 0.0
		var golpes: int = 0
		var vida_prev: float = e.health
		var n: int = 0
		while v.activo and n < 3000:
			v.paso(DT)
			n += 1
			giro_max = maxf(giro_max, dir0.angle_to(v.v.normalized()))
			if e.health < vida_prev - 0.0001:
				golpes += 1
			vida_prev = e.health
		_ok("buscar×%d + flecha: gira hacia el enemigo a 27° (giro máx %.0f°) y lo alcanza (golpes %d, motivo «%s»)" % [n_b, rad_to_deg(giro_max), golpes, v.motivo_fin], giro_max > deg_to_rad(5.0) and golpes == 1 and v.motivo_fin == "golpe")
		await _limpiar(v)
	# a 124° (detrás, fuera del cono de 60°): no lo atrae
	_montar()
	var detras: Combate3D = _enemigo(Vector2i(3, 11))
	var c: HechizoVivo = _lanzar(_hz({"flecha": 4, "buscar": 4}))
	var dir0c: Vector3 = c.v.normalized()
	var g_c: Array = _correr_contando(c, [detras])
	_ok("buscar×4 (busca 3, cono de ±120°) + flecha: un enemigo a 124° (fuera del cono) no lo atrae: sigue recto y no lo golpea (%s)" % str(g_c), g_c == [0] and c.v.normalized().dot(dir0c) > 0.999 and c.motivo_fin != "golpe")
	await _limpiar(c)
	# 30/10 (playtest de Pablo: «un solo ᚨ ya es un imán; más ᚨ, más imán»): enemigo a 2 casillas, a 25° (dentro del cono de 60° de ᚨ×1) y a 90° (solo con ᚨ×2 o más: cono ±90° y ±120°)
	for caso in [[25.0, 0, false], [25.0, 1, true], [90.0, 1, false], [90.0, 3, true], [90.0, 0, false]]:
		_montar()
		var a_grados: float = float(caso[0])
		var n_a: int = int(caso[1])
		var mod := Pj3D.new()
		mod.position = _origen() - Vector3(0.0, 0.8, 0.0) + Vector3(cos(deg_to_rad(a_grados)), 0.0, sin(deg_to_rad(a_grados))) * 2.0 * Terreno3D.casilla
		_m.add_child(mod)
		var lat: Combate3D = Combate3D.equipar(mod, _m, _jug, _l)
		lat.set_physics_process(false)
		lat.altura = 0.85
		lat.congelado = 99.0
		lat.health = VIDA
		var glifos_a: Dictionary = {"flecha": 4}
		if n_a > 0:
			glifos_a["buscar"] = n_a
		var l2: HechizoVivo = _lanzar(_hz(glifos_a))
		var g_l: Array = _correr_contando(l2, [lat])
		_ok("buscar×%d + flecha: un enemigo a 2 casillas y %.0f° %s (%s, motivo «%s»)" % [n_a, a_grados, "lo alcanza" if bool(caso[2]) else "no lo alcanza", str(g_l), l2.motivo_fin], (g_l == [1]) == bool(caso[2]))
		await _limpiar(l2)
	# buscar + volumen quieto: no hay proyectil, no hace nada (se acepta)
	_montar()
	var q: HechizoVivo = _lanzar(_hz({"buscar": 2}))
	_ok("buscar sin flecha: volumen quieto, nada que girar (no falla)", not q.proyectil and q.casillas > 0)
	await _limpiar(q)


# =====================================================================================================
#  retardo
# =====================================================================================================

func _retardo() -> void:
	# proyectil: nace quieto 1 s y luego recorre su alcance (flecha ×3 = 4 casillas)
	for n_r in [1, 2]:
		_montar()
		var v: HechizoVivo = _lanzar(_hz({"flecha": 3, "retardo": n_r}))
		var p0: Vector3 = v.p
		var espera_s: float = float(n_r)
		_ok("retardo×%d + flecha: nace con `espera` = %.1f s y activo" % [n_r, espera_s], is_equal_approx(v.espera, espera_s) and v.activo and v.proyectil)
		var pasos_quieto: int = int(roundf(espera_s / DT))
		var movio: bool = false
		for _i in range(pasos_quieto - 1):
			v.paso(DT)
			movio = movio or v.p.distance_to(p0) > 0.0001
		_ok("retardo×%d: durante %.2f s no se mueve (recorrido %.3f, edad %.3f)" % [n_r, espera_s, v.recorrido, v.edad], not movio and v.recorrido == 0.0 and v.edad == 0.0 and v.golpes_dados == 0)
		for _i in range(4):
			v.paso(DT)
		_ok("retardo×%d: a los %.2f s ya arranca (se movió %.3f u)" % [n_r, espera_s + 2.0 * DT, v.p.distance_to(p0)], v.p.distance_to(p0) > 0.001 and v.espera == 0.0)
		var n: int = 0
		while v.activo and n < 3000:
			v.paso(DT)
			n += 1
		_ok("retardo×%d: luego recorre su alcance (%.2f de 4 casillas, motivo «%s») y vive %.2f s de vuelo" % [n_r, v.recorrido / Terreno3D.casilla, v.motivo_fin, v.edad],
			v.motivo_fin == "alcance" and absf(v.recorrido / Terreno3D.casilla - 4.0) < 0.2)
		await _limpiar(v)
	# un paso grande que se pasa de la espera: lo que sobra ya cuenta como vuelo
	_montar()
	var g: HechizoVivo = _lanzar(_hz({"flecha": 3, "retardo": 1}))
	g.paso(1.5)
	_ok("un paso de 1,5 s con retardo 1: espera 0 y 0,5 s de vuelo (edad %.2f)" % g.edad, g.espera == 0.0 and absf(g.edad - 0.5) < 0.001 and g.recorrido > 0.0)
	await _limpiar(g)
	# sin retardo: arranca ya
	_montar()
	var s: HechizoVivo = _lanzar(_hz({"flecha": 3}))
	var ps: Vector3 = s.p
	s.paso(DT)
	_ok("sin retardo la flecha arranca en el primer paso (como siempre)", s.espera == 0.0 and s.p.distance_to(ps) > 0.0)
	await _limpiar(s)
	# la espera también corre sola, con el reloj de juego (_physics_process): un proyectil NO manual
	_montar()
	var vivo: HechizoVivo = HechizoVivo.crear(_hz({"flecha": 3, "retardo": 1}), _origen(), Vector3.RIGHT, _l, null, {}, false)
	var p_v: Vector3 = vivo.p
	for _i in range(30):
		await physics_frame
	var quieto_medio: bool = vivo.p.distance_to(p_v) < 0.0001 and vivo.espera > 0.0
	for _i in range(60):
		await physics_frame
	_ok("retardo con el reloj de juego: quieto a mitad de la espera y en marcha tras 1,5 s (espera %.2f, se movió %.2f u)" % [vivo.espera, vivo.p.distance_to(p_v)], quieto_medio and vivo.espera == 0.0 and vivo.p.distance_to(p_v) > 0.1)
	await _limpiar(vivo)
	# un enemigo delante: durante la espera NO lo golpea; luego sí
	_montar()
	var e: Combate3D = _enemigo(Vector2i(6, 8))
	var w: HechizoVivo = _lanzar(_hz({"flecha": 3, "retardo": 1}))
	var vida0: float = e.health
	for _i in range(50):
		w.paso(DT)
	var sin_golpe: bool = e.health == vida0
	var n2: int = 0
	while w.activo and n2 < 3000:
		w.paso(DT)
		n2 += 1
	_ok("retardo: no golpea mientras espera y sí después (motivo «%s»)" % w.motivo_fin, sin_golpe and e.health < vida0 and w.motivo_fin == "golpe")
	await _limpiar(w)
	# la previsión NO espera: mismo recorrido con y sin retardo
	_montar()
	var pr0: Dictionary = HechizoVivo.prever(_hz({"flecha": 3}), _l, _origen(), Vector3.RIGHT)
	var pr1: Dictionary = HechizoVivo.prever(_hz({"flecha": 3, "retardo": 2}), _l, _origen(), Vector3.RIGHT)
	_ok("prever: con retardo simula desde que arranca (mismo fin y misma causa que sin retardo)", (pr0["fines"] as Array).size() == 1 and (pr1["fines"] as Array).size() == 1
		and (pr0["fines"][0] as Vector3).distance_to(pr1["fines"][0] as Vector3) < 0.001 and pr0["causas"] == pr1["causas"], str(pr1["causas"]))
	# volumen quieto: como hoy (eventos_de ya sumaba `retardo`)
	var primeras: Array = []
	for n_r in [0, 1, 2]:
		_montar()
		var q: HechizoVivo = _lanzar(_hz({"retardo": n_r, "altura": 1}) if n_r > 0 else _hz({"altura": 1}))
		var t_min: float = INF
		if not _senales.is_empty():
			for ev in ((_senales[0][2] as Dictionary).get("eventos", []) as Array):
				t_min = minf(t_min, float((ev as Dictionary)["t"]))
		primeras.append(t_min)
		_ok("retardo×%d + volumen quieto: primera aparición a %.2f s, no se espera dos veces y hay casillas (%d)" % [n_r, t_min, q.casillas], absf(t_min - float(n_r)) < 0.001 and q.casillas > 0 and q.espera == 0.0)
		await _limpiar(q)
	# retardo + barrera: la barrera (SolidezV2) no existe al lanzar y nace tras el retardo
	_montar()
	var antes: int = _l._solideces_v2.size()
	var b: HechizoVivo = _lanzar(_hz({"retardo": 1, "barrera": 1}))
	var al_lanzar: int = _l._solideces_v2.size() - antes
	await create_timer(1.4).timeout
	var despues: int = _l._solideces_v2.size() - antes
	_ok("retardo×1 + barrera: sin barrera al lanzar (%d) y con ella tras el retardo (%d)" % [al_lanzar, despues], al_lanzar == 0 and despues >= 1)
	await _limpiar(b)


# =====================================================================================================
#  Combinaciones dos a dos con flecha, en fila de enemigos: nada falla y todo acaba
# =====================================================================================================

func _parejas() -> void:
	var casos: int = 0
	var sin_acabar: Array = []
	for i in range(NUEVOS.size()):
		for j in range(i, NUEVOS.size()):
			for e_nombre in ["fire", "water", "ice"]:
				var rune: RuneData = load("res://nucleo/%s_rune.tres" % e_nombre)
				_montar(Vector2i(4, 8))
				var fila: Array = [_enemigo(Vector2i(7, 8)), _enemigo(Vector2i(9, 10)), _enemigo(Vector2i(11, 8))]
				var cont: Dictionary = {"flecha": 4}
				cont[NUEVOS[i]] = int(cont.get(NUEVOS[i], 0)) + 1
				cont[NUEVOS[j]] = int(cont.get(NUEVOS[j], 0)) + 1
				var h: Hechizo = _hz(cont, rune)
				var v: HechizoVivo = _lanzar(h)
				_correr_contando(v, fila)
				casos += 1
				if v.activo:
					sin_acabar.append("%s %s" % [e_nombre, str(cont)])
				await _limpiar(v)
	_ok("combinaciones de dos de los cuatro + flecha (%d casos × 3 elementos): todas acaban y ninguna falla" % casos, sin_acabar.is_empty() and casos == 30, str(sin_acabar))
	# y alguna con las tres a la vez + barrera / ᚱ: lo que salga de los campos, sin excepciones
	for combo in [{"flecha": 3, "perforar": 1, "retorno": 1, "buscar": 1, "retardo": 1}, {"barrera": 1, "perforar": 1, "buscar": 1, "retorno": 1}, {"flecha": 2, "raido": 1, "retorno": 1, "retardo": 1}]:
		_montar(Vector2i(4, 8))
		var fila2: Array = [_enemigo(Vector2i(7, 8)), _enemigo(Vector2i(9, 9))]
		var v2: HechizoVivo = _lanzar(_hz(combo))
		_correr_contando(v2, fila2)
		_ok("mezcla %s: acaba sin fallar (proyectil %s, motivo «%s»)" % [str(combo), str(v2.proyectil), v2.motivo_fin], not v2.activo)
		await _limpiar(v2)


func _limpiar(v: Variant) -> void:
	if is_instance_valid(v) and not (v as Node).is_queued_for_deletion():
		(v as Node).queue_free()
	await process_frame

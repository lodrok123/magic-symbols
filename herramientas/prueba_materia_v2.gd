extends SceneTree
## Prueba de la MATERIA de la receta V2 (R2, 17/10; docs/GLIFOS_RECETA.md §2.3-2.4), sin ventana ni escena. La escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_materia_v2.gd
## Una receta por ESTADO (sólido, líquido, plasma, energía, gas, campo) × cuatro volúmenes: esfera, X×3, Y×2 y Z×3. Comprueba las casillas
## ocupadas, el agua añadida ≈ el volumen, la colisión y lo pisable, el daño, el estado de suelo, el empuje, la ralentización y la señal
## `hechizo_v2`. (R3: la receta V2 es la única; ya no hay interruptor.)

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 16
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var marcas: Array = []                       ## [elemento, celda] de cada _al_impactar (lo que marca el suelo)
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		marcas.append([elemento, Terreno3D.celda_de(punto)])

class ReactivoFalso extends Node3D:
	var golpes: int = 0
	func on_spell_hit(_rune: RuneData, _dir: Vector3 = Vector3.ZERO) -> void:
		golpes += 1

const DT: float = 1.0 / 60.0
const LADO: int = 16
const ORIGEN_C: Vector2i = Vector2i(5, 8)        ## casilla de la mano
const RECETAS: Dictionary = {
	"esfera": [], "X×6": ["linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x"], "Y×8": ["altura", "altura", "altura", "altura", "altura", "altura", "altura", "altura"], "Z×6": ["linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z"],
}
const ELEMENTOS: Dictionary = {"solido": "earth", "liquido": "water", "plasma": "fire", "energia": "lightning", "gas": "wind", "campo": "time"}

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _senales: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	for estado in ELEMENTOS:
		for nombre in RECETAS:
			await _caso(estado, nombre)
	await _hielo()
	await _extras()
	await _vivo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Mundo, jugador y lanzador nuevos para cada caso (Terreno3D es estático: se limpia lo que deja).
func _montar() -> void:
	if _l != null and is_instance_valid(_l):
		_l.free()
	if _m != null and is_instance_valid(_m):
		_m.free()
	if _jug != null and is_instance_valid(_jug):
		_jug.free()
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
	_jug.position = Lanzador3D.centro_de(Vector2i(13, 13), 1.0)
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	_senales.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, g: Dictionary, o: Vector3, d: Vector3, props: Dictionary) -> void: _senales.append([estado, el, g, o, d, props]))


func _receta(glifos: Array) -> Lanzador3D.Receta3D:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for gl in glifos:
		r.apply(String(gl))
	return r


func _origen() -> Vector3:
	return Lanzador3D.centro_de(ORIGEN_C, 0.0)


func _enemigo(c: Vector2i) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, MundoFalso.ALTO)
	_m.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, _m, _jug, _l)
	e.set_physics_process(false)
	e.altura = 0.85
	e.congelado = 99.0                            # que no ande ni ataque: solo mide lo que le hace el hechizo
	return e


func _zona() -> Lanzador3D.ZonaV2:
	var z: Lanzador3D.ZonaV2 = _l._zonas_v2.back()
	z.set_physics_process(false)                  # la avanza la prueba, a mano
	return z


func _caso(estado: String, nombre: String) -> void:
	_montar()
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % ELEMENTOS[estado])      # 20/10: «campo» sale de la runa del tiempo (cinemática): abajo se pide expresamente
	var receta: Lanzador3D.Receta3D = _receta(RECETAS[nombre])
	var g: Dictionary = receta.geo()
	var celdas_esperadas: Array = []
	for c in Lanzador3D.GeometriaV2.celdas(g, Vector2(_origen().x, _origen().z), Vector2.RIGHT, Terreno3D.casilla):
		celdas_esperadas.append(c)
	var niv: int = Lanzador3D.GeometriaV2.niveles(g)
	var et: String = "%s · %s" % [estado, nombre]
	# Una víctima en la casilla de la mano (donde siempre hay volumen) y otra lejos, para plasma/energía/gas/campo.
	var dentro: Combate3D = _enemigo(ORIGEN_C + Vector2i(1, 0)) if celdas_esperadas.has(ORIGEN_C + Vector2i(1, 0)) else _enemigo(ORIGEN_C)
	if estado == "solido" or estado == "liquido":
		dentro.position = Lanzador3D.centro_de(Vector2i(2, 12), MundoFalso.ALTO)       # el sólido no se levanta bajo un enemigo: se aparta
	var fuera: Combate3D = _enemigo(Vector2i(2, 2))
	if estado == "energia":
		# Una cadena de conductores pegada al volumen: la descarga la recorre y llega a quien está en su extremo.
		var ult: Vector2i = ORIGEN_C
		for c in celdas_esperadas:
			if (c as Vector2i).x > ult.x or ((c as Vector2i).x == ult.x and (c as Vector2i).y == ORIGEN_C.y):
				ult = c
		Terreno3D.conductores[ult + Vector2i(1, 0)] = true
		Terreno3D.conductores[ult + Vector2i(2, 0)] = true
		dentro.position = Lanzador3D.centro_de(ult + Vector2i(2, 0), MundoFalso.ALTO)
	var aviso_esperado: bool = estado == "solido" and niv > Jugador3D.MAX_NIVELES_SUBIBLES
	var suelo_esp: float = Terreno3D.y_pies(Terreno3D.celda_de(_origen()))      # ANTES de lanzar: un sólido levanta la casilla del origen
	var n: int = _l._materializar(receta, rune, _origen(), Vector3.RIGHT, rune.cinematico)
	if aviso_esperado:
		_ok("%s: no se lanza (aviso de altura, %d niveles > %d)" % [et, niv, Jugador3D.MAX_NIVELES_SUBIBLES], n == 0 and _senales.is_empty() and Terreno3D.alturas.is_empty() and Lanzador3D.GeometriaV2.aviso_materia(g, rune) != "")
		return
	# La señal para el VFX: una vez, con el estado, el elemento y {x, y, z, celdas, niveles}.
	_ok("%s: emite hechizo_v2 una vez (estado, elemento, g, origen, dir, props; el volumen lleva 9 claves de siempre + viaja, velocidad, permanencia, vida_total, elevacion, separacion, dispersion, gravedad de E2)" % et, _senales.size() == 1 and _senales[0][0] == estado and _senales[0][1] == Objetos.elemento_de(rune) \
		and (_senales[0][2] as Dictionary).keys().size() == 17 and (_senales[0][2]["celdas"] as Array).size() == celdas_esperadas.size() and int(_senales[0][2]["niveles"]) == niv \
		and is_equal_approx(float(_senales[0][2]["z"]), float(g["z"])) and (_senales[0][3] as Vector3).is_equal_approx(_origen()) and (_senales[0][5] as Dictionary).is_empty())
	# T-VFX (155): `persiste` (ya con la calidad), `suelo` (y de los pies bajo el origen) y `eventos` [{t, pos, dir}] de HechizoVivo.eventos_de.
	var sg: Dictionary = _senales[0][2]
	var persiste_esp: float = rune.persiste * Sigils.quality_factor(receta.calidad) if rune.persiste > 0.0 else 0.0
	_ok("%s: la señal lleva `persiste` ya multiplicado por la calidad (%.2f s)" % [et, persiste_esp], sg.has("persiste") and is_equal_approx(float(sg["persiste"]), persiste_esp))
	_ok("%s: la señal lleva `suelo` = y del suelo bajo el origen (%.2f; la mano está a %.2f)" % [et, suelo_esp, _origen().y], sg.has("suelo") and is_equal_approx(float(sg["suelo"]), suelo_esp))
	var evs_ok: bool = sg.has("eventos") and (sg["eventos"] as Array).size() >= 1
	if evs_ok:
		var t_ant: float = -1.0
		for e in (sg["eventos"] as Array):
			evs_ok = evs_ok and e.has("t") and e.has("pos") and e.has("dir") and float(e["t"]) >= t_ant and e["pos"] is Vector2 and e["dir"] is Vector2
			t_ant = float(e["t"])
	_ok("%s: la señal lleva `eventos` [{t, pos, dir}] en orden de tiempo (%d)" % [et, (sg.get("eventos", []) as Array).size()], evs_ok)
	if estado == "liquido":
		var esp_caida: float = minf(0.4 + 0.07 * float(g["y"]), 0.8)
		_ok("%s: t_caida = %.2f s (0,4 + 0,07·semieje_y, máx. 0,8)" % [et, esp_caida], is_equal_approx(float(sg.get("t_caida", -1.0)), esp_caida))
		_ok("%s: el agua NO entra antes de la caída" % et, Terreno3D.agua_sim != null and Terreno3D.agua_sim.volumen_total() < 0.01 * Sigils.volumen_v2(g) * pow(Terreno3D.casilla, 3.0))
		await create_timer(esp_caida + 0.08).timeout
	match estado:
		"solido":
			var todas: bool = true
			var pisables: bool = true
			for c in celdas_esperadas:
				todas = todas and Terreno3D.celda_solida(c as Vector2i, 0) and Terreno3D.altura_en(c as Vector2i) == niv
				pisables = pisables and Terreno3D.pisable(c as Vector2i, 0, true, Jugador3D.MAX_NIVELES_SUBIBLES, false) == rune.pisable
			_ok("%s: %d casillas × %d nivel(es) con colisión (devuelve %d)" % [et, celdas_esperadas.size(), niv, n], todas and n == celdas_esperadas.size() * niv)
			_ok("%s: pisable = RuneData.pisable (%s)" % [et, rune.pisable], pisables)
			_ok("%s: ocupa solo las casillas del volumen" % et, Terreno3D.alturas.size() == celdas_esperadas.size())
			_l._avanzar_caducidades(rune.persiste + 0.1)
			_ok("%s: dura `persiste` (%.0f s) y luego no queda nada" % [et, rune.persiste], Terreno3D.alturas.is_empty())
		"liquido":
			var sim: AguaSim3D = Terreno3D.agua_sim
			var esperado: float = Sigils.volumen_v2(g) * pow(Terreno3D.casilla, 3.0)
			for _i in range(int((HechizoVivo.T_LLENADO_V2 + 0.1) / DT)):
				sim.paso(DT)
			var got: float = sim.volumen_total()
			# A 1,1 s los manantiales ya han echado su parte y se han apagado solos (limitar_fuente). Lo que falta hasta el 100 % no es agua sin echar: es la
			# lámina fina que la propia simulación absorbe mientras el agua se esparce (ABSORBE), de ahí el margen del 10 % por abajo.
			_ok("%s: agua añadida %.2f u³ ≈ volumen del elipsoide %.2f u³ (entre el 75 y el 101 %%: con volúmenes pequeños la lámina que absorbe la simulación pesa más)" % [et, got, esperado], got >= 0.75 * esperado and got <= 1.01 * esperado)
			var apagadas: bool = true
			for c in celdas_esperadas:
				apagadas = apagadas and sim.caudal_en(c as Vector2i) == 0.0 and sim.volumen_restante(c as Vector2i) == INF
			_ok("%s: todos los manantiales echaron su parte y se apagaron solos" % et, apagadas)
			_ok("%s: el agua cae en las casillas del volumen o a su lado" % et, n == celdas_esperadas.size())
		"plasma":
			var vida_ini: float = dentro.vida_max
			_ok("%s: quien entra recibe el golpe (vida %.0f → %.0f)" % [et, vida_ini, dentro.health], dentro.health < vida_ini)
			_ok("%s: quien está lejos no recibe nada" % et, fuera.health == fuera.vida_max)
			var tras_golpe: float = dentro.health
			var z: Lanzador3D.ZonaV2 = _zona()
			z.avanzar(1.0)
			_ok("%s: la zona sigue hiriendo cada pulso (%.0f → %.0f)" % [et, tras_golpe, dentro.health], dentro.health < tras_golpe)
			var marcas_fuego: int = 0
			for mk in _m.marcas:
				marcas_fuego += 1 if String(mk[0]) == "fuego" else 0
			_ok("%s: deja su estado de suelo (`%s`) en cada casilla (%d marcas / %d casillas)" % [et, rune.deja, marcas_fuego, celdas_esperadas.size()], rune.deja == "quemado" and marcas_fuego == celdas_esperadas.size())
			z.avanzar(rune.persiste)
			await process_frame
			_ok("%s: dura `persiste` (%.0f s): la zona desaparece" % [et, rune.persiste], _l._zonas_v2.is_empty())
		"energia":
			_ok("%s: la descarga hiere lo que está en el volumen o en el conductor conectado (vida %.0f → %.0f)" % [et, dentro.vida_max, dentro.health], dentro.health < dentro.vida_max)
			_ok("%s: no hiere a quien no está conectado" % et, fuera.health == fuera.vida_max)
			_ok("%s: es instantánea: no deja zona" % et, _l._zonas_v2.is_empty())
		"gas":
			var z2: Lanzador3D.ZonaV2 = _zona()
			var x0: float = dentro.position.x
			_ok("%s: empuja al entrar (empuje %.1f × FUERZA_EMPUJE)" % [et, rune.empuje], dentro._empuje.length() > 0.0 and dentro._empuje.x > 0.0)
			for _i in range(30):
				z2.avanzar(DT)
				dentro._physics_process(DT)
			_ok("%s: lo arrastra en la dirección de la mirada (+%.2f u en 0,5 s)" % [et, dentro.position.x - x0], dentro.position.x - x0 > 0.2)
			_ok("%s: sin daño (el viento no hiere)" % et, dentro.health == dentro.vida_max and fuera._empuje.length() == 0.0)
			z2.avanzar(rune.persiste)
			await process_frame
			_ok("%s: dura `persiste` (%.1f s)" % [et, rune.persiste], _l._zonas_v2.is_empty())
		"campo":
			_ok("%s: ralentiza a quien está dentro (lento %.2f)" % [et, dentro.lento], dentro.lento > 0.0 and dentro.vel_mult() < 1.0 + 0.0001)
			_ok("%s: no ralentiza a quien está fuera" % et, fuera.lento == 0.0)
			var z3: Lanzador3D.ZonaV2 = _zona()
			z3.avanzar(rune.persiste)
			await process_frame
			_ok("%s: dura `persiste` (%.0f s)" % [et, rune.persiste], _l._zonas_v2.is_empty())


## El hielo: sólido pisable de 6 s que además hiela lo que cubre (`deja`).
func _hielo() -> void:
	_montar()
	var rune: RuneData = load("res://nucleo/ice_rune.tres")
	var receta: Lanzador3D.Receta3D = _receta(["linea_x", "linea_x"])
	var n: int = _l._materializar(receta, rune, _origen(), Vector3.RIGHT)
	var celdas: Array = Lanzador3D.GeometriaV2.celdas(receta.geo(), Vector2(_origen().x, _origen().z), Vector2.RIGHT, Terreno3D.casilla)
	_ok("hielo · X×2: sólido pisable (%d casillas)" % n, n == celdas.size() and Terreno3D.pisable(ORIGEN_C, 0, true, Jugador3D.MAX_NIVELES_SUBIBLES, false))
	var marcas_hielo: int = 0
	for mk in _m.marcas:
		marcas_hielo += 1 if String(mk[0]) == "hielo" else 0
	_ok("hielo · X×2: `deja` helado en cada casilla del suelo (%d)" % marcas_hielo, rune.deja == "helado" and marcas_hielo == celdas.size())
	_l._avanzar_caducidades(5.0)
	_ok("hielo · a los 5 s aún está", not Terreno3D.alturas.is_empty())
	_l._avanzar_caducidades(1.2)
	_ok("hielo · a los 6 s se ha derretido (persiste %.0f)" % rune.persiste, Terreno3D.alturas.is_empty() and is_equal_approx(rune.persiste, 6.0))
	# Un sólido que no cabe en lo que se sube tampoco se lanza con aviso de hielo
	_montar()
	var n2: int = _l._materializar(_receta(["altura", "altura", "altura", "altura", "altura", "altura", "altura", "altura"]), rune, _origen(), Vector3.RIGHT)
	_ok("hielo · Y×2 (3 niveles > %d) no se lanza" % Jugador3D.MAX_NIVELES_SUBIBLES, n2 == 0 and Terreno3D.alturas.is_empty())


## Lo que no es un estado concreto: reactivos que arden, que un estado desconocido cae al más inofensivo, que la tierra de siempre no se toca,
## y que `aviso_receta` conoce el estado.
func _extras() -> void:
	# Un reactivo en la zona de plasma recibe UN golpe (arde), no uno por pulso.
	_montar()
	var fuego: RuneData = load("res://nucleo/fire_rune.tres")
	var r := ReactivoFalso.new()
	r.add_to_group("reactivo3d")
	_m.add_child(r)
	r.position = Lanzador3D.centro_de(ORIGEN_C, 0.0)
	_l._materializar(_receta([]), fuego, _origen(), Vector3.RIGHT)
	var z: Lanzador3D.ZonaV2 = _zona()
	z.avanzar(2.0)
	_ok("plasma · un reactivo en la zona recibe UN golpe en toda la zona (%d)" % r.golpes, r.golpes == 1)
	# Un estado desconocido no rompe nada: se trata como campo.
	_montar()
	var rara: RuneData = fuego.duplicate()
	rara.estado = "inventado"
	var antes: int = _l._zonas_v2.size()
	var n: int = _l._materializar(_receta([]), rara, _origen(), Vector3.RIGHT)
	_ok("un estado desconocido cae a «campo» (señal con estado campo, %d casilla)" % n, _senales.size() == 1 and _senales[0][0] == "campo" and _l._zonas_v2.size() == antes + 1)
	# aviso_receta ve el estado
	_ok("aviso_receta: un sólido de 3 niveles avisa, el agua no", Lanzador3D.aviso_receta(["altura", "altura", "altura", "altura", "altura", "altura", "altura", "altura"], load("res://nucleo/earth_rune.tres")) != "" and Lanzador3D.aviso_receta(["altura", "altura", "altura", "altura", "altura", "altura", "altura", "altura"], load("res://nucleo/water_rune.tres")) == "")
	# La tierra «a mano» (construir_tierra sin opciones V2) sigue siendo un bloque por casilla y entra en el FIFO
	_montar()
	var ok_t: bool = _l.construir_tierra(Vector2i(6, 6)) and _l.bloques_de_tierra() == 1
	_ok("construir_tierra de siempre (1 bloque, cuenta para el tope)", ok_t)
	_montar()
	var cuenta_v2: int = _l._materializar(_receta(["linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z", "linea_z"]), load("res://nucleo/earth_rune.tres"), _origen(), Vector3.RIGHT)
	_ok("tierra V2 no cuenta para el FIFO de MAX_NIVELES_TIERRA (%d bloques V2, %d en el tope)" % [cuenta_v2, _l.bloques_de_tierra()], cuenta_v2 > Lanzador3D.MAX_NIVELES_TIERRA and _l.bloques_de_tierra() == 0)


## HC2 (18/10): el HechizoVivo es el nodo que ejecuta un Hechizo. Nace colgado del lanzador, cumple sus eventos retardados y se borra solo;
## lo que deja en el mundo (zona, solidez, agua) sigue con su vida. `lanzar_hechizo` y `_materializar` dan lo mismo.
func _vivo() -> void:
	_montar()
	var rune: RuneData = load("res://nucleo/water_rune.tres")
	var receta: Lanzador3D.Receta3D = _receta(["linea_x", "linea_x", "linea_x", "linea_x", "linea_z", "linea_z", "flecha"])
	var hz: Hechizo = receta.hechizo(rune)
	_ok("HC2: Receta3D.hechizo trae el elemento y los glifos", hz.fuente == rune and hz.glifos == receta.contadores and hz.elemento == "agua")
	var geo: Dictionary = receta.geo()
	var gh: Dictionary = hz.geo()
	var igual: bool = true
	for k in ["x", "y", "z", "nombre", "viaja", "y_tope"]:
		igual = igual and str(gh[k]) == str(geo[k])
		if str(gh[k]) != str(geo[k]):
			print("  dif geo ", k, ": ", gh[k], " ≠ ", geo[k])
	_ok("HC2: Hechizo.geo() = GeometriaV2.evaluar (x, y, z, nombre, viaja, y_tope)", igual and gh["props"] == geo["props"])
	var n: int = _l.lanzar_hechizo(hz, _origen(), Vector3.RIGHT)
	var hijos: int = 0
	for c in _l.get_children():
		hijos += 1 if c is HechizoVivo else 0
	_ok("HC2: con eventos retardados (viaja) el HechizoVivo sigue vivo tras nacer (%d)" % hijos, n > 0 and hijos == 1)
	await create_timer(float(6) / Hechizo.VELOCIDAD_VIAJE_DEFECTO + 1.4).timeout
	hijos = 0
	for c in _l.get_children():
		hijos += 1 if c is HechizoVivo else 0
	_ok("HC2: cumplidos todos sus eventos, se borra solo (%d)" % hijos, hijos == 0)
	_montar()
	var n2: int = _l._materializar(receta, rune, _origen(), Vector3.RIGHT)
	_ok("HC2: _materializar(receta) = lanzar_hechizo(receta.hechizo) (%d = %d)" % [n2, n], n2 == n)
	# sin eventos retardados nace y se borra en el mismo fotograma, y devuelve las casillas
	_montar()
	var v: HechizoVivo = HechizoVivo.crear(_receta([]).hechizo(load("res://nucleo/fire_rune.tres")), _origen(), Vector3.RIGHT, _l)
	_ok("HC2: crear devuelve el nodo con sus casillas (%d) y lo marca para borrar si no tiene nada pendiente" % v.casillas, v.casillas == 1 and v.is_queued_for_deletion())
	await process_frame
	_ok("HC2: la zona de plasma sobrevive al HechizoVivo que la creó", _l._zonas_v2.size() == 1 and is_instance_valid(_l._zonas_v2[0]))
	# un hechizo rechazado (sólido demasiado alto) no ocupa nada
	_montar()
	var alto: HechizoVivo = HechizoVivo.crear(_receta(["altura", "altura", "altura", "altura", "altura", "altura", "altura", "altura"]).hechizo(load("res://nucleo/earth_rune.tres")), _origen(), Vector3.RIGHT, _l)
	_ok("HC2: un sólido más alto de lo que se pisa devuelve 0 casillas", alto.casillas == 0)

	# ESPEC_HECHIZO §0.3: la flecha de agua que viaja no echa agua al salir, la echa al llegar a su alcance, y entonces el hechizo desaparece
	_montar()
	var sim_f: AguaSim3D = Lanzador3D.montar_agua_sim()
	var fl: HechizoVivo = HechizoVivo.crear(_receta(["flecha", "flecha"]).hechizo(rune), _origen(), Vector3.RIGHT, _l, null, {}, true)
	for _i in range(30):
		fl.paso(DT)
	_ok("flecha de agua: en pleno vuelo todavía no hay agua", fl.activo and sim_f.volumen_total() < 0.0001)
	var pasos_f: int = 0
	while fl.activo and pasos_f < 1500:
		fl.paso(DT)
		pasos_f += 1
	var fin_f: String = fl.motivo_fin
	await create_timer(0.9).timeout                  # t_caida ≤ 0,8 s
	for _i in range(int((HechizoVivo.T_LLENADO_V2 + 0.3) / DT)):
		sim_f.paso(DT)
	_ok("flecha de agua: llega (%s) y forma charco (%.3f u³), luego desaparece" % [fin_f, sim_f.volumen_total()], (fin_f == "alcance" or fin_f == "suelo") and sim_f.volumen_total() > 0.01 and (not is_instance_valid(fl) or fl.is_queued_for_deletion()))

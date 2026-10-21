extends SceneTree
## Prueba de HC4 (18/10; docs/HECHIZO_CLASE.md §2.2 ◇ y §2.3): los campos nuevos del Hechizo y el catálogo de acciones de sus eventos, EJECUTADOS por el HechizoVivo.
##   godot --headless --fixed-fps 60 --path . --script res://herramientas/prueba_hechizo_vivo.gd
## Una comprobación por campo (velocidad, aceleración, gravedad, rebotes, retorna, busca, perfora, veneno, golpea_lanzador, choca_con, estela, efecto_impacto,
## radio_explosion) y por acción (danar_area, crear_hijo, estado_suelo, sonido, vfx) y evento (al_nacer, al_golpear, al_matar, al_expirar, al_rebotar, al_viajar),
## más los límites (profundidad 2, 32 vivos, el hijo no hereda eventos). El proyectil se avanza a mano (`paso(dt)`): sin ventana y sin depender de los fotogramas.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var marcas: Array = []                       ## [elemento, celda] de cada _al_impactar
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		marcas.append([elemento, Terreno3D.celda_de(punto)])

class ReactivoFalso extends Node3D:
	var golpes: int = 0
	func on_spell_hit(_rune: RuneData, _dir: Vector3 = Vector3.ZERO) -> void:
		golpes += 1

class JugadorFalso extends Jugador3D:
	var recibido: float = 0.0
	func recibir_dano(cantidad: float, _desde: Vector3 = Vector3.ZERO) -> void:
		recibido += cantidad

const DT: float = 1.0 / 60.0
const LADO: int = 20
const SALIDA: Vector2i = Vector2i(5, 8)

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: JugadorFalso = null
var _vfx: Array = []                              ## [nombre, posición, elemento] de la señal vfx_hechizo


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_campos_hechizo()
	await _movimiento()
	await _golpes()
	await _estados()
	await _choque_y_aspecto()
	await _eventos()
	await _limites()
	await _vivo_real()
	await _en_punto_y_areas()
	await _unidades()
	await _vida()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


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
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), Terreno3D.y_pies(Vector2i(2, 2)))
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	_vfx.clear()
	_l.vfx_hechizo.connect(func(nombre: String, pos: Vector3, el: String) -> void: _vfx.append([nombre, pos, el]))


## Un hechizo de un elemento con cambios de campos encima (el modo de crear hechizos nuevos: datos, no código).
func _hz(fichero: String, cambios: Dictionary) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % fichero) as RuneData, {}).con(_en_m(cambios))


## Desde el 19/10 (ESPEC_HECHIZO §0.1) el Hechizo habla en m/s y metros-casilla. Los números de esta prueba se escribieron en u/s y u (HC4) y tienen sentido físico en u: aquí se pasan a metros
## al construir (÷ casilla), así el hechizo recibe lo que toca y las medidas de abajo siguen siendo en u. HechizoVivo los multiplica de vuelta.
func _en_m(cambios: Dictionary) -> Dictionary:
	var r: Dictionary = cambios.duplicate()
	for campo in ["velocidad", "aceleracion", "altura_salida"]:
		if r.has(campo):
			r[campo] = float(r[campo]) / Terreno3D.casilla
	return r


func _origen(c: Vector2i = SALIDA, dy: float = Terreno3D.ALTO_NIVEL * 0.0 + 0.8) -> Vector3:
	return Lanzador3D.centro_de(c, Terreno3D.y_pies(c) + dy)


func _lanzar(h: Hechizo, c: Vector2i = SALIDA, dir: Vector3 = Vector3.RIGHT, dy: float = 0.8) -> HechizoVivo:
	return HechizoVivo.crear(h.con(_en_m({"altura_salida": dy})), _origen(c, dy), dir, _l, null, {}, true)


func _correr(v: HechizoVivo, max_pasos: int = 1500) -> int:
	var n: int = 0
	while v.activo and n < max_pasos:
		v.paso(DT)
		n += 1
	return n


func _enemigo(c: Vector2i, vida: float = -1.0) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	_m.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, _m, _jug, _l)
	e.set_physics_process(false)
	e.altura = 0.85
	e.congelado = 99.0
	if vida > 0.0:
		e.health = vida
	return e


func _eventos_de(v: HechizoVivo, nombre: String) -> int:
	return v.eventos_vistos.count(nombre)


func _hijos() -> Array:
	var r: Array = []
	for c in _l.get_children():
		if c is HechizoVivo and not c.is_queued_for_deletion():
			r.append(c)
	return r


# ---------------------------------------------------------------------------------------------------------------------
func _campos_hechizo() -> void:
	var h: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {})
	_ok("HC4 Hechizo: los campos nuevos valen 0 / falso / vacío por defecto (nada cambia en los hechizos de hoy)",
		h.velocidad == 0.0 and h.aceleracion == 0.0 and h.gravedad == 0.0 and h.retorna == false and h.busca == 0.0 and h.perfora == 0 and h.veneno == 0.0
		and h.golpea_lanzador == false and h.choca_con == 0 and h.estela == "" and h.efecto_impacto == "" and h.radio_explosion == 0.0 and h.eventos.is_empty() and h.profundidad == 0)
	var c: Hechizo = h.copiar()
	c.eventos["al_nacer"] = [{"accion": "sonido"}]
	c.dano = 99.0
	_ok("HC4 Hechizo.copiar() es independiente del original (diccionarios y números)", h.eventos.is_empty() and h.dano != 99.0 and c.elemento == h.elemento and c.fuente == h.fuente)
	var d: Hechizo = h.copiar().con({"velocidad": 7.5, "perfora": 2, "retorna": true, "semiejes.x": 0.9, "eventos": {"al_golpear": [{"accion": "vfx", "nombre": "x"}]}})
	_ok("HC4 Hechizo.con(): cambia campos (int, bool, float, componente de semiejes y eventos enteros)",
		d.velocidad == 7.5 and d.perfora == 2 and d.retorna and absf(d.semieje_x - 0.9) < 1e-9 and (d.eventos["al_golpear"] as Array).size() == 1 and h.eventos.is_empty())
	# un elemento puede traer eventos como datos: `op: anade`
	var r: RuneData = (load("res://nucleo/fire_rune.tres") as RuneData).duplicate()
	r.modificadores = r.modificadores.duplicate(true)
	r.modificadores["eventos.al_golpear"] = {"op": "anade", "valor": {"accion": "danar_area", "radio": 1.0, "dano": 5.0}}
	var e: Hechizo = Hechizo.construir(r, {})
	_ok("HC4 un modificador «anade» sobre eventos.<nombre> deja la acción en el Hechizo (y su origen)",
		(e.eventos.get("al_golpear", []) as Array).size() == 1 and String(e.origen.get("eventos", "")) == "elemento" and (e.a_diccionario()["eventos"] as Dictionary).has("al_golpear"))
	_ok("HC4 el catálogo es cerrado: 6 eventos y 5 acciones", Hechizo.EVENTOS.size() == 6 and Hechizo.ACCIONES.size() == 5 and Hechizo.MAX_PROFUNDIDAD == 2 and Hechizo.MAX_VIVOS == 32)


# ---------------------------------------------------------------------------------------------------------------------
func _movimiento() -> void:
	# altura_salida: el proyectil sale a esa altura sobre el suelo de su casilla, venga el origen de donde venga (los pies del jugador, en el lab)
	_montar()
	var pies: Vector3 = Lanzador3D.centro_de(SALIDA, Terreno3D.y_pies(SALIDA))
	var por_defecto: HechizoVivo = HechizoVivo.crear(_hz("fire", {"velocidad": 5.0, "distancia_max": 2.0}), pies, Vector3.RIGHT, _l, null, {}, true)
	_ok("altura_salida: por defecto un proyectil que sale de los pies sale a la altura de la mano (%.2f u sobre el suelo)" % (por_defecto.p.y - pies.y), absf((por_defecto.p.y - pies.y) - 0.9) < 0.001)
	var alto: HechizoVivo = HechizoVivo.crear(_hz("fire", {"velocidad": 5.0, "distancia_max": 2.0, "altura_salida": 2.0}), pies, Vector3.RIGHT, _l, null, {}, true)
	_ok("altura_salida: tocándola sale más alto (%.2f u)" % (alto.p.y - pies.y), absf((alto.p.y - pies.y) - 2.0) < 0.001)
	var con_g: HechizoVivo = HechizoVivo.crear(_hz("fire", {"velocidad": 6.0, "gravedad": 1.0, "distancia_max": 30.0}), pies, Vector3.RIGHT, _l, null, {}, true)
	for _i in range(6):
		con_g.paso(DT)
	_ok("altura_salida: con gravedad y salida desde los pies ya no nace en el suelo: tras 0,1 s sigue en el aire (%s)" % con_g.motivo_fin, con_g.activo)
	var cas: float = Terreno3D.casilla
	# velocidad + distancia_max: recorre lo que dice y a la velocidad que dice
	_montar()
	var v: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 3.0}))
	var x0: float = v.p.x
	var pasos: int = _correr(v)
	_ok("velocidad: es un proyectil, recorre distancia_max (%.2f u de %.2f) y acaba por «alcance» en ≈ %.2f s" % [v.p.x - x0, 3.0 * cas, pasos * DT],
		v.proyectil and absf((v.p.x - x0) - 3.0 * cas) < 0.25 and v.motivo_fin == "alcance" and absf(pasos * DT - 3.0 * cas / 10.0) < 0.06)
	_ok("velocidad: sin velocidad (0) NO es proyectil: sigue el camino de siempre y devuelve casillas", _lanzar(_hz("fire", {})).proyectil == false)
	# aceleración positiva: llega más lejos en el mismo tiempo
	_montar()
	var a: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 4.0, "aceleracion": 6.0, "distancia_max": 30.0}))
	var b: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 4.0, "distancia_max": 30.0}), Vector2i(5, 10))
	var ax: float = a.p.x
	var bx: float = b.p.x
	for _i in range(30):
		a.paso(DT)
		b.paso(DT)
	_ok("aceleracion > 0: en 0,5 s avanza 4·0,5 + ½·6·0,25 = 2,75 u (mide %.2f) frente a 2,0 u sin ella (%.2f)" % [a.p.x - ax, b.p.x - bx],
		absf((a.p.x - ax) - 2.75) < 0.12 and absf((b.p.x - bx) - 2.0) < 0.1)
	# aceleración negativa: frena hasta pararse
	_montar()
	var f: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 6.0, "aceleracion": -4.0, "distancia_max": 30.0}))
	var fx: float = f.p.x
	_correr(f)
	var esperado: float = (36.0 - 0.25) / 8.0
	_ok("aceleracion < 0: frena hasta pararse (motivo «frenado», %.2f u de ≈ %.2f)" % [f.p.x - fx, esperado], f.motivo_fin == "frenado" and absf((f.p.x - fx) - esperado) < 0.2)
	# gravedad: cae como un objeto y acaba en el suelo
	_montar()
	var gv: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 6.0, "gravedad": 1.0, "distancia_max": 30.0}), SALIDA, Vector3.RIGHT, 3.0)
	var y0: float = gv.p.y
	for _i in range(30):
		gv.paso(DT)
	var caida: float = y0 - gv.p.y
	_correr(gv)
	var suelo: float = Terreno3D.y_pies(Terreno3D.celda_de(gv.p))
	_ok("gravedad = 1: en 0,5 s cae ½·9,8·0,25 = 1,22 u (mide %.2f) y acaba en el suelo (motivo «%s», y %.2f ≈ %.2f)" % [caida, gv.motivo_fin, gv.p.y, suelo],
		absf(caida - 1.225) < 0.15 and gv.motivo_fin == "suelo" and absf(gv.p.y - suelo) < 0.12)
	# impulso_salida (21/10, Pablo): la flecha de agua sale en arco y llega a su alcance; sin impulso cae a ~1 casilla
	for con_impulso in [true, false]:
		_montar()
		var pies_a: Vector3 = Lanzador3D.centro_de(SALIDA, Terreno3D.y_pies(SALIDA))
		var cambios_a: Dictionary = {"velocidad": 4.0, "distancia_max": 3.0}
		if not con_impulso:
			cambios_a["impulso_salida"] = 0.0
		var arco: HechizoVivo = HechizoVivo.crear(_hz("water", cambios_a), pies_a, Vector3.RIGHT, _l, null, {}, true)
		var x_a: float = arco.p.x
		var y_max: float = arco.p.y
		var n_a: int = 0
		while arco.activo and n_a < 600:
			arco.paso(DT)
			y_max = maxf(y_max, arco.p.y)
			n_a += 1
		var lejos: float = (arco.p.x - x_a) / cas
		if con_impulso:
			_ok("impulso_salida: el agua sale en arco (sube %.2f u) y aterriza a %.2f casillas de 3 (motivo «%s»)" % [y_max - pies_a.y, lejos, arco.motivo_fin],
				y_max - pies_a.y > 1.8 and lejos > 2.6 and lejos <= 3.05)
		else:
			_ok("impulso_salida = 0: la misma agua cae a %.2f casillas (el fallo del playtest)" % lejos, lejos < 1.3 and arco.motivo_fin == "suelo")
	var sin_g: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 6.0, "distancia_max": 3.0}), Vector2i(5, 12), Vector3.RIGHT, 3.0)
	var ys: float = sin_g.p.y
	_correr(sin_g)
	_ok("gravedad = 0: vuela recto a su altura", absf(sin_g.p.y - ys) < 0.001)
	# rebotes en la pared (la de la derecha está en x = 19)
	_montar()
	var r0: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 12.0, "distancia_max": 6.0}), Vector2i(16, 8))
	_correr(r0)
	_ok("rebotes = 0: la pared lo para (motivo «muro») y salta al_expirar", r0.motivo_fin == "muro" and _eventos_de(r0, "al_rebotar") == 0)
	_montar()
	var r1: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 12.0, "distancia_max": 6.0, "rebotes": 1, "eventos": {"al_rebotar": [{"accion": "vfx", "nombre": "chispa"}]}}), Vector2i(16, 8))
	for _i in range(40):
		r1.paso(DT)
	_ok("rebotes = 1: rebota una vez (al_rebotar ×%d), vuelve hacia atrás (vx = %.1f) y la acción vfx del evento sale (%d)" % [_eventos_de(r1, "al_rebotar"), r1.v.x, _vfx.size()],
		_eventos_de(r1, "al_rebotar") == 1 and r1.v.x < 0.0 and _vfx.size() == 1 and _vfx[0][0] == "chispa")
	var r2: HechizoVivo = r1
	_correr(r2)
	_ok("rebotes: gastado el rebote, la siguiente pared lo para (rebotes_usados %d, motivo %s)" % [r2.rebotes_usados, r2.motivo_fin], r2.rebotes_usados == 1 and r2.motivo_fin in ["alcance", "muro"])
	# rebote en el suelo (gravedad + rebotes)
	_montar()
	var rs: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 3.0, "gravedad": 1.0, "rebotes": 2, "distancia_max": 30.0}), SALIDA, Vector3.RIGHT, 2.0)
	var subio: bool = false
	var bajo_antes: bool = false
	for _i in range(200):
		rs.paso(DT)
		bajo_antes = bajo_antes or rs.v.y < -1.0
		subio = subio or (bajo_antes and rs.v.y > 0.5)
	_ok("rebotes: también rebota en el suelo cuando cae (%d rebotes)" % rs.rebotes_usados, subio and rs.rebotes_usados >= 1)
	# retorna: va, da la vuelta y vuelve al lanzador
	_montar()
	_jug.position = Lanzador3D.centro_de(Vector2i(4, 8), Terreno3D.y_pies(Vector2i(4, 8)))
	var bu: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 8.0, "distancia_max": 3.0, "retorna": true}))
	var max_x: float = bu.p.x
	var diste: bool = false
	for _i in range(600):
		if not bu.activo:
			break
		bu.paso(DT)
		max_x = maxf(max_x, bu.p.x)
		diste = diste or bu.volviendo
	_ok("retorna: llega a su alcance (%.1f u), da la vuelta y se recoge cerca del lanzador (motivo «%s», a %.2f u)" % [max_x - _origen().x, bu.motivo_fin, bu.p.distance_to(_jug.global_position + Vector3(0, 0.8, 0))],
		diste and bu.motivo_fin == "retorno" and absf((max_x - _origen().x) - 3.0 * cas) < 0.3 and bu.p.distance_to(_jug.global_position + Vector3(0, 0.8, 0)) <= 1.0)
	# busca: gira hacia el enemigo del cono
	_montar()
	var en: Combate3D = _enemigo(Vector2i(8, 10))
	var vida0: float = en.health
	var recto: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 6.0, "distancia_max": 8.0}))
	_correr(recto)
	var sin_busca: bool = en.health == vida0
	var busca_h: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 6.0, "distancia_max": 8.0, "busca": 1.0}), Vector2i(5, 8))
	_correr(busca_h)
	_ok("busca = 0: pasa de largo (el enemigo, 2 casillas al lado, no recibe nada); busca = 1: gira, lo alcanza y lo hiere (vida %.0f → %.0f)" % [vida0, en.health],
		sin_busca and en.health < vida0 and busca_h.motivo_fin == "golpe")
	_montar()
	var detras: Combate3D = _enemigo(Vector2i(3, 10))
	var vd: float = detras.health
	var ciego: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 6.0, "distancia_max": 4.0, "busca": 1.0}), Vector2i(5, 12))
	var dir0: Vector3 = ciego.v.normalized()
	_correr(ciego)
	_ok("busca: un enemigo detrás (fuera del cono de 60°) no lo atrae", detras.health == vd and ciego.v.normalized().dot(dir0) > 0.999)


# ---------------------------------------------------------------------------------------------------------------------
func _golpes() -> void:
	# perfora
	for perfora in [0, 1, 2]:
		_montar()
		var e1: Combate3D = _enemigo(Vector2i(8, 8))
		var e2: Combate3D = _enemigo(Vector2i(10, 8))
		var v1: float = e1.health
		var v2: float = e2.health
		var v: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 8.0, "perfora": perfora}))
		_correr(v)
		var golpeados: int = int(e1.health < v1) + int(e2.health < v2)
		var esperado: int = mini(perfora + 1, 2)
		_ok("perfora = %d: hiere a %d enemigo(s) en fila y %s (golpeó a %d)" % [perfora, esperado, "se para en el golpe" if perfora < 2 else "sigue hasta su alcance", golpeados],
			golpeados == esperado and (v.motivo_fin == "golpe") == (perfora < 2))
	# el golpe usa el Hechizo (daño tocado en el lab)
	_montar()
	var d: Combate3D = _enemigo(Vector2i(8, 8))
	var vd: float = d.health
	_correr(_lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 8.0, "dano": 40.0})))
	var mult: float = d.multiplicador("fuego")
	_ok("el golpe del proyectil lee el daño DEL HECHIZO (40 × %.1f del goblin al fuego, no el del .tres): vida %.0f → %.1f" % [mult, vd, d.health], absf((vd - d.health) - 40.0 * mult) < 0.6)
	# reactivos: reciben el golpe como siempre
	_montar()
	var re := ReactivoFalso.new()
	re.add_to_group("reactivo3d")
	_m.add_child(re)
	re.position = Lanzador3D.centro_de(Vector2i(8, 8), Terreno3D.y_pies(Vector2i(8, 8)))
	_correr(_lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 8.0})))
	_ok("un proyectil golpea a un reactivo por on_spell_hit (%d golpe)" % re.golpes, re.golpes == 1)
	# golpea_lanzador
	_montar()
	_jug.position = Lanzador3D.centro_de(Vector2i(8, 8), Terreno3D.y_pies(Vector2i(8, 8)))
	_correr(_lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 6.0})))
	var sin_flag: float = _jug.recibido
	_montar()
	_jug.position = Lanzador3D.centro_de(Vector2i(8, 8), Terreno3D.y_pies(Vector2i(8, 8)))
	_correr(_lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 6.0, "golpea_lanzador": true})))
	_ok("golpea_lanzador: falso lo atraviesa (daño %.0f), verdadero lo hiere (daño %.0f = el del hechizo)" % [sin_flag, _jug.recibido], sin_flag == 0.0 and absf(_jug.recibido - Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {}).dano) < 0.01)
	# radio_explosion (campo) y danar_area (acción): el herido directo, uno cerca y uno lejos
	for modo in ["campo", "accion"]:
		_montar()
		var a: Combate3D = _enemigo(Vector2i(8, 8))
		var cerca: Combate3D = _enemigo(Vector2i(8, 9))
		var lejos: Combate3D = _enemigo(Vector2i(8, 14))
		var rp := ReactivoFalso.new()
		rp.add_to_group("reactivo3d")
		_m.add_child(rp)
		rp.position = Lanzador3D.centro_de(Vector2i(9, 8), Terreno3D.y_pies(Vector2i(9, 8)))
		var cambios: Dictionary = {"velocidad": 10.0, "distancia_max": 8.0, "dano": 10.0}
		if modo == "campo":
			cambios["radio_explosion"] = 1.5
		else:
			cambios["eventos"] = {"al_golpear": [{"accion": "danar_area", "radio": 1.5, "dano": 10.0}]}
		var va: float = a.health
		var vc: float = cerca.health
		var vl: float = lejos.health
		var v: HechizoVivo = _lanzar(_hz("fire", cambios))
		_correr(v)
		var mult2: float = a.multiplicador("fuego")
		_ok("%s: explota al golpear — el directo recibe golpe + explosión (%.0f), el cercano %.0f, el lejano nada, y el reactivo cercano arde (%d)" % ["radio_explosion" if modo == "campo" else "danar_area", va - a.health, vc - cerca.health, rp.golpes],
			absf((va - a.health) - 20.0 * mult2) < 1.0 and absf((vc - cerca.health) - 10.0 * mult2) < 1.0 and lejos.health == vl and rp.golpes >= 1)
	# al_matar
	_montar()
	var debil: Combate3D = _enemigo(Vector2i(8, 8), 1.0)
	var vm: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 8.0, "eventos": {"al_matar": [{"accion": "vfx", "nombre": "muerte"}]}}))
	_correr(vm)
	_ok("al_matar: salta cuando el golpe mata (muerto = %s) y sus acciones se cumplen (vfx «%s»)" % [str(debil.muerto), _vfx[0][0] if not _vfx.is_empty() else "—"],
		debil.muerto and _eventos_de(vm, "al_golpear") == 0 and _eventos_de(vm, "al_matar") == 1 and not _vfx.is_empty() and _vfx[0][0] == "muerte")


# ---------------------------------------------------------------------------------------------------------------------
func _estados() -> void:
	_montar()
	var e: Combate3D = _enemigo(Vector2i(8, 8))
	var v0: float = e.health
	e.golpe(_hz("wind", {"dano": 0.0, "veneno": 2.0, "veneno_dps": 4.0}), Vector3.RIGHT)      # el viento: ni quema ni moja, así solo cuenta el veneno
	_ok("veneno: el golpe deja envenenado (%.1f s, %.0f dps)" % [e.envenenado, e._dps_veneno], absf(e.envenenado - 2.0) < 0.01 and e._dps_veneno == 4.0)
	for _i in range(5):
		e._efectos(0.5)
	_ok("veneno: hiere dps × duración = 8 en total (vida %.1f → %.1f) y se acaba (%.1f)" % [v0, e.health, e.envenenado], absf((v0 - e.health) - 8.0) < 0.6 and e.envenenado == 0.0)
	var q: Combate3D = _enemigo(Vector2i(8, 9))
	q.elemental = true
	q.golpe(_hz("fire", {"dano": 0.0, "veneno": 2.0}), Vector3.RIGHT)
	_ok("veneno: un elemental no se envenena", q.envenenado == 0.0)
	_montar()
	var p: Combate3D = _enemigo(Vector2i(8, 8))
	_correr(_lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 6.0, "veneno": 3.0})))
	_ok("veneno: el proyectil lo deja con el veneno del hechizo (%.1f s)" % p.envenenado, absf(p.envenenado - 3.0) < 0.05)


# ---------------------------------------------------------------------------------------------------------------------
func _choque_y_aspecto() -> void:
	# choca_con: sin «mundo» atraviesa la pared; sin «enemigos» atraviesa al enemigo
	_montar()
	var sin_mundo: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 12.0, "distancia_max": 6.0, "choca_con": Hechizo.CHOCA_ENEMIGOS}), Vector2i(16, 8))
	_correr(sin_mundo)
	_ok("choca_con = solo enemigos: atraviesa la pared (motivo «%s», x = %.1f más allá de la pared en %.1f)" % [sin_mundo.motivo_fin, sin_mundo.p.x, 19.0 * Terreno3D.casilla], sin_mundo.motivo_fin == "alcance" and sin_mundo.p.x > 19.0 * Terreno3D.casilla)
	_montar()
	var e: Combate3D = _enemigo(Vector2i(8, 8))
	var ve: float = e.health
	var sin_enemigos: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 12.0, "distancia_max": 6.0, "choca_con": Hechizo.CHOCA_MUNDO}))
	_correr(sin_enemigos)
	_ok("choca_con = solo mundo: pasa por el enemigo sin herirlo", e.health == ve and sin_enemigos.motivo_fin == "alcance")
	_montar()
	var e2: Combate3D = _enemigo(Vector2i(8, 8))
	var normal: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 12.0, "distancia_max": 6.0}))
	_correr(normal)
	_ok("choca_con = 0 (defecto): mundo + enemigos, como siempre", e2.health < 100.0 and normal.motivo_fin == "golpe")
	# estela y efecto_impacto: nombres que salen por vfx_hechizo
	_montar()
	var e3: Combate3D = _enemigo(Vector2i(8, 8))
	var vv: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 8.0, "estela": "estela_fuego", "efecto_impacto": "chispas"}))
	_correr(vv)
	var estelas: int = 0
	var impactos: int = 0
	for x in _vfx:
		estelas += int(x[0] == "estela_fuego")
		impactos += int(x[0] == "chispas")
	_ok("estela: pide su VFX al nacer y cada medio metro recorrido (%d veces); efecto_impacto: una vez por golpe (%d); nada si están vacíos" % [estelas, impactos], estelas >= 3 and impactos == 1 and e3.health < 100.0)
	_montar()
	_correr(_lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 4.0})))
	_ok("estela / efecto_impacto vacíos: no piden ningún VFX", _vfx.is_empty())


# ---------------------------------------------------------------------------------------------------------------------
func _eventos() -> void:
	# al_nacer + sonido + vfx, en un hechizo de los de siempre (sin velocidad)
	_montar()
	var n0: int = _l.sonidos_fase.size()
	var v: HechizoVivo = _lanzar(_hz("fire", {"eventos": {"al_nacer": [{"accion": "sonido", "nombre": "carga"}, {"accion": "vfx", "nombre": "nace"}]}}))
	var sono: bool = false
	for i in range(n0, _l.sonidos_fase.size()):
		sono = sono or String(_l.sonidos_fase[i]["fase"]) == "carga"
	_ok("al_nacer: en un hechizo SIN velocidad también salta; «sonido» suena (fase carga) y «vfx» emite el nombre", sono and not _vfx.is_empty() and _vfx[0][0] == "nace" and _eventos_de(v, "al_nacer") == 1)
	# al_expirar en un hechizo sin velocidad: tras `persiste`
	_montar()
	var x: HechizoVivo = _lanzar(_hz("fire", {"persiste": 0.3, "eventos": {"al_expirar": [{"accion": "vfx", "nombre": "fin"}]}}))
	var antes: bool = _vfx.is_empty()
	await create_timer(0.6).timeout
	_ok("al_expirar (sin velocidad): salta cuando acaba `persiste` (no antes), una sola vez, y el nodo se borra después (válido = %s)" % str(is_instance_valid(x)), antes and _vfx.size() == 1 and _vfx[0][0] == "fin" and not is_instance_valid(x))
	# al_expirar en un proyectil + estado_suelo
	_montar()
	var cuando: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 3.0, "eventos": {"al_expirar": [{"accion": "estado_suelo", "estado": "fuego", "radio": 1.0}]}}))
	_correr(cuando)
	var celdas: Dictionary = {}
	for mc in _m.marcas:
		celdas[mc[1]] = mc[0]
	_ok("al_expirar + estado_suelo (radio 1): marca la casilla del final y sus 4 vecinas (%d marcas)" % celdas.size(), celdas.size() == 5 and _eventos_de(cuando, "al_expirar") == 1 and String(celdas.values()[0]) == "fuego")
	_montar()
	var gol: Combate3D = _enemigo(Vector2i(8, 8))
	var vg: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 8.0, "eventos": {"al_expirar": [{"accion": "vfx", "nombre": "no_debe_salir"}]}}))
	_correr(vg)
	_ok("al_expirar: NO salta si lo para un golpe (ese ya tuvo su al_golpear)", gol.health < 100.0 and vg.motivo_fin == "golpe" and _vfx.is_empty())
	# al_viajar: cada N casillas
	_montar()
	var vi: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 4.0, "eventos": {"al_viajar": [{"accion": "estado_suelo", "estado": "fuego", "cada": 1.0}]}}))
	_correr(vi)
	_ok("al_viajar (cada 1 casilla, 4 de alcance): rastro de estado de suelo (%d veces, %d marcas)" % [_eventos_de(vi, "al_viajar"), _m.marcas.size()], _eventos_de(vi, "al_viajar") in [3, 4] and _m.marcas.size() >= 3)
	_montar()
	var vj: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 4.0, "eventos": {"al_viajar": [{"accion": "vfx", "nombre": "x", "cada": 2.0}]}}))
	_correr(vj)
	_ok("al_viajar: `cada` 2 casillas da la mitad de eventos (%d)" % _eventos_de(vj, "al_viajar"), _eventos_de(vj, "al_viajar") in [1, 2])
	# crear_hijo: abanico, cambios, sin eventos, sin repetir el golpe
	_montar()
	var objetivo: Combate3D = _enemigo(Vector2i(8, 8))
	var padre: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 8.0, "eventos": {"al_golpear": [{"accion": "crear_hijo", "cuantos": 3, "abanico": 60.0, "cambios": {"velocidad": 6.0, "distancia_max": 2.0, "dano": 7.0}}]}}))
	_correr(padre)
	await process_frame
	var hijos: Array = _hijos()
	var angulos: Array = []
	var todos_bien: bool = hijos.size() == 3
	for hj in hijos:
		var hv: HechizoVivo = hj
		angulos.append(snappedf(absf(rad_to_deg(atan2(hv.v.z, hv.v.x))), 1.0))
		todos_bien = todos_bien and hv.h.profundidad == 1 and hv.h.eventos.is_empty() and hv.h.velocidad == 6.0 and hv.h.dano == 7.0 and hv.golpeados.has(objetivo.get_instance_id())
	angulos.sort()
	_ok("crear_hijo: 3 hijos en abanico de 60° (ángulos %s), profundidad 1, con los cambios, SIN eventos y sin repetir el golpe del padre" % str(angulos), todos_bien and angulos == [0.0, 30.0, 30.0])
	# encadenar: un hijo con busca va al enemigo más cercano que NO sea el golpeado
	_montar()
	var a: Combate3D = _enemigo(Vector2i(8, 8))
	var b: Combate3D = _enemigo(Vector2i(10, 9))
	var va: float = a.health
	var vb: float = b.health
	var cadena: HechizoVivo = _lanzar(_hz("lightning", {"velocidad": 10.0, "distancia_max": 8.0, "persiste": 3.0, "eventos": {"al_golpear": [{"accion": "crear_hijo", "cuantos": 1, "cambios": {"velocidad": 10.0, "distancia_max": 6.0, "busca": 2.0}}]}}))
	_correr(cadena)
	for hj in _hijos():
		_correr(hj as HechizoVivo)
	_ok("crear_hijo + busca (encadenar): el rayo salta del primero al segundo (%.0f → %.0f y %.0f → %.0f)" % [va, a.health, vb, b.health], a.health < va and b.health < vb)


func _limites() -> void:
	# profundidad ≤ 2: cada hijo trae eventos que crean otro hijo; solo hay padre + 2 generaciones
	_montar()
	var nivel3: Dictionary = {"al_nacer": [{"accion": "crear_hijo", "cuantos": 1, "cambios": {}}]}
	var nivel2: Dictionary = {"al_nacer": [{"accion": "crear_hijo", "cuantos": 1, "cambios": {"eventos": nivel3}}]}
	var raiz: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 1.0, "eventos": {"al_nacer": [{"accion": "crear_hijo", "cuantos": 1, "cambios": {"eventos": nivel2}}]}}))
	var profundidades: Array = []
	for c in _l.get_children():
		if c is HechizoVivo:
			profundidades.append((c as HechizoVivo).h.profundidad)
	profundidades.sort()
	_ok("límite de profundidad: padre + hijo + nieto y no más (profundidades %s, vivos %d)" % [str(profundidades), raiz.linaje.vivos], profundidades == [0, 1, 2] and raiz.linaje.vivos == 3)
	# ≤ 32 vivos por lanzamiento
	_montar()
	var nietos: Dictionary = {"al_nacer": [{"accion": "crear_hijo", "cuantos": 20, "cambios": {}}]}
	var raiz2: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 1.0, "eventos": {"al_nacer": [{"accion": "crear_hijo", "cuantos": 20, "cambios": {"eventos": nietos}}]}}))
	var vivos: int = 0
	for c in _l.get_children():
		vivos += int(c is HechizoVivo)
	var lin: HechizoVivo.Linaje = raiz2.linaje
	_ok("límite de vivos: un lanzamiento que se multiplica se queda en %d (nodos %d, contador %d)" % [Hechizo.MAX_VIVOS, vivos, lin.vivos], vivos == Hechizo.MAX_VIVOS and lin.vivos == Hechizo.MAX_VIVOS)
	# el contador baja cuando mueren
	for c in _l.get_children():
		if c is HechizoVivo:
			(c as HechizoVivo).activo = false
			(c as HechizoVivo).queue_free()
	await process_frame
	await process_frame
	_ok("el contador de vivos baja al morir los nodos (%d)" % lin.vivos, lin.vivos == 0)
	# un acción desconocida se ignora, no rompe
	_montar()
	var raro: HechizoVivo = _lanzar(_hz("fire", {"velocidad": 10.0, "distancia_max": 2.0, "eventos": {"al_nacer": [{"accion": "inventada"}, {}, {"accion": "vfx", "nombre": "ok"}]}}))
	_ok("una acción que no está en el catálogo se ignora y las demás se cumplen", _vfx.size() == 1 and _vfx[0][0] == "ok" and raro.proyectil)


## El proyectil avanza solo en el motor (_physics_process), sin llamar a `paso`.
func _vivo_real() -> void:
	_montar()
	var h: Hechizo = _hz("fire", {"velocidad": 10.0, "distancia_max": 3.0})
	var v: HechizoVivo = HechizoVivo.crear(h, _origen(), Vector3.RIGHT, _l)
	var x0: float = v.p.x
	for _i in range(20):
		await physics_frame
	_ok("en el motor avanza solo con _physics_process (%.2f u tras 20 fotogramas)" % (v.p.x - x0), v.p.x - x0 > 1.5 and v.activo)
	var ref: WeakRef = weakref(v)
	for _i in range(60):
		await physics_frame
	await process_frame
	_ok("y al acabar el nodo se borra solo (referencia viva = %s)" % str(ref.get_ref() != null), ref.get_ref() == null)


# --- 18/10 · diseño de Pablo: «nace donde apuntas» (en_punto) y los objetos reactivos que el proyectil alcanza ---
func _en_punto_y_areas() -> void:
	_montar()
	var cas: float = Terreno3D.casilla
	var yo: Vector3 = _jug.position
	# sin en_punto, todo nace en el jugador aunque el cursor esté lejos
	_l._preparado = {"en_punto": false}
	_l._punto_vivo = yo + Vector3(5.0 * cas, 0.0, 0.0)
	_l._calcular_origen_vivo()
	_ok("en_punto: sin él, nace en el jugador", _l._origen_vivo.is_equal_approx(yo))
	# con en_punto nace en el punto apuntado si está dentro del anillo de alcance
	_l._preparado = {"en_punto": true}
	_l._punto_vivo = yo + Vector3(0.0, 0.0, 2.0 * cas)
	_l._calcular_origen_vivo()
	_ok("en_punto: nace en el punto apuntado (2 casillas)", _l._origen_vivo.distance_to(yo + Vector3(0.0, 0.0, 2.0 * cas)) < 0.001)
	# y si el cursor está más lejos, se queda en el borde del anillo (ALCANCE_ORIGEN casillas), en su misma dirección
	_l._punto_vivo = yo + Vector3(10.0 * cas, 0.0, 0.0)
	_l._calcular_origen_vivo()
	_ok("en_punto: lejos, se queda en el borde del anillo (%.2f u)" % ((_l._origen_vivo - yo).length()), absf((_l._origen_vivo - yo).length() - Lanzador3D.ALCANCE_ORIGEN * cas) < 0.001 and _l._origen_vivo.z == yo.z)
	# el hechizo de una barrera lo pide; el de una línea, no (cast_page lo lee de Hechizo.en_punto)
	var rune: RuneData = load("res://nucleo/earth_rune.tres")
	_ok("en_punto: lo pide el glifo de barrera", Hechizo.construir(rune, {"barrera": 1}).en_punto and not Hechizo.construir(rune, {"linea_x": 2}).en_punto)


# --- E1 (19/10): el Hechizo habla en metros-casilla y m/s; HechizoVivo convierte a u con la casilla ---
func _unidades() -> void:
	_montar()
	var cas: float = Terreno3D.casilla
	var pies: Vector3 = Lanzador3D.centro_de(SALIDA, Terreno3D.y_pies(SALIDA))
	var rapido: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {}).con({"velocidad": 2.0, "distancia_max": 4.0})     # SIN _en_m: metros de verdad
	var v: HechizoVivo = HechizoVivo.crear(rapido, pies, Vector3.RIGHT, _l, null, {}, true)
	_ok("unidades: velocidad 2 m/s = 2 casillas/s = %.2f u/s (mide %.2f)" % [2.0 * cas, v.v.length()], absf(v.v.length() - 2.0 * cas) < 0.001)
	_ok("unidades: altura_salida en m: sale a (altura_salida + elevacion) × casilla sobre el suelo (%.3f u)" % (v.p.y - pies.y), absf((v.p.y - pies.y) - rapido.altura_salida * cas) < 0.001 and absf(rapido.altura_salida * cas - 0.9) < 0.001)
	var alto: HechizoVivo = HechizoVivo.crear(rapido.copiar().con({"elevacion": 1.0}), pies, Vector3.RIGHT, _l, null, {}, true)
	_ok("unidades: elevacion 1 m sube un metro-casilla más (%.3f u)" % (alto.p.y - v.p.y), absf((alto.p.y - v.p.y) - cas) < 0.001)
	_correr(v)
	_ok("unidades: distancia_max 4 m = 4 casillas (%.2f u de %.2f)" % [v.p.x - pies.x, 4.0 * cas], absf((v.p.x - pies.x) - 4.0 * cas) < 0.3)


## Regla de vida (ESPEC_HECHIZO §0.3, E2): lo que viaja desaparece al llegar o chocar salvo que lleve `permanencia`; la `persiste` del elemento solo cuenta para lo que nace quieto.
func _vida() -> void:
	var cas: float = Terreno3D.casilla
	# 1. flecha de fuego (persiste 3) de alcance 3 m, SIN permanencia: avanza 3 y desaparece (a 1,7 m/s tardaría 1,7 s; con alcance 6 llegaría a 3,4 s y antes la mataba la `persiste`)
	_montar()
	var f: HechizoVivo = HechizoVivo.crear(_hz("fire", {"persiste": 3.0, "velocidad": 4.0, "distancia_max": 3.0, "gravedad": 0.0}), _origen(), Vector3.RIGHT, _l, null, {}, true)
	_correr(f)
	_ok("vida: flecha de alcance 3 sin permanencia avanza 3 casillas (%.2f) y acaba por «alcance»" % (f.recorrido / cas), absf(f.recorrido / cas - 3.0) < 0.05 and f.motivo_fin == "alcance")
	_ok("vida: ...y desaparece ya (no se queda, aunque el fuego persista 3 s)", not f.quedandose and f.is_queued_for_deletion())
	var larga: HechizoVivo = HechizoVivo.crear(_hz("fire", {"persiste": 3.0, "velocidad": 4.0, "distancia_max": 6.0, "gravedad": 0.0}), _origen(Vector2i(2, 8)), Vector3.RIGHT, _l, null, {}, true)
	_correr(larga)
	_ok("vida: alcance 6 a 1,7 m/s dura 3,4 s > persiste 3: ya NO la corta el tiempo, llega a su alcance (%.2f casillas, «%s»)" % [larga.recorrido / cas, larga.motivo_fin], absf(larga.recorrido / cas - 6.0) < 0.05 and larga.motivo_fin == "alcance")
	# 2. pared a 2 casillas: se para ahí y desaparece (la pared de la derecha es la casilla x = 19; sale de x = 17)
	_montar()
	var pared: HechizoVivo = HechizoVivo.crear(_hz("fire", {"velocidad": 4.0, "distancia_max": 5.0, "gravedad": 0.0}), _origen(Vector2i(17, 8)), Vector3.RIGHT, _l, null, {}, true)
	_correr(pared)
	_ok("vida: con una pared a 2 casillas se para antes de llegar (%.2f casillas, motivo «%s») y desaparece" % [pared.recorrido / cas, pared.motivo_fin], pared.motivo_fin == "muro" and pared.recorrido / cas < 2.0 and not pared.quedandose and pared.is_queued_for_deletion())
	# 3. con Permanencia 2 s: avanza 3 y se queda 2 s
	_montar()
	var p2: HechizoVivo = HechizoVivo.crear(_hz("fire", {"velocidad": 4.0, "distancia_max": 3.0, "gravedad": 0.0, "permanencia": 2.0}), _origen(), Vector3.RIGHT, _l, null, {}, true)
	_correr(p2)
	var x_fin: float = p2.p.x
	_ok("vida: con permanencia 2 avanza 3 casillas (%.2f) y se queda en el sitio" % (p2.recorrido / cas), absf(p2.recorrido / cas - 3.0) < 0.05 and p2.quedandose and not p2.is_queued_for_deletion())
	await create_timer(1.0).timeout
	_ok("vida: a 1 s de parar sigue ahí, quieto", is_instance_valid(p2) and p2.quedandose and p2.p.x == x_fin)
	await create_timer(1.3).timeout
	_ok("vida: pasados sus 2 s desaparece", not is_instance_valid(p2) or (not p2.quedandose and p2.is_queued_for_deletion()))
	# 4. el volumen que nace quieto: persiste + permanencia (muro de tierra con solidez: 8 s, con Permanencia ×1 → 10 s)
	for par in [[0.0, 8.0], [2.0, 10.0]]:
		_montar()
		var muro: HechizoVivo = HechizoVivo.crear(_hz("earth", {"solidez": 1.0, "permanencia": par[0]}), _origen(), Vector3.RIGHT, _l, null, {}, true)
		var vida_s: float = 0.0
		for s2 in _l._solideces_v2:
			vida_s = maxf(vida_s, (s2 as Lanzador3D.SolidezV2).vida)
		_ok("vida: muro de tierra quieto con permanencia %.0f dura %.1f s (mide %.1f)" % [par[0], par[1], vida_s], absf(vida_s - par[1]) < 0.001 and muro != null)
	# 5. el volumen que viaja: la `persiste` del elemento no cuenta (fuego de zona: vida = lo que falta para llegar, no 3 s)
	_montar()
	HechizoVivo.crear(_hz("fire", {"velocidad": 0.0, "distancia_max": 3.0}), _origen(), Vector3.RIGHT, _l, null, {}, true)
	var primera: float = 0.0
	for z in _l._zonas_v2:
		primera = maxf(primera, (z as Lanzador3D.ZonaV2).vida)
	_ok("vida: la primera tanda de un volumen que viaja 3 m a 8 m/s vive lo que falta para llegar (%.2f s ≈ 0,375), no los 3 s del fuego" % primera, absf(primera - 3.0 / Hechizo.VELOCIDAD_VIAJE_DEFECTO) < 0.01)
	# 6. (ESPEC_HECHIZO §0.3, 19/10) la flecha de agua que viaja: mientras viaja no deja nada; al PARARSE aplica su materia una vez (charco en AguaSim) y desaparece
	_montar()
	var sim: AguaSim3D = Lanzador3D.montar_agua_sim()
	var fa: HechizoVivo = HechizoVivo.crear(_hz("water", {"velocidad": 4.0, "distancia_max": 3.0, "gravedad": 0.0}), _origen(), Vector3.RIGHT, _l, null, {}, true)
	for _i in range(30):
		fa.paso(DT)
	_ok("vida: la flecha de agua en pleno vuelo (%.2f casillas) aún no ha echado agua" % (fa.recorrido / cas), fa.activo and sim.volumen_total() < 0.0001)
	_correr(fa)
	var rec_a: float = fa.recorrido / cas                # se lee ANTES de esperar: el hechizo se libera solo al cumplirse
	var fin_a: String = fa.motivo_fin
	await create_timer(0.9).timeout                  # el agua entra cuando la masa ha caído (t_caida ≤ 0,8 s, temporizador real)
	for _i in range(int((HechizoVivo.T_LLENADO_V2 + 0.3) / DT)):
		sim.paso(DT)
	_ok("vida: flecha de agua llega (%.2f casillas, «%s») y forma charco (%.3f u³ en AguaSim)" % [rec_a, fin_a, sim.volumen_total()], fin_a == "alcance" and sim.volumen_total() > 0.01)
	_ok("vida: ...y luego desaparece (permanencia 0)", not is_instance_valid(fa) or (not fa.quedandose and fa.is_queued_for_deletion()))

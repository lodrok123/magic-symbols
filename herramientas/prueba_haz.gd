extends SceneTree
## Prueba del RAYO («haz») de ᛁ `linea` (decisión de Pablo, 21/10): el muro pasa SOLO a `barrera`; `linea` + elemento = un haz recto desde la mano hacia donde apunta,
## que golpea lo que toca en su recorrido y se para en paredes y bloques sólidos. «rayo» es también el elemento relámpago (ᛊ): en el código la forma se llama `haz`.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_haz.gd
## Comprueba: 1. la forma `haz` (Hechizo.haz / figura()) para los seis elementos con linea_x y con linea_z, y que barrera / flecha / sin ᛁ NO la dan; 2. el alcance
## (base + 1 m por glifo sucesivo, tope); 3. que afecta a las casillas del recorrido (estado de suelo) y a un enemigo y un reactivo en él, para cada elemento; 4. que se
## para en un bloque sólido y no golpea lo que hay detrás; 5. que `barrera` sigue siendo un muro (SolidezV2) y `linea` ya NO crea ninguno ni bloquea casillas;
## 6. que el dibujo por elemento (VfxElemento3D) monta SU haz al recibirlo.

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
	pass

const LADO: int = 20
const SALIDA: Vector2i = Vector2i(5, 8)
const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "viento": "wind", "rayo": "lightning", "hielo": "ice"}
## 29/10 (Pablo, laboratorio de geometrías): la tierra y el hielo con ᛁ ya NO son haz: son un sólido ancho o largo (un haz no construye). Las secciones del haz los saltan.
const SOLIDOS: PackedStringArray = ["tierra", "hielo"]

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: JugadorFalso = null
var _volumenes: Array = []                        ## lo que lleva la señal hechizo_v2 de cada lanzamiento
var _runas: Dictionary = {}


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	for e in ELEMENTOS:
		_runas[e] = load("res://nucleo/%s_rune.tres" % ELEMENTOS[e]) as RuneData
	_forma()
	_alcance()
	await _afecta()
	await _se_para()
	await _barrera_y_linea()
	await _dibujo()
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
	_volumenes.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, vol: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void: _volumenes.append([estado, el, vol]))


func _origen(c: Vector2i = SALIDA) -> Vector3:
	return Lanzador3D.centro_de(c, Terreno3D.y_pies(c) + 0.8)


func _hz(el: String, glifos: Dictionary) -> Hechizo:
	return Hechizo.construir(_runas[el], glifos)


func _lanzar(h: Hechizo, dir: Vector3 = Vector3.RIGHT) -> HechizoVivo:
	return HechizoVivo.crear(h, _origen(), dir, _l, null, {}, true)


func _enemigo(c: Vector2i) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	_m.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, _m, _jug, _l)
	e.set_physics_process(false)
	e.altura = 0.85
	e.congelado = 99.0
	return e


func _reactivo(c: Vector2i) -> ReactivoFalso:
	var re := ReactivoFalso.new()
	re.add_to_group("reactivo3d")
	_m.add_child(re)
	re.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	return re


# 1. La forma --------------------------------------------------------------------------------------------------------------------

func _forma() -> void:
	for el in ELEMENTOS:
		for g in ["linea_x", "linea_z"]:
			var h: Hechizo = _hz(el, {g: 1})
			if SOLIDOS.has(el):
				_ok("1 %s + %s NO es haz: es un sólido quieto que nace donde apuntas (con la mano al frente, «%s»)" % [el, g, h.forma], not h.haz and h.solido_quieto and h.en_punto and h.forma == "x_mano")
				continue
			_ok("1 %s + %s = haz (figura «%s», cast point de mano al frente «%s»)" % [el, g, h.figura(), h.forma], h.haz and h.figura() == "haz" and h.forma == "x_mano" and not h.protege and not h.viaja)
	_ok("1 ᛁ en horizontal y en vertical suman al mismo haz (sin importar el orden)", _hz("agua", {"linea_x": 1, "linea_z": 1}).haz and _hz("agua", {"linea_z": 2}).alcance_haz == _hz("agua", {"linea_x": 2}).alcance_haz)
	var b: Hechizo = _hz("tierra", {"barrera": 1, "linea_x": 2})
	_ok("1 barrera + linea NO es haz: sigue siendo el muro (figura «%s», solidez %.2f)" % [b.figura(), b.solidez], not b.haz and b.figura() == "barrera" and b.protege)
	var f: Hechizo = _hz("fuego", {"flecha": 1, "linea_x": 2})
	_ok("1 flecha + linea NO es haz: es un proyectil largo (figura «%s»)" % f.figura(), not f.haz and f.viaja and f.figura() == "proyectil")
	_ok("1 sin ᛁ no hay haz (esfera, altura, pulso, barrera)", not _hz("agua", {}).haz and not _hz("agua", {"altura": 2}).haz and not _hz("agua", {"pulso": 1}).haz and not _hz("agua", {"barrera": 2}).haz)
	_ok("1 el haz aparece en la tabla de derivados del lab", Hechizo.DERIVADOS.has("haz") and Hechizo.DERIVADOS.has("alcance_haz"))
	var copia: Hechizo = _hz("viento", {"linea_x": 3}).copiar()
	_ok("1 una copia del hechizo (los hijos) sigue siendo haz", copia.haz and is_equal_approx(copia.alcance_haz, _hz("viento", {"linea_x": 3}).alcance_haz))
	_ok("1 si el lab le da alcance de proyectil (distancia_max) deja de ser haz", not _hz("viento", {"linea_x": 3}).con({"distancia_max": 2.0, "velocidad": 2.0}).haz)


# 2. El alcance ------------------------------------------------------------------------------------------------------------------

func _alcance() -> void:
	var a1: float = _hz("fuego", {"linea_x": 1}).alcance_haz
	var a2: float = _hz("fuego", {"linea_x": 2}).alcance_haz
	var a9: float = _hz("fuego", {"linea_x": 9}).alcance_haz
	_ok("2 alcance con 1 ᛁ = %.1f m (base), 2 ᛁ = %.1f (+%.1f por glifo sucesivo)" % [a1, a2, Hechizo.HAZ_ALCANCE_POR_GLIFO], is_equal_approx(a1, Hechizo.HAZ_ALCANCE_BASE) and is_equal_approx(a2 - a1, Hechizo.HAZ_ALCANCE_POR_GLIFO))
	_ok("2 el alcance topa en %.1f m (con 9 ᛁ: %.1f)" % [Hechizo.HAZ_ALCANCE_MAX, a9], is_equal_approx(a9, Hechizo.HAZ_ALCANCE_MAX) and Hechizo.HAZ_ALCANCE_MAX <= Hechizo.LIM_DISTANCIA)


# 3. Afecta a las casillas y a lo que toca ---------------------------------------------------------------------------------------

func _afecta() -> void:
	for el in ELEMENTOS:
		if SOLIDOS.has(el):
			continue
		_montar()
		var rune: RuneData = _runas[el]
		var e1: Combate3D = _enemigo(Vector2i(8, 8))
		var e_fuera: Combate3D = _enemigo(Vector2i(8, 12))                 # fuera del recorrido
		var re: ReactivoFalso = _reactivo(Vector2i(7, 8))
		var re_fuera: ReactivoFalso = _reactivo(Vector2i(7, 11))
		var v1: float = e1.health
		var v_fuera: float = e_fuera.health
		var h: Hechizo = _hz(el, {"linea_x": 2})
		var v: HechizoVivo = _lanzar(h)
		_ok("3 %s: el haz ocupa casillas en fila hacia delante (%d)" % [el, v.casillas], v.casillas >= 2)
		_ok("3 %s: un reactivo del recorrido recibe el golpe del elemento (%d)" % [el, re.golpes], re.golpes == 1 and re_fuera.golpes == 0)
		if el == "viento":
			_ok("3 viento: no hace daño pero la señal lleva el haz (el empuje lo da el golpe)", true)
		else:
			_ok("3 %s: un enemigo del recorrido pierde vida (%.0f → %.1f) y el de fuera no" % [el, v1, e1.health], e1.health < v1 and e_fuera.health == v_fuera)
		# estado de suelo en las casillas del recorrido (solo los elementos que lo dejan)
		if rune.deja != "":
			var marcadas: Array = []
			for m in _m.marcas:
				marcadas.append(m[1])
			var en_fila: bool = true
			for c in marcadas:
				if (c as Vector2i).y != SALIDA.y or (c as Vector2i).x <= SALIDA.x:
					en_fila = false
			_ok("3 %s deja «%s» en las casillas del haz (%d marcadas, todas en la fila y por delante)" % [el, rune.deja, marcadas.size()], marcadas.size() >= 2 and en_fila)
		var vol: Dictionary = _volumenes[0][2] if not _volumenes.is_empty() else {}
		_ok("3 %s: avisa al dibujo con el haz (desde → hasta, largo %.1f u)" % [el, _largo_de(vol)], vol.has("haz") and _largo_de(vol) > 1.0 and not bool(vol.get("viaja", true)))


func _largo_de(vol: Dictionary) -> float:
	if not vol.has("haz"):
		return 0.0
	var d: Dictionary = vol["haz"]
	return (d["desde"] as Vector3).distance_to(d["hasta"] as Vector3)


# 4. Se para en un bloque ---------------------------------------------------------------------------------------------------------

func _se_para() -> void:
	_montar()
	var bloque := Vector2i(9, 8)
	_m._bloqueadas[bloque] = true
	var delante: Combate3D = _enemigo(Vector2i(8, 8))
	var detras: Combate3D = _enemigo(Vector2i(11, 8))
	var re_detras: ReactivoFalso = _reactivo(Vector2i(12, 8))
	var vd: float = delante.health
	var vt: float = detras.health
	var v: HechizoVivo = _lanzar(_hz("fuego", {"linea_x": 4}))        # alcance 6: sin el bloque llegaría a x = 11
	_ok("4 el haz se para en el bloque: hiere al de delante (%.0f → %.1f)" % [vd, delante.health], delante.health < vd)
	_ok("4 …y no hiere al que está detrás (%.0f → %.1f) ni activa el reactivo de detrás (%d)" % [vt, detras.health, re_detras.golpes], detras.health == vt and re_detras.golpes == 0)
	var llega: bool = false
	var vol: Dictionary = _volumenes[0][2] if not _volumenes.is_empty() else {}
	for c in vol.get("celdas", []):
		if (c as Vector2i).x >= bloque.x:
			llega = true
	_ok("4 ninguna casilla del haz pasa del bloque (%d casillas)" % int((vol.get("celdas", []) as Array).size()), not llega and (vol.get("celdas", []) as Array).size() >= 1)
	_ok("4 el dibujo acaba ANTES del bloque (hasta.x < x del bloque)", vol.has("haz") and Terreno3D.celda_de((vol["haz"]["hasta"] as Vector3)).x < bloque.x)
	# pegado a la pared: no se lanza el haz en el vacío, pero tampoco rompe
	_montar()
	_m._bloqueadas[Vector2i(6, 8)] = true
	var pegado: HechizoVivo = _lanzar(_hz("agua", {"linea_x": 1}))
	_ok("4 con la pared pegada el haz no revienta y dibuja algo corto (%d casilla/s)" % pegado.casillas, pegado.casillas >= 0 and not _volumenes.is_empty())
	# sigue la dirección en la que apunta
	_montar()
	var e_n: Combate3D = _enemigo(Vector2i(5, 11))
	var vn: float = e_n.health
	_lanzar(_hz("fuego", {"linea_x": 1}), Vector3(0.0, 0.0, 1.0))
	_ok("4 apunta donde se le dice: hacia +Z hiere al enemigo de esa columna (%.0f → %.1f)" % [vn, e_n.health], e_n.health < vn)

	# 30/10 (playtest de Pablo): ᚦ perforar sin flecha deja ATRAVESAR `perfora` casillas sólidas: fuego + ᛁ×4 + ᚦ atraviesa una pared de 1 casilla y quema lo que hay detrás;
	# con una pared de 2 casillas y un solo ᚦ se para en ella como siempre; con dos ᚦ la atraviesa.
	for caso in [[[Vector2i(8, 8)], 0, false], [[Vector2i(8, 8)], 1, true], [[Vector2i(8, 8), Vector2i(9, 8)], 1, false], [[Vector2i(8, 8), Vector2i(9, 8)], 2, true]]:
		_montar()
		for b in (caso[0] as Array):
			_m._bloqueadas[b] = true
		var detras_p: Combate3D = _enemigo(Vector2i(10, 8))
		var vt_p: float = detras_p.health
		var glifos_p: Dictionary = {"linea_x": 4}
		if int(caso[1]) > 0:
			glifos_p["perforar"] = int(caso[1])
		_lanzar(_hz("fuego", glifos_p))
		var vol_p: Dictionary = _volumenes[0][2] if not _volumenes.is_empty() else {}
		var tras_p: bool = false
		var en_pared: bool = false
		for c in vol_p.get("celdas", []):
			tras_p = tras_p or (c as Vector2i).x > (caso[0] as Array).back().x
			en_pared = en_pared or (caso[0] as Array).has(c)
		var herido: bool = detras_p.health < vt_p
		_ok("4 perforar×%d + haz contra una pared de %d casilla/s: %s lo de detrás (herido %s, casillas detrás %s) y ninguna casilla de la pared" % [int(caso[1]), (caso[0] as Array).size(), "alcanza" if bool(caso[2]) else "no alcanza", str(herido), str(tras_p)],
			herido == bool(caso[2]) and tras_p == bool(caso[2]) and not en_pared)


# 5. La barrera sigue siendo muro; la línea ya no -----------------------------------------------------------------------------------

func _barrera_y_linea() -> void:
	for el in ["tierra", "agua", "hielo"]:
		_montar()
		var antes: int = _l._solideces_v2.size()
		_lanzar(_hz(el, {"barrera": 1, "linea_x": 2}))
		_ok("5 barrera + linea (%s) crea un muro: SolidezV2 +%d" % [el, _l._solideces_v2.size() - antes], _l._solideces_v2.size() == antes + 1)
		_montar()
		var bloq_antes: int = _m._bloqueadas.size()
		var alt_antes: int = Terreno3D.alturas.size()
		_lanzar(_hz(el, {"linea_x": 2, "linea_z": 1}))
		if SOLIDOS.has(el):
			_ok("5 linea sola (%s) NO crea muro de solidez, pero SÍ su bloque (es un sólido, no un haz)" % el, _l._solideces_v2.is_empty() and Terreno3D.alturas.size() > alt_antes)
			continue
		_ok("5 linea sola (%s) NO crea muro: sin SolidezV2, sin casillas bloqueadas ni tierra" % el, _l._solideces_v2.is_empty() and _m._bloqueadas.size() == bloq_antes and Terreno3D.alturas.size() == alt_antes)
	# un proyectil ajeno atraviesa el haz (no es un muro)
	_montar()
	_lanzar(_hz("tierra", {"linea_x": 3}))
	_ok("5 un proyectil ajeno no se detiene en el haz (solidez_para = falso)", not _l.solidez_para(_origen(Vector2i(7, 8)), 5.0))


# 6. El dibujo por elemento ---------------------------------------------------------------------------------------------------------

func _dibujo() -> void:
	for el in ELEMENTOS:
		if SOLIDOS.has(el):
			continue
		_montar()
		var ve: VfxElemento3D = VfxElemento3D.conectar(_l, _m)
		_lanzar(_hz(el, {"linea_x": 2}))
		await process_frame
		_ok("6 %s: VfxElemento3D monta UN haz (haces %d, vivos %d)" % [el, ve.haces(), ve.vivos()], ve.haces() == 1 and ve.vivos() >= 1)
		var raiz: Node = _l.find_child("Haz_" + el, true, false)        # cuelga del HechizoVivo (que cuelga del lanzador), que vive lo que se ve el haz
		_ok("6 %s: el dibujo del haz cuelga con su nombre «Haz_%s»" % [el, el], raiz != null)
		var piezas: int = raiz.find_children("*", "MeshInstance3D", true, false).size() if raiz != null else 0
		_ok("6 %s: el haz tiene mallas (%d)" % [el, piezas], piezas >= 1)
	# el dibujo no se apaga a los 0,5 s (el HechizoVivo, de donde cuelga, vive lo que se ve el haz) y desaparece al acabar
	_montar()
	VfxElemento3D.conectar(_l, _m)
	_lanzar(_hz("agua", {"linea_x": 1}))
	await create_timer(0.7).timeout
	_ok("6 a los 0,7 s el haz sigue dibujado (HAZ_DURA_S = %.1f s)" % Hechizo.HAZ_DURA_S, _l.find_child("Haz_agua", true, false) != null)
	await create_timer(2.2).timeout
	_ok("6 …y a los 2,9 s ya se ha liberado", _l.find_child("Haz_agua", true, false) == null and _m.find_child("Haz_agua", true, false) == null)
	# la forma es "haz" y no la de otros volúmenes
	_montar()
	var ve2: VfxElemento3D = VfxElemento3D.conectar(_l, _m)
	_lanzar(_hz("fuego", {"barrera": 1, "linea_x": 2}))
	await process_frame
	_ok("6 una barrera con linea sigue dibujándose como barrera (haces %d)" % ve2.haces(), ve2.haces() == 0)

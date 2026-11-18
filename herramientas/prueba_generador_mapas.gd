extends SceneTree
## Prueba del GENERADOR DE MAPAS (17/11/2026), sin ventana y sin escribir nada en el repo:
##   godot --headless --path . --script res://herramientas/prueba_generador_mapas.gd
## 1. Los tres algoritmos, con 40 semillas cada uno y sus valores por defecto: el mapa pasa `ExportadorMapa.validar` (un solo inicio, borde de
##    pared, todo lo que se pisa se alcanza desde el inicio, piezas sobre suelo y con id único).
## 2. Variantes de parámetros que fuerzan los casos raros (formas, pasillo de 1 y de 3, sin podar, cueva muy cerrada, mucha agua, sin simetría…).
## 3. Misma semilla = mismo mapa; semillas distintas = mapas distintos.
## 4. La TIERRA es una sola pieza aun contando lo que bloquea (cofres, jarrones, braseros): un enemigo que no nada llega a todas partes.
## 5. La llave del tesoro se alcanza sin cruzar la puerta que abre.
## 6. Los retoques a mano se aplican y el mapa sigue siendo válido aunque partan el mapa en dos.
## 7. El texto exportado: las filas son lo primero, la cabecera lleva los parámetros y de ellos vuelve a salir el mismo mapa; la escena nombra el nivel.
## 8. Nombres de nivel: se rechazan los que no valen y no se pisa un mapa hecho a mano (Cueva).

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")
const SEMILLAS: int = 40
const VARIANTES: Array = [
	{"algoritmo": "salas", "forma": "caja"}, {"algoritmo": "salas", "forma": "cruz"}, {"algoritmo": "salas", "forma": "redonda", "ancho": 50, "alto": 50},
	{"algoritmo": "salas", "ancho_pasillo": 1, "callejones": 0, "recto": 0}, {"algoritmo": "salas", "ancho_pasillo": 3, "ancho": 60, "alto": 50},
	{"algoritmo": "salas", "reparto": "densas", "puertas": 150}, {"algoritmo": "salas", "sala_min": 5, "sala_max": 8, "ancho": 20, "alto": 20},
	{"algoritmo": "salas", "puertas": 0, "callejones": 100, "charcas": 100, "salas_cerradas": 100, "enemigos": 3.0, "jarrones": 4.0, "braseros": 3.0},
	{"algoritmo": "salas", "tesoro": false}, {"algoritmo": "salas", "llave": false, "enemigos": 0.0}, {"algoritmo": "salas", "ancho": 12, "alto": 12},
	{"algoritmo": "cueva", "relleno": 55}, {"algoritmo": "cueva", "relleno": 35, "agua": 40}, {"algoritmo": "cueva", "suavizados": 0, "region_min": 1},
	{"algoritmo": "cueva", "ancho": 90, "alto": 70, "agua": 20}, {"algoritmo": "cueva", "silueta": 0}, {"algoritmo": "cueva", "silueta": 100, "relleno": 50}, {"algoritmo": "cueva", "ancho": 12, "alto": 12},
	{"algoritmo": "pagina", "simetria": false, "bucles": 100}, {"algoritmo": "pagina", "n_salas": 30, "ancho": 70, "alto": 60, "pasillos": 60},
	{"algoritmo": "pagina", "n_salas": 40, "ancho": 15, "alto": 15}, {"algoritmo": "pagina", "lado_min": 2, "lado_max": 3, "salas_cerradas": 100, "charcas": 100},
	{"algoritmo": "pagina", "salida_a": "Bosque_02:boca_cueva", "estilo": "bosque", "luz": "bosque"},
	{"algoritmo": "cueva", "metodo": "automata"}, {"algoritmo": "cueva", "octavas": 6, "tamano_sala": 6.0}, {"algoritmo": "cueva", "octavas": 1, "tamano_sala": 30.0, "silueta": 100},
	{"algoritmo": "salas", "salida_a": "Bosque_02:boca_cueva, MonteSumicio:inicio, Cueva:desde_bosque"}, {"algoritmo": "cueva", "salida_a": "A:b,C:d;E:f G:h"},
	{"algoritmo": "pagina", "n_salas": 3, "salida_a": "A:b,C:d,E:f,G:h,I:j"},
	{"algoritmo": "salas", "puzles": 4}, {"algoritmo": "pagina", "puzles": 6, "barreras": 4}, {"algoritmo": "cueva", "puzles": 3},
]

var _fallos: int = 0
var _hechas: int = 0


func _initialize() -> void:
	var t0: int = Time.get_ticks_msec()
	_por_defecto()
	_variantes()
	_reproducible()
	_retoques()
	_texto()
	_nombres()
	_enlaces_a_mano()
	_catalogo()
	_mover_elementos()
	print("%d comprobaciones en %d ms" % [_hechas, Time.get_ticks_msec() - t0])
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _ok(bien: bool, texto: String, info: String = "") -> void:
	_hechas += 1
	if not bien:
		_fallos += 1
		print("FALLO " + texto + "  " + info)


func _resumen(texto: String, antes: int) -> void:
	print(("OK    " if _fallos == antes else "FALLO ") + texto)


## Todas las comprobaciones de un mapa. Devuelve el mapa.
func _revisar(par: Dictionary, retoques: Dictionary = {}, puzles: Dictionary = {}, movidos: Dictionary = {}) -> Dictionary:
	var m: Dictionary = Generador.new().generar(par, retoques, {}, puzles, movidos)
	var quien: String = "%s semilla %d %s" % [String(m["parametros"]["algoritmo"]), int(m["parametros"]["semilla"]), str(par)]
	var err: PackedStringArray = Exportador.validar(m)
	_ok(err.is_empty(), "validar: " + quien, "; ".join(err))
	if not err.is_empty():
		return m
	var filas: PackedStringArray = m["filas"]
	var w: int = int(m["ancho"])
	var h: int = int(m["alto"])
	_ok(w <= 120 and h <= 120 and w >= 12 and h >= 12, "tamaño dentro de límites: " + quien, "%d × %d" % [w, h])
	# 4 · Tierra de una pieza contando los bloqueos.
	var bloquea: Dictionary = {}
	var puentes: Dictionary = {}
	var puerta_llave: Vector2i = Vector2i(-1, -1)
	var cofre_llave: Vector2i = Vector2i(-1, -1)
	for o in m["objetos"]:
		match String(o["tipo"]):
			"cofre_tesoro", "cofre_llave", "jarron", "brasero":
				bloquea[o["c"]] = true                 # el bloque no: se empuja, y su pista (lo que hay detrás de él) se pisa al empujarlo
			_:
				pass
		if String(o["tipo"]) == "puerta_llave":
			puerta_llave = o["c"]
		if String(o["tipo"]) == "cofre_llave":
			cofre_llave = o["c"]
	for cz in m["cruzables"]:                  # agua con puente o de un puzle de paso: cuenta como tierra (se cruza al resolverlo)
		puentes[cz] = true
	var tierra: int = 0
	for y in range(h):
		for x in range(w):
			if filas[y][x] != "#" and (filas[y][x] != "~" or puentes.has(Vector2i(x, y))) and not bloquea.has(Vector2i(x, y)):
				tierra += 1
	var filas_puente: PackedStringArray = filas.duplicate()
	for c in puentes:
		filas_puente[c.y] = filas_puente[c.y].substr(0, c.x) + "." + filas_puente[c.y].substr(c.x + 1)
	var alcanzo: Dictionary = _relleno(filas_puente, m["inicio"], bloquea, true)
	# Barreras: sin errores, cada una con su vínculo, y cada puente sobre agua.
	_ok((m["errores"] as PackedStringArray).is_empty(), "el generador no da errores de barreras: " + quien, "; ".join(m["errores"]))
	var n_enlaces: int = 0
	for en in m["enlaces"]:
		if not bool(en["fijo"]):
			n_enlaces += 1
			_ok((en["de"] as Vector2i).x >= 0, "la barrera %s tiene activador: %s" % [String(en["a_id"]), quien])
			_ok(String(en["de_id"]).begins_with("cat"), "el activador de %s sale del catálogo: %s" % [String(en["a_id"]), quien], String(en["de_id"]))
	# Regla de la Sala del Empuje: todo bloque vive en una pista de una casilla cerrada por paredes (no se puede arrinconar).
	for l in m["lineas"]:
		var tl: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if tl.size() >= 5 and tl[0] == "pieza" and tl[2] == "bloque":
			var bx: int = tl[3].to_int()
			var by: int = tl[4].to_int()
			# La pista va de abajo arriba (paredes a izquierda y derecha): tumbada, la pared de delante la tapa en el juego.
			_ok(filas[by][bx - 1] == "#" and filas[by][bx + 1] == "#",
				"el bloque %s está en una pista vertical cerrada por paredes: %s" % [tl[1], quien], "(%d, %d)" % [bx, by])
			# Dentro de la pista no hay nada más (un goblin entre el bloque y la placa lo pararía); arriba acaba en pared y abajo está abierta.
			for paso_y in [-1, 1]:
				var y: int = by + int(paso_y)
				while y > 0 and y < h - 1 and filas[y][bx] != "#" and filas[y][bx - 1] == "#" and filas[y][bx + 1] == "#":
					_ok(".gR".contains(filas[y][bx]), "la pista del bloque %s está despejada: %s" % [tl[1], quien], "(%d, %d) = %s" % [bx, y, filas[y][bx]])
					y += int(paso_y)
				_ok((filas[y][bx] == "#") == (int(paso_y) < 0), "la pista del bloque %s se cierra arriba y se abre abajo: %s" % [tl[1], quien], "(%d, %d) = %s" % [bx, y, filas[y][bx]])
	_ok(n_enlaces == int(m["barreras"]), "un vínculo por barrera: " + quien, "%d vínculos, %d barreras" % [n_enlaces, int(m["barreras"])])
	for c in puentes:
		_ok(filas[c.y][c.x] == "~", "el puente está sobre agua: " + quien)
	_ok(alcanzo.size() == tierra, "la tierra es una sola pieza (con bloqueos): " + quien, "%d de %d" % [alcanzo.size(), tierra])
	# 5 · La llave, sin cruzar su puerta.
	_ok((puerta_llave.x >= 0) == (cofre_llave.x >= 0), "puerta con llave y cofre de la llave van juntos: " + quien)
	if puerta_llave.x >= 0 and cofre_llave.x >= 0:
		var sin: Dictionary = _relleno(filas, m["inicio"], {puerta_llave: true}, false)
		var junto: bool = false
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			junto = junto or sin.has(cofre_llave + d)
		_ok(junto, "la llave se alcanza sin cruzar la puerta del tesoro: " + quien)
		var tesoro: Vector2i = Vector2i(-1, -1)
		for o in m["objetos"]:
			if String(o["tipo"]) == "cofre_tesoro":
				tesoro = o["c"]
		_ok(tesoro.x >= 0 and not sin.has(tesoro), "el tesoro queda detrás de la puerta con llave: " + quien)
	# Cada vigía tiene enemigos dentro de su zona; cada cerrojo, su vigía y su regla.
	var txt: String = "\n".join(m["lineas"])
	for linea in m["lineas"]:
		var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
		# Puzle3D solo acepta flags de tres partes (nivel.sala.hecho): lo cazó escenario_generador_mapas con la escena de verdad.
		for k in t:
			for clave in ["llave=", "abierto=", "flag=", "hasta=", "aparece_si=flag."]:
				if k.begins_with(clave):
					_ok(k.substr(clave.length()).split(".").size() == 3, "la flag de «%s» tiene tres partes: %s" % [k, quien])
		if t.size() >= 5 and t[2] == "vigia":
			var de: String = ""
			for k in t:
				if k.begins_with("de="):
					de = k.substr(3)
			var r: PackedStringArray = de.replace("..", ",").split(",")
			var n: int = 0
			if r.size() == 4:
				for y in range(r[1].to_int(), r[3].to_int() + 1):
					for x in range(r[0].to_int(), r[2].to_int() + 1):
						if filas[y][x] == "W" or filas[y][x] == "A":
							n += 1
			_ok(n > 0, "el vigía %s tiene enemigos en su zona: %s" % [t[1], quien])
		if t.size() >= 5 and t[2] == "cerrojo":
			var num: String = t[1].trim_prefix("cerrojo_")
			_ok(txt.contains("vigia_%s vigia" % num) and txt.contains("hace=cerrojo_%s.abrir" % num), "el cerrojo %s tiene vigía y regla que lo abre: %s" % [t[1], quien])
	return m


## Casillas alcanzables desde `desde`. `solo_tierra`: el agua no se cruza.
func _relleno(filas: PackedStringArray, desde: Vector2i, bloquea: Dictionary, solo_tierra: bool) -> Dictionary:
	var visto: Dictionary = {desde: true}
	var cola: Array = [desde]
	var k: int = 0
	while k < cola.size():
		var c: Vector2i = cola[k]
		k += 1
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var v: Vector2i = c + d
			if v.y < 0 or v.y >= filas.size() or v.x < 0 or v.x >= filas[v.y].length() or visto.has(v) or bloquea.has(v):
				continue
			var ch: String = filas[v.y][v.x]
			if ch == "#" or (solo_tierra and ch == "~"):
				continue
			visto[v] = true
			cola.append(v)
	return visto


func _por_defecto() -> void:
	for alg in Generador.ALGORITMOS:
		var antes: int = _fallos
		var salas: int = 0
		var enemigos: int = 0
		var con_llave: int = 0
		var ms: int = Time.get_ticks_msec()
		for s in range(1, SEMILLAS + 1):
			var m: Dictionary = _revisar({"algoritmo": alg, "semilla": s})
			salas += int(m["stats"]["salas"])
			enemigos += int(m["stats"]["enemigos"])
			if "\n".join(m["lineas"]).contains("puerta_tesoro"):
				con_llave += 1
			_ok(int(m["stats"]["salas"]) >= 2, "al menos dos salas: %s semilla %d" % [alg, s])
		_resumen("1 «%s»: %d semillas válidas (media %.1f salas, %.1f enemigos; %d con puerta de llave; %d ms por mapa)" % [alg, SEMILLAS, salas / float(SEMILLAS),
			enemigos / float(SEMILLAS), con_llave, (Time.get_ticks_msec() - ms) / SEMILLAS], antes)


func _variantes() -> void:
	var antes: int = _fallos
	for v in VARIANTES:
		for s in range(1, 9):
			var par: Dictionary = (v as Dictionary).duplicate()
			par["semilla"] = s * 101
			_revisar(par)
	_resumen("2 %d variantes de parámetros × 8 semillas, todas válidas" % VARIANTES.size(), antes)


func _reproducible() -> void:
	var antes: int = _fallos
	for alg in Generador.ALGORITMOS:
		var a: Dictionary = Generador.new().generar({"algoritmo": alg, "semilla": 12345})
		var b: Dictionary = Generador.new().generar({"algoritmo": alg, "semilla": 12345})
		var c: Dictionary = Generador.new().generar({"algoritmo": alg, "semilla": 12346})
		_ok("\n".join(a["filas"]) == "\n".join(b["filas"]) and "\n".join(a["lineas"]) == "\n".join(b["lineas"]), "misma semilla, mismo mapa: " + alg)
		_ok("\n".join(a["filas"]) != "\n".join(c["filas"]), "otra semilla, otro mapa: " + alg)
	_resumen("3 misma semilla = mismo mapa; otra semilla = otro mapa", antes)


func _retoques() -> void:
	var antes: int = _fallos
	for alg in Generador.ALGORITMOS:
		var base: Dictionary = Generador.new().generar({"algoritmo": alg, "semilla": 5})
		var w: int = int(base["ancho"])
		var h: int = int(base["alto"])
		# Un muro vertical por el centro (parte el mapa), agua en una fila y suelo en una esquina.
		var ret: Dictionary = {}
		for y in range(h):
			ret[Vector2i(w / 2, y)] = "#"
		for x in range(1, w / 2 - 1):
			ret[Vector2i(x, h / 2)] = "~"
		ret[Vector2i(0, 0)] = "."
		var m: Dictionary = _revisar({"algoritmo": alg, "semilla": 5}, ret)
		var filas: PackedStringArray = m["filas"]
		var muro: bool = true
		for y in range(h):
			muro = muro and filas[y][w / 2] == "#"
		_ok(muro, "el muro pintado a mano está en el mapa: " + alg)
		_ok(filas[0][0] == "#", "el borde no se puede abrir pintando: " + alg)
	_resumen("6 los retoques a mano se aplican y el mapa sigue siendo válido", antes)


## 9 · Enlazar a mano: soltar una barrera da error y no se exporta; darle la vuelta a dos enlaces o bien vale o bien da el error de «sin solución»,
## pero nunca un mapa válido que no se pueda completar; y el enlace a mano se guarda en el .txt y vuelve a salir.
func _enlaces_a_mano() -> void:
	var antes: int = _fallos
	var probados: int = 0
	for alg in Generador.ALGORITMOS:
		for s in range(1, 30):
			var par: Dictionary = {"algoritmo": alg, "semilla": s, "barreras": 3, "nombre": "PruebaEnlaces"}
			var m: Dictionary = Generador.new().generar(par)
			var barreras: Array = []
			for en in m["enlaces"]:
				if not bool(en["fijo"]):
					barreras.append(en)
			if barreras.is_empty():
				continue
			probados += 1
			var suelta: Dictionary = Generador.new().generar(par, {}, {String(barreras[0]["a_id"]): ""})
			var err: PackedStringArray = Exportador.validar(suelta)
			_ok(not err.is_empty() and "; ".join(err).contains(String(barreras[0]["a_id"])), "soltar %s da error: %s semilla %d" % [String(barreras[0]["a_id"]), alg, s], "; ".join(err))
			_ok(not bool(Exportador.exportar(suelta)["ok"]), "con una barrera suelta no se exporta: %s semilla %d" % [alg, s])
			_ok(not "\n".join(suelta["lineas"]).contains("hace=%s." % String(barreras[0]["a_id"])), "la barrera suelta no tiene regla: %s semilla %d" % [alg, s])
			if barreras.size() >= 2:
				var cruce: Dictionary = {String(barreras[0]["a_id"]): String(barreras[1]["de_id"]), String(barreras[1]["a_id"]): String(barreras[0]["de_id"])}
				var mc: Dictionary = Generador.new().generar(par, {}, cruce)
				var txt: String = "\n".join(mc["lineas"])
				_ok(txt.contains("cuando=%s." % String(barreras[1]["de_id"])) and txt.contains("cuando=%s." % String(barreras[0]["de_id"])), "el cruce de enlaces sale en las reglas: %s semilla %d" % [alg, s])
				_ok(Exportador.enlaces_de(Exportador.texto_mapa(mc)) == cruce, "los enlaces a mano se guardan en el .txt: %s semilla %d" % [alg, s])
				_ok(Exportador._sin_fecha(Exportador._regenerado(Exportador.texto_mapa(mc))) == Exportador._sin_fecha(Exportador.texto_mapa(mc)), "y de ahí vuelve a salir el mismo archivo: %s semilla %d" % [alg, s])
	_ok(probados >= 30, "hay mapas con barreras para probar", "%d" % probados)
	_resumen("9 enlazar a mano: lo suelto da error y no se exporta; los cambios se guardan (%d mapas)" % probados, antes)


## Cuántos objetos hay de cada tipo y cuántas letras de cada clase: mover no crea ni destruye nada.
func _censo(m: Dictionary) -> Dictionary:
	var res: Dictionary = {}
	for o in m["objetos"]:
		res[String(o["tipo"])] = int(res.get(String(o["tipo"]), 0)) + 1
	for fila in m["filas"]:
		for ch in ["S", "W", "A", "T"]:
			res["letra " + String(ch)] = int(res.get("letra " + String(ch), 0)) + String(fila).count(String(ch))
	return res


## 11 · Mover elementos a mano: cada tipo movible se lleva a un sitio bueno (queda justo ahí), a una pared (queda en el suelo válido
## más cercano), a la otra punta del mapa y encima de otra cosa. En todos los casos el mapa pasa TODAS las comprobaciones de siempre
## (válido, tierra de una pieza, llave alcanzable, barreras con solución), no aparece ni desaparece nada, y lo movido se guarda en el .txt.
func _mover_elementos() -> void:
	var antes: int = _fallos
	var probados: Dictionary = {}
	var exactos: int = 0
	var ajustados: int = 0
	var rechazados: int = 0
	for alg in Generador.ALGORITMOS:
		for s in range(1, 7):
			var par: Dictionary = {"algoritmo": alg, "semilla": s, "nombre": "PruebaMover", "barreras": 2, "salida_a": "Cueva:desde_bosque, MonteSumicio:inicio"}
			var base: Dictionary = Generador.new().generar(par)
			var filas: PackedStringArray = base["filas"]
			var w: int = int(base["ancho"])
			var h: int = int(base["alto"])
			var ocupadas: Dictionary = {}
			for o in base["objetos"]:
				ocupadas[o["c"]] = true
			var visto_tipo: Dictionary = {}
			for o in base["objetos"]:
				var tipo: String = String(o["tipo"])
				if not Generador.MOVIBLES.has(tipo) or String(o["id"]).begins_with("cat") or visto_tipo.has(tipo):
					continue
				visto_tipo[tipo] = true
				probados[tipo] = true
				var de: Vector2i = o["c"]
				# Destinos: el vecino libre más cercano, una pared pegada, la esquina opuesta del mapa y la casilla de otro objeto.
				var destinos: Array = [Vector2i(0, 0), Vector2i(w - 1 - de.x, h - 1 - de.y)]
				for r in range(1, 5):
					for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
						var c: Vector2i = de + d
						if c.x > 0 and c.y > 0 and c.x < w - 1 and c.y < h - 1 and filas[c.y][c.x] == "." and not ocupadas.has(c) and destinos.size() < 3:
							destinos.append(c)
				for otro in base["objetos"]:
					if (otro["c"] as Vector2i) != de and destinos.size() < 4:
						destinos.append(otro["c"])
				for a in destinos:
					var m: Dictionary = _revisar(par, {}, {}, {de: a})
					var quien: String = "%s semilla %d, %s de %s a %s" % [alg, s, tipo, de, a]
					_ok(_censo(m) == _censo(base), "mover no crea ni destruye nada: " + quien, "%s / %s" % [_censo(m), _censo(base)])
					var hechos: Dictionary = m["movidos"]
					if hechos.has(de):
						var fin: Vector2i = hechos[de]
						var esta: bool = false
						for o2 in m["objetos"]:
							esta = esta or ((o2["c"] as Vector2i) == fin and String(o2["tipo"]) == tipo)
						_ok(esta, "el elemento está donde dice que ha quedado: " + quien, str(fin))
						_ok(m["filas"][fin.y][fin.x] != "#" and m["filas"][fin.y][fin.x] != "~", "y ha quedado en suelo: " + quien, m["filas"][fin.y][fin.x])
						if fin == (a as Vector2i):
							exactos += 1
						else:
							ajustados += 1
							_ok("\n".join(m["avisos"]).contains("ha quedado en"), "si el sitio se ajusta, se avisa: " + quien)
						var texto: String = Exportador.texto_mapa(m)
						_ok(Exportador.movidos_de(texto) == hechos, "lo movido se guarda en el .txt: " + quien)
						_ok(Exportador._sin_fecha(Exportador._regenerado(texto)) == Exportador._sin_fecha(texto), "y de ahí vuelve a salir el mismo archivo: " + quien)
					else:
						rechazados += 1
						_ok("\n".join(m["avisos"]).contains("No se ha podido mover"), "si no se puede mover, se avisa: " + quien, "\n".join(m["avisos"]))
						_ok(m["filas"] == base["filas"], "y el mapa queda como estaba: " + quien)
	for tipo in Generador.MOVIBLES:
		_ok(probados.has(tipo), "se ha probado a mover un «%s»" % tipo)
	_ok(exactos > 50 and ajustados > 50, "hay casos de sitio exacto y de sitio ajustado", "%d exactos, %d ajustados, %d rechazados" % [exactos, ajustados, rechazados])
	# Un movimiento que apunta a una casilla donde ya no hay nada se descarta con aviso y no rompe.
	var huerfano: Dictionary = _revisar({"algoritmo": "salas", "semilla": 3, "nombre": "PruebaMover"}, {}, {}, {Vector2i(0, 0): Vector2i(5, 5)})
	_ok((huerfano["movidos"] as Dictionary).is_empty() and "\n".join(huerfano["avisos"]).contains("ya no hay nada"), "un movimiento sin elemento se descarta con aviso")
	_resumen("11 mover elementos a mano: %d en su sitio, %d ajustados al válido más cercano, %d rechazados" % [exactos, ajustados, rechazados], antes)


## 10 · Catálogo de puzles: cada plantilla se puede poner a mano en alguna sala y el mapa sigue siendo válido; sus líneas salen con el
## prefijo de la instancia y dentro del mapa; si no cabe, avisa y no rompe nada; en salas pequeñas el suelo se ajusta (se excava);
## los puzles a mano se guardan en el .txt.
func _catalogo() -> void:
	var antes: int = _fallos
	var cat: Dictionary = Catalogo.todos()
	_ok(cat.size() >= 4, "el catálogo carga sus plantillas", str(cat.keys()))
	for cid in cat:
		# Ninguna pared de la plantilla queda de punta (suelo por tres lados si la plantilla va en medio de una sala): en el juego esa
		# casilla es una pieza de esquina estrecha que deja un hueco visible (playtest de Pablo, 17/11).
		var fp: Array = cat[cid]["filas"]
		for y in range(fp.size()):
			for x in range(String(fp[y]).length()):
				if String(fp[y])[x] != "#":
					continue
				var abiertos: int = 0
				for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.y < 0 or q.y >= fp.size() or q.x < 0 or q.x >= String(fp[q.y]).length() or String(fp[q.y])[q.x] != "#":
						abiertos += 1
				_ok(abiertos <= 2, "ninguna pared de «%s» queda de punta" % cid, "(%d, %d) con %d lados abiertos" % [x, y, abiertos])
		var puestos: int = 0
		for alg in ["salas", "pagina"]:
			for s in range(1, 9):
				var par: Dictionary = {"algoritmo": alg, "semilla": s, "nombre": "PruebaCat"}
				var base: Dictionary = Generador.new().generar(par)
				for sala in base["salas"]:
					if String(sala["rol"]) == "inicio":
						continue
					var m: Dictionary = _revisar(par, {}, {int(sala["id"]): cid})
					if (m["puzles"] as Dictionary).get(int(sala["id"]), "") != cid:
						continue
					puestos += 1
					var txt: String = "\n".join(m["lineas"])
					_ok(txt.contains("cat1_") or (cat[cid]["lineas"] as Array).is_empty(), "las piezas de «%s» llevan el prefijo de la instancia" % cid)
					_ok(not txt.contains("$"), "no queda ningún comodín sin sustituir en «%s»" % cid, txt)
					_ok(Exportador.puzles_de(Exportador.texto_mapa(m)) == {int(sala["id"]): cid}, "el puzle a mano se guarda en el .txt: " + cid)
					break
		_ok(puestos >= 8, "«%s» se puede poner en al menos 8 de 16 mapas" % cid, "%d" % puestos)
	# Salas pequeñas (2-3 casillas): la plantilla de 5 × 3 no cabe y el suelo se ajusta.
	var excavados: int = 0
	for s in range(1, 13):
		var par2: Dictionary = {"algoritmo": "pagina", "semilla": s, "lado_min": 2, "lado_max": 3, "pasillos": 0, "n_salas": 6}
		var base2: Dictionary = Generador.new().generar(par2)
		for sala in base2["salas"]:
			if String(sala["rol"]) == "inicio":
				continue
			var m2: Dictionary = _revisar(par2, {}, {int(sala["id"]): "braseros_premio"})
			if (m2["puzles"] as Dictionary).has(int(sala["id"])):
				excavados += 1
				_ok("\n".join(m2["filas"]).count("#") < "\n".join(base2["filas"]).count("#"), "poner el puzle en una sala pequeña excava roca: semilla %d" % s)
				break
			else:
				_ok("\n".join(m2["avisos"]).contains("braseros_premio"), "si no cabe ni excavando, lo dice: semilla %d" % s, "\n".join(m2["avisos"]))
	_ok(excavados >= 8, "el autoajuste del suelo funciona en casi todas las semillas", "%d de 12" % excavados)
	var no: Dictionary = _revisar({"algoritmo": "salas", "semilla": 2}, {}, {999: "rio_lava", 1: "no_existe"})
	_ok((no["avisos"] as PackedStringArray).size() >= 2 and (no["puzles"] as Dictionary).is_empty(), "una sala o un puzle que no existen avisan y no rompen", "\n".join(no["avisos"]))
	_resumen("10 catálogo de puzles: %d plantillas, a mano, con autoajuste del suelo" % cat.size(), antes)


func _texto() -> void:
	var antes: int = _fallos
	for alg in Generador.ALGORITMOS:
		var ret: Dictionary = {Vector2i(3, 3): ".", Vector2i(4, 3): "~"} if alg == "cueva" else {}
		var m: Dictionary = Generador.new().generar({"algoritmo": alg, "semilla": 77, "nombre": "PruebaTexto"}, ret)
		var txt: String = Exportador.texto_mapa(m)
		var lineas: PackedStringArray = txt.split("\n")
		var bien: bool = true
		for y in range(int(m["alto"])):
			bien = bien and lineas[y] == (m["filas"] as PackedStringArray)[y]
		_ok(bien, "las filas del plano son las primeras líneas del .txt: " + alg)
		var comentarios: bool = true
		for y in range(int(m["alto"]), lineas.size()):
			comentarios = comentarios and (lineas[y] == "" or lineas[y].begins_with(";"))
		_ok(comentarios, "todo lo demás son líneas «;»: " + alg)
		_ok(txt.contains(Exportador.MARCA) and txt.contains("; zona 1,1.."), "lleva la marca del generador y la zona: " + alg)
		var par: Dictionary = Exportador.parametros_de(txt)
		_ok(int(par.get("semilla", -1)) == 77 and String(par.get("algoritmo", "")) == alg, "la cabecera guarda los parámetros: " + alg)
		_ok(Exportador.retoques_de(txt).size() == ret.size(), "la cabecera guarda los retoques: " + alg)
		_ok(Exportador._sin_fecha(Exportador._regenerado(txt)) == Exportador._sin_fecha(txt), "de la cabecera vuelve a salir el mismo archivo: " + alg)
		var esc: String = Exportador.texto_escena(m)
		_ok(esc.contains("nivel = \"PruebaTexto\"") and esc.contains("res://escenas/puzle.gd") and esc.contains(Exportador.MARCA_ESCENA), "la escena nombra el nivel y cuelga Puzles: " + alg)
		_ok(esc.contains("arqueros = true") == bool(m["arqueros"]), "la escena pide arqueros solo si hay letras A: " + alg)
	_resumen("7 el texto exportado (plano, cabecera, parámetros, escena)", antes)


func _nombres() -> void:
	var antes: int = _fallos
	for malo in ["", "con espacio", "ñandú", "9nueve", "a.b", "a/b"]:
		_ok(Exportador.nombre_valido(malo) != "", "nombre rechazado: «%s»" % malo)
	for bueno in ["MazmorraGen", "Cripta_02", "x"]:
		_ok(Exportador.nombre_valido(bueno) == "", "nombre aceptado: «%s»" % bueno)
	var est: Dictionary = Exportador.estado_destino("cueva")
	_ok(String(est["mapa"]).ends_with("Cueva.txt") and not bool(est["mapa_nuestro"]), "«cueva» se reconoce como el mapa hecho a mano Cueva.txt", str(est))
	var m: Dictionary = Generador.new().generar({"nombre": "Cueva"})
	var res: Dictionary = Exportador.exportar(m)
	_ok(not bool(res["ok"]) and (res["escritos"] as Array).is_empty(), "exportar sobre un mapa hecho a mano se niega y no escribe nada", String(res["error"]))
	_resumen("8 nombres de nivel y protección de los mapas hechos a mano", antes)

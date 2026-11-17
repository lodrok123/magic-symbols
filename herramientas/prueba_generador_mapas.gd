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
const SEMILLAS: int = 40
const VARIANTES: Array = [
	{"algoritmo": "salas", "forma": "caja"}, {"algoritmo": "salas", "forma": "cruz"}, {"algoritmo": "salas", "forma": "redonda", "ancho": 50, "alto": 50},
	{"algoritmo": "salas", "ancho_pasillo": 1, "callejones": 0, "recto": 0}, {"algoritmo": "salas", "ancho_pasillo": 3, "ancho": 60, "alto": 50},
	{"algoritmo": "salas", "reparto": "densas", "puertas": 150}, {"algoritmo": "salas", "sala_min": 5, "sala_max": 8, "ancho": 20, "alto": 20},
	{"algoritmo": "salas", "puertas": 0, "callejones": 100, "charcas": 100, "salas_cerradas": 100, "enemigos": 3.0, "jarrones": 4.0, "braseros": 3.0},
	{"algoritmo": "salas", "tesoro": false}, {"algoritmo": "salas", "llave": false, "enemigos": 0.0}, {"algoritmo": "salas", "ancho": 12, "alto": 12},
	{"algoritmo": "cueva", "relleno": 55}, {"algoritmo": "cueva", "relleno": 35, "agua": 40}, {"algoritmo": "cueva", "suavizados": 0, "region_min": 1},
	{"algoritmo": "cueva", "ancho": 90, "alto": 70, "agua": 20}, {"algoritmo": "cueva", "ancho": 12, "alto": 12},
	{"algoritmo": "pagina", "simetria": false, "bucles": 100}, {"algoritmo": "pagina", "n_salas": 30, "ancho": 70, "alto": 60, "pasillos": 60},
	{"algoritmo": "pagina", "n_salas": 40, "ancho": 15, "alto": 15}, {"algoritmo": "pagina", "lado_min": 2, "lado_max": 3, "salas_cerradas": 100, "charcas": 100},
	{"algoritmo": "pagina", "salida_a": "Bosque_02:boca_cueva", "estilo": "bosque", "luz": "bosque"},
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
func _revisar(par: Dictionary, retoques: Dictionary = {}) -> Dictionary:
	var m: Dictionary = Generador.new().generar(par, retoques)
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
	var puerta_llave: Vector2i = Vector2i(-1, -1)
	var cofre_llave: Vector2i = Vector2i(-1, -1)
	for o in m["objetos"]:
		match String(o["tipo"]):
			"cofre_tesoro", "cofre_llave", "jarron", "brasero":
				bloquea[o["c"]] = true
		if String(o["tipo"]) == "puerta_llave":
			puerta_llave = o["c"]
		if String(o["tipo"]) == "cofre_llave":
			cofre_llave = o["c"]
	var tierra: int = 0
	for y in range(h):
		for x in range(w):
			if filas[y][x] != "#" and filas[y][x] != "~" and not bloquea.has(Vector2i(x, y)):
				tierra += 1
	var alcanzo: Dictionary = _relleno(filas, m["inicio"], bloquea, true)
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

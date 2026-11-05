extends SceneTree
## Prueba del reconocedor por TRAZOS RECTOS (5/11, Pablo; nucleo/trazos_rectos.gd) y de su enganche en el Grimorio, más la regla «el libro no se abre en combate».
## Sin ventana. Comprueba:
##   1. la tabla se lee entera (todos los nombres de ELEMENTOS/SELLOS de GestureLibrary tienen trazo, salvo los sellos sin trazo y `linea`);
##   2. cada plantilla dibujada sintéticamente (ruido, temblor, esquinas redondeadas, tramos de distinta longitud) se reconoce, también al revés
##      y con los trazos en otro orden;
##   3. NINGUNA plantilla cae dentro de la tolerancia de otra de su vocabulario (contando las versiones al revés);
##   4. los garabatos se rechazan y dicen «se parece a»; los empates se rechazan;
##   5. el enganche en un Grimorio real: elemento en el núcleo, sello en un sector, con METODO_TRAZO = "rectos"; "plantillas" sigue existiendo;
##   6. la regla del libro en combate (función pura + el lanzador sin jugadora).
## Corre con:   godot --headless --path . --script res://herramientas/prueba_trazos_rectos.gd

var _fallos: int = 0
var _rng := RandomNumberGenerator.new()

const ESCALA: float = 60.0           ## px de un tramo de longitud 1
const PASO_PX: float = 4.0           ## separación de los puntos del ratón
const REPETICIONES: int = 25         ## dibujos con ruido por plantilla y variante


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	_rng.seed = 5112026
	_tabla()
	_lectura()
	_reconocimiento()
	_medidas()
	_choques()
	_rechazos()
	await _grimorio()
	_libro_en_combate()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## --- DIBUJO SINTÉTICO ---

## Un gesto de la tabla («UR,DR|DL») como lista de trazos de puntos de ratón. `ruido` = temblor por punto (px) y desvío de cada vértice (px);
## `redondeo` = fracción de cada tramo que se corta en cada esquina; `largos` = longitudes distintas por tramo; `alreves` invierte el sentido de
## cada trazo; `barajar` cambia el orden de los trazos.
func _dibujar(texto: String, ruido: float, redondeo: float, largos: bool, alreves: bool, barajar: bool) -> Array:
	var gesto: Array = TrazosRectos.texto_a_gesto(texto)
	if barajar:
		gesto.shuffle()
	var trazos: Array = []
	var desp := Vector2(_rng.randf_range(100.0, 300.0), _rng.randf_range(100.0, 300.0))
	for k in range(gesto.size()):
		var sec: Array = gesto[k]
		if alreves:
			sec = TrazosRectos.invertir(sec)
		# Vértices
		var v: Array = [Vector2.ZERO]
		for d in sec:
			var largo: float = ESCALA * (_rng.randf_range(0.75, 1.35) if largos else 1.0)
			v.append((v[v.size() - 1] as Vector2) + TrazosRectos.vector_de(int(d)) * largo)
		# Los trazos paralelos o cruzados no se pisan: cada uno se desplaza un poco.
		var base: Vector2 = desp + Vector2(0.0, float(k) * ESCALA * 0.8)
		for i in range(v.size()):
			v[i] = (v[i] as Vector2) + base + Vector2(_rng.randf_range(-ruido, ruido), _rng.randf_range(-ruido, ruido)) * (1.0 if i > 0 and i < v.size() - 1 else 0.4)
		trazos.append(_pulir(v, redondeo))
	return trazos


## De vértices a puntos de ratón: esquinas cortadas (redondeo) y puntos cada PASO_PX con un poco de temblor.
func _pulir(v: Array, redondeo: float) -> Array:
	var camino: Array = [v[0]]
	for i in range(1, v.size()):
		var b: Vector2 = v[i]
		if i < v.size() - 1 and redondeo > 0.0:
			camino.append(b + ((v[i - 1] as Vector2) - b) * redondeo)     # donde empieza la esquina
			camino.append(b + ((v[i + 1] as Vector2) - b) * redondeo)     # donde acaba
		else:
			camino.append(b)
	var puntos: Array = []
	for i in range(camino.size() - 1):
		var p: Vector2 = camino[i]
		var q: Vector2 = camino[i + 1]
		var n: int = maxi(int(p.distance_to(q) / PASO_PX), 1)
		for j in range(n):
			puntos.append(p.lerp(q, float(j) / float(n)) + Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8)))
	puntos.append(camino[camino.size() - 1])
	return puntos


## --- 1. LA TABLA ---

func _tabla() -> void:
	var faltan_e: PackedStringArray = []
	for e in GestureLibrary.ELEMENTS:
		if not TrazosRectos.ELEMENTOS.has(e):
			faltan_e.append(e)
	_ok("1 todos los elementos tienen trazo", faltan_e.is_empty(), str(faltan_e))
	var sin_trazo: PackedStringArray = []
	for s in GestureLibrary.SIGILS:
		if not TrazosRectos.SELLOS.has(s):
			sin_trazo.append(s)
	var esperados: PackedStringArray = ["levitacion", "amplificar", "retardo", "atraccion", "espejo", "linea"]
	var raros: PackedStringArray = []
	for s in sin_trazo:
		if not esperados.has(s):
			raros.append(s)
	_ok("1 los sellos sin trazo son solo los antiguos y `linea`", raros.is_empty(), "sin trazo: " + str(sin_trazo))
	var mal: PackedStringArray = []
	for tabla in [TrazosRectos.ELEMENTOS, TrazosRectos.SELLOS]:
		for nombre in tabla:
			var texto: String = String(tabla[nombre])
			var g: Array = TrazosRectos.texto_a_gesto(texto)
			if g.is_empty() or TrazosRectos._a_texto(g) != texto:
				mal.append(nombre)
	_ok("1 todos los textos de la tabla se leen y se reescriben igual", mal.is_empty(), str(mal))
	_ok("1 `linea` se enseña como una raya", TrazosRectos.texto_guia("linea", false) == "R" and TrazosRectos.tiene_trazo("linea", false))
	var guia_ok: bool = true
	for tabla in [TrazosRectos.ELEMENTOS, TrazosRectos.SELLOS]:
		for nombre in tabla:
			for linea in TrazosRectos.guia_polilineas(String(tabla[nombre])):
				for p in (linea as PackedVector2Array):
					if p.x < -0.001 or p.x > 1.001 or p.y < -0.001 or p.y > 1.001:
						guia_ok = false
	_ok("1 la guía visible cabe en su caja de 1×1 para todos los glifos", guia_ok)


## --- Lectura de direcciones ---

func _lectura() -> void:
	# La y de pantalla crece hacia abajo: «U» es y negativa.
	_ok("2 U es hacia arriba de la pantalla (y negativa)", TrazosRectos.direccion_de(Vector2(0, -10)) == 2 and TrazosRectos.direccion_de(Vector2(0, 10)) == 6)
	_ok("2 las ocho direcciones", TrazosRectos.direccion_de(Vector2(10, 0)) == 0 and TrazosRectos.direccion_de(Vector2(10, -10)) == 1 and TrazosRectos.direccion_de(Vector2(-10, -10)) == 3
		and TrazosRectos.direccion_de(Vector2(-10, 0)) == 4 and TrazosRectos.direccion_de(Vector2(-10, 10)) == 5 and TrazosRectos.direccion_de(Vector2(10, 10)) == 7)
	var trazo: Array = []
	for i in range(21):
		trazo.append(Vector2(float(i) * 5.0, 0.0))
	for i in range(1, 21):
		trazo.append(Vector2(100.0, float(i) * 5.0))
	_ok("2 una L (derecha y abajo) se lee R,D", TrazosRectos.texto_de([trazo]) == "R,D", TrazosRectos.texto_de([trazo]))
	var pt: Array = [Vector2(0, 0), Vector2(1, 1)]
	_ok("2 un puntito sin recorrido no tiene dirección", TrazosRectos.secuencia(pt).is_empty())
	_ok("2 invertir: tramos al revés y direcciones opuestas", TrazosRectos.invertir([7, 5]) == [1, 3] and TrazosRectos.invertir(TrazosRectos.invertir([6, 0, 2])) == [6, 0, 2])


## --- 2. CADA PLANTILLA SE RECONOCE ---

func _reconocimiento() -> void:
	var variantes: Array = [
		{"n": "limpio", "ruido": 0.0, "red": 0.0, "largos": false, "alreves": false, "barajar": false},
		{"n": "ruido", "ruido": 3.0, "red": 0.0, "largos": false, "alreves": false, "barajar": false},
		{"n": "esquinas redondeadas", "ruido": 2.0, "red": 0.12, "largos": false, "alreves": false, "barajar": false},
		{"n": "tramos desiguales", "ruido": 2.0, "red": 0.0, "largos": true, "alreves": false, "barajar": false},
		{"n": "al revés", "ruido": 2.0, "red": 0.10, "largos": true, "alreves": true, "barajar": false},
		{"n": "trazos en otro orden", "ruido": 2.0, "red": 0.10, "largos": true, "alreves": false, "barajar": true},
	]
	for vocab in [["elemento", TrazosRectos.ELEMENTOS], ["sello", TrazosRectos.SELLOS]]:
		var tabla: Dictionary = vocab[1]
		for nombre in tabla:
			var texto: String = String(tabla[nombre])
			var peor: String = ""
			var total_bien: int = 0
			var total: int = 0
			for v in variantes:
				var bien: int = 0
				var fallos_aqui: PackedStringArray = []
				for _i in range(REPETICIONES):
					var trazos: Array = _dibujar(texto, v["ruido"], v["red"], v["largos"], v["alreves"], v["barajar"])
					var r: Dictionary = TrazosRectos.reconocer(trazos, tabla)
					if r["accepted"] and r["name"] == nombre:
						bien += 1
					elif fallos_aqui.size() < 2:
						fallos_aqui.append("leído %s -> %s" % [r["secuencia"], r["name"]])
				total_bien += bien
				total += REPETICIONES
				if bien < REPETICIONES:
					peor += " [%s %d/%d: %s]" % [v["n"], bien, REPETICIONES, "; ".join(fallos_aqui)]
			_ok("3 %s %s «%s» se reconoce en %d dibujos con ruido, esquinas, tramos desiguales, al revés y en otro orden" % [vocab[0], nombre, texto, total],
				total_bien == total, "%d/%d%s" % [total_bien, total, peor])


## MIDE (no falla): cuánto aguanta con más deformación que la de las comprobaciones. Sirve para calibrar los umbrales de TrazosRectos.
func _medidas() -> void:
	for dura in [[3.0, 0.15], [4.0, 0.20], [6.0, 0.12]]:
		var bien: int = 0
		var total: int = 0
		var rechazados: int = 0
		for vocab in [TrazosRectos.ELEMENTOS, TrazosRectos.SELLOS]:
			for nombre in vocab:
				for _i in range(REPETICIONES):
					var r: Dictionary = TrazosRectos.reconocer(_dibujar(String(vocab[nombre]), dura[0], dura[1], true, _i % 2 == 0, true), vocab)
					total += 1
					if r["accepted"] and r["name"] == nombre:
						bien += 1
					elif not r["accepted"]:
						rechazados += 1
		print("AVISO ruido %.0f px y esquinas cortadas al %.0f%%: %d/%d bien, %d rechazados, %d confundidos con otro" % [dura[0], 100.0 * dura[1], bien, total, rechazados, total - bien - rechazados])


## --- 3. CHOQUES ENTRE PLANTILLAS ---

func _choques() -> void:
	for vocab in [["elementos", TrazosRectos.ELEMENTOS], ["sellos", TrazosRectos.SELLOS]]:
		var tabla: Dictionary = vocab[1]
		var nombres: Array = tabla.keys()
		var choques: PackedStringArray = []
		var minimo_separacion: int = 99
		for i in range(nombres.size()):
			for j in range(i + 1, nombres.size()):
				var a: Array = TrazosRectos.texto_a_gesto(String(tabla[nombres[i]]))
				var b: Array = TrazosRectos.texto_a_gesto(String(tabla[nombres[j]]))
				# a vs b (con todas las variantes de b: al revés, otro orden) y b vs a: ninguna dentro de tolerancia.
				var d1: Dictionary = TrazosRectos.distancia(a, b)
				var d2: Dictionary = TrazosRectos.distancia(b, a)
				if bool(d1["dentro"]) or bool(d2["dentro"]):
					choques.append("%s/%s" % [nombres[i], nombres[j]])
				minimo_separacion = mini(minimo_separacion, mini(int(d1["coste"]), int(d2["coste"])))
		_ok("4 en los %s ninguna plantilla cae dentro de la tolerancia de otra (también al revés)" % vocab[0], choques.is_empty(),
			"choques: %s  (desviación mínima entre dos plantillas: %d pasos)" % [str(choques), minimo_separacion])
	# El detector detecta: dos plantillas que SÍ chocan.
	var chocan: bool = bool(TrazosRectos.distancia(TrazosRectos.texto_a_gesto("R,D"), TrazosRectos.texto_a_gesto("DR,DL"))["dentro"])
	_ok("4 (control) el detector ve el choque de Γ «R,D» con la flecha «DR,DL», que fue el motivo de cambiar `buscar`", chocan)
	var chocan2: bool = bool(TrazosRectos.distancia(TrazosRectos.texto_a_gesto("DR|DL"), TrazosRectos.texto_a_gesto("R|R"))["dentro"])
	_ok("4 (control) el detector ve el choque del X «DR|DL» con las dos rayas «R|R», que fue el motivo de cambiar `hielo`", chocan2)


## --- 4. RECHAZOS ---

func _rechazos() -> void:
	var circulo: Array = []
	for i in range(65):
		var a: float = float(i) / 64.0 * TAU
		circulo.append(Vector2(300.0 + cos(a) * 70.0, 300.0 + sin(a) * 70.0))
	var raya: Array = []
	for i in range(30):
		raya.append(Vector2(100.0 + float(i) * 5.0, 200.0))
	var sierra: Array = []
	for k in range(6):
		for i in range(10):
			sierra.append(Vector2(100.0 + float(k) * 30.0 + (float(i) * 3.0 if k % 2 == 0 else 30.0 - float(i) * 3.0), 100.0 + float(k) * 25.0 + float(i) * 2.5))
	var espiral: Array = []
	for i in range(80):
		var a2: float = float(i) / 79.0 * TAU * 2.0
		espiral.append(Vector2(300.0 + cos(a2) * (10.0 + float(i)), 300.0 + sin(a2) * (10.0 + float(i))))
	var garabatos: Dictionary = {"círculo": [circulo], "raya sola": [raya], "sierra": [sierra], "espiral": [espiral],
		"tres rayas": [raya, raya.map(func(p): return p + Vector2(0, 40)), raya.map(func(p): return p + Vector2(0, 80))]}
	for vocab in [["elementos", TrazosRectos.ELEMENTOS], ["sellos", TrazosRectos.SELLOS]]:
		for nombre in garabatos:
			var r: Dictionary = TrazosRectos.reconocer(garabatos[nombre], vocab[1])
			_ok("5 el garabato «%s» se rechaza en los %s y dice a qué se parece" % [nombre, vocab[0]], not r["accepted"] and String(r["name"]) != "",
				"leído «%s», se parece a %s" % [r["secuencia"], r["name"]])
	var vacio: Dictionary = TrazosRectos.reconocer([], TrazosRectos.SELLOS)
	_ok("5 sin trazos no hay nada que reconocer", not vacio["accepted"] and vacio["sin_trazo"])

	# Los empates se rechazan: entre todas las secuencias de dos y tres tramos, las hay equidistantes de dos plantillas.
	for vocab in [["sellos", TrazosRectos.SELLOS], ["elementos", TrazosRectos.ELEMENTOS]]:
		var empates: int = 0
		var empate_mal: int = 0
		var ejemplo: String = ""
		for n in [2, 3]:
			var total: int = int(pow(8.0, float(n)))
			for codigo in range(total):
				var sec: Array = []
				var c: int = codigo
				for _k in range(n):
					sec.append(c % 8)
					c /= 8
				var valida: bool = true
				for i in range(1, n):
					if sec[i] == sec[i - 1]:
						valida = false
				if not valida:
					continue
				var trazo: Array = _trazo_de(sec)
				var r2: Dictionary = TrazosRectos.reconocer([trazo], vocab[1])
				if r2["margin"] == 0.0 and r2["second_name"] != "" and int(r2["desviacion"]) < 999 and _dentro(r2, trazo, vocab[1]):
					empates += 1
					if r2["accepted"]:
						empate_mal += 1
					elif ejemplo == "":
						ejemplo = "%s: %s o %s" % [r2["secuencia"], r2["name"], r2["second_name"]]
		_ok("5 en los %s, un empate entre dos plantillas válidas se rechaza (hay %d secuencias empatadas; ejemplo %s)" % [vocab[0], empates, ejemplo], empate_mal == 0)


## ¿Hay al menos dos plantillas dentro de tolerancia para este trazo? (para contar los empates de verdad)
func _dentro(_r: Dictionary, trazo: Array, tabla: Dictionary) -> bool:
	var leidas: Array = TrazosRectos.secuencias([trazo])
	var n: int = 0
	for nombre in tabla:
		if bool(TrazosRectos.distancia(leidas, TrazosRectos.texto_a_gesto(String(tabla[nombre])))["dentro"]):
			n += 1
	return n >= 2


## Un trazo limpio con estas direcciones, un tramo de ESCALA px por dirección.
func _trazo_de(sec: Array) -> Array:
	var p := Vector2(200.0, 200.0)
	var pts: Array = [p]
	for d in sec:
		var v: Vector2 = TrazosRectos.vector_de(int(d)) * ESCALA
		for i in range(1, int(ESCALA / PASO_PX) + 1):
			pts.append(p + v * (float(i) * PASO_PX / ESCALA))
		p += v
	return pts


## --- 5. EL ENGANCHE EN UN GRIMORIO REAL ---

func _grimorio() -> void:
	var estado_rep: Dictionary = Repertoire.a_dic()
	Repertoire.activate_all()
	var metodo_previo: String = Grimorio.METODO_TRAZO
	Grimorio.METODO_TRAZO = "rectos"
	_ok("6 el método por defecto es «rectos»", metodo_previo == "rectos", metodo_previo)

	var g := Grimorio.new()
	root.add_child(g)
	await process_frame

	# Elementos, en el núcleo.
	var elemento_de: Dictionary = {"fuego": Runes.Type.SHAPE_TRIANGLE, "agua": Runes.Type.SHAPE_CIRCLE, "viento": Runes.Type.SHAPE_LINES,
		"tierra": Runes.Type.SHAPE_ARC, "rayo": Runes.Type.ELEMENT_LIGHTNING, "hielo": Runes.Type.ELEMENT_ICE}
	var malos: PackedStringArray = []
	for nombre in elemento_de:
		g.clear_sequence()
		g.add_gesture(_dibujar(String(TrazosRectos.ELEMENTOS[nombre]), 2.0, 0.1, true, false, false), Vector2.ZERO)
		if g.current_element != elemento_de[nombre]:
			malos.append(nombre)
	_ok("6 los seis elementos dibujados en el núcleo con trazos rectos quedan en la página", malos.is_empty(), str(malos))

	# Un elemento al revés y con los trazos en otro orden.
	g.clear_sequence()
	g.add_gesture(_dibujar("U|R", 2.0, 0.1, true, true, true), Vector2.ZERO)
	_ok("6 el hielo (dos trazos) dibujado al revés y en otro orden también", g.current_element == Runes.Type.ELEMENT_ICE)

	# Un rechazo en el núcleo no toca la página y deja el aviso «se parece a».
	g.clear_sequence()
	g.feedback_text = ""
	g.add_gesture(_dibujar("R,UR,U,UL,L,DL,D,DR", 0.0, 0.0, false, false, false), Vector2.ZERO)
	_ok("6 un garabato en el núcleo no pone elemento y avisa «se parece a»", g.current_element == Runes.Type.NONE and g.feedback_text.begins_with("No reconocido · se parece a:"), g.feedback_text)

	# Sellos, en un sector.
	var sector := Vector2(1.0, 0.0)
	malos = PackedStringArray()
	for nombre in TrazosRectos.SELLOS:
		g.clear_sequence()
		g.add_gesture(_dibujar(String(TrazosRectos.SELLOS[nombre]), 2.0, 0.1, true, false, false), sector)
		var puestos: Array = []
		for c in g.components():
			puestos.append_array(c["sigils"])
		if not puestos.has(nombre):
			malos.append("%s->%s" % [nombre, str(puestos)])
	_ok("6 los once sellos de la tabla dibujados en un sector quedan en la página", malos.is_empty(), str(malos))

	# Sin girar por sector: la misma flecha vale en cualquier sector, y la altura (Λ) NO se convierte en otra cosa al girar el sector.
	malos = PackedStringArray()
	for s in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(0.7, 0.7)]:
		g.clear_sequence()
		g.add_gesture(_dibujar("UR,DR", 2.0, 0.1, false, false, false), s)
		var hallado: Array = []
		for c in g.components():
			hallado.append_array(c["sigils"])
		if not hallado.has("altura"):
			malos.append("%s->%s" % [str(s), str(hallado)])
	_ok("6 «Λ» es altura en cualquier sector (las direcciones se leen respecto a la página, sin girar por sector)", malos.is_empty(), str(malos))

	# Un sello bloqueado se rechaza con su aviso, no se convierte en otro.
	g.clear_sequence()
	Repertoire.lock_sigil("rebote")
	g.feedback_text = ""
	g.add_gesture(_dibujar("DR,UR", 1.0, 0.1, false, false, false), sector)
	var llevaba: Array = []
	for c in g.components():
		llevaba.append_array(c["sigils"])
	_ok("6 un sello aún no conocido se rechaza con aviso", llevaba.is_empty() and g.feedback_text.contains("Aún no conoces"), "%s / %s" % [str(llevaba), g.feedback_text])
	Repertoire.unlock_sigil("rebote")

	# La raya sola sigue siendo `linea`, sin tocar.
	g.clear_sequence()
	g.add_gesture([[Vector2(100, 200), Vector2(140, 200), Vector2(180, 200), Vector2(220, 200), Vector2(260, 200)]], sector)
	var raya_puesta: Array = []
	for c in g.components():
		raya_puesta.append_array(c["sigils"])
	_ok("6 la raya de un solo trazo sigue siendo `linea` (linea_x / linea_z)", raya_puesta.size() == 1 and String(raya_puesta[0]).begins_with("linea"), str(raya_puesta))

	# El método de plantillas sigue ahí (el $P no se ha borrado): se puede volver con la constante y dibujar sin que reviente.
	Grimorio.METODO_TRAZO = "plantillas"
	g.clear_sequence()
	g.add_gesture(_dibujar("UR,DR", 0.0, 0.0, false, false, false), Vector2.ZERO)
	g.add_gesture(_dibujar("DR,DL", 0.0, 0.0, false, false, false), sector)
	_ok("6 con METODO_TRAZO = «plantillas» el $P sigue ahí (dibujar no revienta; lo que reconozca depende de las muestras grabadas)", g.has_method("_recognize_with_templates") and g.has_method("_reconocer_glifo"))
	Grimorio.METODO_TRAZO = "rectos"

	# El lanzador del juego, con trazos rectos.
	var l := Lanzador3D.new()
	root.add_child(l)
	await process_frame
	l.add_gesture(_dibujar("UR,DR", 1.0, 0.1, false, false, false), Vector2.ZERO)
	_ok("6 el Lanzador3D también reconoce un elemento por trazos rectos", l.current_element == Runes.Type.SHAPE_TRIANGLE)
	l.queue_free()
	g.queue_free()

	Grimorio.METODO_TRAZO = metodo_previo
	Repertoire.desde_dic(estado_rep)


## --- 6. EL LIBRO EN COMBATE ---

func _libro_en_combate() -> void:
	var previo: bool = Lanzador3D.LIBRO_EN_COMBATE
	_ok("7 por defecto el libro NO se abre en combate", previo == false)
	Lanzador3D.LIBRO_EN_COMBATE = false
	_ok("7 sin enemigos en combate el libro se abre", not Lanzador3D.combate_impide_libro(0))
	_ok("7 con un enemigo en combate el libro no se abre", Lanzador3D.combate_impide_libro(1))
	_ok("7 con varios también", Lanzador3D.combate_impide_libro(4))
	Lanzador3D.LIBRO_EN_COMBATE = true
	_ok("7 con LIBRO_EN_COMBATE = true vuelve a abrirse en combate", not Lanzador3D.combate_impide_libro(3))
	Lanzador3D.LIBRO_EN_COMBATE = false
	var l := Lanzador3D.new()
	root.add_child(l)
	_ok("7 sin jugadora el lanzador no ve combate (y no revienta)", not l.hay_combate_que_impide_libro() and not l.libro_bloqueado_por_combate())
	_ok("7 el aviso es el pedido", Lanzador3D.AVISO_LIBRO_EN_COMBATE == "En combate: lanza tus páginas con 1/2/3")
	# El lanzamiento rápido sigue donde estaba.
	_ok("7 el lanzamiento rápido 1/2/3 sigue (pulsar_pagina / soltar_pagina)", l.has_method("pulsar_pagina") and l.has_method("soltar_pagina") and Lanzador3D.TIEMPO_PAGINA > 0.0)
	l.free()
	Lanzador3D.LIBRO_EN_COMBATE = previo

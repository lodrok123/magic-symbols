extends SceneTree
## Pruebas de lo que la simulación del agua expone al dibujo (W0, 19/10, PLAN_TRES_FRENTES §3) sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_agua_w0.gd
## Cubre: el LLENADO de un recipiente por volumen (capacidad, volumen, fracción, rebose y segundos que faltan, contrastado con una simulación de
## verdad), la CAÍDA (cascadas) y los EVENTOS (entra agua, hielo roto, evaporación, hielo) — y que ninguno de los tres cambia el agua.
## Termina con «FALLOS: n».

const S: float = 2.3
const DT: float = 1.0 / 30.0
var _fallos: int = 0


func _init() -> void:
	_recipiente_cerrado()
	_recipiente_con_derrame()
	_recipiente_abierto_y_rebose_fijo()
	_llenado_contra_simulacion()
	_caida()
	_eventos()
	_no_cambian_el_agua()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _correr(a: AguaSim3D, segundos: float) -> void:
	for _i in range(int(roundf(segundos / DT))):
		a.paso(DT)


func _centro(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * S, 0.0, (float(c.y) + 0.5) * S)


## Mapa de 12 × 12 casillas, suelo a 0; `hoyos` = {casilla: suelo}. Sin paredes.
func _sim(hoyos: Dictionary) -> AguaSim3D:
	var a := AguaSim3D.new()
	a.configurar(12, 12, 3, S, func(c: Vector2i) -> float: return float(hoyos.get(c, 0.0)), func(_c: Vector2i) -> bool: return false)
	return a


func _pozo3x3(fondo: float) -> Dictionary:
	var h: Dictionary = {}
	for x in range(4, 7):
		for y in range(4, 7):
			h[Vector2i(x, y)] = fondo
	return h


## 1: un pozo de 3 × 3 casillas y 1 u de fondo, en un llano. Capacidad = 9 casillas × 2,3² × 1 u; rebosa a 0.
func _recipiente_cerrado() -> void:
	var a: AguaSim3D = _sim(_pozo3x3(-1.0))
	var d: Dictionary = a.recipiente(Vector2i(5, 5))
	var esperada: float = 9.0 * S * S * 1.0
	_ok("1 capacidad del pozo = 9 casillas × 2,3² × 1 u = %.3f u³" % esperada, not d.is_empty() and absf(float(d["capacidad"]) - esperada) < 0.01, str(d))
	_ok("1 rebosa a la altura del llano (Y = 0) y no está abierto", not d.is_empty() and absf(float(d["rebose"])) < 1.0e-4 and not bool(d["abierto"]))
	_ok("1 vacío: volumen 0 y fracción 0", float(d["volumen"]) == 0.0 and float(d["fraccion"]) == 0.0)
	var d2: Dictionary = a.recipiente(Vector2i(4, 6))
	_ok("1 da igual desde qué casilla del pozo se pregunte (esquina)", absf(float(d2["capacidad"]) - esperada) < 0.01)
	a.anadir(_centro(Vector2i(5, 5)), esperada * 0.5, 3.0)
	_correr(a, 8.0)
	var d3: Dictionary = a.recipiente(Vector2i(5, 5))
	_ok("1 con la mitad del volumen la fracción es 0,5 (%.3f)" % float(d3["fraccion"]), absf(float(d3["fraccion"]) - 0.5) < 0.02)
	_ok("1 el volumen que dice el recipiente es el de la simulación (%.3f de %.3f)" % [float(d3["volumen"]), a.volumen_total()], absf(float(d3["volumen"]) - a.volumen_total()) < 0.05)
	_ok("1 faltan (capacidad − volumen) / caudal segundos: con 2 u³/s, %.2f" % a.segundos_hasta_llenar(Vector2i(5, 5), 2.0), absf(a.segundos_hasta_llenar(Vector2i(5, 5), 2.0) - esperada * 0.5 / 2.0) < 0.1)
	_ok("1 caudal 0 → INF", a.segundos_hasta_llenar(Vector2i(5, 5), 0.0) == INF)
	a.anadir(_centro(Vector2i(5, 5)), esperada, 3.0)
	_correr(a, 5.0)
	_ok("1 lleno: fracción 1 y segundos 0", float(a.recipiente(Vector2i(5, 5))["fraccion"]) > 0.999 and a.segundos_hasta_llenar(Vector2i(5, 5), 2.0) == 0.0)
	_ok("1 una casilla de pared no es recipiente", _sim_con_pared().recipiente(Vector2i(0, 0)).is_empty())


func _sim_con_pared() -> AguaSim3D:
	var a := AguaSim3D.new()
	a.configurar(4, 4, 3, S, func(_c: Vector2i) -> float: return 0.0, func(c: Vector2i) -> bool: return c == Vector2i(0, 0))
	return a


## 2: el mismo pozo con una muesca en el borde: la casilla (7,5) a −0,4 y, fuera, (8,5) a −0,6 por donde se escapa. Rebosa a −0,4.
func _recipiente_con_derrame() -> void:
	var h: Dictionary = _pozo3x3(-1.0)
	h[Vector2i(7, 5)] = -0.4
	h[Vector2i(8, 5)] = -0.6
	var a: AguaSim3D = _sim(h)
	var d: Dictionary = a.recipiente(Vector2i(5, 5))
	var esperada: float = 9.0 * S * S * 0.6
	_ok("2 con una muesca a −0,4 rebosa a esa altura (%.3f)" % float(d["rebose"]), absf(float(d["rebose"]) + 0.4) < 1.0e-4, str(d))
	_ok("2 la capacidad es la de 0,6 u de agua en el pozo: %.3f u³" % esperada, absf(float(d["capacidad"]) - esperada) < 0.01, "%.3f" % float(d["capacidad"]))


## 3: un llano sin borde no es recipiente (abierto). Y con la altura del borde fijada a mano sí tiene capacidad.
func _recipiente_abierto_y_rebose_fijo() -> void:
	var a: AguaSim3D = _sim({})
	var d: Dictionary = a.recipiente(Vector2i(5, 5))
	_ok("3 un llano sin borde sale abierto, capacidad 0", bool(d["abierto"]) and float(d["capacidad"]) == 0.0 and a.segundos_hasta_llenar(Vector2i(5, 5), 1.0) == INF, str(d))
	var b: AguaSim3D = _sim(_pozo3x3(-1.0))
	var f: Dictionary = b.recipiente(Vector2i(5, 5), -0.5)
	_ok("3 con el borde fijado a −0,5 la capacidad es la de 0,5 u de agua: %.3f" % float(f["capacidad"]), absf(float(f["capacidad"]) - 9.0 * S * S * 0.5) < 0.01 and absf(float(f["rebose"]) + 0.5) < 1.0e-4, str(f))


## 4: lo que dice `segundos_hasta_llenar` frente a una simulación de verdad. Un manantial de 2 u³/s en el centro del pozo vacío.
func _llenado_contra_simulacion() -> void:
	var a: AguaSim3D = _sim(_pozo3x3(-1.0))
	var cas: Vector2i = Vector2i(5, 5)
	var caudal: float = 2.0
	var previsto: float = a.segundos_hasta_llenar(cas, caudal)
	a.fuente_en(cas, caudal)
	_correr(a, previsto * 0.8)
	var f80: float = float(a.recipiente(cas)["fraccion"])
	_ok("4 a los %.1f s (80 %% de lo previsto) está al %.0f %% (entre 74 y 84)" % [previsto * 0.8, f80 * 100.0], f80 > 0.74 and f80 < 0.84)
	var fuera: float = _agua_fuera(a)
	_ok("4 …y todavía no se ha derramado nada fuera del pozo (%.3f u³)" % fuera, fuera < 0.05)
	_correr(a, previsto * 0.6)
	_ok("4 a los %.1f s (140 %%) ya ha rebosado (fuera %.2f u³)" % [previsto * 1.4, _agua_fuera(a)], _agua_fuera(a) > 0.5)


## Agua fuera del pozo (casillas 4..6): u³.
func _agua_fuera(a: AguaSim3D) -> float:
	var s: float = 0.0
	for i in range(a.prof.size()):
		var cx: int = (i % a.w) / a.sub
		var cy: int = (i / a.w) / a.sub
		if cx < 4 or cx > 6 or cy < 4 or cy > 6:
			s += a.prof[i]
	return s * a.l * a.l


## 5: un escalón de 1 u. Con un manantial arriba el agua cae por él: la caída pasa del umbral. En el llano, no.
func _caida() -> void:
	var h: Dictionary = {}
	for x in range(6):
		for y in range(12):
			h[Vector2i(x, y)] = 1.0
	var a: AguaSim3D = _sim(h)
	a.fuente_en(Vector2i(3, 5), 1.0)
	_correr(a, 4.0)
	var max_caida: float = 0.0
	var en_escalon: bool = false
	for cx in range(12):
		for cy in range(12):
			for i in a._trozos(Vector2i(cx, cy)):
				max_caida = maxf(max_caida, a.caida_en_trozo(i))
	en_escalon = a.hay_cascada_en_casilla(Vector2i(5, 5)) or a.hay_cascada_en_casilla(Vector2i(4, 5)) or a.hay_cascada_en_casilla(Vector2i(6, 5))
	_ok("5 con un escalón de 1 u el agua cae al menos UMBRAL_CAIDA (%.3f ≥ %.2f)" % [max_caida, AguaSim3D.UMBRAL_CAIDA], max_caida >= AguaSim3D.UMBRAL_CAIDA)
	_ok("5 hay_cascada_en_casilla la encuentra en la arista del escalón", en_escalon)
	var img: Image = a.imagen_caida()
	var vmax: float = 0.0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			vmax = maxf(vmax, img.get_pixel(x, y).r)
	_ok("5 la imagen de caída (RF, w × h) lleva el mismo máximo (%.3f)" % vmax, img.get_format() == Image.FORMAT_RF and img.get_width() == a.w and img.get_height() == a.h and absf(vmax - max_caida) < 1.0e-3)
	_ok("5 la textura se crea y se actualiza en el sitio", a.textura_caida() == a.textura_caida())
	var b: AguaSim3D = _sim({})
	b.fuente_en(Vector2i(5, 5), 1.0)
	_correr(b, 6.0)
	var mb: float = 0.0
	for i in range(b.prof.size()):
		mb = maxf(mb, b.caida_en_trozo(i))
	_ok("5 en un llano el agua se extiende sin cascada (%.3f < %.2f)" % [mb, AguaSim3D.UMBRAL_CAIDA], mb < AguaSim3D.UMBRAL_CAIDA)
	# Un escalón con agua parada arriba y sin caudal no es caída.
	var c: AguaSim3D = _sim(h)
	_ok("5 sin agua no hay caída en ningún sitio", c.caida_en(_centro(Vector2i(5, 5))) == 0.0)


func _evento_en(a: AguaSim3D, pos: Vector3, consumir: bool = false) -> Vector2i:
	var img: Image = a.imagen_eventos(consumir)
	var i: int = a._trozo_de(pos)
	var p: Color = img.get_pixel(i % a.w, i / a.w)
	return Vector2i(int(roundf(p.r * 255.0)), int(roundf(p.g * 255.0)))


## 6: los cuatro eventos, su consumo y su caducidad.
func _eventos() -> void:
	var a: AguaSim3D = _sim(_pozo3x3(-1.0))
	var p: Vector3 = _centro(Vector2i(5, 5))
	a.anadir(p, 1.0, 0.0)
	var e: Vector2i = _evento_en(a, p)
	_ok("6 echar agua marca EVENTO_ENTRA con intensidad 255 en su trocito (%s)" % str(e), e.x == AguaSim3D.EVENTO_ENTRA and e.y == 255)
	_ok("6 eventos_pendientes da el mismo evento con su posición", a.eventos_pendientes().size() >= 1 and int(a.eventos_pendientes()[0]["tipo"]) == AguaSim3D.EVENTO_ENTRA)
	var e2: Vector2i = _evento_en(a, p, true)
	var e3: Vector2i = _evento_en(a, p)
	_ok("6 leerlos con consumir los borra: la lectura siguiente está vacía", e2.x == AguaSim3D.EVENTO_ENTRA and e3.x == 0)
	_ok("6 …y la imagen vacía no recorre nada: se devuelve la misma", a.imagen_eventos() == a.imagen_eventos())
	a.quitar(p, 0.5, 0.0)
	_ok("6 evaporar marca EVENTO_EVAPORA", _evento_en(a, p, true).x == AguaSim3D.EVENTO_EVAPORA)
	a.helar(p, 0.0, 2.0)
	_ok("6 helar marca EVENTO_HIELA", _evento_en(a, p, true).x == AguaSim3D.EVENTO_HIELA)
	a.derretir(p, 0.0)
	_ok("6 fundir marca EVENTO_HIELO_ROTO", _evento_en(a, p, true).x == AguaSim3D.EVENTO_HIELO_ROTO)
	a.helar(p, 0.0, 0.2)
	_evento_en(a, p, true)
	_correr(a, 0.5)
	_ok("6 el hielo que se suelta solo por tiempo también marca EVENTO_HIELO_ROTO", _evento_en(a, p, true).x == AguaSim3D.EVENTO_HIELO_ROTO)
	a.anadir(p, 1.0, 0.0)
	_correr(a, AguaSim3D.VIDA_EVENTO + 0.3)
	_ok("6 un evento que nadie lee caduca a los %.1f s" % AguaSim3D.VIDA_EVENTO, _evento_en(a, p).x == 0)
	var pocos: AguaSim3D = _sim({})
	pocos.anadir(p, 0.1, 0.0)
	_ok("6 una gota pequeña marca el evento con poca intensidad (mínimo 0,1 → 26)", _evento_en(pocos, p).y >= 25 and _evento_en(pocos, p).y < 40)


## 7: pedir la caída, los eventos o el recipiente NO cambia el agua: dos simulaciones iguales, una consultada a cada paso, acaban idénticas.
func _no_cambian_el_agua() -> void:
	var a: AguaSim3D = _sim(_pozo3x3(-1.0))
	var b: AguaSim3D = _sim(_pozo3x3(-1.0))
	for s in [a, b]:
		(s as AguaSim3D).fuente_en(Vector2i(5, 5), 2.0)
		(s as AguaSim3D).anadir(_centro(Vector2i(8, 8)), 2.0, 1.0)
		(s as AguaSim3D).helar(_centro(Vector2i(8, 8)), 1.0, 1.0)
	for _i in range(240):
		a.paso(DT)
		b.paso(DT)
		a.imagen_caida()
		a.imagen_eventos()
		a.eventos_pendientes(true)
		a.recipiente(Vector2i(5, 5))
	var igual: bool = a.prof == b.prof and a.caudal == b.caudal and a.helado == b.helado
	_ok("7 consultar caída, eventos y recipiente deja el agua idéntica (volumen %.4f = %.4f)" % [a.volumen_total(), b.volumen_total()], igual)

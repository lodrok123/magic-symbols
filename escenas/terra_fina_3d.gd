class_name TerraFina3D
extends Node

## REGLAS DEL TUTORIAL «TERRA FINA» (Juego). Va ANTES de Bosque 1: enseña a moverse, a quemar y a cazar al gatopedro.
## Mapa: mundo/datos_nivel/mapas/TerraFina.txt. Escena: escenas/PruebaTerraFina.tscn.
##
## POR QUÉ ES UN NODO HIJO Y NO `reglas = "terra_fina"`: PruebaTest2 elige las reglas por cadena fija (Pipeline). Para no tocar su
## archivo, la escena cuelga este nodo como hijo y él se engancha solo: `_ready` del hijo corre ANTES que el del padre, así que
## espera un fotograma (`call_deferred`) y entonces el mundo ya está montado, con el Jugador3D puesto. Si algún día PruebaTest2
## aprende `reglas = "terra_fina"`, basta con llamar a `iniciar(self)` desde allí; este archivo no cambia.
##
## EL NIVEL (docs/PLAN_ARREGLOS.md / presentación de Terra Fina):
##   · TRES ALTURAS (el mapa las declara con `; altura x0 y0 x1 y1 niveles`; aquí se fijan con Terreno3D.fijar_altura y se dibujan):
##     PIES (nivel 0, sur), PELVIS (nivel 1, el cruce de caminos y la aldea) y PECHO (nivel 2, al norte). Se sube SALTANDO un nivel.
##     Jugador3D solo sube 1 nivel (MAX_NIVELES_SUBIBLES); aquí se pone `tope_niveles_nivel = 2` y se suelta al salir del nivel.
##   · PIES: práctica. Un brasero (T) y un muñeco (D); río con puente (b); un seto seco (z) que cierra el paso: se QUEMA con fuego
##     y es la única subida a la pelvis (el resto de la fila 18 es muro).
##   · PELVIS: aldea de casas-cueva (H, las pone este archivo) y el cruce de caminos. Un hueco en el muro de la fila 8 sube al pecho.
##   · PECHO: dos GATOPEDROS (C): huyen al detectarte y caen con 2 flechas de fuego. La SALIDA `E` está sellada hasta que caigan los dos.
##   · Detrás, al norte, el TITÁN (Titan3D) sentado sobre la meseta del pecho.
##
## Letras propias del nivel (PruebaTest2 las ignora, así que no hay que tocar su archivo): H = casa-cueva, C = gatopedro.

const FILA_PIES_TITAN: float = 1.5          ## fila del mapa donde acaban los pies del titán (z = fila × S)
const PIES_LOCAL_Z: float = 26.0            ## hasta dónde llegan los pies en el eje Z propio del Titan3D (medido: ≈ +26)
const NIVEL_MAPA: String = "TerraFina"       ## el .txt de mapas/ del que se leen las alturas
const COLOR_ROCA_S: Color = Color(0.52, 0.48, 0.40)    ## cara sur de una terraza (la que ve la cámara)
const COLOR_ROCA_LADO: Color = Color(0.44, 0.41, 0.35)
const COLOR_ROCA_N: Color = Color(0.38, 0.36, 0.31)
const COLOR_TOPE: Dictionary = {".": Color(0.36, 0.58, 0.30), ",": Color(0.47, 0.68, 0.36), "g": Color(0.45, 0.33, 0.22), "v": Color(0.55, 0.75, 0.3)}
const SEMILLA_TITAN: int = 7
const COLOR_SUELO: Color = Color(0.36, 0.52, 0.26)
const COLOR_CASA: Color = Color(0.46, 0.40, 0.30)
const COLOR_MUSGO: Color = Color(0.34, 0.46, 0.22)
const COLOR_PUERTA: Color = Color(0.12, 0.09, 0.07)
## Las tareas del nivel son los objetivos de una misión del diario (Fase 14.3): 0 los gatopedros (con cuenta), 1 la salida.
const MISION: String = "terra_fina"
const TEXTO_INICIO: String = "TERRA FINA  ·  WASD mover · rueda del ratón: alejar la cámara · F1: dibuja el fuego"
## Avisos de la enseñanza: (fila máxima del mapa donde se dicen, texto). Se dicen una vez, de sur a norte.
const AVISOS: Array = [
	[27, "Prueba el fuego en el brasero: dibuja la llama y lánzala."],
	[22, "Cruza el puente. El seto seco del otro lado arde: quémalo para pasar."],
	[17, "La aldea vive a los pies del titán. Sigue el camino de tierra."],
	[8, "Un gatopedro. Se asusta si te ve: dos flechas de fuego y no vuelve a soñar."],
]

var m: Variant = null                        ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _jug: Jugador3D = null
var _niveles_max: int = 0                   ## la terraza más alta del mapa
var _titan: Titan3D = null
var _celdas_c: Array[Vector2i] = []          ## dónde nace cada gatopedro
var _salida_c: Vector2i = Vector2i(-1, -1)
var _sello: MeshInstance3D = null
var _gatopedros: Array[Gatopedro3D] = []
var _caidos: int = 0
var _esperados: int = 0
var _salida_abierta: bool = false
var _terminado: bool = false
var _t: float = 0.0
var _t_aviso: float = 0.0
var _hud: Label = null
var _aviso: Label = null
var _aviso_dado: Array[bool] = [false, false, false, false]


func _ready() -> void:
	# El padre aún no ha hecho su _ready: se espera a que termine (call_deferred corre al final del fotograma).
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


## Entrada pública: `mundo` es la maqueta ya montada.
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	var mapa: PackedStringArray = m.get("_mapa")
	var s: float = float(m.get("S"))
	var alto: float = float(m.get("ALTO"))
	# Las alturas, ANTES que casas, gatopedros y sello: todos se colocan a la y de su casilla.
	var rects: Array = leer_alturas(NIVEL_MAPA)
	for r in rects:
		for y in range(int(r[1]), int(r[3]) + 1):
			for x in range(int(r[0]), int(r[2]) + 1):
				Terreno3D.fijar_altura(Vector2i(x, y), int(r[4]))
		_niveles_max = maxi(_niveles_max, int(r[4]))
	Jugador3D.tope_niveles_nivel = _niveles_max
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			var c := Vector2i(x, y)
			match mapa[y][x]:
				"H":
					_poner_casa_cueva(c, s, alto)
				"C":
					_celdas_c.append(c)
				"E":
					_salida_c = c
	_esperados = _celdas_c.size()
	_montar_escenario(mapa, s, alto)
	_montar_terrazas(mapa, s)
	_montar_sello_salida(s, alto)
	_subir_piezas_de_la_salida(s)
	for c in _celdas_c:
		_poner_gatopedro(c, alto)
	Estado.i().enemigo_muerto.connect(_on_muerte)
	Misiones.i().definir({"id": MISION, "titulo": "Terra Fina", "tipo": "principal",
		"texto": "Los gatopedros sueñan en las terrazas de Terra Fina y el túnel de la salida no se abre mientras sueñen. Despiértalos a todos.",
		"origen": "Terra Fina",
		"objetivos": [_texto_gatopedros(), "Cruzar el túnel de la salida"]})
	Misiones.i().activar(MISION)
	if _esperados == 0:
		Misiones.i().objetivo_hecho(MISION, 0)
	_montar_hud()
	_decir(TEXTO_INICIO, 7.0)
	set_process(true)


func _exit_tree() -> void:
	# Estado es estático: si no se suelta, la función sobrevive a la escena (la prueba lo cazó con un cierre corrupto).
	if Estado.i().enemigo_muerto.is_connected(_on_muerte):
		Estado.i().enemigo_muerto.disconnect(_on_muerte)
	Jugador3D.tope_niveles_nivel = 0            # estático: si no se suelta, el siguiente nivel heredaría el tope de 2


## --- El escenario: el titán detrás, el suelo bajo él y montes a los lados para que al girar la cámara no se vea el vacío ---

func _montar_escenario(mapa: PackedStringArray, s: float, alto: float) -> void:
	# El mapa en memoria es un CUADRADO relleno con " " (HorneadorNivel.leer_mapa): el tamaño real lo da la maqueta (`_ancho` × `_alto`).
	var ancho: float = float(m.get("_ancho")) * s
	var largo: float = float(m.get("_alto")) * s
	var y_meseta: float = Terreno3D.alto_suelo + float(_niveles_max) * Terreno3D.ALTO_NIVEL     # la terraza alta: donde se sienta el titán
	var raiz := Node3D.new()
	raiz.name = "EscenarioTerraFina"
	(m as Node).add_child(raiz)
	# Suelo detrás (norte) y a los lados: tres losas finas con la cara de arriba a la altura del suelo del mapa.
	for r in [
		[Vector3(ancho * 0.5, y_meseta - 0.3, -90.0), Vector3(ancho + 240.0, 0.6, 180.0)],     # norte, bajo el titán (a la altura de la meseta)
		[Vector3(-60.0, alto - 0.3, largo * 0.5), Vector3(120.0, 0.6, largo)],                  # oeste
		[Vector3(ancho + 60.0, alto - 0.3, largo * 0.5), Vector3(120.0, 0.6, largo)],           # este
		[Vector3(ancho * 0.5, alto - 0.3, largo + 60.0), Vector3(ancho + 240.0, 0.6, 120.0)],   # sur
	]:
		var losa := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = r[1]
		losa.mesh = bm
		losa.material_override = _mat(COLOR_SUELO)
		losa.position = r[0]
		raiz.add_child(losa)
	# El titán, sentado mirando al sur. Sus pies acaban en FILA_PIES_TITAN; el centro, a la mitad del ancho del mapa.
	_titan = Titan3D.new()
	_titan.name = "Titan"
	_titan.semilla = SEMILLA_TITAN
	_titan.position = Vector3(ancho * 0.5, y_meseta, FILA_PIES_TITAN * s - PIES_LOCAL_Z)
	raiz.add_child(_titan)
	# Montes a los lados (los mismos blobs de roca-musgo del titán): tapan el borde de la losa al girar la cámara.
	for k in range(5):
		for lado in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.mesh = Titan3D.malla_blob(Vector3(14.0, 9.0, 12.0), 100 + k * 2 + (1 if lado > 0.0 else 0), 0.25, 24, COLOR_MUSGO, COLOR_MUSGO.darkened(0.2))
			mi.material_override = _mat_vertices()
			mi.position = Vector3(ancho * 0.5 + lado * (ancho * 0.5 + 16.0), alto + 2.0, 6.0 + float(k) * (largo - 12.0) / 4.0)
			raiz.add_child(mi)


## Casa-cueva: un montículo de roca-musgo medio enterrado con la boca oscura hacia el sur (hacia la cámara). Bloquea su casilla.
func _poner_casa_cueva(c: Vector2i, s: float, _alto: float) -> void:
	(m.get("_bloqueadas") as Dictionary)[c] = true
	var centro: Vector3 = m.call("_centro_celda", c, Terreno3D.y_pies(c))      # a la altura de su terraza
	var casa := Node3D.new()
	casa.name = "casa_cueva_%d_%d" % [c.x, c.y]
	casa.position = centro
	var monte := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = s * 0.62
	esfera.height = s * 1.24
	monte.mesh = esfera
	monte.scale = Vector3(1.0, 0.85, 0.95)
	monte.position.y = 0.0
	monte.material_override = _mat(COLOR_CASA)
	casa.add_child(monte)
	var hierba := MeshInstance3D.new()
	var tapa := SphereMesh.new()
	tapa.radius = s * 0.5
	tapa.height = s * 0.5
	hierba.mesh = tapa
	hierba.position = Vector3(0.0, s * 0.42, -0.05 * s)
	hierba.material_override = _mat(COLOR_MUSGO)
	casa.add_child(hierba)
	var boca := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(s * 0.42, s * 0.5, 0.12)
	boca.mesh = caja
	boca.position = Vector3(0.0, s * 0.13, s * 0.56)
	boca.material_override = _mat(COLOR_PUERTA)
	casa.add_child(boca)
	(m as Node).add_child(casa)


## --- Las terrazas ---

## Lee las líneas `; altura x0 y0 x1 y1 niveles` del mapa. Devuelve [[x0, y0, x1, y1, n], ...]. (`leer_mapa` ignora estas líneas.)
static func leer_alturas(nivel: String) -> Array:
	var res: Array = []
	var ruta: String = HorneadorNivel.ruta_mapa(nivel)
	if ruta == "":
		return res
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return res
	for linea in f.get_as_text().split("\n"):
		var l: String = String(linea).replace("\r", "")
		if not l.begins_with(";"):
			continue
		var p: PackedStringArray = l.substr(1).strip_edges().split(" ", false)
		if p.size() >= 6 and p[0] == "altura":
			res.append([int(p[1]), int(p[2]), int(p[3]), int(p[4]), int(p[5])])
	return res


## Dibuja las terrazas: ni la maqueta ni el Lanzador pintan las alturas fijas (solo la tierra y las columnas de los hechizos).
## Una sola malla con color por vértice: la tapa de cada casilla elevada (verde, hierba corta o tierra, según su letra) y, donde la
## vecina es más baja, el muro de roca hasta el suelo de esa vecina. Las casillas del mapa de abajo quedan enterradas bajo la tapa.
func _montar_terrazas(mapa: PackedStringArray, s: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ancho: int = int(m.get("_ancho"))
	var alto_m: int = int(m.get("_alto"))
	var n_celdas: int = 0
	for y in range(alto_m):
		for x in range(ancho):
			var c := Vector2i(x, y)
			var n: int = Terreno3D.altura_en(c)
			if n <= 0:
				continue
			n_celdas += 1
			var y_top: float = Terreno3D.alto_suelo + float(n) * Terreno3D.ALTO_NIVEL
			var x0: float = float(x) * s
			var z0: float = float(y) * s
			var letra: String = String(mapa[y][x])
			var col: Color = COLOR_TOPE.get(letra, COLOR_TOPE["."])
			var v: float = float(absi((x * 73856093) ^ (y * 19349663)) % 100) / 100.0
			col = col.lightened(v * 0.06 - 0.03)
			_cuad(st, Vector3(x0, y_top, z0), Vector3(x0 + s, y_top, z0), Vector3(x0 + s, y_top, z0 + s), Vector3(x0, y_top, z0 + s), Vector3.UP, col)
			for d in [[Vector2i(0, 1), COLOR_ROCA_S], [Vector2i(1, 0), COLOR_ROCA_LADO], [Vector2i(-1, 0), COLOR_ROCA_LADO], [Vector2i(0, -1), COLOR_ROCA_N]]:
				var vec: Vector2i = c + (d[0] as Vector2i)
				if vec.x < 0 or vec.y < 0 or vec.x >= ancho or vec.y >= alto_m or String(mapa[vec.y][vec.x]) == "#":
					continue          # el borde y los muros del mapa ya se ven por sí solos
				var nv: int = Terreno3D.altura_en(vec)
				if nv >= n:
					continue
				var y_bajo: float = Terreno3D.alto_suelo + float(nv) * Terreno3D.ALTO_NIVEL
				var dd: Vector2i = d[0]
				var cc: Color = d[1]
				if dd == Vector2i(0, 1):
					_cuad(st, Vector3(x0, y_top, z0 + s), Vector3(x0 + s, y_top, z0 + s), Vector3(x0 + s, y_bajo, z0 + s), Vector3(x0, y_bajo, z0 + s), Vector3(0, 0, 1), cc)
				elif dd == Vector2i(0, -1):
					_cuad(st, Vector3(x0 + s, y_top, z0), Vector3(x0, y_top, z0), Vector3(x0, y_bajo, z0), Vector3(x0 + s, y_bajo, z0), Vector3(0, 0, -1), cc)
				elif dd == Vector2i(1, 0):
					_cuad(st, Vector3(x0 + s, y_top, z0 + s), Vector3(x0 + s, y_top, z0), Vector3(x0 + s, y_bajo, z0), Vector3(x0 + s, y_bajo, z0 + s), Vector3(1, 0, 0), cc)
				else:
					_cuad(st, Vector3(x0, y_top, z0), Vector3(x0, y_top, z0 + s), Vector3(x0, y_bajo, z0 + s), Vector3(x0, y_bajo, z0), Vector3(-1, 0, 0), cc)
	if n_celdas == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Terrazas"
	mi.mesh = st.commit()
	mi.material_override = _mat_vertices()
	(m as Node).add_child(mi)


## Un cuadrilátero a, b, c, d (en sentido horario visto desde la normal) con su normal y color.
static func _cuad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


## El portal de la salida lo coloca la maqueta a la altura del suelo (y = ALTO): si la salida está en una terraza, las piezas
## que hay sobre su casilla (el portal) se suben lo mismo que ella. Se reconocen por su posición en x/z.
func _subir_piezas_de_la_salida(s: float) -> void:
	if _salida_c.x < 0:
		return
	var dy: float = Terreno3D.y_pies(_salida_c) - Terreno3D.alto_suelo
	if dy <= 0.001:
		return
	var centro: Vector3 = m.call("_centro_celda", _salida_c, 0.0)
	for h in (m.get("_props") as Node).get_children():
		var n3 := h as Node3D
		if n3 != null and n3 != _sello and absf(n3.position.x - centro.x) < s * 0.6 and absf(n3.position.z - centro.z) < s * 0.6:
			n3.position.y += dy


## --- Gatopedros y salida ---

func _poner_gatopedro(c: Vector2i, _alto: float) -> void:
	if _jug == null:
		push_warning("TerraFina3D: no hay Jugador3D; los gatopedros no pueden vigilar a nadie")
		return
	var pos: Vector3 = m.call("_pos_marca", c, Terreno3D.y_pies(c))
	var g: Gatopedro3D = Gatopedro3D.invocar(m, _jug, _jug.lanz, pos)
	if g != null:
		_gatopedros.append(g)
	else:
		push_warning("TerraFina3D: no se pudo crear el gatopedro de %s" % str(c))


func _montar_sello_salida(s: float, _alto: float) -> void:
	if _salida_c.x < 0:
		_salida_abierta = true
		return
	var caja := BoxMesh.new()
	caja.size = Vector3(s * 0.95, 2.6, 0.2)
	caja.material = _mat(Color(0.45, 0.72, 1.0, 0.45))
	var mat: StandardMaterial3D = caja.material as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.72, 1.0)
	mat.emission_energy_multiplier = 0.6
	_sello = MeshInstance3D.new()
	_sello.name = "sello_salida"
	_sello.mesh = caja
	_sello.rotation_degrees.y = 90.0                  # la salida está en el borde este: la cortina cierra de norte a sur
	_sello.position = m.call("_centro_celda", _salida_c, Terreno3D.y_pies(_salida_c) + 1.3)
	(m.get("_props") as Node).add_child(_sello)
	(m.get("_bloqueadas") as Dictionary)[_salida_c] = true


func _on_muerte(_pos: Vector2, id: String) -> void:
	if id != Gatopedro3D.NOMBRE_OFICIAL:
		return
	_caidos += 1
	Misiones.i().objetivo_texto(MISION, 0, _texto_gatopedros())
	if _caidos >= _esperados:
		Misiones.i().objetivo_hecho(MISION, 0)
	if _caidos >= _esperados and not _salida_abierta:
		_abrir_salida()
	else:
		_decir("Gatopedro caído (%d/%d)." % [_caidos, _esperados], 4.0)


func _texto_gatopedros() -> String:
	return "Derrotar a los gatopedros (%d/%d)" % [_caidos, _esperados]


func _abrir_salida() -> void:
	_salida_abierta = true
	m.call("_liberar", _salida_c)
	_decir("Los gatopedros ya no sueñan por nadie: el túnel está libre.", 6.0)
	if _sello != null:
		var tw := create_tween()
		tw.tween_property(_sello, "scale:y", 0.01, 0.8)
		tw.tween_callback(_sello.hide)


## --- Avisos y HUD ---

func _process(delta: float) -> void:
	if m == null or m.get("_jugador") == null:
		return
	_t += delta
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	var pj: Pj3D = m.get("_jugador")
	var c: Vector2i = m.call("_celda_de", pj.position)
	for i in range(AVISOS.size()):
		if not _aviso_dado[i] and c.y <= int(AVISOS[i][0]) and c.y > (int(AVISOS[i + 1][0]) if i + 1 < AVISOS.size() else -1):
			_aviso_dado[i] = true
			_decir(String(AVISOS[i][1]), 6.0)
	if _salida_abierta and not _terminado and c == _salida_c:
		_terminado = true
		Misiones.i().objetivo_hecho(MISION, 1)
		_decir("¡Terra Fina completada en %d s! Por el túnel se llega al bosque." % int(_t), 8.0)
	if _t_aviso <= 0.0 and _aviso != null:
		_aviso.text = ""
	_hud.text = "TERRA FINA  ·  %d s  ·  gatopedros %d/%d  ·  salida %s" % [int(_t), _caidos, _esperados, "LIBRE" if _salida_abierta else "sellada"]


func _montar_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 150.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.position = Vector2(-300.0, -120.0)
	_aviso.custom_minimum_size = Vector2(600.0, 0.0)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.add_theme_font_size_override("font_size", 22)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 8)
	capa.add_child(_aviso)


func _decir(texto: String, seg: float) -> void:
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg


static func _mat(col: Color) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.roughness = 1.0
	return mt


## Material para mallas con color por vértice (los blobs de Titan3D lo traen).
static func _mat_vertices() -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.roughness = 1.0
	return mt

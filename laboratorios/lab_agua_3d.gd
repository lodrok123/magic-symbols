extends Node3D
## LABORATORIO DEL AGUA (Fase 11.2, 12/10). Lo escribe el Juego. F6 sobre `poc_25d/LabAgua3D.tscn`.
## Sirve para juzgar la FÍSICA del agua (AguaSim3D) antes de que exista el dibujo bueno del Pipeline (11.7): cada trocito
## de agua es una caja azul que sube y baja con la superficie. Lo de aquí no va al juego.
##
## Qué hay (12 × 10 casillas):
##   - arriba a la izquierda, un MANANTIAL en lo alto de una escalera de dos niveles: el agua baja escalón a escalón;
##   - en medio, un HOYO de un nivel de hondo: se llena hasta el borde y no más;
##   - una fila de casillas donde levantar una PRESA de tierra (clic derecho);
##   - abajo, un RÍO con salida a la derecha (nivel fijo): el agua que llega se va y se ve la corriente.
## ESCENA DE REFERENCIA (19/10, PLAN_TRES_FRENTES §3): las tres situaciones del vídeo de Pablo, con su MEDIDA en pantalla para compararlas con él al lado:
##   POZO (el hoyo): capacidad, volumen, % lleno y segundos que faltan con el manantial del pozo (P lo abre y cuenta el tiempo real hasta llenarse;
##        el volumen del recipiente sale del suelo, no del agua: `AguaSim3D.recipiente`).
##   CASCADA (la escalera del manantial): la mayor caída de la superficie y cuántas casillas pasan de UMBRAL_CAIDA (`AguaSim3D.caida_en_trozo`).
##   RÍO (abajo): corriente media y máxima (u/s) de sus casillas.
## Controles:
##   P: abre o cierra el manantial del pozo (y reinicia el cronómetro de llenado)
##   clic izquierdo: echa 3 u³ de agua donde apuntas (un hechizo de agua)
##   clic derecho: levanta o quita tierra en esa casilla (presa)
##   H: hiela o deshiela la casilla que apuntas · F: abre o cierra el manantial · R: empezar de nuevo
##   rueda: zoom
## En pantalla: volumen total, ms por paso de la simulación y la casilla apuntada (profundidad, ¿agua?, ¿se nada?, corriente).

const S: float = 2.3                     ## lado de casilla (el de PruebaTest2.S)
const NIVEL: float = 1.15                ## alto de un nivel (S * 0.5, el de PruebaTest2.ALTO)
const ANCHO: int = 12
const ALTO: int = 10
const SUB: int = 3
const CAUDAL_MANANTIAL: float = 1.2      ## u³/s
const CAUDAL_POZO: float = 1.5           ## u³/s del manantial que llena el pozo (P)
const CASILLA_POZO: Vector2i = Vector2i(6, 4)   ## una casilla del hoyo (las del hoyo son 'o': 6-7 × 4-5)
const CASILLAS_CASCADA: Array = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(1, 3), Vector2i(2, 3)]   ## escalera: '2' y '1'

## Plano en letras (una por casilla): # pared · . suelo · 1 / 2 escalón de 1 o 2 niveles · o hoyo (-1 nivel)
## r cauce del río (-0,5 niveles) · M manantial (sobre el escalón 2) · p presa posible (suelo) · s salida del río
const MAPA: PackedStringArray = [
	"############",
	"#M22211....#",
	"#2221.1....#",
	"#11.......p#",
	"#.....oo..p#",
	"#.....oo..p#",
	"#.........p#",
	"#rrrrrrrrrs#",
	"#rrrrrrrrrs#",
	"############",
]

var agua: AguaSim3D = null
var _cajas: MultiMeshInstance3D = null
var _tierra: Dictionary = {}             ## Vector2i -> MeshInstance3D de la presa levantada
var _helada: Dictionary = {}
var _manantial_abierto: bool = true
var _camara: Camera3D = null
var _texto: Label = null
var _ms_paso: float = 0.0
var _suelo_nodo: Node3D = null
var _render: AguaRender3D = null        ## 11.7 (Pipeline): el dibujo bueno del agua; la tecla Y alterna con las cajas de depuración
var _ondas: AguaOndas3D = null          ## 11.8 (Pipeline): ondas que reaccionan; el clic izquierdo (hechizo de agua) levanta una
var _gotas: AguaMetaballs3D = null      ## 11.9 (Pipeline): chorros y salpicaduras; G = salpicadura, V = chorro (alterna) donde apuntas
var _chorro: GPUParticles3D = null
var _flotadores: Array = []              ## troncos que flotan (Flotador3D, Fase 11.6)
var _pozo_abierto: bool = false          ## manantial del pozo (P)
var _pozo_t: float = 0.0                 ## s de simulación desde que se abrió
var _pozo_lleno_t: float = -1.0          ## s que tardó en llenarse (-1 = aún no)
var _pozo_prevision: float = 0.0         ## s previstos al abrirlo: (capacidad − volumen) / caudal


func _ready() -> void:
	_montar_escena()
	_empezar()


func _montar_escena() -> void:
	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = 26.0
	add_child(_camara)
	_camara.look_at_from_position(Vector3(ANCHO * S * 0.5, 30.0, ALTO * S * 0.5 + 22.0), Vector3(ANCHO * S * 0.5, 0.0, ALTO * S * 0.5))
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sol.shadow_enabled = true
	add_child(sol)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.6
	amb.environment = env
	add_child(amb)
	_cajas = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var caja := BoxMesh.new()
	caja.size = Vector3(1, 1, 1)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	caja.material = mat
	mm.mesh = caja
	_cajas.multimesh = mm
	add_child(_cajas)
	var capa := CanvasLayer.new()
	add_child(capa)
	_texto = Label.new()
	_texto.position = Vector2(12, 10)
	_texto.add_theme_color_override("font_color", Color.WHITE)
	_texto.add_theme_constant_override("outline_size", 6)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	capa.add_child(_texto)


func _empezar() -> void:
	if _suelo_nodo != null:
		_suelo_nodo.queue_free()
	for n in _tierra.values():
		(n as Node).queue_free()
	_tierra.clear()
	for f in _flotadores:
		(f as Node).queue_free()
	_flotadores.clear()
	_helada.clear()
	_pozo_abierto = false
	_pozo_t = 0.0
	_pozo_lleno_t = -1.0
	_pozo_prevision = 0.0
	_suelo_nodo = Node3D.new()
	add_child(_suelo_nodo)
	agua = AguaSim3D.new()
	agua.configurar(ANCHO, ALTO, SUB, S, _y_suelo, _es_pared)
	for y in range(ALTO):
		for x in range(ANCHO):
			var c := Vector2i(x, y)
			_poner_bloque_suelo(c)
			var l: String = MAPA[y][x]
			if l == "r":
				agua.llenar_casilla(c, -0.1)            # el río empieza lleno hasta casi el borde
			elif l == "s":
				agua.fijar_nivel(c, -0.35)               # la salida: el agua que llega aquí se va del nivel
			elif l == "M":
				agua.fuente_en(c, CAUDAL_MANANTIAL if _manantial_abierto else 0.0)
	var mm: MultiMesh = _cajas.multimesh
	mm.instance_count = agua.w * agua.h
	if _render == null:
		_render = AguaRender3D.new()
		add_child(_render)
		_cajas.visible = false          # por defecto se ve el dibujo bueno; Y vuelve a las cajas de depuración
	_render.enlazar(agua)
	if _gotas == null:
		_gotas = AguaMetaballs3D.new()
		_gotas.camara = _camara
		add_child(_gotas)
	if _ondas == null:
		_ondas = AguaOndas3D.new()
		add_child(_ondas)
		_ondas.objetivo = _camara
		_ondas.conectar(_render)
	_dibujar()


func _y_suelo(c: Vector2i) -> float:
	match MAPA[c.y][c.x]:
		"1":
			return NIVEL
		"2", "M":
			return 2.0 * NIVEL
		"o":
			return -NIVEL
		"r", "s":
			return -0.5 * NIVEL
		_:
			return 0.0


func _es_pared(c: Vector2i) -> bool:
	return MAPA[c.y][c.x] == "#"


func _poner_bloque_suelo(c: Vector2i) -> void:
	var l: String = MAPA[c.y][c.x]
	var alto_bloque: float = 3.0 * NIVEL if l == "#" else _y_suelo(c) + 2.0 * NIVEL
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(S, alto_bloque, S)
	var mat := StandardMaterial3D.new()
	match l:
		"#":
			mat.albedo_color = Color(0.22, 0.3, 0.2)
		"r", "s":
			mat.albedo_color = Color(0.45, 0.4, 0.32)
		"o":
			mat.albedo_color = Color(0.38, 0.33, 0.27)
		_:
			mat.albedo_color = Color(0.42, 0.55, 0.3) if (c.x + c.y) % 2 == 0 else Color(0.4, 0.52, 0.28)
	b.material = mat
	m.mesh = b
	var techo: float = 3.0 * NIVEL if l == "#" else _y_suelo(c)
	m.position = Vector3((c.x + 0.5) * S, techo - alto_bloque * 0.5, (c.y + 0.5) * S)
	_suelo_nodo.add_child(m)
	_con_colision(m, b.size)


func _physics_process(delta: float) -> void:
	if agua == null:
		return
	var t0: int = Time.get_ticks_usec()
	agua.paso(delta)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_ms_paso = lerpf(_ms_paso, ms, 0.1)
	agua.cambios()                                   # en el juego, el Lanzador las usa; aquí solo se vacían
	if _pozo_abierto:
		_pozo_t += delta
		if _pozo_lleno_t < 0.0 and float(agua.recipiente(CASILLA_POZO).get("fraccion", 0.0)) >= 0.995:
			_pozo_lleno_t = _pozo_t
	_dibujar()


## Una caja por trocito con agua: su base en el suelo y su techo en la superficie. Más azul y más opaca cuanto más honda.
func _dibujar() -> void:
	var mm: MultiMesh = _cajas.multimesh
	var l: float = agua.l
	for y in range(agua.h):
		for x in range(agua.w):
			var i: int = y * agua.w + x
			var p: float = agua.prof[i]
			var t := Transform3D()
			if p > AguaSim3D.PROF_MIN and agua.cerrado[i] == 0:
				t = t.scaled(Vector3(l * 0.98, p, l * 0.98))
				t.origin = Vector3((x + 0.5) * l, agua.suelo[i] + p * 0.5, (y + 0.5) * l)
				var hondo: float = clampf(p / 1.2, 0.0, 1.0)
				var col := Color(0.55, 0.8, 1.0).lerp(Color(0.1, 0.35, 0.85), hondo)
				if agua.helado[i] == 1:
					col = Color(0.85, 0.95, 1.0)
				col.a = lerpf(0.45, 0.85, hondo)
				mm.set_instance_color(i, col)
			else:
				t = t.scaled(Vector3(0.001, 0.001, 0.001))
				t.origin = Vector3(0, -50, 0)
			mm.set_instance_transform(i, t)
	var c: Vector2i = _casilla_raton()
	var info: String = ""
	if c.x >= 0:
		var v: Vector2 = agua.corriente_en(Vector3((c.x + 0.5) * S, 0, (c.y + 0.5) * S))
		info = "casilla %s · prof %.2f · agua %s · nado %s · corriente %.2f u/s · mojada %s" % [c, agua.profundidad_casilla(c),
			"sí" if agua.es_agua_casilla(c) else "no", "sí" if agua.se_nada_en(c) else "no", v.length(),
			"sí" if agua.casilla_mojada(c) else "no"]
	_texto.text = texto_referencia() + "\n" + "LAB AGUA · volumen %.1f u³ · %.2f ms por paso · manantial %s\n%s\nclic izq: agua · clic der: tierra · H: hielo · F: manantial · T: tronco · R: de nuevo · Y: cajas/dibujo · G: salpicadura · V: chorro" % [
		agua.volumen_total(), _ms_paso, "abierto" if _manantial_abierto else "cerrado", info]


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.is_pressed():
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camara.size = maxf(8.0, _camara.size * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camara.size = minf(60.0, _camara.size * 1.1)
		var c: Vector2i = _casilla_raton()
		if c.x < 0 or _es_pared(c):
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			agua.anadir(_punto_raton(), 3.0, 0.9)
			_ondas.impulso(_punto_raton(), 0.12, 0.9)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_alternar_tierra(c)
	elif ev is InputEventKey and ev.is_pressed() and not ev.is_echo():
		var k := ev as InputEventKey
		match k.keycode:
			KEY_R:
				_empezar()
			KEY_P:
				poner_pozo(not _pozo_abierto)
			KEY_Y:
				_cajas.visible = not _cajas.visible
				_render.visible = not _cajas.visible
			KEY_G:
				_gotas.salpicadura(_punto_raton() + Vector3(0, 0.3, 0), 28, 4.0)
			KEY_V:
				if _chorro != null and is_instance_valid(_chorro):
					_gotas.detener(_chorro)
					_chorro = null
				else:
					_chorro = _gotas.chorro(_punto_raton() + Vector3(0, 0.3, 0), Vector3(0.35, 1.0, 0.0), 7.0, 70.0)
			KEY_F:
				_manantial_abierto = not _manantial_abierto
				for y in range(ALTO):
					for x in range(ANCHO):
						if MAPA[y][x] == "M":
							agua.fuente_en(Vector2i(x, y), CAUDAL_MANANTIAL if _manantial_abierto else 0.0)
			KEY_T:
				var p: Vector3 = _punto_raton()
				if p.x > 0.0 and p.z > 0.0:
					echar_tronco(Vector3(p.x, 2.0, p.z))
			KEY_H:
				var c: Vector2i = _casilla_raton()
				if c.x >= 0 and not _es_pared(c):
					var si: bool = not _helada.has(c)
					agua.helar_casilla(c, si)
					if si:
						_helada[c] = true
					else:
						_helada.erase(c)


## Abre o cierra el manantial del pozo. Al abrir, guarda cuánto debería tardar en llenarse (por volumen) y arranca el cronómetro.
func poner_pozo(abierto: bool) -> void:
	_pozo_abierto = abierto
	agua.fuente_en(CASILLA_POZO, CAUDAL_POZO if abierto else 0.0)
	if abierto:
		_pozo_t = 0.0
		_pozo_lleno_t = -1.0
		_pozo_prevision = agua.segundos_hasta_llenar(CASILLA_POZO, CAUDAL_POZO)


## Las tres medidas de referencia como datos (para la prueba y para el texto): pozo {capacidad, volumen, fraccion, rebose, prevision, tardo},
## cascada {caida_max, casillas}, rio {media, max} (u/s).
func referencia() -> Dictionary:
	var d: Dictionary = agua.recipiente(CASILLA_POZO)
	var caida_max: float = 0.0
	var casillas: int = 0
	for c in CASILLAS_CASCADA:
		var m: float = 0.0
		for i in agua._trozos(c as Vector2i):
			m = maxf(m, agua.caida_en_trozo(i))
		caida_max = maxf(caida_max, m)
		if m >= AguaSim3D.UMBRAL_CAIDA:
			casillas += 1
	var suma: float = 0.0
	var maxv: float = 0.0
	var n: int = 0
	for y in range(ALTO):
		for x in range(ANCHO):
			if MAPA[y][x] == "r":
				var v: float = agua.corriente_en(Vector3((x + 0.5) * S, 0.0, (y + 0.5) * S)).length()
				suma += v
				maxv = maxf(maxv, v)
				n += 1
	return {"pozo": {"capacidad": float(d.get("capacidad", 0.0)), "volumen": float(d.get("volumen", 0.0)), "fraccion": float(d.get("fraccion", 0.0)),
			"rebose": float(d.get("rebose", 0.0)), "prevision": _pozo_prevision, "tardo": _pozo_lleno_t},
		"cascada": {"caida_max": caida_max, "casillas": casillas}, "rio": {"media": suma / float(maxi(n, 1)), "max": maxv}}


func texto_referencia() -> String:
	var r: Dictionary = referencia()
	var p: Dictionary = r["pozo"]
	var estado: String = "cerrado (P abre)"
	if _pozo_abierto:
		estado = "abierto %.1f s de %.1f previstos" % [_pozo_t, float(p["prevision"])]
		if float(p["tardo"]) >= 0.0:
			estado = "LLENO en %.1f s (previstos %.1f)" % [float(p["tardo"]), float(p["prevision"])]
	return "POZO %.0f %% · %.1f / %.1f u³ · rebosa a Y %.2f · manantial %s\nCASCADA caída máx %.2f u (umbral %.2f) · %d casillas caen · RÍO corriente media %.2f · máx %.2f u/s" % [
		float(p["fraccion"]) * 100.0, float(p["volumen"]), float(p["capacidad"]), float(p["rebose"]), estado,
		float(r["cascada"]["caida_max"]), AguaSim3D.UMBRAL_CAIDA, int(r["cascada"]["casillas"]), float(r["rio"]["media"]), float(r["rio"]["max"])]


func _alternar_tierra(c: Vector2i) -> void:
	if _tierra.has(c):
		(_tierra[c] as Node).queue_free()
		_tierra.erase(c)
		agua.solidificar_casilla(c, false)
		return
	agua.solidificar_casilla(c, true)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(S * 0.96, NIVEL, S * 0.96)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.36, 0.22)
	b.material = mat
	m.mesh = b
	m.position = Vector3((c.x + 0.5) * S, _y_suelo(c) + NIVEL * 0.5, (c.y + 0.5) * S)
	add_child(m)
	_con_colision(m, b.size)
	_tierra[c] = m


## Para que los troncos choquen con el suelo, las paredes y las presas (el dibujo del lab son cajas, y las cajas no chocan solas).
func _con_colision(m: Node3D, tam: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	cuerpo.add_child(col)
	m.add_child(cuerpo)


## Echa un tronco que flota (Flotador3D) a `pos`. T en el lab lo echa donde apuntas, a un par de unidades de altura.
func echar_tronco(pos: Vector3) -> Flotador3D:
	var f := Flotador3D.new()
	f.agua = agua
	add_child(f)
	f.global_position = pos
	_flotadores.append(f)
	return f


## Punto del suelo bajo el ratón (plano y = 0: basta para un laboratorio casi plano).
func _punto_raton() -> Vector3:
	var pos: Vector2 = get_viewport().get_mouse_position()
	var o: Vector3 = _camara.project_ray_origin(pos)
	var d: Vector3 = _camara.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector3(-1, 0, -1)
	var t: float = -o.y / d.y
	return o + d * t


func _casilla_raton() -> Vector2i:
	var p: Vector3 = _punto_raton()
	var c := Vector2i(int(floorf(p.x / S)), int(floorf(p.z / S)))
	if c.x < 0 or c.y < 0 or c.x >= ANCHO or c.y >= ALTO:
		return Vector2i(-1, -1)
	return c

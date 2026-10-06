extends Node2D

## TEST 2D: el mismo trozo de Test 2 (puerta norte, plaza y aldea) que en la maqueta 3D, pero en 2D de verdad:
## todo es imagen PRERENDERIZADA desde el 3D (prerender_test2d.gd) con la misma cámara y la misma luz.
##   suelo   baldosas grandes (bloques + transiciones + hierba + agua)
##   decorado cada pieza por separado, ordenada en profundidad con los personajes (y-sort)
##   personajes atlas de 8 direcciones (elfa con su grimorio, librera, goblins con garrote y escudo)
## Lo que no se prerenderiza: sombras suaves, partículas, efectos de los hechizos y el grimorio (T).
##
## Teclas: WASD mover · Shift correr · 1-6 hechizo (fuego, agua, tierra, viento, rayo, hielo) hacia donde mira
##         T grimorio · +/- zoom · P partículas · O sombras · G cuadrícula de casillas bloqueadas

const CARPETA: String = "res://poc_25d/test2d/generado/"
const ZOOM_INICIAL: float = 0.6
const VEL_ANDAR: float = 1.6
const VEL_CORRER: float = 3.0
const VFX: String = "res://poc_25d/vfx/"
const COLOR_ELEMENTO: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "tierra": Color(0.85, 0.66, 0.40),
	"viento": Color(0.75, 0.97, 0.85), "rayo": Color(1.0, 0.93, 0.40), "hielo": Color(0.72, 0.92, 1.0),
}
const ELEMENTOS: Array = ["fuego", "agua", "tierra", "viento", "rayo", "hielo"]
const SPRITE_ELEMENTO: Dictionary = {"fuego": "llama", "agua": "gota", "tierra": "roca_mediana",
	"viento": "remolino_viento", "rayo": "chispa_electrica", "hielo": "cristal_hielo"}
const ESTALLIDO_ELEMENTO: Dictionary = {"fuego": "brasa", "agua": "gota", "tierra": "piedrecitas",
	"viento": "hoja", "rayo": "destello", "hielo": "copo"}

var _d: Dictionary = {}
var _ppu: float = 180.0
var _sin: float = 0.94
var _cos: float = 0.34
var _s: float = 2.3
var _alto: float = 1.035
var _zona: Rect2i = Rect2i()
var _bloqueadas: Dictionary = {}

var _suelo: Node2D = null
var _sombras: Node2D = null
var _orden: Node2D = null             ## y-sort: decorado, personajes, efectos
var _efectos: Array[Node] = []
var _jugador: Pj2D = null
var _pos: Vector2 = Vector2.ZERO      ## posición del jugador en el mundo (x, z) en unidades
var _mira: Vector2 = Vector2(0, 1)
var _goblins: Array[Pj2D] = []
var _pos_goblin: Dictionary = {}      ## Pj2D -> Vector2 (x, z)
var _camara: Camera2D = null
var _hud: Label = null
var _grimorio: GrimorioUI = null
var _tex_sombra: Texture2D = null
var _rejilla: Node2D = null
var _avisos: PackedStringArray = PackedStringArray()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.36, 0.55, 0.33))
	var ruta: String = CARPETA + "test2d.json"
	if not FileAccess.file_exists(ruta):
		_mostrar_falta()
		return
	_d = JSON.parse_string(FileAccess.get_file_as_string(ruta)) as Dictionary
	_ppu = float(_d["ppu"])
	_sin = float(_d["sin_e"])
	_cos = float(_d["cos_e"])
	_s = float(_d["celda"])
	_alto = float(_d["alto_suelo"])
	var z: Array = _d["zona"]
	_zona = Rect2i(int(z[0]), int(z[1]), int(z[2]), int(z[3]))
	for b in _d["bloqueadas"]:
		_bloqueadas[Vector2i(int(b[0]), int(b[1]))] = true

	_tex_sombra = _textura_sombra()
	_suelo = Node2D.new()
	_suelo.z_index = -100
	add_child(_suelo)
	_sombras = Node2D.new()
	_sombras.z_index = -50
	add_child(_sombras)
	_orden = Node2D.new()
	_orden.y_sort_enabled = true
	add_child(_orden)

	_montar_suelo()
	_montar_decorado()
	_montar_personajes()
	_montar_efectos_fijos()
	_montar_rejilla()

	_camara = Camera2D.new()
	# 0,6 = la misma distancia que PruebaTest2 a su zoom inicial (6 unidades de alto de pantalla).
	_camara.zoom = Vector2(ZOOM_INICIAL, ZOOM_INICIAL)
	_camara.position_smoothing_enabled = true
	_camara.position_smoothing_speed = 10.0
	add_child(_camara)
	_camara.make_current()
	_camara.position = _jugador.position if _jugador != null else Vector2.ZERO

	_grimorio = GrimorioUI.new()
	add_child(_grimorio)
	_grimorio.abierto_cambiado.connect(_al_abrir_grimorio)

	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 8.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_actualizar_hud()


func _mostrar_falta() -> void:
	var l := Label.new()
	l.text = "Faltan las imágenes del Test 2D.\nAbre poc_25d/test2d/PrerenderTest2D.tscn y pulsa F6 (tarda unos minutos)."
	l.position = Vector2(40, 40)
	add_child(l)


## --- Coordenadas ---

## Mundo (x, z) sobre el suelo -> píxel 2D.
func _a_pixel(w: Vector2, y: float = -1.0) -> Vector2:
	var alto: float = _alto if y < 0.0 else y
	return Vector2(w.x, w.y * _sin - alto * _cos) * _ppu


func _celda(w: Vector2) -> Vector2i:
	return Vector2i(floori(w.x / _s), floori(w.y / _s))


func _centro_celda(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * _s


func _letra(c: Vector2i) -> String:
	var filas: Array = _d["mapa"]
	var fy: int = c.y - _zona.position.y
	var fx: int = c.x - _zona.position.x
	if fy < 0 or fy >= filas.size() or fx < 0 or fx >= String(filas[fy]).length():
		return "#"
	return String(filas[fy])[fx]


func _pisable(w: Vector2) -> bool:
	var c: Vector2i = _celda(w)
	if not _zona.has_point(c):
		return false
	return not _bloqueadas.has(c) and _letra(c) != "#"


## --- Montaje ---

func _montar_suelo() -> void:
	for b in _d["baldosas"]:
		var ruta: String = CARPETA + String(b["archivo"])
		if not ResourceLoader.exists(ruta):
			_avisos.append("falta " + String(b["archivo"]))
			continue
		var s := Sprite2D.new()
		s.texture = load(ruta) as Texture2D
		s.centered = false
		s.position = Vector2(float(b["x"]), float(b["y"]))
		_suelo.add_child(s)


func _montar_decorado() -> void:
	var hojas: Array[Texture2D] = []
	for i in range(int(_d.get("hojas_decorado", 0))):
		var ruta: String = CARPETA + "decorado_%d.webp" % i
		hojas.append(load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null)
	for p in _d["piezas"]:
		var hoja: int = int(p["hoja"])
		if hoja >= hojas.size() or hojas[hoja] == null:
			continue
		var r: Array = p["rect"]
		var at := AtlasTexture.new()
		at.atlas = hojas[hoja]
		at.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var base := Vector2(float(p["base"][0]), float(p["base"][1]))
		var s := Sprite2D.new()
		s.texture = at
		s.centered = false
		s.position = base
		s.offset = Vector2(float(p["pos"][0]), float(p["pos"][1])) - base
		_orden.add_child(s)
		# Sombra suave bajo las piezas con volumen (árboles, rocas, puestos...).
		var ancho: float = float(p.get("ancho_base", 100.0))
		if ancho > 0.35 * _ppu:
			_sombra(base, ancho * 0.75, 0.28)


func _montar_personajes() -> void:
	var pjs: Dictionary = _d["personajes"]
	for y in range(_zona.position.y, _zona.end.y):
		for x in range(_zona.position.x, _zona.end.x):
			var c := Vector2i(x, y)
			match _letra(c):
				"A", "W":
					var g: Pj2D = _crear_pj("goblin", pjs, _centro_celda(c))
					if g != null:
						_goblins.append(g)
						_pos_goblin[g] = _centro_celda(c)
				"n", "Q":
					_crear_pj("librera", pjs, _centro_celda(c) + Vector2(0.0, -_s * 0.35))
				"M":
					_crear_pj("librera", pjs, _centro_celda(c))
	# La elfa empieza en la aldea, delante de los puestos.
	_pos = _centro_celda(Vector2i(19, 32))
	_jugador = _crear_pj("elfa", pjs, _pos)


func _crear_pj(nombre: String, pjs: Dictionary, w: Vector2) -> Pj2D:
	if not pjs.has(nombre):
		_avisos.append("sin " + nombre)
		return null
	var pj := Pj2D.new()
	pj.name = nombre
	pj.position = _a_pixel(w)
	_orden.add_child(pj)
	pj.preparar(pjs[nombre], CARPETA)
	var sombra: Sprite2D = _sombra(pj.position, 0.55 * _ppu, 0.32)
	pj.set_meta("sombra", sombra)
	return pj


## Mancha de sombra ovalada (achatada por la inclinación de la cámara).
func _sombra(p: Vector2, ancho: float, alfa: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex_sombra
	s.position = p
	s.scale = Vector2(ancho, ancho * _sin * 0.55) / 64.0
	s.modulate = Color(0.12, 0.16, 0.10, alfa)
	_sombras.add_child(s)
	return s


func _textura_sombra() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Esporas en las plantas mágicas, círculo rúnico en los guardados y pétalos en el aire.
func _montar_efectos_fijos() -> void:
	for y in range(_zona.position.y, _zona.end.y):
		for x in range(_zona.position.x, _zona.end.x):
			var c := Vector2i(x, y)
			if _letra(c) in ["s", "f", "q"]:
				var e: GPUParticles2D = _particulas("esporas", 5, 3.5, Vector2(30, 20), 12.0, 0.35, true,
					Color(0.9, 1.0, 0.8, 0.8), Vector2(0, -8))
				e.position = _a_pixel(_centro_celda(c), _alto + 0.5)
				_orden.add_child(e)
				_efectos.append(e)
	for g in _d.get("guardados", []):
		var c2 := Vector2i(int(g[0]), int(g[1]))
		if not _zona.has_point(c2):
			continue
		var disco := Sprite2D.new()
		disco.texture = load(VFX + "circulo_runico.png") as Texture2D
		disco.position = _a_pixel(_centro_celda(c2), _alto + 0.05)
		disco.scale = Vector2(1.0, _sin) * (_s * 0.8 * _ppu / 256.0)
		disco.modulate = Color(0.6, 0.85, 1.0, 0.85)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		disco.material = m
		disco.z_index = -40
		add_child(disco)
		var tw := disco.create_tween().set_loops()
		tw.tween_property(disco, "rotation", TAU, 14.0).as_relative()
		_efectos.append(disco)
	var petalos: GPUParticles2D = _particulas("petalo", 30, 7.0, Vector2(1100, 50), 25.0, 0.22, false,
		Color.WHITE, Vector2(18, 30))
	petalos.name = "Petalos"
	petalos.z_index = 50
	(petalos.process_material as ParticleProcessMaterial).angular_velocity_min = -60.0
	(petalos.process_material as ParticleProcessMaterial).angular_velocity_max = 60.0
	add_child(petalos)
	_efectos.append(petalos)


func _particulas(textura: String, n: int, vida: float, caja: Vector2, vel: float, tam: float, aditivo: bool,
		color: Color, gravedad: Vector2) -> GPUParticles2D:
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(caja.x, caja.y, 1.0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = vel * 0.5
	pm.initial_velocity_max = vel
	pm.gravity = Vector3(gravedad.x, gravedad.y, 0)
	var esc: float = tam * _ppu / 256.0
	pm.scale_min = esc * 0.7
	pm.scale_max = esc * 1.3
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var gp := GPUParticles2D.new()
	gp.amount = n
	gp.lifetime = vida
	gp.process_material = pm
	gp.texture = load(VFX + textura + ".png") as Texture2D
	gp.visibility_rect = Rect2(-2000, -2000, 4000, 4000)
	if aditivo:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		gp.material = m
	return gp


## Cuadrícula de casillas bloqueadas (tecla G), para comprobar que la colisión cuadra con el dibujo.
func _montar_rejilla() -> void:
	_rejilla = Node2D.new()
	_rejilla.z_index = 60
	_rejilla.visible = false
	_rejilla.draw.connect(_dibujar_rejilla)
	add_child(_rejilla)


func _dibujar_rejilla() -> void:
	for y in range(_zona.position.y, _zona.end.y):
		for x in range(_zona.position.x, _zona.end.x):
			var c := Vector2i(x, y)
			var a: Vector2 = _a_pixel(Vector2(c) * _s)
			var b: Vector2 = _a_pixel(Vector2(c + Vector2i.ONE) * _s)
			var col := Color(1, 0.2, 0.2, 0.25) if not _pisable(_centro_celda(c)) else Color(1, 1, 1, 0.05)
			_rejilla.draw_rect(Rect2(a, b - a), col, true)
			_rejilla.draw_rect(Rect2(a, b - a), Color(0, 0, 0, 0.2), false, 1.0)


## --- Hechizos (2D, con los sprites de vfx/) ---

func _lanzar(elemento: String) -> void:
	if _jugador == null:
		return
	if _jugador.tiene("cast"):
		_jugador.jugar("cast")
	var col: Color = COLOR_ELEMENTO[elemento]
	var desde: Vector2 = _pos + _mira.normalized() * 0.4
	var hasta: Vector2 = _pos + _mira.normalized() * 5.0
	# Si hay un goblin cerca de esa línea, va a por él.
	for g in _goblins:
		var gp: Vector2 = _pos_goblin[g]
		if gp.distance_to(_pos) < 7.0 and (gp - _pos).normalized().dot(_mira.normalized()) > 0.8:
			hasta = gp
			break
	_circulo_carga(_pos, col)
	if elemento == "rayo" or elemento == "tierra":
		get_tree().create_timer(0.25).timeout.connect(_impacto.bind(elemento, hasta))
		return
	var bala := Node2D.new()
	_orden.add_child(bala)
	var spr := Sprite2D.new()
	spr.texture = load(VFX + String(SPRITE_ELEMENTO[elemento]) + ".png") as Texture2D
	spr.scale = Vector2.ONE * (0.55 * _ppu / 256.0)
	spr.position = Vector2(0, -0.6 * _cos * _ppu - 0.3 * _ppu)
	bala.add_child(spr)
	var estela: GPUParticles2D = _particulas(String(ESTALLIDO_ELEMENTO[elemento]), 24, 0.5, Vector2(6, 6), 15.0,
		0.16, elemento == "fuego" or elemento == "hielo", col, Vector2.ZERO)
	estela.local_coords = false
	estela.position = spr.position
	bala.add_child(estela)
	var t: float = maxf(0.15, desde.distance_to(hasta) / 7.0)
	var tw := bala.create_tween()
	tw.tween_method(func(f: float) -> void: bala.position = _a_pixel(desde.lerp(hasta, f)), 0.0, 1.0, t)
	tw.tween_callback(_impacto.bind(elemento, hasta))
	tw.tween_callback(func() -> void:
		spr.visible = false
		estela.emitting = false)
	tw.tween_interval(0.6)
	tw.tween_callback(bala.queue_free)


func _circulo_carga(w: Vector2, col: Color) -> void:
	var d := Sprite2D.new()
	d.texture = load(VFX + "circulo_runico.png") as Texture2D
	d.position = _a_pixel(w, _alto + 0.03)
	d.scale = Vector2(1.0, _sin) * (1.3 * _ppu / 256.0) * 0.3
	d.modulate = col
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	d.material = m
	d.z_index = -40
	add_child(d)
	var tw := d.create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "scale", Vector2(1.0, _sin) * (1.3 * _ppu / 256.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "rotation", PI * 0.6, 0.7)
	tw.chain().tween_property(d, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(d.queue_free)


func _impacto(elemento: String, w: Vector2) -> void:
	var col: Color = COLOR_ELEMENTO[elemento]
	var e: GPUParticles2D = _particulas(String(ESTALLIDO_ELEMENTO[elemento]), 22, 0.9, Vector2(8, 8), 140.0, 0.2,
		elemento in ["fuego", "rayo", "hielo"], col, Vector2(0, 160))
	e.one_shot = true
	e.explosiveness = 0.95
	(e.process_material as ParticleProcessMaterial).spread = 180.0
	e.position = _a_pixel(w, _alto + 0.5)
	_orden.add_child(e)
	e.emitting = true
	get_tree().create_timer(1.5).timeout.connect(e.queue_free)
	var grande := Sprite2D.new()
	var nombre: String = {"fuego": "llama", "agua": "salpicadura", "tierra": "pua_tierra", "viento": "remolino_viento",
		"rayo": "rayo", "hielo": "cristal_hielo"}[elemento]
	grande.texture = load(VFX + nombre + ".png") as Texture2D
	grande.position = _a_pixel(w)
	grande.offset = Vector2(0, -128)
	var tam: float = (2.4 if elemento == "rayo" else 1.1) * _ppu / 256.0
	grande.scale = Vector2.ONE * tam * 0.3
	if elemento in ["fuego", "rayo"]:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		grande.material = m
	_orden.add_child(grande)
	var tw := grande.create_tween()
	tw.tween_property(grande, "scale", Vector2.ONE * tam, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(grande, "modulate:a", 0.0, 0.3)
	tw.tween_callback(grande.queue_free)
	_circulo_carga(w, col)
	# El goblin alcanzado se queja.
	for g in _goblins:
		if (_pos_goblin[g] as Vector2).distance_to(w) < 1.0:
			g.jugar("hit")


## --- Bucle ---

func _process(delta: float) -> void:
	if _jugador == null:
		return
	if _grimorio == null or not _grimorio.abierto:
		_mover(delta)
	_camara.position = _jugador.position + Vector2(0, -30)
	var petalos: Node = get_node_or_null("Petalos")
	if petalos != null:
		(petalos as Node2D).position = _camara.position + Vector2(0, -500)
	for g in _goblins:
		var d: Vector2 = _pos - (_pos_goblin[g] as Vector2)
		if d.length() < 7.0:
			g.mirar(d)
			if d.length() < 1.6 and g.animacion == "idle" and randf() < delta * 0.8:
				g.jugar("attack")
	_actualizar_hud()


func _mover(delta: float) -> void:
	var entrada := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		entrada.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		entrada.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		entrada.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		entrada.y += 1.0
	if entrada == Vector2.ZERO:
		if _jugador.animacion in ["walk", "run"]:
			_jugador.jugar("idle")
		return
	var mov: Vector2 = entrada.normalized()
	_mira = mov
	var correr: bool = Input.is_key_pressed(KEY_SHIFT)
	var paso: Vector2 = mov * (VEL_CORRER if correr else VEL_ANDAR) * delta
	var destino: Vector2 = _pos + paso
	if not _pisable(destino):
		destino = _pos + Vector2(paso.x, 0.0)
		if not _pisable(destino):
			destino = _pos + Vector2(0.0, paso.y)
			if not _pisable(destino):
				destino = _pos
	_pos = destino
	_jugador.position = _a_pixel(_pos)
	(_jugador.get_meta("sombra") as Node2D).position = _jugador.position
	_jugador.mirar(mov)
	if _jugador.animacion != "cast":
		_jugador.jugar("run" if correr else "walk")


func _al_abrir_grimorio(abierto: bool) -> void:
	if _jugador == null:
		return
	_jugador.jugar("leer" if abierto else "idle")
	# El grimorio pone el mundo a cámara lenta: la elfa sigue leyendo a velocidad normal.
	_jugador.ignorar_camara_lenta = abierto


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			_lanzar(String(ELEMENTOS[k.keycode - KEY_1]))
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_camara.zoom = (_camara.zoom * 1.15).clamp(Vector2(0.2, 0.2), Vector2(3.0, 3.0))
		KEY_MINUS, KEY_KP_SUBTRACT:
			_camara.zoom = (_camara.zoom / 1.15).clamp(Vector2(0.2, 0.2), Vector2(3.0, 3.0))
		KEY_P:
			for e in _efectos:
				(e as CanvasItem).visible = not (e as CanvasItem).visible
		KEY_O:
			_sombras.visible = not _sombras.visible
		KEY_G:
			_rejilla.visible = not _rejilla.visible
			_rejilla.queue_redraw()


## Para pruebas y capturas: lanza un hechizo mirando hacia `dir` (x, z).
func probar_hechizo(datos: Array) -> void:
	_mira = Vector2(float(datos[1]), float(datos[2]))
	if _jugador != null:
		_jugador.mirar(_mira)
	_lanzar(String(datos[0]))


## Para pruebas y capturas: pone a la elfa en una casilla.
func ir_a(c: Vector2i) -> void:
	_pos = _centro_celda(c)
	if _jugador != null:
		_jugador.position = _a_pixel(_pos)
		(_jugador.get_meta("sombra") as Node2D).position = _jugador.position
		_camara.position = _jugador.position
		_camara.reset_smoothing()


func _actualizar_hud() -> void:
	if _hud == null:
		return
	var aviso: String = "" if _avisos.is_empty() else "\n(!) " + ", ".join(_avisos.slice(0, 6))
	_hud.text = "TEST 2D (prerender) | %d FPS | zoom %.2f\nWASD mover · Shift correr · 1-6 hechizo · T grimorio · +/- zoom · P partículas · O sombras · G casillas%s" % [
		int(Engine.get_frames_per_second()), _camara.zoom.x if _camara != null else 1.0, aviso]

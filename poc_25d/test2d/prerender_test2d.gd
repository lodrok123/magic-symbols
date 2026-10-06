extends Node

## PRERENDER DEL TEST 2D. Monta la maqueta 3D de Test 2 (PruebaTest2) dentro de un SubViewport y saca, con
## la MISMA cámara (ortográfica, 20° de inclinación) y la misma luz:
##   1. el suelo de la zona elegida en baldosas de 1024 px (JPG): bloques, transiciones, hierba, agua y las
##      piezas planas (baldosa de guardado, placa, puente)
##   2. cada pieza de decorado por separado (PNG con transparencia), con su punto de apoyo, para ordenarla en
##      profundidad con los personajes
##   3. los personajes (elfa, librera, goblin) en 8 direcciones y varias animaciones, en atlas
## y lo deja todo en poc_25d/test2d/generado/ con un `test2d.json` que lee test_2d.gd.
##
## Uso: abre PrerenderTest2D.tscn y pulsa F6. Tarda unos minutos; al acabar se cierra solo. En tu PC (Forward+)
## sale con sombras y mejor luz que en la nube. Después abre Test2D.tscn.

const TEST2 = preload("res://test_2.gd")
const ESCENA_3D: String = "res://poc_25d/PruebaTest2.tscn"
const SALIDA: String = "res://poc_25d/test2d/generado/"

## Zona de Test 2 que se convierte: columnas 13-26 y filas 5-33 (puerta norte, plaza, aldea).
const ZONA: Rect2i = Rect2i(13, 5, 14, 29)
## Píxeles por unidad del mundo. 180 = lo que se ve en PruebaTest2 a zoom 6 en una pantalla de 1080 px de alto:
## así el Test 2D se ve nítido a la misma distancia (zoom 1 de la Camera2D).
const PPU: float = 180.0
const PPU_PJ: float = 180.0
const ELEV: float = 70.0              ## grados sobre el horizonte (= 20° respecto a la vertical)
const BALDOSA: int = 1024
const CELDA_PJ: Vector2i = Vector2i(256, 256)
const PIES_PJ: Vector2i = Vector2i(128, 176)   ## dónde caen los pies dentro de cada celda del atlas
const PLANAS: Array = ["baldosa_guardado", "placa_peso", "puente", "pasadero"]

## Personajes: id del modelo, animaciones [nombre, fotogramas, en bucle].
const PERSONAJES: Dictionary = {
	"elfa": ["chibi_elf", [["idle", 8, true], ["walk", 8, true], ["run", 8, true], ["cast", 10, false],
		["leer", 8, true]]],
	"librera": ["bookseller_chibi", [["idle", 8, true], ["talk", 8, true]]],
	"goblin": ["goblin_warrior_chibi", [["idle", 8, true], ["walk", 8, true], ["attack", 8, false],
		["hit", 6, false]]],
}
## 8 direcciones: nombre y giro del modelo (0 = mirando a la cámara, hacia abajo en pantalla).
const DIRS: Array = [["S", 0.0], ["SE", 45.0], ["E", 90.0], ["NE", 135.0], ["N", 180.0], ["NW", -135.0],
	["W", -90.0], ["SW", -45.0]]

var _vp: SubViewport = null
var _t2: Node3D = null
var _cam: Camera3D = null
var _env: Environment = null
var _fondo: Color = Color.BLACK
var _datos: Dictionary = {}
var _rotulo: Label = null


func _ready() -> void:
	_rotulo = Label.new()
	_rotulo.position = Vector2(20, 20)
	add_child(_rotulo)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	_vp = SubViewport.new()
	_vp.size = Vector2i(BALDOSA, BALDOSA)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_t2 = (load(ESCENA_3D) as PackedScene).instantiate() as Node3D
	_t2.set("decorado_por_lotes", false)    # aquí hace falta cada pieza como nodo para recortarla
	_t2.set("hierba_completa", true)        # y la hierba de toda la zona, no solo la de alrededor de la chibi
	_t2.set("precalentar_al_inicio", false)
	_t2.set("objetos_reactivos", false)   # sin velo ni hechizos de calentamiento
	_vp.add_child(_t2)
	await _frames(3)
	_preparar()
	await _suelo()
	await _decorado()
	await _personajes()
	_guardar_json()
	_aviso("Hecho. Abre poc_25d/test2d/Test2D.tscn")
	await _frames(30)
	get_tree().quit()


func _aviso(t: String) -> void:
	_rotulo.text = "PRERENDER TEST 2D\n" + t
	print("[prerender] ", t)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## Quita de la maqueta lo que no es escenario (HUD, cámara que sigue, personajes, partículas) y pone la cámara.
func _preparar() -> void:
	_t2.set_process(false)
	_t2.set_process_unhandled_input(false)
	for h in _t2.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		if h is Pj3D:
			(h as Node3D).visible = false
		if h is Camera3D:
			(h as Camera3D).current = false
		if h is WorldEnvironment:
			_env = (h as WorldEnvironment).environment
		if h is DirectionalLight3D:
			# En la nube (renderizador de compatibilidad) las sombras salen quemadas: solo con Forward+.
			var compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
			(h as DirectionalLight3D).shadow_enabled = not compat
	(_t2.get("_efectos") as Node3D).visible = false
	_fondo = _env.background_color
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.1
	_cam.far = 400.0
	_vp.add_child(_cam)
	_cam.current = true
	var e: float = deg_to_rad(ELEV)
	_datos = {
		"zona": [ZONA.position.x, ZONA.position.y, ZONA.size.x, ZONA.size.y],
		"celda": _s(), "alto_suelo": _alto(), "ppu": PPU, "ppu_pj": PPU_PJ, "elev": ELEV,
		"sin_e": sin(e), "cos_e": cos(e), "baldosas": [], "piezas": [], "personajes": {},
	}


func _s() -> float:
	return float(_t2.get("S"))


func _alto() -> float:
	return float(_t2.get("ALTO"))


## Proyección a píxeles 2D (sin cámara): x a la derecha, y hacia abajo en pantalla.
func _p(w: Vector3, ppu: float) -> Vector2:
	var e: float = deg_to_rad(ELEV)
	return Vector2(w.x, w.z * sin(e) - w.y * cos(e)) * ppu


## Pone la cámara para que el píxel `centro` (en el espacio de _p con `ppu`) quede en el centro del viewport.
func _encuadrar(centro: Vector2, tam: Vector2i, ppu: float) -> void:
	var e: float = deg_to_rad(ELEV)
	var dir := Vector3(0.0, -sin(e), -cos(e))
	var y: float = _alto()
	# Punto del plano y = alto que cae en ese píxel.
	var w := Vector3(centro.x / ppu, y, (centro.y / ppu + y * cos(e)) / sin(e))
	_vp.size = tam
	_cam.size = float(tam.y) / ppu
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), w - dir * 80.0)


func _captura() -> Image:
	await _frames(3)
	return _vp.get_texture().get_image()


## --- 1. Suelo ---

func _suelo() -> void:
	var props: Node3D = _t2.get("_props") as Node3D
	for c in props.get_children():
		(c as Node3D).visible = PLANAS.has(_id_de(c))
	_env.background_mode = Environment.BG_COLOR
	_vp.transparent_bg = false
	var s: float = _s()
	var a: Vector2 = _p(Vector3(ZONA.position.x * s, _alto(), ZONA.position.y * s), PPU)
	var b: Vector2 = _p(Vector3(ZONA.end.x * s, _alto(), ZONA.end.y * s), PPU)
	var origen := Vector2(floorf(a.x), floorf(a.y))
	var total := Vector2i(int(ceilf(b.x - origen.x)), int(ceilf(b.y - origen.y)))
	_datos["suelo_origen"] = [origen.x, origen.y]
	_datos["suelo_tam"] = [total.x, total.y]
	var n: int = 0
	for ty in range(int(ceilf(float(total.y) / BALDOSA))):
		for tx in range(int(ceilf(float(total.x) / BALDOSA))):
			var tam := Vector2i(mini(BALDOSA, total.x - tx * BALDOSA), mini(BALDOSA, total.y - ty * BALDOSA))
			var esquina: Vector2 = origen + Vector2(tx * BALDOSA, ty * BALDOSA)
			_encuadrar(esquina + Vector2(tam) * 0.5, tam, PPU)
			var img: Image = await _captura()
			var nombre: String = "suelo_%d_%d.webp" % [tx, ty]
			img.save_webp(SALIDA + nombre, true, 0.9)
			_datos["baldosas"].append({"archivo": nombre, "x": esquina.x, "y": esquina.y})
			n += 1
			_aviso("suelo %d" % n)


## --- 2. Decorado ---

func _id_de(n: Node) -> String:
	for h in n.get_children():
		if h is Node3D and not (h is Label3D):
			return String(h.name)
	return ""


func _decorado() -> void:
	var props: Node3D = _t2.get("_props") as Node3D
	# Fuera el suelo y la hierba: solo la pieza, sobre fondo transparente.
	for h in _t2.get_children():
		if h is MultiMeshInstance3D or h is Hierba3D:
			(h as Node3D).visible = false
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_vp.transparent_bg = true
	var lista: Array[Node3D] = []
	var s: float = _s()
	for c in props.get_children():
		(c as Node3D).visible = false
		if not (c is Node3D) or c is Label3D or c.get_child_count() == 0:
			continue
		var id: String = _id_de(c)
		if id == "" or PLANAS.has(id):
			continue
		var p: Vector3 = (c as Node3D).global_position
		var celda := Vector2i(floori(p.x / s), floori(p.z / s))
		if ZONA.has_point(celda):
			lista.append(c as Node3D)
	var hojas: Array = []   # [Image, ...]
	var hoja := Image.create_empty(2048, 2048, false, Image.FORMAT_RGBA8)
	var cursor := Vector2i.ZERO
	var alto_fila: int = 0
	var k: int = 0
	for c in lista:
		c.visible = true
		var caja: AABB = _caja_global(c)
		var r: Rect2 = Rect2()
		for i in range(8):
			var q: Vector2 = _p(caja.get_endpoint(i), PPU)
			r = Rect2(q, Vector2.ZERO) if i == 0 else r.expand(q)
		r = r.grow(6.0)
		var tam := Vector2i(int(ceilf(r.size.x)), int(ceilf(r.size.y)))
		tam = Vector2i(clampi(tam.x, 8, 2040), clampi(tam.y, 8, 2040))
		var esquina := Vector2(floorf(r.position.x), floorf(r.position.y))
		_encuadrar(esquina + Vector2(tam) * 0.5, tam, PPU)
		var img: Image = await _captura()
		c.visible = false
		var util: Rect2i = img.get_used_rect()
		if util.size.x == 0:
			continue
		if cursor.x + util.size.x > 2048:
			cursor = Vector2i(0, cursor.y + alto_fila + 2)
			alto_fila = 0
		if cursor.y + util.size.y > 2048:
			hojas.append(hoja)
			hoja = Image.create_empty(2048, 2048, false, Image.FORMAT_RGBA8)
			cursor = Vector2i.ZERO
			alto_fila = 0
		hoja.blit_rect(img, util, cursor)
		var base: Vector2 = _p(c.global_position, PPU)
		_datos["piezas"].append({
			"id": _id_de(c), "hoja": hojas.size(), "rect": [cursor.x, cursor.y, util.size.x, util.size.y],
			"pos": [esquina.x + util.position.x, esquina.y + util.position.y],
			"base": [base.x, base.y],
			"ancho_base": caja.size.x * PPU,
			"celda": [floori(c.global_position.x / s), floori(c.global_position.z / s)],
		})
		cursor.x += util.size.x + 2
		alto_fila = maxi(alto_fila, util.size.y)
		k += 1
		_aviso("decorado %d / %d" % [k, lista.size()])
	hojas.append(hoja)
	for i in range(hojas.size()):
		var h: Image = hojas[i]
		h.save_webp(SALIDA + "decorado_%d.webp" % i, true, 0.92)
	_datos["hojas_decorado"] = hojas.size()


func _caja_global(n: Node) -> AABB:
	var res := AABB()
	var vacia: bool = true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var c: AABB = mi.global_transform * mi.mesh.get_aabb()
		res = c if vacia else res.merge(c)
		vacia = false
	return res


## --- 3. Personajes ---

func _personajes() -> void:
	_t2.visible = false
	# La luz y el ambiente de la maqueta, pero sin su mundo: un sol y un entorno iguales en el viewport.
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	luz.light_color = Color(1.0, 0.96, 0.88)
	luz.light_energy = 0.78
	_vp.add_child(luz)
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_vp.transparent_bg = true
	for nombre in PERSONAJES:
		var def: Array = PERSONAJES[nombre]
		var pj := Pj3D.new()
		_vp.add_child(pj)
		if not pj.cargar(String(def[0])):
			pj.queue_free()
			continue
		pj.set_alto(1.0)
		# Sin el disco de sombra del 3D: en 2D la sombra la dibuja test_2d.gd, suave y debajo de todo.
		for m in pj.get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).mesh is CylinderMesh:
				(m as MeshInstance3D).visible = false
		var ap: AnimationPlayer = pj.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var animaciones: Dictionary = {}
		for a in def[1]:
			var anim: String = String(a[0])
			var n: int = int(a[1])
			var bucle: bool = bool(a[2])
			var clip: String = pj._buscar_clip(anim)
			if clip == "":
				continue
			var largo: float = ap.get_animation(clip).length
			var atlas := Image.create_empty(CELDA_PJ.x * n, CELDA_PJ.y * DIRS.size(), false, Image.FORMAT_RGBA8)
			for d in range(DIRS.size()):
				pj.rotation_degrees.y = float(DIRS[d][1])
				for f in range(n):
					var t: float = largo * float(f) / float(n if bucle else maxi(n - 1, 1))
					ap.play(clip)
					ap.seek(minf(t, largo - 0.001), true)
					ap.pause()
					var pies: Vector2 = _p(pj.global_position, PPU_PJ)
					var centro: Vector2 = pies - Vector2(PIES_PJ) + Vector2(CELDA_PJ) * 0.5
					_encuadrar(centro, CELDA_PJ, PPU_PJ)
					var img: Image = await _captura()
					atlas.blit_rect(img, Rect2i(Vector2i.ZERO, CELDA_PJ), Vector2i(f * CELDA_PJ.x, d * CELDA_PJ.y))
			var archivo: String = "%s_%s.webp" % [nombre, anim]
			atlas.save_webp(SALIDA + archivo, true, 0.92)
			animaciones[anim] = {"archivo": archivo, "fotogramas": n, "bucle": bucle, "fps": 10.0 if anim != "idle" else 7.0}
			_aviso("%s: %s" % [nombre, anim])
		_datos["personajes"][nombre] = {"celda": [CELDA_PJ.x, CELDA_PJ.y], "pies": [PIES_PJ.x, PIES_PJ.y],
			"direcciones": DIRS.map(func(x: Array) -> String: return String(x[0])), "animaciones": animaciones}
		pj.queue_free()
		await _frames(2)


## --- Datos del nivel para test_2d.gd ---

func _guardar_json() -> void:
	var mapa: PackedStringArray = TEST2.MAPA_TEST2
	var bloqueadas: Dictionary = _t2.get("_bloqueadas")
	var filas: Array = []
	var cerradas: Array = []
	for y in range(ZONA.position.y, ZONA.end.y):
		filas.append(mapa[y].substr(ZONA.position.x, ZONA.size.x))
		for x in range(ZONA.position.x, ZONA.end.x):
			if bloqueadas.has(Vector2i(x, y)):
				cerradas.append([x, y])
	_datos["mapa"] = filas
	_datos["bloqueadas"] = cerradas
	_datos["guardados"] = TEST2.GUARDADOS_T2.map(func(v: Vector2i) -> Array: return [v.x, v.y])
	var f := FileAccess.open(SALIDA + "test2d.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_datos, "\t"))
	f.close()

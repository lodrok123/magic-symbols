extends SceneTree
## TIRA DE EROSION A TIEMPO REAL (8/11/2026, docs/estudios/VFX_DIAGNOSTICO_2026-11-07.md §5): ¿se lee la erosion a la velocidad a la que mueren de verdad las cuatro bolas?
## No inventa valores de `vida`: crea cada toy (AguaToy, FuegoToy, HieloToy, RayoToy) como BOLA, lo deja nacer y lo mata por el MISMO camino que en el juego (vfx_toy_juego.gd);
## la `vida` del shader la mueve la animacion «morir» del propio toy. Fotografia en instantes de tiempo de escena (fotogramas fijos, --fixed-fps 240) y rotula los ms.
##   modo `golpe`   (camino real de un proyectil que choca): impactar_en() -> «morir» a velocidad x4, mas el impacto que nace en el mismo sitio.
##   modo `aislada` lo mismo SIN el impacto (solo la bola), para juzgar la erosion sin el destello encima.
##   modo `fin`     (camino real de un proyectil que se agota en el aire): terminar_sin_choque() -> la bola se ENCOGE y, con erosion, `vida` baja con esa misma rampa de 500 ms (EfectoToy._vida_erosion).
## godot --rendering-driver opengl3 --fixed-fps 240 --path . --script res://herramientas/captura_vfx_erosion_tira.gd -- <png_salida> <0|1 erosion> <golpe|aislada|fin>
## Dos pasadas (0 y 1) dan los mismos instantes. Imprime por la salida estandar la duracion real de cada muerte y la posicion de la animacion en cada columna.
const FPS: int = 240
const AJUSTE: int = 240                  ## fotogramas de espera antes de matarlos (1 s: «nacer» ya acabo y las particulas estan en regimen)
const ANCHO_CEL: int = 360
const ALTO_CEL: int = 1000
const MARGEN_X: int = 150
const MARGEN_Y: int = 64
const ELEMENTOS: Array = ["agua", "fuego", "hielo", "rayo"]
const Y_FILA: Array = [4.8, 3.2, 1.6, 0.0]
const R_BOLA: float = 0.4

var _out: String = ""
var _modo: String = "golpe"
var _paso: int = 3                       ## fotogramas entre columnas
var _cols: int = 11
var _vp: SubViewport
var _mundo: Node3D
var _toys: Array = []
var _f: int = 0
var _celdas: Array = []                  ## Image por columna
var _ms: Array = []                      ## ms transcurridos de cada columna
var _pedidas: int = 0
var _dur_ms: Array = []
var _montando: bool = false
var _comp: Image
var _vp2: SubViewport
var _esperas: int = 0

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_out = a[0]
	VfxKit3D.usar_erosion = a[1] == "1"
	_modo = a[2] if a.size() > 2 else "golpe"
	if _modo == "fin":
		_paso = 12
	seed(20261108)
	_vp = SubViewport.new()
	_vp.size = Vector2i(ANCHO_CEL, ALTO_CEL)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.4
	_mundo.add_child(cam)
	cam.position = Vector3(0.0, 2.4, 12.0)
	cam.current = true
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.34, 0.30)
	var we := WorldEnvironment.new()
	we.environment = env
	_mundo.add_child(we)
	for i in ELEMENTOS.size():
		var t: Node3D = null
		match ELEMENTOS[i]:
			"agua":
				t = AguaToy.new()
			"fuego":
				t = FuegoToy.new()
			"hielo":
				t = HieloToy.new()
			_:
				t = RayoToy.new()
		t.set("casilla", Terreno3D.casilla)
		_mundo.add_child(t)
		t.position = Vector3(0.0, float(Y_FILA[i]), 0.0)
		t.rotation.y = -PI / 2.0                                           # vuela hacia la derecha, de perfil a la camara
		t.call("definir", 0, R_BOLA, R_BOLA, R_BOLA, true)                 # Figura.BOLA = 0 en las cuatro clases
		t.call("lanzar", -1.0)
		_toys.append(t)
	print("modo=", _modo, " erosion=", VfxKit3D.usar_erosion, " fps=", FPS, " ms/fotograma=", 1000.0 / FPS)

func _process(_d: float) -> bool:
	if _montando:
		return _montar()
	_f += 1
	if _f == AJUSTE:
		_matar()
	# la columna j (j >= 1) se fotografia al final del fotograma (AJUSTE - 1) + 1 + j*paso (= j*paso fotogramas de animacion); la 0 es la bola entera, justo antes de morir
	var rel: int = _f - (AJUSTE - 1)
	if (rel == 0 or (rel > 1 and (rel - 1) % _paso == 0)) and _pedidas < _cols:
		_pedidas += 1
		RenderingServer.frame_post_draw.connect(_foto.bind(rel), CONNECT_ONE_SHOT)
	return false

func _matar() -> void:
	for i in _toys.size():
		var t: Node3D = _toys[i]
		var tm: float = 0.0
		match _modo:
			"golpe":
				t.call("impactar_en", t.global_position, Vector3.BACK)
				tm = float(t.get("dura_morir")) / 4.0
			"aislada":
				var ap: AnimationPlayer = t.get_node("Anim") as AnimationPlayer
				ap.speed_scale = 4.0
				t.call("morir")
				tm = float(t.get("dura_morir")) / 4.0
			_:
				t.call("terminar_sin_choque")
				tm = {"agua": AguaToy.T_APAGAR, "fuego": FuegoToy.T_APAGAR, "hielo": HieloToy.T_APAGAR, "rayo": RayoToy.T_APAGAR}[ELEMENTOS[i]]
		_dur_ms.append(tm * 1000.0)
		print("  ", ELEMENTOS[i], ": la bola muere en ", snappedf(tm * 1000.0, 0.1), " ms (", snappedf(tm * FPS, 0.1), " fotogramas a ", FPS, " fps)")

func _foto(rel: int) -> void:
	var img: Image = _vp.get_texture().get_image()
	_celdas.append(img)
	var ms: float = float(maxi(rel - 1, 0)) * 1000.0 / FPS      # la animacion arranca un fotograma despues de pedir la muerte (medido con current_animation_position)
	_ms.append(ms)
	var pos: String = ""
	for t in _toys:
		if is_instance_valid(t) and _modo != "fin":
			var ap: AnimationPlayer = t.get_node_or_null("Anim") as AnimationPlayer
			if ap != null and ap.is_playing() and ap.current_animation == "morir":
				pos += " %.1f" % (ap.current_animation_position / 4.0 * 1000.0)
			else:
				pos += " -"
	print("columna ", _celdas.size() - 1, " t=", snappedf(ms, 0.1), " ms   pos.anim(ms):", pos)
	if _celdas.size() == _cols:
		_montando = true

func _montar() -> bool:
	if _comp == null:
		var w: int = MARGEN_X + _cols * ANCHO_CEL
		var h: int = MARGEN_Y + ALTO_CEL
		_comp = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_comp.fill(Color(0.10, 0.11, 0.10))
		for j in _cols:
			var im: Image = _celdas[j]
			im.convert(Image.FORMAT_RGBA8)
			_comp.blit_rect(im, Rect2i(0, 0, ANCHO_CEL, ALTO_CEL), Vector2i(MARGEN_X + j * ANCHO_CEL, MARGEN_Y))
		_vp2 = SubViewport.new()
		_vp2.size = Vector2i(w, h)
		_vp2.transparent_bg = false
		_vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_vp2)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(_comp)
		_vp2.add_child(tr)
		var tit := Label.new()
		tit.text = "%s · erosion %s · fotograma = %.2f ms (%d fps)" % [_modo, "ENCENDIDA" if VfxKit3D.usar_erosion else "apagada", 1000.0 / FPS, FPS]
		tit.position = Vector2(8, 4)
		tit.add_theme_font_size_override("font_size", 22)
		_vp2.add_child(tit)
		for j in _cols:
			var l := Label.new()
			l.text = "%.0f ms" % _ms[j]
			l.position = Vector2(MARGEN_X + j * ANCHO_CEL + 8, 34)
			l.add_theme_font_size_override("font_size", 24)
			_vp2.add_child(l)
		for i in ELEMENTOS.size():
			var l2 := Label.new()
			l2.text = "%s\nmuere en\n%.0f ms" % [ELEMENTOS[i], float(_dur_ms[i])]
			l2.position = Vector2(8, MARGEN_Y + ALTO_CEL / 2.0 - (float(Y_FILA[i]) - 2.4) * ALTO_CEL / 6.4 - 40.0)
			l2.add_theme_font_size_override("font_size", 22)
			_vp2.add_child(l2)
		_esperas = 0
		return false
	_esperas += 1
	if _esperas == 4:
		_vp2.get_texture().get_image().save_png(_out)
		print("guardado ", _out)
		quit()
	return false

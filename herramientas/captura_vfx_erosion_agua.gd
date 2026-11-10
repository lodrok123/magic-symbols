extends SceneTree
## TIRA DE EROSION DEL AGUA A TIEMPO REAL (8/11/2026, docs/estudios/VFX_DIAGNOSTICO_2026-11-07.md §8): las figuras del agua (bola, haz, pilar, ola) se matan por el MISMO camino que en el juego
## (vfx_toy_juego.gd) y se fotografian con los milisegundos reales rotulados. Apagada y encendida dan los mismos instantes.
##   fin    BOLA: terminar_sin_choque() (500 ms; `vida` baja con la rampa de apagado)
##   haz    HAZ:  morir() -> la animacion anima `corte` 0 -> 1 en 1000 ms
##   pilar  PILAR: morir() -> `corte` en 1200 ms
##   ola    MURO (ola): morir() -> `corte` en 1900 ms
##   choque BOLA: impactar_en() (morir x4 = 125 ms), para comprobar que el choque sigue igual de corto
## godot --rendering-driver opengl3 --fixed-fps 240 --path . --script res://herramientas/captura_vfx_erosion_agua.gd -- <png_salida> <0|1 erosion> <fin|haz|pilar|ola|choque> [ms_ini ms_fin]
## Nota: agua_mallas.gd crea un RandomNumberGenerator sin semilla (cintas de la bola): las capturas de agua no son reproducibles pixel a pixel entre pasadas.
const FPS: int = 240
const AJUSTE: int = 300                  ## fotogramas de espera antes de matarlo (1,25 s: «nacer» ya acabo)
const ANCHO_CEL: int = 330
const ALTO_CEL: int = 520
const MARGEN_Y: int = 64
const COLS: int = 11

var _out: String = ""
var _fig: String = "fin"
var _ms_ini: float = 0.0
var _ms_fin: float = 500.0
var _vp: SubViewport
var _mundo: Node3D
var _toy: Node3D
var _f: int = 0
var _pedir: Array = []                   ## fotograma `_f` en que se pide cada columna
var _celdas: Array = []
var _ms: Array = []
var _montando: bool = false
var _sig: int = 0
var _comp: Image
var _vp2: SubViewport
var _esperas: int = 0
var _dur_ms: float = 0.0


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_out = a[0]
	VfxKit3D.usar_erosion = a[1] == "1"
	_fig = a[2] if a.size() > 2 else "fin"
	var rango: Dictionary = {"fin": [0.0, 500.0], "haz": [400.0, 1000.0], "pilar": [300.0, 1200.0], "ola": [1000.0, 1900.0], "choque": [0.0, 125.0], "area": [900.0, 1500.0]}
	_ms_ini = float((rango[_fig] as Array)[0])
	_ms_fin = float((rango[_fig] as Array)[1])
	if a.size() > 4:
		_ms_ini = float(a[3])
		_ms_fin = float(a[4])
	seed(20261108)
	_vp = SubViewport.new()
	_vp.size = Vector2i(ANCHO_CEL, ALTO_CEL)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.34, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	var we := WorldEnvironment.new()
	we.environment = env
	_mundo.add_child(we)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14.0, 14.0)
	suelo.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.22, 0.26, 0.22)
	suelo.material_override = sm
	suelo.position = Vector3(0.0, -0.001, 0.0)
	_mundo.add_child(suelo)
	var cam := Camera3D.new()
	_mundo.add_child(cam)
	_toy = AguaToy.new()
	_toy.set("casilla", Terreno3D.casilla)
	if _fig != "area":
		_mundo.add_child(_toy)
	match _fig:
		"haz":
			_toy.call("definir", AguaToy.Figura.HAZ, 1.5, 0.9, 0.4, false)
			_toy.position = Vector3(1.5, 0.0, 1.2)
			cam.look_at_from_position(Vector3(0.0, 1.2, 4.2), Vector3(0.0, 0.8, 0.0))
			cam.fov = 48.0
		"pilar":
			_toy.call("definir", AguaToy.Figura.PILAR, 0.5, 2.0, 0.5, false)
			cam.look_at_from_position(Vector3(2.6, 1.7, 4.4), Vector3(0.0, 1.0, 0.0))
			cam.fov = 48.0
		"ola":
			_toy.call("definir", AguaToy.Figura.MURO, 1.8, 1.2, 0.3, false)
			cam.look_at_from_position(Vector3(3.4, 1.7, 4.0), Vector3(0.0, 0.5, -0.8))
			cam.fov = 52.0
		"area":
			cam.look_at_from_position(Vector3(3.2, 2.2, 4.4), Vector3(0.0, 0.7, 0.0))
			cam.fov = 50.0
		_:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 1.7
			cam.position = Vector3(0.0, 0.0, 6.0)
			_toy.position = Vector3(0.0, 0.0, 0.0)
			_toy.rotation.y = -PI / 2.0
			_toy.call("definir", AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	if _fig != "area":
		_toy.call("lanzar", -1.0)
	if _fig == "fin" or _fig == "choque":
		_dur_ms = AguaToy.T_APAGAR * 1000.0 if _fig == "fin" else 125.0
	for j in COLS:
		var ms: float = lerpf(_ms_ini, _ms_fin, float(j) / float(COLS - 1))
		_pedir.append(AJUSTE + int(round(ms * float(FPS) / 1000.0)))       # la columna j: ms de animacion (la animacion arranca en el fotograma AJUSTE + 1)
	print("figura=", _fig, " erosion=", VfxKit3D.usar_erosion, " fps=", FPS, " rango=", _ms_ini, "-", _ms_fin, " ms")


func _process(_d: float) -> bool:
	if _montando:
		return _montar()
	_f += 1
	if _f == AJUSTE:
		_matar()
	if _sig < COLS and _f == int(_pedir[_sig]):
		_sig += 1
		RenderingServer.frame_post_draw.connect(_foto.bind(_f), CONNECT_ONE_SHOT)
	return false


func _matar() -> void:
	match _fig:
		"fin":
			_toy.call("terminar_sin_choque")
		"area":
			var imp: Node3D = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, 1.8)
			_mundo.add_child(imp)
			_dur_ms = 1700.0
		"choque":
			_toy.call("impactar_en", _toy.global_position, Vector3.BACK)
		_:
			_toy.call("morir")
			_dur_ms = float(_toy.get("dura_morir")) * 1000.0
	print("  ", _fig, " muere en ", snappedf(_dur_ms, 0.1), " ms")


func _foto(f: int) -> void:
	var img: Image = _vp.get_texture().get_image()
	_celdas.append(img)
	var ms: float = float(f - AJUSTE) * 1000.0 / float(FPS)
	_ms.append(maxf(ms, 0.0))
	print("columna ", _celdas.size() - 1, " t=", snappedf(ms, 0.1), " ms")
	if _celdas.size() == COLS:
		_montando = true


func _montar() -> bool:
	if _comp == null:
		var w: int = COLS * ANCHO_CEL
		var h: int = MARGEN_Y + ALTO_CEL
		_comp = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_comp.fill(Color(0.10, 0.11, 0.10))
		for j in COLS:
			var im: Image = _celdas[j]
			im.convert(Image.FORMAT_RGBA8)
			_comp.blit_rect(im, Rect2i(0, 0, ANCHO_CEL, ALTO_CEL), Vector2i(j * ANCHO_CEL, MARGEN_Y))
		_vp2 = SubViewport.new()
		_vp2.size = Vector2i(w, h)
		_vp2.transparent_bg = false
		_vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_vp2)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(_comp)
		_vp2.add_child(tr)
		var tit := Label.new()
		tit.text = "agua %s · muere en %.0f ms · erosion %s · fotograma = %.2f ms (%d fps)" % [_fig, _dur_ms, "ENCENDIDA" if VfxKit3D.usar_erosion else "apagada", 1000.0 / FPS, FPS]
		tit.position = Vector2(8, 4)
		tit.add_theme_font_size_override("font_size", 22)
		_vp2.add_child(tit)
		for j in COLS:
			var l := Label.new()
			l.text = "%.0f ms" % _ms[j]
			l.position = Vector2(j * ANCHO_CEL + 8, 34)
			l.add_theme_font_size_override("font_size", 24)
			_vp2.add_child(l)
		_esperas = 0
		return false
	_esperas += 1
	if _esperas == 4:
		_vp2.get_texture().get_image().save_png(_out)
		print("guardado ", _out)
		quit()
	return false

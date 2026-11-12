extends SceneTree
## Capturas de las dos animaciones nuevas de E4 y E5 en docs/capturas/mouro_compana/: el mouro SURGIENDO del pozo (brocal de la mámoa) y el RELEVO DE LA CRUZ de la Santa Compaña. NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_mouro_compana.gd
## Usa el mundo falso de prueba_mouro_compana (Mundo3D con un suelo plano, la jugadora de mentira lejos) con la luz y el suelo de las capturas de rigs, y los enemigos REALES: el tiempo del juego avanza a
## 1/60 s por paso, dos por fotograma, para que coincida con el AnimationTree a 30 fps (por eso el `--fixed-fps 30`). Cada foto lleva un rótulo con lo que pasa y el segundo en que se hace.
## Salida (cada una, el fotograma suelto 1280x720 y la tira):
##   surgir_1..6.png + surgir_tira.png     el mouro cae a 0 de vida con la mámoa abierta: pozo vacío con humo, sale el cuerpo y se levanta (Getting_Up, 2,7 s), vuelve de pie a los 4 s
##   relevo_1..6.png + relevo_tira.png     cae la guía → la cruz queda en el suelo → la siguiente llega → se agacha (CollectObject) → la cruz se le engancha → sigue la fila
##   HOJA_RESUMEN.jpg                      las dos tiras una sobre otra

const DIR: String = "res://docs/capturas/mouro_compana"
const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14
const FOV: float = 28.0
## Instantes (s desde que cae a 0 de vida el mouro) y rótulo de cada foto del surgir.
const FOTOS_SURGIR: Array = [[1.0, "1 · 1,0 s: vacío y humo"], [1.45, "2 · 1,45 s: sale, tumbado"], [2.0, "3 · 2,0 s: se apoya"],
	[2.7, "4 · 2,7 s: se incorpora"], [3.4, "5 · 3,4 s: casi de pie"], [4.3, "6 · 4,3 s: ha vuelto"]]
## Instantes (s desde que cae el guía; el primero es antes de caer) y rótulo de cada foto del relevo.
const FOTOS_RELEVO: Array = [[-0.1, "1 · la guía lleva la cruz"], [0.3, "2 · cae: la cruz se queda en el suelo, la fila para"], [0.8, "3 · la siguiente viene a por ella"],
	[1.8, "4 · se agacha: la mano llega a la cruz"], [2.7, "5 · la cruz se le engancha; se endereza"], [3.9, "6 · sigue la fila"]]

class JugadoraFalsa extends Jugador3D:
	func recibir_dano(cantidad: float, _desde: Vector3 = Vector3.ZERO) -> void:
		vida -= cantidad

	func enraizar(_s: float) -> void:
		pass

	func aplicar_estado(_e: String, _s: float) -> String:
		return ""

var _mundo: Mundo3D = null
var _jug: JugadoraFalsa = null
var _cam: Camera3D = null
var _rotulo: Label = null
var _mouro: MouroEspectro3D = null
var _proc: SantaCompana3D = null
var _t: float = 0.0
var _sensacion: bool = true


func _initialize() -> void:
	Estado.nuevo()
	_sensacion = Sensacion3D.ACTIVA
	Sensacion3D.ACTIVA = false
	await process_frame
	DirAccess.make_dir_recursive_absolute(DIR)
	_entorno()
	_montar()
	await process_frame
	var tira_s: Image = await _surgir()
	await _limpiar()
	var tira_r: Image = await _relevo()
	_hoja(tira_s, tira_r)
	Sensacion3D.ACTIVA = _sensacion
	quit(0)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * S, Terreno3D.y_pies(c), (float(c.y) + 0.5) * S)


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-45.0, 25.0, 0.0)
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(80, 80)
	suelo.mesh = pl
	suelo.position = Vector3(20, -0.01, 20)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.34, 0.3)
	suelo.material_override = mt
	root.add_child(suelo)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.05
	_cam.far = 200.0
	root.add_child(_cam)
	var capa := CanvasLayer.new()
	root.add_child(capa)
	_rotulo = Label.new()
	_rotulo.position = Vector2(24, 18)
	_rotulo.add_theme_font_size_override("font_size", 30)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 1))
	_rotulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_rotulo.add_theme_constant_override("shadow_offset_x", 2)
	_rotulo.add_theme_constant_override("shadow_offset_y", 2)
	capa.add_child(_rotulo)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jug = JugadoraFalsa.new()
	_jug.position = _pos(Vector2i(7, 12))
	_jug.pj = Pj3D.new()
	_mundo.add_child(_jug.pj)
	_jug.vida = 1000.0
	_cam.current = true


func _limpiar() -> void:
	if _mouro != null and is_instance_valid(_mouro):
		if is_instance_valid(_mouro.pj):
			_mouro.pj.queue_free()
		_mouro.queue_free()
	for m in get_nodes_in_group("mamoa3d"):
		m.queue_free()
	await process_frame
	await process_frame


## Avanza `segundos` de juego: dos pasos de 1/60 s por fotograma, y el fotograma.
func _avanzar_hasta(t: float) -> void:
	while _t < t - 0.0001:
		for _k in range(2):
			_tick()
		_t += 2.0 * DT
		await process_frame


func _tick() -> void:
	if _proc != null and is_instance_valid(_proc):
		_proc.avanzar(DT)
		for a in _proc.animas.duplicate():
			if is_instance_valid(a):
				(a as AnimaCompana3D)._physics_process(DT)
		for a in _proc.animas:
			if is_instance_valid(a):
				(a as Node).set_physics_process(false)
	if _mouro != null and is_instance_valid(_mouro):
		_mouro._physics_process(DT)


func _foto(nombre: String, rotulo: String, foco: Vector3, dir: Vector3, dist: float) -> Image:
	_rotulo.text = rotulo
	_cam.look_at_from_position(foco + dir.normalized() * dist, foco)
	_cam.current = true
	for _i in range(2):
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(DIR.path_join(nombre + ".png"))
	print("foto ", nombre)
	return img


# ---------------------------------------------------------------------------------------------------------------------
#  Surgir
# ---------------------------------------------------------------------------------------------------------------------

func _surgir() -> Image:
	_t = 0.0
	var cm := Vector2i(7, 6)
	var m: Mamoa3D = Mamoa3D.crear(_mundo, cm)
	m.set_physics_process(false)
	_mouro = MouroEspectro3D.crear(_mundo, _pos(Vector2i(4, 6)), m, _jug)
	_mouro.set_physics_process(false)
	_mouro.quieto = true
	await process_frame
	await process_frame
	_mouro.receive_damage(MouroEspectro3D.VIDA + 1.0)
	print("surgir: latente ", _mouro.latente, " · dur_surgir ", _mouro.dur_surgir())
	var foco: Vector3 = _pos(cm) + Vector3(0, 0.45, 0)
	_rotulo.position = Vector2(372, 18)                      # dentro del recorte de la tira
	var tiras: Array[Image] = []
	for f in FOTOS_SURGIR:
		await _avanzar_hasta(float(f[0]))
		var n: int = tiras.size() + 1
		var img: Image = await _foto("surgir_%d" % n, String(f[1]), foco, Vector3(0.2, 1.7, 1.0), 4.8)
		tiras.append(img)
	return _tira(tiras, Rect2i(340, 0, 600, 720), 1)


# ---------------------------------------------------------------------------------------------------------------------
#  Relevo de la cruz
# ---------------------------------------------------------------------------------------------------------------------

func _relevo() -> Image:
	_t = 0.0
	_mouro = null
	_proc = SantaCompana3D.crear(_mundo, [Vector2i(2, 4), Vector2i(12, 4)], 3, Vector2i(2, 4), _jug)
	_proc.set_physics_process(false)
	for a in _proc.animas:
		(a as Node).set_physics_process(false)
	_jug.position = _pos(Vector2i(2, 12))
	await process_frame
	var guia: AnimaCompana3D = _proc.vivas()[0]
	# La fila anda a 1,2 u/s: se deja correr hasta que la guía está a punto de pasar por el centro del encuadre y se toma ESA posición como el sitio donde cae.
	await _avanzar_hasta(0.8)
	_t = 0.0
	var x_caida: float = guia.position.x
	var foco: Vector3 = Vector3(x_caida - 1.1, guia.position.y + 0.4, guia.position.z)      # entre la guía y la siguiente (a una casilla)
	_rotulo.position = Vector2(24, 18)
	var tiras: Array[Image] = []
	# El «tiempo» de esta parte cuenta desde la baja de la guía (los instantes negativos son antes de ella): se recoloca el reloj y se corre hasta cada foto.
	var t_baja: float = 0.35
	_t = -t_baja
	var cayo: bool = false
	for f in FOTOS_RELEVO:
		var t_foto: float = float(f[0])
		while _t < t_foto - 0.0001:
			if not cayo and _t >= 0.0 - 0.0001:
				guia.receive_damage(AnimaCompana3D.VIDA)
				cayo = true
			for _k in range(2):
				_tick()
			_t += 2.0 * DT
			await process_frame
		var n: int = tiras.size() + 1
		var img: Image = await _foto("relevo_%d" % n, String(f[1]), foco, Vector3(-0.1, 0.38, 1.0), 4.6)
		tiras.append(img)
	print("relevo: recogidas ", _proc.recogidas, " · cruz_suelo ", _proc.cruz_suelo)
	return _tira(tiras, Rect2i(0, 0, 1280, 720), 3)


# ---------------------------------------------------------------------------------------------------------------------
#  Tiras y hoja
# ---------------------------------------------------------------------------------------------------------------------

## Junta las fotos recortadas a `recorte` en una tira de `columnas` columnas (una sola fila si hay tantas columnas como fotos). Las de recorte ancho se reducen a la mitad.
func _tira(fotos: Array[Image], recorte: Rect2i, columnas: int) -> Image:
	var ancho: int = recorte.size.x
	var alto: int = recorte.size.y
	var esc: float = 1.0 if ancho <= 600 else 0.5
	var w: int = int(ancho * esc)
	var h: int = int(alto * esc)
	var col: int = fotos.size() if columnas == 1 else columnas
	var filas: int = int(ceil(float(fotos.size()) / float(col)))
	var tira := Image.create_empty(w * col, h * filas, false, Image.FORMAT_RGB8)
	for i in range(fotos.size()):
		var c: Image = Image.create_empty(ancho, alto, false, Image.FORMAT_RGB8)
		c.blit_rect(fotos[i], recorte, Vector2i.ZERO)
		if esc != 1.0:
			c.resize(w, h, Image.INTERPOLATE_LANCZOS)
		tira.blit_rect(c, Rect2i(0, 0, w, h), Vector2i(w * (i % col), h * (i / col)))
	var nombre: String = "surgir_tira" if columnas == 1 else "relevo_tira"
	tira.save_png(DIR.path_join(nombre + ".png"))
	print("tira ", nombre, " ", tira.get_size())
	return tira


func _hoja(tira_s: Image, tira_r: Image) -> void:
	var ancho: int = 1920
	var a: Image = tira_s.duplicate()
	a.resize(ancho, int(float(a.get_height()) * float(ancho) / float(a.get_width())), Image.INTERPOLATE_LANCZOS)
	var b: Image = tira_r.duplicate()
	b.resize(ancho, int(float(b.get_height()) * float(ancho) / float(b.get_width())), Image.INTERPOLATE_LANCZOS)
	var hoja := Image.create_empty(ancho, a.get_height() + b.get_height(), false, Image.FORMAT_RGB8)
	hoja.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	hoja.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, a.get_height()))
	hoja.save_jpg(DIR.path_join("HOJA_RESUMEN.jpg"), 0.9)
	print("hoja ", hoja.get_size())

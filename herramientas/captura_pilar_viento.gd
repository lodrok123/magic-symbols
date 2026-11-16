extends SceneTree

## TIRA TEMPORAL DEL PILAR DE VIENTO (16/11/2026; columna ascendente). NECESITA VENTANA. Saca, con la cámara del juego (ortogonal, inclinada 60°) sobre un suelo verde oscuro
## (el viento es claro: sobre fondo claro no se vería), UNA IMAGEN por tamaño con diez fotogramas del mismo pilar: nacer ×5, vivir ×3 (separados 0,3 s, para ver que las vetas SUBEN)
## y morir ×4. Dos tamaños: la referencia 0,5 × 4 × 0,5 y uno bajo y ancho 1,2 × 1,5 × 1,2 (semiejes en m, como los de VientoToy.definir).
## Va a 30 fps FIJOS (--fixed-fps) y cuenta fotogramas, no segundos: con relojes reales los instantes bailaban de una pasada a otra y las tiras «antes» y «después» no se podían comparar.
##   godot --path . --fixed-fps 30 --script res://herramientas/captura_pilar_viento.gd -- docs/capturas/columnas_2026-11-16/viento_despues
## Escribe <carpeta>/pilar_ref.png y pilar_ancho.png (rejilla 6 × 2: nacer 1-5, vivir 1 / vivir 2-3, morir 1-4). Las carpetas de docs/capturas llevan .gdignore: no genera .import.

const FPS: int = 30
const CUADRO: Vector2i = Vector2i(380, 560)
const TAM_ORTO: float = 5.6
## [nombre, semiejes, tamaño de la vista ortogonal en m]: el ancho no cabría en los 5,6 m de la referencia (la base llega a 1,8 × su radio)
const TAMANOS: Array = [["ref", Vector3(0.5, 4.0, 0.5), 8.0], ["ancho", Vector3(1.2, 1.5, 1.2), 8.0]]

var _dir: String = "res://docs/capturas/columnas_2026-11-16/viento_despues"
var _cam: Camera3D
var _escena: Node3D


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if not _dir.is_absolute_path() and not _dir.begins_with("res://"):
		_dir = "res://" + _dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	root.get_window().size = CUADRO
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_montar_escena()
	await _frames(6)
	for t in TAMANOS:
		_cam.size = float(t[2])
		await _tira(String(t[0]), t[1] as Vector3)
	print("escrito ", _dir)
	quit(0)


func _montar_escena() -> void:
	_escena = Node3D.new()
	root.add_child(_escena)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60.0, 60.0)
	suelo.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.26, 0.12)
	suelo.material_override = mat
	_escena.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	_escena.add_child(sol)
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.10, 0.20, 0.10)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.7, 0.75, 0.7)
	var we := WorldEnvironment.new()
	we.environment = ambiente
	_escena.add_child(we)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = TAM_ORTO
	_escena.add_child(_cam)


func _tira(nombre: String, ejes: Vector3) -> void:
	var toy := VientoToy.new()
	toy.definir(int(VientoToy.Figura.PILAR), ejes.x, ejes.y, ejes.z, false)
	_escena.add_child(toy)
	toy.global_position = Vector3.ZERO
	var foco := Vector3(0.0, ejes.y * VientoToy.ESCALA_ALTO_PILAR * 0.45, 0.0)
	_cam.global_position = foco + Vector3(0.0, sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0))) * 20.0
	_cam.look_at(foco, Vector3.UP)
	var cuadros: Array = []
	toy.lanzar(-1.0)
	_base = Engine.get_process_frames()
	for f in [2, 4, 5, 7, 10]:                  # nacer (dura 0,35 s): 0,07 y 0,13 s para ver el anillo y las medias lunas; 0,17, 0,23 y 0,33 s
		await _hasta(f)
		cuadros.append(_foto())
	for f in [30, 39, 48]:                      # vivir: tres instantes separados 0,3 s
		await _hasta(f)
		cuadros.append(_foto())
	await _hasta(55)
	toy.morir()
	var t_morir: float = toy.dura_morir
	var n0: int = Engine.get_process_frames()
	for frac in [0.15, 0.4, 0.65, 0.9]:         # morir: fracciones de lo que dura
		var objetivo: int = n0 + int(round(t_morir * float(FPS) * frac))
		while Engine.get_process_frames() < objetivo:
			await process_frame
		cuadros.append(_foto())
	print("%s: morir dura %.2f s" % [nombre, t_morir])
	var rejilla := Image.create(CUADRO.x * 6, CUADRO.y * 2, false, Image.FORMAT_RGB8)
	for i in cuadros.size():
		rejilla.blit_rect(cuadros[i] as Image, Rect2i(Vector2i.ZERO, CUADRO), Vector2i((i % 6) * CUADRO.x, (i / 6) * CUADRO.y))
	rejilla.save_png(ProjectSettings.globalize_path(_dir.path_join("pilar_%s.png" % nombre)))
	if is_instance_valid(toy):
		toy.queue_free()
	await _frames(40)


var _base: int = 0

## Espera hasta el fotograma `f` contado desde el último lanzar (se fija al primer uso).
func _hasta(f: int) -> void:
	while Engine.get_process_frames() - _base < f:
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _foto() -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

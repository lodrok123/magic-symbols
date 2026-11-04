extends SceneTree
## 4/11 · Capturas del MODO MARCHA del laboratorio gato (con ventana): lobo en acecho, hiena en zigzag y tanteo, y antes/después con B.
##   godot --path . --fixed-fps 30 --resolution 1280x720 --script res://herramientas/captura_lab_gato_marcha.gd
## Salida: docs/capturas/lab_gato_marcha/*.png

const SALIDA: String = "res://docs/capturas/lab_gato_marcha/"
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _foto(nombre: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	img.save_png(ProjectSettings.globalize_path(SALIDA + nombre + ".png"))
	print("captura ", nombre, " ", img.get_size(), " | ", _lab._rotulo.text.replace("\n", " / "))


func _entrar(id: String) -> void:
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	_lab._marcha_on = false
	_lab._cambiar_modelo(id)
	await _frames(3)
	_lab._alternar_modo_marcha()
	await _frames(10)
	_lab._yaw = 0.35
	_lab._pitch = 0.22
	_lab._dist = 5.5


## Espera (hasta `max_f` fotogramas) a que se cumpla `cond`.
func _esperar(cond: Callable, max_f: int) -> bool:
	for i in range(max_f):
		await process_frame
		if cond.call():
			return true
	return false


func _correr() -> void:
	var esc: PackedScene = load("res://laboratorios/LabGato3D.tscn") as PackedScene
	_lab = esc.instantiate()
	root.add_child(_lab)
	await _frames(5)

	# 1) lobo en acecho
	await _entrar("loberno")
	_lab._presa_pos = Vector3(6.0, 0.0, 0.0)
	_lab.marcha_modo("persigue")
	var ok: bool = await _esperar(func() -> bool: return _lab._mm.estado_conducta() == "acecho", 30 * 15)
	await _frames(25)
	print("lobo en acecho: ", ok)
	await _foto("loberno_acecho")
	await _esperar(func() -> bool: return _lab._mm.estado_conducta() == "embestida", 30 * 10)
	await _frames(1)
	await _foto("loberno_embestida")

	# 2) hiena: zigzag (aproximándose, estado vacío con el desvío lateral) y tanteo
	await _entrar("canouro")
	_lab._pitch = 0.9
	_lab._dist = 6.0
	_lab._presa_pos = Vector3(8.0, 0.0, 0.0)
	_lab.marcha_modo("persigue")
	var zig: bool = await _esperar(func() -> bool: return absf(_lab._mpj.position.z) > 0.18 and _lab._mpj.position.x > 1.0, 30 * 10)
	print("hiena en zigzag: ", zig)
	await _foto("canouro_zigzag_arriba")
	_lab._pitch = 0.22
	_lab._dist = 5.5
	await _frames(2)
	await _foto("canouro_zigzag_lateral")
	# otra pasada para el tanteo (parada y retroceso de espaldas)
	await _entrar("canouro")
	_lab._presa_pos = Vector3(8.0, 0.0, 0.0)
	_lab.marcha_modo("persigue")
	var ult: Array = [_lab._mm.estado_conducta()]
	var vigilar: Callable = func() -> bool:
		var e: String = _lab._mm.estado_conducta()
		if e != ult[0]:
			ult[0] = e
			print("   hiena: estado «%s» en x=%.2f, d=%.2f" % [e, _lab._mpj.position.x, absf(_lab._presa_pos.x - _lab._mpj.position.x)])
		return e == "atras"
	var tan: bool = await _esperar(vigilar, 30 * 10)
	await _frames(8)
	print("hiena en tanteo: ", tan)
	await _foto("canouro_tanteo_atras")

	# 3) antes / después con B: el lobo patrullando, misma cámara
	await _entrar("loberno")
	_lab._presa_pos = Vector3(0.0, 0.0, 9.0)
	_lab.marcha_modo("patrulla")
	await _frames(45)
	await _foto("loberno_patrulla_marcha_SI")
	_lab.alternar_marcha_animal()
	await _frames(45)
	await _foto("loberno_patrulla_marcha_NO")
	# y persiguiendo, antes/después
	_lab.alternar_marcha_animal()
	_lab._presa_pos = Vector3(_lab._mpj.position.x + 5.0, 0.0, 0.0)
	_lab.marcha_modo("persigue")
	await _frames(30)
	await _foto("loberno_persigue_marcha_SI")
	_lab.alternar_marcha_animal()
	await _frames(20)
	await _foto("loberno_persigue_marcha_NO")
	_lab.alternar_marcha_animal()
	quit()

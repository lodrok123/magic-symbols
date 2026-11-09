extends SceneTree

## CAPTURAS del PORT de la demo de gas (laboratorios/haz_gas/, Mayús+F12 del LabVfxComparativa3D). NECESITA VENTANA (compute shaders):
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_haz.gd -- [carpeta] [casos: esfera,muro] [vistas: demo,cerca,contra,juego] [tiempos: 1,3,6] [calidad: low] [paleta: pablo|demo]
## Escribe <carpeta>/<caso>_<vista>_<t>s.png (t = segundos de simulación desde que se enciende) y <caso>_<vista>_apagado.png (1,5 s tras apagar el chorro con ESPACIO).
## Vistas (en coordenadas de la demo): demo = la cámara inicial de main.js; cerca = baja y cerca del choque (como demo_ref/demo_4 y demo_6); contra = desde detrás de la jugadora
## (como demo_ref/demo_5); juego = el dominio escalado en la mano de la jugadora con la cámara del juego (ortográfica, 30°).

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas"
var _casos: PackedStringArray = ["esfera", "muro"]
var _vistas: PackedStringArray = ["demo", "cerca", "contra", "juego"]
var _tiempos: PackedFloat32Array = [1.0, 3.0, 6.0]
var _calidad: String = "low"
var _paleta: String = "pablo"
var _lab: Node3D = null
const CAMARAS: Dictionary = {
	"demo": [Vector3(2.5, 6, 23), Vector3(1.4, 2.4, 0), 32.0],
	"cerca": [Vector3(0.5, 3.2, 13.5), Vector3(-0.5, 2.3, 0), 40.0],
	"contra": [Vector3(15.5, 3.0, -8.5), Vector3(1.0, 2.6, 0.5), 40.0],
}


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_casos = a[1].split(",")
	if a.size() > 2 and a[2] != "":
		_vistas = a[2].split(",")
	if a.size() > 3 and a[3] != "":
		_tiempos = PackedFloat32Array(Array(a[3].split(",")).map(func(s): return float(s)))
	if a.size() > 4 and a[4] != "":
		_calidad = a[4]
	if a.size() > 5 and a[5] != "":
		_paleta = a[5]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	await _esperar(10)
	for caso in _casos:
		for vista in _vistas:
			_lab.call("haz_gas", 0)
			await _esperar(3)
			var g: HazGas = _lab.call("haz_gas", 1 if caso == "esfera" else 2, "juego" if vista == "juego" else "demo")
			if g == null or not g.listo():
				print("FALLO: el gas no arranca (¿sin ventana?)")
				quit(1)
				return
			g.params["paleta"] = 1.0 if _paleta == "pablo" else 0.0
			if g.calidad != _calidad:
				g.crear_solver(_calidad)
			if CAMARAS.has(vista):
				var c: Array = CAMARAS[vista]
				g.camara_en(c[0], c[1], c[2])
			for t in _tiempos:
				await _hasta_paso(g, int(t * 60.0))
				await RenderingServer.frame_post_draw
				_guardar("%s%s_%s_%ds.png" % [caso, _sufijo(), vista, int(t)])
			g.chorro(false)
			await _hasta_paso(g, g.frame + 90)
			await RenderingServer.frame_post_draw
			_guardar("%s%s_%s_apagado.png" % [caso, _sufijo(), vista])
			print("  gpu %s %s: %s · fotograma %.1f ms" % [caso, vista, str(g.gpu_ms), g.gpu_viewport_ms])
	_lab.call("haz_gas", 0)
	print("CAPTURAS en " + _dir)
	quit()


func _sufijo() -> String:
	return "" if _paleta == "pablo" else "_paletademo"


func _hasta_paso(g: HazGas, n: int) -> void:
	var tope: int = 0
	while g.frame < n and tope < 5000:
		await process_frame
		tope += 1


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura " + nombre)

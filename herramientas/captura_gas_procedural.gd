extends SceneTree

## CAPTURAS DEL BARRIDO PROCEDURAL del haz de gas (modo toon; HazGas.derivar_haz). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_procedural.gd -- [carpeta] [vistas: lateral,juego] [segundos: 3]
## Escribe <carpeta>/<vista>_<caso>.png. Casos: largo ×{0,5 1 2} × ancho ×{0,5 1 2}; alto ×{0,7 1,5}; esfera 0,4 / 1,2, caja 0,7 / 1,4, sin obstáculo;
## hechizos reales ᚲ+ᛁ, ᚲ+ᛁᛁᛁ, ᚲ+ᛁ×6, ᚲ+ᛁ+ᛏ (FuegoToy.describir). La cámara lateral se encuadra sola con el tamaño del caso; la del juego es la del lab.

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas_procedural"
var _vistas: PackedStringArray = ["lateral", "juego"]
var _seg: float = 3.0
const CASOS: Array = [
	["L05_A05", {"largo": 1.5, "dist": 1.0, "ancho": 0.075}], ["L05_A1", {"largo": 1.5, "dist": 1.0}], ["L05_A2", {"largo": 1.5, "dist": 1.0, "ancho": 0.3}],
	["L1_A05", {"ancho": 0.075}], ["L1_A1", {}], ["L1_A2", {"ancho": 0.3}],
	["L2_A05", {"largo": 6.0, "dist": 4.0, "ancho": 0.075}], ["L2_A1", {"largo": 6.0, "dist": 4.0}], ["L2_A2", {"largo": 6.0, "dist": 4.0, "ancho": 0.3}],
	["alto07", {"alto": 0.35}], ["alto15", {"alto": 0.75}],
	["esfera04", {"tam": 0.4}], ["esfera12", {"tam": 1.2}], ["caja07", {"obstaculo": "caja", "tam": 0.7}], ["caja14", {"obstaculo": "caja", "tam": 1.4}], ["nada", {"obstaculo": "nada"}],
	["hz_I", {"linea_x": 1}], ["hz_III", {"linea_x": 3}], ["hz_I6", {"linea_x": 6}], ["hz_I_T", {"linea_x": 1, "levitacion": 1}],
]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_vistas = a[1].split(",")
	if a.size() > 2 and a[2] != "":
		_seg = float(a[2])
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await _esperar(10)
	for vista in _vistas:
		for caso in CASOS:
			var c: Dictionary = caso[1]
			var cfg: Dictionary
			if c.has("linea_x"):
				cfg = HazGas.cfg_de_hechizo(Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, c))
			else:
				cfg = HazGas.HAZ_REF.duplicate()
				cfg.merge(c, true)
			lab.call("haz_gas", 0)
			await _esperar(3)
			var g: HazGas = lab.call("haz_gas", 1, vista, true, cfg)
			if g == null or not g.listo():
				print("FALLO: el gas no arranca")
				quit(1)
				return
			g.get_node("HudGas").visible = false
			while g.frame < int(_seg * 60.0):
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = root.get_viewport().get_texture().get_image()
			img.save_png(_dir.path_join("%s_%s.png" % [vista, caso[0]]))
			print("captura %s_%s  (%s)" % [vista, caso[0], g._texto_haz()])
	lab.call("haz_gas", 0)
	quit()


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame

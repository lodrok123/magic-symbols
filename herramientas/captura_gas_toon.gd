extends SceneTree

## CAPTURAS del MODO TOON del haz de gas (prototipo A, 9/11/2026) frente al dibujo realista del port y al haz del juego (FuegoToy contra el muro del lab, tecla F).
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_toon.gd -- [carpeta] [dibujos: toon,realista,fuegotoy] [casos: esfera,muro] [vistas: juego,lateral] [tiempos: 1,3,6]
## Escribe <carpeta>/<dibujo>_<caso>_<vista>_<t>s.png y ..._apagado.png (1,5 s tras apagar el chorro; el FuegoToy: tras quitar el haz).
## El FuegoToy solo va contra el muro (es lo que tiene el lab: F). La vista lateral es la MISMA cámara de mundo para los tres.

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas_toon"
var _dibujos: PackedStringArray = ["toon", "realista", "fuegotoy"]
var _casos: PackedStringArray = ["esfera", "muro"]
var _vistas: PackedStringArray = ["juego", "lateral"]
var _tiempos: PackedFloat32Array = [1.0, 3.0, 6.0]
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_dibujos = a[1].split(",")
	if a.size() > 2 and a[2] != "":
		_casos = a[2].split(",")
	if a.size() > 3 and a[3] != "":
		_vistas = a[3].split(",")
	if a.size() > 4 and a[4] != "":
		_tiempos = PackedFloat32Array(Array(a[4].split(",")).map(func(s): return float(s)))
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	await _esperar(10)
	var pie: Vector3 = (_lab.get("_pj") as Node3D).global_position
	var lat_desde: Vector3 = pie + Vector3(6.5, 2.2, -2.4)
	var lat_mira: Vector3 = pie + Vector3(0.0, 0.9, -2.6)
	for dibujo in _dibujos:
		for caso in _casos:
			if dibujo == "fuegotoy" and caso != "muro":
				continue
			for vista in _vistas:
				_lab.call("haz_gas", 0)
				_lab.call("limpiar")
				await _esperar(4)
				if dibujo == "fuegotoy":
					await _fuegotoy(vista, lat_desde, lat_mira)
					continue
				var g: HazGas = _lab.call("haz_gas", 1 if caso == "esfera" else 2, vista, dibujo == "toon")
				if g == null or not g.listo():
					print("FALLO: el gas no arranca (¿sin ventana?)")
					quit(1)
					return
				g.mostrar_hud = false
				g.get_node("HudGas").visible = false
				if vista == "lateral":
					g.camara_mundo(lat_desde, lat_mira, 60.0)
				for t in _tiempos:
					await _hasta_paso(g, int(t * 60.0))
					await RenderingServer.frame_post_draw
					_guardar("%s_%s_%s_%ds.png" % [dibujo, caso, vista, int(t)])
				g.chorro(false)
				await _hasta_paso(g, g.frame + 90)
				await RenderingServer.frame_post_draw
				_guardar("%s_%s_%s_apagado.png" % [dibujo, caso, vista])
				print("  gpu %s %s %s: total %.2f ms (volumen %.2f)" % [dibujo, caso, vista, float(g.gpu_ms.get("total", 0.0)), float(g.gpu_ms.get("volumen", 0.0))])
	_lab.call("haz_gas", 0)
	print("CAPTURAS en " + _dir)
	quit()


## El haz del juego tal cual (FuegoToy figura haz, F7) contra el muro de prueba del lab (F).
func _fuegotoy(vista: String, desde: Vector3, mira: Vector3) -> void:
	_lab.set("_panel_visible", false)
	_lab.set("_muro_haz_activo", false)
	_lab.set("_obst_esfera", false)
	if vista == "lateral":
		_lab.set("camara_fija", {"desde": desde, "mira": mira})
		_lab.call("poner_camara", 1)
	else:
		_lab.set("camara_fija", {})
		_lab.call("poner_camara", 0)
	_lab.call("alternar_muro_haz")
	_lab.call("fuego_param", 4)
	var t0: int = Time.get_ticks_msec()
	for t in _tiempos:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		await RenderingServer.frame_post_draw
		_guardar("fuegotoy_muro_%s_%ds.png" % [vista, int(t)])
	_lab.call("_quitar_param")
	await _esperar(90)
	await RenderingServer.frame_post_draw
	_guardar("fuegotoy_muro_%s_apagado.png" % vista)
	_lab.call("alternar_muro_haz")
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)


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

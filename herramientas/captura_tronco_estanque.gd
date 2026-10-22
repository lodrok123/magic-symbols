extends "res://herramientas/escenario_base.gd"
## CAPTURAS del TRONCO DEL ESTANQUE (22/10; cauce hondo). NECESITA VENTANA y Godot CERRADO (sin GPU no hay imagen).
##   godot --path . --script res://herramientas/captura_tronco_estanque.gd -- <carpeta> <prefijo>   (por defecto res://docs/capturas/tronco_estanque, "")
## Carga el Bosque 01 de verdad y hace: seco_cerca / seco_ancha (el tronco en el fondo del foso seco, cámara fija), subiendo_1..3 (el agua llena el estanque, a medio camino) y puente_cerca / puente_ancha (arriba, abierto). Una foto IDÉNTICA a la anterior se avisa.

var _carpeta: String = "res://docs/capturas/tronco_estanque"
var _prefijo: String = ""
var _hash_prev: int = 0
var _m: Node3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_carpeta = a[0]
	if a.size() > 1:
		_prefijo = a[1]
	DirAccess.make_dir_recursive_absolute(_carpeta)
	var gi: FileAccess = FileAccess.open(_carpeta.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await cargar("res://escenas/PruebaBosque01.tscn", true)
	if maqueta == null or jugador == null:
		return
	_m = maqueta as Node3D
	_ocultar_ui(root)
	await avanzar(60)
	var tr: TroncoEstanque3D = maqueta.get_node("Reglas").get("_tronco_estanque") as TroncoEstanque3D
	if tr == null:
		print("TRONCO: no hay")
		return
	var cel: Vector2i = tr.celda
	await _encuadre(cel, 3.2, 0.0)
	await _foto("seco_cerca")
	await _encuadre(cel, 6.5, 0.0)
	await _foto("seco_ancha")
	# Abre el manantial (losa T_C) y espera a que el tronco suba y se abra el paso.
	colocar_jugador(Vector2i(16, 9))
	await avanzar(20)
	var t0: float = reloj.t
	var n: int = 0
	var umbrales: Array = [0.25, 0.55, 0.85]
	while not tr.abierto and reloj.t - t0 < 150.0:
		await process_frame
		if n < umbrales.size():
			var f: float = (tr.position.y - float(tr.get("_y_fondo"))) / (float(tr.get("_y_arriba")) - float(tr.get("_y_fondo")))
			if f >= float(umbrales[n]):
				n += 1
				await _encuadre(cel, 3.2, 0.0)
				await _foto("subiendo_%d" % n)
	print("TRONCO abierto %s tras %.1f s; y %.3f" % [str(tr.abierto), reloj.t - t0, tr.position.y])
	await avanzar(30)
	await _encuadre(cel, 3.2, 0.0)
	await _foto("puente_cerca")
	await _encuadre(cel, 6.5, 0.0)
	await _foto("puente_ancha")


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var hsh: int = hash(img.get_data())
	if hsh == _hash_prev:
		print("AVISO: %s es IDENTICA a la foto anterior (ventana sin dibujar, o nada cambió)" % nombre)
	_hash_prev = hsh
	img.save_png("%s/%s%s.png" % [_carpeta, _prefijo, nombre])
	print("FOTO %s%s | t %.1f s" % [_prefijo, nombre, reloj.t])


func _encuadre(c: Vector2i, tam: float, dz: float) -> void:
	_m.set("_jugador", null)
	_m.set("_foco", Vector3((float(c.x) + 0.5) * Terreno3D.casilla, 0.5, (float(c.y) + 0.5 + dz) * Terreno3D.casilla))
	_m.set("_tam_camara", tam)
	(_m.get("_camara") as Camera3D).size = tam
	_m.call("_colocar_camara")
	await avanzar(40)

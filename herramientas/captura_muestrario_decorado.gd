extends "res://herramientas/escenario_base.gd"

## MUESTRARIO DE LA TABLA DE DECORADO (26/11/2026). Pone sobre el suelo de un claro de un nivel generado TODAS las piezas de cada papel de
## `presentacion/tabla_decorado_bioma.gd` (con peso o vetadas), una al lado de otra y con su nombre, con la maqueta (mismos materiales, luz y cámara
## que en el juego): así se ve a ojo si alguna sale gigante, diminuta, de un color que no es del bosque o negra. Una foto por papel y estilo.
## NECESITA VENTANA y el nivel de prueba de `captura_bosque_generado.gd` (lo exporta si falta):
##   godot --path . --script res://herramientas/captura_muestrario_decorado.gd [-- estilo=pantano]
## Fotos en docs/capturas/bosque_generado_2026-11-26/muestrario/.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Test2 = preload("res://presentacion/prueba_test2.gd")
const TABLA = preload("res://presentacion/tabla_decorado_bioma.gd")
const DIR: String = "res://docs/capturas/bosque_generado_2026-11-26/muestrario"
const PAPELES: Array = ["arbol_masa", "arbol_borde", "masa_menor", "decor_claro", "adorno_borde", "roca", "tronco", "hierba_corta", "flor", "ruina"]


func _escenario() -> void:
	var estilo: String = "bosque"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("estilo="):
			estilo = a.substr(7)
	var dir: String = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var par: Dictionary = Generador.parametros_defecto()
	par.merge({"nombre": "BosqueGenPrueba", "algoritmo": "bosque", "semilla": 7, "ancho": 60, "alto": 50, "estilo": estilo, "luz": "bosque"}, true)
	var m: Dictionary = Generador.new().generar(par)
	par["decorado"] = false      # sin la capa de riqueza: el suelo del claro queda limpio para ver las piezas
	par["enemigos"] = 0.0        # y sin enemigos: que no maten a la jugadora mientras se hace la foto
	par["arqueros"] = 0
	m = Generador.new().generar(par)
	var res: Dictionary = Exportador.exportar(m, true)
	_ok("1 se exporta", bool(res["ok"]), String(res.get("error", "")))
	Flags.nuevo()
	Estado.nuevo()
	await cargar(Exportador.ruta_escena("BosqueGenPrueba"), false)
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	root.get_window().size = Vector2i(1600, 900)
	var filas: PackedStringArray = m["filas"]
	# el mayor claro: la casilla `.` con más hierba alrededor
	var centro: Vector2i = Vector2i(30, 25)
	var mejor: int = 0
	for y in range(6, filas.size() - 6):
		for x in range(6, filas[y].length() - 6):
			if filas[y][x] != ".":
				continue
			var n: int = 0
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					if ".,v".contains(filas[y + dy][x + dx]):
						n += 1
			if n > mejor:
				mejor = n
				centro = Vector2i(x, y)
	colocar_jugador(centro)
	await avanzar(40)
	var y0: float = Test2.ALTO - Test2.HUNDIR
	var base: Vector3 = maqueta._centro_celda(centro, y0)
	for papel in PAPELES:
		var filas_t: Array = _todas(estilo, papel)
		if filas_t.is_empty():
			continue
		var nodo := Node3D.new()
		nodo.name = "muestrario_" + String(papel)
		maqueta.add_child(nodo)
		var grande: bool = String(papel).begins_with("arbol") or String(papel) == "masa_menor"
		var n_fila: int = 5 if String(papel).begins_with("arbol") else 6
		var paso: float = 5.0 if String(papel).begins_with("arbol") else (2.2 if grande else 1.0)
		var i: int = 0
		for f in filas_t:
			var id: String = String(f[0])
			var propia: bool = id.begins_with("ss_")
			var plantilla: Array = [] if propia else maqueta._plantilla(maqueta._id_real(id))
			if plantilla.is_empty() and not propia:
				print("sin plantilla: ", id)
				continue
			var col: int = i % n_fila
			var fila: int = floori(float(i) / float(n_fila))
			var pos: Vector3 = base + Vector3((float(col) - float(n_fila - 1) * 0.5) * paso, 0.0, float(fila) * paso * 0.9 - paso)
			if propia:
				var ps: PackedScene = load(TABLA.ruta_de(id)) as PackedScene
				if ps != null:
					var inst: Node3D = ps.instantiate() as Node3D
					inst.position = pos
					nodo.add_child(inst)
			for parte in plantilla:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = parte[0] as Mesh
				mm.instance_count = 1
				mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, pos) * (parte[1] as Transform3D))
				var mi := MultiMeshInstance3D.new()
				mi.multimesh = mm
				if parte[2] != null:
					mi.material_override = parte[2] as Material
				nodo.add_child(mi)
			var et := Label3D.new()
			et.text = ("%s%s" % [id.replace("pn_", "").replace("ss_", "").replace("lost_", ""), " (%d)" % int(f[1])]) if int(f[1]) > 0 else (id.replace("pn_", "") + " VETADA")
			et.font_size = 18
			et.pixel_size = 0.006 * (paso / 1.5 if paso < 3.0 else 2.0)
			et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			et.no_depth_test = true
			et.modulate = Color(1, 1, 1) if int(f[1]) > 0 else Color(1, 0.5, 0.4)
			et.outline_size = 8
			et.position = pos + Vector3(0, 0.05, 0.55)
			nodo.add_child(et)
			i += 1
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		nodo.add_child(cam)
		var filas_n: int = int(ceil(float(i) / float(n_fila)))
		cam.size = (paso * float(n_fila) * 0.62 + 2.0) if grande else (paso * float(maxi(ceili(float(i) / float(n_fila)), 2)) * 1.2 + 1.5)
		var dir_cam := -Vector3(0.0, sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)))
		var objetivo: Vector3 = base + Vector3(0, 0.5, float(filas_n - 1) * paso * 0.45 - paso * 0.3)
		cam.global_transform = Transform3D(Basis.looking_at(dir_cam, Vector3.UP), objetivo - dir_cam * 40.0)
		cam.far = 200.0
		cam.current = true
		await avanzar(25)
		var ruta_foto: String = "%s/%s_%s.png" % [dir, estilo, papel]
		root.get_viewport().get_texture().get_image().save_png(ruta_foto)
		print("captura: ", ruta_foto, " (", i, " piezas)")
		cam.queue_free()
		nodo.queue_free()
		await avanzar(3)
	maqueta.queue_free()
	await avanzar(3)
	for ruta in [Exportador.ruta_mapa("BosqueGenPrueba"), Exportador.ruta_escena("BosqueGenPrueba")]:
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## Todas las filas del papel (también las vetadas) cuyo modelo existe en esta máquina.
func _todas(estilo: String, papel: String) -> Array:
	var est: String = estilo
	while est != "" and not (TABLA.TABLA.get(est, {}) as Dictionary).has(papel):
		est = String(TABLA.HEREDA.get(est, ""))
	if est == "":
		return []
	var res: Array = []
	for f in (TABLA.TABLA[est][papel] as Array):
		var ruta: String = TABLA.ruta_de(String(f[0]))
		if ruta == "" or ResourceLoader.exists(ruta) or not TABLA.es_externa(String(f[0])) and not String(f[0]).begins_with("ss_"):
			res.append(f)
	return res

extends SceneTree
## V8 «presupuesto» (docs/PLAN_EOW_VISUAL.md), parte 1: ÁRBOLES `_2` EN EL BOSQUE 01. NECESITA VENTANA (con --headless no hay imagen ni GPU).
## NO toca el nivel (Nivel_Bosque_01.tscn) ni ninguna pieza: una vez montada la maqueta, cambia la MALLA de los lotes (MultiMesh) de `arbol_redondo` y `pino`
## por las de `arbol_redondo_2` y `pino_2` (misma colocación, mismo giro y escala: solo cambia el modelo). Solo vive en esta herramienta.
##   godot --path . --script res://herramientas/captura_presupuesto_v8.gd -- <actual|todo2|mitad> <carpeta>
## «actual» = el nivel tal cual · «todo2» = todos los árboles/pinos de 12 k pasan a su `_2` · «mitad» = uno de cada dos (alternos, por orden de colocación en el lote).
## Imprime una línea MEDIDA por vista: triángulos de los lotes de árbol (cuenta exacta), triángulos que dibuja Godot en el fotograma (incluye sombras),
## llamadas de dibujo, tiempo de fotograma (CPU+GPU, vsync apagado) y tiempo de GPU medido por el propio Godot.
const IDS: Dictionary = {"arbol_redondo": "arbol_redondo_2", "pino": "pino_2"}
const S: float = 2.3


func _initialize() -> void:
	_correr()


func _tris(m: Mesh) -> int:
	var n: int = 0
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("uso: -- <actual|todo2|mitad> <carpeta>")
		quit(2)
		return
	var modo: String = a[0]
	var carpeta: String = a[1]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var esc: PackedScene = load("res://escenas/PruebaBosque01.tscn")
	var m: Node3D = esc.instantiate()
	root.add_child(m)
	for _i in 100:
		await process_frame
	_ocultar_ui(root)
	var props: Node3D = m.get("_props") as Node3D
	var plant: Dictionary = m.get("_plantillas") as Dictionary
	var tris_mesh: Dictionary = {}
	var cambiados: int = 0
	var mejor: Vector3 = _punto_denso(props, plant)   # ANTES de cambiar nada: así las tres opciones miran exactamente al mismo sitio
	var antes_n: Dictionary = {}
	var despues_n: Dictionary = {}
	if modo != "actual":
		for src in IDS:
			var dst: String = IDS[src]
			if not plant.has(src) or not plant.has(dst):
				push_error("falta la plantilla de %s o %s" % [src, dst])
				quit(3)
				return
		for mmi in props.get_children():
			if not (mmi is MultiMeshInstance3D):
				continue
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			for src in IDS:
				var dst: String = IDS[src]
				var ps: Array = plant[src]
				var pd: Array = plant[dst]
				var k: int = -1
				for j in ps.size():
					if (ps[j] as Array)[0] == mm.mesh:
						k = j
				if k < 0:
					continue
				var local_v: Transform3D = (ps[k] as Array)[1]
				var inv: Transform3D = local_v.affine_inverse()
				var quedan: Array = []
				var van: Array = []
				for i in mm.instance_count:
					var copia: Transform3D = mm.get_instance_transform(i) * inv
					antes_n[src] = int(antes_n.get(src, 0)) + 1 if k == 0 else int(antes_n.get(src, 0))
					if modo == "todo2" or (modo == "mitad" and i % 2 == 1):
						van.append(copia)
					else:
						quedan.append(copia)
				var cast_sombra: int = (mmi as MultiMeshInstance3D).cast_shadow
				# Lo que se queda con su modelo: se reescribe el MultiMesh con menos copias.
				if quedan.is_empty():
					mmi.queue_free()
				else:
					mm.instance_count = quedan.size()
					for i in quedan.size():
						mm.set_instance_transform(i, (quedan[i] as Transform3D) * local_v)
				if k == 0 and not van.is_empty():
					for parte in pd:
						var nmm := MultiMesh.new()
						nmm.transform_format = MultiMesh.TRANSFORM_3D
						nmm.mesh = (parte as Array)[0] as Mesh
						nmm.instance_count = van.size()
						for i in van.size():
							nmm.set_instance_transform(i, (van[i] as Transform3D) * ((parte as Array)[1] as Transform3D))
						var ni := MultiMeshInstance3D.new()
						ni.name = "v8_%s" % dst
						ni.multimesh = nmm
						ni.cast_shadow = cast_sombra as GeometryInstance3D.ShadowCastingSetting
						if (parte as Array)[2] != null:
							ni.material_override = (parte as Array)[2] as Material
						props.add_child(ni)
						cambiados += van.size()
				elif k > 0 and not van.is_empty():
					# partes extra de una pieza de varias mallas: las crea la parte 0; aquí solo se descuentan.
					pass
				break
		for _i in 20:
			await process_frame
	# Cuenta exacta de triángulos de los árboles que hay ahora mismo en los lotes.
	var recuento: Dictionary = {}
	var total_arb: int = 0
	var total_lotes: int = 0
	for mmi in props.get_children():
		if not (mmi is MultiMeshInstance3D) or (mmi as Node).is_queued_for_deletion():
			continue
		var mm2: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		if mm2.mesh == null:
			continue
		if not tris_mesh.has(mm2.mesh):
			tris_mesh[mm2.mesh] = _tris(mm2.mesh)
		var t: int = int(tris_mesh[mm2.mesh]) * mm2.instance_count
		total_lotes += t
		for id in plant:
			for parte in (plant[id] as Array):
				if (parte as Array)[0] == mm2.mesh and (id == "arbol_redondo" or id == "arbol_redondo_2" or id == "pino" or id == "pino_2"):
					recuento[id] = int(recuento.get(id, 0)) + mm2.instance_count
					total_arb += t
	print("RECUENTO %s | copias por id: %s | triángulos de árboles %d | de todos los lotes %d | cambiadas %d" % [modo, str(recuento), total_arb, total_lotes, cambiados])
	# Vistas (el punto denso se calculó arriba, antes de cambiar nada).
	var vistas: Dictionary = {
		"jugador": [Vector3.ZERO, 16.0, true],
		"denso": [Vector3(mejor.x, 0.5, mejor.z), 16.0, false],
		"amplia": [Vector3.ZERO, 34.0, true],
	}
	DirAccess.make_dir_recursive_absolute(carpeta)
	var rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for k in vistas.keys():
		var v: Array = vistas[k]
		if not bool(v[2]):
			m.set("_jugador", null)
			m.set("_foco", v[0])
		m.set("_tam_camara", float(v[1]))
		m.get("_camara").size = float(v[1])
		m.call("_colocar_camara")
		for _i in 40:
			await process_frame
		var t0: int = Time.get_ticks_usec()
		var gpu: float = 0.0
		var cpu: float = 0.0
		var prim: float = 0.0
		var calls: float = 0.0
		var n: int = 120
		for _i in n:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var ms: float = float(Time.get_ticks_usec() - t0) / (n * 1000.0)
		var img: Image = root.get_viewport().get_texture().get_image()
		var ruta: String = "%s/bosque_%s_%s.png" % [carpeta, k, modo]
		img.save_png(ruta)
		print("MEDIDA %s | %s | fotograma %.2f ms (%.0f fps) | GPU %.2f ms | CPU render %.2f ms | triángulos en el fotograma %.0f | llamadas %.0f | %s" % [
			modo, k, ms, 1000.0 / maxf(ms, 0.001), gpu / n, cpu / n, prim / n, calls / n, ruta])
	print("renderer: %s · GPU: %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	quit()


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)

## El punto con más árboles a menos de 9 unidades (se mira sobre el nivel tal cual, antes de sustituir nada).
func _punto_denso(props: Node3D, plant: Dictionary) -> Vector3:
	var origenes: Array = []
	for mmi in props.get_children():
		if mmi is MultiMeshInstance3D:
			var mm3: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			var es_arbol: bool = false
			for id in ["arbol_redondo", "arbol_redondo_2", "pino", "pino_2"]:
				for parte in (plant.get(id, []) as Array):
					if (parte as Array)[0] == mm3.mesh:
						es_arbol = true
			if es_arbol:
				for i in mm3.instance_count:
					origenes.append(mm3.get_instance_transform(i).origin)
	var mejor: Vector3 = Vector3.ZERO
	var mejor_n: int = -1
	for i in range(0, origenes.size(), 3):
		var o: Vector3 = origenes[i]
		var c: int = 0
		for p in origenes:
			if Vector2(o.x - (p as Vector3).x, o.z - (p as Vector3).z).length() < 9.0:
				c += 1
		if c > mejor_n:
			mejor_n = c
			mejor = o
	return mejor


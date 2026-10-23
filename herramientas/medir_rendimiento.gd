extends "res://herramientas/escenario_base.gd"
## BLOQUE 4 de la revisión EoW (23/10): CUÁNTO CUESTA UNA ESCENA. NECESITA VENTANA (en headless no hay GPU):
##   godot --path . --script res://herramientas/medir_rendimiento.gd -- [informe.txt] [escena] [escalas]
##   (por defecto res://docs/capturas/bloque4_eow/<escena>.txt, el Bosque y las escalas «1.0,0.75»)
## Mide sin vsync y sin tope de FPS, con el jugador quieto donde empieza:
##   1 · por cada escala de render (`Viewport.scaling_3d_scale`): FPS medio, tiempo de fotograma (medio y percentil 95), llamadas de dibujo,
##       triángulos dibujados por fotograma, objetos y memoria de vídeo (texturas, búferes, total).
##   2 · el CENSO de la escena: triángulos de cada malla × sus copias (MeshInstance3D y MultiMesh), agrupado por malla, los 20 que más pesan;
##       y los personajes (Pj3D) con sus triángulos cada uno. Es lo que hay EN la escena, se vea o no.
## Los números dependen de la máquina: sirven para comparar antes/después en la MISMA máquina, no como cifra absoluta.

const SEGUNDOS: float = 6.0

var _lineas: PackedStringArray = []


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	var escena: String = a[1] if a.size() > 1 else RUTA_BOSQUE
	var ruta: String = a[0] if a.size() > 0 and a[0] != "" else "res://docs/capturas/bloque4_eow/%s.txt" % escena.get_file().get_basename()
	var escalas: Array = []
	for s in (a[2] if a.size() > 2 else "1.0,0.75").split(","):
		escalas.append(float(s))
	DirAccess.make_dir_recursive_absolute(ruta.get_base_dir())
	var gi: FileAccess = FileAccess.open(ruta.get_base_dir().path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await cargar(escena)
	if maqueta == null:
		return
	await avanzar_s(2.0)
	var vp: Viewport = root.get_viewport()
	_linea("ESCENA %s · ventana %s · %s · %s" % [escena, str(vp.get_visible_rect().size), RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()])
	_linea("")
	_linea("escala | FPS medio | ms medio | ms p95 | llamadas | triángulos dibujados | objetos | VRAM texturas MB | VRAM búferes MB | VRAM total MB")
	for esc in escalas:
		vp.scaling_3d_scale = float(esc)
		await avanzar_s(1.0)
		var tiempos: Array = []
		var llamadas: float = 0.0
		var tris: float = 0.0
		var objetos: float = 0.0
		var n: int = 0
		var inicio: int = Time.get_ticks_usec()
		var previo: int = inicio
		while Time.get_ticks_usec() - inicio < int(SEGUNDOS * 1000000.0):
			await process_frame
			var ahora: int = Time.get_ticks_usec()
			tiempos.append(float(ahora - previo) / 1000.0)
			previo = ahora
			llamadas += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			tris += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			objetos += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			n += 1
		tiempos.sort()
		var medio: float = 0.0
		for t in tiempos:
			medio += t
		medio /= float(maxi(tiempos.size(), 1))
		var p95: float = float(tiempos[int(tiempos.size() * 0.95)]) if not tiempos.is_empty() else 0.0
		var mb: float = 1024.0 * 1024.0
		_linea("%.2f | %.1f | %.2f | %.2f | %d | %d | %d | %.0f | %.0f | %.0f" % [esc, 1000.0 / maxf(medio, 0.001), medio, p95, int(llamadas / n), int(tris / n),
			int(objetos / n), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / mb,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / mb, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / mb])
	vp.scaling_3d_scale = 1.0
	# 3 · DIAGNÓSTICO a escala 1: qué parte del coste es la sombra del sol y qué parte los árboles (se apagan y se vuelven a encender).
	_linea("")
	_linea("diagnóstico (escala 1) | FPS medio | ms medio | llamadas | triángulos dibujados")
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	var arboles: Array = []
	for mi in maqueta.find_children("lote_*", "MultiMeshInstance3D", true, false):
		var nom: String = String((mi as Node).name)
		if nom.begins_with("lote_arbol") or nom.begins_with("lote_pino"):
			arboles.append(mi)
	await _diagnostico("tal cual")
	if sol != null:
		sol.shadow_enabled = false
		await _diagnostico("sin sombra del sol")
		sol.shadow_enabled = true
	for mi in arboles:
		(mi as Node3D).visible = false
	await _diagnostico("sin árboles ni pinos (%d lotes)" % arboles.size())
	for mi in arboles:
		(mi as Node3D).visible = true
	var antes: Array = []
	for mi in arboles:
		antes.append((mi as GeometryInstance3D).cast_shadow)
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _diagnostico("árboles sin proyectar sombra")
	for i in range(arboles.size()):
		(arboles[i] as GeometryInstance3D).cast_shadow = antes[i]
	await avanzar_s(0.5)
	root.get_viewport().get_texture().get_image().save_png(ruta.get_basename() + ".png")
	_censo()
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lineas) + "\n")
		f.close()
	print("informe: " + ruta)


## Mide 3 s y escribe una fila del diagnóstico.
func _diagnostico(nombre: String) -> void:
	await avanzar_s(0.8)
	var n: int = 0
	var llamadas: float = 0.0
	var tris: float = 0.0
	var inicio: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - inicio < 3000000:
		await process_frame
		llamadas += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	var ms: float = float(Time.get_ticks_usec() - inicio) / 1000.0 / float(maxi(n, 1))
	_linea("%s | %.1f | %.2f | %d | %d" % [nombre, 1000.0 / maxf(ms, 0.001), ms, int(llamadas / maxi(n, 1)), int(tris / maxi(n, 1))])


## Triángulos de toda la escena por malla (× copias) y por personaje.
func _censo() -> void:
	var por_malla: Dictionary = {}       # clave -> [triángulos de una copia, copias]
	var total: int = 0
	for n in maqueta.find_children("*", "GeometryInstance3D", true, false):
		var malla: Mesh = null
		var copias: int = 1
		if n is MeshInstance3D:
			malla = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			malla = (n as MultiMeshInstance3D).multimesh.mesh
			copias = (n as MultiMeshInstance3D).multimesh.visible_instance_count
			if copias < 0:
				copias = (n as MultiMeshInstance3D).multimesh.instance_count
		if malla == null or not (n as Node3D).is_visible_in_tree():
			continue
		var t: int = _triangulos(malla)
		var clave: String = _nombre(n as Node, malla)
		var e: Array = por_malla.get(clave, [t, 0])
		e[1] = int(e[1]) + copias
		por_malla[clave] = e
		total += t * copias
	var filas: Array = []
	for k in por_malla:
		filas.append([k, int(por_malla[k][0]), int(por_malla[k][1])])
	filas.sort_custom(func(x, y): return int(x[1]) * int(x[2]) > int(y[1]) * int(y[2]))
	_linea("")
	_linea("CENSO: %d triángulos en la escena (se vean o no), %d mallas distintas" % [total, filas.size()])
	_linea("malla | triángulos | copias | total | % de la escena")
	for i in range(mini(20, filas.size())):
		var r: Array = filas[i]
		_linea("%s | %d | %d | %d | %.1f" % [r[0], r[1], r[2], int(r[1]) * int(r[2]), 100.0 * float(int(r[1]) * int(r[2])) / float(maxi(total, 1))])
	_linea("")
	_linea("PERSONAJES (Pj3D)")
	_linea("id | triángulos | huesos")
	var vistos: Dictionary = {}
	for p in maqueta.find_children("*", "Pj3D", true, false):
		var id: String = str(p.get("id"))
		if vistos.has(id):
			continue
		vistos[id] = true
		var t: int = 0
		var huesos: int = 0
		for m in (p as Node).find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).mesh != null:
				t += _triangulos((m as MeshInstance3D).mesh)
		for s in (p as Node).find_children("*", "Skeleton3D", true, false):
			huesos = maxi(huesos, (s as Skeleton3D).get_bone_count())
		_linea("%s | %d | %d" % [id, t, huesos])


func _triangulos(m: Mesh) -> int:
	var t: int = 0
	if m is ArrayMesh or m is PrimitiveMesh:
		for i in range(m.get_surface_count()):
			var arr: Array = m.surface_get_arrays(i)
			if arr.is_empty():
				continue
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
				t += (idx as PackedInt32Array).size() / 3
			elif arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


func _nombre(n: Node, m: Mesh) -> String:
	if m.resource_path != "":
		return m.resource_path.get_file()
	if m.resource_name != "":
		return m.resource_name
	var s: String = String(n.name)
	return s.substr(0, 40)


func _linea(t: String) -> void:
	_lineas.append(t)
	print(t)

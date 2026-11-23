extends SceneTree

## Medida aislada antes/después. Ejecutar con ventana y --disable-vsync.
const Lab = preload("res://laboratorios/lab_vfx_revision_3d.gd")
var resultados: Array = []

func _initialize() -> void:
	call_deferred("medir")

func medir() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	root.size = Vector2i(1280, 720)
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.0
	cam.position = Vector3(0, 6, 10.392)
	cam.look_at(Vector3.ZERO)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var ronda2: bool = OS.get_cmdline_user_args().has("--ronda2")
	var recetas: Array = [2, 3, 9] if ronda2 else [1, 2, 5, 6, 9, 10]
	for i in recetas:
		var receta: Array = Lab.RECETAS_REVISION[i]
		for revisado in [false, true]:
			var efecto: Node3D
			match receta[1]:
				"agua": efecto = preload("res://laboratorios/vfx_revision/agua_revision.gd").new() if revisado else AguaToy.new()
				"magma": efecto = preload("res://laboratorios/vfx_revision/magma_revision.gd").new() if revisado else MagmaToy.new()
				_: efecto = preload("res://laboratorios/vfx_revision/viento_revision.gd").new() if revisado else VientoToy.new()
			var tam: Vector3 = receta[3]
			efecto.definir(receta[2], tam.x, tam.y, tam.z)
			mundo.add_child(efecto)
			for frame in 40:
				await process_frame
			var gpu: float = 0
			var pared: float = 0
			var dibujos: float = 0
			for frame in 60:
				var inicio: int = Time.get_ticks_usec()
				await process_frame
				pared += float(Time.get_ticks_usec() - inicio) / 1000.0
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
				dibujos += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var dato: Dictionary = {"receta": receta[0], "mejoras": revisado, "gpu_ms": gpu / 60.0, "frame_ms": pared / 60.0, "draw_calls": dibujos / 60.0}
			resultados.append(dato)
			print(JSON.stringify(dato))
			efecto.queue_free()
			await process_frame
	var ruta: String = "res://.godot/vfx_revision_ronda2_medidas.json" if ronda2 else "res://.godot/vfx_revision_medidas.json"
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(resultados, "\t"))
	quit()

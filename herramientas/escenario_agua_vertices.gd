extends "res://herramientas/escenario_base.gd"
## Diagnóstico (15/10, Juego): ¿las «púas» azules que se ven sobre el canal salen de los DATOS de la simulación o del DIBUJO?
## Pablo ve, unos segundos después de llegar el agua al canal, triángulos azules muy altos sobre el canal. AguaRender3D (Pipeline) pone un
## vértice por trocito a la altura R = suelo + profundidad que le da `AguaSim3D.imagen()`. Si ese R es razonable (≤ ~2 u) las púas no
## vienen de la simulación; si hay trocitos con R enorme, sí, y este escenario dice cuáles. No afirma nada: imprime.
##   godot --headless --path . --script res://herramientas/escenario_agua_vertices.gd              (nivel desde las letras)
##   godot --headless --path . --script res://herramientas/escenario_agua_vertices.gd -- escena     (el Nivel_Bosque.tscn horneado, como juega Pablo)
const TINAJA := Vector2i(3, 26)
const DESDE := Vector2i(6, 26)
const UMBRAL_Y: float = 2.0                        ## por encima de esta Y (u) un vértice de agua ya sería sospechoso (el suelo llano está en ≈ 1,03)


func _escenario() -> void:
	var con_escena: bool = OS.get_cmdline_user_args().has("escena")
	await cargar(RUTA_BOSQUE, con_escena)
	print("modo: %s" % ("escena horneada (Nivel_Bosque.tscn)" if con_escena else "letras de Bosque.txt"))
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("0 hay simulación", sim != null)
	if sim == null:
		return
	_informe(sim, "antes de lanzar")
	lanzar_a_celda("agua", ["flecha"], TINAJA, DESDE)
	await avanzar_vigilando(25.0, 5.0, func(t: float) -> void: _informe(sim, "t = %.0f s" % t))
	var render: Node = maqueta.find_child("AguaFisica", true, false)
	if render != null and render is MeshInstance3D:
		var mi: MeshInstance3D = render
		print("AguaFisica: visible=%s  aabb=%s  mezcla/hz=%s" % [mi.visible, mi.get_aabb(), mi.get("hz_actualizacion")])


func _informe(sim: AguaSim3D, titulo: String) -> void:
	var dat: PackedFloat32Array = sim.imagen().get_data().to_float32_array()
	var rmax: float = -INF
	var rmin: float = INF
	var altos: Array = []                            ## trocitos con R > UMBRAL_Y: [(x, z), R, prof, suelo]
	var vmax: float = 0.0
	for k in range(sim.w * sim.h):
		var r: float = dat[k * 4]
		if is_nan(r) or is_inf(r):
			altos.append([Vector2i(k % sim.w, k / sim.w), r, 0.0, 0.0])
			continue
		rmax = maxf(rmax, r)
		rmin = minf(rmin, r)
		vmax = maxf(vmax, Vector2(dat[k * 4 + 2], dat[k * 4 + 3]).length())
		if r > UMBRAL_Y:
			altos.append([Vector2i(k % sim.w, k / sim.w), snappedf(r, 0.01), snappedf(sim.prof[k], 0.01), snappedf(sim.suelo[k], 0.01)])
	print("[%s] R de la imagen: min %.2f  max %.2f   corriente máx %.2f u/s   trocitos con R > %.1f: %d" % [titulo, rmin, rmax, vmax, UMBRAL_Y, altos.size()])
	for i in range(mini(altos.size(), 12)):
		var a: Array = altos[i]
		var t: Vector2i = a[0]
		print("     trocito %s (casilla %s)  R=%s  prof=%s  suelo=%s" % [t, Vector2i(t.x / sim.sub, t.y / sim.sub), a[1], a[2], a[3]])
	var maxp: float = 0.0
	var dentro: Array = []
	for cy in range(sim.alto):
		for cx in range(sim.ancho):
			var p: float = sim.profundidad_casilla(Vector2i(cx, cy))
			maxp = maxf(maxp, p)
			if p > 0.05:
				dentro.append(Vector2i(cx, cy))
	print("     casillas con agua (> 0,05 u): %d   prof máx %.2f   %s" % [dentro.size(), maxp, str(dentro.slice(0, 14))])

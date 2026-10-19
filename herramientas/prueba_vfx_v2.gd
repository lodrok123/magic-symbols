extends SceneTree

## PRUEBA (Pipeline, 18/10, receta V2): VfxEstado3D con un Lanzador de mentira que emite `hechizo_v2`. 6 estados × 4 volúmenes (esfera, X×3, Y×2, Z×3)
## más 6 casos «todas las firmas a la vez» (copias, crece, viaja, rebotes, solidez) en el volumen más grande de cada estado, que es el peor caso para el
## presupuesto. La señal lleva lo que manda el Lanzador3D desde la entrada 160: `persiste`, `suelo`, `t_caida`, `eventos` y, en el sólido, `celdas`.
## Comprueba, MIDIENDO el árbol y no los contadores del propio efecto:
##   1. que cada volumen cabe en el presupuesto (≤ 400 «partículas») y que un hechizo entero, con todas sus copias, no pasa de 2 luces;
##   2. que el efecto crece con el volumen (el AABB de lo dibujado en el eje largo del volumen es mayor que en la esfera);
##   3. que 10 s después del último disparo no queda NADA vivo (ni hechizos, ni luces, ni nodos colgando del mundo);
##   4. que LEE la señal en vez de aproximar (sección H3): `persiste` manda sobre la tabla, `suelo` es la altura del volumen, `t_caida` es la caída del
##      líquido, cada copia es un volumen aparte separado 2·x casillas, el volumen que viaja sigue el camino de `eventos` a 8 casillas/s, un cambio de
##      dirección del camino da un rebote y los bloques del sólido caen EXACTAMENTE en las `celdas` y se apilan `niveles` veces;
##   5. (entradas 165–169) que con barrera (`solidez`) el volumen está centrado en el jugador y sin ella adelantado z − radio base; que `vfx_hechizo` pinta
##      una ráfaga por nombre (con tope y sin dejar nada vivo); y que un proyectil (HechizoVivo con velocidad) NO emite `hechizo_v2`: su dibujo cuelga del
##      nodo, se mueve y mira hacia donde va con él, se suelta al acabar, no pasa de 2 luces ni de 8 dibujos y no deja nada vivo.
## Sin ventana vale (comprueba lógica y que todo compila); con xvfb además compila los shaders:
##   godot --headless --path . --script res://herramientas/prueba_vfx_v2.gd
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/prueba_vfx_v2.gd
class FalsoLanzador:
	extends Node
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)
	signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)

const ESTADOS: Array = [["solido", "tierra"], ["liquido", "agua"], ["plasma", "fuego"], ["energia", "rayo"], ["gas", "viento"], ["campo", "tiempo"]]
const VOLUMENES: Dictionary = {
	"esfera": {"x": 0.5, "y": 0.5, "z": 0.5, "niveles": 1},
	"X3": {"x": 3.0, "y": 0.5, "z": 0.5, "niveles": 1},
	"Y2": {"x": 0.5, "y": 2.0, "z": 0.5, "niveles": 4},
	"Z3": {"x": 0.5, "y": 0.5, "z": 3.0, "niveles": 1},
}
const FIRMAS_TODAS: Dictionary = {"viaja": 1.0, "solidez": 1.0, "copias": 3.0, "rebotes": 2.0, "crece": 1.0}
const ESPERA_FINAL: float = 10.5

var _fallos: int = 0

func _initialize() -> void:
	_correr()

func _correr() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var l := FalsoLanzador.new()
	mundo.add_child(l)
	var vfx: VfxEstado3D = VfxEstado3D.conectar(l, mundo)
	await process_frame
	var lanzados: Array = []   # [nombre, estado, volumen, [hechizos]]
	var x: float = 0.0
	for par in ESTADOS:
		for nombre in VOLUMENES.keys():
			var g: Dictionary = _senal(VOLUMENES[nombre] as Dictionary, par[1], Vector3(x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), {})
			lanzados.append(["%s/%s" % [par[0], nombre], par[0], nombre, _emitir(vfx, l, par[0], par[1], g, Vector3(x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), {}), 1])
			x += 30.0
	for par in ESTADOS:
		var g0: Dictionary = (VOLUMENES["X3"] as Dictionary).duplicate()
		g0["z"] = 3.0
		g0["y"] = 2.0
		g0["niveles"] = 4
		var g: Dictionary = _senal(g0, par[1], Vector3(x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), FIRMAS_TODAS)
		var hs: Array = _emitir(vfx, l, par[0], par[1], g, Vector3(x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), FIRMAS_TODAS)
		# copias = 3 volúmenes (uno por copia); el sólido, con sus casillas reales, es UN hechizo sobre todas
		lanzados.append(["%s/todas_las_firmas" % par[0], par[0], "todas", hs, 1 if par[0] == "solido" else 3])
		x += 30.0
	var total: int = 0
	var esperados: int = 0
	for g_ in lanzados:
		total += (g_[3] as Array).size()
		esperados += int(g_[4])
		_ok((g_[3] as Array).size() == int(g_[4]), "%s: %d volúmenes (se esperaban %d)" % [g_[0], (g_[3] as Array).size(), int(g_[4])])
	_ok(vfx.get_child_count() == total, "cada hechizo_v2 crea sus volúmenes y nada más (%d de %d)" % [vfx.get_child_count(), total])
	# --- 1. presupuesto, medido en el árbol, en el instante de más vida (a mitad del sostenido) y en el último cuadro de cada fundido
	await create_timer(0.15).timeout
	var peor_luces: int = 0
	var peor_part: int = 0
	for gr in lanzados:
		var luces_hechizo: int = 0
		for h in (gr[3] as Array):
			if not is_instance_valid(h):
				continue
			var luces: int = 0
			var part: int = 0
			var pila: Array = [h]
			while not pila.is_empty():
				var n: Node = pila.pop_back()
				if n is Light3D:
					luces += 1
				elif n is MultiMeshInstance3D:
					part += (n as MultiMeshInstance3D).multimesh.instance_count
				elif n is GPUParticles3D:
					part += (n as GPUParticles3D).amount
				pila.append_array(n.get_children())
			luces_hechizo += luces
			peor_part = maxi(peor_part, part)
			_ok(part <= VfxEstado3D.MAX_PARTICULAS, "%s: %d partículas (≤ %d)" % [gr[0], part, VfxEstado3D.MAX_PARTICULAS])
			_ok(luces == (h as VfxEstado3D.EfectoHechizo).luces and part == (h as VfxEstado3D.EfectoHechizo).particulas, "%s: los contadores del efecto dicen la verdad" % gr[0])
		peor_luces = maxi(peor_luces, luces_hechizo)
		_ok(luces_hechizo <= VfxEstado3D.MAX_LUCES, "%s: %d luces en todo el hechizo (≤ %d)" % [gr[0], luces_hechizo, VfxEstado3D.MAX_LUCES])
	print("peor caso medido: %d luces, %d partículas" % [peor_luces, peor_part])
	# --- 2. escala: lo que dibuja cada volumen crece con (X, Y, Z)
	var anchos: Dictionary = {}
	var sin_ventana: bool = DisplayServer.get_name() == "headless"
	if sin_ventana:
		print("(sin ventana: el servidor de render ficticio no guarda las transformaciones de los MultiMesh; la comprobación de escala se salta, usa xvfb)")
	for gr in lanzados:
		if sin_ventana:
			break           # medir MultiMesh sin render da 0 en plasma y gas y salían «fallos» que no lo eran (los 6 de la entrada 167 del Juego)
		var h0: Node = (gr[3] as Array)[0]
		if is_instance_valid(h0) and gr[2] != "todas":
			anchos[gr[0]] = _extension(h0 as Node3D)
	for par in ESTADOS:
		if anchos.is_empty():
			break
		var e: String = par[0]
		if e == "solido":
			continue        # sobre sus casillas reales los bloques están en coordenadas de mundo: la escala se mide en la sección H3 (casillas)
		var esf: Vector3 = anchos.get("%s/esfera" % e, Vector3.ZERO)
		_ok((anchos.get("%s/X3" % e, Vector3.ZERO) as Vector3).x > esf.x * 1.3, "%s: X×3 es más ancho que la esfera" % e)
		_ok((anchos.get("%s/Z3" % e, Vector3.ZERO) as Vector3).z > esf.z * 1.3, "%s: Z×3 es más largo que la esfera" % e)
		if e != "liquido":    # la masa líquida arranca en lo alto y su AABB depende del instante
			_ok((anchos.get("%s/Y2" % e, Vector3.ZERO) as Vector3).y > esf.y * 1.3, "%s: Y×2 es más alto que la esfera" % e)
	await _h3(vfx, l)
	await _h4(vfx, l, mundo)
	await _h5(vfx, l)
	# --- 3. nada vivo 10 s después del último disparo
	await create_timer(ESPERA_FINAL).timeout
	_ok(vfx.activos() == 0, "10 s después no queda ningún hechizo vivo (quedan %d)" % vfx.activos())
	_ok(mundo.get_child_count() == 2, "el mundo solo conserva el lanzador y el VfxEstado3D (hijos: %d)" % mundo.get_child_count())
	_ok(vfx.get_child_count() == 0, "VfxEstado3D no tiene hijos colgando (%d)" % vfx.get_child_count())
	_ok(vfx.proyectiles() == 0 and vfx.rafagas() == 0, "ni proyectiles ni ráfagas contados (%d, %d)" % [vfx.proyectiles(), vfx.rafagas()])
	_ok(l.get_child_count() == 0, "el lanzador no conserva nodos de la prueba (%d)" % l.get_child_count())
	print("%s: %d fallos" % ["FALLO" if _fallos > 0 else "OK", _fallos])
	quit(1 if _fallos > 0 else 0)

## SECCIÓN H5 (P-E1, ESPEC_HECHIZO): la señal trae `viaja`, `permanencia`, `vida_total`, `elevacion`, `separacion`, `dispersion`, `gravedad` y el VFX los usa.
func _h5(vfx: VfxEstado3D, l: FalsoLanzador) -> void:
	var cas: float = vfx.casilla
	var dir := Vector3(0.0, 0.0, 1.0)
	var vol: Dictionary = {"x": 0.5, "y": 0.5, "z": 0.5, "niveles": 1}
	var o := Vector3(1300.0, 0.0, 0.0)
	# --- §0.3 lo que VIAJA: desaparece al llegar; solo se queda `permanencia`. La `persiste` del elemento (fuego 3 s) no cuenta.
	var pv: Dictionary = {"viaja": 3.0}
	var g: Dictionary = _senal(vol, "fuego", o, dir, pv)
	g.merge({"viaja": true, "permanencia": 0.0, "vida_total": 3.0 / 8.0, "elevacion": 0.0, "gravedad": 0.0}, true)
	var h0: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "plasma", "fuego", g, o, dir, pv)[0]
	_ok(absf(h0.vida - (h0._t_pista + h0.nace + h0.muere)) < 0.001, "viaja sin permanencia: desaparece al llegar (vida %.2f s = viaje %.2f + nacer + morir; la persiste de 3 s no cuenta)" % [h0.vida, h0._t_pista])
	var o1: Vector3 = o + Vector3(0.0, 0.0, 30.0)
	g = _senal(vol, "fuego", o1, dir, pv)
	g.merge({"viaja": true, "permanencia": 2.0, "vida_total": 3.0 / 8.0 + 2.0, "elevacion": 0.0, "gravedad": 0.0}, true)
	var h1: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "plasma", "fuego", g, o1, dir, pv)[0]
	_ok(absf(h1.vida - h0.vida - 2.0) < 0.001, "viaja con permanencia 2: se queda 2 s más donde llega (+%.2f s)" % (h1.vida - h0.vida))
	# --- lo que nace quieto: persiste + permanencia (= vida_total)
	var o2: Vector3 = o + Vector3(0.0, 0.0, 60.0)
	g = _senal(vol, "fuego", o2, dir, {})
	g.merge({"viaja": false, "permanencia": 2.0, "vida_total": 5.0, "elevacion": 0.0, "gravedad": 0.0}, true)
	var h2: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "plasma", "fuego", g, o2, dir, {})[0]
	_ok(absf(h2.vida - (5.0 + h2.nace + h2.muere)) < 0.001, "quieto: vive persiste + permanencia = 5 s (vida %.2f s)" % h2.vida)
	# --- elevación: el volumen nace a `elevacion` m sobre el suelo (1 m = una casilla)
	var o3: Vector3 = o + Vector3(0.0, 0.0, 90.0)
	g = _senal(vol, "viento", o3, dir, {})
	g.merge({"viaja": false, "permanencia": 0.0, "vida_total": 1.5, "elevacion": 1.0, "gravedad": 0.0}, true)
	var h3: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "gas", "viento", g, o3, dir, {})[0]
	var o3b: Vector3 = o + Vector3(0.0, 0.0, 120.0)
	g = _senal(vol, "viento", o3b, dir, {})
	g.merge({"viaja": false, "permanencia": 0.0, "vida_total": 1.5, "elevacion": 0.0, "gravedad": 0.0}, true)
	var h3b: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "gas", "viento", g, o3b, dir, {})[0]
	_ok(absf((h3.position.y - h3b.position.y) - cas) < 0.001, "elevación 1 m: el volumen sube una casilla (%.3f u)" % (h3.position.y - h3b.position.y))
	# --- gravedad: el agua con ×0,5 cae más despacio (tiempo ∝ 1/√g)
	var o4: Vector3 = o + Vector3(0.0, 0.0, 150.0)
	g = _senal(vol, "agua", o4, dir, {})
	g.merge({"viaja": false, "permanencia": 0.0, "vida_total": 0.0, "elevacion": 0.0, "gravedad": 1.0}, true)
	var a1: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "liquido", "agua", g, o4, dir, {})[0]
	var o4b: Vector3 = o + Vector3(0.0, 0.0, 180.0)
	g = _senal(vol, "agua", o4b, dir, {})
	g.merge({"viaja": false, "permanencia": 0.0, "vida_total": 0.0, "elevacion": 0.0, "gravedad": 0.5}, true)
	var a5: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "liquido", "agua", g, o4b, dir, {})[0]
	_ok(absf(a5._t_caida / a1._t_caida - sqrt(2.0)) < 0.01, "agua con gravedad ×0,5: cae √2 veces más despacio (%.2f s frente a %.2f)" % [a5._t_caida, a1._t_caida])
	# --- copias con separacion y dispersion (señal sin `eventos`: el respaldo del VFX usa los mismos campos que HechizoVivo.eventos_de)
	var pc: Dictionary = {"copias": 3.0}
	var o5: Vector3 = o + Vector3(0.0, 0.0, 210.0)
	g = {"x": 0.5, "y": 0.5, "z": 0.5, "niveles": 1, "celdas": [], "props": pc, "persiste": 4.0, "suelo": 0.0, "t_caida": 0.0, "separacion": 1.0, "dispersion": 0.0}
	var hs: Array = _emitir(vfx, l, "campo", "tiempo", g, o5, dir, pc)
	_ok(hs.size() == 3, "tres copias, tres volúmenes (%d)" % hs.size())
	if hs.size() == 3:
		var sep_real: float = (hs[0] as Node3D).position.distance_to((hs[1] as Node3D).position)
		_ok(absf(sep_real - (2.0 * 0.5 + 1.0) * cas) < 0.01, "copias a 2·semieje + separación = 2 m de centro a centro (%.3f u, se esperaba %.3f)" % [sep_real, 2.0 * cas])
	var o6: Vector3 = o + Vector3(0.0, 0.0, 240.0)
	g = {"x": 0.5, "y": 0.5, "z": 0.5, "niveles": 1, "celdas": [], "props": pc, "persiste": 4.0, "suelo": 0.0, "t_caida": 0.0, "separacion": 1.0, "dispersion": 20.0}
	var hc: Array = _emitir(vfx, l, "campo", "tiempo", g, o6, dir, pc)
	_ok(hc.size() == 3, "tres copias en abanico, tres volúmenes (%d)" % hc.size())
	if hc.size() == 3:
		var d0: Vector3 = ((hc[0] as Node3D).global_transform.basis.z).normalized()
		var d1: Vector3 = ((hc[1] as Node3D).global_transform.basis.z).normalized()
		_ok(absf(rad_to_deg(d0.angle_to(d1)) - 20.0) < 0.5, "cada copia gira `dispersion` grados respecto a la anterior (%.1f°)" % rad_to_deg(d0.angle_to(d1)))
	# --- proyectil con permanencia: al pararse se queda dibujado donde está mientras `quedandose`, y luego se apaga
	var hv: HechizoVivo = _proyectil(l, "plasma", "fuego", 5.0, o + Vector3(0.0, 1.2, 270.0), 0.3)
	await process_frame
	await process_frame
	var dib: VfxEstado3D.EfectoHechizo = _dibujo_de(hv)
	_ok(dib != null, "el proyectil se dibuja")
	if dib != null:
		hv.activo = false
		hv.quedandose = true
		await create_timer(0.6).timeout           # más que lo que tarda en apagarse un proyectil normal (0,35 s)
		_ok(is_instance_valid(dib) and dib.get_parent() == hv, "con permanencia el dibujo sigue colgado del proyectil parado")
		hv.quedandose = false
		await create_timer(0.1).timeout
		_ok(is_instance_valid(dib) and dib.get_parent() == vfx, "al acabar la permanencia se suelta y se apaga")
	if is_instance_valid(hv):
		hv.queue_free()


## Extensión en X, Y, Z (locales del hechizo) de los MultiMesh y mallas hijas, en unidades. Es aproximada pero monótona con el volumen.
func _extension(h: Node3D) -> Vector3:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	var pila: Array = [h]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		pila.append_array(n.get_children())
		if n is MultiMeshInstance3D:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			for k in mm.instance_count:
				var tr: Transform3D = mm.get_instance_transform(k)
				if tr.basis.get_scale().length() < 0.001:
					continue
				mn = mn.min(tr.origin)
				mx = mx.max(tr.origin)
		elif n is MeshInstance3D and n != h and (n as MeshInstance3D).visible:
			var mi := n as MeshInstance3D
			var a: AABB = mi.mesh.get_aabb()
			for esq in 8:
				var p: Vector3 = mi.transform * a.get_endpoint(esq)
				mn = mn.min(p)
				mx = mx.max(p)
	if mn.x == INF:
		return Vector3.ZERO
	return mx - mn

func _ok(cond: bool, texto: String) -> void:
	if not cond:
		_fallos += 1
		print("FALLO: ", texto)


## `g` como lo manda el Lanzador3D (entrada 160): x, y, z, celdas, niveles + persiste, suelo, t_caida y eventos [{t, pos: Vector2 del mundo, dir: Vector2}].
func _senal(vol: Dictionary, elemento: String, origen: Vector3, dir: Vector3, props: Dictionary) -> Dictionary:
	var g: Dictionary = vol.duplicate()
	g["props"] = props
	var d2 := Vector2(dir.x, dir.z).normalized()
	var cas: float = 2.3
	var copias: int = clampi(int(props.get("copias", 1.0)), 1, 4)
	var viaja: float = float(props.get("viaja", 0.0))
	var sep: float = maxf(2.0 * float(g["x"]), 1.0) * cas
	var ev: Array = []
	for i in copias:
		var o: Vector2 = Vector2(origen.x, origen.z) + d2.orthogonal() * ((float(i) - float(copias - 1) * 0.5) * sep)
		ev.append({"t": 0.0, "pos": o, "dir": d2})
		var p: Vector2 = o
		var d: Vector2 = d2
		for k in range(1, int(floorf(viaja)) + 1):
			p += d * cas
			if float(props.get("rebotes", 0.0)) > 0.0 and k == 3:
				d = -d            # un muro delante: el camino rebota a la tercera casilla
			ev.append({"t": float(k) / 8.0, "pos": p, "dir": d})
	g["eventos"] = ev
	g["suelo"] = 0.0
	g["persiste"] = {"tierra": 8.0, "hielo": 6.0, "fuego": 3.0, "rayo": 0.0, "viento": 1.5, "tiempo": 4.0, "agua": 0.0}.get(elemento, 2.0)
	g["t_caida"] = (0.4 + 0.07 * float(g["y"])) if elemento == "agua" else 0.0
	var celdas: Array = []
	if elemento == "tierra":
		var c0 := Vector2i(int(floorf(origen.x / cas)), int(floorf(origen.z / cas)))
		for dx in range(-int(ceilf(float(g["x"]))), int(ceilf(float(g["x"]))) + 1):
			for dz in range(0, int(ceilf(2.0 * float(g["z"]))) + 1):
				celdas.append(Vector2i(c0.x + dx, c0.y + dz))
	g["celdas"] = celdas
	return g


## Emite la señal y devuelve los volúmenes (hijos nuevos de VfxEstado3D) que ha creado.
func _emitir(vfx: VfxEstado3D, l: FalsoLanzador, estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary) -> Array:
	var antes: Array = vfx.get_children()
	l.hechizo_v2.emit(estado, elemento, g, origen, dir, props)
	var nuevos: Array = []
	for h in vfx.get_children():
		if not antes.has(h) and h is VfxEstado3D.EfectoHechizo:
			nuevos.append(h)
	return nuevos


## SECCIÓN H3: el efecto lee la señal. Los volúmenes se leen en el instante que se fija a mano (`t` + `_aplicar_transform`) para que no dependa del reloj.
func _h3(vfx: VfxEstado3D, l: FalsoLanzador) -> void:
	var cas: float = vfx.casilla
	var dir := Vector3(0.0, 0.0, 1.0)
	var vol: Dictionary = {"x": 0.5, "y": 0.5, "z": 0.5, "niveles": 1}
	var o := Vector3(500.0, 0.0, 0.0)
	# persiste: el plasma de la señal dura 0,4 s aunque la tabla diga 3 (el hechizo vive lo que `persiste` + nacer + morir, no más)
	var g: Dictionary = _senal(vol, "fuego", o, dir, {})
	g["persiste"] = 0.4
	var hp: Array = _emitir(vfx, l, "plasma", "fuego", g, o, dir, {})
	var h_p: VfxEstado3D.EfectoHechizo = hp[0]
	_ok(absf(h_p.vida - (0.4 + h_p.nace + h_p.muere)) < 0.001, "persiste de la señal manda sobre la tabla (vida %.2f s, no %.2f)" % [h_p.vida, 3.0 + h_p.nace + h_p.muere])
	# suelo: el volumen se apoya en `suelo`, no en la altura de la mano
	g = _senal(vol, "viento", o + Vector3(0, 0, 40), dir, {})
	g["suelo"] = 5.0
	var hs: Array = _emitir(vfx, l, "gas", "viento", g, o + Vector3(0, 1.4, 40), dir, {})
	_ok(absf((hs[0] as Node3D).position.y - 5.0) < 0.001, "suelo de la señal: el volumen está a y = %.2f (se esperaba 5)" % (hs[0] as Node3D).position.y)
	# t_caida: la caída del líquido es la que manda el Lanzador
	g = _senal(vol, "agua", o + Vector3(0, 0, 80), dir, {})
	g["t_caida"] = 0.77
	var hl: Array = _emitir(vfx, l, "liquido", "agua", g, o + Vector3(0, 0, 80), dir, {})
	_ok(absf((hl[0] as VfxEstado3D.EfectoHechizo)._t_caida - 0.77) < 0.001, "t_caida de la señal manda sobre la cuenta propia (%.2f)" % (hl[0] as VfxEstado3D.EfectoHechizo)._t_caida)
	# copias: un volumen por copia, de lado, separados max(2·x, 1) casillas
	var pr: Dictionary = {"copias": 3.0}
	g = _senal({"x": 1.0, "y": 0.5, "z": 0.5, "niveles": 1}, "tiempo", o + Vector3(0, 0, 120), dir, pr)
	var hc: Array = _emitir(vfx, l, "campo", "tiempo", g, o + Vector3(0, 0, 120), dir, pr)
	_ok(hc.size() == 3, "copias = 3 → 3 volúmenes (%d)" % hc.size())
	if hc.size() == 3:
		var xs: Array = []
		for h in hc:
			xs.append((h as Node3D).position.x)
		xs.sort()
		_ok(absf((xs[1] - xs[0]) - 2.0 * 1.0 * cas) < 0.01 and absf((xs[2] - xs[1]) - 2.0 * 1.0 * cas) < 0.01, "las copias van de lado, separadas 2·x casillas (%.2f y %.2f u)" % [xs[1] - xs[0], xs[2] - xs[1]])
		var luces: int = 0
		for h in hc:
			luces += (h as VfxEstado3D.EfectoHechizo).luces
		_ok(luces <= 1, "tres copias de un campo no suman luces (%d)" % luces)
	# viaja: la cabeza sigue el camino de `eventos` (8 casillas/s): a los 0,25 s va por la casilla 2
	pr = {"viaja": 6.0}
	g = _senal(vol, "viento", o + Vector3(0, 0, 160), dir, pr)
	var hv: Array = _emitir(vfx, l, "gas", "viento", g, o + Vector3(0, 0, 160), dir, pr)
	var hh: VfxEstado3D.EfectoHechizo = hv[0]
	hh.t = 0.25
	hh._aplicar_transform()
	var adel: float = (0.5 - Sigils.RADIO_BASE_V2) * cas                       # sin barrera el centro se adelanta z − radio base (z = 0,5)
	var avance: float = hh.position.z - 160.0 - adel                           # z de la tanda de salida = 160
	_ok(absf(avance - 2.0 * cas) < 0.05, "viaja: a los 0,25 s la cabeza lleva %.2f u (2 casillas = %.2f)" % [avance, 2.0 * cas])
	hh.t = 5.0
	hh._aplicar_transform()
	_ok(absf((hh.position.z - 160.0 - adel) - 6.0 * cas) < 0.05, "viaja: al final del camino lleva 6 casillas (%.2f u)" % (hh.position.z - 160.0 - adel))
	# rebotes: el camino cambia de dirección una vez → un rebote dibujado; sin cambio de dirección, ninguno
	pr = {"viaja": 6.0, "rebotes": 1.0}
	g = _senal(vol, "viento", o + Vector3(0, 0, 200), dir, pr)
	var hr: Array = _emitir(vfx, l, "gas", "viento", g, o + Vector3(0, 0, 200), dir, pr)
	_ok((hr[0] as VfxEstado3D.EfectoHechizo)._rebotes.size() == 1, "el camino que rebota una vez dibuja 1 rebote (%d)" % (hr[0] as VfxEstado3D.EfectoHechizo)._rebotes.size())
	_ok(hh._rebotes.size() == 0, "el camino recto no dibuja rebotes (%d)" % hh._rebotes.size())
	# crece: solo en planta (X y Z), no en la altura, y al 30 % al nacer
	pr = {"crece": 1.0}
	g = _senal({"x": 1.0, "y": 1.0, "z": 1.0, "niveles": 2}, "tiempo", o + Vector3(0, 0, 240), dir, pr)
	var hk: VfxEstado3D.EfectoHechizo = (_emitir(vfx, l, "campo", "tiempo", g, o + Vector3(0, 0, 240), dir, pr))[0]
	hk.t = 0.0
	hk._aplicar_transform()
	# (la base del volumen tiene el eje «derecha» invertido, así que se mide el LARGO de cada eje, no `get_scale`, que saldría negativo)
	var b0: Basis = hk.transform.basis
	_ok(absf(b0.x.length() - 0.3) < 0.01 and absf(b0.y.length() - 1.0) < 0.01 and absf(b0.z.length() - 0.3) < 0.01, "crece: nace al 30 %% en planta y entero en altura (%.2f, %.2f, %.2f)" % [b0.x.length(), b0.y.length(), b0.z.length()])
	hk.t = 5.0
	hk._aplicar_transform()
	_ok(absf(hk.transform.basis.x.length() - 1.0) < 0.01 and absf(hk.transform.basis.z.length() - 1.0) < 0.01, "crece: acaba al 100 %% (%.2f)" % hk.transform.basis.x.length())
	# sólido sobre las casillas reales: los bloques caen en ellas y se apilan `niveles` veces
	var celdas: Array = [Vector2i(300, 3), Vector2i(301, 3)]
	g = _senal({"x": 0.5, "y": 1.0, "z": 0.5, "niveles": 2}, "tierra", Vector3(300.0 * cas + 1.0, 0.0, 3.0 * cas + 1.0), dir, {})
	g["celdas"] = celdas
	var hsol: Array = _emitir(vfx, l, "solido", "tierra", g, Vector3(300.0 * cas + 1.0, 0.0, 3.0 * cas + 1.0), dir, {})
	_ok(hsol.size() == 1, "sólido con casillas: un solo hechizo (%d)" % hsol.size())
	var bs: Array = (hsol[0] as VfxEstado3D.EfectoHechizo)._bloques
	_ok(bs.size() == 4, "2 casillas × 2 niveles = 4 bloques (%d)" % bs.size())
	var ok_pos: bool = true
	var ys: Array = []
	for b in bs:
		var p: Vector3 = b["pos"]
		var en_celda: bool = (absf(p.x - (300.5 * cas)) < 0.001 or absf(p.x - (301.5 * cas)) < 0.001) and absf(p.z - 3.5 * cas) < 0.001
		ok_pos = ok_pos and en_celda
		ys.append(p.y)
	_ok(ok_pos, "los bloques están en el centro de las casillas de la señal")
	ys.sort()
	_ok(ys.size() == 4 and absf((ys[2] - ys[0]) - vfx.alto_nivel) < 0.001, "los niveles se apilan de %.3f u en %.3f u" % [vfx.alto_nivel, (ys[2] - ys[0]) if ys.size() == 4 else -1.0])
	# y se hunden a su hora: `persiste` desde que salen, no todos a la vez
	var fin0: float = float((bs[0] as Dictionary)["fin"])
	_ok(absf(fin0 - 8.0) < 0.001, "cada bloque se hunde a los 8 s de su tanda (%.2f)" % fin0)
	# precalentar: lanza uno minúsculo de cada uno de los siete efectos (tierra, hielo, líquido, plasma, energía, gas, campo) y no deja nada vivo
	var antes: int = vfx.get_child_count()
	vfx.precalentar(Vector3(700.0, 0.0, 0.0))
	_ok(vfx.get_child_count() - antes == 7, "precalentar crea los 7 efectos (%d)" % (vfx.get_child_count() - antes))
	await create_timer(0.05).timeout


## SECCIÓN H4 (entradas 165–169 del Juego): centro con barrera, `vfx_hechizo` y proyectiles colgados de su HechizoVivo.
func _h4(vfx: VfxEstado3D, l: FalsoLanzador, mundo: Node3D) -> void:
	var cas: float = vfx.casilla
	var dir := Vector3(0.0, 0.0, 1.0)
	var o := Vector3(900.0, 0.0, 0.0)
	# --- centro: con barrera el volumen rodea al jugador y está centrado en él; sin ella se adelanta z − radio base
	var pb: Dictionary = {"solidez": 1.0}
	var gb: Dictionary = _senal({"x": 0.565, "y": 0.5, "z": 0.565, "niveles": 1}, "fuego", o, dir, pb)
	var hb: Node3D = _emitir(vfx, l, "plasma", "fuego", gb, o, dir, pb)[0]
	_ok(hb.position.distance_to(o) < 0.01, "con barrera el volumen está centrado en el jugador (a %.3f u)" % hb.position.distance_to(o))
	var o2: Vector3 = o + Vector3(0.0, 0.0, 40.0)
	var gs: Dictionary = _senal({"x": 0.5, "y": 0.5, "z": 1.0, "niveles": 1}, "fuego", o2, dir, {})
	var hs: Node3D = _emitir(vfx, l, "plasma", "fuego", gs, o2, dir, {})[0]
	_ok(absf((hs.position.z - o2.z) - (1.0 - Sigils.RADIO_BASE_V2) * cas) < 0.01, "sin barrera el centro se adelanta z − radio base (%.3f u)" % (hs.position.z - o2.z))
	# --- modo plano (elemento de prueba «agua sin VFX»): solo la cáscara, sin partículas ni luces, aunque el estado sea plasma
	VfxEstado3D.plano = true
	var o3: Vector3 = o + Vector3(0.0, 0.0, 20.0)
	var gp: Dictionary = _senal({"x": 1.0, "y": 1.0, "z": 1.0, "niveles": 1}, "fuego", o3, dir, {})
	var hp: VfxEstado3D.EfectoHechizo = _emitir(vfx, l, "plasma", "fuego", gp, o3, dir, {})[0]
	VfxEstado3D.plano = false
	_ok(hp.particulas == 0 and hp.luces == 0, "modo plano: sin partículas ni luces (%d, %d)" % [hp.particulas, hp.luces])
	var mallas: int = 0
	for c in hp.get_children():
		if c is MeshInstance3D:
			mallas += 1
	_ok(mallas == 6, "modo plano: cáscara, silueta y 4 aros de contorno, nada más (%d)" % mallas)
	# --- vfx_hechizo: nombre → tipo de ráfaga
	var tipos: Dictionary = {"humo_negro": "humo", "estela_fuego": "estela", "impacto_hielo": "copo", "impacto_fuego": "estallido", "explosion": "estallido",
		"gota_agua": "gota", "polvo_gris": "piedra", "chispas_azules": "chispa", "luz_calida": "destello", "hechizo_raro": "generico", "": "generico"}
	for nom in tipos:
		_ok(VfxEstado3D.tipo_de_vfx(nom) == tipos[nom], "tipo_de_vfx(«%s») = %s (sale %s)" % [nom, tipos[nom], VfxEstado3D.tipo_de_vfx(nom)])
	var r0: int = vfx.rafagas()
	l.vfx_hechizo.emit("impacto_fuego", o + Vector3(0.0, 1.0, 60.0), "fuego")
	l.vfx_hechizo.emit("", o, "fuego")
	_ok(vfx.rafagas() == r0 + 1, "una ráfaga por nombre y un nombre vacío no pinta nada (%d)" % (vfx.rafagas() - r0))
	for i in 40:
		l.vfx_hechizo.emit("estela_agua", o + Vector3(float(i), 1.0, 70.0), "agua")
	_ok(vfx.rafagas() <= VfxEstado3D.MAX_RAFAGAS, "las ráfagas no pasan de %d (%d)" % [VfxEstado3D.MAX_RAFAGAS, vfx.rafagas()])
	var peor: int = 0
	for c in vfx.get_children():
		if c is VfxEstado3D.Rafaga:
			for m in c.get_children():
				if m is MultiMeshInstance3D:
					peor = maxi(peor, (m as MultiMeshInstance3D).multimesh.instance_count)
	_ok(peor > 0 and peor <= 20, "una ráfaga lleva como mucho 20 partículas (%d)" % peor)
	# --- proyectiles
	var emisiones: Array = [0]
	l.hechizo_v2.connect(func(_a, _b, _c, _d, _e, _f) -> void: emisiones[0] += 1)
	var quieto: HechizoVivo = _proyectil(l, "campo", "tiempo", 0.0, o + Vector3(0.0, 1.0, 100.0))
	await process_frame
	await process_frame
	_ok(vfx.proyectiles() == 0 and _dibujo_de(quieto) == null, "un HechizoVivo sin velocidad no se dibuja aquí (usa hechizo_v2)")
	quieto.queue_free()
	var hv: HechizoVivo = _proyectil(l, "plasma", "fuego", 10.0, o + Vector3(0.0, 1.2, 120.0), 0.12)      # 0,12 casillas: por debajo de la esfera base (0,25), para ver que no se le sube al mínimo
	await process_frame
	await process_frame
	var dib: VfxEstado3D.EfectoHechizo = _dibujo_de(hv)
	_ok(vfx.proyectiles() == 1 and dib != null, "un proyectil se dibuja y cuelga de su HechizoVivo (%d)" % vfx.proyectiles())
	_ok(emisiones[0] == 0, "un proyectil no emite hechizo_v2 (%d)" % emisiones[0])
	if dib != null:
		hv.global_position = o + Vector3(30.0, 1.2, 125.0)         # el proyectil avanza…
		hv.v = Vector3(0.0, 0.0, -10.0)                              # …y gira hacia −Z
		await create_timer(0.4).timeout      # el giro es por tiempo (25·dt): con el reloj, no con un nº de cuadros, para que valga igual con y sin ventana
		var centro: Vector3 = dib.global_position + Vector3(0.0, dib.semi.y, 0.0)
		_ok(centro.distance_to(hv.global_position) < 0.01, "el centro del volumen está en el proyectil (a %.3f u)" % centro.distance_to(hv.global_position))
		_ok(dib.global_transform.basis.z.dot(Vector3(0.0, 0.0, -1.0)) > 0.95, "el volumen mira hacia donde va (%.2f)" % dib.global_transform.basis.z.dot(Vector3(0.0, 0.0, -1.0)))
		_ok(absf(dib.semi.x - 0.12 * cas) < 0.001, "un proyectil se dibuja a su tamaño y no al mínimo de 0,25 casillas (radio %.3f u, el suyo %.3f)" % [dib.semi.x, 0.12 * cas])
		# al acabar se suelta del nodo, se queda donde acabó y se apaga
		var fin: Vector3 = dib.global_position
		hv.activo = false
		await process_frame
		await process_frame
		_ok(is_instance_valid(dib) and dib.get_parent() == vfx, "al acabar el dibujo se suelta de su nodo")
		hv.queue_free()
		await process_frame
		_ok(is_instance_valid(dib) and dib.global_position.distance_to(fin) < 0.01, "y se queda donde acabó el proyectil")
		await create_timer(0.6).timeout
		_ok(not is_instance_valid(dib) and vfx.proyectiles() == 0, "se apaga solo (quedan %d)" % vfx.proyectiles())
	else:
		hv.queue_free()
	# un proyectil que desaparece de golpe se lleva su dibujo
	var hv2: HechizoVivo = _proyectil(l, "gas", "viento", 10.0, o + Vector3(0.0, 1.2, 140.0))
	await process_frame
	await process_frame
	_ok(vfx.proyectiles() == 1, "otro proyectil, otro dibujo (%d)" % vfx.proyectiles())
	hv2.queue_free()                    # sin pasar por `activo = false`: el dibujo lo nota, se suelta y se apaga igual (0,35 s)
	await create_timer(0.6).timeout
	_ok(vfx.proyectiles() == 0, "el nodo se libera de golpe: su dibujo se apaga y no queda contado (%d)" % vfx.proyectiles())
	# los seis estados dibujan su proyectil dentro del presupuesto
	var seis: Array = []
	for par in ESTADOS:
		seis.append(_proyectil(l, par[0], par[1], 10.0, o + Vector3(float(seis.size()) * 4.0, 1.2, 160.0)))
	await process_frame
	await process_frame
	await process_frame
	_ok(vfx.proyectiles() == 6, "seis estados, seis dibujos (%d)" % vfx.proyectiles())
	for i in seis.size():
		var d: VfxEstado3D.EfectoHechizo = _dibujo_de(seis[i])
		if d == null:
			_ok(false, "%s: el proyectil no tiene dibujo" % ESTADOS[i][0])
			continue
		var part: int = 0
		var pila: Array = [d]
		while not pila.is_empty():
			var n: Node = pila.pop_back()
			if n is MultiMeshInstance3D:
				part += (n as MultiMeshInstance3D).multimesh.instance_count
			pila.append_array(n.get_children())
		_ok(part <= VfxEstado3D.MAX_PARTICULAS, "%s: proyectil con %d partículas (≤ %d)" % [ESTADOS[i][0], part, VfxEstado3D.MAX_PARTICULAS])
		_ok(d._cuerpo != null or ESTADOS[i][0] not in ["solido", "liquido"], "%s: el sólido y el líquido de proyectil son una bola" % ESTADOS[i][0])
	for hh in seis:
		hh.activo = false
		hh.queue_free()
	await create_timer(0.7).timeout
	# muchos proyectiles a la vez: tope de dibujos y de luces
	var muchos: Array = []
	for i in 12:
		muchos.append(_proyectil(l, "plasma" if i % 2 == 0 else "energia", "fuego" if i % 2 == 0 else "rayo", 10.0, o + Vector3(float(i) * 3.0, 1.2, 200.0)))
	await process_frame
	await process_frame
	await process_frame
	_ok(vfx.proyectiles() == VfxEstado3D.MAX_PROYECTILES, "12 proyectiles, %d dibujos (tope %d)" % [vfx.proyectiles(), VfxEstado3D.MAX_PROYECTILES])
	var luces: int = 0
	for hm in muchos:
		var dm: VfxEstado3D.EfectoHechizo = _dibujo_de(hm)
		if dm != null:
			var pila2: Array = [dm]
			while not pila2.is_empty():
				var n2: Node = pila2.pop_back()
				if n2 is Light3D:
					luces += 1
				pila2.append_array(n2.get_children())
	_ok(luces <= VfxEstado3D.MAX_LUCES, "ocho proyectiles suman %d luces (≤ %d)" % [luces, VfxEstado3D.MAX_LUCES])
	for hm in muchos:
		hm.activo = false
		hm.queue_free()
	await create_timer(1.3).timeout
	_ok(vfx.rafagas() == 0, "las ráfagas se apagan solas (%d)" % vfx.rafagas())
	_ok(vfx.proyectiles() == 0, "y los proyectiles también (%d)" % vfx.proyectiles())


## Un HechizoVivo de mentira: un proyectil a mano (sin el motor físico ni el lanzador de verdad) que hace como si ya hubiera nacido.
func _proyectil(l: FalsoLanzador, estado: String, elemento: String, velocidad: float, pos: Vector3, semieje: float = 0.3) -> HechizoVivo:
	var hv := HechizoVivo.new()
	hv.h = Hechizo.new()
	hv.h.velocidad = velocidad
	hv.h.semieje_x = semieje
	hv.h.semieje_y = semieje
	hv.h.semieje_z = semieje
	hv.estado = estado
	hv.elemento = elemento
	hv.activo = velocidad > 0.0
	hv.proyectil = velocidad > 0.0
	hv.v = Vector3(velocidad, 0.0, 0.0)
	l.add_child(hv)
	hv.set_physics_process(false)      # DESPUÉS de add_child: al entrar en el árbol (NOTIFICATION_READY) el motor reactiva la física de todo script que define _physics_process; antes no sirve y en una máquina lenta el proyectil avanza solo, toca el suelo y se acaba
	hv.global_position = pos
	return hv


func _dibujo_de(hv: Node) -> VfxEstado3D.EfectoHechizo:
	for c in hv.get_children():
		if c is VfxEstado3D.EfectoHechizo:
			return c
	return null

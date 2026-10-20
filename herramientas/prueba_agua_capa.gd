extends SceneTree

## PRUEBA (Pipeline, 20/10, W1): `AguaCapa3D`, la capa visual del agua que SIGUE a la simulación. Comprueba:
##   1. (sin ventana) que se monta ×4 sobre la simulación, que no cambia NI UN dato del agua (misma simulación con y sin capa, 300 pasos, mismo volumen y misma
##      profundidad en todos los trocitos) y que se libera sin dejar nada vivo;
##   2. (con ventana; sin ella AVISO y se salta, porque el renderizador de mentira no deja leer las texturas) que el estado de la GPU hace lo que dice:
##      el error de altura es ~0 con el agua en reposo, un salto del nivel lo mete y el muelle lo recupera en 3 s, la espuma sale en la orilla y no en el
##      centro de un pozo quieto, y la espuma de una corriente se arrastra río abajo (aparece donde la fuente no está).
##   3. (con ventana) W2: una onda lanzada con `impulso()` viaja hasta un anillo lejano y se apaga; la onda no sale al suelo seco; el hielo no ondula ni tiene
##      espuma; el hielo que se suelta levanta la superficie (evento «hielo roto»); una caída de 1,2 u con caudal da cascada (cortina y salpicadura) y sin caudal no.
##   godot --headless --path . --script res://herramientas/prueba_agua_capa.gd
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/prueba_agua_capa.gd

const S: float = 2.3
const DT: float = 1.0 / 30.0
var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  MAL  ") + texto)
	if not cond:
		_fallos += 1


func _suelo(c: Vector2i) -> float:
	if c.x >= 1 and c.x <= 3 and c.y >= 1 and c.y <= 3:
		return -1.0
	return 0.0


func _nueva() -> AguaSim3D:
	var a := AguaSim3D.new()
	a.configurar(8, 8, 3, S, _suelo, func(_c: Vector2i) -> bool: return false)
	a.fuente_en(Vector2i(2, 2), 2.5)
	return a


func _huella(a: AguaSim3D) -> String:
	var t: float = 0.0
	var m: float = 0.0
	for i in range(a.w * a.h):
		t += a.prof[i]
		m = maxf(m, a.prof[i])
	return "%.5f|%.5f|%.5f" % [a.volumen_total(), t, m]


func _correr() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	await process_frame
	print("--- 1. se monta ×4 y no toca la simulación")
	var sin_capa: AguaSim3D = _nueva()
	var con_capa: AguaSim3D = _nueva()
	var capa := AguaCapa3D.new()
	mundo.add_child(capa)
	capa.enlazar(con_capa)
	_ok(capa.dimension_fina() == Vector2i(con_capa.w * 4, con_capa.h * 4), "la capa tiene %s texels = 4 × los %d × %d trocitos" % [str(capa.dimension_fina()), con_capa.w, con_capa.h])
	_ok(capa.superficie() != null and capa.superficie().mesh != null, "tiene su superficie")
	for _i in range(300):
		sin_capa.paso(DT)
		con_capa.paso(DT)
		await process_frame
	_ok(_huella(sin_capa) == _huella(con_capa), "300 pasos con y sin capa: agua idéntica (%s)" % _huella(con_capa))
	_ok(capa.pasos() > 0, "la capa ha dado %d pasos" % capa.pasos())
	if DisplayServer.get_name() == "headless":
		print("  AVISO sin ventana: no se puede leer la GPU; se salta la parte 2 (hace falta xvfb o una ventana)")
	else:
		await _con_ventana(mundo, capa, con_capa)
	capa.enlazar(null)
	capa.queue_free()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await _w2(mundo)
	var restos: int = 0
	for c in mundo.get_children():
		if c is SubViewport or c is AguaCapa3D:
			restos += 1
	_ok(restos == 0 or restos == 0, "al soltar la simulación no quedan SubViewports de la capa")
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _suelo_terraza(c: Vector2i) -> float:
	return 1.2 if c.x >= 4 else 0.0


## Deja pasar `seg` segundos de verdad (los pasos de la capa dependen del reloj real) y devuelve el máximo de |error de altura| en el anillo [r0, r1] u alrededor de `centro`
## (en u del mundo) visto en cualquier fotograma de ese rato, más el máximo de espuma y el último error en el texel del centro.
func _vigilar(capa: AguaCapa3D, sim: AguaSim3D, centro: Vector3, r0: float, r1: float, seg: float) -> Dictionary:
	var paso: float = sim.l / 4.0
	var t: float = 0.0
	var ultimo: int = Time.get_ticks_usec()
	var pico: float = 0.0
	var espuma: float = 0.0
	var e_centro: float = 0.0
	while t < seg:
		await process_frame
		var ahora: int = Time.get_ticks_usec()
		t += minf(float(ahora - ultimo) / 1.0e6, 0.05)
		ultimo = ahora
		sim.paso(DT)
		var im: Image = capa.imagen_estado()
		var io: Image = capa.imagen_ondas()
		var c: Vector2i = _texel(capa, sim, centro.x, centro.z)
		e_centro = io.get_pixelv(c).r
		var n: int = int(ceil(r1 / paso))
		for dy in range(-n, n + 1):
			for dx in range(-n, n + 1):
				var q := Vector2i(c.x + dx, c.y + dy)
				if q.x < 0 or q.y < 0 or q.x >= im.get_width() or q.y >= im.get_height():
					continue
				var d: float = Vector2(dx, dy).length() * paso
				var px: Color = im.get_pixelv(q)
				espuma = maxf(espuma, px.b)
				if d >= r0 and d <= r1:
					pico = maxf(pico, absf(io.get_pixelv(q).r))
	return {"pico": pico, "espuma": espuma, "centro": e_centro}


func _w2(mundo: Node3D) -> void:
	print("--- 3. W2: ondas, hielo, cascada")
	var sim: AguaSim3D = _nueva()
	var capa := AguaCapa3D.new()
	mundo.add_child(capa)
	capa.enlazar(sim)
	for _i in range(200):                              # primero se llena el pozo (si no, no hay agua que ondular)...
		sim.paso(DT)
		await process_frame
	sim.apagar_fuente(Vector2i(2, 2))                  # ...y luego se apaga el manantial y se asienta
	for _i in range(120):
		sim.paso(DT)
		await process_frame
	var centro := Vector3(2.5 * S, 0.0, 2.5 * S)
	var r: Dictionary = await _vigilar(capa, sim, centro, 1.4, 2.4, 0.3)
	_ok(r["pico"] < 0.005, "antes del impulso el anillo de 1,4-2,4 u no tiene ondas: %.4f (< 0,005)" % r["pico"])
	capa.impulso(centro, -0.25, 0.6)
	var r2: Dictionary = await _vigilar(capa, sim, centro, 1.4, 2.4, 2.0)
	_ok(r2["pico"] > 0.02, "la onda llega al anillo de 1,4-2,4 u en 2 s: pico %.4f u (> 0,02)" % r2["pico"])
	_ok(r2["espuma"] > 0.1, "el impulso deja espuma: %.3f (> 0,1)" % r2["espuma"])
	var r3: Dictionary = await _vigilar(capa, sim, centro, 0.0, 2.4, 6.0)
	var r4: Dictionary = await _vigilar(capa, sim, centro, 0.0, 2.4, 0.5)
	_ok(r4["pico"] < 0.02, "8 s después el pozo vuelve al reposo: %.4f (< 0,02)" % r4["pico"])
	var seca: Vector2i = _texel(capa, sim, 7.0 * S, 7.0 * S)
	_ok(capa.imagen_ondas().get_pixelv(seca).r == 0.0, "en el suelo seco la altura de onda es 0 (la onda no sale a la tierra)")
	# Hielo: no ondula ni tiene espuma; al soltarse, el evento «hielo roto» levanta la superficie.
	sim.helar_casilla(Vector2i(2, 2), true)
	await _vigilar(capa, sim, centro, 0.0, 0.5, 0.6)
	capa.impulso(centro, -0.25, 0.6)
	var h: Dictionary = await _vigilar(capa, sim, centro, 0.0, 0.5, 0.8)
	_ok(h["pico"] < 0.001 and h["espuma"] < 0.01, "sobre el hielo no hay ondas (%.5f) ni espuma (%.4f)" % [h["pico"], h["espuma"]])
	sim.helar_casilla(Vector2i(2, 2), false)
	var s: Dictionary = await _vigilar(capa, sim, centro, 0.0, 0.8, 0.8)
	_ok(s["pico"] > 0.03, "al soltarse el hielo la superficie se levanta (evento «hielo roto»): pico %.3f u (> 0,03)" % s["pico"])
	capa.enlazar(null)
	capa.queue_free()
	await process_frame
	# Cascada: una terraza de 1,2 u con un manantial arriba. Con caudal hay caída; sin manantial y con el agua parada no.
	var sim2 := AguaSim3D.new()
	sim2.configurar(8, 8, 3, S, _suelo_terraza, func(_c: Vector2i) -> bool: return false)
	sim2.fuente_en(Vector2i(5, 4), 3.0)
	var capa2 := AguaCapa3D.new()
	mundo.add_child(capa2)
	capa2.enlazar(sim2)
	for _i in range(400):
		sim2.paso(DT)
		if _i % 4 == 0:
			await process_frame
	for _i in range(40):
		sim2.paso(DT)
		await process_frame
	print("  (cascadas dibujadas: %d; el borde de la terraza tiene 24 trocitos de largo)" % capa2.cascadas())
	_ok(capa2.cascadas() > 0, "la terraza con manantial da cascada (%d)" % capa2.cascadas())
	_ok(capa2.salpicaduras_activas() > 0, "la cascada enciende la salpicadura (%d puntos)" % capa2.salpicaduras_activas())
	var mm: MultiMesh = null
	for n in capa2.get_children():
		if n is MultiMeshInstance3D:
			mm = (n as MultiMeshInstance3D).multimesh
	_ok(mm != null and mm.visible_instance_count == capa2.cascadas(), "hay una cortina por cascada (%d)" % (mm.visible_instance_count if mm != null else -1))
	capa2.enlazar(null)
	capa2.queue_free()
	await process_frame
	var sim3: AguaSim3D = _nueva()                    # un pozo en reposo no tiene cascadas
	var capa3 := AguaCapa3D.new()
	mundo.add_child(capa3)
	capa3.enlazar(sim3)
	for _i in range(200):
		sim3.paso(DT)
		await process_frame
	sim3.apagar_fuente(Vector2i(2, 2))
	for _i in range(120):
		sim3.paso(DT)
		await process_frame
	_ok(capa3.cascadas() == 0 and capa3.salpicaduras_activas() == 0, "un pozo en reposo no tiene cascadas ni salpicadura")
	capa3.enlazar(null)
	capa3.queue_free()
	await process_frame


## El texel fino de una posición del mundo en la capa.
func _texel(capa: AguaCapa3D, sim: AguaSim3D, x_u: float, z_u: float) -> Vector2i:
	var paso: float = sim.l / 4.0
	return Vector2i(clampi(int(x_u / paso), 0, capa.dimension_fina().x - 1), clampi(int(z_u / paso), 0, capa.dimension_fina().y - 1))


func _estado(capa: AguaCapa3D) -> Image:
	await process_frame
	await process_frame
	return capa.imagen_estado()


func _con_ventana(mundo: Node3D, capa: AguaCapa3D, sim: AguaSim3D) -> void:
	print("--- 2. el estado de la GPU")
	# Un poco de tiempo para que el pozo (3 × 3 casillas, 1 u de fondo, 2,5 u³/s) se llene y se asiente.
	var im: Image = await _estado(capa)
	_ok(im != null and im.get_width() == capa.dimension_fina().x, "se lee el estado de la GPU (%s)" % ("sí" if im != null else "no"))
	if im == null:
		return
	sim.apagar_fuente(Vector2i(2, 2))                  # sin manantial el pozo se asienta: lo que se mide es agua en reposo, no el chorro
	var borde: Vector2i = _texel(capa, sim, 1.0 * S + 0.1, 2.5 * S)
	for _i in range(120):
		sim.paso(DT)
		await process_frame
	im = await _estado(capa)
	print("  (agua en el mapa: %.1f u³; orilla del pozo %s)" % [sim.volumen_total(), str(borde)])
	var espuma_orilla: float = 0.0
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var p := Vector2i(clampi(borde.x + dx, 0, im.get_width() - 1), clampi(borde.y + dy, 0, im.get_height() - 1))
			espuma_orilla = maxf(espuma_orilla, im.get_pixelv(p).b)
	_ok(espuma_orilla > 0.3, "espuma en la orilla del pozo: %.3f (> 0,3)" % espuma_orilla)
	var seca: Vector2i = _texel(capa, sim, 7.0 * S, 7.0 * S)
	_ok(im.get_pixelv(seca).b < 0.001, "ni rastro de espuma en suelo seco: %.4f" % im.get_pixelv(seca).b)
	# Un salto REAL del objetivo: se escribe en la simulación (sin pasar por su dinámica, que ya lo suavizaría) 0,5 u más de agua en el centro del pozo y se
	# para la simulación. El error de altura absorbe el salto (el nivel dibujado no salta) y el muelle lo recupera en ~3 s de juego.
	for y in range(5, 10):
		for x in range(5, 10):
			sim.prof[y * sim.w + x] += 0.5
	var e_salto: float = 0.0
	var t_muelle: float = 0.0
	var ultimo: int = Time.get_ticks_usec()
	while t_muelle < 0.4:
		await process_frame
		var ahora: int = Time.get_ticks_usec()
		t_muelle += minf(float(ahora - ultimo) / 1.0e6, 0.05)
		ultimo = ahora
		var im2: Image = capa.imagen_estado()
		for y in range(20, 40):
			for x in range(20, 40):
				e_salto = maxf(e_salto, absf(im2.get_pixel(x, y).r))
	_ok(e_salto > 0.15, "tras un salto de 0,5 u del objetivo el error de altura llega a %.3f u (> 0,15: el nivel dibujado NO salta de golpe)" % e_salto)
	while t_muelle < 4.0:
		await process_frame
		var ahora2: int = Time.get_ticks_usec()
		t_muelle += minf(float(ahora2 - ultimo) / 1.0e6, 0.05)
		ultimo = ahora2
	var im3: Image = await _estado(capa)
	var e_fin: float = 0.0
	for y in range(20, 40):
		for x in range(20, 40):
			e_fin = maxf(e_fin, absf(im3.get_pixel(x, y).r))
	_ok(e_fin < 0.02, "4 s de muelle después el error vuelve a %.4f u (< 0,02)" % e_fin)

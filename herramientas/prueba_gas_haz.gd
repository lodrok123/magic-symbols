extends SceneTree

## PRUEBA del PORT de la demo de gas de three.js (laboratorios/haz_gas/, Mayús+F12 del LabVfxComparativa3D; demo lejrimostfa/force-field-vfx-threejs, MIT).
## Los compute shaders NECESITAN VENTANA (en --headless no hay RenderingDevice):
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_gas_haz.gd            (todo)
##   godot --headless --path . --script res://herramientas/prueba_gas_haz.gd                      (solo lo de CPU; lo de GPU se salta con AVISO)
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_gas_haz.gd -- ms      (solo los ms de GPU por calidad)
## CPU (siempre): el flujo horneado existe y está centrado; el contacto y el SDF del obstáculo son los de la demo con la esfera y tienen sentido con la caja;
##   las calidades tienen rejillas divisibles por 8 (cuarto y octavo enteros).
## GPU (con ventana), contra la ESFERA y contra el MURO, tras 5 s de simulación en calidad low:
##   · sin NaN ni infinitos en gas y velocidad, T <= 4 (el tope de gasSources)
##   · no hay gas dentro del obstáculo (celdas con sd < -0,25)
##   · hay hollín junto al obstáculo (encima, lados, detrás) y poco en el NÚCLEO del chorro (antes de su tramo con combustible)
##   · el polvo que levanta el aire rápido se queda a ras de suelo
##   · la proyección: Jacobi resuelve su ecuación (residuo de Poisson < 10 %) y la divergencia tras proyectar baja (celda a celda < 0,85, en bloques de 4³ < 0,65:
##     el esquema colocado de la demo no llega a 0, ver el comentario en _pruebas_gpu)
##   · las chispas (las 1000, 2 s mirando cada fotograma) no atraviesan el suelo ni el obstáculo
##   · con el chorro apagado, el fuego se apaga (T total cae)
## MODO TOON (prototipo A, dibujo con el lenguaje de FuegoToy en el entorno normal del lab, cámara del juego), contra la esfera y el muro tras 5 s:
##   · el fuego no tiene amarillo: en los píxeles de fuego (volumen opaco, saturado y claro) el tono H del HSV está en el rojo-naranja de la rampa de la bola
##     (H < 40°) y casi ninguno cae en el amarillo (45-70°); saturación media alta
##   · el borde no es borroso: ancho medio de la transición del volumen (alfa entre 0,1 y 0,9) acotado en píxeles de pantalla (se informa también el realista)
##   · hay humo pardo (píxeles de humo oscuros con tono pardo)
## y mide ms de GPU (marcas de tiempo del RenderingDevice) por calidad: low, med, high. Imprime FALLOS: n al final.

var _fallos: int = 0
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre + ("  (" + detalle + ")" if detalle != "" else ""))
	else:
		_fallos += 1
		print("  FALLO " + nombre + "  " + detalle)


func _correr() -> void:
	await process_frame
	print("== CPU")
	_pruebas_cpu()
	if RenderingServer.get_rendering_device() == null:
		print("AVISO: sin RenderingDevice (--headless): se saltan las pruebas de GPU del gas. Lánzala con ventana:")
		print("AVISO:   godot --path . --resolution 1280x720 --script res://herramientas/prueba_gas_haz.gd")
		print("FALLOS: %d" % _fallos)
		quit(1 if _fallos > 0 else 0)
		return
	root.get_window().size = Vector2i(1280, 720)
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	await _esperar(5)
	var solo_ms: bool = "ms" in OS.get_cmdline_user_args()          # -- ms : solo la medida de tiempos
	if "barrido" in OS.get_cmdline_user_args():                      # -- barrido : solo el barrido procedural
		await _barrido()
		_lab.call("haz_gas", 0)
		await _esperar(3)
		print("FALLOS: %d" % _fallos)
		quit(1 if _fallos > 0 else 0)
		return
	for caso in ([] if solo_ms else ["esfera", "muro"]):
		print("== GPU: %s" % caso)
		await _pruebas_gpu(caso)
	for caso in ([] if solo_ms else ["esfera", "muro"]):
		print("== TOON: %s" % caso)
		await _pruebas_toon(caso)
	if not solo_ms:
		await _barrido()
	print("== ms de GPU por calidad (contra la esfera, media de 240 fotogramas tras 60 de calentamiento)")
	await _medir_calidades()
	_lab.call("haz_gas", 0)
	await _esperar(3)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _pruebas_cpu() -> void:
	var fl: PackedByteArray = FileAccess.get_file_as_bytes(HazGasSolver.FLUJO_BIN)
	var media: float = 0.0
	for i in range(0, fl.size(), 4):
		media += fl[i]
	media /= maxf(fl.size() / 4.0, 1.0)
	_ok("flujo_48.bin horneado (48³ RGBA8) y centrado en 127,5", fl.size() == 48 * 48 * 48 * 4 and absf(media - 127.5) < 3.0, "media %.2f" % media)
	var g: HazGas = HazGas.new()
	g.obstaculo = "esfera"
	var c: Vector3 = g.contacto()
	var C: Vector3 = g.params["shieldC"]
	var demo: Vector3 = C + ((g.params["nozzle"] as Vector3) - C).normalized() * (float(g.params["shieldR"]) + 0.35)
	_ok("esfera: el contacto es el de sources.js (shieldC + normalize(nozzle - shieldC) * (R + 0,35))", c.distance_to(demo) < 1e-4, str(c))
	var r: Array = g.sd_obstaculo(C + Vector3(3, 0, 0))
	_ok("esfera: sd = |w - C| - R", absf(float(r[0]) - 0.9) < 1e-4 and (r[1] as Vector3).is_equal_approx(Vector3(1, 0, 0)))
	g.obstaculo = "muro"
	c = g.contacto()
	r = g.sd_obstaculo(c)
	_ok("muro: el contacto está a 0,35 m de la cara que mira a la boquilla", absf(float(r[0]) - 0.35) < 1e-3 and (r[1] as Vector3).x > 0.99, "%s sd %.3f" % [str(c), float(r[0])])
	_ok("muro: dentro de la caja sd < 0", float(g.sd_obstaculo(HazGas.MURO_C)[0]) < -0.4)
	g.free()
	for q in HazGasSolver.CALIDADES:
		var res: Vector3i = HazGasSolver.CALIDADES[q]["res"]
		_ok("calidad %s: rejilla %s divisible por 8" % [q, str(res)], res.x % 8 == 0 and res.y % 8 == 0 and res.z % 8 == 0)


func _pruebas_gpu(caso: String) -> void:
	_lab.call("haz_gas", 0)
	await _esperar(3)
	var g: HazGas = _lab.call("haz_gas", 1 if caso == "esfera" else 2, "demo", false)
	_ok("%s: el gas arranca (shaders compilados, RenderingDevice)" % caso, g != null and g.listo())
	if g == null or not g.listo():
		return
	# chispas: se miran cada fotograma durante los 2 primeros segundos tras 1 s
	await _hasta(g, 60)
	var peor_suelo: float = 1000.0
	var peor_obst: float = 1000.0
	var vivas_max: int = 0
	for k in 120:
		await process_frame
		var est: PackedFloat32Array = g.solver.leer(g.solver.chispas).to_float32_array()
		var vivas: int = 0
		for i in HazGasSolver.N_CHISPAS:
			var p: Vector3 = Vector3(est[i * 4], est[i * 4 + 1], est[i * 4 + 2])
			if p.y < -5.0:
				continue                  # aparcada bajo el suelo
			vivas += 1
			peor_suelo = minf(peor_suelo, p.y)
			peor_obst = minf(peor_obst, float(g.sd_obstaculo(p)[0]))
		vivas_max = maxi(vivas_max, vivas)
	_ok("%s: hay chispas vivas" % caso, vivas_max > 300, "%d" % vivas_max)
	_ok("%s: ninguna chispa bajo el suelo (y >= 0,04)" % caso, peor_suelo >= 0.04 - 1e-3, "y mínima %.4f" % peor_suelo)
	_ok("%s: ninguna chispa dentro del obstáculo" % caso, peor_obst >= -2e-3, "sd mínimo %.4f" % peor_obst)
	await _hasta(g, 300)
	g.pausa = true
	await _esperar(2)
	var s: HazGasSolver = g.solver
	var res: Vector3i = s.res
	var gas: PackedByteArray = s.leer(s.gas[0])
	var half: Vector3i = res / 2
	var vel: PackedByteArray = s.leer(s.vel[0])
	var nan: int = 0
	var t_max: float = 0.0
	var dentro: int = 0
	var t_total: float = 0.0
	var hollin_detras: float = 0.0
	var n_detras: int = 0
	var hollin_chorro: float = 0.0
	var hollin_chorro_max: float = 0.0
	var n_chorro: int = 0
	var polvo_bajo: float = 0.0
	var n_bajo: int = 0
	var polvo_alto: float = 0.0
	var n_alto: int = 0
	var noz: Vector3 = g.params["nozzle"]
	var tg: Vector3 = g.params["target"]
	var ab: Vector3 = tg - noz
	var cara_x: float = -0.1                 # la cara que mira al chorro (esfera: -2,2 + 2,1; muro: -0,6 + 0,5)
	for z in res.z:
		for y in res.y:
			for x in res.x:
				var o: int = ((z * res.y + y) * res.x + x) * 8
				var T: float = gas.decode_half(o)
				var so: float = gas.decode_half(o + 2)
				var du: float = gas.decode_half(o + 4)
				var fu: float = gas.decode_half(o + 6)
				if is_nan(T) or is_nan(so) or is_nan(du) or is_nan(fu) or is_inf(T) or is_inf(so):
					nan += 1
					continue
				t_max = maxf(t_max, T)
				t_total += T
				var w: Vector3 = (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) / Vector3(res) * HazGasSolver.WORLD_SIZE + HazGasSolver.WORLD_MIN
				var sd: float = float(g.sd_obstaculo(w)[0])
				if sd < -0.25 and (T + so + du + fu) > 1e-3:
					dentro += 1
				if w.y < 0.5:
					polvo_bajo += du
					n_bajo += 1
				elif w.y > 2.0:
					polvo_alto += du
					n_alto += 1
				if w.x < cara_x + 0.5 and sd > 0.1 and sd < 3.0:          # junto al obstáculo, de su cara hacia atrás (encima, a los lados y detrás)
					hollin_detras += so
					n_detras += 1
				var t: float = clampf((w - noz).dot(ab) / ab.dot(ab), 0.0, 1.0)
				if t > 0.08 and t < 0.45 and w.distance_to(noz + ab * t) < 0.2:   # el NÚCLEO del chorro antes de su tramo con combustible
					hollin_chorro += so
					hollin_chorro_max = maxf(hollin_chorro_max, so)
					n_chorro += 1
	var nan_v: int = 0
	for i in range(0, vel.size(), 2):
		var v: float = vel.decode_half(i)
		if is_nan(v) or is_inf(v):
			nan_v += 1
	_ok("%s: sin NaN ni infinitos en el gas (%d celdas) ni en la velocidad" % [caso, s.celdas], nan == 0 and nan_v == 0, "gas %d · vel %d" % [nan, nan_v])
	_ok("%s: T <= 4 (tope de gasSources)" % caso, t_max <= 4.0 + 1e-3 and t_max > 0.5, "T máx %.2f" % t_max)
	_ok("%s: no hay gas dentro del obstáculo" % caso, dentro == 0, "%d celdas" % dentro)
	var md: float = hollin_detras / maxf(n_detras, 1)
	var mc: float = hollin_chorro / maxf(n_chorro, 1)
	_ok("%s: hollín junto al obstáculo (encima, lados, detrás) y no en el núcleo del chorro" % caso, md > 0.01 and mc < md * 0.33,
		"medio junto al obstáculo %.4f (%d celdas) · medio en el núcleo del chorro %.4f, máx %.3f (%d celdas)" % [md, n_detras, mc, hollin_chorro_max, n_chorro])
	var pb: float = polvo_bajo / maxf(n_bajo, 1)
	var pa: float = polvo_alto / maxf(n_alto, 1)
	_ok("%s: el aire rápido levanta polvo y se queda a ras de suelo (y < 0,5 m frente a y > 2 m)" % caso, pb > 1e-4 and pb > pa * 5.0, "medio abajo %.5f · arriba %.5f" % [pb, pa])
	# proyección: divergencia antes (prs0.y, la lleva Jacobi) y después (residuo.glsl sobre vel0)
	var d: Vector2 = _divergencias(g)
	var umbral: float = 0.85
	_ok("%s: la proyección quita divergencia (|div| después < %.2f · antes, Jacobi %d de la calidad low)" % [caso, umbral, int(s.calidad["jacobi"])], d.y < d.x * umbral and d.x > 0.0,
		"antes %.3f · después %.3f 1/s · cociente %.3f" % [d.x, d.y, d.y / maxf(d.x, 1e-9)])
	# Celda a celda queda ~70 %: es el esquema de la demo (rejilla colocada: divergencia y gradiente centrados a 2h, Jacobi con el laplaciano compacto), que
	# no ve el modo en damero; con 200 iteraciones de Jacobi el cociente es el mismo (el arranque en caliente ya lo deja convergido). Casi toda la divergencia
	# está en el chorro (34 m/s forzados en 1-4 celdas de velocidad cada paso), donde la presión es afilada a escala de celda y los dos laplacianos difieren:
	# en bloques de 4³ celdas (0,75 m) sigue quedando ~50 %. Se pide < 0,65 y se informa.
	var d4: Vector2 = _divergencias(g, 4)
	var umbral4: float = 0.65
	_ok("%s: en bloques de 4³ celdas la divergencia que queda es < %.2f de la de antes" % [caso, umbral4], d4.y < d4.x * umbral4 and d4.x > 0.0,
		"antes %.3f · después %.3f 1/s · cociente %.3f" % [d4.x, d4.y, d4.y / maxf(d4.x, 1e-9)])
	# Lo que sí ha de cumplirse del todo: Jacobi resuelve SU ecuación (laplaciano compacto de p = divergencia, con las reglas de caras de jacobi.glsl).
	var rp: Vector2 = _residuo_poisson(g)
	_ok("%s: Jacobi converge: residuo de Poisson < 0,1 · |divergencia|" % caso, rp.y < rp.x * 0.1 and rp.x > 0.0,
		"|div| %.3f · |lap(p) - div| %.4f · cociente %.4f" % [rp.x, rp.y, rp.y / maxf(rp.x, 1e-9)])
	# apagar el chorro: el fuego se apaga
	g.pausa = false
	g.chorro(false)
	var f0: int = g.frame
	await _hasta(g, f0 + 150)
	g.pausa = true
	await _esperar(2)
	var gas2: PackedByteArray = s.leer(s.gas[0])
	var t2: float = 0.0
	for i in range(0, gas2.size(), 8):
		t2 += gas2.decode_half(i)
	_ok("%s: con el chorro apagado el fuego se apaga en 2,5 s" % caso, t2 < t_total * 0.1, "T total %.0f → %.0f" % [t_total, t2])
	g.pausa = false


## Residuo de la ecuación que resuelve Jacobi sobre prs0 (x = p, y = divergencia, z = sólido), con las reglas de jacobi.glsl: [media |div|, media |lap p - div|].
func _residuo_poisson(g: HazGas) -> Vector2:
	var s: HazGasSolver = g.solver
	var r: Vector3i = s.res / 2
	var h: float = HazGasSolver.WORLD_SIZE.x / float(r.x)
	var prs: PackedFloat32Array = s.leer(s.prs[0]).to_float32_array()
	var a: float = 0.0
	var b: float = 0.0
	var n: int = 0
	var idx: Callable = func(x: int, y: int, z: int) -> int: return ((clampi(z, 0, r.z - 1) * r.y + clampi(y, 0, r.y - 1)) * r.x + clampi(x, 0, r.x - 1)) * 4
	for z in range(1, r.z - 1):
		for y in range(1, r.y - 1):
			for x in range(1, r.x - 1):
				var i: int = idx.call(x, y, z)
				if prs[i + 2] > 0.5:
					continue
				var p: float = prs[i]
				var suma: float = 0.0
				for o in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					var j: int = idx.call(x + o.x, y + o.y, z + o.z)
					suma += p if prs[j + 2] > 0.5 else prs[j]
				a += absf(prs[i + 1])
				b += absf((suma - 6.0 * p) / (h * h) - prs[i + 1])
				n += 1
	return Vector2(a, b) / maxf(n, 1)


## Media de |divergencia| antes de proyectar (prs0.y, que Jacobi arrastra) y después (residuo.glsl sobre vel0 menos la expansión), en las celdas de fluido
## del interior (lejos de las caras abiertas y a más de 0,6 m del sólido, donde la regla de deslizamiento libre no es la misma en las dos lecturas).
## bloque > 1: la misma media pero de la divergencia PROMEDIADA en bloques de bloque³ celdas (la parte de baja frecuencia: la que comprime el gas a la vista;
## el damero que deja el esquema colocado de la demo se cancela dentro del bloque).
func _divergencias(g: HazGas, bloque: int = 1) -> Vector2:
	if bloque > 1:
		return _divergencias_bloque(g, bloque)
	return _divergencias_celda(g)


func _divergencias_bloque(g: HazGas, b: int) -> Vector2:
	var s: HazGasSolver = g.solver
	var half: Vector3i = s.res / 2
	RenderingServer.call_on_render_thread(s.calcular_residuo)
	var rsd: PackedFloat32Array = s.leer(s.residuo).to_float32_array()
	var prs: PackedFloat32Array = s.leer(s.prs[0]).to_float32_array()
	var antes: float = 0.0
	var despues: float = 0.0
	var n: int = 0
	for bz in range(1, half.z / b - 1):
		for by in range(0, half.y / b - 1):
			for bx in range(1, half.x / b - 1):
				var sa: float = 0.0
				var sd_: float = 0.0
				var limpio: bool = true
				for z in range(bz * b, bz * b + b):
					for y in range(by * b, by * b + b):
						for x in range(bx * b, bx * b + b):
							var w: Vector3 = (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) / Vector3(half) * HazGasSolver.WORLD_SIZE + HazGasSolver.WORLD_MIN
							if float(g.sd_obstaculo(w)[0]) < 0.6:
								limpio = false
							var i: int = (z * half.y + y) * half.x + x
							sa += prs[i * 4 + 1]
							sd_ += rsd[i * 4]
				if not limpio:
					continue
				antes += absf(sa) / float(b * b * b)
				despues += absf(sd_) / float(b * b * b)
				n += 1
	return Vector2(antes, despues) / maxf(n, 1)


func _divergencias_celda(g: HazGas) -> Vector2:
	var s: HazGasSolver = g.solver
	var half: Vector3i = s.res / 2
	RenderingServer.call_on_render_thread(s.calcular_residuo)
	var rsd: PackedFloat32Array = s.leer(s.residuo).to_float32_array()
	var prs: PackedFloat32Array = s.leer(s.prs[0]).to_float32_array()
	var antes: float = 0.0
	var despues: float = 0.0
	var n: int = 0
	for z in range(3, half.z - 3):
		for y in range(1, half.y - 3):
			for x in range(3, half.x - 3):
				var i: int = (z * half.y + y) * half.x + x
				var w: Vector3 = (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) / Vector3(half) * HazGasSolver.WORLD_SIZE + HazGasSolver.WORLD_MIN
				if float(g.sd_obstaculo(w)[0]) < 0.6:
					continue
				antes += absf(prs[i * 4 + 1])
				despues += absf(rsd[i * 4])
				n += 1
	return Vector2(antes, despues) / maxf(n, 1)


func _pruebas_toon(caso: String) -> void:
	_lab.call("haz_gas", 0)
	await _esperar(3)
	var g: HazGas = _lab.call("haz_gas", 1 if caso == "esfera" else 2, "juego", true)
	_ok("%s toon: arranca en toon con la cámara del juego" % caso, g != null and g.listo() and g.toon and g.vista == "juego")
	if g == null or not g.listo():
		return
	g.get_node("HudGas").visible = false
	await _hasta(g, 300)
	await RenderingServer.frame_post_draw
	var a: Dictionary = _analiza_volumen(g)
	_ok("%s toon: hay fuego en pantalla" % caso, int(a["fuego"]) > 2000, "%d píxeles de fuego" % int(a["fuego"]))
	_ok("%s toon: fuego SIN amarillo (H 45-70° en < 1 %% de los píxeles de fuego) y tono rojo-naranja" % caso, float(a["amarillo"]) < 0.01 and float(a["h_medio"]) < 40.0,
		"amarillo %.2f %% · H medio %.1f° · H p95 %.1f° · S media %.2f" % [float(a["amarillo"]) * 100.0, float(a["h_medio"]), float(a["h_p95"]), float(a["s_media"])])
	_ok("%s toon: saturación alta en el fuego (media > 0,7)" % caso, float(a["s_media"]) > 0.7, "%.2f" % float(a["s_media"]))
	_ok("%s toon: borde no borroso (transición media < 6 px de pantalla)" % caso, float(a["borde_px"]) < 6.0 and float(a["borde_px"]) > 0.0, "%.2f px" % float(a["borde_px"]))
	_ok("%s toon: hay humo pardo" % caso, int(a["humo"]) > 200, "%d píxeles · H medio %.1f°" % [int(a["humo"]), float(a["h_humo"])])
	print("  INFO %s toon: volumen %.2f ms · total %.2f ms de GPU" % [caso, float(g.gpu_ms.get("volumen", 0.0)), float(g.gpu_ms.get("total", 0.0))])
	# el realista, mismo instante y cámara, para comparar el ancho del borde
	g.poner_toon(false)
	await _esperar(6)
	await RenderingServer.frame_post_draw
	var b: Dictionary = _analiza_volumen(g)
	print("  INFO %s realista: transición media del borde %.2f px (toon %.2f px)" % [caso, float(b["borde_px"]), float(a["borde_px"])])
	_ok("%s: el toon tiene el borde más nítido que el realista" % caso, float(a["borde_px"]) < float(b["borde_px"]))
	g.poner_toon(true)


## Mira el volumen (la textura de media resolución que compone el efecto: rgb premultiplicado, a = fondo que queda) y la pantalla:
## píxeles de fuego (alfa > 0,9, claro y saturado en pantalla), su tono; humo (alfa > 0,5 y color del volumen oscuro); ancho del borde (píxeles con alfa entre 0,1 y 0,7
## por cada cruce de 0,4 en horizontal y vertical, en píxeles de pantalla).
func _analiza_volumen(g: HazGas) -> Dictionary:
	var img: Image = root.get_viewport().get_texture().get_image()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var tv: Vector2i = g.efecto._tam_vol
	var datos: PackedByteArray = rd.texture_get_data(g.efecto._crudo, 0)
	var esc: Vector2 = Vector2(img.get_width(), img.get_height()) / Vector2(tv)
	var fuego: int = 0
	var amarillo: int = 0
	var hs: Array = []
	var s_suma: float = 0.0
	var humo: int = 0
	var h_humo: float = 0.0
	var parcial: int = 0
	var cruces: int = 0
	var alfa: PackedFloat32Array = PackedFloat32Array()
	alfa.resize(tv.x * tv.y)
	for y in tv.y:
		for x in tv.x:
			var o: int = (y * tv.x + x) * 8
			var al: float = 1.0 - datos.decode_half(o + 6)
			alfa[y * tv.x + x] = al
			if al > 0.1 and al < 0.7:          # el humo opaco llega a 0,8 y el fuego a 0,95: lo de en medio es borde
				parcial += 1
			var c: Color = img.get_pixel(clampi(int((x + 0.5) * esc.x), 0, img.get_width() - 1), clampi(int((y + 0.5) * esc.y), 0, img.get_height() - 1))
			var lin: Vector3 = Vector3(datos.decode_half(o), datos.decode_half(o + 2), datos.decode_half(o + 4)) / maxf(al, 0.001)
			if al > 0.9 and c.s > 0.5 and c.v > 0.45 and maxf(lin.x, maxf(lin.y, lin.z)) > 0.15:
				fuego += 1
				var h: float = c.h * 360.0
				if h > 300.0:
					h -= 360.0
				hs.append(h)
				s_suma += c.s
				if h >= 45.0 and h <= 70.0:
					amarillo += 1
			elif al > 0.5 and maxf(lin.x, maxf(lin.y, lin.z)) < 0.12 and c.s > 0.25:
				humo += 1
				h_humo += c.h * 360.0
	for y in tv.y:
		for x in tv.x - 1:
			if (alfa[y * tv.x + x] - 0.4) * (alfa[y * tv.x + x + 1] - 0.4) < 0.0:
				cruces += 1
	for y in tv.y - 1:
		for x in tv.x:
			if (alfa[y * tv.x + x] - 0.4) * (alfa[(y + 1) * tv.x + x] - 0.4) < 0.0:
				cruces += 1
	hs.sort()
	var hm: float = 0.0
	for h in hs:
		hm += h
	return {"fuego": fuego, "amarillo": float(amarillo) / maxf(fuego, 1), "h_medio": hm / maxf(hs.size(), 1), "h_p95": float(hs[int(hs.size() * 0.95)]) if hs.size() > 0 else 0.0,
		"s_media": s_suma / maxf(fuego, 1), "humo": humo, "h_humo": h_humo / maxf(humo, 1),
		"borde_px": float(parcial) / maxf(cruces, 1) * esc.x}




## BARRIDO PROCEDURAL (9/11, Pablo: «que cambios en la longitud, en el ancho, etc. sigan haciendo que se respete la estructura»). Cada caso es la entrada de
## HazGas.derivar_haz (la que da el haz del juego); en todos se miden las MISMAS invariantes, en unidades del dominio y relativas a la escala del caso (M, radios):
##   eje: T media en el núcleo del primer tramo del chorro (t 0,1-0,45 hasta el choque, r < 0,5 R) > 0,6 y su hollín < 1/2 del de la masa;
##   envuelve: fracción del gas caliente junto al obstáculo (sd < 2 M) que está PASADO su ecuador / canto (detrás del centro) > 3 %, y hay gas por encima de él;
##   humo: hollín medio de la masa (junto al obstáculo; sin obstáculo, el final del chorro) > 2 × el del núcleo del chorro (en los chorros finos el núcleo son 1-2 celdas);
##   vuelve: gas caliente que va hacia la lanzadora (u_x > 2·M u/s: relativo al tamaño de la masa) < 3 % y casi nada detrás de la boquilla;
##   dentro: ninguna celda con gas dentro del obstáculo; NaN: ninguno;
##   escala: extensión lateral de la masa (p90 de |z| del gas caliente aguas abajo del choque) / M dentro de ×0,5..×2 de la del caso de referencia;
##   sin obstáculo: el chorro se abre (radio del gas caliente al final > 1,4 × al principio) y acaba en humo;
##   toon (cámara lateral encuadrada con el caso): sin amarillo.
const BARRIDO: Array = [
	["ref (3 m, 0,15, 0,5; esfera 0,8 a 2 m)", {}],
	["largo x0,5", {"largo": 1.5, "dist": 1.0}], ["largo x2", {"largo": 6.0, "dist": 4.0}],
	["ancho x0,5", {"ancho": 0.075}], ["ancho x2", {"ancho": 0.3}],
	["largo x0,5 ancho x0,5", {"largo": 1.5, "dist": 1.0, "ancho": 0.075}], ["largo x0,5 ancho x2", {"largo": 1.5, "dist": 1.0, "ancho": 0.3}],
	["largo x2 ancho x0,5", {"largo": 6.0, "dist": 4.0, "ancho": 0.075}], ["largo x2 ancho x2", {"largo": 6.0, "dist": 4.0, "ancho": 0.3}],
	["alto x0,7", {"alto": 0.35}], ["alto x1,5", {"alto": 0.75}],
	["esfera 0,4", {"tam": 0.4}], ["esfera 1,2", {"tam": 1.2}],
	["caja 0,7", {"obstaculo": "caja", "tam": 0.7}], ["caja 1,4", {"obstaculo": "caja", "tam": 1.4}],
	["sin obstáculo", {"obstaculo": "nada"}],
	["hechizo ᚲ+ᛁ", {"linea_x": 1}], ["hechizo ᚲ+ᛁᛁᛁ", {"linea_x": 3}], ["hechizo ᚲ+ᛁ+ᛏ", {"linea_x": 1, "levitacion": 1}], ["hechizo ᚲ+ᛁ+ᚷ", {"linea_x": 1, "pulso": 1}],
]
var tabla_barrido: Array = []


## Entrada del caso: los hechizos se construyen de verdad (Hechizo.construir con la runa de fuego) y pasan por FuegoToy.describir (HazGas.cfg_de_hechizo).
static func cfg_caso(c: Dictionary) -> Dictionary:
	if c.has("linea_x"):
		var h: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, c)
		return HazGas.cfg_de_hechizo(h)
	var r: Dictionary = HazGas.HAZ_REF.duplicate()
	r.merge(c, true)
	return r


func _barrido() -> void:
	print("== BARRIDO PROCEDURAL (toon, 5 s cada caso)")
	var ref_ext: float = -1.0
	for caso in BARRIDO:
		var nombre: String = caso[0]
		var cfg: Dictionary = cfg_caso(caso[1])
		_lab.call("haz_gas", 0)
		await _esperar(3)
		var g: HazGas = _lab.call("haz_gas", 1, "lateral", true, cfg)
		if g == null or not g.listo():
			_ok("%s: arranca" % nombre, false)
			continue
		g.get_node("HudGas").visible = false
		await _hasta(g, 300)
		await RenderingServer.frame_post_draw
		var vis: Dictionary = _analiza_volumen(g)
		g.pausa = true
		await _esperar(2)
		var m: Dictionary = _medidas(g)
		g.pausa = false
		if ref_ext < 0.0:
			ref_ext = float(m["ext"])
		var d: Dictionary = g.haz_der
		var hay_obst: bool = String(d["obstaculo"]) != "nada"
		var ok_eje: bool = float(m["T_eje"]) > 0.6 and float(m["soot_eje"]) < float(m["soot_masa"]) / 2.0
		var ok_env: bool = (not hay_obst) or (float(m["detras"]) > 0.03 and int(m["encima"]) > 0)
		var ok_humo: bool = float(m["soot_masa"]) > 2.0 * float(m["soot_eje"]) and float(m["soot_masa"]) > 0.01
		var ok_vuelve: bool = float(m["vuelve"]) < 0.03 and float(m["detras_boquilla"]) < 0.01
		var ok_abre: bool = hay_obst or float(m["abre"]) > 1.4
		var ok_esc: bool = float(m["ext"]) > ref_ext * 0.5 and float(m["ext"]) < ref_ext * 2.0
		var ok_amar: bool = float(vis["amarillo"]) < 0.01 and int(vis["fuego"]) > 300
		var todo: bool = ok_eje and ok_env and ok_humo and ok_vuelve and ok_abre and ok_esc and ok_amar and int(m["dentro"]) == 0 and int(m["nan"]) == 0
		var fila: String = "%-28s | %5.3f %4.2f %3dx%3dx%3d | T_eje %4.2f%s hollín eje/masa %.3f/%.3f%s | detrás %4.1f%% encima %4d%s | vuelve %4.1f%%%s | dentro %d nan %d | ext/M %4.2f (ref %4.2f)%s | abre %4.2f%s | amarillo %4.2f%% (%d px)%s" % [
			nombre, float(d["s"]), float(d["M"]), d["res"].x, d["res"].y, d["res"].z, float(m["T_eje"]), "" if float(m["T_eje"]) > 0.6 else "!", float(m["soot_eje"]), float(m["soot_masa"]), "" if ok_humo and ok_eje else "!",
			float(m["detras"]) * 100.0, int(m["encima"]), "" if ok_env else "!", float(m["vuelve"]) * 100.0, "" if ok_vuelve else "!", int(m["dentro"]), int(m["nan"]),
			float(m["ext"]), ref_ext, "" if ok_esc else "!", float(m["abre"]), "" if ok_abre else "!", float(vis["amarillo"]) * 100.0, int(vis["fuego"]), "" if ok_amar else "!"]
		tabla_barrido.append(fila)
		_ok("barrido %s: la estructura se respeta" % nombre, todo, fila)
	print("== TABLA DEL BARRIDO (s m/u · M · rejilla | ...; «!» = lo que falla)")
	for f in tabla_barrido:
		print("  " + f)


## Medidas estructurales del gas (en unidades del dominio). Lee gas y velocidad; con rejillas grandes, una celda de cada 2 por eje.
func _medidas(g: HazGas) -> Dictionary:
	var s: HazGasSolver = g.solver
	var d: Dictionary = g.haz_der
	var res: Vector3i = s.res
	var half: Vector3i = res / 2
	var gas: PackedByteArray = s.leer(s.gas[0])
	var vel: PackedByteArray = s.leer(s.vel[0])
	var paso: int = 2 if s.celdas > 1500000 else 1
	var noz: Vector3 = d["nozzle"]
	var tg: Vector3 = d["target"]
	var mm: float = float(d["M"])
	var hay_obst: bool = String(d["obstaculo"]) != "nada"
	var contacto: Vector3 = g.contacto()
	var eje: Vector3 = (tg - noz).normalized()
	var l_choque: float = (contacto - noz).dot(eje) if hay_obst else (tg - noz).length()
	var centro: Vector3 = d["centro"]
	var arriba: float = (centro.y + float(d["radio"])) if String(d["obstaculo"]) == "esfera" else ((d["semi"] as Vector3).y * 2.0 if hay_obst else 0.0)
	var r = {"T_eje": 0.0, "soot_eje": 0.0, "soot_masa": 0.0, "detras": 0.0, "encima": 0, "vuelve": 0.0, "detras_boquilla": 0.0, "dentro": 0, "nan": 0, "ext": 0.0, "abre": 0.0}
	var n_eje: int = 0
	var n_masa: int = 0
	var n_cerca: int = 0
	var n_detras: int = 0
	var n_cal: int = 0
	var n_vuelve: int = 0
	var t_total: float = 0.0
	var t_atras: float = 0.0
	var zs: Array = []
	var r_ini: Array = []
	var r_fin: Array = []
	var tam: Vector3 = s.mundo_tam
	var lo: Vector3 = s.mundo_lo
	var margen_dentro: float = -maxf(0.25 * mm, 2.0 * tam.x / res.x)
	for z in range(0, res.z, paso):
		for y in range(0, res.y, paso):
			for x in range(0, res.x, paso):
				var o: int = ((z * res.y + y) * res.x + x) * 8
				var T: float = gas.decode_half(o)
				var so: float = gas.decode_half(o + 2)
				if is_nan(T) or is_nan(so) or is_inf(T):
					r["nan"] += 1
					continue
				if T < 0.02 and so < 0.005:
					continue
				var w: Vector3 = (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) / Vector3(res) * tam + lo
				var sd: float = float(g.sd_obstaculo(w)[0])
				if hay_obst and sd < margen_dentro and T + so > 1e-3:
					r["dentro"] += 1
				t_total += T
				if w.x > noz.x + 1.0:
					t_atras += T
				var t: float = (w - noz).dot(eje)
				var rad: float = (w - noz - eje * t).length()
				var tr: float = t / maxf(l_choque, 0.01)
				var radio_chorro: float = lerpf(float(d["beamR0"]), float(d["beamR1"]), clampf(t / (tg - noz).length(), 0.0, 1.0))
				if tr > 0.1 and tr < 0.45 and rad < 0.5 * radio_chorro:
					r["T_eje"] += T
					r["soot_eje"] += so
					n_eje += 1
				var en_masa: bool = (sd > 0.05 and sd < 3.0 * mm and w.x < contacto.x + mm) if hay_obst else (tr > 0.8)
				if en_masa:
					r["soot_masa"] += so
					n_masa += 1
				if T > 0.15:
					var vi: Vector3i = (Vector3i(x, y, z) / 2).clamp(Vector3i.ZERO, half - Vector3i.ONE)
					var vo: int = ((vi.z * half.y + vi.y) * half.x + vi.x) * 8
					n_cal += 1
					if vel.decode_half(vo) > 2.0 * mm and tr > 0.05:     # relativo: las velocidades de la masa escalan con su tamaño
						n_vuelve += 1
					if hay_obst and sd < 2.0 * mm:
						n_cerca += 1
						if w.x < centro.x:
							n_detras += 1
						if w.y > arriba - 0.25 * mm:
							r["encima"] += 1
					if (hay_obst and w.x < contacto.x + mm) or (not hay_obst and tr > 0.5):
						zs.append(absf(w.z))
					if not hay_obst:
						if tr > 0.1 and tr < 0.3:
							r_ini.append(rad)
						elif tr > 0.8 and tr < 1.0:
							r_fin.append(rad)
	r["T_eje"] = float(r["T_eje"]) / maxf(n_eje, 1)
	r["soot_eje"] = float(r["soot_eje"]) / maxf(n_eje, 1)
	r["soot_masa"] = float(r["soot_masa"]) / maxf(n_masa, 1)
	r["detras"] = float(n_detras) / maxf(n_cerca, 1)
	r["vuelve"] = float(n_vuelve) / maxf(n_cal, 1)
	r["detras_boquilla"] = t_atras / maxf(t_total, 1e-6)
	zs.sort()
	r["ext"] = (float(zs[int(zs.size() * 0.9)]) if zs.size() > 0 else 0.0) / mm
	r_ini.sort()
	r_fin.sort()
	if r_ini.size() > 0 and r_fin.size() > 0:
		r["abre"] = float(r_fin[int(r_fin.size() * 0.9)]) / maxf(float(r_ini[int(r_ini.size() * 0.9)]), 1e-3)
	return r


func _medir_calidades() -> void:
	for q in ["low", "med", "high"]:
		_lab.call("haz_gas", 0)
		await _esperar(3)
		var g: HazGas = _lab.call("haz_gas", 1, "demo", false)
		g.crear_solver(q)
		g.camara_en(Vector3(2.5, 6, 23), Vector3(1.4, 2.4, 0), 32.0)
		await _hasta(g, 60)
		var sumas: Dictionary = {}
		var listas: Dictionary = {}
		var n: int = 0
		var vp: float = 0.0
		for k in 240:
			await process_frame
			var t: Dictionary = g.solver.tiempos_gpu()
			if t.is_empty():
				continue
			n += 1
			for c in t:
				sumas[c] = float(sumas.get(c, 0.0)) + float(t[c])
				if not listas.has(c):
					listas[c] = []
				listas[c].append(float(t[c]))
			vp += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		var r: Vector3i = g.solver.res
		var linea: String = "  %s %dx%dx%d (%.2f M celdas, Jacobi %d, %d pasos de raymarch):" % [q, r.x, r.y, r.z, g.solver.celdas / 1.0e6, int(g.solver.calidad["jacobi"]), int(g.solver.calidad["steps"])]
		for c in ["gas", "velocidad", "luz", "chispas", "volumen", "total"]:
			if sumas.has(c):
				var l: Array = listas[c]
				l.sort()
				linea += " %s %.2f (mediana %.2f)" % [c, float(sumas[c]) / n, float(l[l.size() / 2])]
		linea += " ms · fotograma del viewport %.2f ms · %d fps" % [vp / maxf(n, 1), Engine.get_frames_per_second()]
		print(linea)
		_ok("calidad %s: hay marcas de tiempo de GPU" % q, n > 0)


func _hasta(g: HazGas, n: int) -> void:
	var tope: int = 0
	while g.frame < n and tope < 3000:
		await process_frame
		tope += 1


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame

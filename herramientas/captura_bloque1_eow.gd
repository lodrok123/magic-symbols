extends "res://herramientas/escenario_base.gd"
## BLOQUE 1 de la revisión EoW (23/10): luz de fuego que titila, viento en árboles y arbustos, hierba mojada y con escarcha.
## NECESITA VENTANA (los shaders no se compilan en headless):
##   godot --path . --script res://herramientas/captura_bloque1_eow.gd -- [carpeta] [escena]
##   (por defecto res://docs/capturas/bloque1_eow y el Bosque; con res://escenas/PruebaTest2.tscn hay hierba de juego en todo el mapa)
## Mide y fotografía:
##   1 · viento: diferencia media entre dos fotogramas separados 0,7 s, con el viento del decorado y sin él (el jugador quieto).
##   2 · hierba: un área regada (mojada) y otra helada (escarcha) junto al jugador, y el valor que queda en la textura de humedad.
##   3 · fuego: un fuego fijo junto al jugador; energía mínima y máxima de su luz durante 2 s.

var _dir: String = "res://docs/capturas/bloque1_eow"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	await cargar(a[1] if a.size() > 1 else RUTA_BOSQUE)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(30)

	# 1 · Viento
	var con: float = await _diferencia("viento_con")
	_poner_viento(0.0)
	var sin_v: float = await _diferencia("viento_sin")
	_poner_viento(1.0)
	_ok("1 el decorado se mueve con viento", con > sin_v * 1.2 and con > 0.0005, "dif media con %.5f · sin %.5f" % [con, sin_v])

	var c0: Vector2i = celda_jugador()

	# 3 · Fuego (antes de mover al jugador): a una casilla a su derecha, que se vea
	var cf: Vector2i = c0 + Vector2i(1, 0)
	var p: Vector3 = Terreno3D.centro_de(cf, Terreno3D.y_pies(cf))
	maqueta.call("_fuego", p, false)
	await avanzar(5)
	var luz: OmniLight3D = null
	for t in root.find_children("titila", "LuzTitila3D", true, false):
		var l: OmniLight3D = t.get_parent() as OmniLight3D
		if l != null and l.global_position.distance_to(p) < 2.0:
			luz = l
	_ok("3 el fuego tiene una luz que titila", luz != null)
	if luz != null:
		var mn: float = 1000.0
		var mx: float = 0.0
		var inicio: float = reloj.t
		while reloj.t - inicio < 2.0:
			await process_frame
			mn = minf(mn, luz.light_energy)
			mx = maxf(mx, luz.light_energy)
		_ok("3 la energía de la luz varía", mx - mn > 0.1, "min %.2f · max %.2f" % [mn, mx])
		_foto("fuego")

	# 2a · Hierba sobre casillas de SUELO: la moja o la hiela el estado oficial (EstadosSuelo3D), que el shader nuevo también lee
	var hierba: Node = maqueta.get("_hierba")
	var s_moj: Vector2i = c0 + Vector2i(-2, 1)
	var s_hel: Vector2i = c0 + Vector2i(-2, -1)
	Terreno3D.estados.aplicar(s_moj, "agua")
	Terreno3D.estados.aplicar(s_hel, "frio")
	await avanzar_s(0.5)
	_ok("2a el estado oficial moja y hiela esas casillas", Terreno3D.estados.tiene(s_moj, "mojada") and Terreno3D.estados.tiene(s_hel, "helada"),
		"mojada %s · helada %s" % [Terreno3D.estados.tiene(s_moj, "mojada"), Terreno3D.estados.tiene(s_hel, "helada")])
	_foto("hierba_suelo_oficial")

	# 2b · Hierba de juego (la de las fases de fuego): mojada y con escarcha desde la maqueta (Hierba3D.mojar / escarchar)
	var hv: Vector2i = _hierba_mas_cercana(c0)
	if hv == Vector2i(-999, -999) or hierba == null:
		_aviso("2b sin una zona grande de hierba de juego en este mapa (en el Bosque solo está en las casillas v): se salta")
	if hierba != null and hv != Vector2i(-999, -999):
		# Regada en `hv` y helada a 5 casillas (los dos cuadrados de 5×5 se tocan sin pisarse); la cámara cerca, entre los dos.
		var hh: Vector2i = hv + Vector2i(5, 0)
		colocar_jugador(hv + Vector2i(2, 1))
		var cam: Camera3D = maqueta.get("_camara") as Camera3D
		if cam != null:
			cam.size = 9.0
		await avanzar(40)
		_foto("hierba_juego_antes")
		var antes_img: Image = root.get_viewport().get_texture().get_image()
		maqueta.call("_apagar_area", hv, Terreno3D.centro_de(hv, 0.0), false)
		maqueta.call("_apagar_area", hh, Terreno3D.centro_de(hh, 0.0), true)
		await avanzar_s(1.0)
		var despues_img: Image = root.get_viewport().get_texture().get_image()
		if cam != null:
			for par in [["mojada", hv], ["escarcha", hh]]:
				var q: Vector2i = par[1]
				_aviso("2b %s en la casilla %s" % [par[0], str(q)], "jugador en %s · pantalla %s" % [str(celda_jugador()),
					str(cam.unproject_position(Terreno3D.centro_de(q, Terreno3D.y_pies(q))))])
				if not cam.is_position_behind(Terreno3D.centro_de(q, Terreno3D.y_pies(q))):
					var sp: Vector2 = cam.unproject_position(Terreno3D.centro_de(q, Terreno3D.y_pies(q)))
					var r := Rect2i(Vector2i(sp) - Vector2i(110, 110), Vector2i(220, 220)).intersection(Rect2i(Vector2i.ZERO, antes_img.get_size()))
					if r.size.x > 0 and r.size.y > 0:
						var ca: Image = antes_img.get_region(r)
						var cd: Image = despues_img.get_region(r)
						ca.save_png(_dir.path_join("recorte_%s_antes.png" % par[0]))
						cd.save_png(_dir.path_join("recorte_%s_despues.png" % par[0]))
						_aviso("2b color medio de la zona %s" % par[0], "antes %s · después %s · en pantalla %s" % [_media(ca), _media(cd), str(Vector2i(sp))])
		var img: Image = hierba.get("_img_humedad") as Image
		var pm: Color = img.get_pixel(hv.x, hv.y)
		var ph: Color = img.get_pixel(hh.x, hh.y)
		_ok("2b la hierba regada se ve mojada", pm.r > 0.9, "R %.2f G %.2f" % [pm.r, pm.g])
		_aviso("2b la hierba helada", "R %.2f G %.2f (0 si la casilla %s no es hierba de juego)" % [ph.r, ph.g, str(hh)])
		_foto("hierba_juego")


## Dos fotos separadas 0,7 s con el mundo quieto salvo lo que se mueve solo; devuelve la diferencia media (0..1) entre ellas.
func _diferencia(nombre: String) -> float:
	await avanzar(10)
	var a: Image = root.get_viewport().get_texture().get_image()
	await avanzar_s(0.7)
	var b: Image = root.get_viewport().get_texture().get_image()
	a.save_png(_dir.path_join(nombre + "_a.png"))
	b.save_png(_dir.path_join(nombre + "_b.png"))
	var suma: float = 0.0
	var n: int = 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			suma += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
			n += 1
	return suma / float(maxi(n, 1))


var _viento_guardado: Dictionary = {}     ## ShaderMaterial -> su fuerza de viento original

## Apaga (`v` = 0) o devuelve (`v` = 1) el viento de todo el decorado en lotes. Solo para comparar.
func _poner_viento(v: float) -> void:
	for mi in root.find_children("lote_*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			continue
		var mats: Array = []
		for i in range(mm.mesh.get_surface_count()):
			mats.append(mm.mesh.surface_get_material(i))
		mats.append((mi as MultiMeshInstance3D).material_override)
		for m in mats:
			if not (m is ShaderMaterial) or not Ocluso3D.es_comun(m):
				continue
			var sm: ShaderMaterial = m as ShaderMaterial
			if v <= 0.0:
				var bruto: Variant = sm.get_shader_parameter("viento")     # null si nunca se puso (el valor por defecto del shader, 0)
				var f: float = float(bruto) if bruto != null else 0.0
				if f > 0.0:
					_viento_guardado[sm] = f
					sm.set_shader_parameter("viento", 0.0)
			elif _viento_guardado.has(sm):
				sm.set_shader_parameter("viento", _viento_guardado[sm])


## La casilla de hierba DE JUEGO (`_es_hierba`) más cercana a `c` cuyo cuadrado de 5×5, y el de 5 casillas a su derecha, son hierba
## entera (así se ven las dos manchas sin árboles ni piedras encima). (-999, -999) si no hay.
func _hierba_mas_cercana(c: Vector2i) -> Vector2i:
	var lado: int = int(maqueta.get("_lado"))
	var mejor: Vector2i = Vector2i(-999, -999)
	var dmin: int = 1 << 30
	for y in range(lado):
		for x in range(lado):
			var q := Vector2i(x, y)
			if _cuadrado_de_hierba(q) and _cuadrado_de_hierba(q + Vector2i(5, 0)):
				var d: int = absi(q.x - c.x) + absi(q.y - c.y)
				if d < dmin:
					dmin = d
					mejor = q
	return mejor


## ¿Es hierba de juego el centro y al menos 18 de las 25 casillas de su cuadrado de 5×5?
func _cuadrado_de_hierba(q: Vector2i) -> bool:
	if not bool(maqueta.call("_en_mapa", q)) or not bool(maqueta.call("_es_hierba", q)):
		return false
	var n: int = 0
	for y in range(q.y - 2, q.y + 3):
		for x in range(q.x - 2, q.x + 3):
			var p := Vector2i(x, y)
			if bool(maqueta.call("_en_mapa", p)) and bool(maqueta.call("_es_hierba", p)):
				n += 1
	return n >= 18


func _media(img: Image) -> String:
	var s := Vector3.ZERO
	var n: int = 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			s += Vector3(c.r, c.g, c.b)
			n += 1
	s /= float(maxi(n, 1))
	return "(%.3f, %.3f, %.3f)" % [s.x, s.y, s.z]


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)

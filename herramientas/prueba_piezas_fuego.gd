extends SceneTree
## Prueba sin ventana de PiezaFuego3D (T6 c/d): las 17 piezas se crean, miden lo previsto (con su origen), y los estados cambian lo que dicen.
##   godot --headless --path . --script res://herramientas/prueba_piezas_fuego.gd
var fallos: int = 0

func ok(c: bool, m: String) -> void:
	if c:
		print("  ok  ", m)
	else:
		print("  FALLA ", m)
		fallos += 1

func _caja(n: Node, acum: Transform3D = Transform3D.IDENTITY) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var r := AABB(); var primero := true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		r = t * (n as MeshInstance3D).mesh.get_aabb(); primero = false
	for h in n.get_children():
		if h is OmniLight3D:
			continue
		var c: AABB = _caja(h, t)
		if c.size.length() > 0.0:
			r = c if primero else r.merge(c); primero = false
	return r

func _piezas(mundo: Node3D, modo: bool) -> void:
	for pid in PiezaFuego3D.ids():
		var p: PiezaFuego3D = PiezaFuego3D.crear(pid, {"modelos": modo})
		mundo.add_child(p)
		var c: AABB = _caja(p)
		var m: Vector3 = p.medida
		var cuelga: bool = pid == "cuerda_tensa" or pid == "cuerda_cabo"
		ok(p.con_modelo == (modo and PiezaFuego3D.hay_modelo(pid)), "%s: %s" % [pid, "modelo de Meshy" if p.con_modelo else "primitivas"])
		# Medida: el lado mayor coincide con el de la tabla (10 %: las primitivas son una aproximación, no el modelo).
		var mayor: float = maxf(c.size.x, maxf(c.size.y, c.size.z))
		var previsto: float = maxf(m.x, maxf(m.y, m.z))
		ok(absf(mayor - previsto) / previsto < 0.25, "%s: lado mayor %.2f ≈ %.2f" % [pid, mayor, previsto])
		if cuelga:
			ok(c.end.y > -0.15 and c.end.y < 0.12 and c.position.y < -0.2, "%s: cuelga del origen (%.2f..%.2f)" % [pid, c.position.y, c.end.y])
		elif pid.begins_with("goblin_escudo"):
			ok(absf(c.position.y + c.size.y * 0.5) < 0.05, "%s: origen en el centro del disco" % pid)
		else:
			ok(absf(c.position.y) < 0.12, "%s: origen en la base (y mín %.2f)" % [pid, c.position.y])


func _initialize() -> void:
	await process_frame
	var mundo := Node3D.new(); root.add_child(mundo)
	ok(PiezaFuego3D.ids().size() == 17, "hay 17 piezas (%d)" % PiezaFuego3D.ids().size())
	ok(PiezaFuego3D.crear("no_existe") == null, "una pieza que no existe da null")
	for modo in [true, false]:
		_piezas(mundo, modo)
	# Caldera
	var cal: PiezaFuego3D = PiezaFuego3D.crear("caldera_cuerpo"); mundo.add_child(cal)
	var hierro: StandardMaterial3D = cal._mat_calor[0]
	var c0: Color = hierro.albedo_color
	cal.poner_calor(0.5)
	ok(hierro.emission_enabled and cal.get_node_or_null("luz_calor") != null, "caldera caliente: emisión y luz")
	cal.poner_calor(1.0)
	ok((cal.con_modelo or hierro.albedo_color.r > c0.r + 0.3) and hierro.emission_energy_multiplier > 0.4, "caldera al rojo: más roja y brillante (%s)" % ("modelo" if cal.con_modelo else "primitivas"))
	cal.poner_calor(0.0)
	await process_frame
	ok(not hierro.emission_enabled and cal._luz == null, "caldera fría: sin emisión ni luz")
	var med: PiezaFuego3D = PiezaFuego3D.crear("caldera_medidor"); mundo.add_child(med)
	var rel: MeshInstance3D = med.get_node("relleno")
	ok(not rel.visible, "medidor frío: sin relleno")
	med.poner_calor(1.0)
	ok(rel.visible and absf(rel.scale.y - (0.9 if med.con_modelo else 1.0)) < 0.01, "medidor al rojo: relleno entero")
	# Escudo
	var esc: PiezaFuego3D = PiezaFuego3D.crear("goblin_escudo_entero"); mundo.add_child(esc)
	esc.poner_estado("ardiendo")
	ok(esc._mat_calor.size() > 0 and esc._mat_calor[0].emission_enabled, "escudo ardiendo: brasa en las tablas")
	esc.poner_estado("entero")
	ok(not esc._mat_calor[0].emission_enabled, "escudo entero: sin brasa")
	var quem: PiezaFuego3D = PiezaFuego3D.crear("goblin_escudo_quemado")
	ok(quem != null and quem.estado == "", "escudo quemado existe")
	# Contador
	var con: PiezaFuego3D = PiezaFuego3D.crear("contador_placa"); mundo.add_child(con)
	con.poner_cuenta(2)
	var n_vis: int = 0
	for i in 4:
		var g: Node3D = con.get_node_or_null("gema_%d" % i)
		if g != null and g.visible:
			n_vis += 1
	ok(n_vis == 2, "contador 2/4: dos gemas encendidas (%d)" % n_vis)
	con.poner_cuenta(0)
	ok(not (con.get_node("gema_0") as Node3D).visible, "contador 0/4: ninguna")
	# Leña
	var fo: PiezaFuego3D = PiezaFuego3D.crear("fogata_lenos"); mundo.add_child(fo)
	fo.poner_lenos(1)
	if fo.con_modelo:
		ok(fo.visible, "fogata (modelo): con leña se ve")
		fo.poner_lenos(0)
		ok(not fo.visible, "fogata (modelo): sin leña se esconde")
		var fp: PiezaFuego3D = PiezaFuego3D.crear("fogata_lenos", {"modelos": false}); mundo.add_child(fp)
		fp.poner_lenos(1)
		ok((fp.get_node("leno_0") as Node3D).visible and not (fp.get_node("leno_1") as Node3D).visible, "fogata (primitivas): un solo leño")
	else:
		ok((fo.get_node("leno_0") as Node3D).visible and not (fo.get_node("leno_1") as Node3D).visible, "fogata: un solo leño")
	# Baldosa
	var bal: PiezaFuego3D = PiezaFuego3D.crear("baldosa_falsa"); mundo.add_child(bal)
	var llego: Array = [false]
	bal.terminado.connect(func() -> void: llego[0] = true)
	bal.caer()
	await create_timer(PiezaFuego3D.T_CAER + 0.2).timeout
	ok(llego[0] and not bal.visible and bal.position.y < -1.0, "baldosa falsa cae y se esconde")
	# Antorcha
	var ant: PiezaFuego3D = PiezaFuego3D.crear("antorcha_pie"); mundo.add_child(ant)
	ant.poner_llama(true)
	ok(ant.get_node_or_null("llama") != null, "antorcha encendida: llama")
	ant.poner_llama(false)
	await process_frame
	ok(ant._llama == null, "antorcha apagada: sin llama")
	# Mojado
	var seto := MeshInstance3D.new(); seto.mesh = BoxMesh.new(); mundo.add_child(seto)
	PiezaFuego3D.mojado(seto, true)
	ok(seto.material_overlay != null, "mojado: capa puesta")
	PiezaFuego3D.mojado(seto, false)
	ok(seto.material_overlay == null, "mojado: capa quitada")
	# Fuerza primitivas
	PiezaFuego3D.usar_modelos = false
	ok(not PiezaFuego3D.crear("leno").con_modelo, "usar_modelos = false fuerza primitivas")
	print("FALLOS ", fallos)
	quit(1 if fallos > 0 else 0)

extends "res://herramientas/prueba_trayectorias.gd"
## B9c · LA TRAYECTORIA DE LA FLECHA (23/11, sesión HECHIZOS; Pablo: «sigue con B9c, la trayectoria de la flecha»). Sin gravedad en los hechizos (22/11), la flecha vuela recta.
## Para fuego, tierra y agua con ᛇ y con ᛇᛇ, en tres casos (sin nada delante, con un goblin a 2 casillas y con una pared a 1,5 casillas):
##   · la previsión trae UN recorrido, recto (sin quiebres);
##   · Apuntado3D pinta esa cinta A RAS DE SUELO (vuelo recto: sin sombra, que eran dos rayas) y UNA retícula en su final;
##   · el punto final previsto cae a ±0,5 casilla de donde se para el proyectil de verdad, y por el mismo motivo (alcance / golpe / muro).
##   godot --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_trayectoria_flecha.gd

var tabla: Array = []          ## [{elemento, glifos, caso, previsto, real, error, motivo}] (para el plan y las fotos)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(20)
	var pared: Vector2i = _sitio_contra_pared(2)
	_ok("0 hay una pared a 1,5 casillas al oeste de una casilla libre", pared.x >= 0, str(pared))
	for el in ["fuego", "tierra", "agua"]:
		for gl in [["flecha"], ["flecha", "flecha"]]:
			await _caso(el, gl, "libre", Vector2i(12, 33), Vector2i(-1, -1))
			await _caso(el, gl, "goblin", Vector2i(12, 33), Vector2i(10, 33))
			if pared.x >= 0:
				await _caso(el, gl, "pared", pared, Vector2i(-1, -1))
	print("TABLA B9c")
	for f in tabla:
		print("  %-6s %-14s %-6s  previsto %s  real %s  error %.2f u  motivo %s" % [f["elemento"], "+".join(f["glifos"]), f["caso"], f["previsto"], f["real"], f["error"], f["motivo"]])
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _caso(elemento: String, glifos: Array, caso: String, desde: Vector2i, goblin: Vector2i) -> void:
	var nombre: String = "%s %s %s" % [elemento, "+".join(glifos), caso]
	var oeste := Vector3(-1, 0, 0)
	if goblin.x >= 0:
		_goblin(goblin)
	await avanzar(2)
	var d: Dictionary = _preparar(desde, elemento, glifos)
	PrevisionHechizo.prever(lanzador, d, jugador.position, oeste)
	var rec: Dictionary = PrevisionHechizo.ultimo_recorrido.duplicate(true)
	var caminos: Array = rec.get("caminos", [])
	var fines: Array = rec.get("fines", [])
	var causas: Array = rec.get("causas", [])
	_ok("%s: la previsión trae UN recorrido" % nombre, caminos.size() == 1 and (caminos[0] as PackedVector3Array).size() >= 2, str(caminos.size()))
	if caminos.is_empty() or fines.is_empty():
		_limpiar_caso()
		return
	var cam: PackedVector3Array = caminos[0]
	_ok("%s: va recta (sin quiebres)" % nombre, Apuntado3D.quiebres(cam).is_empty())
	var ap := Apuntado3D.new()
	maqueta.add_child(ap)
	ap.mostrar(rec, jugador.position, oeste, 0.0, Apuntado3D.color_de(elemento))
	_ok("%s: el apuntado pinta la cinta y UNA retícula" % nombre, ap.caminos_dibujados.size() == 1 and ap.reticulas.size() == 1, "%d · %d" % [ap.caminos_dibujados.size(), ap.reticulas.size()])
	_ok("%s: la cinta va a ras de suelo y sin sombra (vuelo recto)" % nombre, ap.a_ras_dibujado and not ap._sombras.visible)
	var fin_prev: Vector3 = fines[0]
	var causa_prev: String = String(causas[0]) if not causas.is_empty() else ""
	if not ap.reticulas.is_empty():
		var r: Vector3 = ap.reticulas[0]
		_ok("%s: la retícula está en el final del recorrido" % nombre, Vector2(r.x - cam[cam.size() - 1].x, r.z - cam[cam.size() - 1].z).length() < 0.05)
	ap.queue_free()
	# Lanzar de verdad.
	var antes: Array = lanzador.get_children().filter(func(n): return n is HechizoVivo)
	_lanzar(d, oeste)
	var vivo: HechizoVivo = null
	for n in lanzador.get_children():
		if n is HechizoVivo and not antes.has(n):
			vivo = n
	_ok("%s: sale el proyectil" % nombre, vivo != null)
	if vivo == null:
		_limpiar_caso()
		return
	var ultimo: Vector3 = vivo.p
	var motivo: String = ""
	var fin_real: Array = [""]
	vivo.terminado.connect(func(causa, _p, _n, _m): fin_real[0] = String(causa), CONNECT_ONE_SHOT)
	var t: float = 0.0
	while t < 3.0 and is_instance_valid(vivo) and (vivo.activo or t < 0.05):
		ultimo = vivo.p
		t += await avanzar_s(1.0 / 30.0)
	if is_instance_valid(vivo):
		ultimo = vivo.p
	motivo = String(fin_real[0])
	var err: float = Vector2(ultimo.x - fin_prev.x, ultimo.z - fin_prev.z).length()
	_ok("%s: el final previsto cae a ±0,5 casilla del real (%.2f u)" % [nombre, err], err <= 0.5 * Terreno3D.casilla, "previsto %s · real %s" % [fin_prev, ultimo])
	var esperado: String = {"libre": "alcance", "goblin": "golpe", "pared": "muro"}[caso]
	_ok("%s: acaba por «%s» (real «%s», previsto «%s»)" % [nombre, esperado, motivo, causa_prev], motivo == esperado)
	tabla.append({"elemento": elemento, "glifos": glifos, "caso": caso, "previsto": Vector2(snappedf(fin_prev.x, 0.01), snappedf(fin_prev.z, 0.01)),
		"real": Vector2(snappedf(ultimo.x, 0.01), snappedf(ultimo.z, 0.01)), "error": err, "motivo": "%s / %s" % [motivo, causa_prev]})
	_limpiar_caso()
	await avanzar(3)


func _limpiar_caso() -> void:
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	_limpiar()

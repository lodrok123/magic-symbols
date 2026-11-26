extends "res://herramientas/escenario_base.gd"

func _escenario() -> void:
	await cargar("res://escenas/PruebaSalaGolem.tscn")
	Sfx.REGISTRAR = true
	for el in ["fuego", "agua", "hielo", "rayo", "viento", "tierra"]:
		var linaje := HechizoVivo.Linaje.new()
		var zona := Lanzador3D.ZonaV2.new()
		zona.elemento = el
		zona.celdas = {Vector2i(2, 2): true}
		zona.vida = 100.0
		lanzador.mundo.add_child(zona)
		var solidez := Lanzador3D.SolidezV2.new()
		solidez.elemento = el
		solidez.celdas = zona.celdas.duplicate()
		solidez.vida = 100.0
		lanzador.mundo.add_child(solidez)
		var voz: SonidoPersistencia3D = SonidoPersistencia3D.registrar(zona, el, linaje)
		SonidoPersistencia3D.registrar(solidez, el, linaje)
		Sfx.vaciar_registro()
		zona.avanzar(101.0)
		_ok(el + ": no final si queda otra manifestación", Sfx.veces(el + "_fin") == 0 and voz._audio.playing)
		solidez.golpe(10000.0)
		_ok(el + ": último efecto reproduce un final", Sfx.veces(el + "_fin") == 1 and not voz._audio.playing)
		solidez.golpe(10000.0)
		voz._actualizar(true)
		_ok(el + ": rotura y limpieza no duplican el final", Sfx.veces(el + "_fin") == 1)
		await process_frame
		await process_frame
		var natural := Lanzador3D.ZonaV2.new()
		natural.elemento = el
		natural.celdas = {Vector2i(2, 2): true}
		natural.vida = 100.0
		lanzador.mundo.add_child(natural)
		SonidoPersistencia3D.registrar(natural, el)
		Sfx.vaciar_registro()
		natural.avanzar(101.0)
		_ok(el + ": caducidad natural reproduce un final", Sfx.veces(el + "_fin") == 1)
		await process_frame
		await process_frame
		var retirado := Lanzador3D.ZonaV2.new()
		retirado.celdas = {Vector2i(2, 2): true}
		retirado.vida = 100.0
		lanzador.mundo.add_child(retirado)
		SonidoPersistencia3D.registrar(retirado, el)
		Sfx.vaciar_registro()
		SonidoPersistencia3D.retirar(retirado)
		retirado.queue_free()
		await process_frame
		await process_frame
		_ok(el + ": sustitución o retirada explícita sin final", Sfx.veces(el + "_fin") == 0)
		# Retirar el contenedor de una escena no es un final del hechizo.
		var escena := Node3D.new()
		lanzador.mundo.add_child(escena)
		var cierre := Lanzador3D.ZonaV2.new()
		cierre.celdas = {Vector2i(2, 2): true}
		cierre.vida = 100.0
		escena.add_child(cierre)
		SonidoPersistencia3D.registrar(cierre, el)
		Sfx.vaciar_registro()
		escena.queue_free()
		await process_frame
		await process_frame
		_ok(el + ": cerrar escena no dispara final", Sfx.veces(el + "_fin") == 0)

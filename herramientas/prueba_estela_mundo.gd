extends SceneTree

## PRUEBA de la estela que se queda en el mundo (25/11/2026, presentacion/vfx/toy/estela_mundo_toy.gd):
##   godot --headless --path . --script res://herramientas/prueba_estela_mundo.gd
## Para fuego, agua y tierra: con EstelaMundoToy.activa apagada la bola en vuelo NO cuelga estela; encendida, cuelga UNA, hermana de la bola (no hija: se queda en el mundo),
## suelta bocanadas según avanza (≈ una por `paso` m), las bocanadas NO se mueven con la bola, y al morir la bola la estela se apaga y se libera sola.
## Y que los otros toys (sin `_estela_elemento`) no cuelgan nada.

const EstelaMundo = preload("res://presentacion/vfx/toy/estela_mundo_toy.gd")

var _ok: int = 0
var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _comprobar(c: bool, txt: String) -> void:
	if c:
		_ok += 1
		print("OK    " + txt)
	else:
		_fallos += 1
		print("FALLO " + txt)


func _correr() -> void:
	await process_frame
	var raiz: Node3D = Node3D.new()
	root.add_child(raiz)
	for el in ["fuego", "agua", "tierra"]:
		await _probar(raiz, el)
	await _probar_otro(raiz)
	EstelaMundo.activa = false
	print("prueba_estela_mundo: %d bien, %d fallos" % [_ok, _fallos])
	quit(1 if _fallos > 0 else 0)


func _bola(el: String) -> EfectoToy:
	var b: EfectoToy
	match el:
		"fuego":
			var f := FuegoToy.new()
			f.definir(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
			b = f
		"agua":
			var a := AguaToy.new()
			a.definir(AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
			b = a
		_:
			var t := TierraToy.new()
			t.definir(TierraToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
			b = t
	return b


func _probar(raiz: Node3D, el: String) -> void:
	# apagada: nada
	EstelaMundo.activa = false
	var b0: EfectoToy = _bola(el)
	raiz.add_child(b0)
	b0.position = Vector3(0, 1, 0)
	for i in 10:
		b0.position.x += 0.1
		await process_frame
	_comprobar(b0.proyectil and b0.estela_mundo() == null, "%s: con la estela apagada la bola en vuelo no cuelga estela" % el)
	b0.queue_free()
	await process_frame
	# encendida
	EstelaMundo.activa = true
	var b: EfectoToy = _bola(el)
	raiz.add_child(b)
	b.position = Vector3(0, 1, 0)
	await process_frame
	var recorrido: float = 0.0
	for i in 30:
		b.position.x += 0.1
		recorrido += 0.1
		await process_frame
	var e: Node3D = b.estela_mundo()
	_comprobar(e != null and e.get_parent() == raiz and e.top_level, "%s: encendida cuelga UNA estela, hermana de la bola y suelta en el mundo" % el)
	if e == null:
		b.queue_free()
		return
	var paso: float = float(EstelaMundo.RECETAS[el]["paso"])
	var n: int = int(e.call("soltadas"))
	_comprobar(n >= int(recorrido / paso * 0.7) and n <= int(recorrido / paso * 1.3) + 1, "%s: suelta ≈ una bocanada cada %.2f m (%d en %.1f m)" % [el, paso, n, recorrido])
	_comprobar(raiz.get_children().filter(func(x): return x.get_script() == EstelaMundo).size() == 1, "%s: solo una estela por bola" % el)
	# las bocanadas se quedan donde nacieron aunque la bola se vaya lejos
	var antes: Dictionary = _posiciones(e)
	b.position.x += 5.0
	await process_frame
	var despues: Dictionary = _posiciones(e)
	var quietas: bool = true
	var vistas: int = 0
	for c in antes:
		if despues.has(c) and float(despues[c][0]) == float(antes[c][0]) and float((despues[c][1] as Vector3).x) < b.position.x - 4.0:
			vistas += 1
			if (antes[c][1] as Vector3).distance_to(despues[c][1] as Vector3) > 0.3:
				quietas = false
	_comprobar(quietas and vistas > 0, "%s: las bocanadas no se van con la bola (%d comprobadas)" % [el, vistas])
	# la bola muere: la estela deja de soltar y se libera sola
	b.queue_free()
	await process_frame
	var n2: int = int(e.call("soltadas"))
	var limite: int = Time.get_ticks_msec() + 2500
	while is_instance_valid(e) and Time.get_ticks_msec() < limite:
		await process_frame
	_comprobar(not is_instance_valid(e), "%s: al morir la bola la estela se apaga y se libera sola (había soltado %d)" % [el, n2])


## {clave: [t0, pos]} de las bocanadas vivas (clave = hueco de la reserva; sirve para comparar la MISMA bocanada en dos instantes).
func _posiciones(e: Node3D) -> Dictionary:
	var r: Dictionary = {}
	var sp: Array = e.get("_sprites")
	for i in sp.size():
		if (sp[i]["mi"] as MeshInstance3D).visible:
			r["s%d" % i] = [float(sp[i]["t0"]), (sp[i]["mi"] as MeshInstance3D).global_position]
	var h: Node = e.get("_humo")
	if h != null:
		for st in h.call("estados"):
			r["h%d" % int(st["hueco"])] = [-1.0, st["pos"]]
	return r


func _probar_otro(raiz: Node3D) -> void:
	EstelaMundo.activa = true
	var f := FuegoToy.new()
	f.definir(FuegoToy.Figura.MURO, 1.5, 0.8, 0.2, false)
	raiz.add_child(f)
	for i in 5:
		await process_frame
	_comprobar(f.estela_mundo() == null, "un muro de fuego no cuelga estela (solo la BOLA en vuelo)")
	f.queue_free()

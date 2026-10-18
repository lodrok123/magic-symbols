extends SceneTree
## Prueba del enchufe de los modelos del laboratorio de fuego (cuerda, contador, seto mojado). Los estados se leen del árbol de nodos.
var fallos: int = 0
func ok(c: bool, m: String) -> void:
	print(("OK    " if c else "FALLO ") + m)
	if not c: fallos += 1
func _init() -> void:
	await process_frame
	var cu := Cuerda3D.new()
	root.add_child(cu)
	await process_frame
	ok(cu.get_node_or_null("poste") is PiezaFuego3D and cu.get_node_or_null("cuerda") is PiezaFuego3D and cu.get_node_or_null("cabo") is PiezaFuego3D, "la cuerda usa los 3 modelos")
	ok(cu.get_node("cuerda_caida") is Node3D and not (cu.get_node("cuerda_caida") as Node3D).visible, "el cabo caído existe y está oculto")
	cu.arder()
	var mi: MeshInstance3D = cu.get_node("cuerda").find_children("*", "MeshInstance3D", true, false)[0]
	ok(mi.material_overlay != null, "ardiendo: la cuerda lleva capa de brasa")
	cu._apagar()
	ok(mi.material_overlay == null, "apagada: sin capa")
	cu.arder()
	cu._romper()
	ok(cu.estado == Cuerda3D.EstadoCuerda.ROTA and not (cu.get_node("cuerda") as Node3D).visible and not (cu.get_node("cabo") as Node3D).visible and (cu.get_node("cuerda_caida") as Node3D).visible, "rota: se ocultan tensa y cabo y sale el cabo caído")
	var c2 := Cuerda3D.new(); PiezaFuego3D.usar_modelos = false
	root.add_child(c2); await process_frame
	ok(not (c2.get_node("poste") is PiezaFuego3D), "sin modelos: primitivas")
	c2.arder(); c2._romper()
	ok(c2.rota_ya, "sin modelos la cuerda sigue rompiéndose")
	PiezaFuego3D.usar_modelos = true
	var a := Node3D.new(); var m := MeshInstance3D.new(); m.mesh = BoxMesh.new(); a.add_child(m); root.add_child(a)
	PiezaFuego3D.mojado(a, true)
	ok(m.material_overlay != null, "mojado pone capa")
	PiezaFuego3D.mojado(a, false)
	ok(m.material_overlay == null, "mojado la quita")
	var ls: Array = []
	for i in 4:
		var d := Node.new(); d.set_script(null); ls.append(d)
	var ct := ContadorReactivos3D.new()
	ct.preparar([], 0, Vector2i(-1, -1))
	ok(ct._placa == null, "sin casilla no hay placa (pruebas)")
	var luces: Array = []
	for i in 4:
		var q := Node.new(); q.set_script(load("res://herramientas/_luz.gd")); luces.append(q)
	var c3 := ContadorReactivos3D.new()
	c3.preparar(luces, 0, Vector2i(2, 2))
	root.add_child(c3); await process_frame
	ok(c3._placa != null, "con casilla sale la placa")
	var gemas := func() -> int:
		var n := 0
		for i in 4:
			var g := c3._placa.get_node_or_null("gema_%d" % i) as Node3D
			if g != null and g.visible: n += 1
		return n
	ok(gemas.call() == 0, "0 encendidas = 0 gemas")
	luces[0].is_lit = true; luces[1].is_lit = true
	await process_frame
	ok(gemas.call() == 2 and c3.encendidos == 2, "2 encendidas = 2 gemas")
	print("FALLOS: ", fallos)
	quit()

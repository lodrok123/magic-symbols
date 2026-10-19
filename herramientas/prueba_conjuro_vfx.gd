extends SceneTree
## Prueba sin ventana de ConjuroVfx3D (T6b): con un Lanzador de mentira que emite `conjuro_fase` en los tiempos reales, comprueba que
## cada elemento crea voluta y forma, que la voluta llega a la mano, y que al disparo no queda nada colgando. Sin depender de Lanzador3D.
## 17/10 (T-CP3): amplía con los TRES ORÍGENES de cast point (mano_libre, manos_alto, suelo_delante): la forma nace en la posición que llega
## en `conjuro_fase`, tiene el aspecto de su origen, dura hasta el disparo y después no queda nada vivo; un origen desconocido o un Lanzador
## sin `origen_conjuro` caen en «mano_libre». Además: `Vfx3D.temblor` (la cámara vuelve a su sitio tras sacudidas encadenadas) y `golpe_estrella`.
##   godot --headless --path . --script res://herramientas/prueba_conjuro_vfx.gd
class FalsoLanzador:
	extends Node
	signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
	var origen: String = "mano_libre"
	var destino: Vector3 = Vector3.INF
	func tiempos_conjuro(_e: String) -> Array:
		return [0.05, 0.10, 0.05]
	## Lo que el Juego dará a partir de `CastPoints.de(forma, elemento)["origen"]` y el punto del suelo donde nace el hechizo.
	func origen_conjuro(_e: String) -> Dictionary:
		return {"origen": origen, "destino": destino}

## Un Lanzador de los de antes: sin `origen_conjuro`.
class LanzadorSinOrigen:
	extends Node
	signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
	func tiempos_conjuro(_e: String) -> Array:
		return [0.05, 0.10, 0.05]

var fallos: int = 0

func ok(c: bool, m: String) -> void:
	if c:
		print("  ok  ", m)
	else:
		print("  FALLA ", m)
		fallos += 1

func _initialize() -> void:
	await process_frame
	var mundo := Node3D.new(); root.add_child(mundo)
	var l := FalsoLanzador.new(); mundo.add_child(l)
	var c: ConjuroVfx3D = ConjuroVfx3D.conectar(l, mundo)
	ok(c != null, "conectar devuelve el nodo")
	ok(ConjuroVfx3D.conectar(Node.new(), mundo) == null, "sin señal conjuro_fase no conecta")
	await process_frame      # calentamiento: el primer fotograma de un script trae un delta enorme que se come de golpe el temporizador de 0,14 s, y el primer paso de un tween es de 0 s
	var libro := Vector3(-0.3, 0.55, 0.0)
	var mano := Vector3(0.4, 0.8, 0.2)
	for el in ConjuroVfx3D.PERFIL.keys() + ["inventado"]:
		var antes: int = c.get_child_count()
		l.conjuro_fase.emit("runa", el, mano)
		l.conjuro_fase.emit("voluta", el, libro)
		ok(c.get_child_count() == antes + 1, "%s: nace la voluta" % el)
		var cab: Node3D = c.get_child(c.get_child_count() - 1)
		ok(cab.global_position.distance_to(libro) < 0.01, "%s: sale del libro" % el)
		await create_timer(0.14).timeout
		ok(cab.global_position.distance_to(mano) < 0.08, "%s: llega a la mano (%.3f)" % [el, cab.global_position.distance_to(mano)])
		l.conjuro_fase.emit("forma", el, mano)
		ok(c._vivos.size() >= 1, "%s: hay forma en la mano" % el)
		await create_timer(0.08).timeout
		l.conjuro_fase.emit("disparo", el, mano)
		await create_timer(0.3).timeout
		await process_frame
		ok(c._vivos.is_empty(), "%s: tras el disparo no queda forma" % el)
	await create_timer(1.0).timeout
	await process_frame
	ok(c.get_child_count() == 0, "al cabo de un segundo no queda ningún nodo (%d)" % c.get_child_count())
	# --- Los tres orígenes de cast point ---
	print("-- orígenes de cast point")
	var cp: Dictionary = {"mano_libre": Vector3(0.4, 0.8, 0.2), "manos_alto": Vector3(0.4, 1.7, 0.2), "suelo_delante": Vector3(1.0, 0.0, 2.0)}
	var destino := Vector3(1.2, 0.0, 2.4)
	for origen in ["mano_libre", "manos_alto", "suelo_delante"]:
		for el in ConjuroVfx3D.PERFIL.keys():
			await _ciclo(c, l, el, origen, cp[origen], destino, libro)
	# --- Casos límite: origen desconocido y Lanzador sin `origen_conjuro` ---
	print("-- casos límite")
	l.origen = "inventado"
	await _ciclo(c, l, "fuego", "mano_libre", cp["mano_libre"], destino, libro, "origen inventado")
	var l2 := LanzadorSinOrigen.new(); mundo.add_child(l2)
	var c2: ConjuroVfx3D = ConjuroVfx3D.conectar(l2, mundo)
	l2.conjuro_fase.emit("runa", "agua", cp["mano_libre"])
	l2.conjuro_fase.emit("forma", "agua", cp["mano_libre"])
	ok(c2._origen == "mano_libre" and c2._vivos.size() == 1 and c2._vivos[0].get_node_or_null("Convergen") != null, "sin origen_conjuro: forma en la mano, como siempre")
	l2.conjuro_fase.emit("disparo", "agua", cp["mano_libre"])
	await create_timer(0.6).timeout
	await process_frame
	ok(c2._vivos.is_empty() and c2.get_child_count() == 0, "sin origen_conjuro: nada vivo tras el disparo")
	# Si el disparo no llega, la runa siguiente retira lo que quedara.
	l.origen = "suelo_delante"
	l.conjuro_fase.emit("runa", "tierra", cp["suelo_delante"])
	l.conjuro_fase.emit("forma", "tierra", cp["suelo_delante"])
	var colgada: Node = c._vivos[0]
	l.conjuro_fase.emit("runa", "tierra", cp["suelo_delante"])
	ok(c._vivos.is_empty() and (not is_instance_valid(colgada) or colgada.is_queued_for_deletion()), "un conjuro sin disparo se retira en la runa siguiente")
	await create_timer(0.3).timeout
	# --- (b) temblor público y (c) estrella de impacto ---
	print("-- Vfx3D.temblor y golpe_estrella")
	var cam := Camera3D.new(); cam.h_offset = -0.55; cam.v_offset = 0.1; root.add_child(cam); cam.current = true
	var fx := Vfx3D.new(); mundo.add_child(fx)
	fx.temblor(0.6)
	await create_timer(0.05).timeout
	fx.temblor(1.0)
	await create_timer(0.05).timeout
	fx.temblor(0.25)
	fx.temblor(7.0)       # fuera de rango: se recorta a 1, no falla
	await create_timer(0.5).timeout
	ok(absf(cam.h_offset + 0.55) < 0.0001 and absf(cam.v_offset - 0.1) < 0.0001, "temblor: tras sacudidas encadenadas la cámara vuelve a su sitio (%.4f, %.4f)" % [cam.h_offset, cam.v_offset])
	var antes: int = fx.get_child_count()
	fx.golpe_estrella(Vector3(1.0, 1.0, 1.0), "fuego")
	ok(fx.get_child_count() > antes, "golpe_estrella: nace la estrella")
	await create_timer(0.8).timeout
	await process_frame
	ok(fx.get_child_count() == antes, "golpe_estrella: no queda nada a los 0,8 s (%d de %d)" % [fx.get_child_count(), antes])
	print("FALLOS ", fallos)
	quit(1 if fallos > 0 else 0)


## Un conjuro completo con el origen `origen` (el Lanzador de mentira lo devuelve en `origen_conjuro`): runa → voluta → forma → disparo.
## Comprueba que la forma nace en el cast point, tiene el aspecto de su origen, sigue ahí hasta el disparo y que después no queda nada.
## `esperado` = el origen que debe haberse dibujado (distinto de `origen` solo en los casos límite).
func _ciclo(c: ConjuroVfx3D, l: FalsoLanzador, el: String, esperado: String, pos: Vector3, destino: Vector3, libro: Vector3, nota: String = "") -> void:
	var tag: String = "%s/%s%s" % [esperado, el, (" (%s)" % nota) if nota != "" else ""]
	if nota == "":
		l.origen = esperado
	l.destino = destino
	l.conjuro_fase.emit("runa", el, pos)
	l.conjuro_fase.emit("voluta", el, libro)
	await create_timer(0.12).timeout
	l.conjuro_fase.emit("forma", el, pos)
	# `forma` es lo último que se añade a `_vivos` (la voluta, si sigue viva, va antes).
	var raiz: Node3D = c._vivos[c._vivos.size() - 1] as Node3D if not c._vivos.is_empty() else null
	ok(raiz != null, "%s: hay forma" % tag)
	if raiz == null:
		return
	ok(raiz.global_position.distance_to(pos) < 0.01, "%s: nace en el cast point" % tag)
	ok(c._origen == esperado, "%s: origen dibujado = %s" % [tag, c._origen])
	var tiene_conv: bool = raiz.get_node_or_null("Convergen") != null
	var tiene_subida: bool = raiz.get_node_or_null("Subida") != null
	var tiene_columna: bool = false
	var anillo_en: Vector3 = Vector3.INF
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh is CylinderMesh and mi.material_override is ShaderMaterial and mi.get_parent() != raiz:
			tiene_columna = true
		if mi.mesh is PlaneMesh:
			anillo_en = mi.global_position
	match esperado:
		"mano_libre":
			ok(tiene_conv and not tiene_subida and not tiene_columna and not anillo_en.is_finite(), "%s: orbe con chispas que convergen" % tag)
		"manos_alto":
			ok(tiene_columna and tiene_subida and not tiene_conv, "%s: columna de luz sobre las manos" % tag)
			ok(anillo_en.is_finite() and anillo_en.distance_to(destino + Vector3(0.0, 0.03, 0.0)) < 0.01, "%s: círculo en el suelo delante, en el destino" % tag)
		"suelo_delante":
			ok(anillo_en.is_finite() and absf(anillo_en.y - (pos.y + 0.03)) < 0.01 and not tiene_columna and not tiene_conv, "%s: círculo rúnico en el suelo del cast point" % tag)
	await create_timer(0.15).timeout
	ok(is_instance_valid(raiz) and not raiz.is_queued_for_deletion(), "%s: la forma dura hasta el disparo" % tag)
	var hijos: int = c.get_child_count()
	l.conjuro_fase.emit("disparo", el, pos)
	ok(c._vivos.is_empty(), "%s: tras el disparo no hay forma pendiente" % tag)
	ok(c.get_child_count() >= hijos + 2, "%s: destello y onda en el cast point" % tag)
	await create_timer(0.6).timeout
	await process_frame
	ok(c.get_child_count() == 0, "%s: a los 0,6 s no queda ningún nodo (%d)" % [tag, c.get_child_count()])

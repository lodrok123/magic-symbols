extends SceneTree

## PRUEBA de ARDIENDO «TOY» (presentacion/vfx/toy/ardiendo_toy.gd, 18/11/2026). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_ardiendo_toy.gd
## Comprueba: que `asegurar` crea UN hermano del objetivo con sus cuatro capas (overlay en las mallas, lenguas, brasas, luz); que no se duplica; que el overlay se restaura EXACTO al quitarse
## (el que hubiera antes, o ninguno); que las lenguas van en huesos si hay esqueleto y de reserva si no; que se va solo, con fundido, cuando el objetivo deja de arder; que se libera si el
## objetivo desaparece; que la luz parpadea con ruido; y que los colores no tiran a amarillo. Termina con «FALLOS: N».

const S: float = 2.0
const SCRIPT_OBJETIVO: String = "extends Node3D\nvar quemando: float = 1.0\nvar muerto: bool = false\n"

var _fallos: int = 0
var _mundo: Mundo3D = null
var _jugador: Jugador3D = null


func _ok(texto: String, bien: bool) -> void:
	print(("  OK   " if bien else "  FALLO ") + texto)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	_correr()


func _esperar(segundos: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < segundos:
		await process_frame


func _hermanos(padre: Node) -> int:
	var n: int = 0
	for c in padre.get_children():
		if c is ArdiendoToy:
			n += 1
	return n


## Un objetivo sin esqueleto: dos mallas, una con un overlay propio.
func _objetivo(previo: Material) -> Node3D:
	var s: GDScript = GDScript.new()
	s.source_code = SCRIPT_OBJETIVO
	s.reload()
	var o: Node3D = Node3D.new()
	o.set_script(s)
	var a: MeshInstance3D = MeshInstance3D.new()
	a.name = "A"
	a.mesh = CapsuleMesh.new()
	a.material_overlay = previo
	o.add_child(a)
	var b: MeshInstance3D = MeshInstance3D.new()
	b.name = "B"
	b.mesh = SphereMesh.new()
	o.add_child(b)
	var q: MeshInstance3D = MeshInstance3D.new()               # una barra de vida (quad) no es cuerpo
	q.name = "Barra"
	q.mesh = QuadMesh.new()
	o.add_child(q)
	return o


func _correr() -> void:
	await process_frame
	_colores()
	await _sin_esqueleto()
	await _se_va_solo()
	await _objetivo_liberado()
	await _goblin_real()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _colores() -> void:
	print("== colores")
	var cs: Dictionary = {"borde": ArdiendoToy.COLOR_BORDE, "nucleo": ArdiendoToy.COLOR_NUCLEO, "pico": ArdiendoToy.COLOR_PICO, "luz": ArdiendoToy.COLOR_LUZ, "brasa": ArdiendoToy.COLOR_BRASA}
	for k in cs:
		var c: Color = cs[k]
		_ok("color %s (%.2f, %.2f, %.2f): rojo domina, verde/rojo <= 0,6 y azul <= 0,25 (nada amarillo)" % [k, c.r, c.g, c.b], c.r >= 0.8 and c.g / c.r <= 0.6 and c.b <= 0.25)
	var f: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/ardiendo_cuerpo.gdshader")
	_ok("el shader tiene el naranja de pico por defecto sin amarillo (g/r <= 0,6)", f.find("vec3(1.0, 0.5, 0.14)") >= 0 and f.find("vec3(1.0, 0.33, 0.05)") >= 0)


func _sin_esqueleto() -> void:
	print("== sin esqueleto (sitios de reserva)")
	var padre: Node3D = Node3D.new()
	root.add_child(padre)
	var previo: StandardMaterial3D = StandardMaterial3D.new()
	var o: Node3D = _objetivo(previo)
	padre.add_child(o)
	ArdiendoToy.asegurar(o, 1.2)
	ArdiendoToy.asegurar(o, 1.2)
	await process_frame
	ArdiendoToy.asegurar(o, 1.2)
	_ok("llamar tres veces a asegurar deja UN solo ArdiendoToy, hermano del objetivo (hay %d)" % _hermanos(padre), _hermanos(padre) == 1 and o.get_child_count() == 3)
	var e: ArdiendoToy = o.get_meta(ArdiendoToy.META) as ArdiendoToy
	var est: Dictionary = e.estado()
	_ok("estado: 2 mallas con la capa (la barra no), 5 lenguas, brasas y luz (%s)" % str(est), int(est["mallas"]) == 2 and int(est["lenguas"]) == 5 and bool(est["brasas"]) and bool(est["luz"]))
	_ok("sin esqueleto: ninguna lengua va en un hueso, todas de reserva", int(est["lenguas_en_huesos"]) == 0)
	var a: MeshInstance3D = o.get_node("A") as MeshInstance3D
	var b: MeshInstance3D = o.get_node("B") as MeshInstance3D
	_ok("overlay puesto en las dos mallas (la de la barra, no)", a.material_overlay is ShaderMaterial and a.material_overlay == b.material_overlay and (o.get_node("Barra") as MeshInstance3D).material_overlay == null)
	var cabeza: Node3D = e.get_node("Lengua_cabeza") as Node3D
	var hombro: Node3D = e.get_node("Lengua_hombro_izq") as Node3D
	_ok("las lenguas de reserva: cabeza arriba (y %.2f) y hombro a un lado (x %.2f, y %.2f)" % [cabeza.position.y, hombro.position.x, hombro.position.y],
		cabeza.position.y > 0.9 * 1.2 - 0.01 and hombro.position.x < -0.1 and hombro.position.y < cabeza.position.y and hombro.position.y > 0.4)
	var luz: OmniLight3D = e.get_node("Luz") as OmniLight3D
	_ok("luz naranja de alcance 2,5 x alto (%.2f)" % luz.omni_range, absf(luz.omni_range - 2.5 * 1.2) < 0.01 and luz.light_color.g / luz.light_color.r <= 0.6)
	# fundido de entrada
	_ok("recién puesta aún no está a tope (fundido %.2f) y a los 0,4 s sí" % float(est["fundido"]), float(est["fundido"]) < 1.0)
	await _esperar(0.4)
	_ok("a los 0,4 s: fundido 1", float(e.estado()["fundido"]) > 0.99)
	# la luz parpadea con ruido
	var minimo: float = 99.0
	var maximo: float = -99.0
	var distintas: Dictionary = {}
	for i in 90:
		await process_frame
		var en: float = luz.light_energy
		minimo = minf(minimo, en)
		maximo = maxf(maximo, en)
		distintas[snappedf(en, 0.01)] = true
	_ok("la luz parpadea (energía de %.2f a %.2f, %d valores distintos) y nunca se apaga" % [minimo, maximo, distintas.size()], maximo - minimo > 0.25 and minimo > 0.5 and distintas.size() > 20)
	# restaurar exacto
	e.soltar()
	_ok("tras soltar el overlay sigue unos instantes y la capa de llamas se apaga", e.soltado() and a.material_overlay is ShaderMaterial)
	await _esperar(0.7)
	_ok("al terminar el fundido el overlay vuelve EXACTO a lo de antes: A = el material previo, B = ninguno", a.material_overlay == previo and b.material_overlay == null)
	_ok("y no deja metadatos en las mallas", not a.has_meta(ArdiendoToy.META_PREVIO) and not b.has_meta(ArdiendoToy.META_PREVIO))
	await _esperar(1.2)
	_ok("el nodo se libera solo tras la cola (brasas y lenguas)", _hermanos(padre) == 0 and not is_instance_valid(e))
	_ok("el objetivo ya no tiene la marca", not o.has_meta(ArdiendoToy.META) or not is_instance_valid(o.get_meta(ArdiendoToy.META)))
	padre.queue_free()
	await process_frame


func _se_va_solo() -> void:
	print("== se va solo cuando deja de arder")
	var padre: Node3D = Node3D.new()
	root.add_child(padre)
	var o: Node3D = _objetivo(null)
	padre.add_child(o)
	ArdiendoToy.asegurar(o, 1.0)
	await _esperar(0.4)
	var e: ArdiendoToy = o.get_meta(ArdiendoToy.META) as ArdiendoToy
	_ok("arde: no soltado", not e.soltado() and (o.get_node("A") as MeshInstance3D).material_overlay is ShaderMaterial)
	o.set("quemando", 0.0)
	await _esperar(0.25)
	_ok("quemando = 0: empieza el fundido de salida (soltado, fundido %.2f entre 0 y 1)" % float(e.estado()["fundido"]), e.soltado() and float(e.estado()["fundido"]) > 0.0 and float(e.estado()["fundido"]) < 1.0)
	await _esperar(0.3)
	_ok("a los 0,55 s el overlay ya está restaurado (ninguno)", (o.get_node("A") as MeshInstance3D).material_overlay == null)
	# asegurar de nuevo mientras la anterior se apaga: crea una nueva y el overlay previo verdadero se conserva
	o.set("quemando", 1.0)
	ArdiendoToy.asegurar(o, 1.0)
	await process_frame
	var e2: ArdiendoToy = o.get_meta(ArdiendoToy.META) as ArdiendoToy
	_ok("volver a arder tras soltar crea otro (no el viejo)", e2 != e and not e2.soltado())
	await _esperar(0.3)
	o.set("quemando", 0.0)
	await _esperar(2.0)
	_ok("al apagarse el segundo, ninguna malla queda con overlay y no hay ningún ArdiendoToy", (o.get_node("A") as MeshInstance3D).material_overlay == null and (o.get_node("B") as MeshInstance3D).material_overlay == null and _hermanos(padre) == 0)
	# muerto también lo quita
	o.set("quemando", 5.0)
	ArdiendoToy.asegurar(o, 1.0)
	await _esperar(0.3)
	o.set("muerto", true)
	await _esperar(0.2)
	_ok("muerto: se suelta aunque siga con quemando", (o.get_meta(ArdiendoToy.META) as ArdiendoToy).soltado())
	# poner() puntual con `dura`
	await _esperar(1.5)
	var p: ArdiendoToy = ArdiendoToy.poner(o, 1.0, 0.3, 0.5)
	await _esperar(0.3)
	_ok("poner(dura 0,5): vive mientras dura", not p.soltado())
	await _esperar(0.4)
	_ok("poner(dura 0,5): pasado el tiempo se suelta aunque el objetivo siga", p.soltado())
	await _esperar(1.8)
	padre.queue_free()
	await process_frame


func _objetivo_liberado() -> void:
	print("== si el objetivo se libera, el efecto se va con él")
	var padre: Node3D = Node3D.new()
	root.add_child(padre)
	var o: Node3D = _objetivo(null)
	padre.add_child(o)
	ArdiendoToy.asegurar(o, 1.0)
	await _esperar(0.3)
	var e: ArdiendoToy = o.get_meta(ArdiendoToy.META) as ArdiendoToy
	_ok("puesto", _hermanos(padre) == 1)
	o.free()
	await _esperar(0.1)
	_ok("liberado el objetivo, el efecto se suelta", e.soltado())
	await _esperar(1.7)
	_ok("y se libera (sin errores) tras su cola", not is_instance_valid(e) and _hermanos(padre) == 0)
	padre.queue_free()
	await process_frame
	var inactivo: Node3D = _objetivo(null)
	root.add_child(inactivo)
	ArdiendoToy.ACTIVO = false
	ArdiendoToy.asegurar(inactivo, 1.0)
	ArdiendoToy.ACTIVO = true
	_ok("ACTIVO = false: no pone nada", inactivo.get_parent().get_children().filter(func(c: Node) -> bool: return c is ArdiendoToy).is_empty())
	inactivo.queue_free()
	await process_frame


func _goblin_real() -> void:
	print("== goblin real (modelo con esqueleto), a través de Combate3D")
	var filas: PackedStringArray = []
	for _y in range(10):
		filas.append("..........")
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, {})
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 8.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)
	await process_frame
	var p: Vector3 = Vector3(5.5 * S, Terreno3D.y_pies(Vector2i(5, 5)), 5.5 * S)
	var modelo: Pj3D = Pj3D.new()
	_mundo.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	var hijos_antes: int = g.get_child_count()
	await _esperar(0.3)
	_ok("sin quemar no hay ArdiendoToy", not g.has_meta(ArdiendoToy.META))
	g.quemando = 3.0
	await _esperar(0.5)
	var e: ArdiendoToy = g.get_meta(ArdiendoToy.META, null) as ArdiendoToy
	_ok("Combate3D lo pone solo mientras `quemando` > 0", e != null and is_instance_valid(e) and e.get_parent() == g.get_parent())
	if e == null:
		_ok("(sin efecto no se puede seguir)", false)
		return
	var est: Dictionary = e.estado()
	print("       ", est)
	_ok("tiene esqueleto: las lenguas de cabeza, hombros y manos van en HUESOS (%d de 5)" % int(est["lenguas_en_huesos"]), int(est["lenguas_en_huesos"]) >= 3)
	_ok("el modelo (con esqueleto) lleva la capa en sus mallas (%d)" % int(est["mallas"]), int(est["mallas"]) >= 1)
	_ok("no cambia la lista de hijos del enemigo", g.get_child_count() == hijos_antes)
	# la lengua de la cabeza está más arriba que la de las manos y cerca del cuerpo
	var cabeza: Node3D = e.get_node("Lengua_cabeza") as Node3D
	var mano: Node3D = e.get_node("Lengua_mano_izq") as Node3D
	_ok("la lengua de la cabeza (y %.2f) más alta que la de la mano (y %.2f), ambas cerca del enemigo (a %.2f m)" % [cabeza.global_position.y, mano.global_position.y, cabeza.global_position.distance_to(g.global_position)],
		cabeza.global_position.y > mano.global_position.y and cabeza.global_position.distance_to(g.global_position) < 1.6)
	var pilar: Node = g.get_node_or_null(VfxReaccion3D.NOMBRE_LLAMAS)
	print("       pilar llamas_cuerpo presente: ", pilar != null)
	g.quemando = 0.0
	await _esperar(2.0)
	_ok("al apagarse la quemadura se quita sola", not is_instance_valid(e) and not g.has_meta(ArdiendoToy.META) or (g.has_meta(ArdiendoToy.META) and not is_instance_valid(g.get_meta(ArdiendoToy.META))))
	var restos: int = 0
	for n in g.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_overlay is ShaderMaterial and ((n as MeshInstance3D).material_overlay as ShaderMaterial).shader == ArdiendoToy.SHADER_CUERPO:
			restos += 1
	_ok("ninguna malla del goblin conserva la capa de llamas (%d)" % restos, restos == 0)

extends "res://herramientas/escenario_base.gd"
## ENGANCHE DE LOGROS Y REACCIONES EN LA MAQUETA (diario 245, Juego). Antes `Logros3D.conectar` y `ReaccionesVfx3D.conectar` solo los llamaba el lab de playtest;
## ahora los llama la maqueta (`prueba_test2.gd`, tras montar `_efectos`) una vez por nivel. Comprueba, sobre el Bosque 01 de verdad (escena con el nivel horneado):
##   1. Mundo3D.actual existe y hay EXACTAMENTE una conexion de Logros3D y una de ReaccionesVfx3D; volver a llamar a `conectar` no las duplica.
##   2. Una reaccion («congelado») dibuja su VFX bajo `_efectos`; un logro («puzle_resuelto») dibuja el suyo, cuenta en `Logros3D.total` y pone el rotulo.
##   3. «nivel_completado» sale UNA vez al abrir el cofre final (fin de demo), con su fanfarria: rotulo, hitstop (que se restaura) y zoom.
##   4. Recargar el nivel (mundo nuevo) deja una conexion en el mundo nuevo, el viejo se libera y NO se emite ningun nivel_completado al cargar.
##   5. El lab de playtest (que sigue llamando a `conectar`) tampoco duplica: una conexion de cada.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_enganche_logros.gd

const RUTA_BOSQUE_01: String = "res://escenas/PruebaBosque01.tscn"
const RUTA_LAB: String = "res://laboratorios/LabPlaytestEoW.tscn"

var _vistos: Array = []


func _escenario() -> void:
	await cargar(RUTA_BOSQUE_01, true)
	var mundo: Mundo3D = maqueta.get("_mundo") as Mundo3D
	_ok("1.0 la maqueta tiene su Mundo3D y es el `Mundo3D.actual`", mundo != null and Mundo3D.actual == mundo)
	if mundo == null:
		return
	_ok("1.1 UNA conexion de Logros3D a `Mundo3D.logro` (la puso la maqueta)", _conexiones(mundo, "logro", "_al_logro") == 1, str(_conexiones(mundo, "logro", "_al_logro")))
	_ok("1.2 UNA conexion de ReaccionesVfx3D a `Mundo3D.reaccion`", _conexiones(mundo, "reaccion", "_al_reaccionar") == 1, str(_conexiones(mundo, "reaccion", "_al_reaccionar")))
	var efectos: Node3D = maqueta.get("_efectos") as Node3D
	_ok("1.3 volver a llamar a `conectar` devuelve true y no duplica nada", Logros3D.conectar(mundo, efectos) and ReaccionesVfx3D.conectar(mundo, efectos)
		and _conexiones(mundo, "logro", "_al_logro") == 1 and _conexiones(mundo, "reaccion", "_al_reaccionar") == 1)
	mundo.logro.connect(func(n: String, _p: Vector3, _o: Node) -> void: _vistos.append(n))

	# 2. Una reaccion y un logro producen su presentacion.
	var punto: Vector3 = jugador.position + Vector3(1.0, 0.5, 0.0)
	var antes: int = efectos.get_child_count()
	Mundo3D.avisar_reaccion("congelado", punto, null)
	await avanzar(2)
	_ok("2.1 la reaccion «congelado» dibuja su VFX bajo `_efectos`", efectos.get_child_count() > antes, "%d -> %d hijos" % [antes, efectos.get_child_count()])
	var total_pr: int = int(Logros3D.total.get("puzle_resuelto", 0))
	antes = efectos.get_child_count()
	Mundo3D.avisar_logro("puzle_resuelto", punto, null)
	await avanzar(2)
	_ok("2.2 el logro «puzle_resuelto» cuenta una vez en `Logros3D.total`", int(Logros3D.total.get("puzle_resuelto", 0)) == total_pr + 1)
	_ok("2.3 y dibuja sus motas/aro/luz (mas hijos de `_efectos`)", efectos.get_child_count() > antes, "%d -> %d" % [antes, efectos.get_child_count()])
	_ok("2.4 y pone el rotulo «¡Puzle resuelto!» en el HUD", Logros3D.texto_visible() == "¡Puzle resuelto!", "«%s»" % Logros3D.texto_visible())
	await avanzar_s(2.6)

	# 3. nivel_completado: el cofre final del Bosque 01 (fin de demo).
	var reglas: Node = maqueta.get_node_or_null("Reglas")
	_ok("3.0 el nivel trae sus reglas de Bosque 01", reglas != null)
	if reglas == null:
		return
	_vistos.clear()
	var total_nc: int = int(Logros3D.total.get("nivel_completado", 0))
	reglas.call("_aparecer_cofre", 1)                       # el cofre 2 aparece al caer el elemental; aqui se fuerza (como hace escenario_bosque_01)
	await avanzar(3)
	_ok("3.1 antes de abrir el cofre final no hay ningun nivel_completado", _vistos.count("nivel_completado") == 0)
	reglas.call("_al_abrir_cofre", 1)
	await avanzar(2)
	_ok("3.2 abrir el cofre final emite «nivel_completado» UNA vez", _vistos.count("nivel_completado") == 1, str(_vistos))
	_ok("3.3 la tabla lo cuenta (+1) y el rotulo dice «¡Nivel completado!»", int(Logros3D.total.get("nivel_completado", 0)) == total_nc + 1 and Logros3D.texto_visible() == "¡Nivel completado!", "«%s»" % Logros3D.texto_visible())
	_ok("3.4 lleva hitstop (time_scale frenado)", Logros3D.hitstop_activo() and is_equal_approx(Engine.time_scale, Logros3D.ESCALA_HITSTOP))
	await _esperar_real(0.35)
	_ok("3.5 y el hitstop se restaura solo (time_scale 1)", not Logros3D.hitstop_activo() and is_equal_approx(Engine.time_scale, 1.0), "%.3f" % Engine.time_scale)
	reglas.call("_al_abrir_cofre", 1)
	reglas.call("_al_abrir_cofre", 1)
	await avanzar(2)
	_ok("3.6 abrir/entregar otra vez el cofre NO repite el logro", _vistos.count("nivel_completado") == 1, str(_vistos))
	var fila: Dictionary = Logros3D.resolver("nivel_completado")
	var sala: Dictionary = Logros3D.resolver("sala_limpia")
	_ok("3.7 la celebracion es mayor que «sala_limpia»: mas motas, aro, luz, texto mas largo, zoom mayor y hitstop >= el suyo",
		int(fila["motas"]) > int(sala["motas"]) and float(fila["anillo"]) > float(sala["anillo"]) and float(fila["luz"]) > float(sala["luz"])
		and float(fila["texto_dura"]) > float(sala["texto_dura"]) and float(fila["zoom"]) > float(sala["zoom"]) and float(fila["hitstop"]) >= float(sala["hitstop"]) and String(fila["sfx"]) != "")
	await avanzar_s(4.0)

	# 4. Recargar: mundo nuevo, una conexion, y cargar NO emite nivel_completado.
	var viejo: WeakRef = weakref(mundo)
	var total_antes: int = int(Logros3D.total.get("nivel_completado", 0))
	_vistos.clear()
	maqueta.queue_free()
	await avanzar(4)
	_ok("4.1 al descargar el nivel el mundo viejo se libera (no queda colgando)", viejo.get_ref() == null)
	await cargar(RUTA_BOSQUE_01, true)
	var mundo2: Mundo3D = maqueta.get("_mundo") as Mundo3D
	_ok("4.2 el mundo nuevo es el `Mundo3D.actual` y tiene UNA conexion de cada", mundo2 != null and mundo2 != mundo and Mundo3D.actual == mundo2
		and _conexiones(mundo2, "logro", "_al_logro") == 1 and _conexiones(mundo2, "reaccion", "_al_reaccionar") == 1)
	await avanzar_s(1.0)
	_ok("4.3 cargar el nivel no emite «nivel_completado»", int(Logros3D.total.get("nivel_completado", 0)) == total_antes, "%d -> %d" % [total_antes, int(Logros3D.total.get("nivel_completado", 0))])
	var antes2: int = (maqueta.get("_efectos") as Node3D).get_child_count()
	Mundo3D.avisar_reaccion("congelado", jugador.position + Vector3(1, 0.5, 0), null)
	await avanzar(2)
	_ok("4.4 tras recargar la reaccion vuelve a dibujar bajo los `_efectos` NUEVOS (el padre estatico se actualizo)", (maqueta.get("_efectos") as Node3D).get_child_count() > antes2)
	maqueta.queue_free()
	await avanzar(4)

	# 5. El lab de playtest tambien llama a `conectar`: no duplica.
	await cargar(RUTA_LAB, false)
	var mundo3: Mundo3D = maqueta.get("_mundo") as Mundo3D
	await avanzar(10)
	var lab: Node = maqueta.get_node_or_null("Reglas")
	_ok("5.1 el lab de playtest monta y sus enganches devuelven true", lab != null and bool(lab.call("enganche_ok")) and bool(lab.call("enganche_logros_ok")))
	_ok("5.2 en el lab sigue habiendo UNA conexion de cada (la maqueta y el lab no se duplican)", mundo3 != null and _conexiones(mundo3, "logro", "_al_logro") == 1 and _conexiones(mundo3, "reaccion", "_al_reaccionar") == 1,
		"logro %d · reaccion %d" % [_conexiones(mundo3, "logro", "_al_logro"), _conexiones(mundo3, "reaccion", "_al_reaccionar")])
	Logros3D.restaurar_tiempo()


## Cuantas conexiones de la senal `senal` apuntan al metodo `metodo` (el de las tablas estaticas).
func _conexiones(mundo: Object, senal: String, metodo: String) -> int:
	var n: int = 0
	for c in mundo.get_signal_connection_list(senal):
		var cb: Callable = c["callable"]
		var objeto: Object = cb.get_object()
		# Solo las de la tabla estatica (objeto = el script de la clase), no las del lab, que tambien se llama `_al_reaccionar` pero cuelga de un nodo.
		if cb.get_method() == metodo and not (objeto is Node):
			n += 1
	return n


## Espera en tiempo de PARED (el hitstop baja Engine.time_scale y el reloj de deltas iria lento).
func _esperar_real(segundos: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < segundos:
		await process_frame

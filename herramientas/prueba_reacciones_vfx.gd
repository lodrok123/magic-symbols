extends SceneTree

## PRUEBA (Pipeline, 21/10): PL2 de PLAN_EOW. La tabla reacción → efecto + sonido (`ReaccionesVfx3D`) y los efectos (`VfxReaccion3D`).
## No mira solo que «salga algo»: cada fila de la tabla apunta a un efecto y a un sonido que EXISTEN (el sonido, también como archivo en audio/), cada efecto
## deja en el árbol lo que promete (emisores, luz, hijo que cuelga del que arde), lo que arde se puede apagar y no deja nada huérfano, y el enganche a
## `Mundo3D.reaccion` solo se hace si esa señal existe.
##   godot --headless --path . --script res://herramientas/prueba_reacciones_vfx.gd
class FalsoMundo:
	extends Node
	signal reaccion(nombre: String, punto: Vector3, nodo: Node)

class FalsoGoblin:
	extends Node3D
	var quemando: float = 0.0
	var altura: float = 0.85

class FalsaPieza:
	extends Node3D
	var tipo: String = "seto"

var _fallos: int = 0
var _mundo: Node3D = null


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  MAL  ") + texto)
	if not cond:
		_fallos += 1


func _contar(n: Node, clase: String) -> int:
	var c: int = 0
	for h in n.find_children("*", clase, true, false):
		c += 1
	return c


func _correr() -> void:
	await process_frame
	_mundo = Node3D.new()
	root.add_child(_mundo)
	await process_frame

	print("== La tabla es coherente ==")
	for r in ReaccionesVfx3D.CATALOGO:
		_ok(ReaccionesVfx3D.TABLA.has(r), "«%s» tiene fila en la plantilla" % r)
	for r in ["prendido", "apagado_agua", "apagado_viento", "consumido", "mojado", "secado", "congelado", "derretido", "electrocutado", "hundido", "aturdido", "empujado"]:
		_ok(ReaccionesVfx3D.CATALOGO.has(r), "«%s» (catálogo de A4) está en el catálogo" % r)
	var sfx_vistos: Dictionary = {}
	for tipo in [""] + ReaccionesVfx3D.EXCEPCIONES.keys():
		for r in ReaccionesVfx3D.CATALOGO:
			var f: Dictionary = ReaccionesVfx3D.resolver(r, String(tipo))
			_ok(ReaccionesVfx3D.EFECTOS.has(String(f.get("vfx", ""))), "[%s] %s → efecto «%s» existe" % [tipo, r, f.get("vfx", "")])
			var s: String = String(f.get("sfx", ""))
			if s != "":
				sfx_vistos[s] = true
				_ok(Sfx.CATALOGO.has(s), "[%s] %s → sonido «%s» está en el catálogo de Sfx" % [tipo, r, s])
	for s in sfx_vistos.keys():
		var arch: String = Sfx.CARPETA + String((Sfx.CATALOGO[s]["f"] as Array)[0])
		_ok(ResourceLoader.exists(arch) or FileAccess.file_exists(arch), "el archivo de «%s» existe (%s)" % [s, arch])
	for ex in ReaccionesVfx3D.EXCEPCIONES.keys():
		for r in (ReaccionesVfx3D.EXCEPCIONES[ex] as Dictionary).keys():
			_ok(ReaccionesVfx3D.TABLA.has(r), "la excepción [%s] %s apunta a una reacción real" % [ex, r])
	_ok(ReaccionesVfx3D.resolver("no_existe").is_empty(), "una reacción desconocida no tiene fila")
	_ok(ReaccionesVfx3D.reproducir("no_existe", Vector3.ZERO, null, _mundo).is_empty(), "…y reproducirla no hace nada ni falla")
	_ok(ReaccionesVfx3D.resolver("prendido", "goblin")["vfx"] == "llamas_cuerpo" and ReaccionesVfx3D.resolver("prendido", "goblin")["sfx"] == "arde_bucle", "excepción: el goblin que arde deja llamas colgando")
	_ok(ReaccionesVfx3D.resolver("prendido", "seto")["vfx"] == "llamarada", "tipo sin excepción para la reacción: usa la plantilla")
	_ok(ReaccionesVfx3D.resolver("prendido", "goblin")["esc"] == 1.0, "la excepción solo cambia lo que dice: el resto sale de la plantilla")

	print("== tipo_de ==")
	var gob := FalsoGoblin.new()
	_mundo.add_child(gob)
	var pie := FalsaPieza.new()
	_mundo.add_child(pie)
	var meta := Node3D.new()
	meta.set_meta("tipo", "flecha")
	_mundo.add_child(meta)
	_ok(ReaccionesVfx3D.tipo_de(gob) == "goblin", "un enemigo (tiene `quemando`) es «goblin»")
	_ok(ReaccionesVfx3D.tipo_de(pie) == "seto", "una pieza con propiedad `tipo` usa esa")
	_ok(ReaccionesVfx3D.tipo_de(meta) == "flecha", "el meta `tipo` manda")
	_ok(ReaccionesVfx3D.tipo_de(null) == "", "null = sin tipo")

	print("== Goblin ardiendo ==")
	gob.position = Vector3(2, 0, 3)
	var fila: Dictionary = ReaccionesVfx3D.reproducir("prendido", gob.global_position, gob, _mundo)
	_ok(fila.get("vfx", "") == "llamas_cuerpo", "reproducir devuelve la fila resuelta")
	var llamas: FuegoToy = gob.get_node_or_null(VfxReaccion3D.NOMBRE_LLAMAS) as FuegoToy
	_ok(llamas != null and llamas.get_parent() == gob, "el toy de fuego cuelga del goblin")
	_ok(llamas != null and llamas.figura == FuegoToy.Figura.PILAR and llamas.chispas == 0.25 and _contar(llamas, "OmniLight3D") == 1, "llama vertical de cuerpo con chispas reducidas y una luz")
	var ancho_g: float = llamas.semieje_x if llamas != null else 0.0
	var alto: FalsoGoblin = FalsoGoblin.new()
	alto.altura = 1.7
	_mundo.add_child(alto)
	var l2: FuegoToy = VfxReaccion3D.llamas_cuerpo(alto) as FuegoToy
	_ok(l2 != null and l2.semieje_x > ancho_g * 1.5, "un enemigo del doble de alto arde con llamas más anchas")
	var otra: Node3D = VfxReaccion3D.llamas_cuerpo(gob)
	_ok(otra == llamas and gob.get_children().filter(func(c): return String(c.name).begins_with("LlamasCuerpo")).size() == 1, "arder dos veces no duplica las llamas")
	_ok(ReaccionesVfx3D.suena_bucle(gob), "suena el crepitar en bucle mientras arde")
	await create_timer(0.7).timeout
	_ok(is_instance_valid(llamas) and llamas.aparicion > 0.95, "la llama sigue encendida hasta recibir el apagado")
	_ok(VfxReaccion3D.apagar_llamas(gob, true), "apagar_llamas devuelve true si ardía")
	_ok(is_instance_valid(llamas) and llamas.name != VfxReaccion3D.NOMBRE_LLAMAS, "las llamas entran en el apagado del toy")
	_ok(not VfxReaccion3D.apagar_llamas(gob), "apagar dos veces: la segunda no hace nada")
	_ok(gob.get_node_or_null(VfxReaccion3D.NOMBRE_LLAMAS) == null, "el nombre queda libre: si vuelve a arder se crea otro")
	await create_timer(2.3).timeout
	_ok(not is_instance_valid(llamas), "el hijo se libera cuando acaba la última partícula (no quedan llamas huérfanas)")
	ReaccionesVfx3D.reproducir("prendido", gob.global_position, gob, _mundo)
	_ok(gob.get_node_or_null(VfxReaccion3D.NOMBRE_LLAMAS) != null, "vuelve a arder")
	ReaccionesVfx3D.reproducir("apagado_agua", gob.global_position, gob, _mundo)
	_ok(gob.get_node_or_null(VfxReaccion3D.NOMBRE_LLAMAS) == null, "«apagado_agua» apaga las llamas del goblin")
	_ok(not ReaccionesVfx3D.suena_bucle(gob), "…y corta el crepitar")
	var gotas: Array[Node] = _mundo.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n is ImpactoAguaToy)
	var vapor: Node = _mundo.get_node_or_null("VaporReaccion")
	_ok(gotas.size() == 1 and (gotas[0] as ImpactoAguaToy).variante == ImpactoAguaToy.Variante.FIN, "el apagado deja gotas toy sin anillo de choque")
	_ok(vapor != null and _contar(vapor, "MultiMeshInstance3D") == 1 and _contar(vapor, "GPUParticles3D") == 0, "el apagado deja una bocanada toon por CPU")
	ReaccionesVfx3D.reproducir("prendido", gob.global_position, gob, _mundo)
	var id_gob: int = gob.get_instance_id()
	gob.queue_free()
	await process_frame
	await process_frame
	_ok(not ReaccionesVfx3D._bucles.has(id_gob), "si el goblin se libera ardiendo, el sonido en bucle se limpia solo")

	print("== Flecha ardiendo ==")
	var flecha := Node3D.new()
	flecha.set_meta("tipo", "flecha")
	_mundo.add_child(flecha)
	ReaccionesVfx3D.reproducir("prendido", Vector3.ZERO, flecha, _mundo)
	var lf: FuegoToy = flecha.get_node_or_null(VfxReaccion3D.NOMBRE_LLAMAS) as FuegoToy
	_ok(lf != null and lf.figura == FuegoToy.Figura.PILAR and not lf.viaja, "llama corta colgada de la flecha, sin modo proyectil")
	_ok(lf != null and lf.luz == 0.0, "la llama de la flecha no añade luz")
	_ok(not ReaccionesVfx3D.suena_bucle(flecha), "la flecha no usa bucle (suena una vez al prender)")
	flecha.queue_free()
	await process_frame
	_ok(not is_instance_valid(lf), "las llamas se van con la flecha")

	print("== Hundimiento con burbujas ==")
	var antes: int = _mundo.get_child_count()
	var hundi: Node3D = VfxReaccion3D.hundimiento(_mundo, Vector3(5, 0, 5), 1.0, 0.8)
	_ok(hundi != null and hundi.get_parent() == _mundo, "cuelga del mundo (no del que se hunde)")
	var salp: int = _contar(hundi, "GPUParticles3D")
	_ok(salp >= 1, "salpicadura del chapuzón al instante (%d emisores)" % salp)
	await create_timer(1.2).timeout
	var tras: int = _contar(hundi, "GPUParticles3D")
	_ok(tras > salp + 3, "las burbujas van saliendo mientras baja (%d → %d emisores)" % [salp, tras])
	var aros: int = _contar(hundi, "MeshInstance3D")
	_ok(aros >= 1, "anillos de agua que se abren (%d)" % aros)
	await create_timer(3.0).timeout
	_ok(not is_instance_valid(hundi), "todo se libera solo")

	print("== Escudo: entero, ardiendo, roto ==")
	var escudo := Node3D.new()
	escudo.set_meta("tipo", "escudo")
	_mundo.add_child(escudo)
	var n0: int = _contar(_mundo, "GPUParticles3D")
	var fg: Dictionary = ReaccionesVfx3D.reproducir("bloqueado", Vector3(0, 1, 0), escudo, _mundo)
	var n1: int = _contar(_mundo, "GPUParticles3D")
	_ok(fg["vfx"] == "escudo_golpe" and n1 - n0 == 2, "ENTERO: un golpe → destello y chispas (+%d emisores)" % (n1 - n0))
	ReaccionesVfx3D.reproducir("prendido", Vector3(0, 1, 0), escudo, _mundo)
	var le: FuegoToy = escudo.get_node_or_null(VfxReaccion3D.NOMBRE_LLAMAS) as FuegoToy
	_ok(le != null and le.get_parent() == escudo, "ARDIENDO: toy de fuego colgado del escudo")
	_ok(le != null and le.semieje_x < ancho_g, "llama de escudo más pequeña que la del goblin")
	_ok(ReaccionesVfx3D.suena_bucle(escudo), "…con su crepitar")
	var n2: int = _contar(_mundo, "GPUParticles3D")
	ReaccionesVfx3D.reproducir("consumido", Vector3(0, 1, 0), escudo, _mundo)
	var n3: int = _contar(_mundo, "GPUParticles3D")
	_ok(n3 - n2 >= 3, "ROTO: astillas y polvo (+%d emisores)" % (n3 - n2))
	_ok(not ReaccionesVfx3D.suena_bucle(escudo), "…y deja de crepitar")

	print("== Cada reacción de la plantilla deja algo en el árbol ==")
	var muestra := Node3D.new()
	_mundo.add_child(muestra)
	ReaccionesVfx3D.reproducir("prendido", Vector3.ZERO, muestra, _mundo)
	_ok(_mundo.get_children().any(func(n: Node) -> bool: return n is FuegoToy and n.figura == FuegoToy.Figura.PILAR), "prendido breve usa una llama vertical")
	var antes_mojar: int = _mundo.get_children().filter(func(n: Node) -> bool: return n is ImpactoAguaToy).size()
	ReaccionesVfx3D.reproducir("mojado", Vector3.ZERO, muestra, _mundo)
	_ok(_mundo.get_children().filter(func(n: Node) -> bool: return n is ImpactoAguaToy).size() == antes_mojar + 1, "mojado usa las gotas del toy de agua")
	for r in ReaccionesVfx3D.CATALOGO:
		var a: int = _mundo.find_children("*", "", true, false).size()
		var res: Dictionary = ReaccionesVfx3D.reproducir(r, Vector3(1, 0.5, 1), muestra, _mundo)
		var d: int = _mundo.find_children("*", "", true, false).size()
		_ok(d > a or String(res.get("vfx", "")) == "", "«%s» → dibuja algo (+%d nodos)" % [r, d - a])

	print("== Enganche a Mundo3D.reaccion ==")
	var sin := Node.new()
	_ok(not ReaccionesVfx3D.conectar(sin, _mundo), "sin la señal `reaccion` no se engancha (hoy Mundo3D no la tiene) y no falla")
	_ok(not ReaccionesVfx3D.conectar(null, _mundo), "mundo nulo: false")
	var fm := FalsoMundo.new()
	root.add_child(fm)
	_ok(ReaccionesVfx3D.conectar(fm, _mundo), "con la señal, se engancha")
	var pieza := FalsaPieza.new()
	_mundo.add_child(pieza)
	var antes2: int = _mundo.find_children("*", "", true, false).size()
	fm.reaccion.emit("mojado", Vector3(3, 0, 3), pieza)
	_ok(_mundo.find_children("*", "", true, false).size() > antes2, "emitir `reaccion` dispara el efecto sin más cableado")
	ReaccionesVfx3D.conectar(fm, _mundo)
	# 6/11 (E2): `conectar` engancha además el oyente de FeedbackReaccion3D; lo que no se debe duplicar es cada conexión, así que se cuenta por destinatario.
	var propias: int = 0
	for c in fm.get_signal_connection_list("reaccion"):
		if (c["callable"] as Callable).get_object() == ReaccionesVfx3D:
			propias += 1
	_ok(propias == 1 and fm.get_signal_connection_list("reaccion").size() == 2, "conectar dos veces no duplica la conexión (una de ReaccionesVfx3D y una de FeedbackReaccion3D)")

	print("FALLOS %d" % _fallos)
	quit(1 if _fallos > 0 else 0)

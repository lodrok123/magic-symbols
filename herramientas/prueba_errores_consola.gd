extends SceneTree
## Los tres errores de consola que salían en los playtests del 3/11 y del 4/11, provocados a propósito (5/11):
##  1. RunaSuelo3D redibujada con un solo punto: «No vertices were added, surface can't be created».
##  2. ConjuroVfx3D, forma de fuego en la mano: «Tween … started with no Tweeners».
##  3. AguaMetaballs3D con un MeshInstance3D que se libera antes de la llamada diferida: «Cannot convert argument 1 from Object to Object».
## Un Logger cuenta los errores del motor mientras dura cada caso.
## Uso: godot --headless --path . -s res://herramientas/prueba_errores_consola.gd

var _fallos: int = 0


class Contador extends Logger:
	var errores: PackedStringArray = []

	func _log_error(_funcion: String, _archivo: String, _linea: int, codigo: String, mensaje: String, _de_editor: bool, _tipo: int, _pila: Array[ScriptBacktrace]) -> void:
		errores.append("%s %s" % [codigo, mensaje])

	func _log_message(_mensaje: String, _es_error: bool) -> void:
		pass


func _comprobar(cond: bool, texto: String) -> void:
	print(("  ok  " if cond else "  FALLO  ") + texto)
	if not cond:
		_fallos += 1


func _con(contador: Contador, trozo: String) -> int:
	var n: int = 0
	for e in contador.errores:
		if e.contains(trozo):
			n += 1
	return n


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var contador := Contador.new()
	OS.add_logger(contador)

	print("-- 1. runa del suelo con un solo punto")
	var runa := RunaSuelo3D.new()
	root.add_child(runa)
	runa.empezar(Vector3.ZERO, 1.0, Color.WHITE)
	runa.trazos = [PackedVector3Array([Vector3.ZERO])]
	runa._dibujar(1.0, Color.WHITE, 1.0, 0.05, 0.0)
	await process_frame
	_comprobar(_con(contador, "No vertices were added") == 0, "sin «No vertices were added» (%d)" % _con(contador, "No vertices were added"))
	runa.trazos = [PackedVector3Array([Vector3.ZERO, Vector3(0.5, 0.0, 0.0)])]
	runa._dibujar(1.0, Color.WHITE, 1.0, 0.05, 0.0)
	var malla := runa.get_node("Lineas") as MeshInstance3D
	_comprobar(malla.mesh != null, "con un tramo sí hay malla")
	runa.queue_free()

	print("-- 2. forma de fuego en la mano")
	var vfx := ConjuroVfx3D.new()
	root.add_child(vfx)
	for el in ["fuego", "agua", "hielo"]:
		vfx.forma(el, Vector3(0, 1, 0), 0.3)
	for i in range(4):
		await process_frame
	_comprobar(_con(contador, "no Tweeners") == 0, "sin «started with no Tweeners» (%d)" % _con(contador, "no Tweeners"))
	vfx.limpiar()
	vfx.queue_free()

	print("-- 3. metaballs con una malla que se libera en el mismo fotograma")
	var mb := AguaMetaballs3D.new()
	mb.oclusion = true
	root.add_child(mb)
	await process_frame
	for i in range(5):
		var mi := MeshInstance3D.new()
		root.add_child(mi)
		mi.free()
	for i in range(3):
		await process_frame
	_comprobar(_con(contador, "Cannot convert argument") == 0, "sin «Cannot convert argument» (%d)" % _con(contador, "Cannot convert argument"))
	mb.queue_free()

	OS.remove_logger(contador)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)

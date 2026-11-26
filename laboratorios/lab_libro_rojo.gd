extends Node
## LAB DEL LIBRO ROJO (22/11, sesión HECHIZOS; PLAN_HECHIZOS §6.5). Va dentro de `laboratorios/LabLibroRojo.tscn`, que es el Bosque de pruebas con este nodo.
## Monta el libro de prueba (`LibroRojo`) en su propia capa, por encima de todo, y lo abre al empezar. L lo abre y lo cierra; con él cerrado se juega y se lanza con 1/2/3
## como siempre (el libro de siempre sigue en T). Al salir de la escena devuelve `Repertoire.libro` a como estaba (el libro rojo lo cambia a «avanzado» para combinar).

@export var abrir_al_empezar: bool = true
var libro: LibroRojo = null
var _libro_al_entrar: String = ""
## 23/11: el prototipo LANZABLE de la anidación (el segundo círculo sale cuando toca). Ver `laboratorios/prototipo_anidado.gd`.
var anidado: Node = null


func _ready() -> void:
	_libro_al_entrar = Repertoire.libro
	var capa := CanvasLayer.new()
	capa.name = "CapaLibroRojo"
	capa.layer = 20
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	libro = LibroRojo.new()
	libro.name = "LibroRojo"
	capa.add_child(libro)
	if abrir_al_empezar:
		_abrir_cuando_este_el_lanzador.call_deferred()


## Espera al lanzador y a que se levante el velo de precalentado (`Jugador3D.puede_lanzar`): abrir antes pausaba el juego con el velo puesto y ya no se levantaba.
func _abrir_cuando_este_el_lanzador() -> void:
	var lz: Node = null
	for _i in range(600):
		lz = get_tree().get_first_node_in_group("spellcaster")
		if lz != null:
			break
		await get_tree().process_frame
	if lz is Lanzador3D:
		anidado = (load("res://laboratorios/prototipo_anidado.gd") as GDScript).new()
		anidado.name = "PrototipoAnidado"
		add_child(anidado)
		anidado.call("conectar", lz)
	var jug: Node = lz.get("jugador") if lz != null else null
	var t0: int = Time.get_ticks_msec()
	while jug != null and jug.has_method("puede_lanzar") and not bool(jug.call("puede_lanzar")) and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	libro.abrir()


func _exit_tree() -> void:
	Repertoire.libro = _libro_al_entrar

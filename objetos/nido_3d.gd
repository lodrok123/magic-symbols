class_name Nido3D
extends Area3D

## NIDO (F1 de docs/PLAN_BASE_DATOS.md §3.2, 29/10; pieza nueva de Puzle3D: `; pieza <id> nido <x> <y>`). Un nido en un árbol. El VIENTO lo sacude y suelta una `pluma` al suelo (`reactivos_mapa.tsv`:
## `pluma:1`), como mucho una vez cada `cada_s` (45) s: «rebrota», no es de una sola vez. Con otro elemento no hace nada. Mientras no pasa el tiempo, el viento lo mece pero no cae nada.
##
## ASPECTO: primitivas (un cuenco de ramitas) hasta que el Pipeline dibuje la pieza `nido`; si existe `res://arte/piezas/nido.tscn` se enseña ella. No bloquea su casilla.

signal suelta

const ALTO_NIDO: float = 1.4          ## u sobre el suelo (ver Colmena3D.ALTO_COLGADA: a la altura a la que vuelan los hechizos)
const RADIO_HIT: float = 0.7
const T_DEFECTO: float = 45.0            ## s entre dos plumas si la tabla no dice otra cosa
const COLOR_RAMAS: Color = Color(0.45, 0.32, 0.2)

var celda: Vector2i = Vector2i.ZERO
var sacudidas: int = 0                   ## veces que soltó una pluma (las pruebas)
var soltado: Array = []                  ## lo último que soltó ([{que, n}])
var _ultima: float = -1000000.0          ## reloj (s) de la última pluma
var _visual: Node3D = null


func preparar(p_celda: Vector2i) -> void:
	celda = p_celda
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	add_to_group("nido")
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO_HIT
	forma.shape = esfera
	forma.position = Vector3(0.0, ALTO_NIDO, 0.0)
	add_child(forma)
	_poner_visual()


func _poner_visual() -> void:
	var ruta: String = "res://arte/piezas/nido.tscn"
	if ResourceLoader.exists(ruta):
		var n: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
		if n != null:
			n.name = "modelo"
			add_child(n)
			_visual = n
			return
	var raiz := Node3D.new()
	raiz.name = "modelo"
	var cuenco := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.32
	es.height = 0.36
	es.radial_segments = 12
	es.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR_RAMAS
	m.roughness = 0.95
	es.material = m
	cuenco.mesh = es
	cuenco.position = Vector3(0.0, ALTO_NIDO, 0.0)
	raiz.add_child(cuenco)
	add_child(raiz)
	_visual = raiz


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if Objetos.elemento_de(rune_data) == "viento":
		sacudir()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return rune_data != null and Objetos.elemento_de(rune_data) == "viento"


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## El viento lo sacude. Suelta la pluma si pasaron `cada_s` s desde la última; devuelve lo que cayó ([] si todavía no).
## `ahora` = reloj en s (-1 = el del motor; las pruebas lo pasan).
func sacudir(ahora: float = -1.0) -> Array:
	var t: float = ahora if ahora >= 0.0 else Time.get_ticks_msec() / 1000.0
	if _visual != null and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(_visual, "rotation:z", 0.12, 0.08)
		tw.tween_property(_visual, "rotation:z", -0.12, 0.12)
		tw.tween_property(_visual, "rotation:z", 0.0, 0.1)
	var fila: Dictionary = Botin.fila_reactivo("nido", "viento")
	var espera: float = float(fila.get("cada_s", 0)) if float(fila.get("cada_s", 0)) > 0.0 else T_DEFECTO
	if t - _ultima < espera:
		soltado = []
		return []
	_ultima = t
	sacudidas += 1
	soltado = Botin.desde_texto(String(fila.get("botin", "pluma:1")))
	var padre: Node3D = get_parent() as Node3D
	if padre != null:
		Botin.soltar(padre, Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)), soltado)
	suelta.emit()
	return soltado

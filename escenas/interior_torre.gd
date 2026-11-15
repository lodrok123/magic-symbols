extends "res://escenas/interior_palloza.gd"
## El mismo rellano del mundo sirve a las cinco plantas. Cada sala es una escena editable bajo Plantas.
## La visita conserva las transiciones de escalera, la audiencia y los cofres en sus plantas.
const RADIO := 3
const PUNTOS: Dictionary = {
	# 14/11: (±2, −2) caía en el muro redondo y los cofres quedaban dentro de la pared: van a los lados de Marimanta.
	"marimanta": Vector2i(0, -2),
	"cofre_uniforme": Vector2i(1, -2),
	"cofre_agua": Vector2i(-1, -2),
	"cofre_magico": Vector2i(-2, 1),
}
## 14/11 (decisión de Pablo): LA AUDIENCIA SUBE AL DESPACHO. Marimanta y sus dos cofres viven en la planta 4; el cofre mágico se queda
## en el aula, que es un servicio y no tiene sentido subirlo cuatro plantas. La casilla de cada uno no cambia (PUNTOS): cambia la planta.
## El mobiliario de aula y despacho deja libres las casillas de sus puntos.
const PLANTA_DE: Dictionary = {
	"marimanta": 4,
	"cofre_uniforme": 4,
	"cofre_agua": 4,
	"cofre_magico": 0,
}
const PLANTAS: Array = [
	{"nombre": "Torre Verde · el aula"},
	{"nombre": "Torre Verde · sala de estudio"},
	{"nombre": "Torre Verde · biblioteca"},
	{"nombre": "Torre Verde · celdas"},
	{"nombre": "Torre Verde · despacho de la Maestre"},
]

## Semiancho del tramo caminable entre las barandillas.
const MEDIO_TRAMO := 0.65
## El umbral de la puerta, solo en la planta baja (arriba el sur es muro: no se puede salir desde un piso alto).
const SALIDA_PUERTA := Vector2i(0, 3)
const SIN_SALIDA := Vector2i(0, 99)

var planta := 0
@onready var _plantas: Node3D = $Plantas
var _planta_anterior := -1
var _fov_base: float
## Lo que la visita coloca en la sala y no monta esta escena (Marimanta, el cofre del uniforme, el legendario, el cofre mágico):
## [nodo, planta en la que vive, si se veía por sí mismo]. Se registran con `registrar`, porque algunos (el cofre del uniforme) no son
## hijos de la sala y la sala no puede encontrarlos de otro modo.
var _invitados: Array = []


func montar() -> void:
	if _montada:
		return
	_montada = true
	torre = true
	entrada = Vector2i(0, 2)
	position = Terreno3D.centro_de(centro, Terreno3D.alto_suelo)
	for sala in _plantas.get_children():
		_montar_colisiones(sala)
	_construir()
	_ajustar_camara()


## Cambia de planta. Lo llama la visita entre los dos tramos del fundido.
func ir_a_planta(n: int) -> void:
	planta = clampi(n, 0, PLANTAS.size() - 1)
	_construir()


## En qué planta vive un punto de interés (`PUNTOS`).
func planta_de(sitio: String) -> int:
	return int(PLANTA_DE.get(sitio, 0))


## Apunta un nodo que la visita coloca en la sala, para esconderlo cuando no estemos en su planta.
func registrar(n: Node3D, sitio: String) -> void:
	if n == null:
		return
	_invitados.append([n, planta_de(sitio), n.visible])
	_aplicar_invitados()


func puede_subir() -> bool:
	return planta < PLANTAS.size() - 1


func puede_bajar() -> bool:
	return planta > 0


func llegada(delta: int) -> Vector3:
	var sala := _plantas.get_child(planta)
	var rellano := sala.get_node("Bajada/Llegada" if delta > 0 else "Subida/Llegada") as Marker3D
	return rellano.global_position


## El cambio ocurre al atravesar la línea de Cambio en el sentido del tramo.
func cambio_por_posicion(anterior: Vector3, actual: Vector3) -> int:
	var sala := _plantas.get_child(planta)
	if puede_subir() and _cruza(sala.get_node("Subida"), anterior, actual):
		return 1
	if puede_bajar() and _cruza(sala.get_node("Bajada"), anterior, actual):
		return -1
	return 0


func _cruza(tramo: Node3D, anterior: Vector3, actual: Vector3) -> bool:
	var inicio := tramo.get_node("Inicio") as Marker3D
	var fin := tramo.get_node("Fin") as Marker3D
	var cambio := tramo.get_node("Cambio") as Marker3D
	var eje := Vector2(fin.global_position.x - inicio.global_position.x, fin.global_position.z - inicio.global_position.z).normalized()
	var a := Vector2(anterior.x - cambio.global_position.x, anterior.z - cambio.global_position.z)
	var b := Vector2(actual.x - cambio.global_position.x, actual.z - cambio.global_position.z)
	var antes := a.dot(eje)
	var despues := b.dot(eje)
	if antes >= 0.0 or despues < 0.0:
		return false
	var cruce := a.lerp(b, -antes / (despues - antes))
	return absf(cruce.cross(eje)) <= MEDIO_TRAMO


func nombre_planta() -> String:
	return String(PLANTAS[planta]["nombre"])


## Ocultar una planta también retira sus cuerpos físicos. El mobiliario se conserva al volver a ella.
func _construir() -> void:
	salida = SALIDA_PUERTA if planta == 0 else SIN_SALIDA
	for sala in _plantas.get_children():
		var activa := sala.get_index() == planta
		sala.visible = activa
		sala.process_mode = Node.PROCESS_MODE_INHERIT if activa else Node.PROCESS_MODE_DISABLED
	_aplicar_limites()
	_registrar_tramos()
	_aplicar_invitados()


func _registrar_tramos() -> void:
	Terreno3D.rampas_acotadas.clear()
	var sala := _plantas.get_child(planta)
	for nombre in ["Subida", "Bajada"]:
		var tramo := sala.get_node_or_null(nombre)
		if tramo == null:
			continue
		var inicio := (tramo.get_node("Inicio") as Marker3D).global_position
		var fin := (tramo.get_node("Fin") as Marker3D).global_position
		inicio.y -= global_position.y
		fin.y -= global_position.y
		Terreno3D.rampas_acotadas.append({"inicio": inicio, "fin": fin, "semiancho": MEDIO_TRAMO})


func _aplicar_limites() -> void:
	# El GridMap sigue delimitando la sala. Cada planta comparte perímetro y cambia el umbral del sur.
	for z in range(-RADIO, RADIO + 1):
		for x in range(-RADIO, RADIO + 1):
			var v := Vector2i(x, z)
			var c := centro + v
			Terreno3D.liberar_celda(c)
			if v != salida and es_muro(v):
				Terreno3D.bloquear_celda_completa(c)


## Enseña a Marimanta y a los cofres solo en su planta. Al salir de su planta se apunta si se veían por sí mismos (el cofre legendario
## está oculto hasta que Marimanta recibe el trabajo) para no «encenderlos» al volver.
func _aplicar_invitados() -> void:
	for inv in _invitados:
		var n: Node3D = inv[0]
		if not is_instance_valid(n):
			continue
		var suya := int(inv[1])
		if _planta_anterior == suya and _planta_anterior != planta:
			inv[2] = n.visible
		n.visible = planta == suya and bool(inv[2])
	_planta_anterior = planta


func _ajustar_camara() -> void:
	_fov_base = camara.fov
	get_viewport().size_changed.connect(_encuadrar)
	_encuadrar()


func _encuadrar() -> void:
	var ventana := get_viewport().get_visible_rect().size
	var aspecto := ventana.x / maxf(ventana.y, 1.0)
	var ajuste := maxf(1.0, (16.0 / 9.0) / maxf(aspecto, 0.01))
	camara.fov = minf(85.0, rad_to_deg(2.0 * atan(tan(deg_to_rad(_fov_base * 0.5)) * ajuste)))


func contiene(c: Vector2i) -> bool:
	return Rect2i(centro - Vector2i(RADIO, RADIO), Vector2i(RADIO * 2 + 1, RADIO * 2 + 1)).has_point(c)


## ¿La casilla (desde `centro`) es muro o queda fuera de la sala? (lo usa la prueba para que nada se ponga dentro de la pared)
static func es_muro(v: Vector2i) -> bool:
	return maxi(absi(v.x), absi(v.y)) >= RADIO


## El punto del mundo de un sitio de la sala (`PUNTOS`).
func punto(sitio: String) -> Vector3:
	var c: Vector2i = centro + (PUNTOS[sitio] as Vector2i)
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))

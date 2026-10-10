extends Node3D
class_name Canal3D
## Canal de ruinas por el que corre el agua de la tinaja (10/10, nivel Bosque 1). Lo escribe el Pipeline.
##
## Qué hace: recibe las casillas del canal EN ORDEN (desde la que está junto a la tinaja) y las llena una a una: el agua entra
## por un borde, llega al centro y sale por el borde contrario, y la casilla siguiente empieza `retraso` segundos después de
## que la anterior termine. Sin simulación de fluidos: es solo tiempo y escala de una tira de agua (el shader de franjas es el
## de `Reactivo3D.material_caudal`, el mismo que usa la tinaja).
## Por qué cada casilla son DOS mitades (entrada → centro y centro → salida): así el codo dobla el agua sin dibujar una L.
##
## Uso (la maqueta lo hace en PruebaTest2._montar_canal; el Juego puede hacer lo mismo en sus reglas):
##   var canal := Canal3D.new()
##   add_child(canal)
##   canal.configurar([centro_0, centro_1, ...], direccion_de_entrada)   # centros en coordenadas del mundo, con la altura del suelo
##   tinaja.activado.connect(func(_t, _e): canal.llenar())
##   # al cargar una partida con el puzzle resuelto:  canal.llenar(true)
## Señales: `casilla_llena(i)` al terminar cada casilla y `lleno` al terminar la última (el puzzle se resuelve con `lleno`).

signal casilla_llena(indice: int)
signal lleno

const S: float = 2.3                       ## lado de una casilla (el de PruebaTest2.S)

## AJUSTABLES (en el inspector si el nodo se crea en el editor; en código, antes de llamar a `llenar`).
@export var retraso: float = 0.25          ## pausa en s entre que una casilla termina de llenarse y la siguiente empieza
@export var t_casilla: float = 0.7         ## s que tarda el agua en cruzar una casilla
@export var alto_agua: float = 0.15        ## altura del agua sobre el suelo de la casilla (el fondo del canal queda ~0,11; los bordes, ~0,5)
@export var ancho_agua: float = 0.6        ## ancho de la tira de agua (el hueco entre los bordes del canal recto: ~68 % de su ancho)

var llena: bool = false
var _tramos: Array = []                    ## por casilla: [mitad de entrada, mitad de salida] (Node3D pivote con la tira dentro)
var _llenando: bool = false
var _previas: Dictionary = {}              ## índices de casillas que empiezan LLENAS (marcador de canal con `lleno`): se saltan en la animación


## Casillas (índices de `configurar`) que ya tienen agua desde el principio: se ven llenas sin esperar a la tinaja y `llenar()` no
## las anima. Llamar después de `configurar`.
func marcar_llenas(indices: Array) -> void:
	for i in indices:
		var k: int = int(i)
		if k < 0 or k >= _tramos.size():
			continue
		_previas[k] = true
		for p in _tramos[k]:
			(p as Node3D).visible = true
			(p as Node3D).scale = Vector3.ONE


## `centros`: centro de cada casilla del canal en orden de llenado (Vector3 del mundo, con la altura del suelo).
## `dir_entrada`: hacia dónde fluye el agua al entrar en la primera casilla (de la tinaja hacia el canal).
## `inicio` (13/10): dónde empieza el agua de la primera casilla (donde cae el chorro de la tinaja). Sin él, en su borde.
func configurar(centros: Array, dir_entrada: Vector3, inicio: Vector3 = Vector3.INF) -> void:
	for t in _tramos:
		for p in t:
			(p as Node).queue_free()
	_tramos.clear()
	var n: int = centros.size()
	var d_ent: Vector3 = Vector3(dir_entrada.x, 0.0, dir_entrada.z).normalized()
	for i in range(n):
		var c: Vector3 = centros[i]
		var d_sal: Vector3 = d_ent
		if i + 1 < n:
			d_sal = ((centros[i + 1] as Vector3) - c)
			d_sal.y = 0.0
			d_sal = d_sal.normalized()
		var largo_ent: float = S * 0.5
		if i == 0 and inicio != Vector3.INF:
			largo_ent = maxf((c - inicio).dot(d_ent), 0.05)      # del punto donde cae el chorro al centro de la casilla
		var entrada: Node3D = _tira(c - d_ent * largo_ent, d_ent, largo_ent)
		var salida: Node3D = _tira(c, d_sal, S * 0.5 + 0.03)      # un poco más larga: tapa la unión con la siguiente
		_tramos.append([entrada, salida])
		d_ent = d_sal


func _tira(inicio: Vector3, dir: Vector3, largo: float) -> Node3D:
	var pivote := Node3D.new()
	pivote.position = inicio + Vector3(0.0, alto_agua, 0.0)
	pivote.basis = Basis.looking_at(-dir, Vector3.UP)      # su +Z mira en el sentido del agua
	var malla := PlaneMesh.new()
	malla.size = Vector2(ancho_agua, largo)
	malla.material = Reactivo3D.material_caudal(false, 2.5, 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.position = Vector3(0.0, 0.0, largo * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivote.add_child(mi)
	pivote.visible = false
	pivote.scale = Vector3(1.0, 1.0, 0.02)
	add_child(pivote)
	return pivote


## Llena el canal casilla a casilla. Una sola vez. `instantaneo`: lo deja lleno ya (cargar partida).
func llenar(instantaneo: bool = false) -> void:
	if _llenando or llena:
		return
	_llenando = true
	var tiempo: float = 0.0 if instantaneo else maxf(t_casilla * 0.5, 0.01)
	var tw: Tween = create_tween()
	for i in range(_tramos.size()):
		if _previas.has(i):
			tw.tween_callback(casilla_llena.emit.bind(i))        # ya estaba llena: sin animación ni pausa
			continue
		for p in _tramos[i]:
			var pivote: Node3D = p
			tw.tween_callback(pivote.set_visible.bind(true))
			if instantaneo:
				pivote.scale = Vector3.ONE
			else:
				tw.tween_property(pivote, "scale", Vector3.ONE, tiempo).set_trans(Tween.TRANS_LINEAR)
		tw.tween_callback(casilla_llena.emit.bind(i))
		if not instantaneo and i + 1 < _tramos.size():
			tw.tween_interval(retraso)
	tw.tween_callback(_terminar)


## 13/10: las dos mitades de agua de la casilla `i` (pivotes con +Z en el sentido del agua) y su largo: para poner encima
## lo que siga al agua (las chispas del agua electrificada). [[pivote, largo], [pivote, largo]].
func mitades(i: int) -> Array:
	var res: Array = []
	if i < 0 or i >= _tramos.size():
		return res
	for p in _tramos[i]:
		var pv: Node3D = p
		var mi: MeshInstance3D = pv.get_child(0) as MeshInstance3D
		res.append([pv, (mi.mesh as PlaneMesh).size.y])
	return res


func _terminar() -> void:
	llena = true
	lleno.emit()

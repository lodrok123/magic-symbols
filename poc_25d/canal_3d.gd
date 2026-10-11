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
@export var prolongar_inicio: float = 0.3  ## 11/10: cuánto se alarga el agua de la primera tira hacia atrás, más allá de donde cae el chorro (le da cuerpo al pie del chorro); esa parte aparece desde cero
@export var desv_final: float = 0.6       ## fracción de la última tira en la que el agua se desvanece (el río entra en el lago, sin cortarse en seco)
@export var frecuencia_franjas: float = 2.6  ## franjas por unidad de largo: igual en todas las tiras para que no haya salto en las juntas
## 11/10 (Pablo: «toda esa área debería tener agua»): la primera pieza del canal es un codo con una CÁMARA más ancha que la tira de agua
## (el suelo de piedra al fondo, detrás del codo). Las tiras solo cubren el paso del agua y la cámara se veía seca. Se rellena con dos
## rectángulos de agua en el lado EXTERIOR del giro (medidas desde el centro de la casilla, en unidades del mundo, medidas sobre la pieza).
@export var bahia_atras: float = 0.62      ## hasta dónde llega la cámara por detrás del codo (el lado de por donde entra el agua)
@export var bahia_delante: float = 0.47    ## y por delante (hacia donde sigue el agua de entrada)
@export var bahia_fondo: float = 0.86      ## cuánto se adentra hacia el lado exterior del giro (hasta la pared)

var llena: bool = false
var _tramos: Array = []                    ## por casilla: [mitad de entrada, mitad de salida] (Node3D pivote con la tira dentro)
var _llenando: bool = false
var _extra: Dictionary = {}                ## casilla -> rellenos de agua (la cámara del codo inicial): se llenan con su casilla, pero no cuentan como «mitad»
var _previas: Dictionary = {}              ## índices de casillas que empiezan LLENAS (marcador de canal con `lleno`): se saltan en la animación


## Casillas (índices de `configurar`) que ya tienen agua desde el principio: se ven llenas sin esperar a la tinaja y `llenar()` no
## las anima. Llamar después de `configurar`.
func marcar_llenas(indices: Array) -> void:
	for i in indices:
		var k: int = int(i)
		if k < 0 or k >= _tramos.size():
			continue
		_previas[k] = true
		for p in _tramos[k] + (_extra.get(k, []) as Array):
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
	for e in _extra.values():
		for p in e:
			(p as Node).queue_free()
	_extra.clear()
	var n: int = centros.size()
	var d_ent: Vector3 = Vector3(dir_entrada.x, 0.0, dir_entrada.z).normalized()
	var recorrido: float = 0.0          ## lo que lleva recorrido el agua: es la fase de las franjas de cada tira
	var k: int = 0                      ## orden de la tira: cada una queda 0,5 mm más alta que la anterior (donde se solapan en un codo gana la siguiente, sin parpadeo)
	for i in range(n):
		var c: Vector3 = centros[i]
		var d_sal: Vector3 = d_ent
		if i + 1 < n:
			d_sal = ((centros[i + 1] as Vector3) - c)
			d_sal.y = 0.0
			d_sal = d_sal.normalized()
		# Las tiras se juntan en el PUNTO MEDIO entre dos centros consecutivos (no a S/2 del centro): los marcadores del canal no
		# están en la rejilla (el editor los deja donde quieras: aquí los centros distan ~2,0 y no 2,3) y con S/2 las tiras se
		# solapaban (raya clara por la doble transparencia) o dejaban hueco. Con el punto medio encajan siempre.
		var largo_ent: float = S * 0.5
		if i > 0:
			largo_ent = ((centros[i] as Vector3) - (centros[i - 1] as Vector3)).length() * 0.5
		var prolonga: float = 0.0
		if i == 0 and inicio != Vector3.INF:
			largo_ent = maxf((c - inicio).dot(d_ent), 0.05)      # del punto donde cae el chorro al centro de la casilla
			prolonga = prolongar_inicio                          # y un poco más atrás (la cola del pie del chorro)
			largo_ent += prolonga
		var ultima: bool = i + 1 == n
		var largo_sal: float = S * 0.5          # la última acaba en el borde de su casilla
		if not ultima:
			largo_sal = ((centros[i + 1] as Vector3) - c).length() * 0.5
		var entrada: Node3D = _tira(c - d_ent * largo_ent, d_ent, largo_ent, recorrido, prolonga / largo_ent, 0.0, k)
		recorrido += largo_ent
		k += 1
		# La última se desvanece, para que el río entre en el lago sin corte seco.
		var salida: Node3D = _tira(c, d_sal, largo_sal, recorrido, 0.0, desv_final if ultima else 0.0, k)
		recorrido += largo_sal
		k += 1
		_tramos.append([entrada, salida])
		if i == 0 and not ultima and d_sal.dot(d_ent) < 0.5:
			_extra[0] = _bahia(c, d_ent, d_sal, recorrido, k)
		d_ent = d_sal


func _tira(inicio: Vector3, dir: Vector3, largo: float, fase: float = 0.0, desv_ini: float = 0.0, desv_fin: float = 0.0, orden: int = 0, ancho: float = -1.0) -> Node3D:
	var pivote := Node3D.new()
	pivote.position = inicio + Vector3(0.0, alto_agua + 0.0005 * float(orden), 0.0)
	pivote.basis = Basis.looking_at(-dir, Vector3.UP)      # su +Z mira en el sentido del agua
	var malla := PlaneMesh.new()
	malla.size = Vector2(ancho_agua if ancho < 0.0 else ancho, largo)
	var mat: ShaderMaterial = Reactivo3D.material_caudal(false, 2.5, frecuencia_franjas)
	mat.set_shader_parameter("largo", largo)
	mat.set_shader_parameter("fase", fase)
	mat.set_shader_parameter("desv_ini", desv_ini)
	mat.set_shader_parameter("desv_fin", desv_fin)
	malla.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.position = Vector3(0.0, 0.0, largo * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivote.add_child(mi)
	pivote.visible = false
	pivote.scale = Vector3(1.0, 1.0, 0.02)
	add_child(pivote)
	return pivote


## Relleno de la cámara del codo inicial: dos rectángulos en el lado exterior del giro (el lado contrario al de la salida). `a` = sentido
## de entrada, `o` = lado exterior. El grande va pegado a la tira de entrada y llega hasta la pared; el pequeño tapa el rincón que
## queda entre el centro del codo y la pared de delante. Cada uno crece desde la tira hacia fuera, como si el agua se desbordase a la cámara.
func _bahia(c: Vector3, d_ent: Vector3, d_sal: Vector3, fase: float, orden: int) -> Array:
	var o: Vector3 = -d_sal
	var m: float = ancho_agua * 0.5
	var ancho_a: float = bahia_atras + bahia_delante
	var gran: Node3D = _tira(c + o * m + d_ent * ((bahia_delante - bahia_atras) * 0.5), o, bahia_fondo - m, fase, 0.0, 0.0, orden, ancho_a)
	# El rincón: entre el centro del codo y la pared de delante, en el lado exterior (ni la tira de entrada, que acaba en el centro, ni la
	# de salida, que va por el lado interior, lo cubren).
	var rincon: Node3D = _tira(c + d_ent * (bahia_delante * 0.5), o, m + 0.03, fase, 0.0, 0.0, orden, bahia_delante)      # +0,03 de solape: sin él queda una raya seca entre los dos
	return [gran, rincon]


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
		for p in (_extra.get(i, []) as Array):          # el relleno de la cámara crece a la vez que la mitad de salida
			var relleno: Node3D = p
			tw.tween_callback(relleno.set_visible.bind(true))
			if instantaneo:
				relleno.scale = Vector3.ONE
			else:
				tw.parallel().tween_property(relleno, "scale", Vector3.ONE, tiempo).set_trans(Tween.TRANS_LINEAR)
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


## 11/10: los rellenos de agua de la casilla `i` (la cámara del codo inicial), para poner encima las chispas del agua electrificada:
## [[pivote, largo, ancho], ...]. Vacío si la casilla no tiene relleno.
func rellenos(i: int) -> Array:
	var res: Array = []
	for p in (_extra.get(i, []) as Array):
		var pv: Node3D = p
		var mi: MeshInstance3D = pv.get_child(0) as MeshInstance3D
		var tam: Vector2 = (mi.mesh as PlaneMesh).size
		res.append([pv, tam.y, tam.x])
	return res


func _terminar() -> void:
	llena = true
	lleno.emit()

class_name ContadorReactivos3D
extends Node3D

## CONTADOR DE REACTIVOS (Fase 14.6 · laboratorio de fuego, F1 «enciende las cuatro antorchas», 16/10, Juego). Cuenta cuántos objetos de
## una lista están ENCENDIDOS (`is_lit`: braseros, fogatas, setos que arden, cuerdas…) y avisa cuando están todos, o los que se pidan.
## Es el detector del fuego, igual que NivelAgua3D lo es del agua: no abre nada, solo avisa; quien lo escucha (una regla de Puzle3D) decide.
##
## Señales:
##   todos(si)               cambia «¿están los pedidos?». `si = true` al llegar a `minimo`, `false` al bajar de él. No sale al nacer.
##   cambio(encendidos, total)   cada vez que cambia la cuenta (para el rótulo y el HUD).
## Lectura (no hace falta señal para consultarlo): `encendidos`, `total`, `minimo`, `completo`.
##
## Cómo lee: cada fotograma, `is_lit` de cada nodo de la lista. Un nodo liberado (un seto consumido) cuenta como apagado. No hay
## señal que escuchar porque `is_lit` no tiene una común a todos los tipos (un seto no emite `llama`, un brasero sí), y son cuatro o
## cinco lecturas por fotograma.
## Rótulo flotante «ENCENDIDAS 2/4» sobre su casilla (solo si `preparar` recibe una casilla): es lo que ve el jugador.
## Qué NO hace: no enciende nada ni mira el agua; una lista vacía no está nunca completa.

signal todos(si: bool)
signal cambio(encendidos: int, total: int)

const ALTO_ROTULO: float = 1.8
const ALTO_ROTULO_PLACA: float = 0.85    ## el rótulo sobre la placa (mide 0,5 de alto)
const GEMAS_PLACA: int = 4                ## huecos que tiene el modelo de la placa
const COLOR_FALTAN: Color = Color(1.0, 0.85, 0.6)
const COLOR_TODOS: Color = Color(0.6, 1.0, 0.65)

var lista: Array = []                       ## los nodos que se cuentan (cada uno con `is_lit`)
var minimo: int = 0                         ## cuántos hacen falta (por defecto, todos)
var celda: Vector2i = Vector2i(-1, -1)
var encendidos: int = 0
var completo: bool = false
var _rotulo: Label3D = null
var _placa: PiezaFuego3D = null             ## la placa con huecos del Pipeline (`contador_placa`); null si no hay modelo o no hay casilla


## `p_lista`: los nodos a contar. `p_minimo`: 0 = todos. `p_celda`: donde se cuelga el rótulo (x < 0 = sin rótulo, para las pruebas).
func preparar(p_lista: Array, p_minimo: int = 0, p_celda: Vector2i = Vector2i(-1, -1)) -> void:
	lista = p_lista.duplicate()
	minimo = p_minimo if p_minimo > 0 else lista.size()
	celda = p_celda
	if celda.x >= 0:
		position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo)


func _ready() -> void:
	if celda.x >= 0:
		_rotulo = Label3D.new()
		_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_rotulo.font_size = 28
		_rotulo.outline_size = 8
		_rotulo.pixel_size = 0.005
		_rotulo.position = Vector3(0.0, ALTO_ROTULO, 0.0)
		add_child(_rotulo)
		# La placa con huecos y gemas del Pipeline (diario 108); sin su modelo no se pone nada y queda solo el rótulo, como antes.
		# El rótulo se queda (dice el número exacto, también con más de 4 reactivos) pero baja a ras de la placa.
		if PiezaFuego3D.usar_modelos and PiezaFuego3D.hay_modelo("contador_placa"):
			_placa = PiezaFuego3D.crear("contador_placa")
			add_child(_placa)
			_rotulo.position = Vector3(0.0, ALTO_ROTULO_PLACA, 0.0)
	_leer(false)
	set_process(true)


func total() -> int:
	return lista.size()


## Cuántos de la lista arden ahora mismo.
func contar() -> int:
	var n: int = 0
	for o in lista:
		if is_instance_valid(o) and bool(o.get("is_lit")):
			n += 1
	return n


func _process(_delta: float) -> void:
	_leer(true)


func _leer(avisar: bool) -> void:
	var n: int = contar()
	var ahora: bool = lista.size() > 0 and n >= minimo
	if n != encendidos:
		encendidos = n
		if avisar:
			cambio.emit(encendidos, lista.size())
		_pintar()
	if ahora != completo:
		completo = ahora
		_pintar()
		if avisar:
			todos.emit(completo)


func _pintar() -> void:
	if _placa != null:
		# Una gema por reactivo hasta 4; con más reactivos que huecos, la parte proporcional.
		var de: int = mini(maxi(minimo, 1), GEMAS_PLACA)
		_placa.poner_cuenta(int(floor(float(mini(encendidos, maxi(minimo, 1))) * de / float(maxi(minimo, 1)))), de)
	if _rotulo == null:
		return
	_rotulo.text = "ENCENDIDAS %d/%d" % [encendidos, minimo]
	_rotulo.modulate = COLOR_TODOS if completo else COLOR_FALTAN

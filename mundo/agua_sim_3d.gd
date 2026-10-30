extends RefCounted
class_name AguaSim3D
## AGUA CON VOLUMEN (Fase 11, 12/10). Lo escribe el Juego; el dibujo es del Pipeline (lee `imagen()` / `textura()`).
##
## Qué es: el agua deja de ser una letra «~» con un plano encima y pasa a ser una CANTIDAD por trocito de suelo que se
## mueve sola: baja por las pendientes, llena los huecos hasta el borde, se nivela, se para contra la tierra y el hielo, y
## sigue la corriente. Modelo de «tuberías virtuales» (O'Brien y Hodgins 1995; Mei, Decaudin y Hu, «Fast Hydraulic Erosion
## Simulation and Visualization on GPU», 2007): cada trocito empuja agua a sus 4 vecinos según la diferencia de ALTURA DE
## SUPERFICIE (suelo + agua), con un poco de inercia. Es lo mínimo que da las tres cosas que pidió Pablo: que llenarse sea de
## verdad, que el agua ocupe su sitio (un hoyo se llena hasta el borde y no más) y que se note como un fluido (sale con
## fuerza, rebosa, se calma).
##
## Por qué este modelo y no partículas (EasyFluidSim) ni el océano por FFT (Godot-RealisticEnvironments):
##   - Partículas: dan salpicaduras bonitas pero no un nivel de agua que el juego pueda preguntar («¿esta casilla es agua?»,
##     «¿cuánta?»). Se quedan para el DIBUJO de chorros y salpicaduras (Pipeline).
##   - FFT/iWave: olas de mar abierto, cómputo en GPU y Godot 4.8. Aquí el agua es poca y está en casillas.
##   - Tuberías: el estado es una rejilla de números (se guarda, se mide y se prueba en headless), conserva el volumen
##     exactamente y es estable con cualquier paso de tiempo gracias al recorte K (no puede salir más agua de la que hay).
##
## Escala: la rejilla del agua es más fina que la de juego: `sub` × `sub` trocitos por casilla de 2,3 u (sub = 3 → 0,77 u).
## El juego sigue preguntando por CASILLAS (`profundidad_casilla`, `es_agua_casilla`); el dibujo usa los trocitos.
##
## Uso (el Lanzador o las reglas del nivel):
##   var agua := AguaSim3D.new()
##   agua.configurar(ancho, alto, 3, 2.3, func(c): return y_del_suelo(c), func(c): return es_pared(c))
##   agua.llenar_casilla(c, y_superficie)       # el río del mapa al arrancar
##   agua.fuente_en(c, 0.6)                      # surtidor: 0,6 u³/s mientras no se quite
##   agua.anadir(pos_mundo, volumen, radio)      # hechizo de agua
##   agua.quitar(pos_mundo, volumen, radio)      # fuego que evapora
##   agua.helar_casilla(c, true)                 # hielo: el agua se queda quieta
##   agua.solidificar_casilla(c, true)           # bloque de tierra: tapa y aparta el agua
##   en _physics_process: agua.paso(delta); for cambio in agua.cambios(): ...   # casillas que pasan a agua / a seco
##
## Unidades: las del mundo (u). Volumen en u³. Caudal en u³/s. Alturas en Y del mundo.

## --- Ajustables ---
const G: float = 9.8                    ## gravedad de las tuberías. Más alta = el agua corre más rápido
const AMORTIGUA: float = 0.74           ## lo que queda del caudal tras 1 s sin empuje (1 = sin rozamiento). Baja → se calma antes
const PASO_FIJO: float = 1.0 / 30.0     ## la simulación avanza en pasos fijos (30 por segundo) aunque los fotogramas no lo sean
const MAX_PASOS: int = 4                ## si un fotograma tarda mucho no se intentan más de estos pasos (evita la espiral)
const PROF_MIN: float = 0.0005          ## por debajo de esto un trocito está seco
const PROF_CHARCO: float = 0.03         ## agua tan fina que el suelo la absorbe (deja la casilla «mojada»)
const RETIENE: float = 0.03             ## lámina que el suelo retiene y no corre (tensión superficial, en pequeño). Sin esto
                                        ## un manantial se extiende en una película de milímetros por todo un llano y el suelo
                                        ## se la bebe entera: el agua no llega a ningún sitio (medido en el laboratorio, 12/10)
const ABSORBE: float = 0.02             ## u por segundo que el suelo se bebe de una lámina fina
const UMBRAL_AGUA: float = 0.25         ## profundidad media (u) a partir de la cual una CASILLA es agua para el juego
const UMBRAL_NADO: float = 0.55         ## y a partir de la cual se nada
const DURA_HIELO: float = 20.0          ## s que dura el hielo de un hechizo si nadie lo funde antes (11.12)
const SECA_EN: float = 20.0             ## s que tarda en secarse un trocito desde que se queda sin agua (estado «mojado»)
## --- W0 (19/10, PLAN_TRES_FRENTES §3): lo que el dibujo necesita y la simulación no exponía. NO cambian el agua: solo la describen. ---
const UMBRAL_CAIDA: float = 0.5         ## u de salto de superficie entre un trocito y el vecino al que le corre agua a partir del cual es CASCADA (un nivel de tierra = 1,035 u)
const MAX_RECIPIENTE: int = 20000       ## trocitos que explora `recipiente` antes de darlo por «abierto» (sin fondo: un llano, el mar)
const EVENTO_ENTRA: int = 1             ## entra agua (hechizo de agua, cubo que se vuelca)
const EVENTO_HIELO_ROTO: int = 2        ## un trocito de hielo se suelta (por tiempo o por fuego)
const EVENTO_EVAPORA: int = 3           ## el fuego quita agua
const EVENTO_HIELA: int = 4             ## un hechizo de hielo hiela agua
const VOLUMEN_EVENTO_REF: float = 1.0   ## u³ que dan intensidad 1 a un evento de entrada
const VIDA_EVENTO: float = 1.0          ## s que un evento sin consumir sigue contando (el dibujo debe leerlos antes; después se tiran)

var ancho: int = 0                      ## en casillas
var alto: int = 0
var sub: int = 3                        ## trocitos por lado de casilla
var lado_casilla: float = 2.3
var l: float = 2.3 / 3.0                ## lado de un trocito (u)
var w: int = 0                          ## trocitos de ancho (ancho * sub)
var h: int = 0

var suelo := PackedFloat32Array()       ## Y del suelo por trocito
var prof := PackedFloat32Array()        ## profundidad del agua por trocito (u)
var caudal := PackedFloat32Array()      ## 4 por trocito: 0 izquierda (-x), 1 derecha (+x), 2 arriba (-z), 3 abajo (+z); u³/s
var cerrado := PackedByteArray()        ## 1 = pared o tierra (no hay agua ni pasa)
var helado := PackedByteArray()         ## 1 = hielo (el agua está pero no se mueve). Por TROCITO (11.12)
var hielo_t := PackedFloat32Array()     ## segundos que le quedan al hielo del trocito (al llegar a 0 se suelta solo)
var hielo_ini := PackedFloat32Array()   ## segundos con los que se heló: sirve para saber qué fracción le queda (textura_hielo)
var fijo := PackedFloat32Array()        ## Y de superficie que se mantiene (río que no se vacía); -INF = no
var fuente := PackedFloat32Array()      ## u³/s que entran en el trocito
var mojado := PackedFloat32Array()      ## segundos que le quedan al trocito para secarse (0 = seco); estado «mojado» del suelo
var vecinos := PackedInt32Array()       ## 4 por trocito, el índice del vecino o -1 (borde); se calcula una vez

var _acumulado: float = 0.0
var _rampas: Array = []                 ## manantiales que suben poco a poco: [{c: Vector2i, v: u³/s ganados por segundo, t: s que faltan}]
var _topes: Dictionary = {}             ## Vector2i -> u³ que le quedan por echar a un manantial FINITO (una tinaja): al llegar a 0 se apaga
var _agotadas: Array = []               ## casillas cuyo manantial finito se ha agotado desde la última vez que alguien preguntó
var _x0: int = 0                        ## caja (en trocitos) donde hay agua, fuentes o suelo mojado; vacía si _x1 < _x0
var _x1: int = -1
var _y0: int = 0
var _y1: int = -1
var _trabajo := Rect2i()                 ## la caja (con margen) que recorrió el último paso: allí puede haber cambiado algo
var _era_agua := PackedByteArray()      ## por casilla: 1 si en el último aviso era agua
var _cambios: Array = []                ## [{c: Vector2i, agua: bool}] desde la última llamada a cambios()
var _img: Image = null
var _tex: ImageTexture = null
var _hielo_vivo: bool = false           ## ¿hubo hielo desde la última imagen? Si no, textura_hielo no recorre nada
var _hielo_sucias: Dictionary = {}      ## casillas cuyo hielo ha cambiado desde la última llamada a cambios_hielo()
var _hielo_estado := PackedByteArray()  ## por casilla: 1 si en el último aviso estaba helada
var _tex_hielo: ImageTexture = null
var _eventos: Dictionary = {}           ## trocito -> Vector3(tipo, intensidad 0..1, instante): lo último que pasó ahí (uno por trocito: el último gana)
var _t: float = 0.0                     ## segundos de simulación (para la vida de los eventos)
var _img_eventos: Image = null
var _tex_eventos: ImageTexture = null
var _img_eventos_vacia: bool = false
var _tex_caida: ImageTexture = null
var _img_hielo: Image = null
var _estrechos: Dictionary = {}         ## Vector2i -> Array de Vector2i: casillas «estrechas» (canal) y los lados que abren; ver abrir_solo
var _formas: Dictionary = {}            ## Vector2i -> Array de Vector2i: los trocitos (sx, sy) que quedan abiertos en una casilla de forma libre; ver abrir_trocitos
var _suelo_de: Callable
var _pared_de: Callable


## Prepara la rejilla. `suelo_y(c: Vector2i) -> float` da la Y del suelo de una casilla; `pared(c) -> bool` si no deja pasar
## agua (árboles del borde, muros, rocas). Se leen una vez; si cambian, `refrescar_casilla(c)`.
func configurar(p_ancho: int, p_alto: int, p_sub: int, p_lado: float, suelo_y: Callable, pared: Callable) -> void:
	ancho = p_ancho
	alto = p_alto
	sub = maxi(1, p_sub)
	lado_casilla = p_lado
	l = lado_casilla / float(sub)
	w = ancho * sub
	h = alto * sub
	var n: int = w * h
	suelo.resize(n)
	prof.resize(n)
	prof.fill(0.0)
	caudal.resize(n * 4)
	caudal.fill(0.0)
	cerrado.resize(n)
	cerrado.fill(0)
	helado.resize(n)
	helado.fill(0)
	hielo_t.resize(n)
	hielo_t.fill(0.0)
	hielo_ini.resize(n)
	hielo_ini.fill(0.0)
	_hielo_estado.resize(ancho * alto)
	_hielo_estado.fill(0)
	_hielo_sucias.clear()
	_hielo_vivo = false
	_estrechos.clear()
	_formas.clear()
	_rampas.clear()
	fijo.resize(n)
	fijo.fill(-INF)
	fuente.resize(n)
	fuente.fill(0.0)
	mojado.resize(n)
	mojado.fill(0.0)
	vecinos.resize(n * 4)
	for i in range(n):
		for k in range(4):
			vecinos[i * 4 + k] = _vecino(i % w, i / w, k)
	_x0 = w
	_x1 = -1
	_y0 = h
	_y1 = -1
	_era_agua.resize(ancho * alto)
	_era_agua.fill(0)
	_suelo_de = suelo_y
	_pared_de = pared
	for cy in range(alto):
		for cx in range(ancho):
			refrescar_casilla(Vector2i(cx, cy))


## Vuelve a leer el suelo y la pared de una casilla (al levantar o deshacer tierra, al romper un muro…).
func refrescar_casilla(c: Vector2i) -> void:
	if not _dentro_casilla(c):
		return
	var y: float = float(_suelo_de.call(c)) if _suelo_de.is_valid() else 0.0
	var es_pared: bool = bool(_pared_de.call(c)) if _pared_de.is_valid() else false
	for i in _trozos(c):
		suelo[i] = y
		_poner_cerrado(i, es_pared)
	if not es_pared and _estrechos.has(c):
		_aplicar_estrecho(c)                     # un canal sigue siendo estrecho aunque se vuelva a leer su suelo


## --- Lo que el juego hace al agua ---

## Pone agua en una casilla hasta la superficie `y_sup` (el río del mapa al arrancar). No toca las paredes.
func llenar_casilla(c: Vector2i, y_sup: float) -> void:
	for i in _trozos(c):
		if cerrado[i] == 0:
			prof[i] = maxf(0.0, y_sup - suelo[i])
			_incluir(i)
	_avisar_casilla(c)


## Mantiene la superficie de esa casilla en `y_sup` (un río que entra y sale del nivel no se vacía). NAN/-INF lo quita.
func fijar_nivel(c: Vector2i, y_sup: float) -> void:
	for i in _trozos(c):
		fijo[i] = y_sup
		_incluir(i)


## Deja una casilla como CANAL ESTRECHO (12/10, canal de la tinaja): abiertos solo el trocito central y, por cada lado `d` de
## `lados` (Vector2i: (1,0), (-1,0), (0,1), (0,-1)), el trocito del borde de ese lado; los demás se cierran. Con sub = 3 son
## (1,1) y (1,1)+d. POR QUÉ: el canal de piedra tiene un cajón estrecho de ~0,8 u, no ocupa la casilla entera; con los 9 trocitos
## abiertos el agua se extendía por toda ella y la lámina quedaba a 0,13 u, por debajo del borde de la pieza. Estrecho, el agua
## sube a la altura de la piedra y solo sale por los lados que la pieza abre.
## `aplicar = false` solo RECUERDA la forma (para cuando el canal está sellado y aún no se abre): la forma se aplica la próxima vez
## que la casilla se abra (`solidificar_casilla(c, false)`) o se relea (`refrescar_casilla`). El agua que hubiera en los trocitos
## que se cierran se reparte entre los abiertos (lo hace `_poner_cerrado`).
func abrir_solo(c: Vector2i, lados: Array, aplicar: bool = true) -> void:
	if not _dentro_casilla(c):
		return
	_estrechos[c] = lados.duplicate()
	if aplicar:
		_aplicar_estrecho(c)


## 24/10 (cascada de C2 con pilares): como `abrir_solo` pero eligiendo QUÉ trocitos (sx, sy; 0..sub-1) quedan abiertos, no «el central y los de los lados». Así una casilla puede abrir sus
## tercios de los extremos y cerrar el del medio (un pilar de roca entre dos cortinas). Los demás se cierran; `aplicar = false` solo recuerda la forma (ver `abrir_solo`).
func abrir_trocitos(c: Vector2i, trocitos: Array, aplicar: bool = true) -> void:
	if not _dentro_casilla(c):
		return
	_estrechos[c] = []
	_formas[c] = trocitos.duplicate()
	if aplicar:
		_aplicar_estrecho(c)


## Vuelve a ser una casilla normal (los 9 trocitos según su pared).
func quitar_estrecho(c: Vector2i) -> void:
	_estrechos.erase(c)
	_formas.erase(c)
	refrescar_casilla(c)


func _aplicar_estrecho(c: Vector2i) -> void:
	var lados: Array = _estrechos.get(c, [])
	var m: int = sub / 2
	var abiertos := {}
	if _formas.has(c):
		for q in (_formas[c] as Array):
			abiertos[q] = true
		lados = []
	else:
		abiertos[Vector2i(m, m)] = true
	for d in lados:
		var q: Vector2i = Vector2i(m, m) + (d as Vector2i)
		if q.x >= 0 and q.y >= 0 and q.x < sub and q.y < sub:
			abiertos[q] = true
	for sy in range(sub):
		for sx in range(sub):
			var i: int = (c.y * sub + sy) * w + c.x * sub + sx
			_poner_cerrado(i, not abiertos.has(Vector2i(sx, sy)))


## Los trocitos de la casilla que NO están cerrados (en una casilla normal, los 9; en un canal estrecho, los suyos).
func _trozos_abiertos(c: Vector2i) -> PackedInt32Array:
	var r := PackedInt32Array()
	for i in _trozos(c):
		if cerrado[i] == 0:
			r.append(i)
	return r


## Un manantial: `caudal_u3s` u³/s repartidos por los trocitos ABIERTOS de la casilla (0 lo apaga). Si no hay ninguno abierto
## (casilla sellada) se reparte entre todos, como antes.
func fuente_en(c: Vector2i, caudal_u3s: float) -> void:
	var t: PackedInt32Array = _trozos_abiertos(c)
	if t.is_empty():
		t = _trozos(c)
	for i in t:
		fuente[i] = caudal_u3s / float(t.size())
		_incluir(i)


## SUMA `delta_u3s` u³/s al manantial de la casilla (negativo = resta). A diferencia de `fuente_en`, no pisa lo que ya había:
## un chorro de agua sobre el surtidor o sobre un río suma su caudal y, al acabar, lo retira sin apagar el de los demás.
func sumar_fuente(c: Vector2i, delta_u3s: float) -> void:
	var t: PackedInt32Array = _trozos_abiertos(c)       # solo los abiertos: en un canal estrecho el agua no cabe en los cerrados
	if t.is_empty():
		t = _trozos(c)
	for i in t:
		var q: float = fuente[i] + delta_u3s / float(t.size())
		fuente[i] = 0.0 if absf(q) < 1.0e-6 else maxf(q, 0.0)    # sin restos que mantengan viva la caja de trabajo
		_incluir(i)


## Como `sumar_fuente`, pero el caudal SUBE de 0 a `delta_u3s` en `segundos` s (15/10, Pablo: la tinaja llenaba el canal «muy rápido»).
## La subida es una curva suave (smootherstep): empieza goteando, acelera en el medio y llega al caudal final SIN esquina (pendiente 0 en los dos
## extremos). Con una rampa lineal el frente del agua avanzaba a tirones al cambiar de régimen; así el canal se llena como una tubería que se abre
## poco a poco (15/10, Pablo: «el detalle no es que sea más lento sino cómo se rellena»).
## POR QUÉ aquí y no con un temporizador del árbol: la simulación avanza por sus pasos fijos; así el arranque va con ella (y con las
## pruebas sin ventana, que la mueven a mano). Pasados `segundos`, el manantial queda echando `delta_u3s` fijo hasta que se cierre.
func sumar_fuente_gradual(c: Vector2i, delta_u3s: float, segundos: float) -> void:
	if segundos <= 0.0:
		sumar_fuente(c, delta_u3s)
		return
	_rampas.append({"c": c, "q": delta_u3s, "T": segundos, "t": 0.0})


## CIERRA el manantial de una casilla del todo (15/10, lab de puzles de agua: «cerrar el grifo» de la tinaja): pone a 0 lo que echa y
## retira las rampas que aún estuvieran subiéndolo. `fuente_en(c, 0)` solo no basta: una rampa en marcha seguiría sumando.
func apagar_fuente(c: Vector2i) -> void:
	var i: int = _rampas.size() - 1
	while i >= 0:
		if (_rampas[i] as Dictionary)["c"] == c:
			_rampas.remove_at(i)
		i -= 1
	fuente_en(c, 0.0)


## Hace FINITO el manantial de una casilla (15/10, tinaja con volumen): echará como mucho `volumen_u3` más y entonces se apaga solo
## (`apagar_fuente`), rampa incluida. Se cuenta con el caudal REAL de cada paso, así que vale igual con `fuente_en` que con
## `sumar_fuente_gradual`. Volumen ≤ 0 quita el tope (manantial infinito, como antes). Lo que se agota se lee con `fuentes_agotadas()`.
func limitar_fuente(c: Vector2i, volumen_u3: float) -> void:
	if volumen_u3 <= 0.0:
		_topes.erase(c)
	else:
		_topes[c] = volumen_u3


## u³ que le quedan al manantial finito de la casilla (INF si no tiene tope, 0 si ya se agotó o no hay).
func volumen_restante(c: Vector2i) -> float:
	return float(_topes[c]) if _topes.has(c) else INF


## Lo que echa ahora mismo el manantial de la casilla (u³/s, sumando sus trocitos).
func caudal_en(c: Vector2i) -> float:
	var q: float = 0.0
	for i in _trozos(c):
		q += fuente[i]
	return q


## Casillas cuyo manantial finito se agotó desde la última llamada (y se vacía la lista), como `cambios()`.
func fuentes_agotadas() -> Array:
	var r: Array = _agotadas.duplicate()
	_agotadas.clear()
	return r


func _gastar_topes(dt: float) -> void:
	for c in _topes.keys():
		var gasto: float = caudal_en(c) * dt
		if gasto <= 0.0:
			continue
		var queda: float = float(_topes[c]) - gasto
		if queda <= 0.0:
			_topes.erase(c)
			apagar_fuente(c)
			_agotadas.append(c)
		else:
			_topes[c] = queda


func _avanzar_rampas(dt: float) -> void:
	var i: int = _rampas.size() - 1
	while i >= 0:
		var r: Dictionary = _rampas[i]
		var T: float = float(r["T"])
		var t0: float = float(r["t"])
		var t1: float = minf(t0 + dt, T)
		# `sumar_fuente` SUMA al caudal que ya hay, así que cada paso suma lo que la curva ha subido en él: la suma de todos los pasos es
		# exactamente `q` (telescópica) y el caudal en cada instante es q·suavizado(t/T).
		sumar_fuente(r["c"] as Vector2i, float(r["q"]) * (_suavizado(t1 / T) - _suavizado(t0 / T)))
		r["t"] = t1
		if t1 >= T - 1.0e-6:
			_rampas.remove_at(i)
		i -= 1


## smootherstep: 0→1 con pendiente y curvatura 0 en los dos extremos.
static func _suavizado(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


## Echa `volumen` u³ alrededor de un punto del mundo, en un círculo de `radio` u (hechizo de agua, cubo que se vuelca…).
func anadir(pos: Vector3, volumen: float, radio: float = 0.0) -> void:
	var t: PackedInt32Array = _trozos_en_circulo(pos, maxf(radio, l * 0.5))
	if t.is_empty():
		return
	var por: float = volumen / float(t.size()) / (l * l)
	for i in t:
		if helado[i] == 1:
			continue                            # sobre el hielo el agua no entra (se pierde ese trocito del reparto)
		prof[i] += por
		_incluir(i)
		_evento(i, EVENTO_ENTRA, volumen / VOLUMEN_EVENTO_REF)


## Quita hasta `volumen` u³ alrededor de un punto (fuego que evapora). Devuelve lo que ha quitado de verdad (para el vapor).
func quitar(pos: Vector3, volumen: float, radio: float = 0.0) -> float:
	var t: PackedInt32Array = _trozos_en_circulo(pos, maxf(radio, l * 0.5))
	var quitado: float = 0.0
	var pide: float = volumen / maxf(1.0, float(t.size())) / (l * l)
	for i in t:
		if helado[i] == 1:
			continue                            # el hielo no se evapora: se funde con derretir()
		var q: float = minf(prof[i], pide)
		prof[i] -= q
		quitado += q * l * l
		if q > 0.0:
			_evento(i, EVENTO_EVAPORA, 1.0)
	return quitado


## --- Hielo (Fase 11.12) ---
## El hielo es por TROCITO y con tiempo. Un trocito helado CONSERVA su agua: no corre, no recibe caudal, no se absorbe, no se
## evapora y no le llega agua de fuentes ni de hechizos. Al soltarse (tiempo o fuego) es la misma agua de antes: el volumen
## total no cambia nunca por helar o derretir.

## Hiela los trocitos CON AGUA (más que la lámina que retiene el suelo) del círculo de `radio` u alrededor de `pos`, `segundos`
## s. Si ya estaban helados, NO se les renueva el tiempo (el hielo no se acumula). Devuelve cuántos trocitos helados hay ahora en el círculo.
func helar(pos: Vector3, radio: float, segundos: float = DURA_HIELO) -> int:
	var n: int = 0
	for i in _trozos_en_circulo(pos, maxf(radio, l * 0.5)):
		if prof[i] > RETIENE:
			if helado[i] == 0:                  # el hielo se aplica UNA vez: si ya estaba helado no se renueva ni se alarga (Pablo, 12/10)
				_helar_trozo(i, segundos)
			n += 1
	return n


## Suelta el hielo del círculo (fuego). Devuelve cuántos trocitos soltó.
func derretir(pos: Vector3, radio: float) -> int:
	var n: int = 0
	for i in _trozos_en_circulo(pos, maxf(radio, l * 0.5)):
		if helado[i] == 1:
			_soltar_trozo(i)
			n += 1
	return n


## Atajo por casilla entera (el laboratorio, las pruebas): hiela TODOS sus trocitos aunque no tengan agua, o los suelta.
func helar_casilla(c: Vector2i, si: bool) -> void:
	for i in _trozos(c):
		if si:
			_helar_trozo(i, DURA_HIELO)
		elif helado[i] == 1:
			_soltar_trozo(i)


## Y de la cara de arriba del hielo en un punto del mundo (suelo + agua), o −INF si ahí no hay hielo.
func hielo_en(pos: Vector3) -> float:
	var i: int = _trozo_de(pos)
	if i < 0 or helado[i] == 0:
		return -INF
	return suelo[i] + prof[i]


## Qué fracción de su tiempo le queda al hielo de ese punto (1 = recién hecho, 0 = a punto de soltarse), o −1 si ahí no hay
## hielo. Lo usa el Lanzador para avisar (costra con grietas) a lo que está preso cuando le queda poco.
func fraccion_hielo_en(pos: Vector3) -> float:
	var i: int = _trozo_de(pos)
	if i < 0 or helado[i] == 0:
		return -1.0
	return clampf(hielo_t[i] / maxf(hielo_ini[i], 0.001), 0.0, 1.0)


## ¿Está helada la casilla? Cuando lo está al menos la mitad de sus trocitos (5 de 9).
func casilla_helada(c: Vector2i) -> bool:
	var t: PackedInt32Array = _trozos(c)
	if t.is_empty():
		return false
	var n: int = 0
	for i in t:
		n += helado[i]
	return n * 2 > t.size()


## Hondura media (u) del hielo de la casilla: la prof media de sus trocitos helados (0 si no hay). Es lo «gordo» que es el hielo.
func espesor_hielo(c: Vector2i) -> float:
	var s: float = 0.0
	var n: int = 0
	for i in _trozos(c):
		if helado[i] == 1:
			s += prof[i]
			n += 1
	return s / float(n) if n > 0 else 0.0


## Y de la cara de arriba del hielo de una casilla (media de sus trocitos helados), o −INF si no hay. Para dónde pisa quien
## camina por encima.
func hielo_en_casilla(c: Vector2i) -> float:
	var s: float = 0.0
	var n: int = 0
	for i in _trozos(c):
		if helado[i] == 1:
			s += suelo[i] + prof[i]
			n += 1
	return s / float(n) if n > 0 else -INF


## Las casillas que han pasado a estar heladas (o a dejar de estarlo) desde la última llamada: [{c: Vector2i, helada: bool}].
## Incluye las que se sueltan solas al acabarse el tiempo. El Lanzador las usa para mantener al día `_helada` de la maqueta.
func cambios_hielo() -> Array:
	var r: Array = []
	for c in _hielo_sucias.keys():
		var ahora: bool = casilla_helada(c as Vector2i)
		var idx: int = (c as Vector2i).y * ancho + (c as Vector2i).x
		if (_hielo_estado[idx] == 1) != ahora:
			_hielo_estado[idx] = 1 if ahora else 0
			r.append({"c": c, "helada": ahora})
	_hielo_sucias.clear()
	return r


func _helar_trozo(i: int, segundos: float) -> void:
	helado[i] = 1
	hielo_t[i] = segundos
	hielo_ini[i] = segundos
	_cero_caudal(i)
	_incluir(i)                                 # la caja de trabajo tiene que incluir el hielo, o su tiempo no baja
	_hielo_vivo = true
	_marcar_hielo(i)
	_evento(i, EVENTO_HIELA, 1.0)


func _soltar_trozo(i: int) -> void:
	helado[i] = 0
	hielo_t[i] = 0.0
	hielo_ini[i] = 0.0
	_incluir(i)
	_marcar_hielo(i)
	_evento(i, EVENTO_HIELO_ROTO, 1.0)


func _marcar_hielo(i: int) -> void:
	_hielo_sucias[Vector2i((i % w) / sub, (i / w) / sub)] = true


## Tierra (o cualquier sólido nuevo): tapa la casilla y aparta su agua a los vecinos abiertos (no se pierde ni una gota).
func solidificar_casilla(c: Vector2i, si: bool) -> void:
	if not si and _estrechos.has(c):
		_aplicar_estrecho(c)                    # abrir un canal estrecho no lo ensancha: se abre con su forma
		return
	for i in _trozos(c):
		_poner_cerrado(i, si)


## --- Lo que el juego pregunta ---

## Profundidad media del agua en la casilla (u), contando solo los trocitos abiertos: en un canal estrecho el agua está en su
## cajón, no en los trocitos cerrados de las esquinas. 0 si están todos cerrados (pared).
func profundidad_casilla(c: Vector2i) -> float:
	if not _dentro_casilla(c):
		return 0.0
	var s: float = 0.0
	var t: PackedInt32Array = _trozos_abiertos(c)
	if t.is_empty():
		return 0.0
	for i in t:
		s += prof[i]
	return s / float(t.size())


## ¿Es agua para el juego? (se nada/se hiela/conduce el rayo). Las casillas heladas no son agua: son hielo.
func es_agua_casilla(c: Vector2i) -> bool:
	if not _dentro_casilla(c):
		return false
	return not casilla_helada(c) and profundidad_casilla(c) >= UMBRAL_AGUA


func se_nada_en(c: Vector2i) -> bool:
	return es_agua_casilla(c) and profundidad_casilla(c) >= UMBRAL_NADO


## Y de la superficie del agua en un punto del mundo (o la del suelo si está seco). Para flotar y para salpicar en su sitio.
func superficie_en(pos: Vector3) -> float:
	var i: int = _trozo_de(pos)
	if i < 0:
		return -INF
	return suelo[i] + prof[i]


func profundidad_en(pos: Vector3) -> float:
	var i: int = _trozo_de(pos)
	return prof[i] if i >= 0 else 0.0


## Velocidad de la corriente en un punto (x, z del mundo, u/s). Para arrastrar lo que flota y orientar la espuma.
func corriente_en(pos: Vector3) -> Vector2:
	var i: int = _trozo_de(pos)
	if i < 0:
		return Vector2.ZERO
	return _velocidad(i)


## ¿Está mojada la casilla? (tiene agua, o la tuvo hace menos de SECA_EN s). Para el estado «mojado» del suelo.
func casilla_mojada(c: Vector2i) -> bool:
	if not _dentro_casilla(c):
		return false
	for i in _trozos(c):
		if mojado[i] > 0.0:
			return true
	return false


## SUELO MOJADO PARA EL DIBUJO (27/10). El suelo lo pedía desde el 12/10 (`PruebaTest2._actualizar_suelo_mojado`, 8 veces por segundo) y esta
## función no existía, así que el suelo que moja el agua nunca se veía. R8, un texel por trocito, 0..1:
##   · donde HAY o HUBO agua: lo que le falta para secarse (`mojado`, SECA_EN s), entero hasta que queda MOJADO_SECA_FRAC de SECA_EN y luego
##     baja: el charco que se absorbe deja el suelo oscuro y se va aclarando (DK Bananza: el suelo se oscurece con el agua y se seca).
##   · la ORILLA: el suelo junto a agua que se ve (más que PROF_CHARCO) queda húmedo en una franja de dos trocitos, ORILLA_1 en el primero
##     y ORILLA_2 en el segundo. Solo aspecto: no cuenta para `casilla_mojada` ni para ningún estado. Solo los trocitos de agua del BORDE
##     (con algún vecino sin agua) mojan alrededor: el interior de un río no hace falta mirarlo.
## Es siempre el mismo ImageTexture (se actualiza, no se recrea).
const MOJADO_SECA_FRAC: float = 0.45
const ORILLA_1: float = 0.75
const ORILLA_2: float = 0.3
var _img_mojado: Image = null
var _tex_mojado: ImageTexture = null
var _bytes_mojado := PackedByteArray()


func textura_mojado() -> ImageTexture:
	var n: int = w * h
	if n <= 0:
		return null
	if _bytes_mojado.size() != n:
		_bytes_mojado.resize(n)
	_bytes_mojado.fill(0)
	var seca_plena: float = SECA_EN * MOJADO_SECA_FRAC
	var o1: int = int(ORILLA_1 * 255.0)
	var o2: int = int(ORILLA_2 * 255.0)
	# Solo la caja donde hay agua o suelo mojado (`_x0.._x1`, la del paso): fuera de ella todo está seco. La orilla sale hasta 2 trocitos
	# fuera, pero la escriben los trocitos de dentro.
	for y in range(maxi(_y0, 0), mini(_y1, h - 1) + 1):
		for x in range(maxi(_x0, 0), mini(_x1, w - 1) + 1):
			var i: int = y * w + x
			if mojado[i] > 0.0:
				_bytes_mojado[i] = maxi(_bytes_mojado[i], int(clampf(mojado[i] / seca_plena, 0.0, 1.0) * 255.0))
			if prof[i] <= PROF_CHARCO:
				continue
			if x > 0 and x < w - 1 and y > 0 and y < h - 1 and prof[i - 1] > PROF_CHARCO and prof[i + 1] > PROF_CHARCO 					and prof[i - w] > PROF_CHARCO and prof[i + w] > PROF_CHARCO:
				continue                         # agua por los cuatro lados: no es borde
			# Agua que se ve: humedece los trocitos de alrededor (1.ª corona ORILLA_1, 2.ª ORILLA_2), sin pisar lo que ya esté más mojado.
			for dy in range(-2, 3):
				var yy: int = y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-2, 3):
					var xx: int = x + dx
					if xx < 0 or xx >= w or (dx == 0 and dy == 0):
						continue
					var j: int = yy * w + xx
					var v: int = o1 if maxi(absi(dx), absi(dy)) == 1 else o2
					if _bytes_mojado[j] < v:
						_bytes_mojado[j] = v
	if _img_mojado == null or _img_mojado.get_width() != w or _img_mojado.get_height() != h:
		_img_mojado = Image.create_from_data(w, h, false, Image.FORMAT_R8, _bytes_mojado)
		_tex_mojado = ImageTexture.create_from_image(_img_mojado)
	else:
		_img_mojado.set_data(w, h, false, Image.FORMAT_R8, _bytes_mojado)
		_tex_mojado.update(_img_mojado)
	return _tex_mojado


## La caja (en trocitos) donde hay agua, fuentes, hielo o suelo mojado: lo que recorre el paso. Vacía (sin área) si no hay nada. Para quien
## dibuja (13.9: las paredes del agua solo se rehacen aquí) o mide sin recorrer toda la rejilla.
func caja_trabajo() -> Rect2i:
	if _x1 < _x0 or _y1 < _y0:
		return Rect2i()
	return Rect2i(_x0, _y0, _x1 - _x0 + 1, _y1 - _y0 + 1)


## Volumen total de agua (u³). Sirve para las pruebas: con fuentes y absorción apagadas no cambia nunca.
func volumen_total() -> float:
	var s: float = 0.0
	for i in range(prof.size()):
		s += prof[i]
	return s * l * l


## Las casillas que han pasado de seco a agua o al revés desde la última llamada: [{c: Vector2i, agua: bool}].
## El Lanzador las usa para mantener al día lo que hoy sale de la letra «~» (bloqueo a pie, nado, rayo, dibujo).
func cambios() -> Array:
	var r: Array = _cambios
	_cambios = []
	return r


## --- W0 · Llenado de un recipiente (19/10) ---
## Un pozo, un vaso o un hoyo se llena por VOLUMEN: la simulación ya guarda una cantidad de agua por trocito y la reparte hasta el borde. Lo que no
## existía es PREGUNTARLO: ¿cuánto cabe?, ¿cuánto hay?, ¿a qué altura rebosa?, ¿cuánto falta? Se contesta con el suelo, no con el agua actual: el
## recipiente es la región de trocitos abiertos que se llena antes de que el agua se escape por el punto más bajo de su borde (inundación por
## prioridad: se crece desde el fondo por el trocito más bajo de la frontera; cuando el más bajo tiene un vecino aún más bajo fuera de la región, por ahí
## se derramaría y esa es la altura de rebose). Un llano sin borde (o sin fondo: capacidad 0) o que pasa de MAX_RECIPIENTE trocitos sale `abierto`.
##
## `c` es cualquier casilla del recipiente (se baja desde ella al fondo local). `rebose` opcional fija la altura del borde (Y del mundo) en vez de
## calcularla: sirve para un vaso cuyo borde no es el punto de derrame del terreno. Devuelve {rebose (Y), capacidad (u³), volumen (u³ de agua que hay ahora
## dentro), fraccion (0..1), trozos, abierto, semilla (casilla del fondo)}; {} si la casilla es pared.
func recipiente(c: Vector2i, rebose: float = INF) -> Dictionary:
	var ab: PackedInt32Array = _trozos_abiertos(c)
	if ab.is_empty():
		return {}
	var semilla: int = ab[0]
	for i in ab:
		if suelo[i] < suelo[semilla]:
			semilla = i
	for _n in range(w + h):                     # bajar al fondo local: si un vecino de fuera de la casilla es más bajo, el agua se iría hacia allí
		var mejor: int = semilla
		for k in range(4):
			var j: int = vecinos[semilla * 4 + k]
			if j >= 0 and cerrado[j] == 0 and suelo[j] < suelo[mejor]:
				mejor = j
		if mejor == semilla:
			break
		semilla = mejor
	var vis := PackedByteArray()
	vis.resize(w * h)
	var cola: Array = []                         # montículo mínimo de Vector2(altura de suelo, trocito)
	_mont_meter(cola, Vector2(suelo[semilla], float(semilla)))
	vis[semilla] = 1
	var region := PackedInt32Array()
	var borde: float = rebose
	var abierto: bool = false
	while not cola.is_empty():
		var top: Vector2 = _mont_sacar(cola)
		var i: int = int(top.y)
		var hi: float = top.x
		if rebose != INF and hi > rebose:
			break
		if rebose == INF:
			var derrama: bool = false
			for k in range(4):
				var j: int = vecinos[i * 4 + k]
				if j < 0 or (cerrado[j] == 0 and vis[j] == 0 and suelo[j] < hi):
					derrama = true
					break
			if derrama:
				borde = hi
				break
		region.append(i)
		if region.size() > MAX_RECIPIENTE:
			abierto = true
			break
		for k in range(4):
			var j2: int = vecinos[i * 4 + k]
			if j2 >= 0 and cerrado[j2] == 0 and vis[j2] == 0:
				vis[j2] = 1
				_mont_meter(cola, Vector2(suelo[j2], float(j2)))
	var cap: float = 0.0
	var vol: float = 0.0
	if borde != INF and not abierto:
		for i in region:
			cap += maxf(0.0, borde - suelo[i])
			vol += prof[i]
		cap *= l * l
		vol *= l * l
		if cap <= 0.0:
			abierto = true                       # un llano: el borde está a la altura del fondo, no cabe nada
			borde = INF
	else:
		abierto = true
		borde = INF
	return {"rebose": borde, "capacidad": cap, "volumen": vol, "fraccion": clampf(vol / cap, 0.0, 1.0) if cap > 0.0 else 0.0,
		"trozos": region.size(), "abierto": abierto, "semilla": Vector2i((semilla % w) / sub, (semilla / w) / sub)}


## Segundos que faltan para llenar el recipiente de `c` echándole `caudal_u3s` (u³/s): (capacidad − volumen) / caudal. 0 si ya está lleno, INF si el
## caudal es 0 o el recipiente está abierto. Aproximado: no cuenta lo que el suelo absorbe de las láminas finas ni el tiempo que tarda el agua en repartirse.
func segundos_hasta_llenar(c: Vector2i, caudal_u3s: float, rebose: float = INF) -> float:
	var d: Dictionary = recipiente(c, rebose)
	if d.is_empty() or bool(d["abierto"]) or caudal_u3s <= 0.0:
		return INF
	return maxf(0.0, float(d["capacidad"]) - float(d["volumen"])) / caudal_u3s


func _mont_meter(m: Array, v: Vector2) -> void:
	m.append(v)
	var k: int = m.size() - 1
	while k > 0:
		var p: int = (k - 1) / 2
		if (m[p] as Vector2).x <= (m[k] as Vector2).x:
			break
		var t: Vector2 = m[p]
		m[p] = m[k]
		m[k] = t
		k = p


func _mont_sacar(m: Array) -> Vector2:
	var cima: Vector2 = m[0]
	var ult: Vector2 = m.pop_back()
	if not m.is_empty():
		m[0] = ult
		var k: int = 0
		var n: int = m.size()
		while true:
			var a: int = 2 * k + 1
			var b: int = a + 1
			var s: int = k
			if a < n and (m[a] as Vector2).x < (m[s] as Vector2).x:
				s = a
			if b < n and (m[b] as Vector2).x < (m[s] as Vector2).x:
				s = b
			if s == k:
				break
			var t: Vector2 = m[s]
			m[s] = m[k]
			m[k] = t
			k = s
	return cima


## --- W0 · Caída (cascadas) ---
## Salto de la superficie entre un trocito con agua y el vecino al que le está corriendo agua (u; 0 si no cae). A partir de UMBRAL_CAIDA es una cascada: el
## dibujo pone salpicadura y espuma ahí. Solo cuenta los saltos con caudal de verdad: un escalón con agua parada arriba no es una caída.
func caida_en_trozo(i: int) -> float:
	if i < 0 or prof[i] <= PROF_MIN or cerrado[i] == 1 or helado[i] == 1:
		return 0.0
	var sup: float = suelo[i] + prof[i]
	var m: float = 0.0
	for k in range(4):
		var j: int = vecinos[i * 4 + k]
		if j >= 0 and cerrado[j] == 0 and caudal[i * 4 + k] > 0.0:
			m = maxf(m, sup - (suelo[j] + prof[j]))
	return m


func caida_en(pos: Vector3) -> float:
	return caida_en_trozo(_trozo_de(pos))


## ¿Hay una cascada en la casilla? (algún trocito suyo cae al menos UMBRAL_CAIDA)
func hay_cascada_en_casilla(c: Vector2i) -> bool:
	for i in _trozos(c):
		if caida_en_trozo(i) >= UMBRAL_CAIDA:
			return true
	return false


## Imagen w × h, FORMAT_RF: un float por trocito (u de caída), mismo origen y tamaño de texel que `textura()`. Solo recorre la caja de trabajo.
func imagen_caida() -> Image:
	var datos := PackedFloat32Array()
	datos.resize(w * h)
	if _x1 >= _x0 and _y1 >= _y0:
		for y in range(maxi(0, _y0 - 1), mini(h - 1, _y1 + 1) + 1):
			for x in range(maxi(0, _x0 - 1), mini(w - 1, _x1 + 1) + 1):
				datos[y * w + x] = caida_en_trozo(y * w + x)
	return Image.create_from_data(w, h, false, Image.FORMAT_RF, datos.to_byte_array())


func textura_caida() -> ImageTexture:
	var img: Image = imagen_caida()
	if _tex_caida == null:
		_tex_caida = ImageTexture.create_from_image(img)
	else:
		_tex_caida.update(img)
	return _tex_caida


## --- W0 · Eventos ---
## Lo que acaba de pasar y el dibujo debe animar una vez: entra agua, se rompe hielo, se evapora, se hiela. Uno por trocito (el último gana) y se tiran
## solos a los VIDA_EVENTO s si nadie los consume. No tocan la simulación.
func _evento(i: int, tipo: int, intensidad: float) -> void:
	_eventos[i] = Vector3(float(tipo), clampf(intensidad, 0.1, 1.0), _t)


func _podar_eventos() -> void:
	for i in _eventos.keys():
		if _t - (_eventos[i] as Vector3).z > VIDA_EVENTO:
			_eventos.erase(i)


## Imagen RG8 w × h (mismo origen y texel que `textura()`): R = tipo (EVENTO_*, 0 = nada), G = intensidad (255 = 1). Con `consumir` (por defecto) los
## eventos se borran: el dibujo los lee UNA vez por fotograma de dibujo.
func imagen_eventos(consumir: bool = true) -> Image:
	if _eventos.is_empty() and _img_eventos != null and _img_eventos_vacia:
		return _img_eventos
	var datos := PackedByteArray()
	datos.resize(w * h * 2)
	var n: int = 0
	for i in _eventos:
		var v: Vector3 = _eventos[i]
		if _t - v.z <= VIDA_EVENTO:
			datos[int(i) * 2] = int(v.x)
			datos[int(i) * 2 + 1] = int(roundf(v.y * 255.0))
			n += 1
	_img_eventos = Image.create_from_data(w, h, false, Image.FORMAT_RG8, datos)
	_img_eventos_vacia = n == 0
	if consumir:
		_eventos.clear()
	return _img_eventos


func textura_eventos(consumir: bool = true) -> ImageTexture:
	var img: Image = imagen_eventos(consumir)
	if _tex_eventos == null:
		_tex_eventos = ImageTexture.create_from_image(img)
	else:
		_tex_eventos.update(img)
	return _tex_eventos


## Los mismos eventos como lista, con posición en el mundo (para soltar partículas): [{tipo, intensidad, pos: Vector3 (centro del trocito, en la superficie)}].
func eventos_pendientes(consumir: bool = false) -> Array:
	var r: Array = []
	for i in _eventos:
		var v: Vector3 = _eventos[i]
		if _t - v.z <= VIDA_EVENTO:
			var k: int = int(i)
			r.append({"tipo": int(v.x), "intensidad": v.y, "pos": Vector3((float(k % w) + 0.5) * l, suelo[k] + prof[k], (float(k / w) + 0.5) * l)})
	if consumir:
		_eventos.clear()
	return r


## --- El paso ---

func paso(delta: float) -> void:
	_t += delta
	if _t - _ritmo_hielo_t > 0.5:
		_ritmo_hielo_t = _t
		_ritmo_hielo_cache.clear()
	if not _eventos.is_empty():
		_podar_eventos()
	_acumulado = minf(_acumulado + delta, PASO_FIJO * float(MAX_PASOS))
	var n_pasos: int = 0
	while _acumulado >= PASO_FIJO and n_pasos < MAX_PASOS:
		_acumulado -= PASO_FIJO
		if not _rampas.is_empty():
			_avanzar_rampas(PASO_FIJO)
		if not _topes.is_empty():
			_gastar_topes(PASO_FIJO)
		_paso(PASO_FIJO)
		n_pasos += 1
	if n_pasos > 0:
		_revisar_casillas()


## F4 (29/10): Callable(celda: Vector2i) -> float, cuánto dura el hielo en esa casilla frente a lo normal (`Mundo3D` conecta `EstadoZona3D.factor_hielo_dura`: calor 1/3, frío ×100). Vacío = 1.
var factor_hielo_dura: Callable = Callable()
var _ritmo_hielo_cache: Dictionary = {}          ## casilla -> ritmo del reloj del hielo (1 / factor); se vacía cada medio segundo
var _ritmo_hielo_t: float = 0.0


## A qué ritmo corre el reloj del trocito `i` de hielo (1 = normal, 3 = se deshace en un tercio).
func _ritmo_hielo(i: int) -> float:
	if not factor_hielo_dura.is_valid():
		return 1.0
	var c := Vector2i((i % w) / sub, (i / w) / sub)
	if not _ritmo_hielo_cache.has(c):
		_ritmo_hielo_cache[c] = 1.0 / maxf(float(factor_hielo_dura.call(c)), 0.01)
	return float(_ritmo_hielo_cache[c])


func _paso(dt: float) -> void:
	if _x1 < _x0:
		return                                  # no hay agua, ni fuentes, ni nada mojado: nada que hacer
	var area: float = l * l
	# Solo se recorre la caja donde hay algo (más un trocito de margen: el agua avanza como mucho uno por paso).
	var x0: int = maxi(0, _x0 - 1)
	var x1: int = mini(w - 1, _x1 + 1)
	var y0: int = maxi(0, _y0 - 1)
	var y1: int = mini(h - 1, _y1 + 1)
	_trabajo = _trabajo.merge(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)) if _trabajo.has_area() else Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	# 1) Fuentes, niveles fijos y absorción de las láminas finas.
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			if cerrado[i] == 1:
				continue
			if helado[i] == 1:
				hielo_t[i] -= dt * _ritmo_hielo(i)
				if hielo_t[i] <= 0.0:
					_soltar_trozo(i)            # se acabó el tiempo: vuelve a ser agua, la misma de antes
				else:
					mojado[i] = SECA_EN
					continue                    # el hielo no se absorbe, ni recibe fuentes, ni se fija a un nivel
			if fuente[i] != 0.0:
				prof[i] = maxf(0.0, prof[i] + fuente[i] * dt / area)
			if fijo[i] > -INF:
				prof[i] = maxf(0.0, fijo[i] - suelo[i])
			var p: float = prof[i]
			if p > PROF_MIN:
				mojado[i] = SECA_EN
				# `<=` y no `<`: el recorte K del caudal deja el último trocito justo en RETIENE (= PROF_CHARCO) y,
				# con `<`, esa lámina se quedaba para siempre (el charco nunca se absorbía ni la casilla se secaba).
				# La holgura cubre el redondeo de guardar en float32.
				if p <= PROF_CHARCO + 1.0e-5 and fuente[i] == 0.0 and fijo[i] == -INF:
					prof[i] = maxf(0.0, p - ABSORBE * dt)
			else:
				prof[i] = 0.0                  # restos por debajo de PROF_MIN: fuera (si no, se quedan sin absorber nunca)
				if mojado[i] > 0.0:
					mojado[i] = maxf(0.0, mojado[i] - dt)
	# 2) Caudal de salida de cada trocito con agua hacia sus 4 vecinos, recortado para no sacar más de lo que hay (K).
	var k_g: float = dt * l * G
	var amortigua: float = pow(AMORTIGUA, dt)  # por paso, para que no dependa de PASO_FIJO
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			var b: int = i * 4
			if cerrado[i] == 1 or helado[i] == 1 or prof[i] <= RETIENE:
				caudal[b] = 0.0
				caudal[b + 1] = 0.0
				caudal[b + 2] = 0.0
				caudal[b + 3] = 0.0
				continue
			var sup: float = suelo[i] + prof[i]
			var total: float = 0.0
			for k in range(4):
				var j: int = vecinos[b + k]
				var v: float = 0.0
				if j >= 0 and cerrado[j] == 0 and helado[j] == 0:
					v = maxf(0.0, caudal[b + k] * amortigua + k_g * (sup - suelo[j] - prof[j]))
				caudal[b + k] = v
				total += v
			if total > 0.0:
				var tope: float = (prof[i] - RETIENE) * area / (total * dt)
				if tope < 1.0:
					for k in range(4):
						caudal[b + k] *= tope
	# 3) Mover el agua: lo que sale de i entra en su vecino (conserva el volumen exactamente). Y la caja nueva.
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			var b: int = i * 4
			for k in range(4):
				var f: float = caudal[b + k]
				if f <= 0.0:
					continue
				var j: int = vecinos[b + k]
				var dv: float = f * dt / area
				prof[i] -= dv
				prof[j] += dv
	_x0 = w
	_x1 = -1
	_y0 = h
	_y1 = -1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			if prof[i] < 0.0:
				prof[i] = 0.0                  # restos de redondeo: el recorte K ya impide vaciar de más
			if prof[i] > 0.0 or mojado[i] > 0.0 or fuente[i] != 0.0 or fijo[i] > -INF or helado[i] == 1:
				_incluir_xy(x, y)


## Amplía la caja de trabajo para que incluya el trocito i (al echar agua, poner una fuente, fijar un nivel…).
func _incluir(i: int) -> void:
	_incluir_xy(i % w, i / w)


func _incluir_xy(x: int, y: int) -> void:
	_x0 = mini(_x0, x)
	_x1 = maxi(_x1, x)
	_y0 = mini(_y0, y)
	_y1 = maxi(_y1, y)


## --- Para el dibujo (Pipeline) ---

## Imagen w × h, una texel por trocito: R = Y de la superficie (o del suelo si seco), G = profundidad, B = corriente en x,
## A = corriente en z. Formato RGBAF (32 bits por canal). El shader del agua la lee con `texelFetch` o filtrada.
## Para el dibujo: con G por debajo de ~0,05 u es una LÁMINA (suelo mojado, brillo), no agua que se vea como tal.
## Se rellena un PackedFloat32Array y se crea la imagen de golpe (set_pixel texel a texel es mucho más lento). Llamarla a
## unas 10-15 veces por segundo basta: el agua no cambia tan deprisa y el shader interpola.
func imagen() -> Image:
	var datos := PackedFloat32Array()
	datos.resize(w * h * 4)
	for i in range(w * h):
		var v: Vector2 = _velocidad(i) if prof[i] > PROF_MIN else Vector2.ZERO
		datos[i * 4] = suelo[i] + prof[i]
		datos[i * 4 + 1] = prof[i]
		datos[i * 4 + 2] = v.x
		datos[i * 4 + 3] = v.y
	_img = Image.create_from_data(w, h, false, Image.FORMAT_RGBAF, datos.to_byte_array())
	return _img


## La misma imagen como textura, actualizada en el sitio (no crea una textura nueva cada vez).
func textura() -> ImageTexture:
	var img: Image = imagen()
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	return _tex


## Para el dibujo del hielo (11.14): imagen RG8 de w × h, mismo origen y tamaño de texel que `textura()`.
## R = 255 si el trocito está helado; G = lo que le queda de hielo respecto a lo que tenía al helarse (255 = recién helado,
## 0 = a punto de soltarse). Si no hay hielo, no recorre nada: devuelve la misma imagen de ceros.
func textura_hielo() -> ImageTexture:
	var img: Image = imagen_hielo()
	if _tex_hielo == null:
		_tex_hielo = ImageTexture.create_from_image(img)
	else:
		_tex_hielo.update(img)
	return _tex_hielo


## La imagen de textura_hielo() sin subirla a la tarjeta (las pruebas la leen directamente).
func imagen_hielo() -> Image:
	if _img_hielo != null and not _hielo_vivo:
		return _img_hielo
	var datos := PackedByteArray()
	datos.resize(w * h * 2)
	var vivo: bool = false
	for i in range(w * h):
		if helado[i] == 1:
			vivo = true
			datos[i * 2] = 255
			datos[i * 2 + 1] = int(clampf(hielo_t[i] / maxf(hielo_ini[i], 0.001), 0.0, 1.0) * 255.0)
	_hielo_vivo = vivo
	_img_hielo = Image.create_from_data(w, h, false, Image.FORMAT_RG8, datos)
	return _img_hielo


## --- Internos ---

func _dentro_casilla(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ancho and c.y < alto


func _trozos(c: Vector2i) -> PackedInt32Array:
	var r := PackedInt32Array()
	if not _dentro_casilla(c):
		return r
	for sy in range(sub):
		for sx in range(sub):
			r.append((c.y * sub + sy) * w + c.x * sub + sx)
	return r


func _trozo_de(pos: Vector3) -> int:
	var x: int = int(floorf(pos.x / l))
	var y: int = int(floorf(pos.z / l))
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x


func _trozos_en_circulo(pos: Vector3, radio: float) -> PackedInt32Array:
	var r := PackedInt32Array()
	var x0: int = maxi(0, int(floorf((pos.x - radio) / l)))
	var x1: int = mini(w - 1, int(floorf((pos.x + radio) / l)))
	var y0: int = maxi(0, int(floorf((pos.z - radio) / l)))
	var y1: int = mini(h - 1, int(floorf((pos.z + radio) / l)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cx: float = (float(x) + 0.5) * l - pos.x
			var cy: float = (float(y) + 0.5) * l - pos.z
			var i: int = y * w + x
			if cx * cx + cy * cy <= radio * radio and cerrado[i] == 0:
				r.append(i)
	if r.is_empty():
		var i: int = _trozo_de(pos)
		if i >= 0 and cerrado[i] == 0:
			r.append(i)
	return r


func _vecino(x: int, y: int, k: int) -> int:
	match k:
		0:
			return y * w + x - 1 if x > 0 else -1
		1:
			return y * w + x + 1 if x < w - 1 else -1
		2:
			return (y - 1) * w + x if y > 0 else -1
		_:
			return (y + 1) * w + x if y < h - 1 else -1


func _cero_caudal(i: int) -> void:
	for k in range(4):
		caudal[i * 4 + k] = 0.0


## Cerrar un trocito con agua dentro: el agua se reparte entre los vecinos abiertos (si no hay ninguno, se queda encima:
## no se destruye agua por levantar tierra en mitad de un lago cerrado).
func _poner_cerrado(i: int, si: bool) -> void:
	if not si:
		cerrado[i] = 0
		return
	if cerrado[i] == 1:
		return
	if helado[i] == 1:
		_soltar_trozo(i)                        # la tierra o el muro desplazan el agua: el hielo se rompe
	var abiertos: Array[int] = []
	for k in range(4):
		var j: int = vecinos[i * 4 + k]
		if j >= 0 and cerrado[j] == 0:
			abiertos.append(j)
	if prof[i] > 0.0 and not abiertos.is_empty():
		var parte: float = prof[i] / float(abiertos.size())
		for j in abiertos:
			prof[j] += parte
			_incluir(j)
		prof[i] = 0.0
	cerrado[i] = 1
	_cero_caudal(i)


## Corriente media del trocito (u/s): lo que entra por un lado y sale por el otro, entre la sección mojada.
func _velocidad(i: int) -> Vector2:
	var p: float = prof[i]
	if p <= PROF_MIN:
		return Vector2.ZERO
	var b: int = i * 4
	var izq: int = vecinos[b]
	var der: int = vecinos[b + 1]
	var arr: int = vecinos[b + 2]
	var aba: int = vecinos[b + 3]
	var entra_izq: float = caudal[izq * 4 + 1] if izq >= 0 else 0.0
	var entra_der: float = caudal[der * 4 + 0] if der >= 0 else 0.0
	var entra_arr: float = caudal[arr * 4 + 3] if arr >= 0 else 0.0
	var entra_aba: float = caudal[aba * 4 + 2] if aba >= 0 else 0.0
	var qx: float = (entra_izq - caudal[b] + caudal[b + 1] - entra_der) * 0.5
	var qz: float = (entra_arr - caudal[b + 2] + caudal[b + 3] - entra_aba) * 0.5
	return Vector2(qx, qz) / (l * p)


func _avisar_casilla(c: Vector2i) -> void:
	var ahora: bool = es_agua_casilla(c)
	var idx: int = c.y * ancho + c.x
	if (_era_agua[idx] == 1) != ahora:
		_era_agua[idx] = 1 if ahora else 0
		_cambios.append({"c": c, "agua": ahora})


## Solo mira las casillas que tocan la caja de trabajo de los últimos pasos: fuera de ella no ha cambiado nada (lo que era
## agua tenía agua, y lo que tiene agua está siempre dentro de la caja).
func _revisar_casillas() -> void:
	if not _trabajo.has_area():
		return
	var cx0: int = _trabajo.position.x / sub
	var cy0: int = _trabajo.position.y / sub
	var cx1: int = (_trabajo.end.x - 1) / sub
	var cy1: int = (_trabajo.end.y - 1) / sub
	_trabajo = Rect2i()
	var por: float = 1.0 / float(sub * sub)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var i0: int = (cy * sub) * w + cx * sub
			var suma: float = 0.0
			for sy in range(sub):
				for sx in range(sub):
					suma += prof[i0 + sy * w + sx]
			var n_hielo: int = 0
			for sy in range(sub):
				for sx in range(sub):
					n_hielo += helado[i0 + sy * w + sx]
			var ahora: bool = n_hielo * 2 <= sub * sub and suma * por >= UMBRAL_AGUA
			var idx: int = cy * ancho + cx
			if (_era_agua[idx] == 1) != ahora:
				_era_agua[idx] = 1 if ahora else 0
				_cambios.append({"c": Vector2i(cx, cy), "agua": ahora})

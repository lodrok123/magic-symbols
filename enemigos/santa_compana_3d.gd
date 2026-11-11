class_name SantaCompana3D
extends Node3D

## E5 · SANTA COMPAÑA (enemigo del glifo ᛁ, «línea»: «cógelos a todos de una pasada o no acaba nunca»). Dueño: Juego.
##
## Es la PROCESIÓN: un nodo que coordina a sus ánimas (`AnimaCompana3D`, enemigos/anima_compana_3d.gd). Las reglas:
##   · Son `n_animas` (3 por defecto) EN FILA, a una casilla una de otra (SEPARACION_CASILLAS), recorriendo un CAMINO fijo (una lista de casillas) a VEL_FILA u/s. El camino se recorre de ida y vuelta:
##     al llegar al final la fila da la vuelta entera y vuelve por donde vino. Sin camino, va y viene en línea recta entre dos puntos (`camino_defecto`). NO persiguen.
##   · La fila no se rompe NUNCA: la procesión pone la posición de cada ánima sobre el camino, a su distancia de la cabeza; ni los empujones ni los hechizos la desordenan. Eso es lo que permite
##     barrerlas con un haz (la «línea» del glifo ᛁ). Una ánima congelada, aturdida o enraizada para a TODA la fila (`velocidad_fila`).
##   · El GUÍA (la primera) lleva la CRUZ (`santa_compana_cruz`); las demás, la palmatoria (`santa_compana_vela`). Si a la procesión la atacan, solo el guía se gira y lanza una maldición con aviso.
##   · AL MORIR EL GUÍA: a los T_RELEVO s la cruz PASA a la siguiente de la fila (`AnimaCompana3D.hacer_guia`). Señal `cruz_pasada(numero)` (el `numero` de creación de la nueva guía).
##   · Si caen TODAS (las `n_animas`: tres) dentro de T_VENTANA s, la procesión se acaba de verdad: botín (tabla `anima`) y señal `procesion_rota()` (`motivo_fin = "ventana"`).
##   · Si no, la que quede REPONE la fila: a los T_REPONER s de caer cada una entra una ánima nueva por el extremo, hasta REPOSICIONES_MAX en total. Señal `repuesta(n)` (n = cuántas van). Agotadas
##     las reposiciones, cada baja ya no se repone y, cuando no queda ninguna ánima (ni esperando), la procesión se acaba también (`motivo_fin = "agotada"`): la salida alternativa, cara (n + 3 bajas
##     una a una) para que ninguna sala quede cerrada con llave.
##
## Una ánima de reposición se crea EN EL MOMENTO de la baja, latente (invisible y sin colisión) y en el grupo de combate: así el vigía de una sala (`VigiaPuzle`) la cuenta y no da la sala por limpia
## mientras queda alguien por entrar. Todas nacen con `casa` = la casilla de partida de la pieza (la `de=` del vigía).
##
## La procesión se mueve en `_physics_process`; `avanzar(delta)` hace lo mismo y es lo que llaman las pruebas.

signal cruz_pasada(indice: int)                   ## la cruz pasó a la ánima de ese `numero`
signal procesion_rota                             ## se acabó de verdad
signal repuesta(n: int)                           ## entró una ánima de reposición; n = reposiciones hechas

const VEL_FILA: float = 1.2                       ## u/s
const SEPARACION_CASILLAS: float = 1.0            ## casillas entre dos ánimas seguidas
const N_ANIMAS_DEFECTO: int = 3
const T_RELEVO: float = 1.0                       ## s desde que cae el guía hasta que la cruz pasa a la siguiente
const T_VENTANA: float = 2.5                      ## s: si caen todas dentro de esto, se acaba
const T_REPONER: float = 6.0                      ## s desde la baja hasta que entra la ánima nueva
const REPOSICIONES_MAX: int = 3
const T_PROVOCADA: float = 4.0                    ## s que la procesión sigue «atacada» tras recibir un golpe (el guía maldice mientras)
const CIERRE_VEL: float = 1.2                     ## u/s a los que las de atrás cierran el hueco de una baja
const ENTRADA_ATRAS_CASILLAS: float = 3.0         ## casillas por detrás del hueco desde las que entra la ánima nueva
const LARGO_DEFECTO_CASILLAS: int = 4             ## casillas del recorrido por defecto
const TABLA_BOTIN: String = "anima"               ## la fila `nada` de la tabla la pide `nucleo/botin.gd`

var mundo: Node3D = null
var jugador: Jugador3D = null
var lanz: Lanzador3D = null
var camino: Array[Vector2i] = []                  ## las casillas del recorrido (el bucle de ida y vuelta sale de ellas)
var n_animas: int = N_ANIMAS_DEFECTO
var animas: Array = []                            ## las ánimas vivas o por entrar, en orden de fila ([0] = cabeza); las latentes van al final
var s_cabeza: float = 0.0                         ## u recorridas por la cabeza sobre el bucle
var reposiciones: int = 0                         ## ánimas de reposición que ya han ENTRADO
var rota: bool = false
var motivo_fin: String = ""                       ## «ventana» | «agotada» | «» (las pruebas)
var bajas: int = 0                                ## ánimas caídas en total
var botin_soltado: Array = []
var quieto: bool = false                          ## la fila no avanza (los laboratorios lo ponen para tener dianas)
var _creadas: int = 0                             ## números de creación repartidos
var _programadas: int = 0                         ## reposiciones programadas (entradas o por entrar)
var _reloj: float = 0.0
var _muertes: Array = []                          ## relojes de las bajas recientes (la ventana)
var _reponer: Array = []                          ## [{t, anima}] reposiciones por entrar
var _t_relevo: float = -1.0                       ## > 0 = la cruz pasa en estos s; -1 = ningún relevo pendiente
var _t_provocada: float = 0.0
var _vertices: Array[Vector3] = []                ## el bucle de ida y vuelta, en el mundo
var _acum: Array[float] = []                      ## largo acumulado hasta cada vértice (la última entrada es el largo del bucle)
var _casa: Vector3 = Vector3.ZERO
var _ultima_baja: Vector3 = Vector3.ZERO


## Crea la procesión en el camino `p_camino` (casillas; vacío = el de por defecto desde `p_inicio`) con `p_animas` ánimas y la cuelga de `p_mundo`. Devuelve null si falta el modelo.
static func crear(p_mundo: Node3D, p_camino: Array, p_animas: int = N_ANIMAS_DEFECTO, p_inicio: Vector2i = Vector2i.ZERO, p_jugador: Jugador3D = null, p_lanz: Lanzador3D = null) -> SantaCompana3D:
	var sc := SantaCompana3D.new()
	sc.name = "SantaCompana_%d_%d" % [p_inicio.x, p_inicio.y]
	sc.mundo = p_mundo
	sc.jugador = p_jugador
	sc.lanz = p_lanz
	sc.n_animas = clampi(p_animas, 1, 8)
	var cam: Array[Vector2i] = []
	for c in p_camino:
		cam.append(c as Vector2i)
	if cam.size() < 2:
		cam = camino_defecto(p_inicio if cam.is_empty() else cam[0])
	sc.camino = cam
	sc._construir_bucle()
	sc.s_cabeza = float(sc.n_animas - 1) * sc.separacion()      # nacen en fila sobre el tramo de ida: la cabeza delante y las demás detrás, sin pasar de golpe a la vuelta
	sc._casa = Terreno3D.centro_de(cam[0], Terreno3D.y_pies(cam[0]))
	p_mundo.add_child(sc, true)
	for i in range(sc.n_animas):
		var a: AnimaCompana3D = sc._nueva_anima(i == 0)
		if a == null:
			sc.queue_free()
			return null
		a.desfase = float(i) * sc.separacion()
		sc.animas.append(a)
	sc._colocar_todas()
	return sc


## El recorrido de «va y viene en línea recta entre dos puntos»: desde `c` hacia el este, el sur, el oeste o el norte (el primer rumbo con sitio), hasta LARGO_DEFECTO_CASILLAS casillas o
## hasta donde se pueda pisar. Si no cabe ni una casilla en ningún rumbo, se queda una sola (la procesión no se mueve).
static func camino_defecto(c: Vector2i) -> Array[Vector2i]:
	var mejor: Array[Vector2i] = [c]
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var ruta: Array[Vector2i] = [c]
		for k in range(1, LARGO_DEFECTO_CASILLAS + 1):
			var s: Vector2i = c + (d as Vector2i) * k
			if not Terreno3D.en_mapa(s) or Terreno3D.bloqueada(s) or Terreno3D.es_agua(s):
				break
			ruta.append(s)
		if ruta.size() > mejor.size():
			mejor = ruta
		if mejor.size() > LARGO_DEFECTO_CASILLAS:
			break
	if mejor.size() < 2:
		mejor = [c, c]
	return mejor


func _nueva_anima(guia: bool) -> AnimaCompana3D:
	var a: AnimaCompana3D = AnimaCompana3D.crear(mundo, _casa, self, _creadas, guia, _casa, jugador, lanz)
	if a != null:
		_creadas += 1
	return a


func separacion() -> float:
	return SEPARACION_CASILLAS * Terreno3D.casilla


## =====================================================================================================
##  El bucle: el camino de ida y vuelta como una línea cerrada
## =====================================================================================================

func _construir_bucle() -> void:
	var pts: Array[Vector3] = []
	for c in camino:
		pts.append(Terreno3D.centro_de(c, Terreno3D.y_pies(c)))
	var v: Array[Vector3] = pts.duplicate()
	for i in range(pts.size() - 2, 0, -1):
		v.append(pts[i])                              # la vuelta, sin repetir los extremos
	_vertices = v
	_acum = [0.0]
	var total: float = 0.0
	for i in range(_vertices.size()):
		total += _vertices[i].distance_to(_vertices[(i + 1) % _vertices.size()])
		_acum.append(total)


func largo_bucle() -> float:
	return _acum[_acum.size() - 1] if not _acum.is_empty() else 0.0


## El punto del bucle a `s` u de su inicio (se da la vuelta solo) y hacia dónde se va allí. {pos, dir}.
func punto_en(s: float) -> Dictionary:
	var largo: float = largo_bucle()
	if largo < 0.01 or _vertices.is_empty():
		return {"pos": _casa, "dir": Vector3(0, 0, 1)}
	var t: float = fposmod(s, largo)
	var i: int = 0
	while i < _vertices.size() - 1 and _acum[i + 1] <= t:
		i += 1
	var a: Vector3 = _vertices[i]
	var b: Vector3 = _vertices[(i + 1) % _vertices.size()]
	var seg: float = _acum[i + 1] - _acum[i]
	var k: float = (t - _acum[i]) / maxf(seg, 0.0001)
	var d: Vector3 = b - a
	d.y = 0.0
	return {"pos": a.lerp(b, k), "dir": d.normalized() if d.length() > 0.001 else Vector3(0, 0, 1)}


## =====================================================================================================
##  Fotograma: avanza la fila, repone y cuenta atrás del relevo
## =====================================================================================================

func _physics_process(delta: float) -> void:
	avanzar(delta)


func avanzar(delta: float) -> void:
	if rota:
		return
	_reloj += delta
	_t_provocada = maxf(0.0, _t_provocada - delta)
	_avanzar_fila(delta)
	_avanzar_relevo(delta)
	_avanzar_reposiciones(delta)


## ¿La fila anda ahora?
func en_marcha() -> bool:
	return not quieto and velocidad_fila() > 0.01 and largo_bucle() > 0.01


## La velocidad de la fila (u/s): VEL_FILA × lo que deje la más frenada. Una ánima congelada, aturdida o enraizada la para entera.
func velocidad_fila() -> float:
	var f: float = 1.0
	var hay: bool = false
	for a in animas:
		var an: AnimaCompana3D = a
		if not is_instance_valid(an) or an.muerto or an.latente:
			continue
		hay = true
		f = minf(f, an.factor_marcha())
	return VEL_FILA * f if hay else 0.0


func _avanzar_fila(delta: float) -> void:
	if en_marcha():
		s_cabeza += velocidad_fila() * delta
	var i: int = 0
	for a in animas:
		var an: AnimaCompana3D = a
		if not is_instance_valid(an) or an.muerto or an.latente:
			continue
		an.desfase = move_toward(an.desfase, float(i) * separacion(), CIERRE_VEL * delta)
		i += 1
	_colocar_todas()


## Pone cada ánima viva en su sitio del bucle (x y z; la altura la ajusta su propio `_ajustar_al_suelo`) y mirando hacia donde va la fila (salvo el guía mientras maldice).
func _colocar_todas() -> void:
	for a in animas:
		var an: AnimaCompana3D = a
		if not is_instance_valid(an) or an.muerto or an.latente:
			continue
		var p: Dictionary = punto_en(s_cabeza - an.desfase)
		var pos: Vector3 = p["pos"]
		an.position.x = pos.x
		an.position.z = pos.z
		if not an.maldiciendo:
			an.mirada = p["dir"]


## =====================================================================================================
##  Bajas: relevo de la cruz, ventana, reposición, final
## =====================================================================================================

## El golpe a una ánima: la procesión queda «atacada» T_PROVOCADA s y su guía maldice.
func al_ser_atacada(_a: AnimaCompana3D) -> void:
	_t_provocada = T_PROVOCADA


func provocada() -> bool:
	return _t_provocada > 0.0


## La llama cada ánima al caer (después de morir: su `muerto` ya es true).
func al_morir(a: AnimaCompana3D) -> void:
	if rota:
		return
	bajas += 1
	_ultima_baja = a.position
	var era_guia: bool = a.es_guia
	animas.erase(a)
	_muertes.append(_reloj)
	while not _muertes.is_empty() and _reloj - float(_muertes[0]) > T_VENTANA:
		_muertes.pop_front()
	if _muertes.size() >= n_animas:
		_acabar("ventana")
		return
	if era_guia:
		_t_relevo = T_RELEVO
	if _programadas < REPOSICIONES_MAX:
		_programadas += 1
		var nueva: AnimaCompana3D = _nueva_anima(false)
		if nueva != null:
			nueva.esperar_fuera()
			animas.append(nueva)
			_reponer.append({"t": T_REPONER, "anima": nueva})
	if animas.is_empty():
		_acabar("agotada")


func _avanzar_relevo(delta: float) -> void:
	if _t_relevo < 0.0:
		return
	_t_relevo -= delta
	if _t_relevo > 0.0:
		return
	_t_relevo = -1.0
	_pasar_cruz()


## La cruz pasa a la primera ánima viva de la fila (si no hay ninguna, se hará cuando entre una).
func _pasar_cruz() -> void:
	for a in animas:
		var an: AnimaCompana3D = a
		if is_instance_valid(an) and not an.muerto and not an.latente:
			an.hacer_guia()
			cruz_pasada.emit(an.numero)
			PlayLog.event("compana_cruz_pasada", {"numero": an.numero})
			return


func _hay_guia() -> bool:
	for a in animas:
		if is_instance_valid(a) and not (a as AnimaCompana3D).muerto and (a as AnimaCompana3D).es_guia:
			return true
	return false


func _avanzar_reposiciones(delta: float) -> void:
	for r in _reponer.duplicate():
		r["t"] = float(r["t"]) - delta
		if float(r["t"]) > 0.0:
			continue
		_reponer.erase(r)
		var an: AnimaCompana3D = r["anima"]
		if not is_instance_valid(an):
			continue
		var cola: int = 0
		for a in animas:
			if a != an and is_instance_valid(a) and not (a as AnimaCompana3D).muerto and not (a as AnimaCompana3D).latente:
				cola += 1
		an.desfase = float(cola) * separacion() + ENTRADA_ATRAS_CASILLAS * Terreno3D.casilla
		an.entrar()
		# Va al final de la fila, detrás de todas las vivas (las latentes que quedan por entrar ya estaban detrás).
		animas.erase(an)
		animas.insert(cola, an)
		reposiciones += 1
		repuesta.emit(reposiciones)
		PlayLog.event("compana_repuesta", {"n": reposiciones})
		if not _hay_guia() and _t_relevo < 0.0:
			_t_relevo = T_RELEVO


## Se acaba de verdad: botín, y las ánimas que esperaban entrar se van sin salir.
func _acabar(motivo: String) -> void:
	rota = true
	motivo_fin = motivo
	_reponer.clear()
	for a in animas:
		if is_instance_valid(a) and (a as AnimaCompana3D).latente:
			var pj: Pj3D = (a as AnimaCompana3D).pj
			if pj != null and is_instance_valid(pj):
				pj.queue_free()
			(a as AnimaCompana3D).queue_free()
	animas = animas.filter(func(x: Variant) -> bool: return is_instance_valid(x) and not (x as AnimaCompana3D).latente)
	botin_soltado = Botin.tirar(TABLA_BOTIN)
	Botin.soltar(mundo, _ultima_baja, botin_soltado, jugador)
	PlayLog.event("compana_rota", {"motivo": motivo, "bajas": bajas})
	procesion_rota.emit()


## Las ánimas que están en la fila ahora (sin las muertas ni las que esperan entrar).
func vivas() -> Array:
	var r: Array = []
	for a in animas:
		if is_instance_valid(a) and not (a as AnimaCompana3D).muerto and not (a as AnimaCompana3D).latente:
			r.append(a)
	return r

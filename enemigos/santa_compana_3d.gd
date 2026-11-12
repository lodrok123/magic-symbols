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
##   · AL MORIR EL GUÍA (12/11, con animación): su cruz SE QUEDA EN EL SUELO donde cayó (`cruz_suelo`, la pieza `cruz_santa` tumbada) y la fila se PARA. La siguiente cierra el hueco hasta esa
##     casilla a CIERRE_RELEVO_VEL u/s (2,3 u en ~1 s: T_RELEVO es el mínimo que espera antes de agacharse) y la RECOGE con `AnimaCompana3D.recoger_cruz` (clip `CollectObject`, T_RECOGER s): la cruz
##     se le engancha en la mano a los T_ENGANCHE s de empezar (`al_recoger`: señal `cruz_pasada(numero)` con el `numero` de creación de la nueva guía) y la fila sigue cuando se endereza.
##     Si la ánima no llega en T_LLEGADA_MAX s se agacha donde esté. Si la cortan a medias (la matan o la paran), la cruz sigue en el suelo y se reintenta a los T_REINTENTO s con la siguiente.
##   · Si caen TODAS (las `n_animas`: tres) dentro de T_VENTANA s, la procesión se acaba de verdad: botín (tabla `anima`) y señal `procesion_rota()` (`motivo_fin = "ventana"`).
##   · Si no, la que quede REPONE la fila: a los T_REPONER s de caer cada una entra una ánima nueva por la COLA, hasta REPOSICIONES_MAX en total. 12/11: primero se la espera (T_REPONER − la
##     duración del clip = 3,3 s, invisible) y luego SURGE DE LA TIERRA los últimos 2,7 s (clip Getting_Up; sube desde bajo el suelo; ver `AnimaCompana3D`) en la casilla que va detrás de la última
##     ánima viva (`_empezar_surgir`); el clip acaba justo al cumplirse T_REPONER y entonces es un enemigo de verdad (`entrar`: colisión y grupos de combate). Señal `repuesta(n)` (n = cuántas van). Agotadas
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
const T_RELEVO: float = 1.0                       ## s desde que cae el guía hasta que la siguiente se agacha a por la cruz (la cruz se le engancha T_ENGANCHE s después)
const T_REINTENTO: float = 0.5                    ## s hasta volver a intentar el relevo si cortaron la recogida
const T_LLEGADA_MAX: float = 4.0                  ## s esperando a que la siguiente llegue a la cruz; pasado esto se agacha donde esté
const CIERRE_RELEVO_VEL: float = 2.4              ## u/s a los que la siguiente cierra el hueco mientras hay una cruz en el suelo (a 1,2 tardaba 1,9 s en llegar)
const LLEGADA_DESFASE: float = 0.05               ## u de desfase por debajo de los que la ánima «ha llegado» a su sitio (el de la cruz)
const SALIDAS_ATRAS: int = 4                      ## casillas más hacia atrás del camino que se prueban si donde toca surgir la repuesta no está libre
const CRUZ_ADELANTE: float = 0.22                 ## u por delante de la casilla del guía donde queda la cruz (bajo las manos de quien llega agachándose)
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
var cruz_suelo: Node3D = null                     ## la cruz caída esperando a que la recojan (null = no hay)
var recogidas: int = 0                            ## cruces que han acabado en la mano de otra ánima (pruebas)
var quieto: bool = false                          ## la fila no avanza (los laboratorios lo ponen para tener dianas)
var _creadas: int = 0                             ## números de creación repartidos
var _programadas: int = 0                         ## reposiciones programadas (entradas o por entrar)
var _reloj: float = 0.0
var _muertes: Array = []                          ## relojes de las bajas recientes (la ventana)
var _reponer: Array = []                          ## [{t, anima}] reposiciones por entrar
var _t_relevo: float = -1.0                       ## > 0 = la siguiente se agacha a por la cruz en estos s; -1 = ningún relevo pendiente
var _relevo_listo: bool = false                   ## pasó T_RELEVO: espera a que la primera de la fila llegue a la cruz
var _t_llegada: float = 0.0
var _recogiendo: AnimaCompana3D = null            ## la que se agacha ahora
var _cerrando: bool = false                       ## alguna ánima está cerrando hueco (anda aunque la fila esté parada)
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


## ¿La fila anda ahora? No mientras hay una cruz en el suelo o alguien se agacha a por ella.
func en_marcha() -> bool:
	return not quieto and not fila_parada() and velocidad_fila() > 0.01 and largo_bucle() > 0.01


## Hay una cruz caída que recoger (o alguien en ello): la fila no avanza.
func fila_parada() -> bool:
	return cruz_suelo != null or _relevo_listo or _recogiendo != null or _t_relevo >= 0.0


## Las ánimas se mueven (andan con el clip): la fila va, o alguna cierra el hueco de una baja.
func hay_movimiento() -> bool:
	return en_marcha() or _cerrando


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
	var vel_cierre: float = CIERRE_RELEVO_VEL if cruz_suelo != null else CIERRE_VEL
	_cerrando = false
	for a in animas:
		var an: AnimaCompana3D = a
		if not is_instance_valid(an) or an.muerto or an.latente:
			continue
		var meta: float = float(i) * separacion()
		if absf(an.desfase - meta) > 0.01 and not an.recogiendo:
			_cerrando = true
		var vc: float = vel_cierre if absf(an.desfase - meta) <= 1.5 * separacion() else CIERRE_RELEVO_VEL      # la repuesta que se queda atrás al surgir se une corriendo más
		an.desfase = move_toward(an.desfase, meta, vc * delta)
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
		_soltar_cruz(a)
		_recogiendo = null
		_relevo_listo = false
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
	if _t_relevo >= 0.0:
		_t_relevo -= delta
		if _t_relevo <= 0.0:
			_t_relevo = -1.0
			_relevo_listo = true
			_t_llegada = 0.0
	if _relevo_listo:
		_pasar_cruz(delta)


## Pasada la espera, la primera ánima viva de la fila va a la cruz del suelo y, al llegar (o pasado T_LLEGADA_MAX), se agacha a recogerla (si no hay ninguna viva, se hará cuando entre una). Sin
## cruz en el suelo (no debería ocurrir) se la pone de golpe, como antes del 12/11.
func _pasar_cruz(delta: float) -> void:
	for a in animas:
		var an: AnimaCompana3D = a
		if not is_instance_valid(an) or an.muerto or an.latente:
			continue
		if cruz_suelo == null:
			an.hacer_guia()
			_relevo_listo = false
			cruz_pasada.emit(an.numero)
			PlayLog.event("compana_cruz_pasada", {"numero": an.numero})
			return
		_t_llegada += delta
		if an.desfase <= LLEGADA_DESFASE or _t_llegada >= T_LLEGADA_MAX:
			if an.recoger_cruz():
				_recogiendo = an
				_relevo_listo = false
		return


## La ánima `a` ha enganchado la cruz en su mano (a los T_ENGANCHE s de agacharse): la cruz del suelo desaparece y se avisa.
func al_recoger(a: AnimaCompana3D) -> void:
	_quitar_cruz_suelo()
	recogidas += 1
	cruz_pasada.emit(a.numero)
	PlayLog.event("compana_cruz_pasada", {"numero": a.numero})


## La ánima `a` se ha enderezado con la cruz: la fila vuelve a andar.
func al_enderezarse(a: AnimaCompana3D) -> void:
	if _recogiendo == a:
		_recogiendo = null


## Cortaron a `a` antes de que enganchara la cruz: sigue en el suelo y se reintenta enseguida (con ella o con la que esté primera).
func cruz_sin_recoger(a: AnimaCompana3D) -> void:
	if _recogiendo == a:
		_recogiendo = null
	_relevo_listo = false
	if cruz_suelo != null:
		_t_relevo = T_REINTENTO


## La cruz del guía caído se queda en el suelo, tumbada y atravesada a la marcha, un poco por delante de donde cayó. La que llevaba en la mano se esconde.
func _soltar_cruz(guia: AnimaCompana3D) -> void:
	_quitar_cruz_suelo()
	var pj: Pj3D = guia.pj
	var escala: float = Equipo3D.CRUZ_ESCALA
	if pj != null and is_instance_valid(pj) and pj._modelo != null:
		escala *= pj.scale.y
		for n in pj._modelo.find_children("*", "Node3D", true, false):
			if n.has_meta("equipo_id") and String(n.get_meta("equipo_id")) == "cruz_santa":
				(n as Node3D).visible = false
	var dir: Vector3 = guia.mirada
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	var raiz := Node3D.new()
	raiz.name = "CruzSuelo"
	mundo.add_child(raiz)
	raiz.position = guia.position + dir * CRUZ_ADELANTE
	raiz.rotation.y = atan2(dir.x, dir.z)
	var cruz: Node3D = Equipo3D.pieza("cruz_santa")
	raiz.add_child(cruz)
	cruz.scale = Vector3.ONE * escala
	cruz.rotation_degrees = Vector3(0.0, 0.0, 90.0)             # el mango, que es su eje Y, pasa a horizontal (a lo largo de X: atravesado a la marcha)
	var caja: AABB = Mamoa3D._caja_modelo(raiz)
	if caja.size.x > 0.0001 or caja.size.y > 0.0001:
		cruz.position = Vector3(-(caja.position.x + caja.size.x * 0.5), -caja.position.y, -(caja.position.z + caja.size.z * 0.5))
	cruz_suelo = raiz


func _quitar_cruz_suelo() -> void:
	if cruz_suelo != null and is_instance_valid(cruz_suelo):
		cruz_suelo.queue_free()
	cruz_suelo = null


func _exit_tree() -> void:
	_quitar_cruz_suelo()


func _hay_guia() -> bool:
	for a in animas:
		if is_instance_valid(a) and not (a as AnimaCompana3D).muerto and (a as AnimaCompana3D).es_guia:
			return true
	return false


func _avanzar_reposiciones(delta: float) -> void:
	for r in _reponer.duplicate():
		r["t"] = float(r["t"]) - delta
		var an: AnimaCompana3D = r["anima"]
		if not is_instance_valid(an):
			_reponer.erase(r)
			continue
		# Los últimos `dur_surgir()` s de la espera, sale de la tierra detrás de la cola (primero se la espera, luego sale: el clip acaba justo al cumplirse T_REPONER).
		if not r.has("s0") and an.dur_surgir() > 0.0 and float(r["t"]) <= an.dur_surgir():
			r["s0"] = _empezar_surgir(an)
		if float(r["t"]) > 0.0:
			continue
		_reponer.erase(r)
		var cola: int = 0
		for a in animas:
			if a != an and is_instance_valid(a) and not (a as AnimaCompana3D).muerto and not (a as AnimaCompana3D).latente:
				cola += 1
		if r.has("s0"):
			an.desfase = maxf(s_cabeza - float(r["s0"]), float(cola) * separacion())      # donde la dejó la fila al seguir andando; el hueco lo cierra andando (CIERRE_RELEVO_VEL)
		else:
			an.desfase = float(cola) * separacion() + ENTRADA_ATRAS_CASILLAS * Terreno3D.casilla       # sin clip de surgir: entra de golpe por detrás, como antes del 12/11
		an.entrar()
		# Va al final de la fila, detrás de todas las vivas (las latentes que quedan por entrar ya estaban detrás).
		animas.erase(an)
		animas.insert(cola, an)
		reposiciones += 1
		repuesta.emit(reposiciones)
		PlayLog.event("compana_repuesta", {"n": reposiciones})
		if not _hay_guia() and _t_relevo < 0.0 and not _relevo_listo and _recogiendo == null:
			_t_relevo = T_RELEVO


## La ánima repuesta `an` empieza a surgir de la tierra DETRÁS de la última ánima viva (o que ya esté surgiendo): su casilla es la que va a una separación de ella sobre el recorrido
## (`s_cabeza − k·separación`), y si no está libre (bloqueada, agua o con un bloque encima), la siguiente hacia atrás del camino, hasta SALIDAS_ATRAS casillas más. Queda quieta ahí mirando
## hacia donde va la fila (la fila sigue andando y la deja atrás: se le une al acabar, ver `_avanzar_reposiciones`). Devuelve la coordenada `s` del bucle donde sale.
func _empezar_surgir(an: AnimaCompana3D) -> float:
	var k: int = 0
	for a in animas:
		if a != an and is_instance_valid(a) and not (a as AnimaCompana3D).muerto and (not (a as AnimaCompana3D).latente or (a as AnimaCompana3D).surgiendo):
			k += 1
	var elegida: int = k
	for i in range(SALIDAS_ATRAS + 1):
		var c: Vector2i = Terreno3D.celda_de(punto_en(s_cabeza - float(k + i) * separacion())["pos"] as Vector3)
		if _casilla_libre(c):
			elegida = k + i
			break
	var s0: float = s_cabeza - float(elegida) * separacion()
	var p: Dictionary = punto_en(s0)
	var pos: Vector3 = p["pos"]
	var celda: Vector2i = Terreno3D.celda_de(pos)
	an.mirada = p["dir"]
	an.surgir_en(Vector3(pos.x, Terreno3D.y_pies(celda), pos.z))
	PlayLog.event("compana_surge", {"celda": [celda.x, celda.y], "detras_de": k})
	return s0


func _casilla_libre(c: Vector2i) -> bool:
	return Terreno3D.en_mapa(c) and not Terreno3D.bloqueada(c) and not Terreno3D.es_agua(c) and BloqueEmpujable3D.en(c) == null


## Se acaba de verdad: botín, y las ánimas que esperaban entrar se van sin salir.
func _acabar(motivo: String) -> void:
	rota = true
	motivo_fin = motivo
	_reponer.clear()
	_t_relevo = -1.0
	_relevo_listo = false
	_quitar_cruz_suelo()
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

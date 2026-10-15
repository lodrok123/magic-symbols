class_name Gatopedro3D
extends Combate3D
## El Gatopedro (el lince cornudo, nombre oficial desde el 14/10): un enemigo que NO ataca, HUYE.
##
## Para qué sirve (Pablo): es el objetivo del tutorial de la Terra Fina. Como se escapa, el jugador no puede esperar a tenerlo
## delante para ponerse a dibujar una runa: tiene que usar las PÁGINAS del grimorio (1/2/3, con el libro cerrado) y disparar
## sobre la marcha. Por eso el diseño no es «correr más que tú», sino ofrecer ventanas de tiro:
##   - Te detecta como a un goblin (RADIO_DETECCION y línea de visión) y echa a correr en dirección contraria.
##   - Corre a tramos: TRAMO_CARRERA corriendo y TRAMO_PARADA quieto mirándote. Corre más que andas (1,6) y menos que corres (3,0):
##     si lo persigues a pie lo alcanzas, pero lento; con una flecha de la página lo tienes antes (alcance de hechizo: 3 casillas).
##   - Si estás muy cerca (DIST_SIN_PARADA) o acaba de recibir un golpe, no se para: huye sin pausas y algo más rápido.
##   - No se aleja más de RADIO_CASA de su sitio: rodea en vez de irse del tutorial. Si pierde de vista al jugador, vuelve a casa.
##
## Definición de enemigo (Pablo): «debe caer con 2 flechas de fuego». El fuego de la página hace 40 de daño (fire_rune.tres) y deja
## ardiendo 3 s (3 de daño cada 0,5 s = hasta 18 más). Con VIDA = 70: una flecha + toda la quemadura = 58 -> sobrevive; dos flechas
## = 80 -> cae. (Con otro elemento la cuenta es la del resto de enemigos: sin debilidad ni resistencia, 1,0 × el daño del hechizo.)
## Si se cambia el daño del fuego o la quemadura, hay que revisar VIDA: lo comprueba herramientas/prueba_gatopedro.gd.
##
## Todo lo medible está en constantes. Las marcadas ESTIMADO no se han visto en el juego: afinar a ojo.

const ID_MODELO: String = "lince"
const NOMBRE_OFICIAL: String = "Gatopedro"
const VIDA: float = 70.0                  ## ver arriba: 2 flechas de fuego (80) lo tumban, 1 flecha + quemadura (58) no
const ORO_GATOPEDRO: int = 15
const VEL_HUIDA: float = 2.6              ## u/s corriendo (ESTIMADO): entre andar (1,6) y correr (3,0) del jugador
const MULT_SUSTO: float = 1.3             ## × la velocidad mientras está asustado por un golpe
const T_SUSTO: float = 2.0                ## s que dura el susto tras recibir un hechizo vivo
const TRAMO_CARRERA: float = 1.2          ## s corriendo antes de poder pararse (ESTIMADO)
const TRAMO_PARADA: float = 0.9           ## s quieto mirándote: la ventana de tiro (ESTIMADO)
const DIST_SIN_PARADA: float = 3.5        ## más cerca que esto no se para (ESTIMADO)
const RADIO_CASA: float = 9.0             ## no se aleja más de esto de su sitio (huye en círculo en vez de irse)
const VEL_PASEO: float = 0.3              ## u/s de su paseo tranquilo (ESTIMADO; el clip walk va a ~0,23 u/s a velocidad normal)
const VEL_VUELTA: float = 1.2             ## u/s al volver a casa tras perderte de vista
## u/s que recorre el suelo con el clip a velocidad 1 (ya contando VEL_CLIP_PJ). `walk`: 0,46 × 0,5 que anotó el Pipeline (entrada 59).
## `run` (gallop): midiendo el apoyo de la pata en los dos clips del GLB, el galope va 4,0 veces más rápido que el walk al mismo
## escalado -> 1,85 u/s. ESTIMADO: las dos cifras salen de una medida a ojo del apoyo; si patina, tocar solo estas dos.
const ZANCADA_WALK: float = 0.23
const ZANCADA_RUN: float = 1.85
const AVANCE_SONDEO: float = 1.15         ## a qué distancia mira si puede pisar para elegir rumbo (media casilla)
const ANGULOS_HUIDA: Array = [0.0, 35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0, -150.0, 180.0]   ## grados respecto a «directo contra ti»

var _t_tramo: float = 0.0
var _parado: bool = false
var _t_susto: float = 0.0
var _rumbo: Vector3 = Vector3.ZERO        ## último rumbo elegido (da histéresis: sin esto zigzaguea entre dos rumbos casi iguales)
var _vel_real: float = 0.0                ## u/s que lleva este frame (la usa _animar para que las patas no patinen)


## Le cuelga el comportamiento de Gatopedro a un modelo `lince` que ya está en el mundo.
static func equipar_gatopedro(modelo: Pj3D, p_mundo: Node3D, p_jugador: Jugador3D, p_lanz: Lanzador3D) -> Gatopedro3D:
	var c := Gatopedro3D.new()
	c.name = "Gatopedro_" + modelo.id
	c.pj = modelo
	c.mundo = p_mundo
	c.jugador = p_jugador
	c.lanz = p_lanz
	c.position = modelo.position
	c.casa = modelo.position
	c.altura = modelo.alto_modelo() * modelo.scale.y
	# Antes de add_child: `_ready` de Combate3D copia vida_max a health y construye la barra con estos valores.
	c.nombre = NOMBRE_OFICIAL
	c.vida_max = VIDA
	c.debil = ""
	c.resiste = ""
	c.tinte = Color.WHITE
	c.oro = ORO_GATOPEDRO
	c.snd_alerta = "gato_maullido"
	c.snd_muere = "gato_maullido"
	p_mundo.add_child(c, true)
	c._marca_debil.visible = false          # sin debilidad no hay rombo de elemento
	return c


## Crea un Gatopedro en `pos` (modelo nuevo + comportamiento). Lo usa Mayús+F11 del Jugador3D (banco de pruebas) y servirá a
## cualquier marcador del nivel que lo pida. Devuelve null si falta el modelo.
static func invocar(p_mundo: Node3D, p_jugador: Jugador3D, p_lanz: Lanzador3D, pos: Vector3) -> Gatopedro3D:
	var modelo: Pj3D = p_mundo.call("_personaje", [ID_MODELO], pos)
	if modelo == null:
		return null
	var lista: Variant = p_mundo.get("_goblins")
	if lista is Array:
		(lista as Array).append(modelo)
	return equipar_gatopedro(modelo, p_mundo, p_jugador, p_lanz)


## Un hechizo que no lo mata lo asusta (huye sin pausas y más rápido unos segundos), lo vea o no.
func golpe(rune_data: RuneData, direccion: Vector3) -> void:
	var vivo_antes: bool = not muerto
	super.golpe(rune_data, direccion)
	if vivo_antes and not muerto:
		_t_susto = T_SUSTO
		if estado != "huye":
			_alertar()


func _alertar() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	estado = "huye"
	objetivo = jugador
	vista_perdida = 0.0
	ultima_pos = jugador.position
	_parado = false
	_t_tramo = TRAMO_CARRERA
	flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0), "!", Color(1, 0.85, 0.2))
	Sfx3D.play(self, snd_alerta)
	PlayLog.event("gatopedro_huye", {"distancia": snappedf(_dist(jugador.position), 0.1), "vida": snappedf(health, 0.1)})


func _ia(delta: float) -> void:
	_vel_real = 0.0
	# Lo mismo que Combate3D: retroceso por golpes, aturdimiento, hielo e interrupción lo dejan quieto.
	if _empuje.length() > 0.1:
		_mover_paso(_empuje * delta)
		_empuje = _empuje.lerp(Vector3.ZERO, clampf(7.0 * delta, 0.0, 1.0))
	if stun_timer > 0.0:
		stun_timer -= delta
		moviendo = 0
		return
	if congelado > 0.0:
		moviendo = 0
		return
	if interrupcion > 0.0:
		interrupcion -= delta
		moviendo = 0
		return
	_t_susto = maxf(0.0, _t_susto - delta)
	var vel: float = vel_mult()
	if _ve(RADIO_SOLTAR if estado == "huye" else RADIO_DETECCION):
		if estado != "huye":
			_alertar()
		vista_perdida = 0.0
		ultima_pos = jugador.position
	elif estado == "huye":
		vista_perdida += delta
		var lejos: bool = jugador == null or _dist(jugador.position) > RADIO_SOLTAR
		if vista_perdida > TIEMPO_PERDER or lejos:
			objetivo = null
			estado = "vuelve"
			PlayLog.event("gatopedro_se_calma")
	match estado:
		"huye":
			_huir(delta, vel)
		"vuelve":
			var h: Vector3 = casa - position
			h.y = 0.0
			if h.length() < 0.25:
				estado = "patrulla"
				moviendo = 0
			else:
				mirada = h.normalized()
				moviendo = 2
				_vel_real = VEL_VUELTA * vel
				if not _mover_paso(h.normalized() * _vel_real * delta):
					estado = "patrulla"
		_:
			_pasear(delta, vel)


func _pasear(delta: float, vel: float) -> void:
	moviendo = 1
	mirada = Vector3(_direccion, 0.0, 0.0)
	_vel_real = VEL_PASEO * vel
	var movido: bool = _mover_paso(mirada * _vel_real * delta)
	if not movido or absf(position.x - casa.x) >= DISTANCIA_PATRULLA:
		_direccion *= -1.0


## Huye de donde te vio por última vez: a tramos (carrera / parada) y esquivando lo que no se pisa.
func _huir(delta: float, vel: float) -> void:
	var fuera: Vector3 = position - ultima_pos
	fuera.y = 0.0
	var d_jug: float = fuera.length()
	var asustado: bool = _t_susto > 0.0
	# Alterna carrera y parada. Cerca de ti o asustado nunca se para.
	_t_tramo -= delta
	if _t_tramo <= 0.0:
		if _parado:
			_parado = false
			_t_tramo = TRAMO_CARRERA
		elif not asustado and d_jug > DIST_SIN_PARADA:
			_parado = true
			_t_tramo = TRAMO_PARADA
		else:
			_t_tramo = TRAMO_CARRERA
	if asustado or d_jug <= DIST_SIN_PARADA:
		_parado = false
	var directo: Vector3 = fuera.normalized() if d_jug > 0.05 else -mirada
	if _parado:
		moviendo = 0
		mirada = -directo                     # quieto, mirándote: es la ventana de tiro
		return
	var dir: Vector3 = _elegir_rumbo(directo)
	if dir == Vector3.ZERO:                  # acorralado: se queda mirándote (y se le puede disparar)
		moviendo = 0
		mirada = -directo
		return
	mirada = dir
	var v: float = VEL_HUIDA * vel * (MULT_SUSTO if asustado else 1.0)
	if _mover_paso(dir * v * delta):
		moviendo = 2
		_vel_real = v
		_rumbo = dir
	else:
		moviendo = 0


## Entre los rumbos posibles (el directo contra ti y giros de hasta 180°) elige el que se pueda pisar a una y a dos sondas
## (AVANCE_SONDEO y una casilla) y deje más lejos de ti, sin alejarse más de RADIO_CASA de su sitio. Devuelve ZERO si no hay ninguno.
func _elegir_rumbo(directo: Vector3) -> Vector3:
	var mejor: Vector3 = Vector3.ZERO
	var mejor_p: float = -INF
	for a in ANGULOS_HUIDA:
		var dir: Vector3 = directo.rotated(Vector3.UP, deg_to_rad(float(a)))
		var p1: Vector3 = position + dir * AVANCE_SONDEO
		if not _puede_estar(p1):
			continue
		var p2: Vector3 = position + dir * 2.3
		var punt: float = Vector2(p2.x - ultima_pos.x, p2.z - ultima_pos.z).length()
		if not _puede_estar(p2):
			punt -= 1.5                      # pasa la primera sonda pero la segunda da en pared: callejón probable
		punt -= 0.25 * maxf(0.0, Vector2(p2.x - casa.x, p2.z - casa.z).length() - RADIO_CASA)
		punt -= 0.01 * absf(float(a))        # a igualdad, el más directo
		if _rumbo != Vector3.ZERO:
			punt += 0.6 * dir.dot(_rumbo)    # histéresis
		if punt > mejor_p:
			mejor_p = punt
			mejor = dir
	return mejor


## Combate3D pone aquí el clip según `moviendo`; este solo ajusta a qué ritmo, para que las patas no patinen, y lo gira hacia
## donde mira cuando está quieto huyendo (la base solo gira si se mueve o si «persigue»).
func _animar() -> void:
	super._animar()
	if _t_anim > 0.0 or congelado > 0.0 or stun_timer > 0.0:
		return
	if moviendo > 0 and _vel_real > 0.0:
		var ref: float = ZANCADA_RUN if moviendo == 2 else ZANCADA_WALK
		pj.set_velocidad_animacion(clampf(_vel_real / ref, 0.4, 2.5))
	elif moviendo == 0 and estado == "huye" and mirada.length() > 0.01:
		pj.mirar(mirada, 0.1)

class_name Chaman3D
extends Combate3D

## E2 · CHAMÁN GOBLIN (docs/PROPUESTA_COMBATE.md §4 y §7; reglas de Pablo del 28/10). Dueño: Juego.
##
## Pregunta que plantea: «¿a quién ataco primero?». Las reglas:
##   · PRIMERO ESCUDA. Si hay aliados (goblins, Combate3D vivos a ≤ ALIADOS_CASILLAS casillas de él) SIN escudo de naturaleza y ya no está en enfriamiento, va a un sitio DETRÁS de ellos
##     (a ESPALDAS_ALIADOS u del centro del grupo, del lado opuesto a la jugadora) y hace el RITUAL (`ChamanRitual`): traza con el bastón, en el suelo, un ROMBO dentro de un sello circular
##     (el trazo ES el aviso: se ve venir) y lo clava; a los AnimacionesChaman.INSTANTE_CLAVAR s sale una ONDA VERDE (RunaSuelo3D) que da un ESCUDO DE NATURALEZA (`EscudoNaturaleza3D`:
##     absorbe ESCUDO_VIDA de daño; el fuego lo quema de un golpe) a cada aliado al que llega (≈ ONDA_CASILLAS casillas desde la runa).
##   · Con todos los aliados escudados (o sin aliados) SE MANTIENE LEJOS de la jugadora (entre DIST_MIN y DIST_MAX u: se acerca si está más lejos, RETROCEDE si se acerca) y le tira BOLAS DE VENENO
##     (`BolaVeneno3D`: arco visible, aviso en el suelo, daño pequeño y veneno) cada CD_BOLA s con línea libre.
##   · Si le pegan, lo aturden, lo congelan o lo empujan MIENTRAS TRAZA, el ritual se interrumpe: la runa se rompe (`cancelar`) y espera CD_RITUAL s para volver a intentarlo. Con la onda ya
##     fuera (tras clavar) ya no hay nada que romper.
##   · Vida baja (VIDA).
## Es un `Combate3D` (vida, barra, estados, empujes, previsión, vigía: se heredan) con modelo Pj3D `goblin_chaman`. Se sustituyen la IA, el dibujo de su animación mientras dura el ritual y la
## muerte. Se pone desde un mapa con la pieza `chaman` de Puzle3D o con `Chaman3D.invocar_chaman`.

signal ritual_empezado
signal ritual_roto
signal ritual_completado
signal bola_lanzada(bola: BolaVeneno3D)
signal flecha_lanzada(flecha: Node3D)

## 6/11 (Pablo): CHAMÁN V2. Con `CHAMAN_V2 = true` decide por PRIORIDADES (curar al aliado herido → escudar → atacar), ataca sobre todo con FLECHAS DE VENENO (rectas, rápidas, 4 de daño y una pila de
## veneno) y deja la bola de veneno como ataque de área para quien se queda quieto o se esconde; además suelta un antídoto el 50 % de las veces (fila `chaman` de botin_tablas.tsv). Con `false` se
## comporta como el 28/10 (escudar → bolas cada 3 s), para poder compararlos. Lo cambian las pruebas y el laboratorio.
static var CHAMAN_V2: bool = true
const UMBRAL_CURAR: float = 0.6                 ## v2: un aliado con menos de esta fracción de vida pide el ritual de CURAR
const CURA_RITUAL: float = 20.0                 ## v2: vida que da la onda del ritual de curar a cada aliado herido al que llega
const CD_FLECHA: float = 2.2                    ## v2: s entre dos flechas
const ALCANCE_FLECHA: float = 10.0
const VEL_FLECHA_VENENO: float = 9.0            ## u/s (la del arquero goblin)
const DANO_FLECHA_VENENO: float = 4.0
const CD_BOLA_V2: float = 6.0                   ## v2: la bola pasa a ser secundaria
const T_QUIETA: float = 2.0                     ## v2: s que la jugadora lleva casi sin moverse para que valga la bola...
const RADIO_QUIETA: float = 1.0                 ## ...«casi» = a menos de esta distancia (u) de donde estaba hace T_QUIETA s
const COLOR_FLECHA_VENENO: Color = Color(0.45, 0.95, 0.3)

const ID: String = "goblin_chaman"
const VIDA: float = 30.0                    ## 29/10 (DANO_Y_TINTA): 50 → 30
const ORO_CHAMAN: int = 15
## 29/10: sus velocidades ya no son constantes: andar = v_base("walk") y retroceso = v_base("run") (clip ×1,1 con su zancada: ver Combate3D.PASO_GOBLIN)
const ALIADOS_CASILLAS: float = 4.0             ## busca escudar a los aliados a esta distancia de él
const ESPALDAS_ALIADOS: float = 1.8             ## u: cuánto se coloca detrás del centro del grupo
const DIST_MIN: float = 5.0                     ## u: más cerca de la jugadora que esto, retrocede
const DIST_MAX: float = 7.0                     ## u: más lejos, se acerca
const DIST_VER: float = 13.0                    ## u: la ve (con línea libre) a esto
const ALCANCE_BOLA: float = 10.0
const CD_RITUAL: float = 8.0                    ## s entre dos rituales (se cuenta desde que acaba o se rompe)
const CD_BOLA: float = 3.0
const T_IR_MAX: float = 8.0                     ## s máximos yendo a su sitio antes de empezar donde esté (29/10: 5 → 8 al ir más despacio)
const LLEGADA: float = 0.4
const COLOR_VENENO: Color = Color(0.6, 0.95, 0.35)
const ENERGIA_VENENO: float = 1.8
const RADIO_CAPSULA: float = 0.32

var c_estado: String = "vigila"                 ## vigila · yendo · ritual · lanzando (muerto: `muerto`)
var ritual: ChamanRitual = null
var rituales: int = 0                           ## rituales empezados (pruebas)
var rituales_rotos: int = 0
var rituales_completos: int = 0
var escudos_dados: int = 0
var bolas: int = 0                              ## bolas lanzadas
var ultima_bola: BolaVeneno3D = null
var _cd_ritual: float = 0.0
var _cd_bola: float = 1.0
var _t_estado: float = 0.0
var _destino_ritual: Vector3 = Vector3.ZERO
var _dir_ritual: Vector3 = Vector3(0, 0, 1)
var _t_lanzar: float = 0.0
var _bola_soltada: bool = false
var flechas: int = 0                            ## v2: flechas de veneno lanzadas (pruebas)
var ultima_flecha: Node3D = null
var curas_dadas: int = 0                        ## v2: aliados curados por la onda (pruebas)
var rituales_curar: int = 0                     ## v2: rituales de curar empezados
var _cd_flecha: float = 1.0
var _curados_onda: Dictionary = {}              ## v2: aliados que ya curó la onda en curso (instance_id -> true)
var _ritual_cura: bool = false                 ## v2: el ritual en curso (o por empezar) es de curar y no de escudar
var _tipo_lanzar: String = "bola"               ## v2: lo que suelta el lanzamiento en curso: bola | flecha
var _ref_jug: Vector3 = Vector3.ZERO            ## v2: dónde estaba la jugadora al empezar a contar su quietud
var _t_quieta: float = 0.0


## Crea un chamán en `pos` (modelo Pj3D `goblin_chaman` + su combate) y lo cuelga del mundo. Devuelve null si falta el modelo.
static func invocar_chaman(p_mundo: Node3D, pos: Vector3, p_jugador: Jugador3D = null, p_lanz: Lanzador3D = null) -> Chaman3D:
	var modelo: Pj3D = p_mundo.call("_personaje", [ID], pos)
	if modelo == null:
		return null
	var lista: Variant = p_mundo.get("_goblins")
	if lista is Array:
		(lista as Array).append(modelo)
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	var c := Chaman3D.new()
	c.name = "Chaman_" + str(modelo.get_instance_id())
	c.pj = modelo
	c.mundo = p_mundo
	c.jugador = p_jugador
	c.lanz = p_lanz
	c.position = pos
	c.casa = pos
	c.altura = modelo.alto_modelo() * modelo.scale.y
	p_mundo.add_child(c, true)
	return c


func _init() -> void:
	inmune_estados = ["veneno"]               # F4: el chamán no se envenena con su propio veneno


func _ready() -> void:
	nombre = "Chamán goblin"
	vida_max = VIDA
	masa = 0.9
	defensa = Dano.DEF_CHAMAN                 # 29/10 (DANO_Y_TINTA): 0
	oro = ORO_CHAMAN
	tabla_botin = "chaman"
	debil = ""
	resiste = ""
	tinte = Color.WHITE
	if jugador == null or lanz == null:
		_buscar_jugador()
	super()
	health = VIDA
	if _col != null and _col.shape is CapsuleShape3D:
		(_col.shape as CapsuleShape3D).radius = RADIO_CAPSULA
	if _marca_debil != null:
		_marca_debil.visible = false


func _buscar_jugador() -> void:
	if not is_inside_tree():
		return
	for grupo in ["spellcaster", "player"]:
		var l: Node = get_tree().get_first_node_in_group(grupo)
		if l != null and l.get("jugador") is Jugador3D:
			jugador = l.get("jugador") as Jugador3D
			lanz = l as Lanzador3D if l is Lanzador3D else jugador.lanz
			return


## =====================================================================================================
##  Aliados
## =====================================================================================================

## Los aliados vivos a `radio` u o menos de él (goblins con combate; no el limo ni el gólem, que no llevan escudo de hojas).
func aliados(radio: float = -1.0) -> Array:
	var res: Array = []
	if not is_inside_tree():
		return res
	var r: float = radio if radio > 0.0 else ALIADOS_CASILLAS * Terreno3D.casilla
	for n in get_tree().get_nodes_in_group("combate3d"):
		if n == self or not is_instance_valid(n) or not (n is Combate3D):
			continue
		var a: Combate3D = n
		if a.muerto or a is Limo3D or a is Golem3D or a is Chaman3D:
			continue
		if _dist(a.position) <= r:
			res.append(a)
	return res


func aliados_sin_escudo(radio: float = -1.0) -> Array:
	var res: Array = []
	for a in aliados(radio):
		var c: Combate3D = a
		if c.escudo_natural == null or not is_instance_valid(c.escudo_natural) or not c.escudo_natural.activo():
			res.append(c)
	return res


## v2: los aliados vivos con menos de UMBRAL_CURAR de su vida (a ≤ `radio` u; por defecto ALIADOS_CASILLAS casillas).
func aliados_heridos(radio: float = -1.0) -> Array:
	var res: Array = []
	for a in aliados(radio):
		var c: Combate3D = a
		if c.health < c.vida_max * UMBRAL_CURAR:
			res.append(c)
	return res


## v2: qué hace ahora en lugar de moverse: «curar» (hay un aliado herido y el ritual está listo), «escudo» (hay uno sin escudo y está listo) o «atacar». El ritual de curar y el de escudar
## comparten el enfriamiento CD_RITUAL. Con CHAMAN_V2 apagado solo existe «escudo» / «atacar» (como el 28/10).
func decidir_accion() -> String:
	if _cd_ritual <= 0.0:
		if CHAMAN_V2 and not aliados_heridos().is_empty():
			return "curar"
		if not aliados_sin_escudo().is_empty():
			return "escudo"
	return "atacar"


## v2: qué lanza a `dist` u de la jugadora si `ve` (línea libre): la bola de veneno (área) solo si ella lleva ≥ T_QUIETA s casi quieta (< RADIO_QUIETA u) o si no la ve (cobertura) y la bola está
## lista; si no, la flecha de veneno si está lista y la ve. "" = nada todavía.
func decidir_ataque(dist: float, ve: bool) -> String:
	if dist > ALCANCE_FLECHA:
		return ""
	if _cd_bola <= 0.0 and (_t_quieta >= T_QUIETA or not ve):
		return "bola"
	if _cd_flecha <= 0.0 and ve:
		return "flecha"
	return ""


## v2: cuenta cuánto lleva la jugadora sin alejarse más de RADIO_QUIETA u del punto de referencia (se reinicia al salir de él).
func _seguir_quietud(delta: float) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	if _plano(jugador.position - _ref_jug).length() > RADIO_QUIETA:
		_ref_jug = jugador.position
		_t_quieta = 0.0
	else:
		_t_quieta += delta


func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Sitio donde se coloca para escudar a `grupo`: detrás de su centro, del lado opuesto a la jugadora, y la dirección en que mirará (hacia ellos).
func _sitio_ritual(grupo: Array) -> Dictionary:
	var c := Vector3.ZERO
	for a in grupo:
		c += (a as Combate3D).position
	c /= float(maxi(grupo.size(), 1))
	var lejos: Vector3 = _plano(c - jugador.position)
	lejos = lejos.normalized() if lejos.length() > 0.05 else _plano(position - jugador.position).normalized()
	var spot: Vector3 = c + lejos * ESPALDAS_ALIADOS
	spot.y = position.y
	if not _puede_estar(spot):
		spot = position
	if combate_tactico and lanz != null and lanz.muro_entre(jugador.position, position):
		spot = position
	var mira: Vector3 = _plano(c - spot)
	mira = mira.normalized() if mira.length() > 0.05 else -lejos
	return {"spot": spot, "mira": mira}


## =====================================================================================================
##  Fotograma e IA
## =====================================================================================================

func _ia(delta: float) -> void:
	_t_estado += delta
	_cd_ritual = maxf(0.0, _cd_ritual - delta)
	_cd_bola = maxf(0.0, _cd_bola - delta)
	_cd_flecha = maxf(0.0, _cd_flecha - delta)
	_seguir_quietud(delta)
	if _empuje.length() > 0.1:
		_mover_paso(_empuje * delta, true)
		_empuje = _empuje.lerp(Vector3.ZERO, clampf(DECAIMIENTO_EMPUJE * delta, 0.0, 1.0))
	if _fase_empuje != FASE_NINGUNA or stun_timer > 0.0 or congelado > 0.0 or interrupcion > 0.0:
		if stun_timer > 0.0:
			stun_timer -= delta
		elif interrupcion > 0.0 and _fase_empuje == FASE_NINGUNA and congelado <= 0.0:
			interrupcion -= delta
		_interrumpir_todo()
		moviendo = 0
		return
	if quieto or jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		objetivo = null
		moviendo = 0
		return
	match c_estado:
		"vigila":
			_ia_vigila(delta)
		"yendo":
			_ia_yendo(delta)
		"ritual":
			moviendo = 0                            # el giro lo lleva el ritual (gira en el sitio al trazar)
		"lanzando":
			_ia_lanzando(delta)


func _ia_vigila(delta: float) -> void:
	var d: Vector3 = _plano(jugador.position - position)
	var dist: float = d.length()
	var ve: bool = _ve(DIST_VER)
	if ve:
		if objetivo == null:
			flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0), "!", Color(1, 0.85, 0.2))
			Sfx3D.play(self, snd_alerta)     # 13/11 (inventario SFX): antes no sonaba
		objetivo = jugador
		vista_perdida = 0.0
	elif objetivo != null:
		vista_perdida += delta
		if vista_perdida > TIEMPO_PERDER:
			objetivo = null
	if objetivo == null:
		moviendo = 0
		return
	if d.length() > 0.05:
		mirada = d.normalized()
	# 1) escudar antes que nada (v2: curar al herido antes que escudar)
	if _cd_ritual <= 0.0:
		var accion: String = decidir_accion()
		if accion != "atacar":
			_ritual_cura = accion == "curar"
			var grupo: Array = aliados_heridos() if _ritual_cura else aliados_sin_escudo()
			var s: Dictionary = _sitio_ritual(grupo)
			_destino_ritual = s["spot"]
			_dir_ritual = s["mira"]
			c_estado = "yendo"
			_t_estado = 0.0
			return
	# 2) mantener la distancia
	moviendo = 0
	if dist < DIST_MIN:
		moviendo = 1
		_v_avance = v_base("run")
		if not _mover_paso(-mirada * _v_avance * delta):
			moviendo = 0
	elif dist > DIST_MAX:
		moviendo = 1
		_v_avance = v_base("walk")
		_mover_paso(_dir_hacia(jugador.position, delta) * _v_avance * delta, false, true)
	# 3) bolas de veneno (v2: flechas de veneno, y la bola solo si ella está quieta o escondida)
	if CHAMAN_V2:
		var tiro_libre: bool = ve and not (combate_tactico and lanz != null and lanz.muro_entre(position, jugador.position))
		var ataque: String = decidir_ataque(dist, tiro_libre)
		if ataque != "":
			_empezar_lanzar(ataque)
	elif _cd_bola <= 0.0 and ve and dist <= ALCANCE_BOLA:
		_empezar_lanzar()


func _ia_yendo(delta: float) -> void:
	var sin: Array = aliados_heridos() if (CHAMAN_V2 and _ritual_cura) else aliados_sin_escudo()
	if sin.is_empty():
		c_estado = "vigila"
		return
	var d: Vector3 = _plano(_destino_ritual - position)
	if d.length() <= LLEGADA or _t_estado > T_IR_MAX:
		_empezar_ritual()
		return
	mirada = d.normalized()
	moviendo = 1
	pj.mirar(mirada, 0.1)
	_v_avance = v_base("run")                  # 29/10: va a su sitio a paso ligero (correr): a su andar (0,47 u/s) los 5 s de T_IR_MAX no llegaban y el ritual empezaba lejos de los aliados
	_mover_paso(_dir_hacia(_destino_ritual, delta) * _v_avance * delta, false, true)


func _empezar_ritual() -> void:
	moviendo = 0
	mirada = _dir_ritual
	pj.mirar(_dir_ritual, 1.0)
	pj.set_velocidad_animacion(1.0)
	ritual = ChamanRitual.iniciar(pj, mundo)
	if ritual == null:
		c_estado = "vigila"
		_cd_ritual = CD_RITUAL
		return
	c_estado = "ritual"
	_t_estado = 0.0
	rituales += 1
	_curados_onda.clear()
	if _ritual_cura:
		rituales_curar += 1
	ritual.activado.connect(_on_activado)
	ritual.terminado.connect(_on_terminado)
	ritual.interrumpido.connect(_on_interrumpido)
	ritual.runa.onda_avanza.connect(_on_onda.bind(ritual.runa))
	PlayLog.event("chaman_ritual", {"aliados": aliados_sin_escudo().size(), "cura": _ritual_cura})
	ritual_empezado.emit()


func _on_activado() -> void:
	Sfx3D.play(self, "escudo_golpe")


func _on_onda(radio: float, de_runa: RunaSuelo3D = null) -> void:
	if ritual == null or ritual.runa == null or not is_instance_valid(ritual.runa):
		return
	if de_runa != null and de_runa != ritual.runa:
		return                                     # 6/11: la onda de un ritual anterior que aún se apaga no cuenta para el de ahora
	var c: Vector3 = ritual.runa.global_position
	if _ritual_cura:
		_curar_onda(c, radio)
		return
	for a in aliados(1000.0):
		var ally: Combate3D = a
		if Vector2(ally.position.x - c.x, ally.position.z - c.z).length() <= radio:
			if ally.escudo_natural == null or not is_instance_valid(ally.escudo_natural) or not ally.escudo_natural.activo():
				if EscudoNaturaleza3D.poner(ally) != null:
					escudos_dados += 1
					texto_en(ally, "¡Escudo!")


## v2: la onda del ritual de curar da CURA_RITUAL de vida (sin pasar de su máximo) a cada aliado herido al que llega; texto verde sobre él. La onda y la runa son las del escudo (verdes).
func _curar_onda(c: Vector3, radio: float) -> void:
	for a in aliados(1000.0):
		var ally: Combate3D = a
		if ally.health >= ally.vida_max or ally.health <= 0.0 or _curados_onda.has(ally.get_instance_id()):
			continue
		if Vector2(ally.position.x - c.x, ally.position.z - c.z).length() <= radio:
			_curados_onda[ally.get_instance_id()] = true       # `onda_avanza` suena cada fotograma: una cura por aliado y por onda
			curar_aliado(ally, CURA_RITUAL)


## v2: sube la vida de `ally` hasta `cantidad` (tope vida_max), enseña la barra y el «+n». Devuelve lo que curó de verdad.
func curar_aliado(ally: Combate3D, cantidad: float) -> float:
	var antes: float = ally.health
	ally.health = minf(ally.vida_max, ally.health + cantidad)
	var dado: float = ally.health - antes
	if dado > 0.0:
		ally._barra_t = Combate3D.TIEMPO_BARRA
		curas_dadas += 1
		flotante(mundo, ally.position + Vector3(0, ally.altura + 0.45, 0), "+%d" % int(round(dado)), EscudoNaturaleza3D.COLOR)
	return dado


func texto_en(a: Combate3D, txt: String) -> void:
	flotante(mundo, a.position + Vector3(0, a.altura + 0.45, 0), txt, EscudoNaturaleza3D.COLOR)


func _on_terminado() -> void:
	rituales_completos += 1
	ritual = null
	c_estado = "vigila"
	_t_estado = 0.0
	_cd_ritual = CD_RITUAL
	ritual_completado.emit()


func _on_interrumpido() -> void:
	rituales_rotos += 1
	ritual = null
	c_estado = "vigila"
	_t_estado = 0.0
	_cd_ritual = CD_RITUAL
	ritual_roto.emit()
	PlayLog.event("chaman_ritual_roto", {})


## Corta lo que esté haciendo (ritual o lanzar) porque lo han golpeado, aturdido, congelado o empujado.
func _interrumpir_todo() -> void:
	if ritual != null and is_instance_valid(ritual) and ritual.en_curso():
		ritual.interrumpir()
	if c_estado == "lanzando":
		_terminar_lanzar()
	if c_estado == "yendo":
		c_estado = "vigila"


func receive_damage(cantidad: float, desde_nivel: int = 0) -> void:
	if ritual != null and is_instance_valid(ritual) and ritual.en_curso():
		ritual.interrumpir()               # le pegan trazando: la runa se rompe
	if c_estado == "lanzando":
		_terminar_lanzar()
	super(cantidad, desde_nivel)


## --- La bola de veneno ---

func _empezar_lanzar(tipo: String = "bola") -> void:
	var d: Vector3 = _plano(jugador.position - position)
	_dir_ritual = d.normalized() if d.length() > 0.05 else mirada
	mirada = _dir_ritual
	pj.mirar(_dir_ritual, 1.0)
	c_estado = "lanzando"
	_t_lanzar = 0.0
	_bola_soltada = false
	_tipo_lanzar = tipo
	if tipo == "flecha":
		_cd_flecha = CD_FLECHA
	else:
		_cd_bola = CD_BOLA_V2 if CHAMAN_V2 else CD_BOLA
	moviendo = 0
	pj.agarrar_baston(true, 0.15)
	pj.teñir_baston(COLOR_VENENO, ENERGIA_VENENO)
	pj.set_velocidad_animacion(1.0)
	pj.animacion_actual = ""
	pj.jugar("lanzar", true)


func _ia_lanzando(delta: float) -> void:
	moviendo = 0
	_t_lanzar += delta * ritmo()         # tiempo DEL CLIP: el clip va a ritmo, así que INSTANTE_LANZAR / DUR_LANZAR (s de clip) tardan 1 / ritmo
	if not _bola_soltada and _t_lanzar >= AnimacionesChaman.INSTANTE_LANZAR:
		if _tipo_lanzar == "flecha":
			_soltar_flecha_veneno()
		else:
			_soltar_bola()
	if _t_lanzar >= AnimacionesChaman.DUR_LANZAR:
		_terminar_lanzar()


func _soltar_bola() -> void:
	_bola_soltada = true
	Sfx3D.play(self, "veneno_bola")     # 13/11 (pack de magia): antes no sonaba
	var b: BastonChaman3D = pj.baston()
	var origen: Vector3 = b.cima_global() if b != null else position + Vector3(0, altura * 0.8, 0)
	var destino: Vector3 = jugador.position
	ultima_bola = BolaVeneno3D.lanzar(mundo, origen, destino, self, jugador, lanz)
	bolas += 1
	bola_lanzada.emit(ultima_bola)


## --- v2: la flecha de veneno (la del arquero goblin, teñida de verde: recta, VEL_FLECHA_VENENO u/s) ---

## Sale de la punta del bastón hacia donde ESTÁ la jugadora ahora (sin adelanto: si se mueve, falla), con aviso en el suelo. La burbuja y los volúmenes con solidez la paran, como a la flecha goblin
## (`_vuelo_flecha`). Al llegar: DANO_FLECHA_VENENO y una pila de veneno (`Jugador3D.envenenar_pila`).
func _soltar_flecha_veneno() -> void:
	_bola_soltada = true
	var b: BastonChaman3D = pj.baston()
	var origen: Vector3 = b.cima_global() if b != null else position + Vector3(0, altura * 0.8, 0)
	var destino: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0)
	var t_vuelo: float = maxf(origen.distance_to(destino) / VEL_FLECHA_VENENO, 0.1)
	var aviso: AvisoAtaque3D = AvisoAtaque3D.circulo(mundo, Vector3(destino.x, jugador.position.y, destino.z), RADIO_IMPACTO_FLECHA, t_vuelo, self)
	var flecha: Node3D = _crear_flecha()
	_teñir_flecha(flecha)
	mundo.add_child(flecha)
	flecha.position = origen
	flecha.look_at(destino, Vector3.UP)
	var tw: Tween = flecha.create_tween()
	tw.tween_method(_vuelo_flecha_veneno.bind(flecha, origen, destino, aviso), 0.0, 1.0, t_vuelo)
	tw.tween_callback(_flecha_veneno_llega.bind(flecha, destino))
	ultima_flecha = flecha
	flechas += 1
	PlayLog.event("flecha_veneno", {})
	flecha_lanzada.emit(flecha)


func _teñir_flecha(flecha: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR_FLECHA_VENENO
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = COLOR_FLECHA_VENENO
	m.emission_energy_multiplier = 1.6
	for n in flecha.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m


func _vuelo_flecha_veneno(k: float, flecha: Node3D, origen: Vector3, destino: Vector3, aviso: AvisoAtaque3D) -> void:
	_vuelo_flecha(k, flecha, origen, destino)           # burbuja, solidez, llamas
	if is_instance_valid(flecha) and flecha.has_meta("parada") and aviso != null and is_instance_valid(aviso):
		aviso.cancelar()


func _flecha_veneno_llega(flecha: Node3D, destino: Vector3) -> void:
	if is_instance_valid(flecha):
		var parada: bool = flecha.has_meta("parada")
		flecha.queue_free()
		if parada:
			return
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return
	var dx: float = jugador.position.x - destino.x
	var dz: float = jugador.position.z - destino.z
	if Vector2(dx, dz).length() <= RADIO_IMPACTO_FLECHA and absf(jugador.position.y + 0.8 - destino.y) < Terreno3D.ALTO_NIVEL:
		jugador.recibir_dano(DANO_FLECHA_VENENO, position)
		jugador.envenenar_pila()


func _terminar_lanzar() -> void:
	c_estado = "vigila"
	_t_estado = 0.0
	pj.agarrar_baston(false, 0.25)
	pj.teñir_baston(Color.WHITE, 0.0)
	pj.animacion_actual = ""


func _animar() -> void:
	if c_estado == "ritual" or c_estado == "lanzando":
		return                                     # el ritual y el lanzar ponen sus clips
	super()


func _morir(ahogado: bool = false) -> void:
	if muerto:
		return
	if ritual != null and is_instance_valid(ritual) and ritual.en_curso():
		ritual.interrumpir()
	if escudo_natural != null and is_instance_valid(escudo_natural):
		escudo_natural.queue_free()
	if pj != null and is_instance_valid(pj):
		pj.agarrar_baston(false, 0.0)
		pj.teñir_baston(Color.WHITE, 0.0)
	c_estado = "muerto"
	super(ahogado)

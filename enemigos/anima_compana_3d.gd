class_name AnimaCompana3D
extends Combate3D

## E5a · ÁNIMA de la SANTA COMPAÑA (enemigo del glifo ᛁ, «línea»). Dueño: Juego. Una ánima suelta no se pone nunca: las crea y las manda `SantaCompana3D` (la procesión), que es quien sabe de la fila.
##
## Reglas de UNA ánima (las de la procesión, en enemigos/santa_compana_3d.gd):
##   · NO persigue. Va donde la fila la lleva (la posición se la pone la procesión: así «la fila no se rompe nunca»). Se mueve con el clip «Walking» (el andar de ánima, Unsteady_Walk) y no pisa.
##   · Si la jugadora se le CRUZA (a ≤ RADIO_TOQUE_CASILLAS casillas), le hace DANO_TOQUE y la deja ralentizada T_LENTO_TOQUE s (`Jugador3D.aplicar_estado("hielo", ...)`). Sin aviso: no es un ataque que
##     elija, es lo que pasa si te metes en medio. CD_TOQUE s entre dos toques de la misma ánima.
##   · Si a la procesión la atacan, SOLO EL GUÍA (la ánima que porta la CRUZ) se gira hacia la jugadora y lanza una MALDICIÓN con aviso (`AvisoAtaque3D`, T_AVISO_MALDICION s, el círculo cae donde ella
##     estaba al empezar): DANO_MALDICION y ralentizada T_LENTO_MALDICION s si sigue dentro. Clip `MageSoellCast001` (rol `cast_empuje`). El guía no se sale de la fila al lanzarla.
##   · Vida 25, defensa 0, masa 0,8; inmune al veneno. No se la puede empujar fuera de la fila (`push` no hace nada, `empujable_golpe = false`): lo que sí hace un golpe fuerte es pararla
##     (la procesión se queda quieta mientras una ánima esté congelada, aturdida o enraizada).
##   · Una ánima que cae NO suelta botín (lo suelta la procesión al acabarse).
##
## `es_guia`: la que lleva la cruz (`santa_compana_cruz`); las demás, la palmatoria (`santa_compana_vela`). Al morir el guía, la procesión le pasa la cruz a otra con `hacer_guia()`: se le QUITA la
## vela y se le pone la cruz con `Equipo3D.equipar`. LIMITACIÓN: el ANDAR no se cambia en caliente (el id del `Pj3D` sigue siendo `santa_compana_vela`, así que sigue con el Unsteady_Walk de la vela y
## no con el Spear_Walk de la cruz), ni se cierran sus dedos de la mano derecha (`Pj3D.MANO_RELAJADA` se aplica al cargar el modelo). Cambiar el id de un `Pj3D` ya cargado no está soportado.
##
## PASAR LA CRUZ (12/11): al caer el guía su cruz se QUEDA EN EL SUELO donde cayó (`SantaCompana3D.cruz_suelo`) y la fila se para. La ánima siguiente cierra el hueco hasta esa casilla y la
## RECOGE (`recoger_cruz`): se agacha con `CollectObject` (rol `cast_recoger`, estado `lanzar_recoger`, recortado de 0,5 a 4,7 s del clip y a RECOGER_VEL: el original dura 6 s y trae el
## reposo al principio y al final). A los T_ENGANCHE s (la mano ya está abajo, sobre la cruz) se le pone la cruz con `hacer_guia` y la pieza del suelo desaparece; a los T_RECOGER s se endereza y
## la fila sigue. Se eligió `CollectObject` y no `Ofrecer` (la jugadora, de pie, con la palma abierta): la que da la cruz está muerta, así que no hay nadie a quien ofrecérsela. Si la golpean o
## la paran mientras se agacha, se corta: la cruz sigue en el suelo (o ya en su mano, si pasó el enganche) y la procesión lo reintenta.
##
## `latente`: una ánima de REPOSICIÓN espera, invisible y sin colisión, a entrar por la cola de la fila. Sigue en el grupo de combate GRACIA_VIGIA s a propósito: así el vigía de una sala (que escanea
## cada 0,1 s) la ve y la cuenta como viva y no da la sala por limpia mientras la procesión tiene a alguien por entrar. Pasada la gracia SALE de los grupos `combate3d` y `goblins` (como hace el mouro
## latente) para que nada la elija de objetivo (saltos de rayo, hechizos de área, el golpe F…) mientras no es un enemigo de verdad; vuelve a ellos en `entrar()`.
##
## SURGIR DE LA TIERRA (12/11, reposición): la procesión (`SantaCompana3D._empezar_surgir`) la pone detrás de la última ánima viva y llama a `surgir_en(pos)`: se ve el cuerpo, que empieza
## HUNDIDO HUNDIDA_SURGIR u bajo el suelo (el suelo lo tapa: nada se ve antes de empezar el clip) y SUBE hasta quedar a ras durante la primera mitad del clip (TRAMO_SUBIDA, smoothstep) mientras se
## incorpora con `Getting_Up` de Mixamo (rol `cast_surgir`, estado `lanzar_surgir`, el mismo clip que el mouro; el INVERSO de él, que flotaba sobre el brocal). Sigue LATENTE todo ese tiempo (sin
## colisión, fuera de los grupos de combate, sin barra): es enemigo de verdad en `entrar()`, que llama la procesión justo al acabar el clip. Al empezar suelta polvo a ras de suelo
## (`Sensacion3D.polvo`, el polvo del gólem y del derrumbe; no hay efecto nuevo).

const ID_GUIA: String = "santa_compana_cruz"
const ID_VELA: String = "santa_compana_vela"
const ALTO: float = 0.85                         ## u de alto del modelo (el de `lab_humanoide_3d.gd`)
const VIDA: float = 25.0
const DEFENSA: float = 0.0
const MASA: float = 0.8
const RADIO_TOQUE_CASILLAS: float = 1.0          ## casillas: se le cruza si está a esto o menos
const DANO_TOQUE: float = 10.0
const T_LENTO_TOQUE: float = 1.5                 ## s ralentizada tras el toque
const CD_TOQUE: float = 1.5                      ## s entre dos toques de la misma ánima
const ALCANCE_MALDICION_CASILLAS: float = 6.0    ## casillas: el guía solo maldice a quien está a esto o menos
const T_AVISO_MALDICION: float = 1.0             ## s entre que sale el aviso y cae la maldición
const RADIO_MALDICION: float = 1.6               ## u del círculo de la maldición
const DANO_MALDICION: float = 8.0
const T_LENTO_MALDICION: float = 2.0
const CD_MALDICION: float = 5.0                  ## s entre dos maldiciones del guía
const T_DESCANSO_MALDICION: float = 0.5          ## s tras caer la maldición antes de volver a andar
const ROL_CLIP_MALDICION: String = "cast_empuje" ## MageSoellCast001 (ver `Pj3D.SINONIMOS`)
const ROL_CLIP_RECOGER: String = "cast_recoger"  ## CollectObject (ver `Pj3D.SINONIMOS`)
const ESTADO_RECOGER: String = "lanzar_recoger"  ## estado del grafo reducido (`lanzar*` vale)
const RECOGER_DESDE: float = 0.5                 ## s del clip original donde empieza (aún de pie, a punto de agacharse)
const RECOGER_HASTA: float = 4.7                 ## s del clip original donde acaba (ya erguida; después solo es reposo)
const RECOGER_VEL: float = 1.7                   ## velocidad con la que se reproduce el tramo
const T_ENGANCHE: float = 1.4                    ## s desde que empieza: la mano está abajo sobre la cruz (clip a 2,9 s) y se le engancha
const T_RECOGER: float = (RECOGER_HASTA - RECOGER_DESDE) / RECOGER_VEL   ## s que dura entera la recogida
const ROL_CLIP_SURGIR: String = "cast_surgir"    ## Getting_Up de Mixamo (ver `Pj3D.SINONIMOS`)
const ESTADO_SURGIR: String = "lanzar_surgir"
const HUNDIDA_SURGIR: float = 0.9                ## u bajo el suelo a las que empieza al surgir (algo más que su alto, ALTO = 0,85)
const TRAMO_SUBIDA: float = 0.5                  ## fracción del clip en la que sube hasta quedar a ras (smoothstep); el resto es incorporarse ya a ras
const GRACIA_VIGIA: float = 0.5                  ## s latente que sigue en los grupos de combate para que el vigía la vea (escanea cada 0,1 s)
const POLVO_SURGIR: float = 0.4                  ## radio (u) del polvo al empezar a surgir: un marco a ras de suelo, no una cortina (0,8 la tapaba entera; `Sensacion3D.polvo` solo admite el radio)
const RADIO_CAPSULA: float = 0.32

var procesion: SantaCompana3D = null
var numero: int = 0                              ## orden de creación en la procesión (0..n-1 las de salida; luego las reposiciones)
var es_guia: bool = false
var latente: bool = false                        ## ánima de reposición que aún no ha entrado
var desfase: float = 0.0                         ## u que va por detrás de la cabeza de la fila (lo mueve la procesión)
var toques_dados: int = 0                        ## toques que alcanzaron a la jugadora (pruebas)
var malditos: int = 0                            ## maldiciones lanzadas (pruebas)
var maldiciones_acertadas: int = 0
var maldiciendo: bool = false                    ## está lanzando la maldición (mira a la jugadora en vez de a donde anda)
var surgiendo: bool = false                      ## latente pero con el cuerpo ya a la vista, subiendo de la tierra (pruebas)
var _t_surgir: float = 0.0
var _t_gracia: float = 0.0                       ## s que le quedan en los grupos de combate estando latente
var recogiendo: bool = false                     ## se está agachando a recoger la cruz del suelo
var cruces_recogidas: int = 0                    ## cruces que ha llegado a enganchar (pruebas)
var _t_recoger: float = 0.0
var _enganchada: bool = false                    ## la cruz ya está en su mano (pasado T_ENGANCHE)
var _cd_toque: float = 0.0
var _cd_mal: float = 0.0
var _t_mal: float = 0.0
var _mal_hecha: bool = false
var _punto_mal: Vector3 = Vector3.ZERO


## Crea una ánima en `pos` y la cuelga de `p_mundo`. `p_guia` = lleva la cruz. `p_casa` = la casilla de partida de la procesión (la que mira el vigía de una sala). Null si falta el modelo.
static func crear(p_mundo: Node3D, pos: Vector3, p_procesion: SantaCompana3D, p_numero: int, p_guia: bool, p_casa: Vector3, p_jugador: Jugador3D = null, p_lanz: Lanzador3D = null) -> AnimaCompana3D:
	var modelo: Pj3D = MouroEspectro3D.nuevo_modelo(p_mundo, ID_GUIA if p_guia else ID_VELA, pos, ALTO)
	if modelo == null:
		return null
	var lista: Variant = p_mundo.get("_goblins")
	if lista is Array:
		(lista as Array).append(modelo)
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	var a := AnimaCompana3D.new()
	a.name = "Anima_%d_%d" % [p_numero, modelo.get_instance_id()]
	a.pj = modelo
	a.mundo = p_mundo
	a.jugador = p_jugador
	a.lanz = p_lanz
	a.procesion = p_procesion
	a.numero = p_numero
	a.es_guia = p_guia
	a.position = pos
	a.casa = p_casa
	a.altura = modelo.alto_modelo() * modelo.scale.y
	p_mundo.add_child(a, true)
	return a


func _init() -> void:
	inmune_estados = ["veneno"]
	empujable_golpe = false                      # el golpe F le hace daño pero no la saca de la fila


func _ready() -> void:
	nombre = "Ánima guía" if es_guia else "Ánima"
	vida_max = VIDA
	masa = MASA
	defensa = DEFENSA
	tabla_botin = "anima"                        # no se tira: el botín lo suelta la procesión (`_soltar_botin` no hace nada)
	debil = ""
	resiste = ""
	tinte = Color.WHITE
	snd_paso = ""
	snd_alerta = ""
	snd_muere = ""
	snd_golpe = ""
	if jugador == null or lanz == null:
		_buscar_jugador()
	super()
	health = VIDA
	if _col != null and _col.shape is CapsuleShape3D:
		(_col.shape as CapsuleShape3D).radius = RADIO_CAPSULA
	if _marca_debil != null:
		_marca_debil.visible = false


func _exit_tree() -> void:
	_quitar_aviso()


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
##  La cruz pasa de mano
## =====================================================================================================

## Este ánima pasa a ser el guía: se le quita la palmatoria y se le pone la cruz (`Equipo3D.equipar`). Devuelve false si el modelo no deja cambiar la pieza (entonces solo cambia el rol).
## El andar NO cambia (ver la cabecera).
func hacer_guia() -> bool:
	es_guia = true
	nombre = "Ánima guía"
	if _nombre_etiqueta != null:
		_nombre_etiqueta.text = nombre
	if pj == null or not is_instance_valid(pj):
		return false
	var modelo: Node3D = pj._modelo
	if modelo == null:
		return false
	for n in modelo.find_children("*", "Node3D", true, false):
		if n.has_meta("equipo_id") and String(n.get_meta("equipo_id")) == "vela_santa":
			pj._equipo.erase(n)
			n.queue_free()
	var vertical: Node = modelo.get_node_or_null("Vertical")      # lo que mantiene la palmatoria de pie (`Equipo3D.equipar`)
	if vertical != null:
		vertical.queue_free()
	var puestas: Array[Node3D] = Equipo3D.equipar(ID_GUIA, modelo)
	pj._equipo.append_array(puestas)
	return not puestas.is_empty()


## La procesión le manda recoger la cruz del suelo: se agacha (clip `CollectObject` recortado) y a los T_ENGANCHE s la cruz pasa a su mano. Devuelve false si no puede (muerta, latente).
func recoger_cruz() -> bool:
	if muerto or latente or recogiendo:
		return false
	_cortar_maldicion()
	recogiendo = true
	_enganchada = false
	_t_recoger = 0.0
	moviendo = 0
	if pj != null and is_instance_valid(pj):
		pj.animacion_actual = ""
		pj.set_velocidad_animacion(1.0)
		var arbol: ArbolAnimPj = pj.arbol()
		var clip: String = pj.clip_de(ROL_CLIP_RECOGER)
		if clip != "" and arbol != null and arbol.pedir(ESTADO_RECOGER, clip, {"desde": RECOGER_DESDE, "hasta": RECOGER_HASTA, "bucle": Animation.LOOP_NONE, "vel": RECOGER_VEL, "mezcla": 0.15}):
			pj.animacion_actual = ROL_CLIP_RECOGER
	PlayLog.event("anima_recoge_cruz", {"numero": numero})
	return true


func _seguir_recoger(delta: float) -> void:
	_t_recoger += delta
	if not _enganchada and _t_recoger >= T_ENGANCHE:
		_enganchada = true
		hacer_guia()                                            # la mano ya está abajo: la cruz se le engancha ahora, no antes
		cruces_recogidas += 1
		if procesion != null and is_instance_valid(procesion):
			procesion.al_recoger(self)
	if _t_recoger >= T_RECOGER:
		_acabar_recoger()


## Se endereza: vuelve a andar con la fila.
func _acabar_recoger() -> void:
	recogiendo = false
	if pj != null and is_instance_valid(pj):
		pj.animacion_actual = ""                                # que `_animar` pida idle / andar otra vez
	if procesion != null and is_instance_valid(procesion):
		procesion.al_enderezarse(self)


## Golpeada, congelada, aturdida o muerta a medio agacharse: se corta. Si aún no tenía la cruz, sigue en el suelo y la procesión lo reintenta.
func _cortar_recogida() -> void:
	if not recogiendo:
		return
	recogiendo = false
	if pj != null and is_instance_valid(pj):
		pj.animacion_actual = ""
	if procesion != null and is_instance_valid(procesion):
		if _enganchada:
			procesion.al_enderezarse(self)
		else:
			procesion.cruz_sin_recoger(self)


## =====================================================================================================
##  Muerte, golpes y reposición
## =====================================================================================================

## El botín de la procesión lo suelta `SantaCompana3D` cuando se acaba, no cada ánima.
func _soltar_botin() -> void:
	pass


func _morir(ahogado: bool = false) -> void:
	if muerto or latente:
		return
	_cortar_maldicion()
	maldiciendo = false
	_cortar_recogida()
	super(ahogado)
	if procesion != null and is_instance_valid(procesion):
		procesion.al_morir(self)


func receive_damage(cantidad: float, desde_nivel: int = 0) -> void:
	super(cantidad, desde_nivel)
	if cantidad > 0.0 and not muerto and procesion != null and is_instance_valid(procesion):
		procesion.al_ser_atacada(self)


## La sacan de la fila a empujones: no. Se queda donde la procesión la pone.
func push(_direccion: Vector3, _fuerza: float, _suelo: bool = false, _dano: float = -1.0, _debil: bool = false) -> void:
	return


## Una ánima de reposición sale de su espera y entra por el extremo de la fila.
## Aquí (y no antes) pasa a ser un enemigo de verdad: colisión, grupos de combate y blanco de todo. Si venía de surgir, el clip acaba justo ahora y queda a ras de suelo (desplazamiento 0 exacto).
func entrar() -> void:
	latente = false
	surgiendo = false
	collision_layer = Lanzador3D.CAPA_REACTIVO
	monitorable = true
	add_to_group("combate3d")
	add_to_group("goblins")
	if pj != null and is_instance_valid(pj):
		pj.visible = true
		pj.position = position
		pj.animacion_actual = ""                                # que `_animar` pida idle / andar
	for n in [_nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = true
	texto_grande("¡Se une!", Color(0.75, 0.85, 1.0), 0.1)


## La dejan latente (invisible, sin colisión), a la espera de entrar. En el grupo de combate: ver la cabecera.
func esperar_fuera() -> void:
	latente = true
	surgiendo = false
	_t_gracia = GRACIA_VIGIA
	collision_layer = 0
	monitorable = false
	if pj != null and is_instance_valid(pj):
		pj.visible = false
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = false


## Lo que dura el clip de surgir (s); 0 si el modelo no lo trae (entonces entra de golpe, como antes del 12/11).
func dur_surgir() -> float:
	if pj == null or not is_instance_valid(pj):
		return 0.0
	return pj.duracion(ROL_CLIP_SURGIR)


## La procesión la manda surgir de la tierra en `pos` (centro de la casilla, a la altura de su suelo): el cuerpo se ve, hundido, y empieza el clip. Sigue latente hasta `entrar()`.
func surgir_en(pos: Vector3) -> void:
	surgiendo = true
	_t_surgir = 0.0
	position = pos
	if pj == null or not is_instance_valid(pj):
		return
	pj.position = position + Vector3(0.0, -HUNDIDA_SURGIR, 0.0)      # bajo el suelo ANTES de hacerse visible
	if mirada.length() > 0.01:
		pj.mirar(mirada, 1.0)
	pj.animacion_actual = ""
	pj.set_velocidad_animacion(1.0)
	var arbol: ArbolAnimPj = pj.arbol()
	var clip: String = pj.clip_de(ROL_CLIP_SURGIR)
	if clip != "" and arbol != null and arbol.pedir(ESTADO_SURGIR, clip, {"bucle": Animation.LOOP_NONE, "vel": 1.0, "mezcla": 0.0, "reiniciar": true}):
		pj.animacion_actual = ROL_CLIP_SURGIR
	pj.visible = true
	Sensacion3D.polvo(mundo, position, POLVO_SURGIR)


## Cada fotograma de surgir: sube de la tierra hasta quedar a ras en TRAMO_SUBIDA del clip.
func _seguir_surgir(delta: float) -> void:
	_t_surgir += delta
	if pj == null or not is_instance_valid(pj):
		return
	var u: float = clampf(_t_surgir / maxf(dur_surgir() * TRAMO_SUBIDA, 0.01), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	pj.position = position + Vector3(0.0, -HUNDIDA_SURGIR * (1.0 - u), 0.0)


## Cuánto deja avanzar a la fila: 0 si está congelada, aturdida o enraizada; si no, lo que le dejen los estados (ralentizada, mojada).
func factor_marcha() -> float:
	if stun_timer > 0.0 or congelado > 0.0 or enraizado > 0.0 or _fase_empuje != FASE_NINGUNA:
		return 0.0
	return vel_mult()


## =====================================================================================================
##  Fotograma e IA: no persigue; toca a quien se cruza y, el guía, maldice
## =====================================================================================================

func _physics_process(delta: float) -> void:
	if latente:
		if surgiendo:
			_seguir_surgir(delta)
		if _t_gracia > 0.0:
			_t_gracia -= delta
			if _t_gracia <= 0.0:
				remove_from_group("combate3d")                  # ya la vio el vigía: ahora nada la elige de objetivo hasta `entrar()`
				remove_from_group("goblins")
		return
	super(delta)


func _ia(delta: float) -> void:
	_cd_toque = maxf(0.0, _cd_toque - delta)
	_cd_mal = maxf(0.0, _cd_mal - delta)
	if _fase_empuje != FASE_NINGUNA or stun_timer > 0.0 or congelado > 0.0 or interrupcion > 0.0:
		if stun_timer > 0.0:
			stun_timer -= delta
		elif interrupcion > 0.0 and _fase_empuje == FASE_NINGUNA and congelado <= 0.0:
			interrupcion -= delta
		_cortar_maldicion()
		_cortar_recogida()
		moviendo = 0
		return
	if recogiendo:
		moviendo = 0
		_seguir_recoger(delta)
		return
	if quieto:
		moviendo = 0
		return
	moviendo = 1 if (procesion != null and procesion.hay_movimiento()) else 0
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		_cortar_maldicion()
		return
	_tocar_si_se_cruza()
	if es_guia:
		_ia_maldicion(delta)


func _tocar_si_se_cruza() -> void:
	if _cd_toque > 0.0 or _dist(jugador.position) > RADIO_TOQUE_CASILLAS * Terreno3D.casilla or absf(jugador.position.y - position.y) >= Terreno3D.ALTO_NIVEL * 0.9:
		return
	_cd_toque = CD_TOQUE
	var antes: float = jugador.vida
	jugador.recibir_dano(DANO_TOQUE)                       # sin `desde`: no la empuja
	if jugador.vida < antes:
		jugador.aplicar_estado("hielo", T_LENTO_TOQUE)
		toques_dados += 1
	PlayLog.event("anima_toca", {"numero": numero, "dano": antes - jugador.vida})


func _ia_maldicion(delta: float) -> void:
	if maldiciendo:
		_t_mal += delta
		var d: Vector3 = jugador.position - position
		d.y = 0.0
		if d.length() > 0.05:
			mirada = d.normalized()                         # se gira hacia ella sin salirse de la fila (la posición la pone la procesión)
		if not _mal_hecha and _t_mal >= T_AVISO_MALDICION:
			_mal_hecha = true
			_aviso = null                                   # el aviso acaba solo en este instante
			_caer_maldicion()
		if _t_mal >= T_AVISO_MALDICION + T_DESCANSO_MALDICION:
			maldiciendo = false
		return
	if _cd_mal > 0.0 or procesion == null or not procesion.provocada() or _dist(jugador.position) > ALCANCE_MALDICION_CASILLAS * Terreno3D.casilla:
		return
	_empezar_maldicion()


func _empezar_maldicion() -> void:
	maldiciendo = true
	_t_mal = 0.0
	_mal_hecha = false
	malditos += 1
	_punto_mal = jugador.position
	_quitar_aviso()
	if AVISAR_ATAQUES and mundo != null:
		_aviso = AvisoAtaque3D.circulo(mundo, _punto_mal, RADIO_MALDICION, T_AVISO_MALDICION, self)
		avisos_dados += 1
	if pj != null and is_instance_valid(pj):
		pj.animacion_actual = ""
		pj.set_velocidad_animacion(1.0)
		pj.jugar(ROL_CLIP_MALDICION, true)
	PlayLog.event("anima_maldice", {"numero": numero})


## Lo que se ve es lo que pega: si ella sigue dentro del círculo, daño y ralentizada.
func _caer_maldicion() -> void:
	_cd_mal = CD_MALDICION
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return
	var rel: Vector3 = jugador.position - _punto_mal
	rel.y = 0.0
	if rel.length() <= RADIO_MALDICION:
		var antes: float = jugador.vida
		jugador.recibir_dano(DANO_MALDICION)
		if jugador.vida < antes:
			jugador.aplicar_estado("hielo", T_LENTO_MALDICION)
			maldiciones_acertadas += 1
	PlayLog.event("anima_maldicion_cae", {"acierta": rel.length() <= RADIO_MALDICION})


## Golpeada, congelada, aturdida o muerta: la maldición se corta y su aviso, si aún no había caído.
func _cortar_maldicion() -> void:
	if maldiciendo:
		maldiciendo = false
		if not _mal_hecha:
			_quitar_aviso()


func _animar() -> void:
	if recogiendo and _fase_empuje == FASE_NINGUNA:
		return                                                  # el clip de recoger ya está puesto
	if maldiciendo and _fase_empuje == FASE_NINGUNA:
		if mirada.length() > 0.01:
			pj.mirar(mirada, 0.12)
		return                                              # el clip de la maldición ya está puesto
	super()

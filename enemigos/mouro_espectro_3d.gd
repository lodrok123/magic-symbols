class_name MouroEspectro3D
extends Combate3D

## E4 · MOURO ESPECTRO (enemigo del glifo ᛉ, «permanencia»: vuelve de la tumba mientras la mámoa siga abierta). Dueño: Juego.
##
## Pregunta que plantea: «¿de dónde vuelve, y cómo corto el bucle?». Su dificultad no es el elemento (`debil` y `resiste` van VACÍOS) sino el bucle. Las reglas:
##   · Es un fantasma de elfo (modelo `fantasma_elfo_rig`) que SE DESLIZA hacia la jugadora despacio (VEL_ANDAR u/s, con el clip «Walking», que ya es el andar tambaleante). No pisa: `snd_paso = ""`.
##   · Ataque: si ella está a ≤ ALCANCE_TOQUE_CASILLAS casillas marca en el suelo (`AvisoAtaque3D`, T_AVISO_TOQUE s) el círculo de ese alcance alrededor de él; al acabar el aviso, si ella sigue
##     dentro, le hace DANO_TOQUE y la ENRAÍZA T_ENRAIZA s (`Jugador3D.enraizar`: «te agarra»). Si ella se sale del círculo, o a él lo golpean, no pasa nada.
##   · MUERTE: al llegar a 0 de vida, si tiene `mamoa`, está ABIERTA, no está agrietada y le quedan rebrotes (REBROTES_MAX = 3) NO MUERE: se DESHACE (`_deshacerse`: sin botín, sin contar como
##     enemigo muerto, sigue siendo «vivo» para el vigía de la sala) y queda LATENTE; a los T_REBROTE s reaparece EN LA CASILLA DE LA MÁMOA con la vida llena. Durante esos segundos la mámoa
##     echa humo (`Mamoa3D.humo_rebrote`): así se entiende de dónde sale. Cada rebrote gasta uno; al gastar el último (rebrote nº 3), `mamoa.agrietar()` y el siguiente golpe mortal ya es definitivo.
##   · Si la mámoa está TAPADA cuando muere: muerte definitiva, con botín. Si la tapan MIENTRAS está latente: no vuelve; a los T_SELLADO s muere definitivamente y su botín cae en la mámoa
##     (y la mámoa suelta además sus reliquias: ver `Mamoa3D`). Sin mámoa (`mamoa = null`) es un enemigo normal: muere una vez.
##   · Muerto en el agua (empujado a agua honda) es siempre definitivo: no hay tumba bajo el agua.
##
## Cómo está hecho: es un `Combate3D` con modelo Pj3D (el vigía, la previsión, los estados, el empuje y la barra se heredan). Se sustituyen la IA (`_ia`), la muerte (`_morir`) y el dibujo de la
## animación mientras ataca (`_animar`); el estado latente se resuelve en `_physics_process` antes de llegar a la física de Combate3D. Se pone desde un mapa con la pieza `mouro` de Puzle3D
## (`mamoa=<id de la pieza mámoa>`) o con `MouroEspectro3D.crear`.
##
## CLIP DEL TOQUE: el ataque quiere `ChargedSpellCast001` (el rol `cast` resuelve a MageSoellCast003). Desde el 12/11 tiene su rol `cast_agarre` en `Pj3D.SINONIMOS`; se pide al árbol con el estado
## `lanzar_agarre` (`_clip_toque`, el grafo reducido solo admite estados `lanzar*`); si el clip no está, se usa el rol `cast`.
##
## SURGIR DEL POZO (12/11): el mouro ya no aparece de golpe. Latente hay `T_REBROTE` s; los últimos `dur_surgir()` s (lo que dura el clip) el cuerpo YA se ve, en la casilla de la mámoa y
## todavía sin colisión ni barra, levantándose del suelo con el clip `Getting_Up` de Mixamo (rol `cast_surgir`, estado `lanzar_surgir`; la fuente se añadió al fantasma en `ClipsFamilia.FUENTE_MIXAMO_MOURO`).
## Antes de eso el cuerpo no se ve (solo el humo). Al acabar el clip se completa el rebrote como siempre (`_rebrotar`: vida llena, golpeable, `rebroto`). Si taparon la mámoa a mitad, se esconde.
## Se probó antes `SwimmingToEdge` (salir del agua): avanza la cadera casi un cuerpo y se sale del encuadre, no vale para un brocal; no se generó clip por código porque `Getting_Up` ya lee bien.

signal deshecho                                  ## cayó a 0 con la mámoa abierta: se ha deshecho, volverá
signal rebroto(veces: int)                       ## ha vuelto de la tumba; `veces` = rebrotes gastados ya (1..REBROTES_MAX)
signal sellado                                   ## taparon la mámoa estando él dentro: ya no vuelve

const ID: String = "fantasma_elfo_rig"
const ALTO: float = 0.9                          ## u de alto del modelo (el de `lab_humanoide_3d.gd`)
const VIDA: float = 45.0
const DEFENSA: float = 1.0
const MASA: float = 1.0
const ORO_MOURO: int = 12
const VEL_ANDAR: float = 1.6                     ## u/s: se desliza despacio
const RADIO_VER: float = 9.2                     ## u (4 casillas): la ve a esto y con línea libre
const RADIO_PERDER: float = 13.8                 ## u: ya persiguiendo, la pierde más allá
const ALCANCE_TOQUE_CASILLAS: float = 1.5        ## casillas: hasta dónde llega su toque (y el círculo del aviso)
const T_AVISO_TOQUE: float = 0.7                 ## s entre que sale el aviso y el agarre
const DANO_TOQUE: float = 12.0
const T_ENRAIZA: float = 1.0                     ## s que la sujeta (`Jugador3D.enraizar`)
const DESCANSO_TOQUE: float = 1.2                ## s tras el agarre antes de volver a moverse
const REBROTES_MAX: int = 3
const T_REBROTE: float = 4.0                     ## s latente hasta reaparecer en la mámoa
const T_SELLADO: float = 1.5                     ## s desde que tapan la mámoa hasta que muere definitivamente
const RADIO_CAPSULA: float = 0.32
const ROL_CLIP_TOQUE: String = "cast_agarre"       ## ChargedSpellCast001 (ver `Pj3D.SINONIMOS`)
const ESTADO_TOQUE: String = "lanzar_agarre"     ## estado del grafo reducido (`lanzar*` vale) para el clip del toque
const ROL_CLIP_SURGIR: String = "cast_surgir"    ## Getting_Up de Mixamo (ver `Pj3D.SINONIMOS`)
const ESTADO_SURGIR: String = "lanzar_surgir"

var mamoa: Mamoa3D = null                        ## de dónde vuelve; null = enemigo normal
var latente: bool = false                        ## deshecho, a la espera de volver (o de morir sellado)
var rebrotes_gastados: int = 0
var toques: int = 0                              ## agarres empezados (pruebas)
var golpes_dados: int = 0                        ## agarres que alcanzaron a la jugadora (pruebas)
var surgiendo: bool = false                      ## latente pero con el cuerpo ya a la vista, levantándose del pozo (pruebas)
var _t_latente: float = 0.0
var _dur_surgir: float = -1.0                    ## lo que dura el clip de surgir (s); -1 = sin medir, 0 = el modelo no lo trae
var _sellado: bool = false                       ## la tapa cayó estando latente: muere definitivamente en `_t_sellado`
var _t_sellado: float = 0.0
var _definitiva: bool = false                    ## la próxima `_morir` no rebrota (la muerte sellada)
var _atacando: bool = false
var _t_toque: float = 0.0
var _golpe_hecho: bool = false


## Crea un mouro en `pos` (modelo Pj3D `fantasma_elfo_rig` + su combate) y lo cuelga del mundo. `p_mamoa` = la tumba de la que vuelve (null = sin bucle). Devuelve null si falta el modelo.
## `jugador` y `lanzador` se buscan solos en los grupos de siempre si no se pasan.
static func crear(p_mundo: Node3D, pos: Vector3, p_mamoa: Mamoa3D = null, p_jugador: Jugador3D = null, p_lanz: Lanzador3D = null) -> MouroEspectro3D:
	var modelo: Pj3D = nuevo_modelo(p_mundo, ID, pos, ALTO)
	if modelo == null:
		return null
	var lista: Variant = p_mundo.get("_goblins")
	if lista is Array:
		(lista as Array).append(modelo)
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	var m := MouroEspectro3D.new()
	m.name = "Mouro_" + str(modelo.get_instance_id())
	m.pj = modelo
	m.mundo = p_mundo
	m.jugador = p_jugador
	m.lanz = p_lanz
	m.mamoa = p_mamoa
	m.position = pos
	m.casa = pos
	m.altura = modelo.alto_modelo() * modelo.scale.y
	p_mundo.add_child(m, true)
	return m


## El modelo Pj3D de `id` colgado de `p_mundo` en `pos` y con `alto` u de alto; null si el GLB no está. Lo comparten los dos enemigos de la mámoa y de la compaña (`AnimaCompana3D`): se crea
## aquí y no con `_personaje` del mundo porque el mundo de una prueba no lo tiene y la altura de estos ids no está en su tabla.
static func nuevo_modelo(p_mundo: Node3D, id: String, pos: Vector3, alto: float) -> Pj3D:
	var modelo := Pj3D.new()
	modelo.position = pos
	p_mundo.add_child(modelo)
	if not modelo.cargar(id):
		modelo.queue_free()
		return null
	modelo.set_alto(alto)
	return modelo


func _init() -> void:
	inmune_estados = ["veneno"]                 # no tiene carne que envenenar


func _ready() -> void:
	nombre = "Mouro espectro"
	vida_max = VIDA
	masa = MASA
	defensa = DEFENSA
	oro = ORO_MOURO
	tabla_botin = "mouro"
	debil = ""                                  # su dificultad es el bucle, no el elemento
	resiste = ""
	tinte = Color.WHITE
	snd_paso = ""                               # se desliza, no pisa
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
		_marca_debil.visible = false            # sin debilidad no hay rombo
	if mamoa != null and is_instance_valid(mamoa):
		var m: Mamoa3D = mamoa
		mamoa = null
		asignar_mamoa(m)                        # la conecta (la pieza `mouro` de Puzle3D la asigna después, con `asignar_mamoa`)


## Le da (o le cambia) la tumba de la que vuelve, y se entera de cuándo la tapan.
func asignar_mamoa(m: Mamoa3D) -> void:
	if mamoa != null and is_instance_valid(mamoa) and mamoa.tapada.is_connected(_al_tapar):
		mamoa.tapada.disconnect(_al_tapar)
	mamoa = m
	if mamoa != null and is_instance_valid(mamoa):
		mamoa.tapada.connect(_al_tapar)


func _exit_tree() -> void:
	if mamoa != null and is_instance_valid(mamoa):
		mamoa.salir_mouro(self)


func _buscar_jugador() -> void:
	if not is_inside_tree():
		return
	for grupo in ["spellcaster", "player"]:
		var l: Node = get_tree().get_first_node_in_group(grupo)
		if l != null and l.get("jugador") is Jugador3D:
			jugador = l.get("jugador") as Jugador3D
			lanz = l as Lanzador3D if l is Lanzador3D else jugador.lanz
			return


## u de su toque (y del círculo del aviso).
func alcance_toque() -> float:
	return ALCANCE_TOQUE_CASILLAS * Terreno3D.casilla


## =====================================================================================================
##  Muerte: se deshace y vuelve, o muere de verdad
## =====================================================================================================

## ¿Le toca rebrotar si cae ahora? Con mámoa, abierta, sin agrietar y con rebrotes sin gastar.
func puede_rebrotar() -> bool:
	return mamoa != null and is_instance_valid(mamoa) and mamoa.abierta and not mamoa.esta_agrietada and rebrotes_gastados < REBROTES_MAX


func _morir(ahogado: bool = false) -> void:
	if muerto or latente:
		return
	if not ahogado and not _definitiva and puede_rebrotar():
		_deshacerse()
		return
	_definitiva = false
	if mamoa != null and is_instance_valid(mamoa):
		mamoa.salir_mouro(self)
	super(ahogado)


## Se deshace sin morir: sin botín, sin aviso de muerte, sin `enemigo_muerto` (no cuenta como caído) y SIN marcarse `muerto`: para el vigía de la sala sigue vivo. Queda latente T_REBROTE s.
## Sale de los grupos de combate y de la capa de los hechizos, para que nada lo busque ni lo golpee mientras no está.
func _deshacerse() -> void:
	_quitar_aviso()
	_cortar_toque()
	latente = true
	surgiendo = false
	_sellado = false
	rebrotes_gastados += 1
	_t_latente = T_REBROTE
	moviendo = 0
	objetivo = null
	_empuje = Vector3.ZERO
	_fase_empuje = FASE_NINGUNA
	_t_fase_empuje = 0.0
	_destello = 0.0
	_hitstop = 0.0
	collision_layer = 0
	monitorable = false
	remove_from_group("combate3d")
	remove_from_group("goblins")
	_visible(false)
	if mamoa != null and is_instance_valid(mamoa):
		mamoa.entrar_mouro(self)
		mamoa.humo_rebrote(T_REBROTE)
	PlayLog.event("mouro_deshecho", {"rebrotes": rebrotes_gastados, "celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y]})
	deshecho.emit()


## Reaparece en la casilla de la mámoa con la vida llena y sin ningún estado. Al gastar el último rebrote, la mámoa se agrieta.
func _rebrotar() -> void:
	latente = false
	surgiendo = false
	_sellado = false
	var c: Vector2i = mamoa.celda
	position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if pj != null and is_instance_valid(pj):
		pj.position = position
	health = vida_max
	quemando = 0.0
	envenenado = 0.0
	mojado = 0.0
	congelado = 0.0
	lento = 0.0
	cegado = 0.0
	enraizado = 0.0
	stun_timer = 0.0
	interrupcion = 0.0
	_vida_mostrada = 1.0
	_barra_t = 0.0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	monitorable = true
	add_to_group("combate3d")
	add_to_group("goblins")
	_visible(true)
	if pj != null and is_instance_valid(pj):
		pj.animacion_actual = ""
		pj.jugar("idle")
	mamoa.salir_mouro(self)
	mamoa.cancelar_humo()
	texto_grande("¡Vuelve!", Color(0.75, 0.85, 1.0), 0.1)
	PlayLog.event("mouro_rebrota", {"veces": rebrotes_gastados})
	rebroto.emit(rebrotes_gastados)
	if rebrotes_gastados >= REBROTES_MAX:
		mamoa.agrietar()                          # el último: a partir de aquí, el siguiente golpe mortal es definitivo


## Taparon la mámoa. Si estaba latente, ya no vuelve: muere definitivamente en T_SELLADO s.
func _al_tapar() -> void:
	if not latente or _sellado:
		return
	if surgiendo:
		surgiendo = false
		_visible(false)                                         # la tapa lo pilla a medio salir: se esconde (a los T_SELLADO s reaparece para morir, como siempre)
	_sellado = true
	_t_sellado = T_SELLADO
	sellado.emit()
	PlayLog.event("mouro_sellado", {"rebrotes": rebrotes_gastados})


## El fin del mouro sellado: aparece un instante en la mámoa y muere de verdad (con su botín, que cae allí).
func _morir_sellado() -> void:
	latente = false
	surgiendo = false
	_sellado = false
	_definitiva = true
	if mamoa != null and is_instance_valid(mamoa):
		var c: Vector2i = mamoa.celda
		position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
		mamoa.salir_mouro(self)
	if pj != null and is_instance_valid(pj):
		pj.position = position
	add_to_group("combate3d")
	add_to_group("goblins")
	_visible(true)
	health = 0.0
	_morir()


func _visible(v: bool) -> void:
	if pj != null and is_instance_valid(pj):
		pj.visible = v
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = v


## =====================================================================================================
##  Fotograma e IA
## =====================================================================================================

func _physics_process(delta: float) -> void:
	if latente:
		_vigilar_latente(delta)
		return
	super(delta)


## Latente: espera a volver. Si la mámoa se tapó (o desapareció) no vuelve. La señal `tapada` ya lo avisa; esto es la red de seguridad por si la tapa llegó sin señal.
func _vigilar_latente(delta: float) -> void:
	if mamoa == null or not is_instance_valid(mamoa):
		_sellado = true
	elif not mamoa.abierta and not _sellado:
		_al_tapar()
	if _sellado:
		_t_sellado -= delta
		if _t_sellado <= 0.0:
			_morir_sellado()
		return
	_t_latente -= delta
	if not surgiendo and _t_latente <= dur_surgir() and dur_surgir() > 0.0:
		_empezar_surgir()
	if _t_latente <= 0.0:
		_rebrotar()


## Lo que dura el clip de surgir (s), sin pasarse del tiempo de rebrote; 0 si el modelo no lo trae (entonces aparece de golpe, como antes).
func dur_surgir() -> float:
	if _dur_surgir < 0.0:
		_dur_surgir = 0.0
		if pj != null and is_instance_valid(pj):
			_dur_surgir = minf(pj.duracion(ROL_CLIP_SURGIR), T_REBROTE - 0.5)
	return _dur_surgir


## El cuerpo sale a la vista en la casilla de la mámoa y se levanta del suelo. Sigue latente: sin colisión, sin barra, fuera de los grupos de combate, hasta `_rebrotar`.
func _empezar_surgir() -> void:
	surgiendo = true
	if mamoa == null or not is_instance_valid(mamoa) or pj == null or not is_instance_valid(pj):
		return
	var c: Vector2i = mamoa.celda
	position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	pj.position = position
	if jugador != null and is_instance_valid(jugador):
		var d: Vector3 = jugador.position - position
		d.y = 0.0
		if d.length() > 0.05:
			mirada = d.normalized()
			pj.mirar(mirada, 1.0)                               # de cara a ella desde el primer fotograma
	pj.visible = true
	pj.animacion_actual = ""
	pj.set_velocidad_animacion(1.0)
	var arbol: ArbolAnimPj = pj.arbol()
	var clip: String = pj.clip_de(ROL_CLIP_SURGIR)
	if clip != "" and arbol != null and arbol.pedir(ESTADO_SURGIR, clip, {"bucle": Animation.LOOP_NONE, "vel": 1.0, "mezcla": 0.0, "reiniciar": true}):
		pj.animacion_actual = ROL_CLIP_SURGIR
	PlayLog.event("mouro_surge", {"celda": [c.x, c.y]})


func _ia(delta: float) -> void:
	if _empuje.length() > 0.1:
		_mover_paso(_empuje * delta, true)
		_empuje = _empuje.lerp(Vector3.ZERO, clampf(DECAIMIENTO_EMPUJE * delta, 0.0, 1.0))
	if _fase_empuje != FASE_NINGUNA or stun_timer > 0.0 or congelado > 0.0 or interrupcion > 0.0:
		if stun_timer > 0.0:
			stun_timer -= delta
		elif interrupcion > 0.0 and _fase_empuje == FASE_NINGUNA and congelado <= 0.0:
			interrupcion -= delta
		_cortar_toque()
		moviendo = 0
		return
	if quieto or jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		objetivo = null
		moviendo = 0
		_cortar_toque()
		return
	if _atacando:
		moviendo = 0
		_seguir_toque(delta)
		return
	var ve: bool = _ve(RADIO_VER if objetivo == null else RADIO_PERDER)
	if ve:
		if objetivo == null:
			flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0), "!", Color(1, 0.85, 0.2))
		objetivo = jugador
		vista_perdida = 0.0
		ultima_pos = jugador.position
		estado = "persigue"
	elif objetivo != null:
		vista_perdida += delta
		if vista_perdida > TIEMPO_PERDER:
			objetivo = null
			estado = "patrulla"
		else:
			estado = "busca"
	if objetivo == null:
		moviendo = 0
		return
	var meta: Vector3 = jugador.position if ve else ultima_pos
	var d: Vector3 = meta - position
	d.y = 0.0
	if d.length() > 0.05:
		mirada = d.normalized()
	if ve and d.length() <= alcance_toque() and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9:
		_empezar_toque()
		return
	if d.length() < 0.3:
		moviendo = 0
		return
	moviendo = 1
	_v_avance = VEL_ANDAR * vel_mult()
	_mover_paso(_dir_hacia(meta, delta) * _v_avance * delta, false, true)


## =====================================================================================================
##  El agarre
## =====================================================================================================

func _empezar_toque() -> void:
	_atacando = true
	_t_toque = 0.0
	_golpe_hecho = false
	toques += 1
	_quitar_aviso()
	if AVISAR_ATAQUES and mundo != null:
		_aviso = AvisoAtaque3D.circulo(mundo, position, alcance_toque(), T_AVISO_TOQUE, self)
		avisos_dados += 1
	_clip_toque()
	PlayLog.event("mouro_toque", {"distancia": snappedf(_dist(jugador.position), 0.1)})


func _seguir_toque(delta: float) -> void:
	_t_toque += delta
	if not _golpe_hecho and _t_toque >= T_AVISO_TOQUE:
		_golpe_hecho = true
		_aviso = null                                       # el aviso acaba solo en este instante
		_agarrar()
	if _t_toque >= T_AVISO_TOQUE + DESCANSO_TOQUE:
		_atacando = false


## Lo que se ve es lo que pega: si ella sigue dentro del círculo del aviso, daño y raíces.
func _agarrar() -> void:
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return
	var dentro: bool = _dist(jugador.position) <= alcance_toque() and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9
	if dentro:
		var antes: float = jugador.vida
		jugador.recibir_dano(DANO_TOQUE)                    # sin `desde`: no la empuja, la agarra
		if jugador.vida < antes:
			jugador.enraizar(T_ENRAIZA)
			golpes_dados += 1
	PlayLog.event("mouro_agarra", {"acierta": dentro})


## Golpeado, congelado, aturdido o empujado: el agarre se corta y su aviso, si aún no había caído.
func _cortar_toque() -> void:
	if _atacando:
		_atacando = false
		if not _golpe_hecho:
			_quitar_aviso()


## `ChargedSpellCast001` por su nombre (ver la cabecera); sin él, el rol `cast`.
func _clip_toque() -> void:
	if pj == null or not is_instance_valid(pj):
		return
	var arbol: ArbolAnimPj = pj.arbol()
	var clip: String = pj.clip_de(ROL_CLIP_TOQUE)        # 12/11: ya hay rol (`cast_agarre` en `Pj3D.SINONIMOS`)
	if clip != "" and arbol != null and arbol.pedir(ESTADO_TOQUE, clip, {"bucle": Animation.LOOP_NONE, "vel": 1.0, "mezcla": 0.15}):
		pj.animacion_actual = ESTADO_TOQUE
		pj.set_velocidad_animacion(1.0)
		return
	pj.animacion_actual = ""
	pj.set_velocidad_animacion(1.0)
	pj.jugar("cast", true)


func _animar() -> void:
	if _atacando and _fase_empuje == FASE_NINGUNA:
		if mirada.length() > 0.01:
			pj.mirar(mirada, 0.1)
		return                                              # el clip del agarre ya está puesto
	super()

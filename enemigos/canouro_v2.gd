class_name CanouroV2
extends RefCounted
## CANOURO v2 (6/11, rediseño aprobado por Pablo): la hiena que acecha en círculo, muerde y huye; su niebla negra protege y el fuego se la quita.
## Lo crea Combate3D en `_ready` para el id «canouro» (`CanouroV2.nuevo`) y lo consulta en cuatro sitios: `_ia` (rama «persigue»), `_conectar` (el mordisco), `golpe`
## (el fuego disipa la niebla) y `receive_damage` (×0,5 con niebla / ×1,5 expuesto). Interruptor: `CanouroV2.CANOURO_V2 = false` y vuelve el canouro genérico de antes
## (50 de vida, 20 de daño, zigzag y arrancada de MarchaCuadrupedo3D). Todo lo ajustable está en las constantes de abajo.
##
##  1. STATS PROPIOS: 40 de vida, defensa 0, mordisco de 12. Débil al agua como antes; ya NO resiste el fuego (con el fuego expuesto ×1,5 la resistencia ×0,75 sobraba y contradecía).
##  2. ACECHO: rodea a la jugadora a 4-5 u (tangencial, cambia de sentido cada 2,5-5 s) y nunca se le acerca de frente. Pasados 3-4 s de acecho EMBISTE (3,2 u/s), se para a
##     ~1,2 u, avisa 0,4 s (el aviso de siempre: AvisoAtaque3D.T_MIN, el contrato C3) y muerde; en cuanto muerde (o se le cancela) HUYE en diagonal hasta los 4,3 u y vuelve a rodear.
##  3. NIEBLA CON JUEGO: con la niebla puesta recibe ×0,5 de daño y la asistencia de apuntado (el `busca` de los proyectiles) lo ignora; sigue siendo golpeable por lo que
##     llegue físicamente hasta él. UN golpe de FUEGO disipa la niebla 8 s (fundido visual) y expuesto recibe ×1,5 y SÍ es apuntable; a los 8 s la niebla rebrota en 1,5 s.
##  4. LA BARRERA LO CASTIGA: si su mordisco lo para la burbuja de la jugadora, rebota y queda aturdido 1,5 s (la burbuja ya le devuelve su elemento: fuego ⇒ arde).

## Interruptor del rediseño (false = canouro genérico de antes).
static var CANOURO_V2: bool = true

# --- 1 · stats ---
const VIDA: float = 40.0
const DEFENSA: float = 0.0
const DANO_MORDISCO: float = 12.0

# --- 2 · acecho en círculo ---
const R_ORBITA: float = 4.5                  ## u a los que rodea (la banda buena es R_ORBITA_MIN..R_ORBITA_MAX)
const R_ORBITA_MIN: float = 4.0
const R_ORBITA_MAX: float = 5.0
const V_ORBITA: float = 1.5                  ## u/s rodeando (> v_cambio 1,4 del perfil: usa el clip Gallop, así que los pies no patinan)
const V_ACERCARSE: float = 2.2               ## u/s al venir de lejos / al rodear un obstáculo (= v_perseguir del perfil)
const T_SENTIDO_MIN: float = 2.5             ## s entre cambios de sentido del giro
const T_SENTIDO_MAX: float = 5.0
const T_ESPERA_MIN: float = 3.0              ## s de acecho (ya en su banda y a la vista) antes de cada embestida
const T_ESPERA_MAX: float = 4.0
const T_ESPERA_INICIAL_MIN: float = 2.0     ## la primera, un poco antes
const T_ESPERA_INICIAL_MAX: float = 3.0
const SEPARACION_EMBESTIDAS_S: float = 1.5   ## entre las embestidas de dos canouros distintos (que no muerdan a la vez)
const MIRAR_ADELANTE: float = 0.9            ## u: si ahí delante no cabe (muro, agua, árbol), cambia de sentido

# --- embestida y mordisco ---
const V_EMBESTIDA: float = 3.2               ## u/s (el Gallop del perfil llega a 3,4 sin patinar: v_clip 1,55 × vel_max 2,2)
const T_EMBESTIDA_MAX: float = 2.5           ## s: si no llega, desiste
const D_EMBESTIDA_ABORTA: float = 9.0        ## u: si la jugadora huye más lejos, desiste
const D_MORDISCO: float = 1.2                ## u a los que se para a morder (= Combate3D.RANGO_ATAQUE)
const ALCANCE_MORDISCO: float = 1.7          ## u: hasta dónde llega el mordisco cuando sale (= RANGO_ATAQUE + 0,5, como el golpe de los goblins)
const T_AVISO_MORDISCO: float = 0.4          ## s de preparación visible (= AvisoAtaque3D.T_MIN: el contrato C3 no deja menos)
const T_RECUPERA: float = 0.25               ## s que sigue en la pose tras morder antes de huir

# --- huida ---
const V_HUIDA: float = 2.8
const D_HUIDA_FIN: float = 4.3               ## u: al llegar aquí vuelve a rodear
const T_HUIDA_MAX: float = 2.5
const DESVIO_HUIDA_GRADOS: float = 40.0      ## huye en diagonal hacia su lado de giro (el cuerpo gira a 3,6 rad/s: de frente a espaldas tardaría casi 1 s)

# --- 3 · niebla ---
const MULT_NIEBLA: float = 0.5
const MULT_EXPUESTO: float = 1.5
const T_EXPUESTO: float = 8.0                ## s sin niebla tras un golpe de fuego
const T_DISIPAR: float = 0.6                 ## s del fundido al disiparse
const T_REBROTE: float = 1.5                 ## s en que vuelve a crecer (ya cuenta como niebla puesta)

# --- 4 · barrera ---
const T_ATURDIDO_BARRERA: float = 1.5
const V_REBOTE: float = 5.0                  ## u/s iniciales del rebote hacia fuera (decae solo: recorre ~0,7 u)

enum Fase { ORBITA, EMBESTIDA, MORDER, HUIDA }
enum Niebla { PUESTA, EXPUESTA, REBROTANDO }

var fase: Fase = Fase.ORBITA
var niebla_estado: Niebla = Niebla.PUESTA
var mordiscos: int = 0                       ## cuántos mordiscos han salido (pruebas)
var mordiscos_parados: int = 0               ## cuántos los ha parado la burbuja

var _c: Combate3D = null
var _sentido: float = 1.0
var _t_sentido: float = 3.0
var _t_espera: float = 2.5
var _t_fase: float = 0.0
var _t_bloq: float = 0.0
var _t_niebla: float = 0.0
var _mordido: bool = false                   ## el golpe del mordisco en curso ya salió

static var _frame_ultima_embestida: int = -100000


## Crea el canouro v2 de `c` y le pone sus stats. Devuelve null con el interruptor apagado.
static func nuevo(c: Combate3D) -> CanouroV2:
	if not CANOURO_V2 or c == null:
		return null
	var v := CanouroV2.new()
	v._c = c
	c.vida_max = VIDA
	c.health = VIDA
	c.defensa = DEFENSA
	c.resiste = ""                           # débil al agua (como antes); sin resistencia al fuego
	c.nombre = "Canouro"
	v._sentido = 1.0 if randf() < 0.5 else -1.0
	v._t_sentido = randf_range(T_SENTIDO_MIN, T_SENTIDO_MAX)
	v._t_espera = randf_range(T_ESPERA_INICIAL_MIN, T_ESPERA_INICIAL_MAX)
	return v


# ======================================================================================================================
#  Niebla con juego
# ======================================================================================================================

## Cada fotograma (desde Combate3D._physics_process): los relojes de la niebla.
func tick(delta: float) -> void:
	match niebla_estado:
		Niebla.EXPUESTA:
			_t_niebla -= delta
			if _t_niebla <= 0.0:
				niebla_estado = Niebla.REBROTANDO
				_t_niebla = T_REBROTE
				if _c._niebla != null and is_instance_valid(_c._niebla):
					_c._niebla.rebrotar(T_REBROTE)
		Niebla.REBROTANDO:
			_t_niebla -= delta
			if _t_niebla <= 0.0:
				niebla_estado = Niebla.PUESTA


## ¿Está expuesto (sin niebla)? Solo entonces recibe ×1,5 y lo apunta la asistencia.
func expuesto() -> bool:
	return niebla_estado == Niebla.EXPUESTA


## La asistencia de apuntado (el `busca` de los proyectiles) solo lo ve sin niebla.
func apuntable() -> bool:
	return expuesto()


## Multiplicador de TODO el daño que recibe (golpes, quemadura, veneno…).
func mult_dano() -> float:
	return MULT_EXPUESTO if expuesto() else MULT_NIEBLA


## Lo llama `Combate3D.golpe` antes de calcular nada: un golpe de fuego disipa la niebla (y este mismo golpe ya lo encuentra expuesto). Otro golpe de fuego renueva los 8 s.
func al_golpe(hechizo: Hechizo) -> void:
	if hechizo == null or not Materia.calienta(Materia.de(hechizo)):
		return
	disipar()


func disipar() -> void:
	var antes: Niebla = niebla_estado
	niebla_estado = Niebla.EXPUESTA
	_t_niebla = T_EXPUESTO
	if _c._niebla != null and is_instance_valid(_c._niebla):
		_c._niebla.disipar(T_DISIPAR)
	if antes != Niebla.EXPUESTA:
		_c.texto("¡Sin niebla!", Combate3D.COLORES.get("fuego", Color(1.0, 0.5, 0.2)), 0.28)
		PlayLog.event("canouro_sin_niebla", {"t": T_EXPUESTO})


# ======================================================================================================================
#  IA: acecho, embestida, mordisco y huida
# ======================================================================================================================

## La rama «persigue» de `Combate3D._ia` para el canouro. `vel` = vel_mult() (mojado / lento).
func ia(delta: float, vel: float) -> void:
	var c: Combate3D = _c
	var j: Jugador3D = c.jugador
	var al_j: Vector3 = j.position - c.position
	al_j.y = 0.0
	var r: float = al_j.length()
	if r > 0.05:
		c.mirada = al_j / r                  # siempre de cara a la presa (el cuerpo gira con su velocidad angular máxima; la cabeza la sigue)
	c._carga = 0.0
	match fase:
		Fase.MORDER:
			c.moviendo = 0
			if c._ataque <= 0.0:
				_empezar_huida()
		Fase.EMBESTIDA:
			_embestir(delta, vel, r)
		Fase.HUIDA:
			_huir(delta, vel, r, al_j)
		_:
			_orbitar(delta, vel, r, al_j)


## Un paso hacia `dir` a `v` u/s con el giro suave de la marcha. false si no se pudo mover.
func _andar(dir: Vector3, v: float, delta: float, por_ruta: bool = false) -> bool:
	var c: Combate3D = _c
	c.moviendo = 2
	c._v_avance = v
	c._modo_marcha = ""
	var paso: Vector3 = dir * v * delta
	if c._marcha != null:
		paso = c._marcha.paso_suave(paso, delta, false)
	return c._mover_paso(paso, false, por_ruta)


## Elige la primera dirección de `candidatas` en la que cabe el cuerpo `MIRAR_ADELANTE` u más allá; si es la 2.ª (la opuesta), cambia de sentido. Sin ninguna, la primera.
func _primera_libre(candidatas: Array) -> Vector3:
	var c: Combate3D = _c
	for i in range(candidatas.size()):
		var d: Vector3 = candidatas[i]
		if c._puede_estar(c.position + d * MIRAR_ADELANTE):
			if i == 1:
				_sentido = -_sentido
				_t_sentido = randf_range(T_SENTIDO_MIN, T_SENTIDO_MAX)
			return d
	return candidatas[0]


func _orbitar(delta: float, vel: float, r: float, al_j: Vector3) -> void:
	var c: Combate3D = _c
	var j: Jugador3D = c.jugador
	_t_sentido -= delta
	if _t_sentido <= 0.0:
		_sentido = -_sentido
		_t_sentido = randf_range(T_SENTIDO_MIN, T_SENTIDO_MAX)
	var u: Vector3 = -al_j / r if r > 0.05 else Vector3.RIGHT      # de la jugadora a él
	var a_vista: bool = Terreno3D.linea_libre(c.position, j.position)
	if not a_vista:
		# Algo se interpone (árbol, muro): rodea por la ruta hasta tenerla a la vista.
		_andar(c._dir_hacia(j.position, delta), V_ACERCARSE * vel, delta, true)
		return
	var k: float = clampf((R_ORBITA - r) / 1.5, -1.0, 1.0)         # >0: demasiado cerca (hacia fuera) · <0: demasiado lejos (hacia dentro)
	var t1: Vector3 = Vector3(-u.z, 0.0, u.x) * _sentido
	var dir_a: Vector3 = (t1 * 0.8 + u * k).normalized()
	var dir_b: Vector3 = (-t1 * 0.8 + u * k).normalized()
	var dir_c: Vector3 = (-u).normalized() if r > R_ORBITA_MIN else u
	var dir: Vector3 = _primera_libre([dir_a, dir_b, dir_c])
	var v: float = V_ACERCARSE if r > R_ORBITA_MAX + 0.7 else V_ORBITA
	var movido: bool = _andar(dir, v * vel, delta)
	if not movido:
		_t_bloq += delta
		if _t_bloq > 0.3:
			_sentido = -_sentido                 # bloqueado: da la vuelta
			_t_bloq = 0.0
	else:
		_t_bloq = 0.0
	# Reloj de la embestida: solo corre estando a la vista y en su banda de acecho.
	if r >= R_ORBITA_MIN - 0.5 and r <= R_ORBITA_MAX + 0.7:
		_t_espera -= delta
	if _t_espera <= 0.0 and not j.muerto and Engine.get_physics_frames() - _frame_ultima_embestida > int(SEPARACION_EMBESTIDAS_S * Engine.physics_ticks_per_second):
		_empezar_embestida()


func _empezar_embestida() -> void:
	fase = Fase.EMBESTIDA
	_t_fase = 0.0
	_t_bloq = 0.0
	_frame_ultima_embestida = Engine.get_physics_frames()


func _embestir(delta: float, vel: float, r: float) -> void:
	var c: Combate3D = _c
	var j: Jugador3D = c.jugador
	_t_fase += delta
	if j.muerto or _t_fase > T_EMBESTIDA_MAX or r > D_EMBESTIDA_ABORTA:
		_volver_a_orbitar()
		return
	if r <= D_MORDISCO:
		_empezar_mordisco()
		return
	var movido: bool = _andar(c._dir_hacia(j.position, delta), V_EMBESTIDA * vel, delta, true)
	_t_bloq = 0.0 if movido else _t_bloq + delta
	if _t_bloq > 0.5:
		_volver_a_orbitar()                      # atascado: desiste


## Se planta, avisa y muerde (el golpe sale a los T_AVISO_MORDISCO s). El clip de ataque se acelera para que su zarpazo caiga justo ahí y se corta poco después.
func _empezar_mordisco() -> void:
	var c: Combate3D = _c
	fase = Fase.MORDER
	_mordido = false
	c.moviendo = 0
	var dur: float = c.pj.duracion("attack")
	var momento: float = c.pj.momento_golpe("attack")
	var vel_anim: float = 1.0
	if dur > 0.0:
		vel_anim = clampf(dur * momento / (T_AVISO_MORDISCO * c.ritmo()), 0.4, 8.0)
	var total: float = T_AVISO_MORDISCO + T_RECUPERA
	c._ataque = total
	c._t_anim = total
	c._ataque_vel = vel_anim
	c.anim_orden = "attack"
	c._ataque_id += 1
	c._golpe_pendiente = true
	c.get_tree().create_timer(T_AVISO_MORDISCO, false).timeout.connect(c._efecto_ataque.bind(c._ataque_id, c._conectar))
	c._avisar_ataque(c._conectar, T_AVISO_MORDISCO)
	PlayLog.event("goblin_ataca", {"duracion": snappedf(total, 0.01), "efecto_en": snappedf(T_AVISO_MORDISCO, 0.01), "canouro": true})


## El golpe del mordisco (lo llama `Combate3D._conectar`). Si la burbuja de la jugadora lo para: rebota y queda aturdido.
func al_conectar() -> void:
	var c: Combate3D = _c
	var j: Jugador3D = c.jugador
	_mordido = true
	if c.muerto or j == null or not is_instance_valid(j) or c.stun_timer > 0.0 or c.interrupcion > 0.0 or c.congelado > 0.0:
		return
	if c._dist(j.position) > ALCANCE_MORDISCO or absf(j.position.y - c.position.y) >= Terreno3D.ALTO_NIVEL * 0.9:
		return
	mordiscos += 1
	var b: Variant = c.lanz.get("_barrera_activa") if c.lanz != null else null
	var habia_burbuja: bool = b != null and is_instance_valid(b) and b.get("reventada") == false      # 13/11 (T9): ya no hay `burbuja` (todo `_barrera_activa` es una Burbuja)
	j.recibir_dano(DANO_MORDISCO, c.position)
	if habia_burbuja and is_instance_valid(b) and b.get("reventada") == true:
		mordiscos_parados += 1
		_rebotar(j)


func _rebotar(j: Jugador3D) -> void:
	var c: Combate3D = _c
	var d: Vector3 = c.position - j.position
	d.y = 0.0
	if d.length() < 0.01:
		d = -c.mirada
	c._empuje += d.normalized() * V_REBOTE            # resbala hacia fuera sin salir volando (el vuelo del `push` sumaría su tiempo al aturdimiento)
	c.stun_timer = maxf(c.stun_timer, T_ATURDIDO_BARRERA)
	c._carga = 0.0
	c.texto("¡Rebota!", Color(0.6, 0.9, 1.0), 0.28)
	PlayLog.event("canouro_rebota", {"aturdido": T_ATURDIDO_BARRERA})
	_volver_a_orbitar()


func _empezar_huida() -> void:
	fase = Fase.HUIDA
	_t_fase = 0.0
	_t_bloq = 0.0


func _huir(delta: float, vel: float, r: float, al_j: Vector3) -> void:
	var c: Combate3D = _c
	_t_fase += delta
	if r >= D_HUIDA_FIN or _t_fase > T_HUIDA_MAX:
		_volver_a_orbitar()
		return
	var u: Vector3 = -al_j / r if r > 0.05 else -c.mirada
	var t1: Vector3 = Vector3(-u.z, 0.0, u.x) * _sentido
	var a: float = deg_to_rad(DESVIO_HUIDA_GRADOS)
	var dir_a: Vector3 = (u * cos(a) + t1 * sin(a)).normalized()
	var dir_b: Vector3 = (u * cos(a) - t1 * sin(a)).normalized()
	var dir: Vector3 = _primera_libre([dir_a, dir_b, u])
	var movido: bool = _andar(dir, V_HUIDA * vel, delta)
	_t_bloq = 0.0 if movido else _t_bloq + delta
	if _t_bloq > 0.4:
		_volver_a_orbitar()


func _volver_a_orbitar() -> void:
	fase = Fase.ORBITA
	_t_fase = 0.0
	_t_bloq = 0.0
	_t_espera = randf_range(T_ESPERA_MIN, T_ESPERA_MAX)

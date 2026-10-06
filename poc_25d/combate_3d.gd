class_name Combate3D
extends Area3D

## COMBATE EN 3D Y LA IA DEL GOBLIN GUERRERO (4.3). Dueño: Juego.
##
## Es el `CombateComun` del 2D (la MISMA tabla de debilidades, efectos y botín) más la IA de `goblin_guerrero.gd`, en un
## solo nodo. Se cuelga de un `Pj3D` (el modelo del Pipeline, que no sabe nada de IA) con `Combate3D.equipar(...)`.
## Cambios por ser 3D, y solo esos:
##   - un Area3D en la capa CAPA_REACTIVO que implementa el contrato on_spell_hit(rune_data, direccion: Vector3)
##   - el tinte va en los materiales del modelo (`albedo_color`) y no en `modulate`
##   - la barra de vida es una malla que mira a la cámara, y los números son Label3D
##   - las distancias están en unidades del 3D: 1 casilla = 2,3 u (en el 2D, 64 px)
##   - `anim_orden`: la IA pide una animación por su nombre y este nodo la traduce a Pj3D.jugar() (como MsActor)
##
## Posición: el Area3D es HERMANO del modelo, no hijo, para que su `position` sea la del mundo. Cada fotograma copia la
## del modelo, y la IA es la que mueve al modelo.
##
## Debilidad del guerrero: AGUA (x2). Resiste FUEGO (x0,5).
##   fuego   daño + QUEMADURA (3 cada 0,5 s durante 3 s). Mojado la apaga.
##   agua    daño + MOJADO (6 s): -25 % de velocidad; el rayo le hace +50 % y salta.
##   rayo    daño alto + ATURDE; si está mojado, x1,5 y SALTA al más cercano.
##   hielo   poco daño + CONGELA; mojado, congela más y hace +15.
##   viento  casi sin daño: INTERRUMPE y EMPUJA.   tierra  pedrada + retroceso y lentitud (3 s).

const COLORES: Dictionary = {
	"fuego": Color(1.0, 0.45, 0.2), "agua": Color(0.35, 0.65, 1.0), "rayo": Color(1.0, 0.95, 0.35),
	"hielo": Color(0.65, 0.95, 1.0), "viento": Color(0.75, 1.0, 0.8), "tierra": Color(0.75, 0.55, 0.3),
}
const DANO_EXTRA: Dictionary = {"tierra": 18.0, "viento": 0.0}
const FUERZA_POR_ELEMENTO: Dictionary = {"viento": 2600.0, "tierra": 2200.0, "agua": 600.0, "fuego": 500.0,
	"hielo": 300.0, "rayo": 400.0}
const MULT_DEBIL: float = 2.0
const MULT_RESISTE: float = 0.5
const TIEMPO_BARRA: float = 4.0
const ESCALA_EMPUJE: float = 2.3 / 64.0 * 0.1      ## 2D: dir * fuerza * 0.1 px/s; aquí en u/s

## --- IA (px del 2D pasados a unidades: 300 px ≈ 2,5 casillas, §4.3 del plan) ---
const RADIO_DETECCION: float = 5.75
const RADIO_SOLTAR: float = 10.0
const TIEMPO_PERDER: float = 3.5
const VEL_PERSEGUIR: float = 2.4                   ## entre andar (1,6) y correr (3,0) del jugador
const VEL_PATRULLA: float = 1.0
const DISTANCIA_PATRULLA: float = 2.0
const RANGO_ATAQUE: float = 1.2
const PREPARAR_GOLPE: float = 0.6
const DESCANSO_GOLPE: float = 1.6
const DANO_GOLPE: float = 20.0
const T_ANIM_ATAQUE: float = 0.8              ## solo si el modelo no tiene clip de ataque
## El ataque se reproduce ENTERO (el clip dura 3-5 s): mientras dura, el goblin no anda ni se gira.
const VEL_ANIM_GUERRERO: float = 1.0
const VEL_ANIM_ARQUERO: float = 1.25
const MOMENTO_GOLPE_GUERRERO: float = 0.19    ## fracción del clip LeftSlash en que cae el golpe (~0,6 s de 3,2)
const VIDA_MAXIMA: float = 100.0
const ORO_BOTIN: int = 10
const ALTO_BARRA_EXTRA: float = 0.28

## --- Arquero (modelo goblin_archer*): dispara desde lejos y retrocede si te acercas ---
const ARQUERO_ALCANCE: float = 6.5
const ARQUERO_MIN: float = 2.4
const PREPARAR_FLECHA: float = 0.9
const DESCANSO_FLECHA: float = 2.2
const DANO_FLECHA: float = 12.0
const VEL_FLECHA: float = 9.0
const RADIO_IMPACTO_FLECHA: float = 0.75

var pj: Pj3D = null
var mundo: Node3D = null
var jugador: Jugador3D = null
var lanz: Lanzador3D = null

var health: float = VIDA_MAXIMA
var vida_max: float = VIDA_MAXIMA
var debil: String = "agua"
var resiste: String = "fuego"
var nombre: String = "Goblin guerrero"
var tinte: Color = Color(1.12, 0.9, 0.85)
var oro: int = ORO_BOTIN
var altura: float = 0.85                ## alto del modelo, para la barra

var quemando: float = 0.0
var mojado: float = 0.0
var congelado: float = 0.0
var lento: float = 0.0
var stun_timer: float = 0.0
var interrupcion: float = 0.0

var estado: String = "patrulla"         ## patrulla, persigue, busca, vuelve
var objetivo: Node3D = null
var vista_perdida: float = 0.0
var ultima_pos: Vector3 = Vector3.ZERO
var mirada: Vector3 = Vector3(0, 0, 1)
var moviendo: int = 0                   ## 0 quieto, 1 anda, 2 corre
var anim_orden: String = ""             ## animación puntual que se reproduce una vez
var casa: Vector3 = Vector3.ZERO
var muerto: bool = false
var arquero: bool = false               ## ataque a distancia (lo decide el modelo: goblin_archer*)

var _direccion: float = 1.0
var _carga: float = 0.0
var _descanso: float = 0.0
var _empuje: Vector3 = Vector3.ZERO
var _tick_fuego: float = 0.0
var _barra_t: float = 0.0
var _vida_mostrada: float = 1.0
var _destello: float = 0.0
var _t_anim: float = 0.0
var _ataque: float = 0.0       ## s que le quedan a la animación de ataque en curso (bloquea movimiento y giro)
var _ataque_vel: float = 1.0
var _ataque_id: int = 0        ## cambia al cancelar el ataque: los golpes/flechas pendientes se descartan
var _materiales: Array = []
var _bases: Array = []
var _barra_fondo: MeshInstance3D = null
var _barra_perdida: MeshInstance3D = null
var _barra_vida: MeshInstance3D = null
var _marca_debil: Label3D = null
var _nombre_etiqueta: Label3D = null
const ANCHO_BARRA: float = 0.8
const ALTO_BARRA: float = 0.09


## Crea el combate de `modelo` y lo cuelga del mundo.
static func equipar(modelo: Pj3D, p_mundo: Node3D, p_jugador: Jugador3D, p_lanz: Lanzador3D) -> Combate3D:
	var c := Combate3D.new()
	c.name = "Combate_" + modelo.id
	c.pj = modelo
	c.mundo = p_mundo
	c.jugador = p_jugador
	c.lanz = p_lanz
	c.position = modelo.position
	c.casa = modelo.position
	c.altura = modelo.alto_modelo() * modelo.scale.y
	p_mundo.add_child(c, true)
	return c


func _ready() -> void:
	add_to_group("combate3d")
	add_to_group("goblins")
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	var forma := CapsuleShape3D.new()
	forma.radius = 0.32
	forma.height = maxf(altura, 0.7)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position = Vector3(0, forma.height * 0.5, 0)
	add_child(cs)
	health = vida_max
	arquero = pj != null and pj.id.begins_with("goblin_archer")
	if arquero:
		nombre = "Goblin arquero"
	_vida_mostrada = 1.0
	_ultima_celda_ok()
	# Materiales del modelo (cada copia tiene los suyos) y su color de partida
	var lista: Variant = pj.get("_materiales")
	if lista is Array:
		for m in (lista as Array):
			if m is StandardMaterial3D:
				_materiales.append(m)
				_bases.append((m as StandardMaterial3D).albedo_color)
	_construir_barra()
	_aplicar_tinte(tinte)


func _ultima_celda_ok() -> void:
	ultima_pos = position


## =====================================================================================================
##  Contrato on_spell_hit, push y niveles
## =====================================================================================================

func nivel_altura() -> int:
	return 1


func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO) -> void:
	golpe(rune_data, direccion)
	if objetivo == null and jugador != null and not muerto and _ve(RADIO_SOLTAR):
		objetivo = jugador          # un golpe te hace mirar a quien viene


func push(direccion: Vector3, fuerza: float) -> void:
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() < 0.01 or muerto:
		return
	_empuje += d.normalized() * fuerza * ESCALA_EMPUJE


## =====================================================================================================
##  Daño y efectos (la tabla de CombateComun)
## =====================================================================================================

func multiplicador(elemento: String) -> float:
	if elemento == "":
		return 1.0
	if elemento == debil:
		return MULT_DEBIL
	if elemento == resiste or (resiste == "agua" and elemento == "hielo"):
		return MULT_RESISTE
	return 1.0


func vel_mult() -> float:
	if congelado > 0.0:
		return 0.0
	var m: float = 1.0
	if mojado > 0.0:
		m *= 0.75
	if lento > 0.0:
		m *= 0.6
	return m


func golpe(rune_data: RuneData, direccion: Vector3) -> void:
	if muerto or rune_data == null:
		return
	var el: String = Objetos.elemento_de(rune_data)
	var base: float = rune_data.damage + float(DANO_EXTRA.get(el, 0.0))
	var mult: float = multiplicador(el)

	match el:
		"fuego":
			if mojado > 0.0:
				mojado = 0.0
				texto("¡Vapor!", Color(0.85, 0.9, 1.0))
			else:
				quemando = 3.0
		"agua":
			mojado = 6.0
			quemando = 0.0
		"rayo":
			if mojado > 0.0:
				base *= 1.5
				_arco_cercano(base * 0.5)
		"hielo":
			congelado = 2.5 if mojado > 0.0 else 1.5
			if mojado > 0.0:
				base += 15.0
			quemando = 0.0
		"viento":
			interrupcion = 0.7
			_carga = 0.0
		"tierra":
			lento = 3.0

	var dano: float = base * mult
	if mult > 1.0:
		texto("¡Débil!", COLORES.get(debil, Color.WHITE), 0.28)
	elif mult < 1.0 and base > 0.0:
		texto("Resiste", Color(0.7, 0.7, 0.7), 0.28)

	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() > 0.01 and el != "viento":      # el empuje del viento (y la atracción) lo da Lanzador3D por push()
		push(d, float(FUERZA_POR_ELEMENTO.get(el, 400.0)))
	if rune_data.tags.has("electrico"):
		_aturdir()
	if dano > 0.0:
		receive_damage(dano)
	else:
		_destello = 0.12
	PlayLog.event("golpe_goblin", {"elemento": el, "dano": snappedf(dano, 0.1), "vida": snappedf(health, 0.1),
		"mult": mult})


func _aturdir() -> void:
	stun_timer = 1.2
	_carga = 0.0


func _arco_cercano(dano: float) -> void:
	var mejor: Combate3D = null
	var dmin: float = 4.5
	for n in get_tree().get_nodes_in_group("combate3d"):
		if n == self or not is_instance_valid(n) or (n as Combate3D).muerto:
			continue
		var dd: float = position.distance_to((n as Node3D).position)
		if dd < dmin:
			dmin = dd
			mejor = n as Combate3D
	if mejor != null:
		mejor.receive_damage(dano)
		mejor.texto("¡Descarga!", COLORES["rayo"])


func receive_damage(cantidad: float, _desde_nivel: int = 0) -> void:
	if health <= 0.0:
		return
	health -= cantidad
	_barra_t = TIEMPO_BARRA
	_destello = 0.10
	texto(str(int(round(cantidad))), Color(1, 0.95, 0.85))
	if stun_timer <= 0.0 and health > 0.0:
		anim_orden = "hit"
		interrupcion = maxf(interrupcion, 0.3)
	if health <= 0.0:
		_morir()


func texto(txt: String, color: Color, extra_alto: float = 0.0) -> void:
	Combate3D.flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA + extra_alto, 0), txt, color)


## Número o aviso que sube y se desvanece. Estático: lo usan también Jugador3D y Lanzador3D.
static func flotante(en: Node, pos: Vector3, txt: String, color: Color) -> void:
	if en == null or not en.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = txt
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.0045
	l.font_size = 44
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position = pos + Vector3(randf_range(-0.15, 0.15), 0, 0)
	en.add_child(l)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 0.7, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## =====================================================================================================
##  Fotograma: efectos, IA, movimiento y animación
## =====================================================================================================

func _physics_process(delta: float) -> void:
	if muerto or pj == null or not is_instance_valid(pj):
		return
	_efectos(delta)
	_ia(delta)
	_ajustar_al_suelo(delta)
	_animar()
	pj.position = position
	_dibujar_estado(delta)


func _efectos(delta: float) -> void:
	_barra_t = maxf(0.0, _barra_t - delta)
	_destello = maxf(0.0, _destello - delta)
	if quemando > 0.0:
		quemando -= delta
		_tick_fuego -= delta
		if _tick_fuego <= 0.0:
			_tick_fuego = 0.5
			receive_damage(3.0 * (MULT_DEBIL if debil == "fuego" else 1.0))
			if muerto:
				return
	mojado = maxf(0.0, mojado - delta)
	congelado = maxf(0.0, congelado - delta)
	lento = maxf(0.0, lento - delta)
	_t_anim = maxf(0.0, _t_anim - delta)
	_ataque = maxf(0.0, _ataque - delta)
	_descanso = maxf(0.0, _descanso - delta)


func _ia(delta: float) -> void:
	# Retroceso por golpes (decae solo)
	if _empuje.length() > 0.1:
		_mover_paso(_empuje * delta)
		_empuje = _empuje.lerp(Vector3.ZERO, clampf(7.0 * delta, 0.0, 1.0))
	if stun_timer > 0.0:
		stun_timer -= delta
		_cancelar_ataque()
		_carga = 0.0
		moviendo = 0
		return
	if congelado > 0.0:
		_cancelar_ataque()
		moviendo = 0
		_carga = 0.0
		return
	if interrupcion > 0.0:
		interrupcion -= delta
		_cancelar_ataque()
		_carga = 0.0
		moviendo = 0
		return

	# Animación de ataque a medias: se queda quieto y mirando donde estaba hasta que acabe.
	if _ataque > 0.0:
		moviendo = 0
		return
	var vel: float = vel_mult()
	var ve: bool = _ve(RADIO_DETECCION if objetivo == null else RADIO_SOLTAR)
	if ve:
		if objetivo == null:
			flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0), "!", Color(1, 0.85, 0.2))
			PlayLog.event("goblin_ve_al_jugador", {"distancia": snappedf(position.distance_to(jugador.position), 0.1)})
		objetivo = jugador
		vista_perdida = 0.0
		ultima_pos = jugador.position
		estado = "persigue"
	elif objetivo != null:
		vista_perdida += delta
		var lejos: bool = jugador != null and _dist(jugador.position) > RADIO_SOLTAR
		if vista_perdida > TIEMPO_PERDER or lejos:
			objetivo = null
			estado = "vuelve"
			PlayLog.event("goblin_se_rinde")
		else:
			estado = "busca"

	match estado:
		"persigue", "busca":
			if arquero and estado == "persigue":
				_ia_arquero(delta, vel)
				return
			var meta: Vector3 = jugador.position if estado == "persigue" else ultima_pos
			var d: Vector3 = meta - position
			d.y = 0.0
			if d.length() > 0.05:
				mirada = d.normalized()
			if estado == "persigue" and d.length() <= RANGO_ATAQUE:
				moviendo = 0
				_atacar(delta)
			elif d.length() > 0.3:
				_carga = 0.0
				moviendo = 2 if vel > 0.8 else 1
				_mover_paso(d.normalized() * VEL_PERSEGUIR * vel * delta)
			else:
				moviendo = 0
		"vuelve":
			_carga = 0.0
			var h: Vector3 = casa - position
			h.y = 0.0
			if h.length() < 0.25:
				estado = "patrulla"
				moviendo = 0
			else:
				mirada = h.normalized()
				moviendo = 1
				if not _mover_paso(h.normalized() * VEL_PATRULLA * 1.5 * vel * delta):
					estado = "patrulla"
		_:
			_patrullar(delta, vel)


func _patrullar(delta: float, vel: float) -> void:
	_carga = 0.0
	moviendo = 1
	mirada = Vector3(_direccion, 0.0, 0.0)
	var paso := Vector3(_direccion * VEL_PATRULLA * vel * delta, 0.0, 0.0)
	var movido: bool = _mover_paso(paso)
	if not movido or absf(position.x - casa.x) >= DISTANCIA_PATRULLA:
		_direccion *= -1.0


func _atacar(delta: float) -> void:
	if _descanso > 0.0:
		_carga = 0.0
		return
	_carga += delta
	if _carga >= PREPARAR_GOLPE:
		_carga = 0.0
		_descanso = DESCANSO_GOLPE
		_iniciar_ataque(VEL_ANIM_GUERRERO, MOMENTO_GOLPE_GUERRERO, _conectar)


## El arquero mantiene la distancia: se acerca hasta ARQUERO_ALCANCE, retrocede dentro de ARQUERO_MIN y dispara en medio.
func _ia_arquero(delta: float, vel: float) -> void:
	var d: Vector3 = jugador.position - position
	d.y = 0.0
	var dist: float = d.length()
	if dist > 0.05:
		mirada = d.normalized()
	if dist > ARQUERO_ALCANCE:
		_carga = 0.0
		moviendo = 2 if vel > 0.8 else 1
		_mover_paso(mirada * VEL_PERSEGUIR * vel * delta)
	elif dist < ARQUERO_MIN:
		_carga = 0.0
		moviendo = 1
		if not _mover_paso(-mirada * VEL_PATRULLA * 1.6 * vel * delta):
			moviendo = 0
			if dist <= RANGO_ATAQUE:
				_atacar(delta)      # acorralado: pega con el arco
	else:
		moviendo = 0
		if _descanso > 0.0:
			_carga = 0.0
			return
		_carga += delta
		if _carga >= PREPARAR_FLECHA:
			_carga = 0.0
			_descanso = DESCANSO_FLECHA
			_iniciar_ataque(VEL_ANIM_ARQUERO, pj.momento_golpe("attack"), _soltar_flecha)


## Lanza la animación de ataque entera y programa el golpe/la flecha en su momento. Hasta que acaba no se mueve.
func _iniciar_ataque(vel_anim: float, momento: float, efecto: Callable) -> void:
	var dur: float = pj.duracion("attack")
	if dur <= 0.0:
		dur = T_ANIM_ATAQUE
		vel_anim = 1.0
		momento = 0.3
	var total: float = dur / vel_anim
	_ataque = total
	_t_anim = total
	_ataque_vel = vel_anim
	anim_orden = "attack"
	_ataque_id += 1
	get_tree().create_timer(total * momento, false).timeout.connect(_efecto_ataque.bind(_ataque_id, efecto))
	PlayLog.event("goblin_ataca", {"duracion": snappedf(total, 0.01), "efecto_en": snappedf(total * momento, 0.01)})


func _efecto_ataque(id: int, efecto: Callable) -> void:
	if id == _ataque_id:
		efecto.call()


## Golpe, parálisis, hielo o muerte: la animación se corta y el golpe/flecha pendiente ya no sale.
func _cancelar_ataque() -> void:
	if _ataque > 0.0:
		_ataque = 0.0
		_t_anim = 0.0
		_ataque_id += 1


## La flecha sale hacia donde ESTÁ el jugador ahora y tarda en llegar: si se ha movido, falla.
func _soltar_flecha() -> void:
	if muerto or jugador == null or not is_instance_valid(jugador) or jugador.muerto or stun_timer > 0.0 \
			or interrupcion > 0.0 or congelado > 0.0:
		return
	var origen: Vector3 = position + Vector3(0.0, altura * 0.65, 0.0)
	var destino: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0)
	var bloqueada: bool = not Lanzador3D.linea_libre(position, jugador.position)
	var flecha := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.05, 0.05, 0.6)
	flecha.mesh = caja
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.45, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flecha.material_override = mat
	mundo.add_child(flecha)
	flecha.position = origen
	flecha.look_at(destino, Vector3.UP)
	var t: float = maxf(origen.distance_to(destino) / VEL_FLECHA, 0.1)
	var tw: Tween = flecha.create_tween()
	tw.tween_property(flecha, "position", destino, t)
	tw.tween_callback(_flecha_llega.bind(flecha, destino, bloqueada))
	PlayLog.event("flecha_goblin", {"bloqueada": bloqueada})


func _flecha_llega(flecha: Node3D, destino: Vector3, bloqueada: bool) -> void:
	if is_instance_valid(flecha):
		flecha.queue_free()
	if bloqueada or jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return
	var dx: float = jugador.position.x - destino.x
	var dz: float = jugador.position.z - destino.z
	if Vector2(dx, dz).length() <= RADIO_IMPACTO_FLECHA and absf(jugador.position.y + 0.8 - destino.y) < Lanzador3D.ALTO_NIVEL:
		jugador.recibir_dano(DANO_FLECHA, position)


func _conectar() -> void:
	if muerto or jugador == null or not is_instance_valid(jugador) or stun_timer > 0.0 or interrupcion > 0.0 \
			or congelado > 0.0:
		return
	if _dist(jugador.position) <= RANGO_ATAQUE + 0.5 and absf(jugador.position.y - position.y) < Lanzador3D.ALTO_NIVEL * 0.9:
		jugador.recibir_dano(DANO_GOLPE, position)


func _dist(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()


## ¿Ve al jugador? Distancia + línea de visión (árboles, muros y torres de tierra la cortan).
func _ve(radio: float) -> bool:
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return false
	if _dist(jugador.position) > radio:
		return false
	return Lanzador3D.linea_libre(position, jugador.position)


## Un goblin no sube ni nada: casillas a nivel 0 y que no sean agua. Desliza por los ejes.
func _mover_paso(paso: Vector3) -> bool:
	if paso.length() < 0.0001:
		return false
	for v in [paso, Vector3(paso.x, 0.0, 0.0), Vector3(0.0, 0.0, paso.z)]:
		var vv: Vector3 = v
		if vv.length() < 0.0001:
			continue
		var destino: Vector3 = position + vv
		if _puede_estar(destino):
			position.x = destino.x
			position.z = destino.z
			return true
	return false


func _puede_estar(p: Vector3) -> bool:
	var c: Vector2i = Lanzador3D.celda_de(p)
	if c == Lanzador3D.celda_de(position):
		return Lanzador3D.en_mapa(c)
	if not Lanzador3D.pisable(c, 0, false, 0, false):
		return false
	# Un escalón (del puente al suelo) se sube; un bloque no.
	return absf(Lanzador3D.y_pies(c) - position.y) <= 0.6


func _ajustar_al_suelo(delta: float) -> void:
	var c: Vector2i = Lanzador3D.celda_de(position)
	if Lanzador3D.es_agua(c):
		# Se le fue el suelo (hielo derretido): vuelve a su puesto, sin daño
		position = Vector3(casa.x, Lanzador3D.y_pies(Lanzador3D.celda_de(casa)), casa.z)
		estado = "patrulla"
		objetivo = null
		return
	if Lanzador3D.altura_en(c) > 0:
		# Le han levantado un bloque debajo: sube con él
		position.y = Lanzador3D.y_pies(c)
		return
	position.y = move_toward(position.y, Lanzador3D.y_pies(c), 6.0 * delta)


func _animar() -> void:
	if anim_orden != "":
		var orden: String = anim_orden
		anim_orden = ""
		pj.animacion_actual = ""
		if orden == "attack":
			pj.set_velocidad_animacion(_ataque_vel)
			pj.jugar(orden, true)
		else:
			pj.set_velocidad_animacion(1.0)
			pj.jugar(orden)
		if orden == "hit":
			_t_anim = maxf(_t_anim, 0.35)
	if _t_anim > 0.0:
		return
	if stun_timer > 0.0 or congelado > 0.0:
		pj.set_velocidad_animacion(0.0 if congelado > 0.0 else 1.0)
		return
	pj.set_velocidad_animacion(1.0)
	match moviendo:
		0:
			pj.jugar("idle")
		1:
			pj.jugar("walk")
		2:
			pj.jugar("run")
	if mirada.length() > 0.01 and (moviendo > 0 or estado == "persigue"):
		pj.mirar(mirada, 0.05)


## =====================================================================================================
##  Aspecto: tinte por material y barra de vida
## =====================================================================================================

func _aplicar_tinte(c: Color) -> void:
	for i in range(_materiales.size()):
		var m: StandardMaterial3D = _materiales[i]
		if is_instance_valid(m):
			var b: Color = _bases[i]
			m.albedo_color = Color(b.r * c.r, b.g * c.g, b.b * c.b, b.a)


func _dibujar_estado(delta: float) -> void:
	var c: Color = tinte
	if congelado > 0.0:
		c = c.lerp(Color(0.6, 0.9, 1.4), 0.7)
	elif quemando > 0.0:
		c = c.lerp(Color(1.5, 0.7, 0.4), 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.02))
	elif mojado > 0.0:
		c = c.lerp(Color(0.6, 0.75, 1.2), 0.45)
	if _destello > 0.0:
		c = Color(2.2, 2.2, 2.2)
	_aplicar_tinte(c)

	var fr: float = clampf(health / vida_max, 0.0, 1.0)
	_vida_mostrada = lerpf(_vida_mostrada, fr, clampf(8.0 * delta, 0.0, 1.0))
	_poner_barra(_barra_vida, fr)
	_poner_barra(_barra_perdida, _vida_mostrada)
	(_barra_vida.material_override as StandardMaterial3D).albedo_color = \
		Color(0.35, 0.9, 0.4) if fr > 0.5 else (Color(1.0, 0.8, 0.25) if fr > 0.25 else Color(1.0, 0.3, 0.25))
	_nombre_etiqueta.visible = _barra_t > 0.0


func _poner_barra(mi: MeshInstance3D, fr: float) -> void:
	var q: QuadMesh = mi.mesh as QuadMesh
	var ancho: float = maxf(ANCHO_BARRA * fr, 0.0001)
	q.size = Vector2(ancho, ALTO_BARRA * (0.66 if mi != _barra_fondo else 1.0))
	q.center_offset = Vector3(-ANCHO_BARRA * 0.5 + ancho * 0.5, 0.0, 0.0)


func _construir_barra() -> void:
	var alto: float = altura + ALTO_BARRA_EXTRA
	_barra_fondo = _quad(Color(0, 0, 0, 0.8), 0, alto)
	_barra_perdida = _quad(Color(1, 1, 1, 0.55), 1, alto)
	_barra_vida = _quad(Color(0.35, 0.9, 0.4), 2, alto)
	_barra_fondo.mesh = _quad_mesh()
	var q: QuadMesh = _barra_fondo.mesh as QuadMesh
	q.size = Vector2(ANCHO_BARRA + 0.04, ALTO_BARRA + 0.03)
	q.center_offset = Vector3.ZERO
	_marca_debil = Label3D.new()
	_marca_debil.text = "◆"
	_marca_debil.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marca_debil.no_depth_test = true
	_marca_debil.pixel_size = 0.004
	_marca_debil.font_size = 40
	_marca_debil.outline_size = 8
	_marca_debil.modulate = COLORES.get(debil, Color.WHITE)
	_marca_debil.position = Vector3(ANCHO_BARRA * 0.5 + 0.13, alto, 0.0)
	add_child(_marca_debil)
	_nombre_etiqueta = Label3D.new()
	_nombre_etiqueta.text = nombre
	_nombre_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nombre_etiqueta.no_depth_test = true
	_nombre_etiqueta.pixel_size = 0.0035
	_nombre_etiqueta.font_size = 36
	_nombre_etiqueta.outline_size = 8
	_nombre_etiqueta.position = Vector3(0.0, alto + 0.14, 0.0)
	_nombre_etiqueta.visible = false
	add_child(_nombre_etiqueta)


func _quad_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(ANCHO_BARRA, ALTO_BARRA)
	return q


func _quad(color: Color, prioridad: int, alto: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_mesh()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.render_priority = prioridad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, alto, 0)
	add_child(mi)
	return mi


## =====================================================================================================
##  Muerte y botín
## =====================================================================================================

func _morir() -> void:
	if muerto:
		return
	muerto = true
	collision_layer = 0
	monitorable = false
	remove_from_group("combate3d")
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = false
	_aplicar_tinte(tinte)
	Jugador3D.una_vez(pj, "death")
	var lista: Variant = mundo.get("_goblins")
	if lista is Array:
		(lista as Array).erase(pj)
	PlayLog.event("goblin_muere", {"nombre": nombre, "celda": [Lanzador3D.celda_de(position).x, Lanzador3D.celda_de(position).y]})
	Estado.i().enemigo_muerto.emit(Vector2(position.x, position.z), nombre)
	if oro > 0:
		Botin3D.soltar(mundo, jugador, oro, position)
	var tw: Tween = create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(pj, "scale", pj.scale * 0.01, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(pj):
			pj.queue_free()
		queue_free())


## Moneda de oro que se recoge al pasar cerca.
class Botin3D extends MeshInstance3D:
	var jugador: Jugador3D = null
	var cantidad: int = 10
	var _t: float = 0.0
	var _base_y: float = 0.0
	var _vivo: bool = true

	static func soltar(p_mundo: Node3D, p_jugador: Jugador3D, p_cantidad: int, pos: Vector3) -> Botin3D:
		var b := Botin3D.new()
		b.jugador = p_jugador
		b.cantidad = p_cantidad
		var esfera := SphereMesh.new()
		esfera.radius = 0.16
		esfera.height = 0.1
		esfera.radial_segments = 12
		esfera.rings = 4
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.82, 0.25)
		m.metallic = 0.6
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = Color(0.9, 0.6, 0.1)
		m.emission_energy_multiplier = 0.6
		esfera.material = m
		b.mesh = esfera
		b.name = "Oro"
		b.position = pos + Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(0.2, 0.6))
		b._base_y = pos.y + 0.3
		p_mundo.add_child(b)
		return b

	func _process(delta: float) -> void:
		if not _vivo:
			return
		_t += delta
		position.y = _base_y + sin(_t * 3.0) * 0.06
		rotate_y(delta * 2.0)
		if jugador != null and is_instance_valid(jugador) and not jugador.muerto:
			var d: float = Vector2(jugador.position.x - position.x, jugador.position.z - position.z).length()
			if d < 1.1 and absf(jugador.position.y - _base_y) < 1.4:
				_vivo = false
				Estado.i().dar_oro(cantidad)
				Combate3D.flotante(get_parent(), position + Vector3(0, 0.5, 0), "+%d oro" % cantidad, Color(1, 0.9, 0.4))
				PlayLog.event("oro", {"cantidad": cantidad, "total": Estado.i().oro})
				queue_free()

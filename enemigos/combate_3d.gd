class_name Combate3D
extends Area3D

## COMBATE EN 3D Y LA IA DEL GOBLIN GUERRERO (4.3). Dueño: Juego.
##
## Es la tabla de debilidades, efectos y botín que nació en el 2D (ya propia de este archivo, no hereda de nada) más la IA de `goblin_guerrero.gd`, en un
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
## HC3: el daño extra de la tierra (+18), la fuerza del golpe por elemento y las duraciones de estado ya no están aquí: salen de los `modificadores` de cada *_rune.tres.
const TICK_VENENO: float = 0.5               ## s entre dos pulsos del veneno (HC4)
const ELEMENTAL_QUEMA: float = 5.0             ## el elemental arde más que un goblin (los que no son elementales usan la `quema` del hechizo)
const MULT_DEBIL: float = 2.0
const MULT_RESISTE: float = 0.5
const TIEMPO_BARRA: float = 4.0
const ESCALA_EMPUJE: float = 2.3 / 64.0 * 0.1      ## 2D: dir * fuerza * 0.1 px/s; aquí en u/s

## --- SENSACIÓN DE GOLPE (17/10, Pablo: «que los hechizos se sientan poderosos»; LAB_CASTPOINT §3, diario 148) ---
## Son `static var` y no `const` A PROPÓSITO: un panel del laboratorio tiene que poder cambiarlas en vivo (`Combate3D.HITSTOP = 0.1`),
## y una `const` no se puede escribir. Se leen igual que una constante (`Combate3D.MULT_EMPUJE`). Valores confirmados por Pablo.
static var MULT_EMPUJE: float = 2.0            ## × sobre TODA fuerza de `push` (`fuerza_golpe` del Hechizo y también viento/atracción de Lanzador3D)
static var EMPUJE_MIN_CASILLAS: float = 0.35   ## ningún golpe con daño > 0 recorre menos de esto (× Terreno3D.casilla); a ×2 los básicos aún no se veían
static var MULT_EMPUJE_ELEMENTAL: float = 0.3  ## el elemental pesa: recibe este factor del empuje y del suelo (antes 0,15, sin ×2)
static var DECAIMIENTO_EMPUJE: float = 7.0     ## `lerp(empuje, 0, 7·dt)` por fotograma: el recorrido es v0 / 7 (de ahí la v0 mínima del suelo)
static var TEMBLOR_GOLPE: float = 0.25         ## intensidad (0–1) del temblor de cámara al golpear a un enemigo (Vfx3D.temblor)
static var TEMBLOR_DEBIL: float = 0.5          ## ... y si el elemento es su punto débil
static var HITSTOP: float = 0.06               ## s que se congela ESE enemigo al recibir un golpe con daño (IA, animación y empuje; el mundo no)
static var HITSTOP_DEBIL: float = 0.09         ## ídem si el golpe es de su elemento débil
static var DESTELLO_GOLPE: float = 0.20        ## s de blanco puro tras un golpe (antes 0,10 y tinte ×2,2, que dejaba ver la textura)
static var SQUASH_ESCALA: Vector3 = Vector3(1.25, 0.8, 1.25)   ## aplastamiento del modelo al golpe: vuelve a 1 en SQUASH_TIEMPO con TRANS_BACK
static var SQUASH_TIEMPO: float = 0.15
static var SALTO_ALTO: float = 0.25            ## u: salto SOLO visual (el cuerpo no se mueve) con los elementos de SALTO_ELEMENTOS
static var SALTO_TIEMPO: float = 0.3           ## s que dura (sube y baja)
static var SALTO_ELEMENTOS: Array = ["viento", "tierra"]
static var INTERRUPCION_GOLPE: float = 0.6     ## s sin atacar tras un golpe con daño (antes 0,3). El resto del daño sigue con INTERRUPCION_DANO
static var INTERRUPCION_DANO: float = 0.3      ## s que da cualquier otro daño (quemadura, arco del rayo): con 0,6 una quemadura no le dejaría atacar nunca
const DESTELLO_DANO: float = 0.10              ## destello del daño que no es golpe (quemadura): el de siempre, para que no parpadee en blanco

## --- IA (px del 2D pasados a unidades: 300 px ≈ 2,5 casillas, §4.3 del plan) ---
const RADIO_DETECCION: float = 5.75
const RADIO_SOLTAR: float = 10.0
const TIEMPO_PERDER: float = 3.5
const VEL_PERSEGUIR: float = 2.4                   ## entre andar (1,6) y correr (3,0) del jugador
const VEL_PATRULLA: float = 1.0
const DISTANCIA_PATRULLA: float = 2.0
const RANGO_ATAQUE: float = 1.2
const HISTERESIS_RANGO: float = 1.2              ## empieza a pegar a `rango`, deja de esperar al pasar de rango*1,2 (evita parpadear entre atacar y perseguir)
const MARGEN_CANCELAR: float = 1.4               ## si el jugador se va más allá de rango*1,4 ANTES de que salga el golpe, se cancela el ataque
const ELEM_ZANCADA_WALK: float = 3.5             ## metros que avanza el elemental en un ciclo de `walk` a velocidad 1 (ESTIMADO, afinar a ojo)
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

## --- ELEMENTAL DE BOSQUE (8/10): élite lento que pega con el puño, conjura enredaderas vinculadas y se cura con agua ---
const ID_ELEMENTAL: String = "elemental_bosque"
const ELEM_VIDA: float = 1000.0
const ELEM_VEL: float = 0.7                    ## × la velocidad de un goblin
const ELEM_DANO_GOLPE: float = 45.0
const ELEM_ALTO_REF: float = 1.7              ## altura para la que se midieron rango, golpe, cápsula y brotes; todo escala con altura/esto
const ELEM_RANGO: float = 2.0                  ## distancia (centro a centro) a la que empieza a pegar
const ELEM_MOMENTO_GOLPE: float = 0.6          ## fracción del clip `attack` en que el puño toca el suelo (SIN medir: 0,55–0,65)
const ELEM_ALCANCE_GOLPE: float = 2.8          ## el área del puñetazo: hasta tanto por delante...
const ELEM_ANCHO_GOLPE: float = 1.3            ## ...y tanto a cada lado (no es un punto)
const ELEM_DESCANSO: float = 1.2
const ELEM_CD_CONJURO: float = 9.0
const ELEM_CONJURO_MIN: float = 2.6
const ELEM_CONJURO_MAX: float = 8.0
const ELEM_NUM_ENREDADERAS: int = 2            ## Pablo dijo «unas enredaderas»: 2 (rango 1–3)
const ELEM_MOMENTO_CONJURO: float = 0.45       ## fracción del clip `cast` en que brotan
const ELEM_CURA_CONJURO: float = 25.0          ## vida/s mientras conjura (brillo)
const ELEM_CURA_ENREDADERA: float = 6.0        ## vida/s por cada enredadera VIVA
const ELEM_DANO_ENREDADERA_ARDE: float = 90.0  ## lo que le cuesta que le quemen una enredadera (D3)
const ELEM_CURA_AGUA: float = 120.0
const ELEM_ESCALA_AGUA: float = 1.25
const ELEM_IGNITE: float = 6.0                 ## daño por tick (0,5 s) mientras arde
const ELEM_VINCULO: float = 12.0               ## si una enredadera queda más lejos que esto, se deshace
const ELEM_DANO_FOCO: float = 6.0              ## daño al jugador que pisa una llama de la enredadera
const ELEM_RADIO_FOCO: float = 1.0
const ELEM_ORO: int = 150

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
var snd_alerta: String = "goblin_grito"      ## sonido al descubrir al jugador (Gatopedro usa otro)
var snd_muere: String = "goblin_muere"       ## sonido al morir
var tinte: Color = Color(1.12, 0.9, 0.85)
var oro: int = ORO_BOTIN
var altura: float = 0.85                ## alto del modelo, para la barra

var quemando: float = 0.0
var envenenado: float = 0.0             ## HC4: s que le quedan de veneno (lo deja `Hechizo.veneno`); hiere `_dps_veneno` por segundo, en pulsos de TICK_VENENO
var _dps_veneno: float = 0.0
var _tick_veneno: float = 0.0
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
var quieto: bool = false                 ## R4 (17/10): sin IA (ni ve, ni persigue, ni ataca): los laboratorios lo ponen para tener dianas con vida. Sí recibe golpes, empuje y efectos
var arquero: bool = false               ## ataque a distancia (lo decide el modelo: goblin_archer*)

var _direccion: float = 1.0
var _carga: float = 0.0
var _descanso: float = 0.0
var _empuje: Vector3 = Vector3.ZERO
var _tick_fuego: float = 0.0
var _barra_t: float = 0.0
var _vida_mostrada: float = 1.0
var impactos_visuales: int = 0              ## cuántas veces pidió estrella + temblor al Vfx3D (para las pruebas)
var _destello: float = 0.0
var _flash_blanco: bool = false         ## el destello está pintado ahora mismo (emisión blanca en los materiales)
var _emision_previa: Array = []         ## [enabled, color, energía] de cada material antes del destello, para devolverlo igual
var _hitstop: float = 0.0               ## s que le quedan congelado por el último golpe
var _squash: Vector3 = Vector3.ONE      ## factor de aplastamiento aplicado ahora mismo a pj.scale (se compone con otras escalas)
var _tw_squash: Tween = null
var _tw_salto: Tween = null
var _salto_y: float = 0.0               ## u de salto visual sobre el suelo (solo se suma a pj.position)
## 15/10 (gamefeel de la barra): la barra solo se ve tras recibir daño; al golpe, el relleno se pone BLANCO un instante y el trozo perdido
## se queda en blanco `RETARDO_PERDIDA` s antes de vaciarse, para que se vea cuánto ha quitado el golpe.
const RETARDO_PERDIDA: float = 0.35     ## s que el trozo perdido espera antes de encogerse
const DESTELLO_BARRA: float = 0.14      ## s que el relleno de la barra se queda blanco tras un golpe
var _barra_destello: float = 0.0
var _perdida_espera: float = 0.0
var _t_anim: float = 0.0
var _ataque: float = 0.0       ## s que le quedan a la animación de ataque en curso (bloquea movimiento y giro)
var _ataque_vel: float = 1.0
var elemental: bool = false             ## el elemental de bosque (comportamiento propio)
var _potenciado: bool = false           ## el agua lo ha agrandado ahora mismo
var _ya_crecio: bool = false            ## el agua solo lo agranda UNA vez
var _alto_base: float = 1.7
var _cd_conjuro: float = 4.0
var _t_conjuro: float = 0.0             ## lo que queda del brillo / conjuro
var _vides: Array = []                  ## Enredadera3D vinculadas
var _col: CollisionShape3D = null
var _jefe_capa: CanvasLayer = null
var _jefe_relleno: ColorRect = null
var _jefe_perdida: ColorRect = null
var _golpe_pendiente: bool = false   ## hay un ataque cuerpo a cuerpo cuyo golpe aún no ha salido (se puede cancelar)
var _en_rango: bool = false          ## histéresis: ya está en rango de golpe
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


## Crea un elemental de bosque en `pos` (un modelo nuevo + su combate). Lo usa la tecla F8 del Jugador3D y servirá a cualquier
## marcador del nivel que lo pida. Devuelve null si falta el modelo.
static func invocar_elemental(p_mundo: Node3D, p_jugador: Jugador3D, p_lanz: Lanzador3D, pos: Vector3) -> Combate3D:
	var modelo: Pj3D = p_mundo.call("_personaje", [ID_ELEMENTAL], pos)
	if modelo == null:
		return null
	var lista: Variant = p_mundo.get("_goblins")
	if lista is Array:
		(lista as Array).append(modelo)
	return equipar(modelo, p_mundo, p_jugador, p_lanz)


func _ready() -> void:
	add_to_group("combate3d")
	add_to_group("goblins")
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	elemental = pj != null and pj.id == ID_ELEMENTAL
	var forma := CapsuleShape3D.new()
	forma.radius = 0.7 * altura / ELEM_ALTO_REF if elemental else 0.32
	forma.height = maxf(altura, 0.7)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position = Vector3(0, forma.height * 0.5, 0)
	add_child(cs)
	_col = cs
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
	if elemental:
		_preparar_elemental()
	_aplicar_tinte(tinte)


func _ultima_celda_ok() -> void:
	ultima_pos = position


## =====================================================================================================
##  Contrato on_spell_hit, push y niveles
## =====================================================================================================

func nivel_altura() -> int:
	return 1


## El contrato con los reactivos sigue recibiendo un RuneData (HC3: no se toca); el enemigo lo convierte en el `Hechizo` del elemento (sin glifos), que es lo que lee `golpe`.
## `hechizo` (HC4): si el que golpea ya tiene su Hechizo (HechizoVivo), se usa ese y no se reconstruye desde el RuneData.
func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if rune_data == null:
		return
	golpe(hechizo if hechizo != null else Hechizo.construir(rune_data, {}), direccion)
	if objetivo == null and jugador != null and not muerto and _ve(RADIO_SOLTAR):
		objetivo = jugador          # un golpe te hace mirar a quien viene


## `suelo` = es un golpe con daño: no recorre menos de EMPUJE_MIN_CASILLAS casillas (v0 mínima = casillas × tamaño × DECAIMIENTO, porque el
## empuje decae con lerp(…, 7·dt) y recorre v0 / 7). El elemental recibe MULT_EMPUJE_ELEMENTAL también en el suelo (si no, pegaría igual que un goblin).
func push(direccion: Vector3, fuerza: float, suelo: bool = false) -> void:
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() < 0.01 or muerto:
		return
	var peso: float = MULT_EMPUJE_ELEMENTAL if elemental else 1.0
	var v0: float = fuerza * MULT_EMPUJE * ESCALA_EMPUJE * peso
	if suelo:
		v0 = maxf(v0, EMPUJE_MIN_CASILLAS * Terreno3D.casilla * DECAIMIENTO_EMPUJE * peso)
	_empuje += d.normalized() * v0


## =====================================================================================================
##  Daño y efectos (la tabla de debilidades, heredada del 2D pero propia de este archivo)
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


## HC3 (18/10): el golpe lee del `Hechizo` (daño, fuerza, quema, moja, congela, aturde, ralentiza, interrumpe), ya no de tablas escritas aquí. Lo que SE QUEDA aquí son las reglas
## de interacción que dependen del estado del ENEMIGO (vapor si está mojado y recibe fuego, el rayo ×1,5 y el arco si está mojado, el hielo más largo si está mojado,
## el elemental curado por el agua y que arde más): son del que recibe, no del hechizo.
func golpe(hechizo: Hechizo, direccion: Vector3) -> void:
	if muerto or hechizo == null:
		return
	var el: String = hechizo.elemento
	if elemental and el == "agua":
		_agua_elemental()                # lo cura y lo agranda UNA vez; ni mojado ni barrera de agua que lo proteja
		return
	var base: float = hechizo.dano
	var mult: float = multiplicador(el)

	match el:
		"fuego":
			if mojado > 0.0:
				mojado = 0.0
				texto("¡Vapor!", Color(0.85, 0.9, 1.0))
			else:
				quemando = maxf(hechizo.quema, ELEMENTAL_QUEMA) if elemental else hechizo.quema       # el elemental queda ardiendo un poco más: «ignite»
		"agua":
			mojado = hechizo.moja
			quemando = 0.0
		"rayo":
			if mojado > 0.0:
				base *= 1.5
				_arco_cercano(base * 0.5)
		"hielo":
			congelado = hechizo.congela_mojado if mojado > 0.0 else hechizo.congela
			if mojado > 0.0:
				base += 15.0
			quemando = 0.0
		"viento":
			if not elemental:                 # pesa demasiado: el viento no le corta el ataque
				interrupcion = hechizo.interrumpe
				_carga = 0.0
		"tierra":
			lento = hechizo.ralentiza

	var dano: float = base * mult
	if elemental and el == "fuego" and _potenciado:
		_encoger()                             # el fuego le quita lo que le dio el agua
	if mult > 1.0:
		texto("¡Débil!", COLORES.get(debil, Color.WHITE), 0.28)
	elif mult < 1.0 and base > 0.0:
		texto("Resiste", Color(0.7, 0.7, 0.7), 0.28)

	if hechizo.veneno > 0.0 and not elemental:           # el veneno no hace nada a un elemental (no tiene carne); se queda el más largo / fuerte
		if envenenado <= 0.0:
			texto("Veneno", Color(0.55, 0.9, 0.35), 0.28)
		envenenado = maxf(envenenado, hechizo.veneno)
		_dps_veneno = maxf(_dps_veneno, hechizo.veneno_dps)
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() > 0.01 and hechizo.fuerza_golpe > 0.0:      # el empuje del viento (y la atracción) lo da Lanzador3D por push(): su fuerza_golpe es 0
		push(d, hechizo.fuerza_golpe, dano > 0.0)
	if hechizo.aturde > 0.0 and not elemental:
		_aturdir(hechizo.aturde)
	if dano > 0.0:
		receive_damage(dano)
		if not muerto:
			interrupcion = maxf(interrupcion, INTERRUPCION_GOLPE)
			_iniciar_hitstop(HITSTOP_DEBIL if mult > 1.0 else HITSTOP)
	_destello = maxf(_destello, DESTELLO_GOLPE)
	if not muerto:
		_reaccion_visual(el)
	_impacto_visual(el, mult > 1.0)
	PlayLog.event("golpe_goblin", {"elemento": el, "dano": snappedf(dano, 0.1), "vida": snappedf(health, 0.1),
		"mult": mult})


func _aturdir(segundos: float) -> void:
	stun_timer = segundos
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
	_destello = maxf(_destello, DESTELLO_DANO)
	_barra_destello = DESTELLO_BARRA
	_perdida_espera = RETARDO_PERDIDA
	texto(str(int(round(cantidad))), Color(1, 0.95, 0.85))
	if health > 0.0 and not elemental:      # el elemental no tiene clip `hit`. 17/10: también aturdido (antes se saltaba y el rayo no se notaba)
		anim_orden = "hit"
		interrupcion = maxf(interrupcion, INTERRUPCION_DANO)
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
	if _hitstop > 0.0:
		# Pausa de impacto de ESTE enemigo: no avanzan ni su IA, ni su animación (velocidad 0 desde _iniciar_hitstop), ni su empuje (va
		# dentro de _ia). Sí corren el destello y el dibujo, que son justo lo que hace que el golpe se vea.
		_hitstop -= delta
		_destello = maxf(0.0, _destello - delta)
		pj.position = position + Vector3(0.0, _salto_y, 0.0)
		_dibujar_estado(delta)
		if _hitstop <= 0.0:
			_fin_hitstop()
		return
	_efectos(delta)
	_ia(delta)
	_ajustar_al_suelo(delta)
	_animar()
	pj.position = position + Vector3(0.0, _salto_y, 0.0)
	_dibujar_estado(delta)


## Congela a este enemigo `t` s (si ya estaba congelado más rato, no se acorta). La animación se para con velocidad 0.
func _iniciar_hitstop(t: float) -> void:
	if t <= 0.0 or t <= _hitstop:
		return
	_hitstop = t
	if pj != null and is_instance_valid(pj):
		pj.set_velocidad_animacion(0.0)


## Devuelve la velocidad de animación que tocaba (congelado = 0; atacando = la del ataque; si no, 1). Si hay un `hit` pendiente, _animar lo pondrá a 1.
func _fin_hitstop() -> void:
	_hitstop = 0.0
	if pj == null or not is_instance_valid(pj):
		return
	var v: float = 1.0
	if congelado > 0.0:
		v = 0.0
	elif _ataque > 0.0:
		v = _ataque_vel
	pj.set_velocidad_animacion(v)


## Aplastamiento (no al elemental: su tamaño lo lleva el tween del agua con `set_alto`, que pisaría el factor) y salto visual del viento y la tierra.
func _reaccion_visual(el: String) -> void:
	if not elemental and pj != null and is_instance_valid(pj):
		_cancelar_squash()
		_poner_squash(SQUASH_ESCALA)
		_tw_squash = create_tween()
		_tw_squash.tween_method(_poner_squash, SQUASH_ESCALA, Vector3.ONE, SQUASH_TIEMPO) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if SALTO_ELEMENTOS.has(el):
		if _tw_salto != null and _tw_salto.is_valid():
			_tw_salto.kill()
		_tw_salto = create_tween()
		_tw_salto.tween_method(func(t: float) -> void: _salto_y = SALTO_ALTO * sin(PI * t), 0.0, 1.0, SALTO_TIEMPO)
		_tw_salto.tween_callback(func() -> void: _salto_y = 0.0)


## Estrella de impacto del elemento sobre el enemigo y un temblor de cámara: más fuerte si es su punto débil (T-CP2 / MEJORAS_POTENCIA §2). Sin `_fx` en el mundo
## (escenarios sin ventana) no hace nada.
func _impacto_visual(el: String, debil: bool) -> void:
	var fx: Variant = mundo.get("_fx") if mundo != null else null
	if not (fx is Vfx3D) or not is_inside_tree() or not Vfx3D.ELEMENTOS.has(el):
		return
	(fx as Vfx3D).golpe_estrella(global_position + Vector3(0.0, 0.6, 0.0), el, 1.5 if debil else 1.0)
	(fx as Vfx3D).temblor(TEMBLOR_DEBIL if debil else TEMBLOR_GOLPE)
	impactos_visuales += 1


## Aplica un factor de aplastamiento RELATIVO al anterior (escala × nuevo / viejo), así se compone con cualquier otra escala de pj.
func _poner_squash(f: Vector3) -> void:
	if pj == null or not is_instance_valid(pj):
		return
	var s: Vector3 = pj.scale
	pj.scale = Vector3(s.x / _squash.x * f.x, s.y / _squash.y * f.y, s.z / _squash.z * f.z)
	_squash = f


func _cancelar_squash() -> void:
	if _tw_squash != null and _tw_squash.is_valid():
		_tw_squash.kill()
	_poner_squash(Vector3.ONE)


func _efectos(delta: float) -> void:
	_barra_t = maxf(0.0, _barra_t - delta)
	_destello = maxf(0.0, _destello - delta)
	if quemando > 0.0:
		quemando -= delta
		_tick_fuego -= delta
		if _tick_fuego <= 0.0:
			_tick_fuego = 0.5
			receive_damage(ELEM_IGNITE if elemental else 3.0 * (MULT_DEBIL if debil == "fuego" else 1.0))
			if muerto:
				return
	if envenenado > 0.0:
		envenenado = maxf(0.0, envenenado - delta)
		_tick_veneno -= delta
		if _tick_veneno <= 0.0:
			_tick_veneno = TICK_VENENO
			receive_damage(_dps_veneno * TICK_VENENO)
			if muerto:
				return
		if envenenado <= 0.0:
			_dps_veneno = 0.0
	mojado = maxf(0.0, mojado - delta)
	congelado = maxf(0.0, congelado - delta)
	lento = maxf(0.0, lento - delta)
	_t_anim = maxf(0.0, _t_anim - delta)
	_ataque = maxf(0.0, _ataque - delta)
	_descanso = maxf(0.0, _descanso - delta)
	if elemental:
		_efectos_elemental(delta)


func _ia(delta: float) -> void:
	# Retroceso por golpes (decae solo)
	if _empuje.length() > 0.1:
		_mover_paso(_empuje * delta)
		_empuje = _empuje.lerp(Vector3.ZERO, clampf(DECAIMIENTO_EMPUJE * delta, 0.0, 1.0))
	if elemental:
		stun_timer = 0.0
		interrupcion = 0.0
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

	if quieto:
		# R4: el laboratorio de recetas quiere goblins que no se muevan. Va DESPUÉS del empuje y de los estados (aturdido, congelado), así que un
		# golpe todavía los empuja y los congela; solo se quita lo que los haría ir a por el jugador.
		objetivo = null
		moviendo = 0
		_cancelar_ataque()
		return

	# Animación de ataque a medias: se queda quieto y mirando donde estaba hasta que acabe.
	if _ataque > 0.0:
		moviendo = 0
		# Si el jugador se aleja antes de que salga el golpe, no se queda clavado en la pose: lo cancela y persigue.
		if _golpe_pendiente and not arquero and jugador != null and is_instance_valid(jugador) \
				and _dist(jugador.position) > _rango_ataque() * MARGEN_CANCELAR:
			_cancelar_ataque()
			_en_rango = false
		else:
			return
	var vel: float = vel_mult() * (ELEM_VEL if elemental else 1.0)
	var ve: bool = _ve(RADIO_DETECCION if objetivo == null else RADIO_SOLTAR)
	if ve:
		if objetivo == null:
			flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0), "!", Color(1, 0.85, 0.2))
			if not elemental:
				Sfx3D.play(self, snd_alerta)        # el «!» sobre la cabeza, también al oído
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
			if elemental and estado == "persigue" and _quiere_conjurar(d.length()):
				moviendo = 0
				_conjurar()
				return
			var rango: float = _rango_ataque()
			# Histéresis: se entra en rango a `rango` y se sale a rango*1,2, para no alternar clips en el borde.
			if estado != "persigue":
				_en_rango = false
			elif d.length() <= rango:
				_en_rango = true
			elif d.length() > rango * HISTERESIS_RANGO:
				_en_rango = false
			if estado == "persigue" and _en_rango:
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


func _rango_ataque() -> float:
	return ELEM_RANGO * _k_ref() if elemental else RANGO_ATAQUE


func _atacar(delta: float) -> void:
	if _descanso > 0.0:
		_carga = 0.0
		return
	_carga += delta
	if _carga >= PREPARAR_GOLPE:
		_carga = 0.0
		if elemental:
			_descanso = ELEM_DESCANSO
			_iniciar_ataque(1.0, ELEM_MOMENTO_GOLPE, _golpe_elemental)
			return
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
	_golpe_pendiente = true
	get_tree().create_timer(total * momento, false).timeout.connect(_efecto_ataque.bind(_ataque_id, efecto))
	PlayLog.event("goblin_ataca", {"duracion": snappedf(total, 0.01), "efecto_en": snappedf(total * momento, 0.01)})


func _efecto_ataque(id: int, efecto: Callable) -> void:
	if id == _ataque_id:
		_golpe_pendiente = false
		efecto.call()


## Golpe, parálisis, hielo o muerte: la animación se corta y el golpe/flecha pendiente ya no sale.
func _cancelar_ataque() -> void:
	if _ataque > 0.0:
		_ataque = 0.0
		_t_anim = 0.0
		_ataque_id += 1
		_golpe_pendiente = false


## La flecha sale hacia donde ESTÁ el jugador ahora y tarda en llegar: si se ha movido, falla.
func _soltar_flecha() -> void:
	if muerto or jugador == null or not is_instance_valid(jugador) or jugador.muerto or stun_timer > 0.0 \
			or interrupcion > 0.0 or congelado > 0.0:
		return
	var origen: Vector3 = position + Vector3(0.0, altura * 0.65, 0.0)
	var destino: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0)
	var bloqueada: bool = not Terreno3D.linea_libre(position, jugador.position)
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
	if lanz != null and not bloqueada:
		tw.tween_method(_vuelo_flecha.bind(flecha, origen, destino), 0.0, 1.0, t)     # por tramos: así nota la burbuja del jugador
	else:
		tw.tween_property(flecha, "position", destino, t)
	tw.tween_callback(_flecha_llega.bind(flecha, destino, bloqueada))
	PlayLog.event("flecha_goblin", {"bloqueada": bloqueada})


## Un paso del vuelo de la flecha. Si entra en la burbuja del jugador (16/10, barrera-burbuja) la revienta ahí mismo, en el punto donde la
## toca, y la flecha desaparece sin hacer daño. Va por tramos y no con un solo `tween_property` porque la burbuja SE MUEVE con el jugador.
func _vuelo_flecha(k: float, flecha: Node3D, origen: Vector3, destino: Vector3) -> void:
	if not is_instance_valid(flecha) or flecha.has_meta("parada"):
		return
	var p: Vector3 = origen.lerp(destino, k)
	flecha.position = p
	if lanz != null and lanz.burbuja_contiene(p):
		flecha.set_meta("parada", true)            # `_flecha_llega` (si el tween llega a llamarla en este mismo paso) no hace daño
		lanz.burbuja_recibe("", p, self)
		flecha.queue_free()
	elif lanz != null and lanz.solidez_para(p, DANO_FLECHA):
		flecha.set_meta("parada", true)            # R3: un volumen con solidez (propiedad de la receta V2) para la flecha y aguanta el golpe
		flecha.queue_free()


func _flecha_llega(flecha: Node3D, destino: Vector3, bloqueada: bool) -> void:
	if is_instance_valid(flecha):
		var parada: bool = flecha.has_meta("parada")
		flecha.queue_free()
		if parada:
			return
	if bloqueada or jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return
	var dx: float = jugador.position.x - destino.x
	var dz: float = jugador.position.z - destino.z
	if Vector2(dx, dz).length() <= RADIO_IMPACTO_FLECHA and absf(jugador.position.y + 0.8 - destino.y) < Terreno3D.ALTO_NIVEL:
		jugador.recibir_dano(DANO_FLECHA, position)


func _conectar() -> void:
	if muerto or jugador == null or not is_instance_valid(jugador) or stun_timer > 0.0 or interrupcion > 0.0 \
			or congelado > 0.0:
		return
	if _dist(jugador.position) <= RANGO_ATAQUE + 0.5 and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9:
		jugador.recibir_dano(DANO_GOLPE, position)


func _dist(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()


## ¿Ve al jugador? Distancia + línea de visión (árboles, muros y torres de tierra la cortan).
func _ve(radio: float) -> bool:
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return false
	if _dist(jugador.position) > radio:
		return false
	return Terreno3D.linea_libre(position, jugador.position)


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
	if elemental and not _cabe_con_cuerpo(p):
		return false
	var c: Vector2i = Terreno3D.celda_de(p)
	if c == Terreno3D.celda_de(position):
		return Terreno3D.en_mapa(c)
	# Se mueve por SU nivel (el de la casilla donde está): a nivel 0 es lo de siempre; en una terraza (Terra Fina) recorre la
	# terraza y puede bajar, pero no sube: pisable con `sube = false` y tope = su nivel.
	var nivel: int = Terreno3D.altura_en(Terreno3D.celda_de(position))
	if not Terreno3D.pisable(c, nivel, false, nivel, false):
		return false
	# Un escalón (del puente al suelo) se sube; un bloque no.
	return absf(Terreno3D.y_pies(c) - position.y) <= 0.6


## 9.13: el elemental mide 2,5 u de alto y su cuerpo (cápsula) tiene un radio de ~1 u, casi media casilla (la casilla mide 2,3).
## `_puede_estar` solo miraba la casilla del CENTRO, así que el centro podía llegar al borde de una pared y el cuerpo se le metía
## un radio entero en los árboles del borde (medido: el modelo con los brazos abiertos mide ±1,2 u). Aquí se comprueban cuatro
## puntos a un radio del centro (±X, ±Z): si alguno entra en una casilla NUEVA que no se pisa, no se avanza. Si ya estaba
## metido (un nivel que lo coloca pegado a una pared), se le deja salir: solo se rechaza ENTRAR en una casilla bloqueada.
## Solo el elemental: los goblins miden 0,32 de radio y no tenían el problema. Efecto de diseño: con 2,06 u de cuerpo, un hueco
## de una casilla (2,3) como la puerta de la sala solo lo cruza si va centrado; en la práctica se queda en su sala.
func _cabe_con_cuerpo(p: Vector3) -> bool:
	var r: float = 0.7 * altura / ELEM_ALTO_REF
	for o in [Vector3(r, 0.0, 0.0), Vector3(-r, 0.0, 0.0), Vector3(0.0, 0.0, r), Vector3(0.0, 0.0, -r)]:
		var nueva: Vector2i = Terreno3D.celda_de(p + o)
		if nueva == Terreno3D.celda_de(position + o):
			continue                                   # no cambia de casilla por ese lado: nada que comprobar
		if not Terreno3D.pisable(nueva, 0, false, 0, false):
			return false
	return true


func _ajustar_al_suelo(delta: float) -> void:
	var c: Vector2i = Terreno3D.celda_de(position)
	if Terreno3D.es_agua(c):
		# Se le fue el suelo (hielo derretido): vuelve a su puesto, sin daño
		position = Vector3(casa.x, Terreno3D.y_pies(Terreno3D.celda_de(casa)), casa.z)
		estado = "patrulla"
		objetivo = null
		return
	if Terreno3D.altura_en(c) > 0:
		# Le han levantado un bloque debajo: sube con él
		position.y = Terreno3D.y_pies(c)
		return
	position.y = move_toward(position.y, Terreno3D.y_pies(c), 6.0 * delta)


func _animar() -> void:
	if anim_orden != "":
		var orden: String = anim_orden
		anim_orden = ""
		pj.animacion_actual = ""
		if orden == "cast":
			pj.set_velocidad_animacion(1.0)
			pj.jugar(orden, true)
		elif orden == "attack":
			pj.set_velocidad_animacion(_ataque_vel)
			pj.jugar(orden, true)
		else:
			pj.set_velocidad_animacion(1.0)
			pj.jugar(orden)
		if orden == "hit":
			_t_anim = maxf(_t_anim, 0.35)
	if _t_anim > 0.0:
		return
	if congelado > 0.0:
		pj.set_velocidad_animacion(0.0)          # congelado: se queda en la pose a propósito
		return
	if stun_timer > 0.0:
		# Aturdido: sin esto se quedaba en el último fotograma de attack/cast; pasa a reposo.
		pj.set_velocidad_animacion(1.0)
		pj.jugar("idle")
		return
	pj.set_velocidad_animacion(1.0)
	if elemental and moviendo == 1:
		# Pies resbalando: el clip `walk` (5,5 s) a velocidad 1 va más lento que el suelo. Se acelera lo justo.
		var dur: float = pj.duracion("walk")
		if dur > 0.0:
			var vel_real: float = VEL_PERSEGUIR * ELEM_VEL * vel_mult()
			pj.set_velocidad_animacion(clampf(vel_real * dur / ELEM_ZANCADA_WALK, 0.5, 2.5))
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

## Destello BLANCO PURO: albedo negro + emisión blanca, así la textura del modelo no se ve (el tinte ×2,2 de antes la dejaba asomar). Al apagarlo
## se devuelve la emisión que cada material tenía. Se llama cada fotograma desde _dibujar_estado; solo toca los materiales al cambiar de estado.
func _destello_blanco(activo: bool) -> void:
	if activo == _flash_blanco:
		if activo:
			for m in _materiales:
				if is_instance_valid(m):
					(m as StandardMaterial3D).albedo_color = Color.BLACK    # _aplicar_tinte lo acaba de repintar con el tinte
		return
	_flash_blanco = activo
	if activo:
		_emision_previa.clear()
		for m in _materiales:
			var mat: StandardMaterial3D = m as StandardMaterial3D
			if not is_instance_valid(mat):
				_emision_previa.append(null)
				continue
			_emision_previa.append([mat.emission_enabled, mat.emission, mat.emission_energy_multiplier])
			mat.emission_enabled = true
			mat.emission = Color.WHITE
			mat.emission_energy_multiplier = 1.0
			mat.albedo_color = Color.BLACK
	else:
		for i in range(_materiales.size()):
			var mat2: StandardMaterial3D = _materiales[i] as StandardMaterial3D
			if not is_instance_valid(mat2) or i >= _emision_previa.size() or _emision_previa[i] == null:
				continue
			var e: Array = _emision_previa[i]
			mat2.emission_enabled = bool(e[0])
			mat2.emission = e[1]
			mat2.emission_energy_multiplier = float(e[2])
		_emision_previa.clear()


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
	if _t_conjuro > 0.0:                      # brillo sutil que lo cura
		c = c.lerp(Color(0.8, 1.55, 0.85), 0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.012))
	_aplicar_tinte(c)
	_destello_blanco(_destello > 0.0)

	var fr: float = clampf(health / vida_max, 0.0, 1.0)
	_barra_destello = maxf(0.0, _barra_destello - delta)
	_perdida_espera = maxf(0.0, _perdida_espera - delta)
	if fr >= _vida_mostrada:
		_vida_mostrada = fr                                   # curarse: sin trozo blanco
	elif _perdida_espera <= 0.0:
		_vida_mostrada = lerpf(_vida_mostrada, fr, clampf(8.0 * delta, 0.0, 1.0))
	_poner_barra(_barra_vida, fr)
	_poner_barra(_barra_perdida, _vida_mostrada)
	(_barra_vida.material_override as StandardMaterial3D).albedo_color = Color.WHITE if _barra_destello > 0.0 else \
		(Color(0.35, 0.9, 0.4) if fr > 0.5 else (Color(1.0, 0.8, 0.25) if fr > 0.25 else Color(1.0, 0.3, 0.25)))
	# Con la vida llena la barra no se ve (solo el rombo de su debilidad); aparece con el primer daño. El elemental ya las tiene ocultas.
	if not elemental and not muerto:
		var ver: bool = fr < 0.999 or _barra_destello > 0.0
		for n in [_barra_fondo, _barra_perdida, _barra_vida]:
			(n as Node3D).visible = ver
	_nombre_etiqueta.visible = _barra_t > 0.0 and not elemental
	if elemental:
		_actualizar_barra_jefe(fr)


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
##  ELEMENTAL DE BOSQUE (8/10): usa el mismo cuerpo que un goblin (barra, efectos, empuje) con reglas propias.
##  Por qué aquí y no en un archivo nuevo: comparte con Combate3D todo el combate (daño, ataque bloqueante, muerte, botín); un
##  archivo aparte habría duplicado esa lógica o obligado a abrir Combate3D a herencia.
## =====================================================================================================

func _preparar_elemental() -> void:
	vida_max = ELEM_VIDA
	health = ELEM_VIDA
	nombre = "Elemental del bosque"
	debil = "fuego"
	resiste = ""
	oro = ELEM_ORO
	_alto_base = altura
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = false       # su barra es la grande de la pantalla
	_construir_barra_jefe()


## Cuánto ha crecido respecto a su tamaño normal (1 = normal).
func _factor_tamano() -> float:
	return altura / maxf(_alto_base, 0.01)


## Escala de las medidas del elemental respecto a su altura de referencia (1,7 u).
## Incluye el crecimiento del agua, porque el puño y el alcance crecen con el cuerpo.
func _k_ref() -> float:
	return altura / ELEM_ALTO_REF


## --- AGUA: lo cura y lo agranda una sola vez ---
func _agua_elemental() -> void:
	health = minf(vida_max, health + ELEM_CURA_AGUA)
	_barra_t = TIEMPO_BARRA
	texto("+%d" % int(ELEM_CURA_AGUA), Color(0.5, 1.0, 0.6))
	PlayLog.event("elemental_agua", {"vida": snappedf(health, 0.1), "crece": not _ya_crecio})
	if _ya_crecio:
		return
	_ya_crecio = true
	_potenciado = true
	_cambiar_tamano(_alto_base * ELEM_ESCALA_AGUA)


## --- FUEGO sobre el potenciado: le quita el tamaño ---
func _encoger() -> void:
	_potenciado = false
	texto("¡Encoge!", COLORES["fuego"], 0.3)
	_cambiar_tamano(_alto_base)


func _cambiar_tamano(alto_final: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_method(_poner_alto, altura, alto_final, 0.8)


func _poner_alto(a: float) -> void:
	if not is_instance_valid(pj):
		return
	pj.set_alto(a)
	altura = a
	if _col != null:
		_col.scale = Vector3.ONE * (a / _alto_base)


func _efectos_elemental(delta: float) -> void:
	_cd_conjuro = maxf(0.0, _cd_conjuro - delta)
	_t_conjuro = maxf(0.0, _t_conjuro - delta)
	var cura: float = 0.0
	if _t_conjuro > 0.0:
		cura += ELEM_CURA_CONJURO
	var vivas: Array = []
	for v in _vides:
		if is_instance_valid(v):
			vivas.append(v)
			var e: Enredadera3D = v
			if e.fase == Enredadera3D.Fase.VIVA:
				cura += ELEM_CURA_ENREDADERA
				if (e.global_position - position).length() > ELEM_VINCULO:
					e.deshacer()                 # se ha alejado demasiado de quien la conjuró
	_vides = vivas
	if cura > 0.0 and health < vida_max:
		health = minf(vida_max, health + cura * delta)


## --- GOLPE: puñetazo al suelo con un ÁREA delante de él (no un punto) ---
func _golpe_elemental() -> void:
	if muerto or jugador == null or not is_instance_valid(jugador):
		return
	var f: Vector3 = Vector3(mirada.x, 0.0, mirada.z)
	f = f.normalized() if f.length() > 0.01 else Vector3(0, 0, 1)
	var k: float = _k_ref()
	var centro: Vector3 = position + f * (ELEM_ALCANCE_GOLPE * 0.5 * k)
	var fx: Node = mundo.get("_fx")
	if fx != null and Vfx3D.ELEMENTOS.has("tierra"):
		fx.call("lanzar_forma", "onda", "tierra", centro, centro, {"radio": ELEM_ANCHO_GOLPE * k, "dura": 0.6})
	if jugador.muerto:
		return
	var rel: Vector3 = jugador.position - position
	rel.y = 0.0
	var delante: float = rel.dot(f)
	var lado: float = absf(rel.dot(Vector3(-f.z, 0.0, f.x)))
	var dentro: bool = delante >= -0.3 and delante <= ELEM_ALCANCE_GOLPE * k and lado <= ELEM_ANCHO_GOLPE * k
	if dentro and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9:
		jugador.recibir_dano(ELEM_DANO_GOLPE, position)
	PlayLog.event("elemental_golpe", {"acierta": dentro})


## --- CONJURO: enredaderas delante, vinculadas a él ---
func _quiere_conjurar(dist: float) -> bool:
	if _cd_conjuro > 0.0 or _ataque > 0.0 or _descanso > 0.0:
		return false
	if dist < ELEM_CONJURO_MIN or dist > ELEM_CONJURO_MAX:
		return false
	for v in _vides:
		if is_instance_valid(v) and (v as Enredadera3D).fase != Enredadera3D.Fase.QUEMADA \
				and (v as Enredadera3D).fase != Enredadera3D.Fase.DESHACIENDO:
			return false                        # ya tiene sus enredaderas
	return true


func _conjurar() -> void:
	var dur: float = pj.duracion("cast")
	if dur <= 0.0:
		dur = 2.7
	_cd_conjuro = ELEM_CD_CONJURO
	_ataque = dur
	_t_anim = dur
	_t_conjuro = dur
	anim_orden = "cast"
	_ataque_id += 1
	get_tree().create_timer(dur * ELEM_MOMENTO_CONJURO, false).timeout.connect(_efecto_ataque.bind(_ataque_id, _brotar_enredaderas))
	PlayLog.event("elemental_conjura", {"duracion": snappedf(dur, 0.01)})


func _brotar_enredaderas() -> void:
	if muerto:
		return
	var f: Vector3 = Vector3(mirada.x, 0.0, mirada.z)
	f = f.normalized() if f.length() > 0.01 else Vector3(0, 0, 1)
	var der: Vector3 = Vector3(-f.z, 0.0, f.x)
	var fx: Variant = mundo.get("_fx")
	var n: int = clampi(ELEM_NUM_ENREDADERAS, 1, 3)
	for i in range(n):
		var lateral: float = (float(i) - float(n - 1) * 0.5) * 1.6
		var p: Vector3 = position + f * (ELEM_ALTO_REF + 0.35 * float(i % 2)) * _k_ref() + der * lateral
		var c: Vector2i = Terreno3D.celda_de(p)
		if not Terreno3D.en_mapa(c) or Terreno3D.es_agua(c) or Terreno3D.bloqueada(c) or Terreno3D.altura_en(c) > 0:
			continue
		var e := Enredadera3D.new()
		mundo.add_child(e)
		e.position = Vector3(p.x, Terreno3D.y_pies(c), p.z)
		e.rotation.y = atan2(-f.x, -f.z)         # su largo (eje X local) queda de lado, cortando el paso
		e.preparar(fx as Vfx3D, 1.6)
		var enlace := EnlaceEnredadera.new()
		enlace.vid = e
		enlace.dueno = self
		enlace.celda = c
		e.add_child(enlace)
		e.brotada.connect(enlace.al_brotar)
		e.ardiendo.connect(_enredadera_arde)
		e.foco.connect(_foco_enredadera.bind(e))
		e.quemada.connect(enlace.liberar)
		e.deshecha.connect(enlace.liberar)
		e.brotar()
		_vides.append(e)
	PlayLog.event("elemental_enredaderas", {"n": _vides.size()})


## Quemar su enredadera le duele a él (D3).
func _enredadera_arde() -> void:
	if muerto:
		return
	texto("¡Su enredadera arde!", COLORES["fuego"], 0.3)
	receive_damage(ELEM_DANO_ENREDADERA_ARDE)


## Cada llama nueva de una enredadera ardiendo prende lo que haya a ~1 u: suelo y objetos (como un impacto de fuego), otras
## enredaderas y el jugador si está encima.
func _foco_enredadera(punto: Vector3, origen: Enredadera3D) -> void:
	if lanz != null:
		lanz.impacto_filtrado("fuego", punto)
	for v in _vides:
		if is_instance_valid(v) and v != origen and (v as Enredadera3D).global_position.distance_to(punto) <= ELEM_RADIO_FOCO + 0.9:
			(v as Enredadera3D).quemar()
	if jugador != null and is_instance_valid(jugador) and not jugador.muerto:
		var d: float = Vector2(jugador.position.x - punto.x, jugador.position.z - punto.z).length()
		if d <= ELEM_RADIO_FOCO and absf(jugador.position.y - punto.y) < Terreno3D.ALTO_NIVEL:
			jugador.recibir_dano(ELEM_DANO_FOCO, punto)


func _morir_elemental() -> void:
	for v in _vides:
		if is_instance_valid(v):
			(v as Enredadera3D).deshacer()
	_vides.clear()
	if _jefe_capa != null:
		_jefe_capa.visible = false


## Zona de golpe de una enredadera: recibe el fuego (on_spell_hit) y bloquea su casilla mientras vive.
class EnlaceEnredadera extends Area3D:
	var vid: Enredadera3D = null
	var dueno: Combate3D = null
	var celda: Vector2i = Vector2i(-1, -1)
	var _bloqueando: bool = false

	func _ready() -> void:
		collision_layer = Lanzador3D.CAPA_REACTIVO
		collision_mask = 0
		monitoring = false
		monitorable = true
		var cs := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(vid.ancho if vid != null else 1.6, 1.0, 0.7)
		cs.shape = caja
		cs.position = Vector3(0, 0.5, 0)
		add_child(cs)

	func nivel_altura() -> int:
		return 1

	## Solo el fuego la toca; lo demás (flechas de otro elemento...) pasa de largo.
	func spell_reacts(rune: RuneData, _dir: Vector3) -> bool:
		return Objetos.elemento_de(rune) == "fuego"

	func on_spell_hit(rune: RuneData, _dir: Vector3 = Vector3.ZERO) -> void:
		if vid != null and is_instance_valid(vid) and Objetos.elemento_de(rune) == "fuego":
			vid.quemar()

	## Al terminar de brotar bloquea su casilla (si estaba libre y no es la del jugador).
	func al_brotar() -> void:
		if Terreno3D.bloqueada(celda):
			return
		var j: Variant = dueno.jugador if dueno != null else null
		if j != null and is_instance_valid(j) and Terreno3D.celda_de((j as Node3D).position) == celda:
			return
		Terreno3D.bloquear_celda(celda)
		_bloqueando = true

	func liberar() -> void:
		if _bloqueando:
			Terreno3D.liberar_celda(celda)
			_bloqueando = false
		monitorable = false
		collision_layer = 0

	func _exit_tree() -> void:
		if _bloqueando:
			Terreno3D.liberar_celda(celda)
			_bloqueando = false


## --- Barra de vida grande, arriba en el centro de la pantalla ---
func _construir_barra_jefe() -> void:
	_jefe_capa = CanvasLayer.new()
	_jefe_capa.layer = 20
	_jefe_capa.visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.75)
	fondo.anchor_left = 0.5
	fondo.anchor_right = 0.5
	fondo.offset_left = -300.0
	fondo.offset_right = 300.0
	fondo.offset_top = 22.0
	fondo.offset_bottom = 46.0
	_jefe_capa.add_child(fondo)
	_jefe_perdida = ColorRect.new()
	_jefe_perdida.color = Color(1, 1, 1, 0.55)
	_jefe_perdida.position = Vector2(3, 3)
	_jefe_perdida.size = Vector2(594, 18)
	fondo.add_child(_jefe_perdida)
	_jefe_relleno = ColorRect.new()
	_jefe_relleno.color = Color(0.35, 0.8, 0.3)
	_jefe_relleno.position = Vector2(3, 3)
	_jefe_relleno.size = Vector2(594, 18)
	fondo.add_child(_jefe_relleno)
	var rotulo := Label.new()
	rotulo.text = nombre
	rotulo.anchor_left = 0.5
	rotulo.anchor_right = 0.5
	rotulo.offset_left = -300.0
	rotulo.offset_right = 300.0
	rotulo.offset_top = 2.0
	rotulo.offset_bottom = 22.0
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jefe_capa.add_child(rotulo)
	add_child(_jefe_capa)


func _actualizar_barra_jefe(fr: float) -> void:
	if _jefe_capa == null:
		return
	_jefe_capa.visible = not muerto and (objetivo != null or _barra_t > 0.0)
	_jefe_relleno.size.x = 594.0 * fr
	_jefe_perdida.size.x = 594.0 * _vida_mostrada



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
	if elemental:
		_morir_elemental()
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = false
	# Si muere en pleno golpe: sin destello blanco, sin aplastamiento ni salto a medias (el tween de muerte encoge pj.scale desde su valor actual).
	_destello = 0.0
	_hitstop = 0.0
	_salto_y = 0.0
	if _tw_salto != null and _tw_salto.is_valid():
		_tw_salto.kill()
	_cancelar_squash()
	_destello_blanco(false)
	_aplicar_tinte(tinte)
	Jugador3D.una_vez(pj, "death")
	if not elemental:
		Sfx3D.play(self, snd_muere)
	var lista: Variant = mundo.get("_goblins")
	if lista is Array:
		(lista as Array).erase(pj)
	PlayLog.event("goblin_muere", {"nombre": nombre, "celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y]})
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

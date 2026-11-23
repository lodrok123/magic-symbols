class_name Escudo3D
extends Node3D

## EL ESCUDO DEL GOBLIN COMO COMPONENTE (A5 de docs/PLAN_EOW.md, 21/10; §4 de docs/DISENO_FUTURO.md). Dueño: Juego.
##
## Un nodo HIJO de un `Combate3D` con vida propia, su propio `on_spell_hit` y dos PAPELES (la misma idea que `Reactivo3D.papeles`, A1; el escudo NO es un Reactivo3D
## porque no vive en una casilla: va colgado de un enemigo que se mueve):
##   `bloquea_proyectiles`  mientras está entero, un disparo DIRECTO DE FRENTE no llega al goblin: lo recibe el escudo y se avisa `bloqueado`.
##   `inflamable`           el fuego lo prende y arde `T_CONSUMO` s hasta consumirse (`consumido`). Mojado no prende (fuego sobre mojado = vapor), y el agua o el hielo
##                          apagan el que arde (`apagado_agua`), como en el resto del juego. Si el GOBLIN arde (A2: contacto con una llama), el escudo que lleva arde con él.
## Retoques por pieza: `papeles = PackedStringArray(["-inflamable"])` quita un papel y `+nombre` lo añade (como en Reactivo3D). Un escudo de hierro sería `-inflamable`.
##
## POR QUÉ UN COMPONENTE: ni el goblin ni el fuego saben qué es un escudo. Lo ÚNICO que `Combate3D` sabe es que puede tener un `escudo` y, antes de aplicar un
## disparo, preguntarle `escudo.para(direccion, hechizo)`; si responde true, el disparo ya lo ha recibido el escudo y el goblin no se entera. El fuego (A2) tampoco
## mira escudos: el escudo lee `combate.esta_ardiendo()` por su cuenta. Para armaduras, monturas… (DISENO_FUTURO §4) se repite el patrón: nodo hijo + una consulta.
##
## CÓMO SE EQUIPA: `Escudo3D.equipar(combate)`. Ningún goblin de los niveles lo lleva si nadie lo pide.
##
## AVISOS (A4, `Mundo3D.avisar_reaccion(nombre, punto, nodo)` con este nodo; su `tipo` es «escudo» para que el Pipeline use sus excepciones):
##   `bloqueado`   cada disparo de frente que para · `prendido` al empezar a arder · `consumido` al acabarse (quemado o roto) · `apagado_agua` si lo apagan · `mojado`.

## Qué cuenta como «de frente»: ángulo TOTAL del cono frontal del goblin, en grados (mitad a cada lado de hacia dónde mira). 120° = ±60°: el escudo cubre el
## frente y algo de los costados, pero no el flanco puro (90°) ni la espalda. Un disparo que viaja contra la mirada del goblin (dentro del cono) se bloquea.
const ANGULO_CONO_FRONTAL: float = 120.0
const VIDA_ESCUDO: float = 60.0               ## daño que aguanta si alguien lo desgasta a mano (`_desgastar`); desde el 21/11 los hechizos que no son fuego ya NO lo desgastan
const T_CONSUMO: float = 4.0                  ## s que tarda en consumirse una vez prendido. 21/11 (Pablo: «aguanta varios segundos»): 3 → 4; mientras arde el goblin se quema el brazo y no ataca
## 21/11 (Pablo: «la debilidad es el fuego; el resto podrían empujar levemente al goblin sin hacerle daño con una animación de bloqueo acorde»). Lo que NO es fuego y llega de frente
## ni le hace daño ni desgasta el escudo: lo empuja un poco hacia atrás (sin tumbarlo: no pasa por `Combate3D.push`, que lo haría volar) y el goblin hace el clip de BLOQUEO.
const EMPUJE_BLOQUEO: float = 2.2             ## u/s de arranque del retroceso (decae con `Combate3D.DECAIMIENTO_EMPUJE`: recorre ~0,3 u, media casilla corta)
const CLIP_BLOQUEO: String = "parrybackward002"   ## se busca por nombre en el GLB del guerrero (SwordParryBackward002: el 001 es casi una pose fija, el brazo no se mueve); sin él, el «hit»
const ESTADO_BLOQUEO: String = "lanzar_bloqueo"   ## estado del grafo reducido (`lanzar*` admite cualquier clip, como el agarre del mouro)
const VEL_BLOQUEO: float = 1.6                ## el parry original dura ~1,3 s; acelerado se lee como un golpe parado, no como una pausa
## BRAZO ARDIENDO (21/11, Pablo: «una animación del goblin quemándose el brazo; inspírate en cuando a un hilichurl del Genshin se le quema el escudo»): mientras el escudo arde,
## el goblin NO ataca ni persigue: sacude el brazo del escudo con el codo doblado, se inclina apartándose de la llama, con la otra mano se palmea el antebrazo y da saltitos.
## Clip hecho por código sobre su Idle (`preparar_brazo_ardiendo`), en bucle; dura un CICLO y todas las oscilaciones caben un número entero de veces (el bucle no salta).
const ANIM_BRAZO_ARDIENDO: String = "BrazoArdiendo"
const ESTADO_BRAZO_ARDIENDO: String = "lanzar_brazo_ardiendo"
const CICLO_BRAZO_ARDIENDO: float = 1.6
const SACUDIDAS_CICLO: int = 14               ## sacudidas de la mano por ciclo (~8,8 por segundo)
const BALANCEOS_CICLO: int = 2                ## giros del torso a un lado y otro por ciclo
const PALMADAS_CICLO: int = 4                 ## palmadas de la otra mano sobre el antebrazo
const SALTITOS_CICLO: int = 4                 ## saltitos (la cadera sube y baja)
const SALTITO_ALTO: float = 0.05              ## fracción de la altura de la cadera en reposo
## Hueso -> [eje local, grados de la POSTURA, grados de la OSCILACIÓN, oscilaciones por ciclo]. Los del brazo izquierdo son los de `Pj3D.MANO_QUEMADA_HUESOS` (mismos ejes, más fuertes).
const BRAZO_ARDIENDO_HUESOS: Dictionary = {
	"mixamorig_LeftArm": [Vector3(0.0, 0.0, 1.0), 55.0, 10.0, SACUDIDAS_CICLO],
	"mixamorig_LeftForeArm": [Vector3(1.0, 0.0, 0.0), -80.0, 12.0, SACUDIDAS_CICLO],
	"mixamorig_LeftHand": [Vector3(0.0, 0.0, 1.0), 0.0, 55.0, SACUDIDAS_CICLO],
	"mixamorig_Spine1": [Vector3(1.0, 0.0, 0.0), 14.0, 5.0, SALTITOS_CICLO],
	"mixamorig_Spine": [Vector3(0.0, 1.0, 0.0), 0.0, 14.0, BALANCEOS_CICLO],
	"mixamorig_RightArm": [Vector3(0.0, 0.0, 1.0), -35.0, 18.0, PALMADAS_CICLO],
	"mixamorig_RightForeArm": [Vector3(1.0, 0.0, 0.0), -65.0, 22.0, PALMADAS_CICLO],
	"mixamorig_Head": [Vector3(0.0, 1.0, 0.0), 20.0, 8.0, BALANCEOS_CICLO],
}
## CARBONIZADO (21/11, Pablo: «que se vea visualmente el escudo quemado»): mientras arde, una capa marrón-negra que va tapando la madera hasta ALFA_CARBON_MAX al consumirse.
const COLOR_CARBON: Color = Color(0.03, 0.02, 0.02)
const ALFA_CARBON_MAX: float = 0.9
const BRASA_CARBON: float = 0.06              ## brillo de las brasas (emisión naranja de la capa) al final de la quema. Con 0,25 ya se veía rojo oscuro en vez de negro (captura «carbon» del 21/11)
## COMO UN MURO (21/11, Pablo: «cuando bloquee debería ser como si fuera un muro, teniendo en cuenta el modelo»): el escudo lleva su PROPIA caja de choque, del tamaño de su
## malla, en la capa de los reactivos. Los rayos de los hechizos la encuentran ANTES que al goblin (va delante), así que el impacto ocurre en la cara del escudo y no en el cuerpo.
const GROSOR_MIN_CHOQUE: float = 0.12         ## u: el disco es casi plano; con menos grosor un rayo rasante lo atravesaría
const T_MOJADO: float = 6.0                   ## s que un escudo mojado no prende
## MANO QUEMADA (21/10, Pablo tras el playtest): cuando el escudo termina de arder, al goblin le quema la mano: lo suelta, se queda aturdido T_MANO_QUEMADA s
## con el clip ROL_MANO_QUEMADA (si su GLB lo trae; si no, el de golpe) y el escudo se DESINTEGRA en T_DESINTEGRA s en vez de quedarse quemado en el brazo.
## El goblin NO se prende por su propio escudo. El clip es del Pipeline (diario); el disolver por celdas es V6 (`Ocluso3D`, uniform `disolver`): la malla quemada se deshace en T_DESINTEGRA s. Con
## `Ocluso3D.usar_quemado_disolver = false` (o sin material común) vuelve a encoger hasta desaparecer, como antes.
const T_MANO_QUEMADA: float = Pj3D.MANO_QUEMADA_DUR      ## 1,2 s: lo que dura el clip `mano_quemada` (Pj3D.MANO_QUEMADA_DUR), para que acaben a la vez
const T_DESINTEGRA: float = 0.8
const ROL_MANO_QUEMADA: String = "mano_quemada"
const DISTANCIA_MANO: float = 0.42            ## (SIN esqueleto) u por delante del centro del cuerpo
const ALTURA_RELATIVA: float = 0.55           ## (SIN esqueleto) a qué fracción de la altura del goblin va el centro del disco
## EN EL BRAZO (22/10): con un goblin de verdad el escudo ya no flota delante del cuerpo: va colgado del antebrazo izquierdo (el hueso `LeftForeArm`, donde ya iba el
## escudo de adorno de `Equipo3D`, que se oculta mientras el de verdad exista) y sigue cada fotograma la pose del clip. Medidas en unidades de juego, en el espacio del hueso
## (el eje Y va del codo a la muñeca; Z sale hacia fuera del brazo): el disco queda sobre la cara exterior del antebrazo, apoyado y no clavado en él.
const HUESO_ESCUDO: String = "LeftForeArm"
const ESCALA_EN_BRAZO: float = 0.62           ## el disco de la pieza mide 0,55 u (más que el torso del goblin, 0,85 de alto): sobre el brazo se queda en ~0,34 u
const POS_EN_BRAZO: Vector3 = Vector3(0.0, 0.07, 0.07)
const GIRO_EN_BRAZO: Vector3 = Vector3(0.0, 0.0, 0.0)    ## grados (X, Y, Z) en el espacio del hueso (solo si CARA_AL_FRENTE = false)
## 21/11 (Pablo, captura «cerca»: de frente el escudo iba de canto y la mano lo atravesaba): la POSICIÓN sigue al antebrazo, pero la CARA del escudo mira hacia delante
## del goblin (girada GIRO_HACIA_FUERA grados hacia su lado izquierdo, el del brazo) y se separa ADELANTE_EN_BRAZO u del brazo hacia delante, para que puño y dedos queden detrás.
const CARA_AL_FRENTE: bool = true
const GIRO_HACIA_FUERA: float = 20.0
const ADELANTE_EN_BRAZO: float = 0.16         ## con 0,10 aún asomaban los dedos por la cara del escudo en tres cuartos
const BAJADA_EN_BRAZO: float = 0.07           ## u que baja respecto al antebrazo: con 0 tapaba la cara del goblin de frente
const INCLINACION_ATRAS: float = 8.0          ## grados que se echa hacia atrás por arriba (no se ve un disco de canto vertical perfecto)
const PIEZA_EQUIPO_ADORNO: String = "escudo"  ## el id de `Equipo3D.EQUIPO` que se oculta
## ESCUDO MOJADO (22/10): una capa translúcida azul oscura con brillo húmedo (`PiezaFuego3D.capa_mojada`) mientras `mojado_t > 0`, que se aclara en los últimos T_SECADO s.
const ALFA_ESCUDO_MOJADO: float = 0.55
const T_SECADO: float = 1.5
const ID_ENTERO: String = "goblin_escudo_entero"
const ID_QUEMADO: String = "goblin_escudo_quemado"
const PAPEL_INFLAMABLE: String = "inflamable"
const PAPEL_BLOQUEA: String = "bloquea_proyectiles"
const PAPELES_DE_SERIE: Array = [PAPEL_INFLAMABLE, PAPEL_BLOQUEA]

## Se acabó el escudo: `causa` = «quemado» o «roto».
signal consumido(causa: String)
## Un disparo de frente chocó contra el escudo (haya hecho algo o no).
signal bloqueado(punto: Vector3)
## Se consumió ardiendo y le quemó la mano a `goblin` (para el Pipeline: chispas en la mano, el disolver del escudo).
signal mano_quemada(goblin: Combate3D)

var combate: Combate3D = null
var tipo: String = "escudo"                    ## lo lee el Pipeline (`ReaccionesVfx3D.tipo_de`) para elegir las excepciones del escudo
@export var papeles: PackedStringArray = PackedStringArray()
var vida: float = VIDA_ESCUDO
var vida_max: float = VIDA_ESCUDO
var arde_t: float = 0.0                        ## s que le quedan de arder (> 0 = está ardiendo). No se llama `quemando` a propósito: el Pipeline tomaría el nodo por un goblin
var mojado_t: float = 0.0                      ## s que le quedan mojado
var estado: String = "entero"                  ## entero · ardiendo · quemado (se consumió ardiendo) · roto (se consumió a golpes)
var bloqueos: int = 0                          ## cuántos disparos ha parado (para las pruebas y el diario de partida)
var desintegra_t: float = 0.0                  ## s que le quedan a la malla quemada antes de desaparecer (> 0 = desintegrándose)

var _entero: PiezaFuego3D = null
var _quemado: PiezaFuego3D = null
var _escala_quemado: Vector3 = Vector3.ONE
var en_brazo: bool = false                     ## true si va colgado del hueso del brazo (modelo con esqueleto); false = delante del cuerpo
var _capa_mojada: StandardMaterial3D = null    ## la capa de «mojado» sobre la malla entera (null = seco)
var _mats_quemado: Array[ShaderMaterial] = []  ## V6: materiales comunes de la malla quemada (su uniform `disolver` hace la desintegración)
var disolver: float = 0.0                      ## V6: 0..1, cuánto lleva deshecho (lo lee la prueba; 0 si no se usa el disolver)
var empujes_bloqueo: int = 0                   ## 21/11: cuántas veces un hechizo que no era fuego lo empujó (pruebas)
var giros_cubrirse: int = 0                    ## 21/11: cuántas veces se giró a cubrirse tras un golpe por la espalda o el costado (pruebas)
var _defensa_previa: float = 0.0               ## la defensa del goblin antes del escudo: se la devuelve al consumirse («que pelee pero sin la ventaja»)
var _capa_carbon: StandardMaterial3D = null    ## la capa de carbonizado mientras arde (null = sin quemar)
var _choque: Area3D = null                     ## la caja de choque del escudo (ver COMO UN MURO)
var _bucle_ardiendo: bool = false              ## true mientras está pedido el clip del brazo ardiendo


## La caja de choque: un Area3D que reenvía el golpe al escudo. Los hechizos la tratan como a cualquier reactivo (`on_spell_hit` con tres argumentos).
class ChoqueEscudo extends Area3D:
	var escudo: Escudo3D = null

	func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
		if escudo != null and is_instance_valid(escudo):
			escudo.on_spell_hit(rune_data, direccion, hechizo)


## Le pone un escudo a `c` (o devuelve el que ya tiene). `con_modelo = false` fuerza las formas sencillas de PiezaFuego3D.
static func equipar(c: Combate3D, con_modelo: bool = true) -> Escudo3D:
	if c == null:
		return null
	if c.escudo != null and is_instance_valid(c.escudo):
		return c.escudo
	var e := Escudo3D.new()
	e.name = "Escudo"
	e.combate = c
	var opc: Dictionary = {} if con_modelo else {"modelos": false}
	e._entero = PiezaFuego3D.crear(ID_ENTERO, opc)
	e._quemado = PiezaFuego3D.crear(ID_QUEMADO, opc)
	if e._entero != null:
		e.add_child(e._entero)
	if e._quemado != null:
		e._quemado.visible = false
		e.add_child(e._quemado)
		# V6: la malla quemada se dibuja con el material común para poder DISOLVERSE por celdas (con el borde de brasa) al desintegrarse.
		Ocluso3D.preparar()                                  # idempotente; el parámetro global no hace nada mientras nadie lo active
		e._mats_quemado = Ocluso3D.convertir_nodo(e._quemado)
		for m in e._mats_quemado:
			Ocluso3D.configurar_disolver(m, Ocluso3D.DISOLVER_COLOR, Ocluso3D.DISOLVER_CELDA_ESCUDO)
	c.escudo = e
	e._defensa_previa = c.defensa
	c.defensa = maxf(c.defensa, Dano.DEF_ESCUDO)          # 29/10 (DANO_Y_TINTA): el guerrero con escudo lleva defensa 5 (el resto de goblins, 2)
	c.add_child(e)
	e._colocar()
	e._crear_choque()
	if c.pj != null and is_instance_valid(c.pj):
		preparar_brazo_ardiendo(c.pj)
	if e.en_brazo and c.pj != null and is_instance_valid(c.pj):
		c.pj.poner_equipo_visible(PIEZA_EQUIPO_ADORNO, false)     # el de adorno del brazo ya no hace falta (se vería doble)
	e.mano_quemada.connect(func(g: Combate3D) -> void:            # las chispas de la mano: Pipeline (VfxReaccion3D), enganchadas a la señal de arriba
		if g != null and is_instance_valid(g) and g.pj != null:
			VfxReaccion3D.mano_quemada(g.pj, T_MANO_QUEMADA))
	return e


## 21/11 (arena de combate, pieza `goblin_escudo` de Puzle3D): un goblin guerrero con su combate y su escudo, colgado de `p_mundo` en `pos`. null si falta el modelo.
static func invocar_goblin_escudo(p_mundo: Node3D, pos: Vector3, p_jugador: Jugador3D = null, p_lanz: Lanzador3D = null) -> Combate3D:
	if p_mundo == null or not p_mundo.has_method("_personaje"):
		return null
	var modelo: Pj3D = p_mundo.call("_personaje", ["goblin_warrior_chibi"], pos)
	if modelo == null:
		return null
	var lista: Variant = p_mundo.get("_goblins")
	if lista is Array:
		(lista as Array).append(modelo)
	var c: Combate3D = Combate3D.equipar(modelo, p_mundo, p_jugador, p_lanz)
	equipar(c)
	return c


## ¿Tiene ocupado al goblin? Mientras el escudo arde se quema el brazo: ni ataca ni persigue (lo consulta `Combate3D._ia`).
func ocupa_al_goblin() -> bool:
	return esta_ardiendo() and combate != null and is_instance_valid(combate) and not combate.muerto


## La caja de choque del tamaño de la malla del escudo (en el espacio del escudo, que ya lleva la escala del brazo). Sin malla, un disco aproximado.
func _crear_choque() -> void:
	_choque = ChoqueEscudo.new()
	_choque.name = "ChoqueEscudo"
	_choque.escudo = self
	_choque.collision_layer = Lanzador3D.CAPA_REACTIVO
	_choque.collision_mask = 0
	_choque.monitoring = false
	_choque.monitorable = true
	var caja := AABB(Vector3(-0.28, -0.28, -0.04), Vector3(0.56, 0.56, 0.08))
	if _entero != null:
		var hay: bool = false
		for mi in _entero.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			if m.mesh == null:
				continue
			var t: Transform3D = _transform_hasta(m, _entero)     # en el espacio del escudo (el padre de la malla entera)
			var a: AABB = t * m.mesh.get_aabb()
			caja = a if not hay else caja.merge(a)
			hay = true
	var forma := BoxShape3D.new()
	var tam: Vector3 = caja.size
	var minimo: float = GROSOR_MIN_CHOQUE / maxf(ESCALA_EN_BRAZO, 0.01)
	forma.size = Vector3(maxf(tam.x, minimo), maxf(tam.y, minimo), maxf(tam.z, minimo))
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position = caja.get_center()
	_choque.add_child(cs)
	add_child(_choque)


## La transformación de `n` relativa a `hasta` (subiendo por los padres).
static func _transform_hasta(n: Node3D, hasta: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var x: Node = n
	while x != null and x != hasta:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return (hasta.transform * t) if x == hasta else t


func _apagar_choque() -> void:
	if _choque != null and is_instance_valid(_choque):
		_choque.set_deferred("monitorable", false)
		_choque.collision_layer = 0


## Construye (una vez por modelo) el clip ANIM_BRAZO_ARDIENDO sobre el Idle del goblin. Devuelve si el modelo lo tiene.
static func preparar_brazo_ardiendo(pj: Pj3D) -> bool:
	if pj == null or pj._ap == null:
		return false
	if pj._ap.has_animation(ANIM_BRAZO_ARDIENDO):
		return true
	var idle_n: String = pj._buscar_clip("idle")
	var sk: Skeleton3D = pj._esqueleto()
	if idle_n == "" or sk == null:
		return false
	var idle: Animation = pj._ap.get_animation(idle_n)
	var prefijo: String = String(pj._ap.get_node(pj._ap.root_node).get_path_to(sk)) + ":"
	var dest := Animation.new()
	dest.length = CICLO_BRAZO_ARDIENDO
	dest.loop_mode = Animation.LOOP_LINEAR
	var n: int = maxi(int(ceil(CICLO_BRAZO_ARDIENDO * 60.0)), 2)     # 60 fotogramas por segundo: 14 sacudidas por ciclo necesitan muestras finas
	var hips_y: float = 0.0
	for i in range(idle.get_track_count()):
		var tipo: int = idle.track_get_type(i)
		if tipo != Animation.TYPE_ROTATION_3D and tipo != Animation.TYPE_POSITION_3D:
			continue
		var nom: String = String(idle.track_get_path(i)).get_slice(":", 1)
		if sk.find_bone(nom) < 0:
			continue
		var d: int = dest.add_track(tipo)
		dest.track_set_path(d, NodePath(prefijo + nom))
		if tipo == Animation.TYPE_POSITION_3D and nom.ends_with("Hips"):
			hips_y = absf(idle.position_track_interpolate(i, 0.0).y)
		for f in range(n + 1):
			var u: float = float(f) / float(n)
			var t: float = CICLO_BRAZO_ARDIENDO * u
			var ts: float = fposmod(t, maxf(idle.length, 0.001))
			if tipo == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = idle.rotation_track_interpolate(i, ts)
				if BRAZO_ARDIENDO_HUESOS.has(nom):
					q = q * giro_brazo_ardiendo(nom, u)
				dest.rotation_track_insert_key(d, t, q)
			else:
				var p: Vector3 = idle.position_track_interpolate(i, ts)
				if nom.ends_with("Hips"):
					p.y += hips_y * SALTITO_ALTO * absf(sin(PI * SALTITOS_CICLO * u))
				dest.position_track_insert_key(d, t, p)
	var lib: AnimationLibrary = pj._ap.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		pj._ap.add_animation_library("", lib)
	lib.add_animation(ANIM_BRAZO_ARDIENDO, dest)
	return true


## El giro que se suma a `hueso` en el instante normalizado `u` (0..1) del ciclo: la postura fija más la oscilación (entera por ciclo: el bucle cierra).
static func giro_brazo_ardiendo(hueso: String, u: float) -> Quaternion:
	var d: Array = BRAZO_ARDIENDO_HUESOS[hueso]
	var grados: float = float(d[1]) + float(d[2]) * sin(TAU * float(d[3]) * u)
	return Quaternion((d[0] as Vector3).normalized(), deg_to_rad(grados))


## Pide (o quita) el bucle del brazo ardiendo al árbol del goblin.
func _poner_bucle_ardiendo(si: bool) -> void:
	if combate == null or not is_instance_valid(combate) or combate.pj == null or not is_instance_valid(combate.pj):
		return
	var pj: Pj3D = combate.pj
	if si:
		var arbol: ArbolAnimPj = pj.arbol()
		if arbol != null and pj._ap != null and pj._ap.has_animation(ANIM_BRAZO_ARDIENDO) \
				and arbol.pedir(ESTADO_BRAZO_ARDIENDO, ANIM_BRAZO_ARDIENDO, {"bucle": Animation.LOOP_LINEAR, "vel": 1.0, "mezcla": 0.12}):
			pj.animacion_actual = ESTADO_BRAZO_ARDIENDO
			pj.set_velocidad_animacion(1.0, false)
			_bucle_ardiendo = true
			return
		combate.anim_orden = "hit"
		_bucle_ardiendo = true
	elif _bucle_ardiendo:
		_bucle_ardiendo = false
		pj.animacion_actual = ""
		combate._t_anim = 0.0


## 21/11 (Pablo: «que se gire a cubrirse»): un golpe que le entró por la espalda o el costado (viajaba en `direccion`) lo hace GIRARSE de golpe hacia de donde vino, con el escudo
## por delante y el clip de bloqueo, y a partir de ahí va a por ella: el siguiente disparo desde el mismo sitio ya lo para. Solo con el escudo activo (entero o ardiendo) y sin estar
## quemándose el brazo (entonces no se cubre: sacude el brazo). Devuelve si se giró.
func cubrirse(direccion: Vector3) -> bool:
	if combate == null or not is_instance_valid(combate) or combate.muerto or not esta_activo() or ocupa_al_goblin():
		return false
	var d := Vector3(-direccion.x, 0.0, -direccion.z)
	if d.length() < 0.01 or es_de_frente(direccion):
		return false
	combate.mirada = d.normalized()
	if combate.pj != null and is_instance_valid(combate.pj):
		combate.pj.mirar(combate.mirada, 1.0)                 # el giro es inmediato: se cubre ya, no a la velocidad de andar
	if combate.jugador != null and is_instance_valid(combate.jugador):
		combate.objetivo = combate.jugador
	giros_cubrirse += 1
	combate.texto("¡Se cubre!", Color(0.8, 0.75, 0.55), 0.28)
	_animar_bloqueo()
	PlayLog.event("escudo_se_cubre", {})
	return true


## 21/11: lo que no es fuego y para de frente lo empuja un poco hacia atrás, sin daño, con el clip de bloqueo.
func _empujar_bloqueo() -> void:
	if combate == null or not is_instance_valid(combate) or combate.muerto:
		return
	empujes_bloqueo += 1
	var atras := Vector3(-combate.mirada.x, 0.0, -combate.mirada.z)
	if atras.length() > 0.01 and combate.enraizado <= 0.0:
		combate._empuje += atras.normalized() * EMPUJE_BLOQUEO
	_animar_bloqueo()


## El clip de bloqueo (parry) del goblin; sin él, el «hit». No mientras arde (manda el clip del brazo).
func _animar_bloqueo() -> void:
	if esta_ardiendo() or combate == null or not is_instance_valid(combate):
		return
	var pj: Pj3D = combate.pj
	if pj == null or not is_instance_valid(pj) or pj._ap == null:
		return
	var clip: String = ""
	for a in pj._ap.get_animation_list():
		if String(a).to_lower().contains(CLIP_BLOQUEO):
			clip = String(a)
			break
	var arbol: ArbolAnimPj = pj.arbol()
	if clip != "" and arbol != null and arbol.pedir(ESTADO_BLOQUEO, clip, {"bucle": Animation.LOOP_NONE, "vel": VEL_BLOQUEO, "mezcla": 0.08}):
		pj.animacion_actual = ESTADO_BLOQUEO
		pj.set_velocidad_animacion(1.0, false)           # la velocidad del clip ya va en `vel` del estado (si no, se multiplicaría dos veces)
		combate._t_anim = maxf(combate._t_anim, pj._ap.get_animation(clip).length / VEL_BLOQUEO)
	else:
		combate.anim_orden = "hit"


## ¿Tiene este papel? Los de serie más los retoques de `papeles` (`+nombre` añade, `-nombre` quita; sin signo añade), en orden.
func tiene_papel(papel: String) -> bool:
	var ok: bool = PAPELES_DE_SERIE.has(papel)
	for r in papeles:
		var nombre: String = r.substr(1) if r.begins_with("+") or r.begins_with("-") else r
		if nombre == papel:
			ok = not r.begins_with("-")
	return ok


## ¿Está parando disparos ahora mismo? Entero o ardiendo todavía lo hace (arde y aún protege hasta consumirse); quemado o roto, no.
func esta_activo() -> bool:
	return (estado == "entero" or estado == "ardiendo") and tiene_papel(PAPEL_BLOQUEA) \
		and combate != null and is_instance_valid(combate) and not combate.muerto


func esta_ardiendo() -> bool:
	return arde_t > 0.0 and (estado == "ardiendo")


## ¿Viaja `direccion` contra la mirada del goblin, dentro del cono frontal? Solo cuenta el plano horizontal: un disparo cenital o sin dirección (una onda, el
## suelo) no es «de frente» y pasa de largo.
func es_de_frente(direccion: Vector3) -> bool:
	if combate == null:
		return false
	var d := Vector3(direccion.x, 0.0, direccion.z)
	var m := Vector3(combate.mirada.x, 0.0, combate.mirada.z)
	if d.length() < 0.01 or m.length() < 0.01:
		return false
	return (-d.normalized()).dot(m.normalized()) >= cos(deg_to_rad(ANGULO_CONO_FRONTAL * 0.5))


## EL ÚNICO PUNTO DE CONSULTA de Combate3D: ¿para este disparo? Si responde true, el escudo YA lo ha recibido (su `on_spell_hit`) y el goblin no debe aplicarlo.
func para(direccion: Vector3, hechizo: Hechizo) -> bool:
	if not cubre(direccion, hechizo):
		return false
	_recibir(hechizo)
	return true


## 28/10 · A2 (previsión): la DECISIÓN de `para`, sin recibir nada: ¿pararía este disparo? Es lo que `para` consulta antes de actuar, así que predicción y golpe real no divergen.
func cubre(direccion: Vector3, hechizo: Hechizo) -> bool:
	return hechizo != null and esta_activo() and es_de_frente(direccion)


## 28/10 · A2: qué le pasaría al ESCUDO con este hechizo (lo que decide `_recibir`, sin tocarlo): «prende», «seca» (fuego sobre mojado), «moja», «apaga» (hielo, o agua sobre uno que arde)
## o «desgasta» (cualquier otro). Cadena vacía = nada. `_recibir` usa esta misma tabla.
func reaccion_a(hechizo: Hechizo) -> String:
	match hechizo.elemento:
		"fuego":
			if mojado_t > 0.0:
				return "seca"
			return "prende" if (estado == "entero" and tiene_papel(PAPEL_INFLAMABLE)) else ""
		"agua":
			return "apaga" if esta_ardiendo() else "moja"
		"hielo":
			return "apaga" if esta_ardiendo() else "empuja"
	return "empuja"                                          # 21/11: ya no desgasta; lo empuja un poco sin daño


## El contrato de los reactivos, para quien golpee al escudo directamente (sin pasar por el cono): el golpe es del escudo, no del goblin.
func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	var h: Hechizo = hechizo if hechizo != null else (Hechizo.construir(rune_data, {}) if rune_data != null else null)
	if h != null and (estado == "entero" or estado == "ardiendo"):
		_recibir(h)


func _recibir(h: Hechizo) -> void:
	bloqueos += 1
	_avisar(Mundo3D.R_BLOQUEADO)
	bloqueado.emit(_pos_mundo())
	var r: String = reaccion_a(h)                        # A2: la decisión del fuego es de `reaccion_a`, la misma que consulta la previsión
	match h.elemento:
		"fuego":
			if r == "seca":
				mojado_t = 0.0                           # fuego sobre mojado = vapor: lo seca y no prende (como el goblin)
				_avisar(Mundo3D.R_SECADO)
				_actualizar_mojado()
			else:
				prender()
		"agua":
			if tiene_papel(PAPEL_INFLAMABLE) and mojado_t <= 0.0:
				_avisar(Mundo3D.R_MOJADO)
			mojado_t = T_MOJADO
			apagar()
			_actualizar_mojado()
			_empujar_bloqueo()
		"hielo":
			apagar()
			_empujar_bloqueo()
		_:
			_empujar_bloqueo()                               # 21/11: tierra, viento, rayo… lo empujan un poco y no le hacen nada
	if combate != null and is_instance_valid(combate):
		combate.texto("Bloqueado", Color(0.8, 0.7, 0.5), 0.28)
	PlayLog.event("escudo_bloquea", {"elemento": h.elemento, "vida": snappedf(vida, 0.1), "estado": estado})


## Lo prende el fuego (directo o porque el goblin arde). Devuelve si prendió. No reinicia la cuenta de uno que ya arde.
func prender() -> bool:
	if estado != "entero" or not tiene_papel(PAPEL_INFLAMABLE) or mojado_t > 0.0:
		return false
	estado = "ardiendo"
	arde_t = T_CONSUMO
	if _entero != null:
		_entero.poner_estado("ardiendo")
	_avisar(Mundo3D.R_PRENDIDO)
	if combate != null and is_instance_valid(combate):
		combate._cancelar_ataque()                       # 21/11: se le quema el brazo: el ataque que tuviera a medias se corta
		combate.texto("¡Se quema el brazo!", Color(1.0, 0.55, 0.2), 0.3)
	_poner_bucle_ardiendo(true)
	PlayLog.event("escudo_brazo_ardiendo", {})
	return true


## Lo apaga el agua o el hielo. Devuelve si estaba ardiendo.
func apagar() -> bool:
	if estado != "ardiendo":
		return false
	estado = "entero"
	arde_t = 0.0
	if _entero != null:
		_entero.poner_estado("entero")
	_avisar(Mundo3D.R_APAGADO_AGUA)
	_poner_bucle_ardiendo(false)                         # apagado a tiempo: vuelve a pelear con el escudo (lo chamuscado se queda)
	return true


func _desgastar(cantidad: float) -> void:
	vida -= maxf(cantidad, 0.0)
	if vida <= 0.0:
		_consumir("roto")


## Se acaba: quemado (le quema la mano al goblin y la malla quemada se desintegra) o roto (desaparece). El goblin queda expuesto en ambos casos.
func _consumir(causa: String) -> void:
	if estado == "quemado" or estado == "roto":
		return
	estado = causa
	arde_t = 0.0
	vida = 0.0
	_poner_bucle_ardiendo(false)
	_apagar_choque()
	if combate != null and is_instance_valid(combate):
		combate.defensa = _defensa_previa                # 21/11 (Pablo: «que pelee pero sin la ventaja»): sin escudo vuelve a la defensa de un goblin normal
	if _entero != null:
		_entero.visible = false
	if _quemado != null:
		_quemado.visible = causa == "quemado"
		_escala_quemado = _quemado.scale
	if causa == "quemado":
		desintegra_t = T_DESINTEGRA
		if combate != null and is_instance_valid(combate):
			combate.escudo_quemado = true                    # F1: al morir ese goblin suelta los jirones del escudo (tabla `goblin_escudo`)
		_quemar_mano()
	_avisar(Mundo3D.R_CONSUMIDO)
	consumido.emit(causa)
	PlayLog.event("escudo_consumido", {"causa": causa})


## El goblin suelta el escudo quemándose la mano: aturdido T_MANO_QUEMADA s con su clip (o el de golpe). No le prende fuego ni le quita vida.
func _quemar_mano() -> void:
	if combate == null or not is_instance_valid(combate) or combate.muerto:
		return
	combate.stun_timer = maxf(combate.stun_timer, T_MANO_QUEMADA)
	var tiene_clip: bool = combate.pj != null and is_instance_valid(combate.pj) and combate.pj.duracion(ROL_MANO_QUEMADA) > 0.0
	combate.anim_orden = ROL_MANO_QUEMADA if tiene_clip else "hit"
	combate.texto("¡Se quema la mano!", Color(1.0, 0.55, 0.2), 0.3)
	mano_quemada.emit(combate)
	PlayLog.event("escudo_mano_quemada", {"clip": combate.anim_orden})


func _physics_process(delta: float) -> void:
	if combate == null or not is_instance_valid(combate):
		return
	if combate.muerto:
		visible = false                                  # el escudo cae con el goblin; ya no para nada
		return
	_colocar()
	mojado_t = maxf(0.0, mojado_t - delta)
	_actualizar_mojado()
	if desintegra_t > 0.0:
		desintegra_t = maxf(0.0, desintegra_t - delta)
		if _quemado != null:
			if Ocluso3D.usar_quemado_disolver and not _mats_quemado.is_empty():
				# V6: se deshace por celdas en el MISMO tiempo que antes tardaba en encoger (decisión de Pablo, diario 239).
				disolver = 1.0 - desintegra_t / T_DESINTEGRA
				for m in _mats_quemado:
					Ocluso3D.poner_disolver(m, disolver)
			else:
				_quemado.scale = _escala_quemado * maxf(desintegra_t / T_DESINTEGRA, 0.001)    # comportamiento de antes de V6 (encoger)
			_quemado.visible = desintegra_t > 0.0
	# A2: lo que el goblin lleva encima arde con él (el escudo es inflamable y lo toca). El agua lo protege igual que a cualquier madera.
	if estado == "entero" and combate.esta_ardiendo():
		prender()
	if estado == "ardiendo":
		arde_t -= delta
		_actualizar_carbon(1.0 - arde_t / T_CONSUMO)
		if _bucle_ardiendo:
			combate._t_anim = maxf(combate._t_anim, 0.1)     # el clip del bucle manda: ni el andar ni el reposo lo pisan
			if combate.pj != null and is_instance_valid(combate.pj) and combate.pj.animacion_actual != ESTADO_BRAZO_ARDIENDO \
					and combate._fase_empuje == Combate3D.FASE_NINGUNA:
				_poner_bucle_ardiendo(true)                  # un golpe o un empujón lo quitó: se vuelve a pedir
		if arde_t <= 0.0:
			_consumir("quemado")


## La capa de carbonizado: aparece al prender y se oscurece con lo que lleva ardido (`k` 0..1). Se queda chamuscado si lo apagan.
func _actualizar_carbon(k: float) -> void:
	if _entero == null:
		return
	if _capa_carbon == null:
		_capa_carbon = StandardMaterial3D.new()
		_capa_carbon.albedo_color = Color(COLOR_CARBON, 0.0)
		_capa_carbon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_capa_carbon.roughness = 1.0
		_capa_carbon.emission_enabled = true
		_capa_carbon.emission = Color(0.85, 0.22, 0.05)
		PiezaFuego3D.poner_capa(_entero, _capa_carbon)
	var a: float = ALFA_CARBON_MAX * clampf(k, 0.0, 1.0)
	_capa_carbon.albedo_color.a = maxf(_capa_carbon.albedo_color.a, a)
	var lat: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)          # las brasas laten
	_capa_carbon.emission_energy_multiplier = BRASA_CARBON * clampf(k, 0.0, 1.0) * lat


## ¿Cuánto se ve carbonizado (0..1 del máximo)? Pruebas y capturas.
func carbonizado() -> float:
	return 0.0 if _capa_carbon == null else _capa_carbon.albedo_color.a / ALFA_CARBON_MAX


## Colgado del brazo se recoloca también en cada fotograma de dibujo (el clip avanza ahí, no en la física): sin esto iría un fotograma por detrás de la mano.
func _process(_delta: float) -> void:
	if en_brazo and combate != null and is_instance_valid(combate) and not combate.muerto:
		_colocar()


const HUESOS_BRAZO: PackedStringArray = ["mixamorig_LeftForeArm", "mixamorig_RightForeArm", "mixamorig_LeftHand", "mixamorig_RightHand"]


## Lo pone delante del cuerpo, mirando hacia donde mira el goblin (el frente de la pieza es +Z).
func _colocar() -> void:
	if combate == null:
		return
	# Con un goblin de verdad (esqueleto en el árbol): colgado del antebrazo, siguiendo el clip.
	var hueso: Variant = null
	if combate.pj != null and is_instance_valid(combate.pj) and is_inside_tree():
		hueso = combate.pj.hueso_ahora(HUESO_ESCUDO)
	en_brazo = hueso != null
	if en_brazo:
		var tb: Transform3D = hueso
		var b: Basis = tb.basis.orthonormalized()
		if CARA_AL_FRENTE:
			var fwd: Vector3 = combate.pj.global_transform.basis.z
			fwd.y = 0.0
			if fwd.length() < 0.01:
				fwd = Vector3(combate.mirada.x, 0.0, combate.mirada.z)
			fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
			var cara: Vector3 = fwd.rotated(Vector3.UP, deg_to_rad(GIRO_HACIA_FUERA))
			var bas: Basis = Basis.looking_at(-cara, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(-INCLINACION_ATRAS))
			global_transform = Transform3D(bas * Basis.from_scale(Vector3.ONE * ESCALA_EN_BRAZO), tb.origin + b * POS_EN_BRAZO + fwd * ADELANTE_EN_BRAZO + Vector3(0.0, -BAJADA_EN_BRAZO, 0.0))
			return
		var giro := Basis.from_euler(Vector3(deg_to_rad(GIRO_EN_BRAZO.x), deg_to_rad(GIRO_EN_BRAZO.y), deg_to_rad(GIRO_EN_BRAZO.z)))
		global_transform = Transform3D(b * giro * Basis.from_scale(Vector3.ONE * ESCALA_EN_BRAZO), tb.origin + b * POS_EN_BRAZO)
		return
	var m := Vector3(combate.mirada.x, 0.0, combate.mirada.z)
	if m.length() < 0.01:
		m = Vector3(0.0, 0.0, 1.0)
	m = m.normalized()
	position = Vector3(0.0, combate.altura * ALTURA_RELATIVA, 0.0) + m * DISTANCIA_MANO
	basis = Basis.looking_at(-m, Vector3.UP)
	# Empujado (22/10): mientras vuela o se levanta, el escudo viaja con el cuerpo en vez de quedarse flotando donde estaba el brazo de pie. Se mueve con el HUESO DEL BRAZO
	# más cercano a donde lo lleva de pie (antebrazo o mano) lo mismo que ese hueso se ha movido respecto a su postura de pie: `Rel = hueso_ahora × hueso_de_pie⁻¹`.
	if combate.en_empujado() and combate.pj != null and is_instance_valid(combate.pj) and is_inside_tree():
		var de_pie := Transform3D(basis, combate.global_position + position)
		var cd: Array = []
		var d_min: float = INF
		for h in HUESOS_BRAZO:
			var hm: Array = combate.pj.hueso_mundo(h)
			if hm.size() == 2 and ((hm[1] as Transform3D).origin - de_pie.origin).length() < d_min:
				d_min = ((hm[1] as Transform3D).origin - de_pie.origin).length()
				cd = hm
		if cd.size() == 2:
			var rel: Transform3D = (cd[0] as Transform3D) * (cd[1] as Transform3D).affine_inverse()
			var ahora: Transform3D = rel * de_pie
			ahora.basis = ahora.basis.orthonormalized()
			global_transform = ahora


## Dibuja el escudo MOJADO mientras `mojado_t > 0`: una capa translúcida (`material_overlay` de la malla entera, sin tocar sus materiales) con el brillo húmedo; en los
## últimos T_SECADO s se aclara hasta quitarse. Se llama cada fotograma (y al recibir el agua, para que se vea ya).
func _actualizar_mojado() -> void:
	if _entero == null:
		return
	if mojado_t <= 0.0 or estado != "entero":
		if _capa_mojada != null:
			_capa_mojada = null
			PiezaFuego3D.poner_capa(_entero, _capa_carbon)     # seco: vuelve lo chamuscado, si lo hay (null = sin capa, como antes)
		return
	if _capa_mojada == null:
		_capa_mojada = PiezaFuego3D.capa_mojada(ALFA_ESCUDO_MOJADO)
		PiezaFuego3D.poner_capa(_entero, _capa_mojada)
	_capa_mojada.albedo_color.a = ALFA_ESCUDO_MOJADO * smoothstep(0.0, T_SECADO, mojado_t)


## ¿Se ve el escudo mojado ahora? (pruebas y capturas)
func se_ve_mojado() -> bool:
	return _capa_mojada != null and _capa_mojada.albedo_color.a > 0.01


func _pos_mundo() -> Vector3:
	return global_position if is_inside_tree() else position


func _avisar(nombre: String) -> void:
	Mundo3D.avisar_reaccion(nombre, _pos_mundo(), self)

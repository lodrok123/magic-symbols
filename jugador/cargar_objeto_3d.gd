class_name CargarObjeto3D
extends Node

## COGER Y LANZAR (4/11, encargo de Pablo «recoger cosas del suelo y lanzarlas, como en Echoes of Wisdom»; referencia y tiempos en docs/RECOGER_LANZAR_2026-11-04.md).
## Cuelga de Jugador3D (`Jugador3D.carga`). Todo lo que Jugador3D tiene que saber son siete llamadas de una línea (ver `ocupa_manos`, `mult_vel`, `quieta`, `animar`, `al_recibir_golpe`).
##
## QUÉ SE COGE: lo que está en el grupo `cogible` y lleva el metadato `cogible` = un tipo de `COGIBLES`. Hoy: jarrones y cajas (`Rompible3D`). Un nodo suelto cualquiera con ese metadato también vale
## (se lleva tal cual, se suelta entero o, si su fila rompe, se esfuma con polvo). NO se coge: el bloque empujable (puzle), los cofres, las puertas, las plantas (esas van a la bolsa con E).
## TECLAS: E junto a un cogible lo coge, SIEMPRE que no haya una interacción más prioritaria a mano (cofre cerrado, puerta con llave, salida de nivel, NPC, planta o lo que enseñe la pista [E]).
## Con él en brazos: E lo lanza hacia donde mira, Q (`usar_consumible`) lo suelta delante sin romperlo.
## FASES (segundos, ver las constantes): agacharse y coger (`T_FONDO` hasta tocar el objeto y otro tanto en alzarse, con el clip `agacharse` acelerado) → llevarlo sobre la cabeza (andar a ×`mult_vel`,
## sin correr, saltar, rodar, golpear ni lanzar hechizos) → anticipación `T_ANTICIPAR` + lanzamiento + remate (`T_REMATE`) → vuelo en arco → impacto. Si recibe un golpe con él en brazos, se cae y se rompe.
## LA POSE (4/11, clips de Meshy en arte/meshy/jugadora_carga_clips.glb, ver ClipsFamilia.FUENTE_CLIPS_CARGA y docs/RECOGER_LANZAR_2026-11-04.md §2): coger = `levantar` (acelerado: el agarre cae en `T_FONDO`
## y toda la subida dura ~`T_FONDO`·2), cargando = `cargar_idle` / `cargar_andar` (la velocidad del clip sigue a la real, con tope), lanzar = `lanzar_objeto` (la suelta en su instante medido, `T_SUELTA_CLIP`;
## ~0,5 s en total), soltar = `dejar_objeto` (apoya a los `T_DEJAR_FONDO` s). Los objetos LIGEROS (`es_ligero`: piedras, frutas…) se cogen y se lanzan de una vez con `coger_lanzar` (`T_PEQUENO` s, sin cargarlos).
## RESPALDO: un modelo SIN esos clips (`tiene_clips()` falso) sigue con la capa procedural `BrazosCarga3D` sobre `agacharse` / `walk` / `idle`. En los dos casos el objeto va al punto medio de los huesos de las
## manos (en brazos, sobre la cabeza: ver `_base_en_manos`) en cada actualización del esqueleto.

const RECOGER_ACTIVO: bool = true

enum Estado { LIBRE, COGIENDO, CARGANDO, ANTICIPANDO, LANZANDO, SOLTANDO }

## Una fila por tipo. `vel` = multiplicador de la velocidad de andar con él en brazos · `alcance` = casillas del lanzamiento (en plano) · `dano` = daño al enemigo que recibe el golpe (como el golpe F: sin elementos) ·
## `empuje` = fuerza que se pasa a `Combate3D.recibir_golpe_cuerpo` · `rompe` = se rompe al caer o chocar · `alto` = u de alto · `escala` = a qué tamaño se ve en brazos (el jarrón entero es casi tan alto como ella y le taparía los brazos; vuelve a su tamaño al soltarse o romperse).
## `ligero` (opcional) = true: objeto pequeño, se coge y se lanza de una vez con el clip `coger_lanzar` sin cargarlo; sin la clave cuenta como ligero lo que mide `UMBRAL_LIGERO` de alto o menos (ver `es_ligero`).
const COGIBLES: Dictionary = {
	"jarron": {"nombre": "jarrón", "vel": 0.7, "alcance": 3.5, "dano": 8.0, "empuje": 4500.0, "rompe": true, "alto": 0.5, "escala": 0.6},
	"caja": {"nombre": "caja", "vel": 0.7, "alcance": 3.2, "dano": 6.0, "empuje": 3500.0, "rompe": true, "alto": 0.4, "escala": 0.65},
	# Hoy no hay piedras sueltas en el mundo (las `piedras` / `rocas_pequenas` son decorado y las `piedra` de `fuentes.tsv` van a la bolsa con E); la fila queda lista para cuando haya (metadato `cogible` = "piedra").
	"piedra": {"nombre": "piedra", "vel": 0.6, "alcance": 3.0, "dano": 12.0, "empuje": 6000.0, "rompe": false, "alto": 0.35, "escala": 1.0, "ligero": true},
}
## Hasta qué alto (u) un cogible sin la clave `ligero` cuenta como pequeño (una piedra de 0,35 u, una fruta de 0,2 u; el jarrón de 0,5 y la caja de 0,4 se cargan).
const UMBRAL_LIGERO: float = 0.36

# --- tiempos (s). Echoes of Wisdom: agacharse y coger ~0,3 s; alzarlo ~0,3 s; lanzar casi seguido ---
const T_FONDO: float = 0.33              ## de pulsar E a tener el objeto en las manos (fondo de la agachada); el clip `agacharse` se acelera para que su fondo caiga aquí
const T_ANTICIPAR: float = 0.12          ## el objeto hacia atrás antes de soltarlo
const T_REMATE: float = 0.28             ## desde que lo suelta hasta poder andar otra vez
const T_REMATE_PESO: float = 0.12        ## al final del remate los brazos vuelven a la animación
const T_SOLTAR: float = 0.28             ## dejarlo delante
# Con los clips de Meshy (4/11). Los instantes de cada clip (la suelta, las manos abajo) están medidos en Pj3D.INSTANTE_CLIP; el clip se acelera para que caigan en estos tiempos.
const T_SUELTA_CLIP: float = 0.18        ## de pulsar E a la suelta del objeto con `lanzar_objeto` (el clip, de 1,15 s, va a ×2,3: el lanzamiento entero dura ~0,5 s)
const T_DEJAR_FONDO: float = 0.34        ## de pulsar Q a apoyar el objeto con `dejar_objeto` (el clip, de 2,32 s, va a ×3,8: entero ~0,6 s)
const T_PEQUENO: float = 1.2             ## `coger_lanzar` entero (3,25 s a ×2,7): se agacha, coge con la derecha, da un paso y lanza
const ZANCADA_CARGAR: float = 0.28       ## u/s de suelo que cubre el clip `cargar_andar` a ×1: su ciclo avanza la cadera 0,41 u del GLB (0,26 u del juego, ×0,625) en 0,93 s. Es un andar de pasos CORTOS: el juego va a 1,12 u/s
const VEL_CARGAR_MIN: float = 0.8        ## tope inferior de la velocidad del clip `cargar_andar` (el arranque, antes de llegar a la velocidad de marcha)
const VEL_CARGAR_MAX: float = 2.2        ## tope superior: a ×4 (lo que pediría no patinar) los pies son un borrón; a este tope aún patinan (ver docs/RECOGER_LANZAR_2026-11-04.md)
const T_PESO_GOLPE: float = 0.18         ## los brazos se sueltan tras un golpe
const ALCANCE_COGER: float = 2.7         ## u (plano) del centro de la jugadora al del objeto: la casilla vecina (2,3) con margen, como el cofre y los NPC
const ALTO_COGER: float = 1.0            ## u de diferencia de altura como mucho
const VEL_VUELO: float = 12.0            ## u/s en plano
const ARCO_ALTO: float = 1.1             ## u que sube el arco sobre la recta del lanzamiento
const RADIO_CHOQUE: float = 0.75         ## u: a esa distancia (plano) de un enemigo en vuelo, choca
const ALTO_CHOQUE: float = 2.2           ## u por encima de sus pies hasta donde el arco aún lo alcanza (un lanzamiento a quemarropa pasa a ~1,5 u sobre su cabeza: se cuenta como acierto, como en los Zelda de arriba)
const RADIO_IMPACTO: float = 1.15        ## u: a quién alcanza el golpe al caer
const DESPEGUE_ANGULO: float = 0.25      ## fracción del vuelo antes de la cual el suelo no cuenta (sale de la altura de la cabeza)
const HUNDE_EN_CABEZA: float = 0.08       ## u: lo que la base del objeto baja por debajo de la coronilla cuando lo lleva sobre la cabeza
const EN_EJE_CABEZA: float = 0.55         ## 0 = justo sobre las manos (en el plano), 1 = justo sobre la coronilla
const GRUPO: StringName = &"cogible"
const SONIDO_GOLPE: String = "dano"
const TEMBLOR: float = 0.10

signal cogido(tipo: String)
signal lanzado(tipo: String, destino: Vector3)
signal impacto(tipo: String, punto: Vector3, enemigos: int)
signal soltado(tipo: String, punto: Vector3)
signal roto_en_brazos(tipo: String)

var jugador: Jugador3D = null
var estado: int = Estado.LIBRE
var objeto: Node3D = null                ## el que lleva (o está cogiendo)
var tipo: String = ""
var datos: Dictionary = {}
var ultimo: Dictionary = {}              ## resumen del último lanzamiento/suelta/rotura (lo leen las pruebas y el diario)
var activo: bool = RECOGER_ACTIVO

var _t: float = 0.0
var _agarrado: bool = false
var _k_coger: float = 0.0               ## 0..1: cuánto ha viajado el objeto del suelo a las manos
var mano_izq: Vector3 = Vector3.ZERO        ## posición de las manos en el último skeleton_updated (con la capa de brazos puesta)
var mano_der: Vector3 = Vector3.ZERO
var _tengo_manos: bool = false
var cabeza_top: Vector3 = Vector3.ZERO     ## la punta de la cabeza (HeadTop_End) en el mismo instante
var _hueso_cabeza: int = -1
var _f_cabeza: float = 1.0                 ## 0..1: cuánto manda la cabeza sobre las manos al colocar el objeto (agachada: 0; alzado: 1)
var _t_total: float = 0.0                ## lo que dura la agachada entera (la del clip)
var _t_fondo: float = T_FONDO
var _origen: Vector3 = Vector3.ZERO      ## dónde estaba el objeto al cogerlo
var _pos_soltar: Vector3 = Vector3.ZERO
var _peso_salida: float = 1.0            ## el peso con el que empieza a soltarse la capa (tras un golpe)
var _desvanece: float = 0.0              ## s que quedan de soltar la capa cuando el estado ya es LIBRE
var _brazos: BrazosCarga3D = null
var usa_clips: bool = false                ## true = este cargado va con los clips de Meshy (el modelo los tiene); false = la capa procedural de respaldo
var pequeno: bool = false                  ## true = objeto ligero cogido con `coger_lanzar` (sin cargarlo)
var _t_suelta: float = 0.0                 ## pequeño: segundo (de pulsar E) en que sale el objeto de la mano derecha
var _t_anticipar: float = T_ANTICIPAR      ## lo que dura la anticipación de ESTE lanzamiento (con clip: T_SUELTA_CLIP)
var _t_remate: float = T_REMATE            ## lo que dura el remate (tras soltar el objeto hasta poder andar) de ESTE lanzamiento / suelta
var _t_soltar: float = T_SOLTAR            ## lo que tarda en apoyar el objeto al soltarlo con Q
var _sk: Skeleton3D = null
var _hueso_izq: int = -1
var _hueso_der: int = -1
var _vuelos: Array = []                  ## objetos en el aire: diccionarios (ver `_iniciar_vuelo`)


## Lo monta Jugador3D.montar. Devuelve el nodo (null si el interruptor está apagado).
static func montar(j: Jugador3D) -> CargarObjeto3D:
	var c := CargarObjeto3D.new()
	c.name = "CargarObjeto3D"
	c.jugador = j
	c.activo = RECOGER_ACTIVO
	j.add_child(c)
	return c


func _ready() -> void:
	add_to_group(PistaProximidad.GRUPO)         # la pista «[E] Coger / Lanzar» (gamefeel U6)
	PistaProximidad.asegurar(get_tree())
	if jugador != null:
		jugador.murio.connect(_al_morir)


# ---------------------------------------------------------------------------------------------------------------------
#  Lo que pregunta Jugador3D
# ---------------------------------------------------------------------------------------------------------------------

## ¿Tiene las manos ocupadas (agachándose, cargando, lanzando, soltando)? Entonces no corre, no salta, no rueda, no golpea ni lanza hechizos.
func ocupa_manos() -> bool:
	return activo and estado != Estado.LIBRE


## Multiplicador de la velocidad de andar: el de la fila del objeto mientras lo lleva, 1 si no.
func mult_vel() -> float:
	if not ocupa_manos():
		return 1.0
	return float(datos.get("vel", 0.7))


## ¿Está quieta de espaldas al mundo (agachándose, armando el lanzamiento, remate, soltando)? Solo andar cargando permite moverse.
func quieta() -> bool:
	return activo and (estado == Estado.ANTICIPANDO or estado == Estado.LANZANDO or estado == Estado.SOLTANDO)


## Lo llama Jugador3D._animar: con el objeto en brazos pone idle / andar (a ×vel el clip) y devuelve true; si no, false y sigue lo de siempre.
## Con los clips de Meshy: `cargar_andar` (a la velocidad del suelo: `vel_clip_andar`) o `cargar_idle`.
func animar(mov: Vector3) -> bool:
	if not ocupa_manos() or estado == Estado.COGIENDO:
		return false
	var pj: Pj3D = jugador.pj
	if usa_clips and estado == Estado.CARGANDO:
		if mov != Vector3.ZERO:
			pj.jugar("cargar_andar")
			pj.set_velocidad_animacion(vel_clip_andar())
		else:
			pj.jugar("cargar_idle")
			pj.set_velocidad_animacion(1.0)
		return true
	if estado == Estado.CARGANDO and mov != Vector3.ZERO:
		pj.jugar("walk")
		pj.set_velocidad_animacion(mult_vel())
	else:
		pj.jugar("idle")
		pj.set_velocidad_animacion(1.0)
	return true


## Velocidad del clip `cargar_andar` para la velocidad real del suelo (u/s): la que cubre su ciclo (`ZANCADA_CARGAR`), con los topes `VEL_CARGAR_MIN`/`VEL_CARGAR_MAX`.
func vel_clip_andar(v_suelo: float = -1.0) -> float:
	var v: float = jugador.vel_suelo.length() if v_suelo < 0.0 else v_suelo
	return clampf(v / ZANCADA_CARGAR, VEL_CARGAR_MIN, VEL_CARGAR_MAX)


## ¿El modelo de la jugadora trae TODOS los clips de cargar (levantar, cargar_idle, cargar_andar, lanzar_objeto, dejar_objeto)? Si no, va la capa procedural de respaldo.
func tiene_clips() -> bool:
	if jugador == null or jugador.pj == null:
		return false
	for rol in ["levantar", "cargar_idle", "cargar_andar", "lanzar_objeto", "dejar_objeto"]:
		if jugador.pj.duracion(rol) <= 0.0:
			return false
	return true


## ¿Esta fila es de un objeto ligero (se coge y se lanza de una vez con `coger_lanzar`)? La clave `ligero` manda; sin ella, el alto (`UMBRAL_LIGERO`).
static func es_ligero(fila: Dictionary) -> bool:
	if fila.has("ligero"):
		return bool(fila["ligero"])
	return float(fila.get("alto", 1.0)) <= UMBRAL_LIGERO


## Un golpe de verdad (Jugador3D.recibir_dano): lo que lleva se cae y se rompe a sus pies; si aún se estaba agachando y no lo había cogido, lo deja donde estaba.
func al_recibir_golpe() -> void:
	if not ocupa_manos() or objeto == null:
		return
	if estado == Estado.COGIENDO and _t < _t_fondo * 0.5:
		_cancelar_cogida()
		return
	var punto: Vector3 = jugador.position + jugador.mirada() * 0.7
	punto.y = jugador.position.y
	_romper_o_soltar(punto, true)
	_peso_salida = 1.0 if _brazos == null else maxf(_brazos.influence, 0.0)
	_desvanece = T_PESO_GOLPE
	estado = Estado.LIBRE
	roto_en_brazos.emit(tipo)
	PlayLog.event("cogible_golpeado_en_brazos", {"tipo": tipo})
	_limpiar()


func _al_morir() -> void:
	if ocupa_manos() and objeto != null:
		_romper_o_soltar(jugador.position, true)
		_limpiar()
		estado = Estado.LIBRE
	_desvanece = 0.0
	if _brazos != null and is_instance_valid(_brazos):
		_brazos.influence = 0.0


# ---------------------------------------------------------------------------------------------------------------------
#  Entrada
# ---------------------------------------------------------------------------------------------------------------------

func _libre_para_actuar() -> bool:
	if jugador == null or not is_instance_valid(jugador) or not activo:
		return false
	return not jugador.muerto and not jugador.bloqueado and not jugador.nadando and not get_tree().paused and jugador.mundo.get("_velo") == null


## Con el objeto en brazos las teclas se atienden ANTES que el resto del juego (`_input`): E lo lanza y Q lo suelta, y ningún cofre ni hud se entera.
func _input(ev: InputEvent) -> void:
	if not ocupa_manos() or not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.is_action("interactuar"):
		get_viewport().set_input_as_handled()
		lanzar()
	elif k.is_action("usar_consumible"):
		get_viewport().set_input_as_handled()
		soltar()


## Con las manos libres: E coge lo que tenga a mano si no hay nada más prioritario. Va en `_unhandled_input`: si un cofre, una puerta, un NPC… ya se la comió, no llega.
func _unhandled_input(ev: InputEvent) -> void:
	if estado != Estado.LIBRE or not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or not k.is_action("interactuar"):
		return
	var o: Node3D = candidato()
	if o == null or hay_otra_interaccion():
		return
	if coger(o):
		get_viewport().set_input_as_handled()


## La pista «[E] Coger» / «[E] Lanzar» de PistaProximidad.
func accion_pista() -> String:
	if not activo or jugador == null or not _libre_para_actuar():
		return ""
	if estado == Estado.CARGANDO:
		return "Lanzar"
	if estado == Estado.LIBRE and candidato() != null and not hay_otra_interaccion():
		return "Coger"
	return ""


# ---------------------------------------------------------------------------------------------------------------------
#  Coger
# ---------------------------------------------------------------------------------------------------------------------

## El cogible más cercano al alcance (plano), a su altura y no roto ni en brazos. null si no hay.
func candidato() -> Node3D:
	if jugador == null or not is_inside_tree():
		return null
	var mejor: Node3D = null
	var d_mejor: float = ALCANCE_COGER
	for n in get_tree().get_nodes_in_group(GRUPO):
		var o := n as Node3D
		if o == null or not is_instance_valid(o) or not o.is_inside_tree() or not _es_cogible(o):
			continue
		var d: Vector3 = o.global_position - jugador.global_position
		if absf(d.y) > ALTO_COGER:
			continue
		d.y = 0.0
		if d.length() <= d_mejor:
			d_mejor = d.length()
			mejor = o
	return mejor


func _es_cogible(o: Node3D) -> bool:
	if not o.has_meta("cogible") or not COGIBLES.has(String(o.get_meta("cogible"))):
		return false
	if _marca(o, "roto_ya") or _marca(o, "en_brazos"):
		return false
	return not _en_vuelo(o)


## Una propiedad booleana del nodo (false si no la tiene: los cogibles sueltos no son Rompible3D).
func _marca(o: Object, prop: String) -> bool:
	var v: Variant = o.get(prop)
	return v != null and bool(v)


func _en_vuelo(o: Node3D) -> bool:
	for v in _vuelos:
		if (v as Dictionary)["objeto"] == o:
			return true
	return false


## ¿Hay algo más prioritario que el cogible para esta E? Cofre cerrado o puerta con llave a su alcance (los Puzle3D), salida de nivel, NPC del Bosque 02 y todo lo que enseñe la pista [E].
func hay_otra_interaccion() -> bool:
	var yo: Vector3 = jugador.global_position
	for n in get_tree().get_nodes_in_group(PistaProximidad.GRUPO):
		if n != self and is_instance_valid(n) and n.has_method("accion_pista") and String(n.call("accion_pista")) != "":
			return true
	for n in get_tree().get_nodes_in_group("salida_nivel"):
		if is_instance_valid(n) and n.has_method("cerca") and String(n.get("modo")) == SalidaNivel3D.MODO_USAR and bool(n.call("cerca")):
			return true
	for n in get_tree().get_nodes_in_group("e_cofre"):          # CofrePuzle: cerrado y a ALCANCE_COFRE (2,7)
		if is_instance_valid(n) and bool(n.get("es_cerrado")) and not bool(n.get("_abriendo")) and PistaProximidad.dist_plana((n as Node3D).global_position, yo) <= 2.7:
			return true
	for n in get_tree().get_nodes_in_group("e_puerta"):         # PuertaPuzle con llave, a ALCANCE_USAR (3,2)
		if is_instance_valid(n) and String(n.get("llave")) != "" and not bool(n.get("abierta")) and PistaProximidad.dist_plana((n as Node3D).global_position, yo) <= 3.2:
			return true
	var mundo: Node = jugador.mundo
	var reglas: Node = mundo.get_node_or_null("Reglas") if mundo != null else null
	if reglas != null and reglas.get("_gente") is Array:
		for g in (reglas.get("_gente") as Array):
			var p: Pj3D = (g as Dictionary).get("pj") as Pj3D
			if p != null and is_instance_valid(p) and PistaProximidad.dist_plana(p.position, yo) <= 2.7:
				return true
	return false


## Empieza a coger `o`: se vuelve hacia él, se agacha (clip `agacharse` acelerado) y a los `_t_fondo` s lo tiene en las manos. false si no puede (ocupada, nadando, sin clip…).
func coger(o: Node3D) -> bool:
	if not activo or estado != Estado.LIBRE or o == null or not _libre_para_actuar() or not _es_cogible(o):
		return false
	var t: String = String(o.get_meta("cogible"))
	var fila: Dictionary = COGIBLES[t]
	var hacia: Vector3 = o.global_position - jugador.global_position
	hacia.y = 0.0
	if hacia.length() > 0.05:
		jugador.mirar_hacia(hacia)
	# Qué clip: `coger_lanzar` (objeto ligero), `levantar` (objeto de carga) o, sin los clips de Meshy, `agacharse` + la capa procedural.
	var pj: Pj3D = jugador.pj
	var es_pequeno: bool = es_ligero(fila) and pj.duracion("coger_lanzar") > 0.0
	var con_clips: bool = not es_pequeno and tiene_clips()
	var rol: String = "coger_lanzar" if es_pequeno else ("levantar" if con_clips else "agacharse")
	var instante: float = Pj3D.instante_clip_de(pj.id, "coger_lanzar_agarre" if es_pequeno else rol)
	var vel: float = 1.0
	if es_pequeno:
		vel = pj.duracion(rol) / T_PEQUENO          # el clip entero en T_PEQUENO s
	elif instante > 0.0:
		vel = instante / T_FONDO                    # el agarre cae en T_FONDO
	var dur: float = jugador.gesto(rol, vel)
	if dur <= 0.0:
		if pj.duracion(rol) > 0.0:
			return false                         # había clip pero está ocupada (golpeando, rodando…)
		dur = T_FONDO * 2.0
		jugador._t_gesto = dur                   # sin clip: se queda quieta el mismo rato
	if o.has_method("al_coger") and not bool(o.call("al_coger")):
		return false
	objeto = o
	tipo = t
	datos = fila
	usa_clips = con_clips
	pequeno = es_pequeno
	estado = Estado.COGIENDO
	_t = 0.0
	_agarrado = false
	_t_total = dur
	_t_fondo = instante / vel if instante > 0.0 else T_FONDO
	_t_suelta = Pj3D.instante_clip_de(pj.id, "coger_lanzar") / vel if es_pequeno else 0.0
	_origen = o.global_position
	_desvanece = 0.0
	if not usa_clips and not pequeno:
		_asegurar_capa()
	PlayLog.event("cogible_coger", {"tipo": tipo, "fondo": snappedf(_t_fondo, 0.01), "total": snappedf(_t_total, 0.01), "clip": rol if (usa_clips or pequeno) else ""})
	return true


func _cancelar_cogida() -> void:
	if objeto != null:
		objeto.scale = Vector3.ONE
	if objeto != null and objeto.has_method("al_soltar"):
		objeto.call("al_soltar", _origen)
	elif objeto != null:
		objeto.global_position = _origen
	estado = Estado.LIBRE
	_limpiar()
	if _brazos != null:
		_brazos.influence = 0.0


# ---------------------------------------------------------------------------------------------------------------------
#  Soltar
# ---------------------------------------------------------------------------------------------------------------------

## Q: lo deja entero delante. false si no lo lleva o no hay sitio libre (entonces avisa y lo sigue llevando).
func soltar() -> bool:
	if estado != Estado.CARGANDO or objeto == null:
		return false
	var c: Vector2i = _casilla_para_soltar()
	if c.x < 0:
		_avisar("No hay sitio para dejarlo")
		return false
	_pos_soltar = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	estado = Estado.SOLTANDO
	_t = 0.0
	_t_soltar = T_SOLTAR
	_t_remate = T_REMATE
	jugador.mirar_hacia(_pos_soltar - jugador.position)
	if usa_clips:
		# `dejar_objeto` acelerado para que el objeto quede apoyado a los T_DEJAR_FONDO s; el resto del clip (se levanta con las manos vacías) es el remate
		var inst: float = Pj3D.instante_clip_de(jugador.pj.id, "dejar_objeto")
		var vel: float = inst / T_DEJAR_FONDO if inst > 0.0 else 1.0
		var dur: float = jugador.gesto("dejar_objeto", vel)
		if dur > T_DEJAR_FONDO:
			_t_soltar = T_DEJAR_FONDO
			_t_remate = dur - T_DEJAR_FONDO
	return true


func _casilla_para_soltar() -> Vector2i:
	var propia: Vector2i = Terreno3D.celda_de(jugador.position)
	var m: Vector3 = jugador.mirada()
	m.y = 0.0
	m = m.normalized() if m.length() > 0.01 else Vector3(0, 0, 1)
	# delante, y si no cabe, delante-izquierda, delante-derecha, los lados y detrás
	var giros: Array = [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]
	for g in giros:
		var d: Vector3 = m.rotated(Vector3.UP, deg_to_rad(float(g)))
		var c: Vector2i = Terreno3D.celda_de(jugador.position + d * Terreno3D.casilla * 0.9)
		if c != propia and _casilla_libre(c):
			return c
	return Vector2i(-1, -1)


func _casilla_libre(c: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.es_agua(c) or Terreno3D.bloqueada(c):
		return false
	var n: int = Terreno3D.altura_en(c)
	if not Terreno3D.pisable(c, n, false, n, false):
		return false
	return absf(Terreno3D.y_pies(c) - jugador.position.y) <= 0.8


# ---------------------------------------------------------------------------------------------------------------------
#  Lanzar
# ---------------------------------------------------------------------------------------------------------------------

## E con el objeto en brazos: anticipación y, a los `T_ANTICIPAR` s, sale despedido hacia donde mira. false si no lo lleva.
func lanzar() -> bool:
	if estado != Estado.CARGANDO or objeto == null:
		return false
	estado = Estado.ANTICIPANDO
	_t = 0.0
	_t_anticipar = T_ANTICIPAR
	_t_remate = T_REMATE
	jugador.pj.mirar(jugador.mirada(), 1.0)
	if usa_clips:
		# `lanzar_objeto` acelerado para que el objeto salga a los T_SUELTA_CLIP s (su instante medido); lo que queda del clip es el remate
		var inst: float = Pj3D.instante_clip_de(jugador.pj.id, "lanzar_objeto")
		var vel: float = inst / T_SUELTA_CLIP if inst > 0.0 else 1.0
		var dur: float = jugador.gesto("lanzar_objeto", vel)
		if dur > T_SUELTA_CLIP:
			_t_anticipar = T_SUELTA_CLIP
			_t_remate = dur - T_SUELTA_CLIP
	return true


func _soltar_al_aire() -> void:
	var dir: Vector3 = jugador.mirada()
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	var origen: Vector3 = objeto.global_position
	var dist: float = float(datos.get("alcance", 3.5)) * Terreno3D.casilla
	var meta: Vector3 = jugador.position + dir * dist
	var c_meta: Vector2i = Terreno3D.celda_de(meta)
	var y_fin: float = Terreno3D.y_pies(c_meta) if Terreno3D.en_mapa(c_meta) else jugador.position.y
	var v := {"objeto": objeto, "tipo": tipo, "datos": datos, "origen": origen, "dir": dir, "dist": dist, "t": 0.0, "T": dist / VEL_VUELO,
		"y0": origen.y, "y1": y_fin, "previa": origen, "nivel": jugador.nivel_actual()}
	_vuelos.append(v)
	ultimo = {"accion": "lanzar", "tipo": tipo, "origen": origen, "destino_previsto": jugador.position + dir * dist, "dir": dir, "dist": dist}
	lanzado.emit(tipo, jugador.position + dir * dist)
	PlayLog.event("cogible_lanzar", {"tipo": tipo, "dist": snappedf(dist, 0.1)})
	_limpiar()


func _volar(v: Dictionary, delta: float) -> bool:
	var o: Node3D = v["objeto"] as Node3D
	if o == null or not is_instance_valid(o):
		return true
	v["t"] = float(v["t"]) + delta
	var T: float = maxf(float(v["T"]), 0.05)
	var k: float = clampf(float(v["t"]) / T, 0.0, 1.0)
	var o0: Vector3 = v["origen"]
	var dir: Vector3 = v["dir"]
	var plano: Vector3 = o0 + dir * float(v["dist"]) * k
	var y: float = lerpf(float(v["y0"]), float(v["y1"]), k) + ARCO_ALTO * 4.0 * k * (1.0 - k)
	var p := Vector3(plano.x, y, plano.z)
	var c: Vector2i = Terreno3D.celda_de(p)
	# choque con una pared o con lo que tape la casilla (a la altura del vuelo)
	var previa: Vector3 = v["previa"]
	if not Terreno3D.en_mapa(c) or _tapa_el_paso(c, int(v["nivel"]), p.y):
		_aterrizar(v, previa)
		return true
	# choque con un enemigo en el aire
	var en_aire: Combate3D = _enemigo_en(p)
	if en_aire != null:
		_aterrizar(v, en_aire.global_position + Vector3(0.0, en_aire.altura * 0.6, 0.0))      # rompe contra su pecho, no en el aire por encima
		return true
	# tocó el suelo
	var suelo: float = Terreno3D.y_pies(c)
	if k >= DESPEGUE_ANGULO and p.y <= suelo + 0.04 or k >= 1.0:
		p.y = suelo
		_aterrizar(v, p)
		return true
	v["previa"] = p
	o.global_position = p
	o.rotation.x += 9.0 * delta
	o.rotation.z += 5.0 * delta
	return false


## ¿Tapa el paso la casilla `c`? Lo sólido (pared, árbol, bloque, otro jarrón) sí; el agua se sobrevuela.
func _tapa_el_paso(c: Vector2i, _nivel: int, _y: float) -> bool:
	return not Terreno3D.es_agua(c) and Terreno3D.bloqueada(c)


func _enemigo_en(p: Vector3) -> Combate3D:
	for n in get_tree().get_nodes_in_group("combate3d"):
		var c := n as Combate3D
		if c == null or not is_instance_valid(c) or c.muerto:
			continue
		var d: Vector3 = c.global_position - p
		var dy: float = p.y - c.global_position.y
		d.y = 0.0
		if d.length() <= RADIO_CHOQUE and dy > -0.3 and dy < c.altura + ALTO_CHOQUE:
			return c
	return null


## El objeto `v` cae o choca en `punto`: golpea a quien esté al lado, se rompe (o se queda en el suelo si no rompe) y lo apunta en `ultimo`.
func _aterrizar(v: Dictionary, punto: Vector3) -> void:
	var o: Node3D = v["objeto"] as Node3D
	var fila: Dictionary = v["datos"]
	var t: String = String(v["tipo"])
	var dir: Vector3 = v["dir"]
	var c: Vector2i = Terreno3D.celda_de(punto)
	if Terreno3D.en_mapa(c):
		punto.y = maxf(punto.y, Terreno3D.y_pies(c))
	var golpeados: int = 0
	var vida_antes: Array = []
	for n in get_tree().get_nodes_in_group("combate3d"):
		var e := n as Combate3D
		if e == null or not is_instance_valid(e) or e.muerto:
			continue
		var d: Vector3 = e.global_position - punto
		var dy: float = absf(punto.y - e.global_position.y)
		d.y = 0.0
		if d.length() <= RADIO_IMPACTO and dy <= 1.5:
			var h0: float = float(e.get("health"))
			e.recibir_golpe_cuerpo(dir, float(fila["dano"]), float(fila["empuje"]))
			golpeados += 1
			vida_antes.append([e, h0])
	# otros rompibles pegados al impacto: se rompen con el golpe
	var rotos_extra: int = 0
	for n in get_tree().get_nodes_in_group("rompible"):
		var r := n as Rompible3D
		if r != null and is_instance_valid(r) and r != o and not r.roto_ya and not r.en_brazos and (r.global_position - punto).length() <= 0.9:
			r.golpear(punto)
			rotos_extra += 1
	var rompio: bool = false
	if o != null and is_instance_valid(o):
		rompio = bool(fila.get("rompe", false))
		if rompio:
			_romper(o, punto)
		else:
			_dejar(o, punto)
	if golpeados > 0 or rompio:
		Sfx.play(jugador, SONIDO_GOLPE, 0.9)
		var fx: Variant = jugador.mundo.get("_fx") if jugador.mundo != null else null
		if fx is Vfx3D:
			(fx as Vfx3D).temblor(TEMBLOR)
	var danos: Array = []
	for par in vida_antes:
		danos.append(snappedf(float(par[1]) - float((par[0] as Combate3D).get("health")), 0.1))
	ultimo = {"accion": "impacto", "tipo": t, "punto": punto, "enemigos": golpeados, "danos": danos, "rompio": rompio, "rotos_extra": rotos_extra,
		"distancia": snappedf(Vector2(punto.x - float((v["origen"] as Vector3).x), punto.z - float((v["origen"] as Vector3).z)).length(), 0.01), "origen": v["origen"], "dir": dir}
	impacto.emit(t, punto, golpeados)
	PlayLog.event("cogible_impacto", {"tipo": t, "enemigos": golpeados, "rompio": rompio, "distancia": ultimo["distancia"]})


## Rompe `o` en `punto` (el botín y el polvo los pone su propio romper).
func _romper(o: Node3D, punto: Vector3) -> void:
	o.scale = Vector3.ONE
	if o.has_method("romper_lanzado"):
		o.call("romper_lanzado", punto)
	else:
		VfxPuzle3D.polvo(o.get_parent() as Node3D, punto + Vector3(0.0, 0.2, 0.0), 0.8)
		Sfx.play(o, "derrumbe", 1.6)
		o.queue_free()


## Lo deja entero en el suelo en `punto`.
func _dejar(o: Node3D, punto: Vector3) -> void:
	o.scale = Vector3.ONE
	if o.has_method("al_soltar"):
		o.call("al_soltar", punto)
	else:
		o.rotation = Vector3.ZERO
		o.global_position = punto


## Rompe (o, si no rompe, deja) lo que lleva en `punto`. Lo usan el golpe recibido y la muerte.
func _romper_o_soltar(punto: Vector3, romper: bool) -> void:
	if objeto == null or not is_instance_valid(objeto):
		return
	var rompe: bool = romper and bool(datos.get("rompe", false))
	if rompe:
		_romper(objeto, punto)
	else:
		var c: Vector2i = _casilla_para_soltar()
		_dejar(objeto, Terreno3D.centro_de(c, Terreno3D.y_pies(c)) if c.x >= 0 else punto)
	ultimo = {"accion": "caida", "tipo": tipo, "punto": punto, "rompio": rompe}


# ---------------------------------------------------------------------------------------------------------------------
#  Cada fotograma
# ---------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	# los objetos en el aire siguen su camino aunque la jugadora ya haya vuelto a andar
	var i: int = 0
	while i < _vuelos.size():
		if _volar(_vuelos[i] as Dictionary, delta):
			_vuelos.remove_at(i)
		else:
			i += 1
	if estado == Estado.LIBRE:
		if _desvanece > 0.0:
			_desvanece = maxf(0.0, _desvanece - delta)
			if _brazos != null and is_instance_valid(_brazos):
				_brazos.influence = _peso_salida * _desvanece / T_PESO_GOLPE
		return
	if estado != Estado.LANZANDO and (objeto == null or not is_instance_valid(objeto)):
		estado = Estado.LIBRE
		_limpiar()
		return
	if (jugador.nadando or jugador.muerto) and estado != Estado.LANZANDO:
		_al_morir()
		return
	_t += delta
	match estado:
		Estado.COGIENDO:
			_fase_coger()
		Estado.CARGANDO:
			_poner_pose("alzado", "alzado", 0.0, 1.0, 1.0)
			_colocar_objeto()
		Estado.ANTICIPANDO:
			var k: float = clampf(_t / _t_anticipar, 0.0, 1.0)
			_poner_pose("alzado", "atras", k, 1.0, 1.0)
			_colocar_objeto()
			if _t >= _t_anticipar:
				_soltar_al_aire()
				estado = Estado.LANZANDO
				_t = 0.0
		Estado.LANZANDO:
			var kk: float = clampf(_t / 0.09, 0.0, 1.0)
			var peso: float = clampf((_t_remate - _t) / T_REMATE_PESO, 0.0, 1.0)
			_poner_pose("atras", "adelante", kk, peso, 0.0)
			if _t >= _t_remate:
				estado = Estado.LIBRE
				_poner_pose("adelante", "adelante", 0.0, 0.0, 0.0)
		Estado.SOLTANDO:
			_fase_soltar()


func _fase_coger() -> void:
	var fondo: float = _t_fondo
	# el objeto se acerca a las manos mientras se agacha y desde el fondo las sigue
	var kk: float = smoothstep(0.0, 1.0, clampf((_t - fondo * 0.45) / (fondo * 0.55), 0.0, 1.0))
	var peso: float = clampf((_t - fondo * 0.8) / maxf(_t_total - fondo * 0.8, 0.05), 0.0, 1.0)
	var k_pose: float = clampf((_t - fondo) / maxf(_t_total - fondo, 0.05), 0.0, 1.0)
	_poner_pose("bajo", "alzado", k_pose, peso, k_pose)
	_k_coger = kk
	_colocar_objeto()
	if _t >= fondo and not _agarrado:
		_agarrado = true
		ultimo = {"accion": "coger", "tipo": tipo, "t_fondo": snappedf(_t, 0.001)}
	if pequeno and _t >= _t_suelta and objeto != null:
		# objeto ligero: sale de la mano derecha en el instante medido del clip `coger_lanzar`, hacia donde mira, y la jugadora acaba el gesto (remate)
		_soltar_al_aire()
		ultimo["t_suelta"] = snappedf(_t, 0.001)
		estado = Estado.LANZANDO
		_t_remate = maxf(_t_total - _t_suelta, 0.05)
		_t = 0.0
		return
	if _t >= _t_total and not jugador.en_gesto():
		estado = Estado.CARGANDO
		_t = 0.0
		cogido.emit(tipo)
		PlayLog.event("cogible_cargando", {"tipo": tipo})


func _fase_soltar() -> void:
	var k: float = clampf(_t / _t_soltar, 0.0, 1.0)
	_poner_pose("alzado", "bajo", smoothstep(0.0, 1.0, k), 1.0 if k < 0.7 else clampf((1.0 - k) / 0.3, 0.0, 1.0), 1.0 - k)
	_colocar_objeto()
	if _t >= _t_soltar:
		_dejar(objeto, _pos_soltar)
		ultimo = {"accion": "soltar", "tipo": tipo, "punto": _pos_soltar, "celda": Terreno3D.celda_de(_pos_soltar)}
		soltado.emit(tipo, _pos_soltar)
		PlayLog.event("cogible_soltar", {"tipo": tipo})
		if _brazos != null:
			_brazos.influence = 0.0
		_limpiar()
		if usa_clips and _t_remate > 0.01:
			estado = Estado.LANZANDO               # el objeto ya está en el suelo: lo que queda del clip `dejar_objeto` (se levanta) es el remate, quieta
			_t = 0.0
		else:
			estado = Estado.LIBRE


## Pone el objeto donde toca según la fase. Se llama cada fotograma Y cada vez que el esqueleto se actualiza (`skeleton_updated`): solo ahí valen las posiciones de los huesos con las capas
## puestas (fuera de esa señal `get_bone_global_pose` devuelve la pose de la animación sin modificar).
func _colocar_objeto() -> void:
	if objeto == null or not is_instance_valid(objeto):
		return
	match estado:
		Estado.COGIENDO:
			_f_cabeza = clampf((_t - _t_fondo) / maxf(_t_total - _t_fondo, 0.05), 0.0, 1.0)
			if pequeno:
				objeto.global_position = _origen.lerp(_base_en_mano_derecha(), _k_coger)     # un objeto ligero va en la mano derecha, no entre las dos
			else:
				objeto.global_position = _origen.lerp(_base_en_manos(), _k_coger)
			objeto.scale = Vector3.ONE * lerpf(1.0, _escala(), _k_coger)
		Estado.CARGANDO, Estado.ANTICIPANDO:
			# Con el clip de lanzar el objeto baja de la coronilla a las manos según se echan atrás y salen al frente (suelta = solo las manos); sin él, sigue sobre la cabeza.
			_f_cabeza = 1.0 - clampf(_t / _t_anticipar, 0.0, 1.0) if (usa_clips and estado == Estado.ANTICIPANDO) else 1.0
			objeto.global_position = _base_en_manos()
			objeto.scale = Vector3.ONE * _escala()
		Estado.SOLTANDO:
			var k: float = clampf(_t / _t_soltar, 0.0, 1.0)
			var arco: float = 0.25 * 4.0 * k * (1.0 - k)
			_f_cabeza = 1.0 - k
			objeto.global_position = _base_en_manos().lerp(_pos_soltar, smoothstep(0.0, 1.0, k)) + Vector3(0, arco, 0)
			objeto.scale = Vector3.ONE * lerpf(_escala(), 1.0, k)


func _escala() -> float:
	return float(datos.get("escala", 1.0))


func _al_actualizar_esqueleto() -> void:
	if _sk == null or not is_instance_valid(_sk) or _hueso_izq < 0 or _hueso_der < 0:
		return
	mano_izq = _sk.global_transform * _sk.get_bone_global_pose(_hueso_izq).origin
	mano_der = _sk.global_transform * _sk.get_bone_global_pose(_hueso_der).origin
	if _hueso_cabeza >= 0:
		cabeza_top = _sk.global_transform * _sk.get_bone_global_pose(_hueso_cabeza).origin
	_tengo_manos = true
	if estado != Estado.LIBRE:
		_colocar_objeto()


## Dónde queda la BASE del objeto para que su centro quede sobre el punto medio de las manos (huesos de las manos de la jugadora).
func _base_en_manos() -> Vector3:
	if _sk == null or not is_instance_valid(_sk):
		_enganchar_esqueleto()
	if not _tengo_manos:
		return jugador.position + Vector3(0, 1.5, 0)
	# La jugadora es chibi: con los brazos todo lo arriba que llegan las manos quedan a 0,86 u y la cabeza acaba en 0,98 u, así que el objeto NO puede quedar de verdad encima de ellas.
	# Se coloca con la base un poco por debajo de la coronilla (`HUNDE_EN_CABEZA`) y a medio camino, en el plano, entre las manos y el eje de la cabeza; nunca por debajo de las manos.
	var medio: Vector3 = (mano_izq + mano_der) * 0.5
	if _hueso_cabeza < 0:
		return medio + Vector3(0.0, 0.03, 0.0)
	var f: float = _f_cabeza
	var base: Vector3 = medio.lerp(cabeza_top, EN_EJE_CABEZA * f)
	base.y = lerpf(medio.y + 0.03, maxf(medio.y + 0.03, cabeza_top.y - HUNDE_EN_CABEZA), f)
	return base


## La BASE de un objeto ligero para que su centro quede en la mano derecha (el clip `coger_lanzar` lo coge y lo lanza con ella).
func _base_en_mano_derecha() -> Vector3:
	if _sk == null or not is_instance_valid(_sk):
		_enganchar_esqueleto()
	if not _tengo_manos:
		return jugador.position + Vector3(0, 0.5, 0)
	return mano_der - Vector3(0.0, float(datos.get("alto", 0.3)) * _escala() * 0.5, 0.0)


func _enganchar_esqueleto() -> void:
	var pj: Pj3D = jugador.pj
	_sk = pj._esqueleto()
	if _sk == null:
		return
	_hueso_izq = Equipo3D._hueso(_sk, "LeftHand")
	_hueso_der = Equipo3D._hueso(_sk, "RightHand")
	_hueso_cabeza = Equipo3D._hueso(_sk, "HeadTop_End")
	if not _sk.skeleton_updated.is_connected(_al_actualizar_esqueleto):
		_sk.skeleton_updated.connect(_al_actualizar_esqueleto)


func _asegurar_capa() -> void:
	if _brazos != null and is_instance_valid(_brazos):
		return
	if _sk == null or not is_instance_valid(_sk):
		_enganchar_esqueleto()
	if _sk == null:
		return
	var b := BrazosCarga3D.new()
	b.name = "BrazosCarga"
	b.influence = 0.0
	_sk.add_child(b)
	if b.preparar():
		_brazos = b
	else:
		b.queue_free()


func _poner_pose(a: String, b: String, k: float, peso: float, inclina: float) -> void:
	if usa_clips or pequeno:
		return                       # con los clips de Meshy la pose es la del clip: la capa procedural solo es el respaldo
	if _brazos != null and is_instance_valid(_brazos):
		_brazos.poner(a, b, k, peso, inclina)


func _limpiar() -> void:
	objeto = null
	tipo = ""
	datos = {}


func _avisar(texto: String) -> void:
	if jugador != null and jugador.lanz != null:
		jugador.lanz.avisar(texto, Color(1, 0.8, 0.6))

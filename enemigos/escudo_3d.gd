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
const VIDA_ESCUDO: float = 60.0               ## daño que aguanta (los golpes no ardientes lo desgastan; al llegar a 0 se rompe)
const T_CONSUMO: float = 3.0                  ## s que tarda en consumirse una vez prendido (la quemadura de la runa de fuego dura lo mismo)
const T_MOJADO: float = 6.0                   ## s que un escudo mojado no prende
## MANO QUEMADA (21/10, Pablo tras el playtest): cuando el escudo termina de arder, al goblin le quema la mano: lo suelta, se queda aturdido T_MANO_QUEMADA s
## con el clip ROL_MANO_QUEMADA (si su GLB lo trae; si no, el de golpe) y el escudo se DESINTEGRA en T_DESINTEGRA s en vez de quedarse quemado en el brazo.
## El goblin NO se prende por su propio escudo. El clip es del Pipeline (diario); el disolver por celdas es V6 (`Ocluso3D`, uniform `disolver`): la malla quemada se deshace en T_DESINTEGRA s. Con
## `Ocluso3D.usar_quemado_disolver = false` (o sin material común) vuelve a encoger hasta desaparecer, como antes.
const T_MANO_QUEMADA: float = 1.2
const T_DESINTEGRA: float = 0.8
const ROL_MANO_QUEMADA: String = "mano_quemada"
const DISTANCIA_MANO: float = 0.42            ## u por delante del centro del cuerpo
const ALTURA_RELATIVA: float = 0.55           ## a qué fracción de la altura del goblin va el centro del disco
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
var _mats_quemado: Array[ShaderMaterial] = []  ## V6: materiales comunes de la malla quemada (su uniform `disolver` hace la desintegración)
var disolver: float = 0.0                      ## V6: 0..1, cuánto lleva deshecho (lo lee la prueba; 0 si no se usa el disolver)


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
	c.add_child(e)
	e._colocar()
	return e


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
	if hechizo == null or not esta_activo() or not es_de_frente(direccion):
		return false
	_recibir(hechizo)
	return true


## El contrato de los reactivos, para quien golpee al escudo directamente (sin pasar por el cono): el golpe es del escudo, no del goblin.
func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	var h: Hechizo = hechizo if hechizo != null else (Hechizo.construir(rune_data, {}) if rune_data != null else null)
	if h != null and (estado == "entero" or estado == "ardiendo"):
		_recibir(h)


func _recibir(h: Hechizo) -> void:
	bloqueos += 1
	_avisar("bloqueado")
	bloqueado.emit(_pos_mundo())
	match h.elemento:
		"fuego":
			if mojado_t > 0.0:
				mojado_t = 0.0                           # fuego sobre mojado = vapor: lo seca y no prende (como el goblin)
				_avisar("secado")
			else:
				prender()
		"agua":
			if tiene_papel(PAPEL_INFLAMABLE) and mojado_t <= 0.0:
				_avisar("mojado")
			mojado_t = T_MOJADO
			apagar()
		"hielo":
			apagar()
		_:
			_desgastar(h.dano)
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
	_avisar("prendido")
	return true


## Lo apaga el agua o el hielo. Devuelve si estaba ardiendo.
func apagar() -> bool:
	if estado != "ardiendo":
		return false
	estado = "entero"
	arde_t = 0.0
	if _entero != null:
		_entero.poner_estado("entero")
	_avisar("apagado_agua")
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
	if _entero != null:
		_entero.visible = false
	if _quemado != null:
		_quemado.visible = causa == "quemado"
		_escala_quemado = _quemado.scale
	if causa == "quemado":
		desintegra_t = T_DESINTEGRA
		_quemar_mano()
	_avisar("consumido")
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
		if arde_t <= 0.0:
			_consumir("quemado")


const HUESOS_BRAZO: PackedStringArray = ["mixamorig_LeftForeArm", "mixamorig_RightForeArm", "mixamorig_LeftHand", "mixamorig_RightHand"]


## Lo pone delante del cuerpo, mirando hacia donde mira el goblin (el frente de la pieza es +Z).
func _colocar() -> void:
	if combate == null:
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


func _pos_mundo() -> Vector3:
	return global_position if is_inside_tree() else position


func _avisar(nombre: String) -> void:
	Mundo3D.avisar_reaccion(nombre, _pos_mundo(), self)

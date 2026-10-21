class_name Reactivo3D
extends Area3D

## OBJETOS DEL TEST 2 QUE REACCIONAN A UN HECHIZO EN 3D (tarea 4.7). Dueño: JUEGO (`objetos/` es del Juego, docs/PROPIETARIOS.md §1).
## El Pipeline solo lo COLOCA (PruebaTest2._reactivo: `preparar()` + `fx`/`celda`/`visual`) y pinta su visual; no decide cómo reacciona.
##
## 21/10 (A1 de docs/PLAN_EOW.md) · PAPELES. Lo que un objeto hace ante un hechizo ya no se decide por su `tipo` («es un seto») sino por
## sus PAPELES («puede arder», «propaga la llama»…): `PAPELES_POR_TIPO` da los de cada tipo y `papeles` (`@export`) los retoca por pieza con
## `+nombre` / `-nombre` (una variante = una diferencia de papeles: un seto con `-inflamable` no prende; una telaraña con `+mojable` se moja).
## `COMBUSTIBLES` y `FUENTES` guardan solo NÚMEROS (segundos, escala…). El MONTAJE visual y la geometría (`_ready`, `_alto_cuerpo`,
## `punto_activacion`, `nivel_altura`) siguen por `tipo`: dependen del modelo, no de lo que reacciona. Vocabulario y significado: ver PAPELES.
##
## 21/10 (A2 de docs/PLAN_EOW.md) · EL FUEGO PASA POR CONTACTO. Regla de Pablo: el fuego solo pasa de algo que ESTÁ ARDIENDO a algo INFLAMABLE
## que lo TOCA; no hay radio de calor. Dos formas de «tocar», las dos documentadas aquí:
##   · CUERPOS (enemigos y flechas): `toca_punto(p, radio)` mira si el punto está dentro de la caja de este objeto (+ el radio de quien toca).
##     Lo usa `Combate3D` (un goblin ardiendo prende lo que pisa; lo que arde le prende a él; la flecha sale ardiendo si cruza una llama).
##     `emite_fuego_por_contacto()` dice si este objeto, ahora, pasa la llama a lo que lo toca.
##   · REJILLA (objetos entre sí): `_contagiar` (≤ 1,7 casillas cada 0,8 s) NO es un radio de calor: es el «vecino de rejilla». Las cajas de dos
##     piezas de casillas distintas nunca se solapan (caja ≈ 0,9 casillas, hueco de 0,1 entre vecinas), así que el contacto entre piezas es,
##     en la práctica, ser vecino de casilla (alcance de 1,7 casillas = vecinas y diagonales). Se queda como está; solo cambia cómo se llama.
## Mojado sigue bloqueando en las dos formas (`can_burn` / `esta_mojado`).
##
## Un solo nodo con varios `tipo`, que implementa el contrato on_spell_hit de Lanzador3D (diario, 2026-10-06 00:50):
## es un Area3D en la capa CAPA_REACTIVO, decide por `rune_data.tags` y trae `spell_reacts`, `carried_element` y
## `nivel_altura`. Las reglas son las del 2D (combustible.gd, fogata.gd, nivel_base.gd: Interruptor, PlacaPeso, puente)
## y las de docs/ESTADOS_SUELO.md §1.6. Los estados se ven por MATERIAL (tinte, emisión, escala), no por PNG.
##
##   seto · tronco · telarana   arden: calor o rayo prenden → CHAMUSCADO (se oscurece) → desaparecen con su cuerpo; agua o
##                              frío los apagan (vuelven a estar sanos); contagian a ≤ 1,7 casillas cada 0,8 s y el viento,
##                              en su cono, a ≤ 3,6. Seto, tronco y telaraña son muro hasta que se queman.
##   totem (fuego|agua|rayo)    se activa con SU elemento (calor · agua · rayo/eléctrico) y se queda: brilla, suelta motas.
##   fogata · brasero           fuego de mapa: calor lo enciende, agua o frío lo apagan; si arde, el viento se lleva la llama.
##                              El brasero es la "antorcha" del Test 2 (empieza apagado); la fogata, empieza encendida.
##   puente                     plegado (levantado, la casilla bloquea) hasta `tender()`, que lo baja. No oye hechizos:
##                              lo tiende el tótem de rayo.
##   placa                      se hunde y se queda cuando algo con peso la pisa (nodo del grupo GRUPO_PESO: bloque de
##                              tierra del Lanzador o empujable). El jugador no pesa.
##   emisor_rayo                9.7 · fuente eléctrica del Bosque 1 (letra `e`): cristal con chispas y destellos PERMANENTES.
##                              No oye hechizos; la corriente por el agua la mete el Juego (emisor_rayo_3d.gd, 9.10).
##   puerta_goblin · torre_goblin  10/10 · madera del campamento goblin (letras `y` y `o`): arden como un seto grande y se
##                              consumen (la puerta deja libre el paso). Nacen con la pieza de su mismo nombre.
##   surtidor                   9.7 · fuente de piedra (letra `u`): con agua echa un chorro, se llena su pila y emite
##                              `activado("surtidor", "agua")` (cada vez). Llenar el cauce es cosa del Juego (9.11).
##                              Con la pieza `tinaja_ruina` (10/10) es una TINAJA con cuatro estados: vacía → llenándose
##                              (T_LLENADO s, sube el agua dentro) → inclinándose (T_INCLINA s, de INCLINA_DESDE° a INCLINA_HASTA°)
##                              → vertiendo (chorro por el pico, gotas y arroyo hacia +Z local hasta la casilla de
##                              delante). Emite `activado` AL EMPEZAR a verter, una sola vez; se queda vertiendo.
##
## Quien lo coloca (PruebaTest2._reactivo) pone antes `fx`, `celda` y `visual`, y conecta `consumido` para liberar la casilla.

signal consumido(celda: Vector2i)
## tipo, elemento ("" si no aplica): tótem activado, fuente encendida/apagada, puente tendido, placa pisada.
signal activado(tipo: String, elemento: String)
## Solo la tinaja: el arroyo ha llegado al canal (T_CAUDAL s después de empezar a caer el agua). Es la señal para llenar el canal:
## llenarlo con `activado` (que sale al empezar a verter) lo haría arrancar antes de que el agua lo alcance.
signal agua_llega
## 16/10 (Fase 14.6, laboratorio de fuego): la llama de una fogata o un brasero se enciende (true) o se apaga (false). `activado` ya dice
## lo mismo pero con dos textos; esta es la que escucha Puzle3D (`brasero.encendido` / `brasero.apagado`).
signal llama(encendida: bool)

const GRUPO_ARDE: String = "flammable3d"
const GRUPO_REACTIVO: String = "reactivo3d"
const GRUPO_PESO: String = "peso"          ## lo que pesa lo tiene que poner el Juego (bloque de tierra) y el empujable
const S: float = 2.3                       ## lado de una casilla (el de PruebaTest2.S)

const CONTAGIO: float = 1.7 * S            ## 110 px del 2D
const CONTAGIO_VIENTO: float = 3.6 * S     ## 230 px
const PUNTO_VIENTO: float = 0.3
const INTERVALO_CONTAGIO: float = 0.8
const FUNDIDO: float = 0.6
const CHAMUSCADO: Color = Color(0.3, 0.25, 0.22)
const APAGADO: Color = Color(0.72, 0.7, 0.72)          ## la pira apagada del 2D
const COLOR_ELEMENTO: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "rayo": Color(1.0, 0.92, 0.4),
}

## tipo -> [segundos ardiendo, escala de las llamas, medio lado de la zona que arde (u), alto del cuerpo (u)]
const COMBUSTIBLES: Dictionary = {
	"seto": [3.5, 1.0, 0.8, 1.3], "tronco": [4.0, 0.8, 0.8, 0.7], "telarana": [1.6, 0.8, 0.7, 2.0],
	# 10/10 (campamento goblin): la madera de la puerta y de la torre. Más tiempo que un seto (son grandes) y llamas más grandes.
	"puerta_goblin": [5.0, 1.3, 1.4, 1.8], "torre_goblin": [7.0, 1.5, 1.0, 3.2],
}
## Cuerpo ancho (u) de lo que no cabe en una casilla: la zona donde le acierta un hechizo. Lo demás: 0,9 casillas.
const ANCHO_CUERPO: Dictionary = {"puerta_goblin": S * 1.6, "surtidor": S * 1.0}      # 11/10: la tinaja era 1,5 S (demasiado grande)
## Fondo (u) del cuerpo cuando no es 0,9 casillas. La tinaja es un cuerpo grande: su zona envuelve la panza, la boca y el pedestal
## aunque se incline, para que el hechizo le acierte donde se ve.
const FONDO_CUERPO: Dictionary = {"surtidor": S * 1.0}
## tipo -> [alto de las llamas sobre el suelo (u), escala de las llamas, radio de la zona que arde, alto del cuerpo]
const FUENTES: Dictionary = {
	"fogata": [0.1, 0.8, 0.25, 0.6], "brasero": [1.25, 0.65, 0.12, 1.4],
}
const ALTO_TOTEM: float = 1.8
## Números que se usan cuando una pieza gana `+inflamable` / `+fuente_fuego` sin tener fila propia arriba (los del seto y los de la fogata):
## así dar un papel a una pieza nueva no revienta con una clave que falta.
const COMBUSTIBLE_BASE: Array = [3.5, 1.0, 0.8, 1.3]
const FUENTE_BASE: Array = [0.1, 0.8, 0.25, 0.6]

## --- PAPELES (21/10, A1 del plan EoW) ---
## Por qué: antes cada decisión era «¿es un seto? ¿es una fogata?» (`COMBUSTIBLES.has(tipo)`, `match tipo`). Para que una variante (un seto que no
## arde, una telaraña que se moja) no pida tocar el código, cada objeto lleva una lista de PAPELES y el código pregunta por el papel, no por el
## tipo. Lo que MIRA el código con cada uno (no lo que «parece»):
const P_INFLAMABLE: String = "inflamable"          ## calor o rayo lo prenden; arde COMBUSTIBLES[tipo][0] s, se chamusca y se consume. Mojado no prende.
const P_PROPAGA_LLAMA: String = "propaga_llama"    ## mientras arde contagia a lo inflamable de ≤ 1,7 casillas y el viento lleva su llama (≤ 3,6, en su cono)
const P_APAGA: String = "apaga"                    ## el agua o el frío APAGAN su llama (arde → sano). Es el nombre del plan: léase «se deja apagar»
const P_MOJABLE: String = "mojable"                ## el agua lo MOJA estando sano y no prende durante T_MOJADO s (el cortafuegos); por defecto nadie lo tiene
const P_PESADO: String = "pesado"                  ## cuenta como peso para las placas: entra en el grupo GRUPO_PESO
const P_CONDUCE: String = "conduce"                ## lleva la corriente (el cristal emisor). Solo se declara: aún no lo lee nada (lo usarán A2–A4)
const P_CONGELABLE: String = "congelable"          ## el frío lo congela. Solo se declara: aún no lo lee nada (lo usará A3: agua helada)
## Tres papeles MÁS que el plan no nombra pero sin los cuales seguiría un `match tipo` en pie (Pablo lo dirá si prefiere otros nombres):
const P_FUENTE_FUEGO: String = "fuente_fuego"      ## fuego de mapa (fogata, brasero): el calor lo ENCIENDE, no se consume (FUENTES da los números); el rayo no lo toca
const P_ACTIVABLE: String = "activable"            ## se activa UNA vez con su `elemento` (tótem: calor · agua · rayo) y se queda
const P_RECIBE_AGUA: String = "recibe_agua"        ## el agua lo llena y brota (surtidor, tinaja)
const PAPELES_VALIDOS: Array = [
	P_INFLAMABLE, P_PROPAGA_LLAMA, P_APAGA, P_MOJABLE, P_PESADO, P_CONDUCE, P_CONGELABLE, P_FUENTE_FUEGO, P_ACTIVABLE, P_RECIBE_AGUA,
]
## tipo -> papeles de serie. `mojable` no está en ninguno: sin pedirlo, el agua no le hace nada a la leña sana (diario 100). Seto, tronco, telaraña,
## puerta y torre de madera comparten papeles: lo que cambia entre ellos son solo los números de COMBUSTIBLES.
const PAPELES_POR_TIPO: Dictionary = {
	"seto": [P_INFLAMABLE, P_PROPAGA_LLAMA, P_APAGA],
	"tronco": [P_INFLAMABLE, P_PROPAGA_LLAMA, P_APAGA],
	"telarana": [P_INFLAMABLE, P_PROPAGA_LLAMA, P_APAGA],
	"puerta_goblin": [P_INFLAMABLE, P_PROPAGA_LLAMA, P_APAGA],
	"torre_goblin": [P_INFLAMABLE, P_PROPAGA_LLAMA, P_APAGA],
	"fogata": [P_FUENTE_FUEGO, P_APAGA],
	"brasero": [P_FUENTE_FUEGO, P_APAGA],
	"totem": [P_ACTIVABLE],
	"surtidor": [P_RECIBE_AGUA],
	"emisor_rayo": [P_CONDUCE],
	"puente": [],
	"placa": [],
}

enum EstadoObj { SANO, ARDIENDO, CONSUMIDO }

var tipo: String = ""
var elemento: String = ""
var celda: Vector2i = Vector2i.ZERO
var fx: Vfx3D = null
var visual: Node3D = null
var start_lit: bool = false          ## fogata: nace encendida
## Lo que el nivel hace para que el fuego de un objeto prenda la hierba: (posicion: Vector3, radio: float, viento: Vector3).
var hierba_cerca: Callable = Callable()

var estado: EstadoObj = EstadoObj.SANO
var is_lit: bool = false             ## arde (igual que en el 2D: el hielo y el viento lo miran)
var activo: bool = false             ## tótem activado
var usado: bool = false              ## placa pisada / puente tendido

## --- 16/10 (Fase 14.6) · BRASERO CON RELÉ ---
## Un brasero con relé, al encenderse, cuenta: a los `T_RELE_ESPERA` s enciende al siguiente de la fila (`rele_siguiente`) y a los
## `T_RELE_DURA` s se apaga solo. El siguiente hace lo mismo con el suyo, así que la llama «corre» por la fila y va dejando atrás
## braseros apagados. Sin `configurar_rele` el brasero es el de siempre (no se apaga solo y no contagia).
const T_RELE_ESPERA: float = 1.5
const T_RELE_DURA: float = 6.0
var rele_activo: bool = false
var rele_siguiente: Reactivo3D = null
var rele_espera: float = T_RELE_ESPERA
var rele_dura: float = T_RELE_DURA
var _t_rele: float = 0.0
var _rele_contagiado: bool = false

## --- 16/10 (Fase 14.6) · LEÑA MOJABLE (el cortafuegos) ---
## El contagio (1,7 casillas cada 0,8 s) corre más que la combustión (3,5 s), así que un hueco quemado no frena un incendio: el único
## cortafuegos posible es no dar combustible. Con `mojable = true` el agua MOJA un seto/tronco sano y no prende durante T_MOJADO s
## (como la hierba mojada de la maqueta, que dura 8). Por defecto es false: sin pedirlo, el agua sigue sin hacerle nada a la leña sana.
## Por qué 12 s y no los 8 de la hierba: medido en F4, un seto vecino sigue ardiendo y contagiando cada 0,8 s durante 3,5 s (más lo que tarde en
## prender él); con 8 s el seto mojado se secaba a mitad del incendio y prendía igual.
const T_MOJADO: float = 12.0
## 21/10 (A1): `mojable` ya no es una variable suelta sino el papel `mojable`. Se mantiene como propiedad para no tocar a quien la pone
## (Puzle3D: `seto … mojable=si`): leer = ¿tiene el papel?; escribir = añadir `+mojable` / `-mojable` a `papeles`.
var mojable: bool:
	get:
		return tiene_papel(P_MOJABLE)
	set(v):
		_fijar_papel(P_MOJABLE, v)
var _mojado_s: float = 0.0           ## s que le quedan empapado (se cuenta con el delta del juego, no con el reloj de pared)

var _mats: Array = []              ## [material copiado (StandardMaterial3D o el ShaderMaterial de Ocluso3D), Color original]
var _sprites: Array = []             ## [SpriteBase3D, Color original]
var _llama: Node3D = null
var _snd_fuego: AudioStreamPlayer3D = null   ## el crepitar en bucle mientras arde / está encendido (Sfx3D); se apaga con la llama
var _luz: OmniLight3D = null
var _t: float = 0.0
var _t_contagio: float = 0.0
var _k: float = 0.0                  ## 0 sano … 1 chamuscado
var _tween: Tween = null
var _disco: MeshInstance3D = null
var _motas: Node3D = null
var _plegado: bool = true
var _forma_cuerpo: CollisionShape3D = null   ## la caja de acierto (la crea `_ready`); A2 la usa para saber qué cuerpos lo tocan


## Se llama una vez, con `visual` ya hijo (o sin él), antes de añadirlo al árbol.
func preparar(p_tipo: String, p_celda: Vector2i, p_elemento: String, p_fx: Vfx3D, p_visual: Node3D) -> void:
	tipo = p_tipo
	celda = p_celda
	elemento = p_elemento
	fx = p_fx
	visual = p_visual


## --- Papeles: consulta ---

## Retoques de ESTA pieza sobre los papeles de su tipo: `+nombre` añade, `-nombre` quita (sin signo = añade). Se aplican en orden, así que el
## último gana. Ej.: `["-inflamable"]` = seto que no prende · `["+mojable"]` = telaraña que se moja · `["+pesado"]` = pieza que aplasta placas.
## Un nombre que no está en PAPELES_VALIDOS se avisa y se ignora (una errata no debe pasar por buena en silencio).
@export var papeles: PackedStringArray = PackedStringArray():
	set(v):
		papeles = v
		_papeles_vale = false

var _papeles_ok: Dictionary = {}          ## papel -> true: los EFECTIVOS (tipo + retoques); se recalculan si cambia `papeles` o `tipo`
var _papeles_tipo: String = ""            ## el tipo para el que se calcularon (el Pipeline pone `tipo` en `preparar`, que va después del `new()`)
var _papeles_vale: bool = false


## ¿Tiene este papel? Es lo que el código pregunta en vez de «¿es de tal tipo?».
func tiene_papel(papel: String) -> bool:
	if not _papeles_vale or _papeles_tipo != tipo:
		_recalcular_papeles()
	return _papeles_ok.has(papel)


## Los papeles efectivos, ordenados (para pruebas y para ver qué es una pieza).
func papeles_efectivos() -> PackedStringArray:
	if not _papeles_vale or _papeles_tipo != tipo:
		_recalcular_papeles()
	var res := PackedStringArray()
	for k in _papeles_ok.keys():
		res.append(String(k))
	res.sort()
	return res


func _recalcular_papeles() -> void:
	_papeles_ok.clear()
	_papeles_tipo = tipo
	_papeles_vale = true
	for p in (PAPELES_POR_TIPO.get(tipo, []) as Array):
		_papeles_ok[String(p)] = true
	for t in papeles:
		var ficha: String = t.strip_edges()
		var signo: String = ficha.substr(0, 1)
		var nombre: String = ficha.substr(1).strip_edges() if (signo == "+" or signo == "-") else ficha
		if not PAPELES_VALIDOS.has(nombre):
			push_warning("Reactivo3D «%s»: papel desconocido «%s» (válidos: %s)" % [tipo, ficha, ", ".join(PAPELES_VALIDOS)])
			continue
		if signo == "-":
			_papeles_ok.erase(nombre)
		else:
			_papeles_ok[nombre] = true


## Deja `papel` puesto (`si`) o quitado en esta pieza: borra sus retoques anteriores y añade uno solo si hace falta (si ya es de serie, ninguno).
func _fijar_papel(papel: String, si: bool) -> void:
	var nuevos := PackedStringArray()
	for t in papeles:
		var f: String = t.strip_edges()
		if (f.substr(1).strip_edges() if (f.begins_with("+") or f.begins_with("-")) else f) != papel:
			nuevos.append(t)
	var de_serie: bool = (PAPELES_POR_TIPO.get(tipo, []) as Array).has(papel)
	if si != de_serie:
		nuevos.append(("+" if si else "-") + papel)
	papeles = nuevos            # pasa por el setter: invalida la caché


## Los números del combustible / de la fuente de ESTE objeto (sin fila propia: los de seto / fogata).
func _num_combustible() -> Array:
	return COMBUSTIBLES.get(tipo, COMBUSTIBLE_BASE) as Array


func _num_fuente() -> Array:
	return FUENTES.get(tipo, FUENTE_BASE) as Array


func _ready() -> void:
	add_to_group(GRUPO_REACTIVO)
	var reacciona: bool = tipo != "puente"
	collision_layer = Lanzador3D.CAPA_REACTIVO if reacciona else 0
	collision_mask = 0xFFFFF if tipo == "placa" else 0
	monitoring = tipo == "placa"
	monitorable = reacciona
	var alto: float = _alto_cuerpo()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(float(ANCHO_CUERPO.get(tipo, S * (0.7 if tipo == "placa" else 0.9))), alto, float(FONDO_CUERPO.get(tipo, S * (0.7 if tipo == "placa" else 0.9))))
	forma.shape = caja
	forma.position = Vector3(S * 0.5 if tipo == "puente" else 0.0, alto * 0.5, 0.0)
	_ajustar_cuerpo(caja, forma)
	if tipo == "emisor_rayo":          # el cristal: `tipo` del Reactivo es «emisor_rayo»; «roca_cristal» es el tipo del marcador, no este
		forma.position += Vector3(0.0, 0.0, 0.0)      # después de _ajustar_cuerpo, que recoloca la caja y se comería el desvío
	add_child(forma)
	_forma_cuerpo = forma                       # A2: `toca_punto` mide contra esta caja
	_recoger_materiales()
	if tiene_papel(P_INFLAMABLE):
		add_to_group(GRUPO_ARDE)
	if tiene_papel(P_PESADO):
		add_to_group(GRUPO_PESO)            # lo que pesa lo detectan las placas (antes solo el bloque de tierra y el empujable)
	if tiene_papel(P_FUENTE_FUEGO):
		_montar_fuente()
	match tipo:                              # el montaje visual sigue por tipo: depende del modelo, no de cómo reacciona
		"totem":
			_montar_totem()
		"puente":
			rotation.z = deg_to_rad(80.0)       # plegado: levantado contra la orilla
		"placa":
			_pintar_emision(Color(0.5, 0.9, 0.6), 0.0)
		"emisor_rayo":
			_montar_emisor()
		"surtidor":
			_montar_surtidor()
	set_process(false)
	set_physics_process(tipo == "placa")


func _alto_cuerpo() -> float:
	if COMBUSTIBLES.has(tipo):
		return float((COMBUSTIBLES[tipo] as Array)[3])
	if FUENTES.has(tipo):
		return float((FUENTES[tipo] as Array)[3])
	match tipo:
		"totem":
			return ALTO_TOTEM
		"placa":
			return 0.3
		"puente":
			return 0.3
		"emisor_rayo":
			return 1.4
		"surtidor":
			return 2.0       # la tinaja mide 1,5 y su boca sube al inclinarse
	return 1.0


## 11/10 (Pablo): las cajas de acierto eran demasiado grandes (0,9 casillas para todo) y la de la telaraña no coincidía con la red.
## Ahora el cuerpo se ajusta a lo que se VE: el tamaño de la caja de los tipos de TIPOS_CUERPO_AJUSTADO es el de su visual (más
## MARGEN_CUERPO), sin pasar de lo que tenía ni bajar de MIN_CUERPO. La telaraña, además, usa el alto y el sitio exactos de la red.
## 20/10 (Pablo: «que las colisiones sean cercanas al modelo real y no a la cuadrícula»): ahora se ajustan TODOS los tipos salvo estos. La caja solo se
## ENCOGE (nunca pasa de lo que tenía): antes un barril de 0,8 u o una seta tenían una caja de acierto de 0,9 casillas (2,07 u).
##   · «placa»: la caja es el área que PISA el jugador (no el modelo, que es una lámina) · «puente»: va plegado y girado ·
##   · «surtidor»: su ANCHO_CUERPO/FONDO_CUERPO está medido a mano para que envuelva la tinaja aunque se incline.
const TIPOS_SIN_AJUSTE: Array = ["placa", "puente", "surtidor"]
const MARGEN_CUERPO: float = 0.1         ## cuánto sobresale el cuerpo de lo que se ve (u): que acertar no pida puntería de píxel
const MIN_CUERPO: float = 0.8            ## lado mínimo de la caja (u)
const PUNTO_BAJO_TECHO: float = 0.05     ## cuánto por debajo de lo más alto del visual queda el punto de activación (u)
const TIPOS_PUNTO_ALTO: Array = ["totem", "fogata", "brasero", "emisor_rayo"]


func _ajustar_cuerpo(caja: BoxShape3D, forma: CollisionShape3D) -> void:
	if TIPOS_SIN_AJUSTE.has(tipo):
		return
	var ab: AABB = _aabb_visual()
	if ab.size.x < 0.05 or ab.size.z < 0.05:
		return          # sin malla que medir (sprites…): se queda la caja de siempre
	var c: Vector3 = ab.get_center()
	if tipo == "telarana":
		# la red es una lámina: la caja la envuelve entera (alto y sitio exactos, sin el tope de una casilla)
		caja.size = Vector3(maxf(ab.size.x + MARGEN_CUERPO, MIN_CUERPO), ab.size.y + MARGEN_CUERPO, maxf(ab.size.z + MARGEN_CUERPO, MIN_CUERPO))
		forma.position = c
		return
	caja.size.x = clampf(ab.size.x + MARGEN_CUERPO, MIN_CUERPO, caja.size.x)
	caja.size.z = clampf(ab.size.z + MARGEN_CUERPO, MIN_CUERPO, caja.size.z)
	forma.position.x = c.x
	forma.position.z = c.z
	if TIPOS_PUNTO_ALTO.has(tipo):
		# La columna llega hasta el punto de activación (12/10): un disparo a cualquier altura por debajo lo acierta.
		caja.size.y = maxf(caja.size.y, ab.end.y + MARGEN_CUERPO * 0.5)
		forma.position.y = caja.size.y * 0.5


## Caja (en el espacio local del reactivo) de las mallas visibles del visual.
func _aabb_visual() -> AABB:
	var res := AABB()
	if visual == null:
		return res
	var hay: bool = false
	var pila: Array = [[visual, visual.transform]]
	while not pila.is_empty():
		var par: Array = pila.pop_back()
		var n: Node3D = par[0]
		var t: Transform3D = par[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var m: Mesh = (n as MeshInstance3D).mesh
			var ab: AABB = t * (m.get_meta("aabb_parte") as AABB if m.has_meta("aabb_parte") else m.get_aabb())
			res = ab if not hay else res.merge(ab)
			hay = true
		for h in n.get_children():
			if h is Node3D and (h as Node3D).visible:
				pila.append([h, t * (h as Node3D).transform])
	return res


## --- Contrato con los hechizos (Lanzador3D) ---

## 12/10 (Pablo): PUNTO DE ACTIVACIÓN, en coordenadas del mundo: donde el hechizo «toca» este objeto y la acción se dispara. Antorcha/brasero,
## fogata, tótem y cristal: la parte de arriba (el cuenco, la piedra); la tinaja: la boca; el resto: el centro del cuerpo. El Lanzador lo usa
## para colocar el impacto y la chispa. (La caja de acierto es una columna que llega hasta él: acierta cualquier disparo por debajo.)
func punto_activacion() -> Vector3:
	match tipo:
		"surtidor":
			if _pivote != null and is_instance_valid(_pivote):
				return _pivote.to_global(BOCA_CENTRO - PIVOTE_TINAJA)
		"totem", "fogata", "brasero", "emisor_rayo":
			var ab: AABB = _aabb_visual()
			if ab.size.y > 0.05:
				return to_global(Vector3(ab.get_center().x, ab.end.y - PUNTO_BAJO_TECHO, ab.get_center().z))
		"seto", "tronco", "telarana":
			# 13/10 (P2): la caja de acierto de estos se ajusta a lo que SE VE (centro del visual), así que la mano los toca ahí; antes el
			# punto era la mitad del alto «de diseño» (p. ej. 1,0 en la telaraña) y no coincidía con la red.
			var av: AABB = _aabb_visual()
			if av.size.y > 0.05:
				return to_global(av.get_center())
	return to_global(Vector3(0.0, _alto_cuerpo() * 0.5, 0.0))

func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data == null:
		return
	var calor: bool = rune_data.tags.has("calor")
	var rayo: bool = rune_data.tags.has("rayo") or rune_data.tags.has("electrico")
	var humedo: bool = rune_data.tags.has("agua") or rune_data.tags.has("frio")
	if tiene_papel(P_INFLAMABLE):
		if calor or rayo:
			ignite(Lanzador3D.ultimo_impacto)
		elif humedo and estado == EstadoObj.ARDIENDO and tiene_papel(P_APAGA):
			_apagar()
		elif tiene_papel(P_MOJABLE) and rune_data.tags.has("agua") and estado == EstadoObj.SANO:
			if _mojado_s <= 0.0:
				_reaccionar("mojado")                  # solo si estaba seco: regar lo ya mojado solo alarga el tiempo, no es un cambio
			_mojado_s = T_MOJADO
			PiezaFuego3D.mojado(visual, true)       # capa húmeda del Pipeline (diario 109); se quita al secarse, en `_process`
			set_process(true)
		elif rune_data.tags.has("viento") and estado == EstadoObj.ARDIENDO and tiene_papel(P_PROPAGA_LLAMA):
			_contagiar(CONTAGIO_VIENTO, direccion)
		return
	if tiene_papel(P_FUENTE_FUEGO):
		if calor and not is_lit:
			_encender(true)
		elif humedo and is_lit and tiene_papel(P_APAGA):
			_apagar_fuente()
		return
	if tiene_papel(P_ACTIVABLE):
		if not activo and _le_toca(rune_data):
			_activar_totem()
		return
	if tiene_papel(P_RECIBE_AGUA):
		if rune_data.tags.has("agua"):
			brotar()


## ¿Cambiaría algo este hechizo aquí? Si no, lo atraviesa.
func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null:
		return false
	var calor: bool = rune_data.tags.has("calor")
	var rayo: bool = rune_data.tags.has("rayo") or rune_data.tags.has("electrico")
	var humedo: bool = rune_data.tags.has("agua") or rune_data.tags.has("frio")
	if tiene_papel(P_INFLAMABLE):
		if calor or rayo:
			return estado == EstadoObj.SANO
		if tiene_papel(P_MOJABLE) and rune_data.tags.has("agua") and estado == EstadoObj.SANO:
			return not esta_mojado()
		var apaga: bool = humedo and tiene_papel(P_APAGA)
		var lleva: bool = rune_data.tags.has("viento") and tiene_papel(P_PROPAGA_LLAMA)
		return (apaga or lleva) and estado == EstadoObj.ARDIENDO
	if tiene_papel(P_FUENTE_FUEGO):
		if calor:
			return not is_lit
		return humedo and is_lit and tiene_papel(P_APAGA)
	if tiene_papel(P_ACTIVABLE):
		return not activo and _le_toca(rune_data)
	if tiene_papel(P_RECIBE_AGUA):
		return rune_data.tags.has("agua")
	return false


## Lo que el viento puede llevarse: una llama si arde.
func carried_element() -> RuneData:
	return _runa_fuego() if is_lit else null


## Niveles de alto que ocupa (0 = a ras): lo que choca con un proyectil normal tiene 1.
func nivel_altura() -> int:
	return 0 if (tipo == "fogata" or tipo == "puente" or tipo == "placa") else 1


static func _runa_fuego() -> RuneData:
	var r := RuneData.new()
	r.display_name = "Fuego"
	var t: Array[String] = ["fuego", "calor"]
	r.tags = t
	return r


func _le_toca(rune_data: RuneData) -> bool:
	match elemento:
		"fuego":
			return rune_data.tags.has("calor")
		"agua":
			return rune_data.tags.has("agua")
	return rune_data.tags.has("rayo") or rune_data.tags.has("electrico")


## --- Objetos que arden ---

func can_burn() -> bool:
	return tiene_papel(P_INFLAMABLE) and estado == EstadoObj.SANO and not esta_mojado()


## ¿Está empapado (leña mojable regada hace menos de T_MOJADO s)? Mojado no prende, ni por hechizo ni por contagio.
func esta_mojado() -> bool:
	return _mojado_s > 0.0


func ignite(_desde: Vector3 = Vector3.INF) -> void:
	if not can_burn():
		return
	estado = EstadoObj.ARDIENDO
	is_lit = true
	_reaccionar("prendido")
	_t = 0.0
	_t_contagio = 0.0
	var d: Array = _num_combustible()
	_llama = fx.llamas(global_position, float(d[1]), float(d[2]))
	_luz = _crear_luz(Color(1.0, 0.6, 0.3), 0.9, 3.0, Vector3(0.0, 0.8, 0.0))
	_snd_fuego = Sfx3D.ambiente(self, "fuego")
	_ver_ardiendo(true)
	_animar_k(1.0)
	set_process(true)
	if hierba_cerca.is_valid():
		hierba_cerca.call(global_position, CONTAGIO, Vector3.ZERO)


func _process(delta: float) -> void:
	if _mojado_s > 0.0:
		_mojado_s = maxf(0.0, _mojado_s - delta)
		if _mojado_s <= 0.0:
			PiezaFuego3D.mojado(visual, false)
			_reaccionar("secado")
	if rele_activo and is_lit:
		_avanzar_rele(delta)
	if estado != EstadoObj.ARDIENDO:
		if _mojado_s <= 0.0 and not (rele_activo and is_lit):
			set_process(false)
		return
	_t += delta
	_t_contagio += delta
	if _t_contagio >= INTERVALO_CONTAGIO:
		_t_contagio = 0.0
		_contagiar(CONTAGIO, Vector3.ZERO)
	if _t >= float(_num_combustible()[0]):
		_consumir()


## A4: avisa de una reacción con nombre (catálogo de Mundo3D.REACCIONES) en el centro de esta pieza. Qué se ve y suena lo decide el Pipeline.
func _reaccionar(nombre: String) -> void:
	var p: Vector3 = global_position if is_inside_tree() else position
	Mundo3D.avisar_reaccion(nombre, p + Vector3(0.0, 0.5, 0.0), self)


func _apagar() -> void:
	estado = EstadoObj.SANO
	is_lit = false
	_reaccionar("apagado_agua")             # solo lo apaga el agua o el frío (`humedo` en on_spell_hit); el viento no apaga, lleva la llama
	_quitar_fuego()
	_ver_ardiendo(false)
	_animar_k(0.0)
	fx.vapor(global_position + Vector3(0.0, 0.5, 0.0))
	set_process(false)


func _consumir() -> void:
	estado = EstadoObj.CONSUMIDO
	is_lit = false
	_reaccionar("consumido")
	_quitar_fuego()
	fx.ceniza(global_position)
	collision_layer = 0
	remove_from_group(GRUPO_ARDE)
	consumido.emit(celda)
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for s in _sprites:
		tw.tween_property(s[0], "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(queue_free)


## La telaraña de modelos (PruebaTest2._poner_telarana) trae dos hijas en `visual`: "sana" y "ardiendo" (la red con brasas).
## Sin ellas (la de Formas3D, otro combustible) no hace nada: basta el chamuscado del material.
func _ver_ardiendo(si: bool) -> void:
	if visual == null:
		return
	var sana: Node3D = visual.get_node_or_null("sana") as Node3D
	var ardiendo: Node3D = visual.get_node_or_null("ardiendo") as Node3D
	if sana == null or ardiendo == null:
		return
	sana.visible = not si
	ardiendo.visible = si


func _quitar_fuego() -> void:
	Sfx3D.parar(_snd_fuego)
	_snd_fuego = null
	if _llama != null and is_instance_valid(_llama):
		fx.apagar(_llama)
	_llama = null
	if _luz != null and is_instance_valid(_luz):
		_luz.queue_free()
	_luz = null


## ¿Está esto ardiendo ahora? Un inflamable en llamas o una fogata / un brasero encendidos (A2). Es el «está ardiendo» de la regla de Pablo.
func esta_ardiendo() -> bool:
	return estado == EstadoObj.ARDIENDO or (tiene_papel(P_FUENTE_FUEGO) and is_lit)


## ¿Pasa la llama, ahora, a lo inflamable que lo TOCA con el cuerpo? Arde Y (propaga la llama O es fuente de fuego). Lo que arde con
## `-propaga_llama` se consume sin pasarla, igual que en `_contagiar`.
func emite_fuego_por_contacto() -> bool:
	return esta_ardiendo() and (tiene_papel(P_PROPAGA_LLAMA) or tiene_papel(P_FUENTE_FUEGO))


## ¿Toca un cuerpo de radio `radio` situado en `p` (mundo) la caja de este objeto? Mide en horizontal con el radio de quien toca, y en vertical
## con el alto de la caja (un cuerpo por encima o por debajo no la toca). Sin caja (aún no está en el árbol) no toca nada.
func toca_punto(p: Vector3, radio: float = 0.0) -> bool:
	if _forma_cuerpo == null or not is_instance_valid(_forma_cuerpo) or not (_forma_cuerpo.shape is BoxShape3D):
		return false
	var caja: Vector3 = (_forma_cuerpo.shape as BoxShape3D).size
	var l: Vector3 = _forma_cuerpo.global_transform.affine_inverse() * p
	return absf(l.x) <= caja.x * 0.5 + radio and absf(l.z) <= caja.z * 0.5 + radio and absf(l.y) <= caja.y * 0.5 + radio


## Contagia a los objetos que arden de alrededor (y a la hierba, vía `hierba_cerca`): `viento` ≠ 0 = solo en su cono.
## A2: esto es el «vecino de rejilla» (ver la cabecera): el contacto entre PIEZAS de casillas vecinas. El contacto con CUERPOS (goblins, flechas)
## va por `toca_punto` desde `Combate3D`.
func _contagiar(radio: float, viento: Vector3) -> void:
	if not tiene_papel(P_PROPAGA_LLAMA):      # lo que arde pero no propaga (`-propaga_llama`) se consume sin pasar la llama
		return
	for otro in get_tree().get_nodes_in_group(GRUPO_ARDE):
		if otro == self or not is_instance_valid(otro) or not otro.has_method("can_burn") or not otro.can_burn():
			continue
		var hacia: Vector3 = (otro as Node3D).global_position - global_position
		hacia.y = 0.0
		if hacia.length() > radio:
			continue
		if viento != Vector3.ZERO and hacia.normalized().dot(viento.normalized()) < PUNTO_VIENTO:
			continue
		otro.ignite(global_position)
	if hierba_cerca.is_valid():
		hierba_cerca.call(global_position, radio, viento)


## --- Tótems ---

func _montar_totem() -> void:
	var c: Color = COLOR_ELEMENTO.get(elemento, Color.WHITE)
	# Círculo rúnico en el suelo (pieza 3D plana, Formas3D "runa"): apagado = casi del color del suelo; al activarse, el del elemento.
	_disco = Formas3D.instancia("runa", c.lerp(Color(0.62, 0.6, 0.56), 0.72))
	_disco.scale = Vector3(S * 1.1, 1.0, S * 1.1)
	_disco.position = Vector3(0.0, 0.02, 0.0)      # = Y_DECAL - ALTO de prueba_test2.gd: una sola altura para todo decal
	add_child(_disco)
	_pintar_emision(c, 0.0)


func _activar_totem() -> void:
	activo = true
	var c: Color = COLOR_ELEMENTO.get(elemento, Color.WHITE)
	_luz = _crear_luz(c, 1.0, 3.5, Vector3(0.0, 1.4, 0.0))
	fx.chispazo(global_position + Vector3(0.0, 1.0, 0.0), elemento)
	# Motas sutiles que se quedan saliendo de la runa (como `_particulas_runa` del 2D).
	_motas = Node3D.new()
	_motas.position = Vector3(0.0, 1.1, 0.12)
	add_child(_motas)
	var gp: GPUParticles3D = fx.chispas_mano(elemento, 1.2)
	_motas.add_child(gp)
	if elemento == "rayo":
		# Encendido para siempre: chispas eléctricas continuas por el suelo.
		var suelo: GPUParticles3D = fx.chispas_mano("rayo", 1.6)
		suelo.position = Vector3(0.0, 0.1, 0.0)
		(suelo.process_material as ParticleProcessMaterial).emission_sphere_radius = S * 0.4
		_motas.add_child(suelo)
		suelo.global_position = global_position + Vector3(0.0, 0.1, 0.0)
	_animar_k(1.0)
	if _disco != null:
		_disco.set_surface_override_material(0, Formas3D.material_tinte(c, true))
	activado.emit("totem", elemento)


## --- Fogatas y braseros ---

func _montar_fuente() -> void:
	if start_lit:
		_encender(false)
	else:
		_pintar_tinte(1.0)


func _encender(con_efectos: bool) -> void:
	is_lit = true
	if con_efectos:
		_reaccionar("prendido")             # encenderse al montar el nivel (start_lit) no es un cambio: no avisa
	var d: Array = _num_fuente()
	_llama = fx.llamas(global_position + Vector3(0.0, float(d[0]), 0.0), float(d[1]), float(d[2]), 1)   # 6.15: una sola lengua
	_luz = _crear_luz(Color(1.0, 0.6, 0.3), 1.1, 3.0, Vector3(0.0, float(d[0]) + 0.7, 0.0))
	_snd_fuego = Sfx3D.ambiente(self, "fuego")
	_pintar_tinte(0.0)
	_pintar_emision(Color(1.0, 0.55, 0.25), 0.25)
	if con_efectos:
		fx.chispazo(global_position + Vector3(0.0, float(d[0]) + 0.3, 0.0), "fuego")
		activado.emit(tipo, "fuego")
	llama.emit(true)
	if rele_activo:
		_t_rele = 0.0
		_rele_contagiado = false
		set_process(true)


## `motivo` = nombre de reacción con que se avisa: por defecto la apaga el agua o el frío; el relé y las reglas de Puzle3D la apagan sin elemento (consumido).
func _apagar_fuente(motivo: String = "apagado_agua") -> void:
	is_lit = false
	_reaccionar(motivo)
	_t_rele = 0.0
	_quitar_fuego()
	_pintar_tinte(1.0)
	_pintar_emision(Color.BLACK, 0.0)
	fx.ceniza(global_position + Vector3(0.0, float(_num_fuente()[0]), 0.0))
	activado.emit(tipo, "")
	llama.emit(false)


## --- Brasero con relé (Fase 14.6) ---

## Convierte este brasero en uno con relé: `siguiente` (puede ser null: un brasero que solo se apaga solo) se enciende `espera` s después
## de este y este se apaga a los `dura` s. Se llama una vez, al montar la fila (Puzle3D, `pieza … brasero rele=<id>`).
func configurar_rele(siguiente: Reactivo3D, espera: float = T_RELE_ESPERA, dura: float = T_RELE_DURA) -> void:
	rele_activo = true
	rele_siguiente = siguiente
	rele_espera = espera
	rele_dura = dura
	if is_lit:                       # ya estaba encendido al configurarlo: la cuenta empieza ahora
		_t_rele = 0.0
		_rele_contagiado = false
		set_process(true)


func _avanzar_rele(delta: float) -> void:
	_t_rele += delta
	if not _rele_contagiado and rele_siguiente != null and _t_rele >= rele_espera:
		_rele_contagiado = true
		if is_instance_valid(rele_siguiente) and not rele_siguiente.is_lit:
			rele_siguiente.encender_llama()
	if _t_rele >= rele_dura:
		_apagar_fuente("consumido")


## Enciende la llama de una fogata o un brasero sin hechizo (lo usan el relé y las reglas de Puzle3D). No hace nada si ya arde.
func encender_llama() -> void:
	if tiene_papel(P_FUENTE_FUEGO) and not is_lit:
		_encender(true)


## Apaga la llama de una fogata o un brasero sin hechizo. No hace nada si ya está apagada.
func apagar_llama() -> void:
	if tiene_papel(P_FUENTE_FUEGO) and is_lit:
		_apagar_fuente("consumido")


## --- 9.7 · Fuente eléctrica y surtidor (Bosque 1) ---

const COLOR_RAYO: Color = Color(1.0, 0.92, 0.4)
var _agua_pila: MeshInstance3D = null    ## surtidor: el agua de la pila (invisible hasta el primer chorro)
var _t_chispa: Timer = null              ## emisor_rayo: cada cuánto salta un chispazo grande


## Chispas que no paran (dos emisores a distinta altura), luz amarilla que parpadea a golpes irregulares y, cada 1–2,5 s,
## un chispazo grande en un punto al azar del cristal. Por qué tanto: es lo único que dice «esto da corriente» antes de que
## el jugador vea el agua electrificada.
## Tiñe el modelo del cristal de amarillo (material propio por malla, con un brillo suave).
func _tinte_amarillo(nodo: Node) -> void:
	Pieza3D.tinte_amarillo(nodo)      # 13/10: el mismo tinte que el marcador `e` en el editor (vive en Pieza3D)


func _montar_emisor() -> void:
	_pintar_emision(COLOR_RAYO, 0.6)
	if visual != null:
		_tinte_amarillo(visual)          # 12/10: el cristal es amarillo con chispas, no azul (el modelo trae el azul de serie)
	_motas = Node3D.new()
	add_child(_motas)
	# 13/10 (Pablo): las chispas del cristal, mucho más sutiles: menos, más pequeñas y apagadas (BRILLO_CHISPAS_CRISTAL).
	for alto in [0.7, 1.35]:
		var gp: GPUParticles3D = fx.chispas_mano("rayo", 1.5)
		(gp.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.45
		gp.amount = 4
		Vfx3D.atenuar(gp, BRILLO_CHISPAS_CRISTAL)
		_motas.add_child(gp)
		gp.global_position = global_position + Vector3(0.0, float(alto), 0.0)
	_luz = _crear_luz(COLOR_RAYO, LUZ_CRISTAL, 4.0, Vector3(0.0, 1.3, 0.0))
	var tw := _luz.create_tween().set_loops()
	for e in [1.7, 0.6, 1.3, 0.4, 1.9, 0.8]:          # parpadeo de tubo que falla, no un seno suave
		tw.tween_property(_luz, "light_energy", float(e) * LUZ_CRISTAL, 0.07)
		tw.tween_interval(0.05 + 0.1 * float(e))
	_t_chispa = Timer.new()
	_t_chispa.one_shot = true
	add_child(_t_chispa)
	_t_chispa.timeout.connect(_chispa_grande)
	_t_chispa.start(randf_range(0.5, 1.5))


func _chispa_grande() -> void:
	if fx != null:
		fx.chispazo_suave(global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.6, 1.5), randf_range(-0.4, 0.4)),
			COLOR_RAYO)
	_t_chispa.start(randf_range(2.5, 5.0))         # 13/10: menos a menudo (antes cada 1-2,5 s) y más pequeño


## 13/10 (Pablo: «mucho más sutiles»): brillo de las chispas del cristal (1 = el de antes) y energía de su luz (antes 1).
const BRILLO_CHISPAS_CRISTAL: float = 0.4
const LUZ_CRISTAL: float = 0.4


## La pila de piedra alrededor del pilar (la pieza `pilar` es el visual) y su agua, apagada hasta el primer chorro.
func _montar_surtidor() -> void:
	if visual != null and (visual.name == "tinaja_ruina" or visual.find_child("tinaja_ruina", true, false) != null):
		_montar_tinaja()
		return
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.58, 0.56, 0.52)
	piedra.roughness = 0.95
	var borde := CylinderMesh.new()
	borde.top_radius = 0.95
	borde.bottom_radius = 1.0
	borde.height = 0.3
	borde.material = piedra
	var pila := MeshInstance3D.new()
	pila.mesh = borde
	pila.position = Vector3(0.0, 0.15, 0.0)
	add_child(pila)
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color(0.35, 0.62, 0.9, 0.85)
	agua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	agua.roughness = 0.1
	agua.emission_enabled = true
	agua.emission = Color(0.2, 0.45, 0.7)
	agua.emission_energy_multiplier = 0.3
	var disco := CylinderMesh.new()
	disco.top_radius = 0.85
	disco.bottom_radius = 0.85
	disco.height = 0.02
	disco.material = agua
	_agua_pila = MeshInstance3D.new()
	_agua_pila.mesh = disco
	_agua_pila.position = Vector3(0.0, 0.31, 0.0)
	_agua_pila.visible = false
	add_child(_agua_pila)


## El surtidor echa agua: columna de agua de 2 s, salpicadura en la pila y la pila se llena (se queda llena). Público para que
## el Juego lo dispare también sin hechizo (p. ej. al cargar una partida con el cauce ya lleno).
func brotar(instantaneo: bool = false) -> void:
	if _es_tinaja:
		_brotar_tinaja(instantaneo)
		return
	if fx != null:
		fx.lanzar_forma("columna", "agua", global_position, global_position, {"dura": 2.0})
		fx.salpicadura(global_position + Vector3(0.0, 0.32, 0.0), 0.6)
	if _agua_pila != null and not _agua_pila.visible:
		_agua_pila.visible = true
		_agua_pila.scale = Vector3(0.2, 1.0, 0.2)
		_agua_pila.create_tween().tween_property(_agua_pila, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	usado = true
	activado.emit("surtidor", "agua")


## --- Tinaja de ruinas (10/10): vacía → llenándose → vertiendo ---
## Medidas en unidades de juego, en el espacio local del reactivo (la pieza mide 1,5 de alto y mira hacia +Z con giro 0).
## Medidas sobre el modelo (ruinas_agua.glb, ×2,70): el pico es la muesca del borde. Si cambias la pieza, mídelas de nuevo.
const BOCA_PICO: Vector3 = Vector3(0.16, 1.1, 0.52)      ## por dónde se derrama, con la tinaja SIN inclinar
## La boca está medida sobre la malla (10/10, mapa de alturas visto desde arriba): el borde es un anillo casi plano, inclinado ~17° hacia
## +X, con plano y = -0,288 x - 0,095 z + 1,396. La tinaja es un cuello abierto y hueco (el interior se ve opaco).
const BOCA_CENTRO: Vector3 = Vector3(0.254, 1.307, 0.158)   ## centro del borde de la boca, sobre el plano del anillo
const BOCA_RADIO: float = 0.26                              ## radio del borde exterior (por donde se derrama al inclinar)
const BOCA_NORMAL: Vector3 = Vector3(0.288, 1.0, 0.095)     ## normal del plano del borde (sin normalizar): el cuello apunta así
const AGUA_RADIO: float = 0.19                              ## el agua de dentro: un disco algo más ancho que el hueco (~0,17): lo recortan las paredes del cuello (15/10: antes 0,15)…
const AGUA_PROFUNDIDAD: float = 0.14                        ## …como mucho a esta profundidad bajo el borde (con la tinaja sin llenar del todo)…
const AGUA_PROFUNDIDAD_MIN: float = 0.02                    ## …y como poco a esta: el agua llega casi al borde.
const VUELO_Z: float = 0.4                               ## velocidad horizontal del chorro al salir (u/s)
const GRAVEDAD_CHORRO: float = 9.8
const SUELO_CHORRO: float = 0.05                         ## altura a la que termina el chorro
const T_LLENADO: float = 1.6                             ## s que tarda en llenarse antes de inclinarse
## Inclinación (encargo de Pablo): de 90° a 135°, es decir 45° MÁS sobre la pose de reposo. INCLINA_DESDE/HASTA solo importan por su
## diferencia; INCLINA_SENTIDO la multiplica (0,5 = la mitad). HACIA QUÉ LADO se inclina lo decide INCLINA_HACIA (abajo).
const INCLINA_DESDE: float = 90.0
const INCLINA_HASTA: float = 135.0
const INCLINA_SENTIDO: float = 0.5
## Hacia dónde se inclina y vierte, en el espacio LOCAL de la tinaja (la pieza mira a +Z con giro 0; su izquierda es +X):
## (1, 0, 0) = su izquierda (el valor de Pablo) · (0, 0, 1) = hacia delante (como antes) · (-1, 0, 0) = su derecha · (0, 0, -1) = atrás.
## Va con el giro de la pieza (`; giro x y grados` en el mapa): con giro 180 la izquierda de la tinaja es el OESTE del mapa.
## El chorro, las gotas, el arroyo y la casilla donde empieza el canal (`_montar_canal`) siguen esta dirección.
const INCLINA_HACIA: Vector3 = Vector3(1.0, 0.0, 0.0)
const T_INCLINA: float = 1.2                             ## s que dura la inclinación
const PIVOTE_TINAJA: Vector3 = Vector3(0.0, 0.55, 0.0)   ## centro de la panza: la tinaja gira alrededor de este punto
const T_CAUDAL: float = 2.2                              ## s que tarda el arroyo en llegar a su tamaño
const ARROYO_HASTA: float = S * 0.5                      ## el arroyo llega hasta el borde de la casilla de delante (donde empieza el canal)
const ARROYO_ANCHO: float = 0.42
## Velocidad del arroyo (u/s). Tarda lo que mide el trecho entre donde cae el chorro y el borde del canal (máximo T_CAUDAL, mínimo 0,15 s);
## si el chorro ya cae DENTRO de la casilla del canal (tinaja movida hacia ella) no hay arroyo y el canal empieza a llenarse al instante.
const VEL_ARROYO: float = 0.6
const COLOR_AGUA: Color = Color(0.35, 0.66, 0.95, 0.85)
## Brillo de la tinaja al recibir agua (feedback): sube a BRILLO_PICO (energía de emisión) en T_BRILLO s al empezar a llenarse, se queda
## suave mientras vierte y se apaga solo. Sutil: con el color del agua y poca energía.
const COLOR_BRILLO: Color = Color(0.5, 0.8, 1.0)
const BRILLO_PICO: float = 0.9
const BRILLO_REPOSO: float = 0.35                        ## fracción del pico que se mantiene mientras se llena
const T_BRILLO: float = 0.35
const T_BRILLO_FIN: float = 1.6                          ## s que tarda en apagarse una vez que vierte

## Agua que fluye (sin cálculo de fluidos: franjas que corren por la superficie). `por_x`: la corriente va por U en vez de V.
## Se comparte con los canales del suelo (la tubería abierta).
const CODIGO_CAUDAL: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 color : source_color = vec4(0.35, 0.66, 0.95, 0.85);
uniform float velocidad = 2.5;
uniform float frecuencia = 6.0;
uniform bool por_x = false;
uniform bool opaco = false;
// 10/10 (canal): para que las franjas sigan sin salto de una tira a la siguiente, `u` se mide en unidades de mundo: UV * `largo` +
// `fase` (lo que lleva recorrido el agua antes de esta tira). Por defecto (largo 1, fase 0) es el de siempre.
uniform float largo = 1.0;
uniform float fase = 0.0;
uniform float desv_ini = 0.0;       // fracción de la tira (al principio) donde el agua se desvanece desde cero
uniform float desv_fin = 0.0;       // fracción al final donde se desvanece hasta cero (el río que entra en el lago)
void fragment() {
	float u = por_x ? UV.x : UV.y;
	float v = por_x ? UV.y : UV.x;
	float uw = u * largo + fase;
	float franja = sin((uw * frecuencia - TIME * velocidad) * 6.2832) * 0.5 + 0.5;
	float onda = sin((v * 5.0 + uw * 3.0 - TIME * 0.6) * 6.2832) * 0.5 + 0.5;
	float k = clamp(franja * 0.6 + onda * 0.4, 0.0, 1.0);
	ALBEDO = mix(color.rgb, vec3(0.9, 0.97, 1.0), k * 0.55);
	ALPHA = opaco ? 1.0 : color.a * (0.7 + 0.3 * k);
	if (desv_ini > 0.0) { ALPHA *= smoothstep(0.0, desv_ini, u); }
	if (desv_fin > 0.0) { ALPHA *= 1.0 - smoothstep(1.0 - desv_fin, 1.0, u); }
}
"""

var _es_tinaja: bool = false
var _llenando: bool = false
var _pivote: Node3D = null               ## tinaja: gira la tinaja entera (modelo, agua de la boca) al inclinarse
var _gotas: GPUParticles3D = null        ## tinaja: gotas finas que salen hacia abajo (casi solo Y, muy poco X y Z)
var _chorro: Array = []                  ## tramos del chorro (MeshInstance3D), se enseñan de arriba abajo
var _chorro_gotas: Variant = null        ## 11.18: el chorro de gotas (GPUParticles3D) que sustituye a los cilindros, o null
var _snd_agua_cae: AudioStreamPlayer3D = null   ## 15/10 (Pablo): el agua cayendo en bucle mientras la tinaja vierte (Sfx3D); se corta en `dejar_de_verter`
var _charco: MeshInstance3D = null            ## 15/10: el charco de agua donde cae el chorro (crece al empezar a verter, se quita al dejar de verter)
var _chorro_sustituido: bool = false
var _vertido_parado: bool = false      ## 13/10: `dejar_de_verter` ya se ha llamado (puzzle resuelto)
const R_GOTAS_TINAJA: float = 0.12       ## radio visual del hilo de agua de la tinaja (u)
const CHARCO_RADIO: float = 0.3          ## 15/10 (Pablo): charco redondo donde cae el chorro, para que el agua no salga de la nada; cabe en el hueco del canal (~0,8 de ancho)
const CHARCO_ALTO: float = 0.16          ## altura sobre el suelo: justo encima del fondo del hueco del canal (FONDO_CANAL 0,11), para que no lo tape la piedra
var _punto_caida: Vector3 = Vector3.ZERO     ## local: donde cae el chorro
var _arroyo: Node3D = null               ## pivote en el punto de caída; su escala Z es lo que avanza el arroyo
var _tira: PlaneMesh = null              ## la tira del arroyo (su largo se ajusta con ajustar_arroyo)
var _tira_mi: MeshInstance3D = null
var _dist_arroyo: float = 1.0           ## trecho real (u) del chorro al borde del canal; ≤ 0,15 = el chorro cae ya dentro del canal
var _t_salp: Timer = null
static var _sombreado_caudal: Shader = null
const ENTRADA_CHORRO: float = 0.2         ## 11/10: cuánto se mete el primer tramo del chorro hacia dentro de la boca, para unirlo con el agua
const ALTO_ENTRADA_CHORRO: float = 0.04    ## y cuánto sube sobre el pico (el agua de dentro está un poco más alta que el borde por el que sale)
const ENTRADA_GOTAS: float = 0.12         ## 15/10: lo mismo para el chorro de GOTAS (menos que el de cilindros: las gotas ya tienen grosor)


static func material_caudal(por_x: bool = false, velocidad: float = 2.5, frecuencia: float = 6.0, opaco: bool = false) -> ShaderMaterial:
	if _sombreado_caudal == null:
		_sombreado_caudal = Shader.new()
		_sombreado_caudal.code = CODIGO_CAUDAL
	var m := ShaderMaterial.new()
	m.shader = _sombreado_caudal
	m.set_shader_parameter("color", COLOR_AGUA)
	m.set_shader_parameter("por_x", por_x)
	m.set_shader_parameter("opaco", opaco)
	m.set_shader_parameter("velocidad", velocidad)
	m.set_shader_parameter("frecuencia", frecuencia)
	return m


## Un tramo del chorro: cilindro fino de `a` a `b` (local), oculto hasta que le toca verse. Lo usan el tramo de entrada y los de la parábola.
func _cilindro_chorro(a: Vector3, b: Vector3) -> MeshInstance3D:
	var cil := CylinderMesh.new()
	cil.top_radius = 0.06
	cil.bottom_radius = 0.05
	cil.height = a.distance_to(b)
	cil.radial_segments = 8
	cil.rings = 1
	cil.material = material_caudal(false, 3.5, 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = cil
	mi.position = (a + b) * 0.5
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


## Punto del chorro `t` segundos después de salir por el pico (tiro parabólico).
static func punto_chorro(t: float) -> Vector3:
	return pico_inclinado() + dir_vertido() * (VUELO_Z * t) + Vector3(0.0, -0.5 * GRAVEDAD_CHORRO * t * t, 0.0)


## Dirección horizontal (local, unitaria) hacia la que se inclina y vierte.
static func dir_vertido() -> Vector3:
	var d := Vector3(INCLINA_HACIA.x, 0.0, INCLINA_HACIA.z)
	return d.normalized() if d.length() > 0.001 else Vector3(0.0, 0.0, 1.0)


## Eje de giro que baja el borde del lado `dir_vertido()` (Y × dirección: para +Z da +X, como antes).
static func eje_inclina() -> Vector3:
	return Vector3.UP.cross(dir_vertido()).normalized()


## Por dónde sale el agua con la tinaja SIN inclinar: la muesca del pico si vierte hacia delante; si no, el punto del borde de la
## boca que mira hacia donde se inclina (sobre el plano del anillo).
static func boca_vertido() -> Vector3:
	if dir_vertido().is_equal_approx(Vector3(0.0, 0.0, 1.0)):
		return BOCA_PICO
	var p: Vector3 = BOCA_CENTRO + dir_vertido() * BOCA_RADIO
	p.y = 1.396 - 0.288 * p.x - 0.095 * p.z
	return p


## Dónde queda el punto de vertido cuando la tinaja ya está inclinada (giro alrededor del pivote).
static func pico_inclinado() -> Vector3:
	var giro := Basis(eje_inclina(), deg_to_rad((INCLINA_HASTA - INCLINA_DESDE) * INCLINA_SENTIDO))
	return PIVOTE_TINAJA + giro * (boca_vertido() - PIVOTE_TINAJA)


func _montar_tinaja() -> void:
	_es_tinaja = true
	set_meta("no_ocluye_agua", true)      # 15/10: la tinaja no tapa las gotas de su propio chorro (AguaMetaballs3D.oclusion), sale de dentro de su boca
	# El modelo cuelga de un pivote en la panza para poder inclinarlo sin mover la base de piedra del suelo.
	_pivote = Node3D.new()
	_pivote.position = PIVOTE_TINAJA
	add_child(_pivote)
	if visual != null and visual.get_parent() == self:
		remove_child(visual)
		_pivote.add_child(visual)
		visual.position -= PIVOTE_TINAJA
	# El agua dentro de la boca: un disco inclinado como la boca, invisible hasta que empieza a llenarse.
	# 10/10 (Pablo): el agua de dentro NO se ve fuera de la boca. Es un disco OPACO y más estrecho que el hueco, metido por el cuello
	# por debajo del borde: lo tapan las paredes y solo se ve a través de la abertura. Se queda nivelado al inclinar (_brotar_tinaja).
	var disco := CylinderMesh.new()
	disco.top_radius = AGUA_RADIO
	disco.bottom_radius = AGUA_RADIO
	disco.height = 0.01
	disco.material = material_caudal(false, 1.0, 3.0, true)
	_agua_pila = MeshInstance3D.new()
	_agua_pila.mesh = disco
	_agua_pila.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_agua_pila.visible = false
	_pivote.add_child(_agua_pila)
	_poner_pila(0.0)
	# Chorro: ocho cilindros finos siguiendo la parábola.
	var t_fin: float = sqrt(2.0 * (pico_inclinado().y - SUELO_CHORRO) / GRAVEDAD_CHORRO)
	# 11/10 (Pablo): el chorro arrancaba en el borde del pico y no se unía con el agua de dentro de la boca (un hilo suelto). Un primer
	# tramo recto lo une: del agua, metido `ENTRADA_CHORRO` hacia dentro de la boca y a la altura del agua, hasta el pico. Sale el
	# primero (el chorro se enseña de arriba abajo).
	var desde: Vector3 = pico_inclinado() - dir_vertido() * ENTRADA_CHORRO + Vector3(0.0, ALTO_ENTRADA_CHORRO, 0.0)
	_chorro.append(_cilindro_chorro(desde, punto_chorro(0.0)))
	for i in range(8):
		var a: Vector3 = punto_chorro(t_fin * float(i) / 8.0)
		var b: Vector3 = punto_chorro(t_fin * float(i + 1) / 8.0)
		_chorro.append(_cilindro_chorro(a, b))
	var caida: Vector3 = punto_chorro(t_fin)
	caida.y = 0.0
	_punto_caida = caida + Vector3(0.0, 0.045, 0.0)      # donde toca el suelo el chorro (salpicadura); ya no hay charco dibujado
	# 15/10 (Pablo): un fondo circular de agua en el punto de caída. Sin él el chorro caía sobre la piedra seca y el agua salía «de la nada»
	# hasta que el canal (que ahora tarda ~18 s en llenarse) tenía agua. Opaco y plano, como el agua de la boca; invisible hasta que vierte.
	var disco_c := CylinderMesh.new()
	disco_c.top_radius = CHARCO_RADIO
	disco_c.bottom_radius = CHARCO_RADIO
	disco_c.height = 0.01
	disco_c.material = material_caudal(false, 1.0, 3.0, true)
	_charco = MeshInstance3D.new()
	_charco.mesh = disco_c
	_charco.position = Vector3(caida.x, CHARCO_ALTO, caida.z)
	_charco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charco.visible = false
	add_child(_charco)
	_arroyo = Node3D.new()
	_arroyo.position = caida + Vector3(0.0, 0.05, 0.0)
	_arroyo.rotation.y = atan2(dir_vertido().x, dir_vertido().z)      # su +Z mira hacia donde vierte
	_arroyo.visible = false
	add_child(_arroyo)
	var tira := PlaneMesh.new()
	_dist_arroyo = ARROYO_HASTA - caida.dot(dir_vertido())
	var largo: float = maxf(_dist_arroyo, 0.1)    # distancia hasta el borde de la casilla, en la dirección del vertido
	tira.size = Vector2(ARROYO_ANCHO, largo)
	tira.material = material_caudal(false, 2.5, 3.0)
	var tira_mi := MeshInstance3D.new()
	tira_mi.mesh = tira
	tira_mi.position = Vector3(0.0, 0.0, largo * 0.5)     # el pivote queda en el extremo de arriba de la tira
	tira_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arroyo.add_child(tira_mi)
	_tira = tira
	_tira_mi = tira_mi
	# Gotas: un «hechizo» de agua con la velocidad casi toda en Y (hacia abajo) y muy poca en X y Z.
	_gotas = GPUParticles3D.new()
	_gotas.amount = 28
	_gotas.lifetime = 0.5
	_gotas.emitting = false
	_gotas.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(dir_vertido().x * 0.25, -1.0, dir_vertido().z * 0.25)
	pm.spread = 6.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0.0, -GRAVEDAD_CHORRO, 0.0)
	_gotas.process_material = pm
	var gota := SphereMesh.new()
	gota.radius = 0.025
	gota.height = 0.05
	gota.radial_segments = 6
	gota.rings = 3
	var mg := StandardMaterial3D.new()
	mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mg.albedo_color = Color(0.7, 0.88, 1.0, 0.9)
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gota.material = mg
	_gotas.draw_pass_1 = gota
	_gotas.position = punto_chorro(0.0)
	add_child(_gotas)
	_t_salp = Timer.new()
	_t_salp.wait_time = 0.7
	_t_salp.timeout.connect(_salpicar_caida)
	add_child(_t_salp)


## El arroyo debe llegar hasta `hasta` (distancia desde el origen de la tinaja, en la dirección del vertido): el borde de la casilla
## donde empieza el canal. Lo llama la maqueta al montar el canal; la tinaja puede no estar centrada en su casilla (marcador movido).
func ajustar_arroyo(hasta: float) -> void:
	if _tira == null:
		return
	var t_fin: float = sqrt(2.0 * (pico_inclinado().y - SUELO_CHORRO) / GRAVEDAD_CHORRO)
	_dist_arroyo = hasta - punto_chorro(t_fin).dot(dir_vertido())
	var largo: float = maxf(_dist_arroyo, 0.1)
	_tira.size = Vector2(ARROYO_ANCHO, largo)
	_tira_mi.position = Vector3(0.0, 0.0, largo * 0.5)


## 13/10: dónde toca el suelo el chorro, en coordenadas del mundo. El canal empieza su agua justo aquí (PruebaTest2._montar_canal).
func punto_caida_global() -> Vector3:
	return global_transform * _punto_caida


## 13/10: el canal empieza donde cae el chorro, así que no hay arroyo que recorrer: el agua llega al canal en cuanto cae.
func sin_arroyo() -> void:
	_dist_arroyo = 0.0


func _salpicar_caida() -> void:
	if fx != null and is_inside_tree():
		fx.salpicadura(to_global(_punto_caida), 0.35)


## Vacía → llenándose → inclinándose → vertiendo. Una sola vez; después se queda vertiendo. `instantaneo`: sin esperas ni
## animación (al cargar una partida): la tinaja aparece ya inclinada y vertiendo.
func _brotar_tinaja(instantaneo: bool) -> void:
	if _llenando or usado:
		return
	_llenando = true
	_agua_pila.visible = true
	var angulo: float = deg_to_rad((INCLINA_HASTA - INCLINA_DESDE) * INCLINA_SENTIDO)
	var eje: Vector3 = eje_inclina()
	if instantaneo:
		_agua_pila.scale = Vector3.ONE
		_pivote.basis = Basis(eje, angulo)
		_poner_pila(1.0)       # el agua se queda nivelada y a la altura del pico
		_empezar_a_verter(true)
		return
	_agua_pila.scale = Vector3(0.15, 1.0, 0.15)
	_brillar()
	var tw: Tween = create_tween()
	tw.tween_property(_agua_pila, "scale", Vector3.ONE, T_LLENADO).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_inclinar.bind(eje, angulo), 0.0, 1.0, T_INCLINA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_empezar_a_verter.bind(false))


## Un paso (k de 0 a 1) de la inclinación: gira la tinaja entera y contragira el agua para que se quede nivelada.
func _inclinar(k: float, eje: Vector3, angulo: float) -> void:
	_pivote.basis = Basis(eje, angulo * k)
	_poner_pila(k)


## 15/10 (Pablo: «el agua debería llenar la boca» y «hay una discontinuidad» entre el agua de dentro y el chorro): el agua de dentro se
## queda a la ALTURA DEL PICO (donde nace el chorro), con la tinaja inclinada `k` de 0 a 1. Así el chorro sale del agua, sin salto, y el agua
## llena la boca hasta el borde. Se desplaza a lo largo del cuello (nunca más hondo que AGUA_PROFUNDIDAD ni más arriba que AGUA_PROFUNDIDAD_MIN)
## y se contragira para quedar nivelada.
func _poner_pila(k: float) -> void:
	var eje: Vector3 = eje_inclina()
	var angulo: float = deg_to_rad((INCLINA_HASTA - INCLINA_DESDE) * INCLINA_SENTIDO) * k
	var giro := Basis(eje, angulo)
	var n: Vector3 = BOCA_NORMAL.normalized()
	var c: Vector3 = BOCA_CENTRO - PIVOTE_TINAJA
	var objetivo_y: float = (giro * (boca_vertido() - PIVOTE_TINAJA)).y      # altura del pico con esta inclinación (relativa al pivote)
	var rn: float = (giro * n).y
	var d: float = AGUA_PROFUNDIDAD
	if absf(rn) > 0.05:
		d = clampf(((giro * c).y - objetivo_y) / rn, AGUA_PROFUNDIDAD_MIN, AGUA_PROFUNDIDAD)
	_agua_pila.position = c - n * d
	_agua_pila.quaternion = Quaternion(eje, -angulo)


## Brillo sutil de la tinaja al recibir el agua (feedback visual): sube rápido, se queda suave mientras se llena y se apaga al verter.
func _brillar() -> void:
	var tb: Tween = create_tween()
	tb.tween_method(_poner_brillo, 0.0, 1.0, T_BRILLO).set_trans(Tween.TRANS_SINE)
	tb.tween_method(_poner_brillo, 1.0, BRILLO_REPOSO, T_LLENADO).set_trans(Tween.TRANS_SINE)


func _poner_brillo(k: float) -> void:
	_pintar_emision(COLOR_BRILLO, BRILLO_PICO * k)


func _empezar_a_verter(instantaneo: bool) -> void:
	usado = true
	if instantaneo:
		for mi in _chorro:
			(mi as MeshInstance3D).visible = true
		_arroyo.visible = true
		_arroyo.scale = Vector3.ONE
		agua_llega.emit()
	else:
		var tw: Tween = create_tween()
		for i in range(_chorro.size()):         # el chorro baja de tramo en tramo (0,05 s cada uno)
			tw.tween_callback(_ver_tramo.bind(i))
			tw.tween_interval(0.05)
		tw.tween_callback(_abrir_caudal)
		create_tween().tween_method(_poner_brillo, BRILLO_REPOSO, 0.0, T_BRILLO_FIN).set_trans(Tween.TRANS_SINE)     # el brillo se apaga
	# 13/10 (Pablo): sin salpicadura donde cae el chorro: ahí empieza el río (el agua del canal), ver punto_caida_global.
	if _charco != null and not _charco.visible:
		_charco.visible = true
		_charco.scale = Vector3(0.2, 1.0, 0.2)
		_charco.create_tween().tween_property(_charco, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	_gotas.emitting = true
	_chorro_de_gotas()
	# El sonido sale de donde CAE el agua, no de la boca de la tinaja: es donde se oye el golpe. Sin audio importado `ambiente` devuelve null y no pasa nada.
	if _snd_agua_cae == null:
		_snd_agua_cae = Sfx3D.ambiente(self, "agua_cae")
		if _snd_agua_cae != null:
			_snd_agua_cae.position = _punto_caida + Vector3(0.0, 0.4, 0.0)
	activado.emit("surtidor", "agua")


## 13/10 (Pablo): puzzle resuelto → la tinaja deja de echar agua (antes vertía para siempre). Para el chorro de gotas (o los cilindros
## si no hay agua física), el arroyo y las gotas finas. Deja la tinaja inclinada y vacía; el agua que ya está en el canal NO se toca (la
## decide la maqueta). Idempotente; solo hace algo en una tinaja que está vertiendo. Lo llama la maqueta, pero es público para el Juego.
func dejar_de_verter() -> void:
	if not _es_tinaja or _vertido_parado:
		return
	_vertido_parado = true
	Sfx3D.parar(_snd_agua_cae)
	_snd_agua_cae = null
	if _charco != null:
		_charco.visible = false
	if not usado:          # puzzle resuelto antes de regarla: queda bloqueada, ya no vierte nunca (`brotar` sale si `usado`)
		usado = true
		return
	if _chorro_gotas != null:
		var maqueta: Node = get_parent()
		while maqueta != null and not maqueta.has_method("parar_chorro_agua"):
			maqueta = maqueta.get_parent()
		if maqueta != null:
			maqueta.call("parar_chorro_agua", _chorro_gotas)
		_chorro_gotas = null
	for mi in _chorro:
		(mi as MeshInstance3D).visible = false
	_arroyo.visible = false
	_gotas.emitting = false
	if _agua_pila != null:
		_agua_pila.visible = false


## Enseña el tramo `i` del chorro de cilindros, salvo que lo haya sustituido el chorro de gotas (11.18).
func _ver_tramo(i: int) -> void:
	if not _chorro_sustituido and i < _chorro.size():
		(_chorro[i] as MeshInstance3D).visible = true


## 11.18 (Pipeline): si la maqueta tiene agua con física, el chorro de la tinaja es de GOTAS fundidas (AguaMetaballs3D.chorro_fisico) con tantas
## gotas como caudal echa el surtidor (`Surtidor3D.CAUDAL_TINAJA`), en vez de los cilindros finos de arriba, que se ocultan. Sale del pico,
## con la X y la Y de la boca al punto de caída. Sin agua física (u otro nivel) no cambia nada.
func _chorro_de_gotas() -> void:
	var maqueta: Node = get_parent()
	while maqueta != null and not maqueta.has_method("chorro_agua"):
		maqueta = maqueta.get_parent()
	if maqueta == null or not is_inside_tree():
		return
	# 15/10 (Pablo: «mira la discontinuidad»): las gotas nacen METIDAS `ENTRADA_GOTAS` hacia dentro de la boca y a la altura del agua de dentro,
	# no en el borde: así el chorro cruza el borde y se une con el agua de la boca (como hacía el primer tramo de cilindros). Se alarga `x` y `y`
	# lo mismo que se retrasa el origen, así el punto de caída es el de siempre.
	var pico: Vector3 = to_global(punto_chorro(0.0) - dir_vertido() * ENTRADA_GOTAS + Vector3(0.0, ALTO_ENTRADA_CHORRO, 0.0))
	var dir_g: Vector3 = (global_transform.basis * dir_vertido()).normalized()
	var t_fin: float = sqrt(2.0 * (pico_inclinado().y - SUELO_CHORRO) / GRAVEDAD_CHORRO)
	var x: float = VUELO_Z * t_fin + ENTRADA_GOTAS
	var y: float = to_global(punto_chorro(0.0)).y + ALTO_ENTRADA_CHORRO - to_global(_punto_caida).y
	_chorro_gotas = maqueta.call("chorro_agua", pico, dir_g, x, y, R_GOTAS_TINAJA, -1.0, Surtidor3D.CAUDAL_TINAJA, false)
	if _chorro_gotas == null:
		return
	for mi in _chorro:
		(mi as MeshInstance3D).visible = false
	_gotas.emitting = false
	_chorro_sustituido = true


## El agua llega al suelo y el arroyo avanza hacia el canal (sin charco: el canal ya es el agua que se ve). Sin simulación: solo el
## tiempo y la escala. Al terminar el arroyo emite `agua_llega`: ahí empieza a llenarse el canal.
func _abrir_caudal() -> void:
	if _dist_arroyo <= 0.15:         # el chorro cae ya en el canal: nada que recorrer, el canal empieza ahora
		agua_llega.emit()
		return
	_arroyo.visible = true
	_arroyo.scale = Vector3(1.0, 1.0, 0.02)
	var tw: Tween = _arroyo.create_tween()
	tw.tween_property(_arroyo, "scale:z", 1.0, clampf(_dist_arroyo / VEL_ARROYO, 0.15, T_CAUDAL)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(agua_llega.emit)


## --- Puente y placa ---

func tender() -> void:
	if tipo != "puente" or usado:
		return
	usado = true
	_plegado = false
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.0, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fx.chispazo.bind(global_position + Vector3(S * 0.5, 0.3, 0.0), "rayo"))
	activado.emit("puente", "")


func esta_plegado() -> bool:
	return _plegado


## Algo con peso encima: se hunde y se queda (una vez, como en el 2D).
func pesar() -> void:
	if tipo != "placa" or usado:
		return
	usado = true
	var tw := create_tween()
	tw.tween_property(visual, "position:y", -0.06, 0.2)
	_pintar_emision(Color(0.5, 0.9, 0.6), 0.6)
	fx.chispazo(global_position + Vector3(0.0, 0.2, 0.0), "agua")
	activado.emit("placa", "")


func _physics_process(_delta: float) -> void:
	if usado:
		set_physics_process(false)
		return
	for a in get_overlapping_areas():
		if a.is_in_group(GRUPO_PESO):
			pesar()
			return
	for b in get_overlapping_bodies():
		if b.is_in_group(GRUPO_PESO):
			pesar()
			return


## --- Materiales: cada objeto trae sus copias, para tintar uno sin tocar a los demás ---

func _recoger_materiales() -> void:
	if visual == null:
		return
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_active_material(s)
			if mat is StandardMaterial3D:
				var copia: Material = (mat as StandardMaterial3D).duplicate() as Material
				copia = Ocluso3D.convertir(copia)      # con el círculo de transparencia del jugador (si está activo)
				mi.set_surface_override_material(s, copia)
				_mats.append([copia, Ocluso3D.color_de(copia)])
	for n in visual.find_children("*", "SpriteBase3D", true, false):
		_sprites.append([n, (n as SpriteBase3D).modulate])
	if visual is SpriteBase3D:
		_sprites.append([visual, (visual as SpriteBase3D).modulate])


## Tinta todo hacia `hacia` (multiplicando el color original): k = 0 sano … 1 el tinte.
func _pintar_tinte(k: float, hacia: Color = APAGADO) -> void:
	for m in _mats:
		Ocluso3D.poner_color(m[0] as Material, (m[1] as Color).lerp((m[1] as Color) * hacia, k))
	for s in _sprites:
		(s[0] as SpriteBase3D).modulate = (s[1] as Color).lerp((s[1] as Color) * hacia, k)


func _pintar_emision(c: Color, energia: float) -> void:
	for m in _mats:
		Ocluso3D.poner_emision(m[0] as Material, c, energia)


## Lleva el chamuscado (combustibles) o el brillo (tótem) a `destino` en FUNDIDO s.
func _animar_k(destino: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_poner_k, _k, destino, FUNDIDO)


func _poner_k(k: float) -> void:
	_k = k
	if tipo == "totem":
		_pintar_emision(COLOR_ELEMENTO.get(elemento, Color.WHITE), 1.2 * k)
	else:
		_pintar_tinte(k, CHAMUSCADO)


func _crear_luz(c: Color, energia: float, rango: float, p: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energia
	l.omni_range = rango
	l.position = p
	l.shadow_enabled = false
	add_child(l)
	return l

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
## 29/10 (DANO_Y_TINTA): débil ×1,5 y resiste ×0,75 (antes ×2 y ×0,5); los valores viven en `Dano` (único sitio del cálculo).
const MULT_DEBIL: float = Dano.MULT_DEBIL
const MULT_RESISTE: float = Dano.MULT_RESISTE
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
## 28/10 (gamefeel, `Sensacion3D.hitstop_de`): el hitstop es PROPORCIONAL al daño, de HITSTOP (golpe flojo) a HITSTOP_DEBIL (Sensacion3D.DANO_HITSTOP_MAX de daño o más, o su debilidad),
## y la jugadora se congela también una fracción (Sensacion3D.HITSTOP_COMPARTIDO). Antes era fijo: 0,06 y 0,09.
static var HITSTOP: float = 0.04               ## s que se congela ESE enemigo con el golpe más flojo (IA, animación y empuje; el mundo no)
static var HITSTOP_DEBIL: float = 0.10         ## el máximo: un golpe grande o de su elemento débil
static var DESTELLO_GOLPE: float = 0.20        ## s de blanco puro tras un golpe (antes 0,10 y tinte ×2,2, que dejaba ver la textura)
static var SQUASH_ESCALA: Vector3 = Vector3(1.25, 0.8, 1.25)   ## aplastamiento del modelo al golpe: vuelve a 1 en SQUASH_TIEMPO con TRANS_BACK
static var SQUASH_TIEMPO: float = 0.15
static var ANTICIPA_ESCALA: Vector3 = Vector3(1.12, 0.86, 1.12)   ## gamefeel: cómo se encoge al empezar el aviso de su ataque (C3)
static var SALTO_ALTO: float = 0.25            ## u: salto SOLO visual (el cuerpo no se mueve) con los elementos de SALTO_ELEMENTOS
static var SALTO_TIEMPO: float = 0.3           ## s que dura (sube y baja)
static var SALTO_ELEMENTOS: Array = ["viento", "tierra"]
static var INTERRUPCION_GOLPE: float = 0.6     ## s sin atacar tras un golpe con daño (antes 0,3). El resto del daño sigue con INTERRUPCION_DANO
static var INTERRUPCION_DANO: float = 0.3      ## s que da cualquier otro daño (quemadura, arco del rayo): con 0,6 una quemadura no le dejaría atacar nunca
## C3 (28/10): los ataques marcan antes en el suelo la zona que van a golpear (`AvisoAtaque3D`). `static var` para poder apagarlo desde un laboratorio.
static var AVISAR_ATAQUES: bool = true
const DESTELLO_DANO: float = 0.10              ## destello del daño que no es golpe (quemadura): el de siempre, para que no parpadee en blanco

## --- IA (px del 2D pasados a unidades: 300 px ≈ 2,5 casillas, §4.3 del plan) ---
const RADIO_DETECCION: float = 5.75
const RADIO_SOLTAR: float = 10.0
const TIEMPO_PERDER: float = 3.5
const PERIODO_CAMINO: float = 0.5                  ## D2: s entre dos recálculos de la ruta por casillas (también se recalcula si el objetivo cambia de casilla o el goblin se sale de ella). Barato, pero no hace falta cada fotograma
const VEL_PERSEGUIR: float = 2.4                   ## entre andar (1,6) y correr (3,0) del jugador
const VEL_PATRULLA: float = 1.0
const DISTANCIA_PATRULLA: float = 2.0
const RANGO_ATAQUE: float = 1.2
const HISTERESIS_RANGO: float = 1.2              ## empieza a pegar a `rango`, deja de esperar al pasar de rango*1,2 (evita parpadear entre atacar y perseguir)
const MARGEN_CANCELAR: float = 1.4               ## si el jugador se va más allá de rango*1,4 ANTES de que salga el golpe, se cancela el ataque
## 28/10 · RITMO DE LA FAMILIA GOBLIN (guerrero, arquero —también el de puesto—, asesino y chamán; no el elemental, el limo ni el gólem). Pedido de Pablo tras probar el chamán:
## «todo está muy acelerado, baja un 20 % animaciones y movimientos». UN SOLO MANDO para sus animaciones: `Pj3D.ritmo` multiplica todos sus clips (salvo los
## que van con la física o el mundo: empujado, levantarse, ahogo). El AVANCE no lo lleva: lo fija PASO_GOBLIN (29/10, «más pausado»). Lo cronometrado contra un clip (golpe, flecha, aviso, ritual, bola) divide su duración entre este número.
static var RITMO_GOBLIN: float = 0.8
## u de juego que avanza el cuerpo por ciclo de `walk` / `run` con el clip a velocidad 1 (sin root motion), medidas con herramientas/medidas_zancada_goblin.gd (pie apoyado, esqueleto
## escalado). Con ellas el clip va a vel_real · duración / zancada y los pies no patinan (`_animar`). Un modelo que no esté aquí usa el del guerrero.
const ZANCADA_GOBLIN: Dictionary = {
	"goblin_warrior_chibi": {"walk": 0.467, "run": 0.756},
	"goblin_archer_chibi": {"walk": 0.494, "run": 0.786},
	"goblin_asesino": {"walk": 0.540, "run": 0.854},
	"goblin_chaman": {"walk": 0.431, "run": 0.656},     # 29/10: su `walk` es el «Walking» de Marimanta (el de anciana: 0,2 u/ciclo, no servía para moverse)
}
const PASO_GOBLIN: float = 1.1                   ## 29/10: velocidad a la que se mueven los clips de andar/correr de un goblin (×1,1 de su clip); de ahí sale su avance (`v_base`)
const CLIP_ANDAR_MIN: float = 0.5
const CLIP_ANDAR_MAX: float = 2.5
const ELEM_ZANCADA_WALK: float = 3.5            ## metros que avanza el elemental en un ciclo de `walk` a velocidad 1 (ESTIMADO, afinar a ojo)
const PREPARAR_GOLPE: float = 0.6
const DESCANSO_GOLPE: float = 1.6
const DANO_GOLPE: float = 20.0
const T_ANIM_ATAQUE: float = 0.8              ## solo si el modelo no tiene clip de ataque
## El ataque se reproduce ENTERO (el clip dura 3-5 s): mientras dura, el goblin no anda ni se gira.
const VEL_ANIM_GUERRERO: float = 1.0
const VEL_ANIM_ARQUERO: float = 1.25
const MOMENTO_GOLPE_GUERRERO: float = 0.19    ## fracción del clip LeftSlash en que cae el golpe (~0,6 s de 3,2)
const VIDA_MAXIMA: float = 50.0               ## 29/10 (DANO_Y_TINTA): 100 → 50, el daño bajó a ~la mitad
const ORO_BOTIN: int = 10
const ALTO_BARRA_EXTRA: float = 0.28

## --- ELEMENTAL DE BOSQUE (8/10): élite lento que pega con el puño, conjura enredaderas vinculadas y se cura con agua ---
const ID_ELEMENTAL: String = "elemental_bosque"
const ELEM_VIDA: float = 500.0              ## 29/10 (DANO_Y_TINTA): 1000 → 500
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
const ARQUERO_FIJO_ALCANCE: float = 20.0        ## u: un arquero de puesto (`fijo`) dispara hasta aquí (≈ 8,7 casillas), con línea libre
const ARQUERO_FIJO_RAFAGA: float = 1.6          ## × la velocidad de la animación de disparo de un arquero de puesto (ciclo ≈ 3,4 s en vez de ≈ 4,9): bate el paso, no lo vigila
const SUAVIZADO_VEL_JUGADOR: float = 0.3        ## cuánto pesa cada fotograma en la velocidad estimada del jugador (para apuntar con adelanto)
const DANO_FLECHA: float = 12.0
const VEL_FLECHA: float = 9.0
const RADIO_IMPACTO_FLECHA: float = 0.75

## --- EL FUEGO PASA POR CONTACTO (21/10, A2 de docs/PLAN_EOW.md; regla de Pablo) ---
## Solo pasa de algo que ESTÁ ARDIENDO a algo INFLAMABLE que lo TOCA; no hay radio de calor. Aquí:
##   · un enemigo con `quemando > 0` está ARDIENDO (`esta_ardiendo()`) y prende lo inflamable que toca: objetos (`Reactivo3D.toca_punto`); a otros enemigos solo si `CONTACTO_ENTRE_ENEMIGOS`;
##   · todo enemigo es INFLAMABLE (`puede_prender()`) salvo mojado, congelado o muerto (como en `golpe`: fuego sobre mojado = vapor, no quema);
##     lo que arde y pasa llama (`Reactivo3D.emite_fuego_por_contacto`: fogata, brasero, seto en llamas…) lo prende si lo toca;
##   · la flecha del arquero es inflamable: sale ARDIENDO si cruza una llama (`_flecha_toca_fuego`) y, ardiendo, prende lo inflamable que toca y su impacto quema.
## El contagio entre OBJETOS no es de aquí: es el «vecino de rejilla» de `Reactivo3D._contagiar`.
const QUEMA_CONTACTO: float = 3.0               ## s de quemadura al prenderse por contacto (los 3 s de la runa de fuego; el elemental usa ELEMENTAL_QUEMA)
const INTERVALO_CONTACTO_FUEGO: float = 0.2     ## s entre dos comprobaciones de contacto (no hace falta cada fotograma: el fuego no va a esa velocidad)
const RADIO_CUERPO_ENEMIGO: float = 0.32        ## radio de la cápsula de un goblin (el del elemental se calcula de su altura)
const RADIO_FLECHA_FUEGO: float = 0.15          ## lo que «toca» una flecha en vuelo
## Decisión de Pablo (21/10, tras el playtest): los enemigos NO se contagian el fuego entre ellos; se prenden por OTRO elemento (brasero, seto en llamas,
## flecha ardiendo, hechizo). true = un enemigo ardiendo prende al enemigo que toca.
const CONTACTO_ENTRE_ENEMIGOS: bool = false
const COLOR_FLECHA_ARDIENDO: Color = Color(1.0, 0.5, 0.15)
## Una flecha ardiendo ha alcanzado a `objetivo` (el jugador): quien tenga mecánica de quemadura la escucha. El jugador no tiene aún (ver `quemar`).
signal flecha_ardiente_impacta(objetivo: Node3D)

## --- CONTRATO DE REACCIONES Y «CAE AL AGUA» (21/10, A3 de docs/PLAN_EOW.md) ---
## Todo enemigo responde a las mismas siete reacciones (nombres fijos, los de `reacciones_soportadas()`); la prueba herramientas/prueba_contrato_enemigo.gd
## recorre cada tipo y comprueba que lo que declara es lo que de verdad hace. Una reacción que un tipo NO tiene se declara ausente, no se finge.
const REACCIONES: PackedStringArray = ["quemado", "mojado", "congelado", "electrocutado", "empujado", "aturdido", "cae_al_agua"]
## Cae al agua: si tras un EMPUJE (o porque el suelo se le va: el hielo se derrite, el agua sube) su casilla es agua honda y no helada, se HUNDE: baja bajo la
## superficie en TIEMPO_HUNDIMIENTO, avisa a Mundo3D (nombre del aviso: AVISO_HUNDIDO, para las burbujas), muere SIN botín y emite `hundido`.
## Un goblin que anda por su cuenta NO entra en el agua: solo el empuje (`_mover_paso(..., true)`) puede meterlo.
const AVISO_HUNDIDO: String = "hundido"
## Ahogamiento lento (diario 245, pedido de Pablo tras validar el clip «Drowning»): el agua «se lo traga» despacio, no de golpe.
const TIEMPO_HUNDIMIENTO: float = 3.2          ## s que dura el hundimiento si el modelo NO trae clip (con clip, dura lo que el clip: así acaban a la vez)
const PROFUNDIDAD_EXTRA_HUNDIDO: float = 0.3   ## u que baja de más por debajo de la superficie (la cabeza también se pierde)
const HUNDIMIENTO_CURVA: float = 2.2           ## exponente de la bajada: 1 = lineal; >1 = se hunde poco mientras forcejea y más deprisa al final (el agua lo agarra)
const HUNDIMIENTO_REBOTES: float = 2.0         ## nº de «sacudidas» de flotación (sube un poco, vuelve a bajar) durante la caída; 0 = sin rebotes
const HUNDIMIENTO_REBOTE_ALTURA: float = 0.05  ## u que sube cada rebote al principio (se apaga hacia el final para no frenar el último tramo)
const CLIP_AHOGARSE: String = "drown"          ## rol del clip «Drowning» (diario 231): se usa si el modelo lo trae Y el árbol de animación lo admite
## Ser empujado (22/10, aprobado por Pablo): un empujón fuerte lanza al goblin por el aire con el clip «BeHit_FlyUp» (rol `empujado`, 1,5 s, acaba tumbado) y,
## si sigue vivo, se levanta con «Stand_Up1» recortado (rol `levantarse`, ~1,2 s) y vuelve a Idle. Mientras dura (EMPUJADO + LEVANTARSE, ~2,7 s) no anda ni ataca.
## Si muere o se hunde en mitad, se corta y pasa a muerte / hundirse como siempre. Solo los modelos que traen los dos clips (los goblins; `Pj3D.tiene_empujado`).
static var EMPUJADO_ACTIVO: bool = true               ## interruptor: false = los goblins no reaccionan al empuje con animación (como antes)
const EMPUJADO_V0_MIN: float = 1.0                    ## u/s de empuje inicial por debajo del cual NO se lanza (los soplos suaves del gas no lo tiran al suelo)
const FASE_NINGUNA: int = 0
const FASE_VOLANDO: int = 1                           ## clip `empujado`
const FASE_LEVANTANDOSE: int = 2                      ## clip `levantarse`
## Un enemigo se ha hundido en agua honda. Ya está marcado `muerto` y sin botín. `Estado.enemigo_muerto` también se emite (las misiones cuentan al caído).
signal hundido(enemigo: Combate3D)

var pj: Pj3D = null
## 28/10 (E2): el escudo de NATURALEZA que le pone el chamán (EscudoNaturaleza3D): absorbe daño por todos lados y el fuego lo quema de un golpe. null = sin él.
var escudo_natural: EscudoNaturaleza3D = null
var escudo: Escudo3D = null             ## A5: componente opcional (`Escudo3D.equipar(combate)`); null = sin escudo, como todos los goblins de los niveles
var mundo: Node3D = null
var jugador: Jugador3D = null
var lanz: Lanzador3D = null

var health: float = VIDA_MAXIMA
var vida_max: float = VIDA_MAXIMA
## 29/10 (DANO_Y_TINTA): DEFENSA plana del enemigo: `Dano.tras_defensa` la resta de cada golpe (con el suelo del 20 %). 2 = goblin (arquero, asesino, guerrero); 5 = el que lleva escudo
## (`Escudo3D.equipar`); 6 = elemental; 10 = gólem; 0 = limo, chamán, gatopedro. NO afecta al daño continuo (quemadura, veneno, pulsos).
@export var defensa: float = Dano.DEF_GOBLIN
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
var se_hundio: bool = false              ## murió ahogado (cae al agua), no por daño: sin botín
var _punto_hundido: Vector3 = Vector3.ZERO   ## dónde se hundió (en la superficie), para el aviso y la animación
var duracion_hundimiento: float = 0.0    ## s que dura el hundimiento real (el clip de ahogarse o TIEMPO_HUNDIMIENTO); 0 = aún no se ha hundido. Burbujas y sonido la copian
var quieto: bool = false                 ## R4 (17/10): sin IA (ni ve, ni persigue, ni ataca): los laboratorios lo ponen para tener dianas con vida. Sí recibe golpes, empuje y efectos
## C1 (28/10): false = el golpe cuerpo a cuerpo de la jugadora (`GolpeCuerpo`) le hace daño pero NO lo mueve (por masa). Lo pone a false el gólem de piedra (`Golem3D`, E3, 28/10).
var empujable_golpe: bool = true
var botin_goblin: bool = true           ## E3 (28/10): false = al morir no suelta los materiales del goblin (`BotinGoblin`: el colmillo); el gólem no los tiene
var premia_tinta: bool = true           ## C2 (28/10): false = muñeco o diana que no da tinta por reacción (`Tinta.premiar_reaccion`)
var arquero: bool = false               ## ataque a distancia (lo decide el modelo: goblin_archer*)
var fijo: bool = false                  ## 24/10 (paso batido del Bosque 01 v01): arquero DE PUESTO. No persigue, no retrocede ni patrulla: dispara desde su sitio a quien entre en ARQUERO_FIJO_ALCANCE con línea libre, apuntando con adelanto (la flecha tarda ~1,5 s: sin él solo acierta al que está parado)
var _pos_jug_prev: Vector3 = Vector3.ZERO
var _vel_jug: Vector3 = Vector3.ZERO    ## velocidad del jugador estimada por el arquero de puesto (u/s)

var _direccion: float = 1.0
var _ruta: Array[Vector2i] = []         ## D2: ruta por casillas (Caminos3D) que sigue cuando no hay línea recta libre; vacía = va derecho
var _ruta_meta: Vector2i = Vector2i(-9999, -9999)   ## casilla a la que se calculó
var _t_ruta: float = 0.0                ## cuenta atrás hasta el próximo recálculo
var rutas_calculadas: int = 0           ## cuántas veces pidió una ruta (para las pruebas: «con moderación»)
var _carga: float = 0.0
var _descanso: float = 0.0
var _empuje: Vector3 = Vector3.ZERO
var _fase_empuje: int = FASE_NINGUNA     ## FASE_*: en qué parte del «ser empujado» está (0 = en nada)
var _dir_previa: Vector3 = Vector3(0.0, 0.0, 1.0)   ## hacia dónde miraba el cuerpo antes del empujón
var _t_fase_empuje: float = 0.0          ## s que le quedan a la fase actual
var _tick_fuego: float = 0.0
var _t_contacto_fuego: float = 0.0      ## cuenta atrás hasta la próxima comprobación de contacto con el fuego (A2)
var _barra_t: float = 0.0
var _vida_mostrada: float = 1.0
var impactos_visuales: int = 0              ## cuántas veces pidió estrella + temblor al Vfx3D (para las pruebas)
var _destello: float = 0.0
var _flash_blanco: bool = false         ## el destello está pintado ahora mismo (emisión blanca en los materiales)
var _emision_previa: Array = []         ## [enabled, color, energía] de cada material antes del destello, para devolverlo igual
var _hitstop: float = 0.0               ## s que le quedan congelado por el último golpe
var respingo: Vector3 = Vector3.ZERO    ## gamefeel lote 3: desplazamiento del MODELO (no del nodo) del tirón al recibir un golpe; vuelve solo a cero
var _tw_respingo: Tween = null
var _squash: Vector3 = Vector3.ONE      ## factor de aplastamiento aplicado ahora mismo a pj.scale (se compone con otras escalas)
var _tw_squash: Tween = null
var _tw_salto: Tween = null
var _salto_y: float = 0.0               ## u de salto visual sobre el suelo (solo se suma a pj.position)
## 15/10 (gamefeel de la barra): la barra solo se ve tras recibir daño; al golpe, el relleno se pone BLANCO un instante y el trozo perdido
## se queda en blanco `RETARDO_PERDIDA` s antes de vaciarse, para que se vea cuánto ha quitado el golpe.
const RETARDO_PERDIDA: float = 0.35     ## s que el trozo perdido espera antes de encogerse
const DESTELLO_BARRA: float = 0.14      ## s que el relleno de la barra se queda blanco tras un golpe
var _barra_destello: float = 0.0
## Gamefeel (28/10): cómo se pinta el próximo número de daño. Un GOLPE (hechizo, golpe F) sale con «pop», del color del elemento y más grande si es su debilidad; el daño
## CONTINUO (quemadura, veneno, pulsos de una zona) se SUMA en un solo número mientras siga llegando (VENTANA_SUMA_MS).
const VENTANA_SUMA_MS: int = 600
var _num_golpe: bool = false
var _num_elemento: String = ""
var _num_debil: bool = false
var _num_continuo: Label3D = null
var _suma_continua: float = 0.0
var _t_suma_ms: int = -100000
var _perdida_espera: float = 0.0
var _t_anim: float = 0.0
var _ataque: float = 0.0       ## s que le quedan a la animación de ataque en curso (bloquea movimiento y giro)
var _ataque_vel: float = 1.0
var elemental: bool = false             ## el elemental de bosque (comportamiento propio)
var es_goblin: bool = false             ## 28/10: de la familia goblin (modelo `goblin_*`): lleva RITMO_GOBLIN
var _v_avance: float = 0.0              ## 28/10: u/s a los que avanza ahora mismo (ya con ritmo y estados): de ahí sale la velocidad del clip de andar sin patinar
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
var _aviso: AvisoAtaque3D = null        ## C3: el aviso en el suelo del ataque en curso (null si no hay o si ya lo soltó: la flecha en vuelo lleva el suyo)
var avisos_dados: int = 0               ## C3: cuántos avisos ha sacado (para las pruebas)
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
	# A2: los enemigos usan un grafo de animación reducido (idle, andar, correr, atacar, lanzar, golpeado, muerto): lo que no está ahí no se reproduce.
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
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


## Crea un goblin asesino en `pos` (banco de pruebas: Alt+F11 en el Jugador3D; ningún nivel lo coloca todavía). Mismo comportamiento cuerpo a cuerpo que el guerrero.
## Si falta su modelo sale un goblin guerrero. Devuelve null si no hay ninguno de los dos.
static func invocar_asesino(p_mundo: Node3D, p_jugador: Jugador3D, p_lanz: Lanzador3D, pos: Vector3) -> Combate3D:
	var modelo: Pj3D = p_mundo.call("_personaje", ["goblin_asesino", "goblin_warrior_chibi"], pos)
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
	es_goblin = pj != null and pj.id.begins_with("goblin")
	if es_goblin:
		pj.ritmo = RITMO_GOBLIN
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
	elif pj != null and pj.id.begins_with("goblin_asesino"):
		nombre = "Goblin asesino"
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
	# V5: el borde brillante del enemigo es del color de su debilidad (el mismo rombo que lleva sobre la cabeza): se lee de un vistazo con qué pegarle.
	if pj != null:
		pj.set_rol_visual("enemigo", (COLORES.get(debil, Pj3D.RIM_ENEMIGO) as Color).lerp(Color.WHITE, 0.25))


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
	var h: Hechizo = hechizo if hechizo != null else Hechizo.construir(rune_data, {})
	if h == null:
		return                                              # runa cinemática sin su Hechizo: no es un golpe del jugador
	# A5: único punto de consulta del escudo. Si está y el disparo viene de frente, lo recibe él y el goblin no se entera (por la espalda o el lado, pasa).
	if escudo != null and is_instance_valid(escudo) and escudo.para(direccion, h):
		return
	golpe(h, direccion)
	if objetivo == null and jugador != null and not muerto and _ve(RADIO_SOLTAR):
		objetivo = jugador          # un golpe te hace mirar a quien viene


## ¿Le cubre el escudo de lo que viaja en `direccion`, sin que el escudo lo «reciba»? Consulta pura (no cuenta bloqueo ni prende nada). La usa el daño por pulsos de
## una zona (`HechizoVivo.pulso_plasma`), que no pasa por `on_spell_hit`: lo que deja el impacto que el escudo paró (el campo de llamas) tampoco le llega al goblin.
func escudo_cubre(direccion: Vector3) -> bool:
	return escudo != null and is_instance_valid(escudo) and escudo.esta_activo() and escudo.es_de_frente(direccion)


## 28/10 · C1 (golpe cuerpo a cuerpo de la jugadora, `GolpeCuerpo`): daño plano `dano` (sin debilidades ni elementos) y un empujón FUERTE `fuerza` en `dir` por el `push` de siempre, así que si acaba en agua
## honda se hunde y da tinta por C2. Interrumpe el ataque que tuviera en curso. Con un escudo ACTIVO de frente (entero o ardiendo; `Escudo3D.esta_activo` ya excluye el quemado o roto) el golpe se para en él:
## sin daño y con `factor_escudo` del empuje; con el escudo quemado o roto, lo tumba como a cualquiera. Un enemigo con `empujable_golpe` false (el gólem, `Golem3D`) recibe el daño pero NO se mueve.
## Devuelve {escudo: bool, dano: float, v0: float}.
func recibir_golpe_cuerpo(dir: Vector3, dano: float, fuerza: float, factor_escudo: float = 0.5) -> Dictionary:
	var r: Dictionary = {"escudo": false, "dano": 0.0, "v0": 0.0}
	var d := Vector3(dir.x, 0.0, dir.z)
	if muerto or d.length() < 0.01:
		return r
	d = d.normalized()
	var parado: bool = escudo != null and is_instance_valid(escudo) and escudo.esta_activo() and escudo.es_de_frente(d)
	if parado:
		r["escudo"] = true
		escudo.bloqueos += 1
		escudo.bloqueado.emit(global_position + Vector3(0.0, altura * 0.5, 0.0))
		texto("Bloqueado", Color(0.75, 0.8, 0.9), 0.28)
	# Se interrumpe aunque no llegue a volar: el golpe le corta el ataque y la carga (como un hechizo con daño).
	_cancelar_ataque()
	_carga = 0.0
	interrupcion = maxf(interrupcion, INTERRUPCION_GOLPE)
	if empujable_golpe:
		var f: float = fuerza * (factor_escudo if parado else 1.0)
		r["v0"] = v0_de_empuje(f, true)
		push(d, f, true)
	if not parado and dano > 0.0:
		dano = Dano.tras_defensa(dano, defensa)         # 29/10 (DANO_Y_TINTA): el golpe F también pasa por la defensa y su suelo (F = 5: goblin 2 → 3 · escudo 5 → 1)
		r["dano"] = dano
		_num_golpe = true
		_num_elemento = ""
		_num_debil = false
		receive_damage(dano)
		_num_golpe = false
		var hs: float = Sensacion3D.hitstop_de(dano, false)
		_hitstop_compartido(hs)
		if not muerto:
			_iniciar_hitstop(hs)
		_impacto_visual("", false, d)
	_destello = maxf(_destello, DESTELLO_GOLPE)
	if objetivo == null and jugador != null and not muerto and _ve(RADIO_SOLTAR):
		objetivo = jugador                                  # un golpe te hace mirar a quien viene
	PlayLog.event("golpe_cuerpo_recibido", {"nombre": nombre, "dano": snappedf(float(r["dano"]), 0.1), "vida": snappedf(health, 0.1), "escudo": parado,
		"v0": snappedf(float(r["v0"]), 0.1)})
	return r


## `suelo` = es un golpe con daño: no recorre menos de EMPUJE_MIN_CASILLAS casillas (v0 mínima = casillas × tamaño × DECAIMIENTO, porque el
## empuje decae con lerp(…, 7·dt) y recorre v0 / 7). El elemental recibe MULT_EMPUJE_ELEMENTAL también en el suelo (si no, pegaría igual que un goblin).
func push(direccion: Vector3, fuerza: float, suelo: bool = false) -> void:
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() < 0.01 or muerto:
		return
	var v0: float = v0_de_empuje(fuerza, suelo)
	_empuje += d.normalized() * v0
	_reaccionar("empujado")                        # una vez por empujón (cada llamada a push), no por fotograma de desplazamiento
	if v0 >= EMPUJADO_V0_MIN:
		Sensacion3D.polvo(mundo, _pos_mundo(), Sensacion3D.POLVO_EMPUJE)     # gamefeel lote 2: los pies levantan polvo al salir despedido
	_empezar_empujado(d, v0)


## 28/10 · A2: la velocidad inicial (u/s) de un empujón de `fuerza`; `suelo` = es un golpe con daño (no recorre menos de EMPUJE_MIN_CASILLAS). Lo usan `push` y la previsión.
func v0_de_empuje(fuerza: float, suelo: bool = false) -> float:
	var peso: float = MULT_EMPUJE_ELEMENTAL if elemental else 1.0
	var v0: float = fuerza * MULT_EMPUJE * ESCALA_EMPUJE * peso
	if suelo:
		v0 = maxf(v0, EMPUJE_MIN_CASILLAS * Terreno3D.casilla * DECAIMIENTO_EMPUJE * peso)
	return v0


## 28/10 · A2: adónde llegaría este enemigo con los empujones `empujes` (Vector3 = dirección × v0, los que sumaría `push` a `_empuje`), SIN moverlo. Repite el bucle de `_ia`
## (`_mover_paso` con `empujado = true`, y el lerp de DECAIMIENTO_EMPUJE) con la misma `_puede_estar` (que mira desde la posición simulada), a pasos de `dt`. Si el cuerpo entra en
## agua honda, `_ajustar_al_suelo` lo hundiría en ese mismo fotograma: ahí se para y `hundira` es true. Devuelve {destino: Vector3, recorrido: float (u), hundira: bool, celda_agua}.
func prever_empuje(empujes: Array, dt: float = 1.0 / 60.0) -> Dictionary:
	var e := Vector3.ZERO
	for v in empujes:
		e += v as Vector3
	var pos: Vector3 = position
	var res: Dictionary = {"destino": pos, "recorrido": 0.0, "hundira": false, "celda_agua": Vector2i(-9999, -9999)}
	var c_ini: Vector2i = Terreno3D.celda_de(pos)
	var recorrido: float = 0.0
	var n: int = 0
	while e.length() > 0.1 and n < 600:
		n += 1
		var paso: Vector3 = e * dt
		for v in [paso, Vector3(paso.x, 0.0, 0.0), Vector3(0.0, 0.0, paso.z)]:
			var vv: Vector3 = v
			if vv.length() < 0.0001:
				continue
			var destino: Vector3 = pos + vv
			if _puede_estar_desde(pos, destino, true, false):
				pos.x = destino.x
				pos.z = destino.z
				recorrido += Vector2(vv.x, vv.z).length()
				break
		var c: Vector2i = Terreno3D.celda_de(pos)
		if c != c_ini and Terreno3D.es_agua(c) and _es_agua_honda(c):
			res["hundira"] = true                      # `_ajustar_al_suelo` lo hunde en el mismo fotograma en que pisa el agua honda
			res["celda_agua"] = c
			break
		e = e.lerp(Vector3.ZERO, clampf(DECAIMIENTO_EMPUJE * dt, 0.0, 1.0))
	res["destino"] = pos
	res["recorrido"] = recorrido
	return res


## 28/10 · A2: qué le pasaría a este enemigo si este hechizo le diera AHORA (misma regla que `on_spell_hit` → `golpe`), sin aplicar nada. `dir` = hacia dónde viaja el golpe;
## `empuje_previo` = empuje que `Lanzador3D._golpear` aplica ANTES del golpe (viento, atracción): {dir, fuerza} o {}. Devuelve:
##   cubierto   el escudo de frente lo para: entonces `escudo` lleva su reacción (`Escudo3D.reaccion_a`) y el goblin no recibe nada de lo demás (salvo el empuje previo, que no pasa por el escudo)
##   + todo lo de `decidir_golpe` (mult, dano, mojado/quemando/congelado nuevos, avisos…)
##   empujes    [{v0, dir}] los empujones que recibiría (el previo y el del golpe);  empuje  el resultado de `prever_empuje` con todos juntos ({} si no hay)
##   cae_al_agua  true si el empuje lo mete en agua honda
func prever_golpe(hechizo: Hechizo, dir: Vector3, empuje_previo: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {"cubierto": false, "escudo": "", "muerto": muerto, "curado": false, "mult": 1.0, "dano": 0.0, "avisos": [], "empujes": [], "empuje": {}, "cae_al_agua": false,
		"aturde": false, "vapor": false, "arco": false}
	if muerto or hechizo == null:
		return r
	var empujes: Array = []
	var d := Vector3(dir.x, 0.0, dir.z)
	if not empuje_previo.is_empty():
		var dp: Vector3 = empuje_previo["dir"]
		var vp: float = v0_de_empuje(float(empuje_previo["fuerza"]), false)
		empujes.append({"v0": vp, "dir": dp.normalized()})
	if escudo != null and is_instance_valid(escudo) and escudo.cubre(dir, hechizo):
		r["cubierto"] = true
		r["escudo"] = escudo.reaccion_a(hechizo)
	else:
		var dec: Dictionary = decidir_golpe(hechizo)
		for k in dec:
			r[k] = dec[k]
		if not bool(dec["curado"]) and d.length() > 0.01 and hechizo.fuerza_golpe > 0.0:
			empujes.append({"v0": v0_de_empuje(hechizo.fuerza_golpe, float(dec["dano"]) > 0.0), "dir": d.normalized()})
	r["empujes"] = empujes
	if not empujes.is_empty():
		var vs: Array = []
		for em in empujes:
			vs.append((em["dir"] as Vector3) * float(em["v0"]))
		r["empuje"] = prever_empuje(vs)
		r["cae_al_agua"] = bool((r["empuje"] as Dictionary)["hundira"])
	return r


## ¿Está volando o levantándose tras un empujón? (no anda ni ataca; el escudo va con el cuerpo)
func en_empujado() -> bool:
	return _fase_empuje != FASE_NINGUNA


func fase_empuje() -> int:
	return _fase_empuje


## Arranca el vuelo si el empujón es fuerte, el modelo trae los clips y no estaba ya en ello (los empujones seguidos del gas no lo reinician).
func _empezar_empujado(d: Vector3, v0: float) -> void:
	if not EMPUJADO_ACTIVO or elemental or muerto or _fase_empuje != FASE_NINGUNA or v0 < EMPUJADO_V0_MIN:
		return
	if pj == null or not is_instance_valid(pj) or not pj.tiene_empujado():
		return
	_fase_empuje = FASE_VOLANDO
	_t_fase_empuje = pj.duracion("empujado")
	_cancelar_ataque()
	_carga = 0.0
	_dir_previa = Vector3(sin(pj.rotation.y), 0.0, cos(pj.rotation.y))     # hacia dónde miraba: al levantarse vuelve a mirar ahí (mirada, y con ella el cono del escudo, no se toca)
	pj.mirar(-d, 1.0)             # el clip lo tira hacia atrás: de espaldas a donde va (de cara a quien lo empuja)
	anim_orden = ""
	pj.animacion_actual = ""      # que `jugar` no lo tome por «ya está puesto» si el último clip fue otro
	PlayLog.event("goblin_empujado", {"nombre": nombre, "v0": snappedf(v0, 0.1)})
	# Gamefeel lote 2: el polvo de la caída, hacia la mitad del clip de vuelo (cuando el cuerpo da en el suelo). Con hitstop o congelado el clip se para, el polvo no espera.
	if Sensacion3D.ACTIVA and is_inside_tree():
		var tw: Tween = create_tween()                 # un tween del nodo: si se libera antes, se va con él
		tw.tween_interval(maxf(_t_fase_empuje * 0.5, 0.05))
		tw.tween_callback(_polvo_caida)


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


## Las reacciones de `REACCIONES` que ESTE enemigo tiene de verdad (leído de `golpe`, `_ia` y `_ajustar_al_suelo`, no supuesto):
##   · quemado, congelado, electrocutado, empujado y cae_al_agua: todos (el elemental también; pesa: recibe el empuje × MULT_EMPUJE_ELEMENTAL).
##   · mojado y aturdido: todos MENOS el elemental. El agua no lo moja: lo cura y lo agranda (`_agua_elemental`); y `golpe`/`_ia` ignoran el aturdimiento
##     de un elemental (pesa demasiado). Decisión de diseño anterior a A3, que se respeta y se declara aquí.
func reacciones_soportadas() -> PackedStringArray:
	var r := PackedStringArray()
	for nombre in REACCIONES:
		if elemental and (nombre == "mojado" or nombre == "aturdido"):
			continue
		r.append(nombre)
	return r


## 29/10 · PASO DE LOS GOBLINS (Pablo eligió «más pausado»): el AVANCE de un goblin es el que hace que su clip de andar o correr vaya a ×PASO_GOBLIN con su zancada medida: v = PASO_GOBLIN · zancada / duración del clip,
## por modelo y por clip (guerrero: andar ≈ 0,49 u/s, correr ≈ 1,25). `v_base("walk")` es lo que antes era VEL_PATRULLA y `v_base("run")` lo que era VEL_PERSEGUIR; los demás enemigos (elemental…) siguen con esas dos constantes.
## El ritmo (RITMO_GOBLIN) ya no entra en el avance: queda para el resto de los clips (idle, ataque, lanzar…).
func v_base(clip: String) -> float:
	if es_goblin and pj != null and is_instance_valid(pj):
		var d: float = pj.duracion(clip)
		var z: float = zancada_goblin(clip)
		if d > 0.0 and z > 0.0:
			return PASO_GOBLIN * z / d
	return VEL_PERSEGUIR if clip == "run" else VEL_PATRULLA


## u por ciclo medidos del clip `clip` ("walk" o "run") de este goblin (los del guerrero si el modelo no está en la tabla); 0 si no es goblin.
func zancada_goblin(clip: String) -> float:
	if not es_goblin or pj == null:
		return 0.0
	return float((ZANCADA_GOBLIN.get(pj.id, ZANCADA_GOBLIN["goblin_warrior_chibi"]) as Dictionary).get(clip, 0.0))


## Velocidad (u/s) por encima de la cual un goblin usa `run` aunque su estado sea «andando»: la media geométrica entre su andar y su correr (mojado persigue a 0,75 · v_correr y sigue con `run`).
func umbral_correr() -> float:
	return sqrt(v_base("walk") * v_base("run"))


## 28/10: el ritmo de este enemigo (RITMO_GOBLIN si es de la familia goblin; 1 el elemental, el limo, el gólem y el resto).
func ritmo() -> float:
	return RITMO_GOBLIN if es_goblin else 1.0


func vel_mult() -> float:
	if congelado > 0.0:
		return 0.0
	var m: float = 1.0
	if mojado > 0.0:
		m *= 0.75
	if lento > 0.0:
		m *= 0.6
	return m


## 28/10 · A2 (previsión): la DECISIÓN del golpe, sin aplicar nada (ni estado, ni señales, ni texto). Es la única fuente de verdad: `golpe` aplica lo que devuelve esto y
## `prever_golpe` (la previsión del indicador) lo enseña. Devuelve:
##   curado     true = elemental con agua: lo cura y lo agranda (`_agua_elemental`), no recibe nada más
##   mult       R: debilidad ×1,5 / resistencia ×0,75 / 1        base  B·E·G·X (+ la suma de la reacción) ANTES de R y de la defensa (el rayo sobre mojado X = ×1,5, el hielo sobre mojado suma 15)
##   bruto      D = base × R, antes de la defensa        dano  D_final = máx(SUELO_DEF · D, D − defensa) (`Dano.aplicar`: el ÚNICO punto del cálculo)       defensa   la de este enemigo
##   mojado, quemando, congelado   cómo quedan esos contadores    lento   -1 = no cambia      interrumpe   -1 = no cambia (el viento la fija; el elemental no)
##   vapor      fuego sobre mojado       arco   el rayo sobre mojado salta al más cercano
##   avisos     las reacciones de `Mundo3D.REACCIONES` que saltarían, EN ORDEN (electrocutado, prendido, apagado_agua, secado, mojado, congelado)
##   aturde     true si el golpe lo aturde (no al elemental)        veneno  true si le deja veneno
func decidir_golpe(hechizo: Hechizo) -> Dictionary:
	var el: String = hechizo.elemento
	var x: float = 1.0               # X: la reacción (rayo sobre mojado)
	var suma_x: float = 0.0          # lo que SUMA la reacción (hielo sobre mojado)
	var r: Dictionary = {"curado": false, "mult": multiplicador(el), "base": hechizo.dano, "bruto": 0.0, "defensa": defensa, "dano": 0.0,
		"mojado": mojado, "quemando": quemando, "congelado": congelado, "lento": -1.0, "interrumpe": -1.0,
		"vapor": false, "arco": false, "avisos": [], "aturde": hechizo.aturde > 0.0 and not elemental, "veneno": hechizo.veneno > 0.0 and not elemental}
	if elemental and el == "agua":
		r["curado"] = true
		return r
	match el:
		"fuego":
			if mojado > 0.0:
				r["mojado"] = 0.0
				r["vapor"] = true
			else:
				r["quemando"] = maxf(hechizo.quema, ELEMENTAL_QUEMA) if elemental else hechizo.quema       # el elemental queda ardiendo un poco más: «ignite»
		"agua":
			r["mojado"] = hechizo.moja
			r["quemando"] = 0.0
		"rayo":
			if mojado > 0.0:
				x = Dano.X_RAYO_MOJADO
				r["arco"] = true
		"hielo":
			r["congelado"] = hechizo.congela_mojado if mojado > 0.0 else hechizo.congela
			if mojado > 0.0:
				suma_x = Dano.SUMA_HIELO_MOJADO
			r["quemando"] = 0.0
		"viento":
			if not elemental:                 # pesa demasiado: el viento no le corta el ataque
				r["interrumpe"] = hechizo.interrumpe
		"tierra":
			r["lento"] = hechizo.ralentiza
	var avisos: Array = r["avisos"]
	if el == "rayo":
		avisos.append("electrocutado")                # cada descarga que le llega es una reacción (no hay estado que dure)
	var ardia: bool = quemando > 0.0
	if float(r["quemando"]) > 0.0 and not ardia:
		avisos.append("prendido")
	elif ardia and float(r["quemando"]) <= 0.0:
		avisos.append("apagado_agua")                 # solo el agua y el hielo (quemando = 0) lo apagan; el viento no
	var estaba_mojado: bool = mojado > 0.0
	if estaba_mojado and float(r["mojado"]) <= 0.0:
		avisos.append("secado")                       # el fuego sobre mojado = vapor: lo seca
	elif not estaba_mojado and float(r["mojado"]) > 0.0:
		avisos.append("mojado")
	if float(r["congelado"]) > 0.0 and not (congelado > 0.0):
		avisos.append("congelado")
	# 29/10 (DANO_Y_TINTA): D = (B·E · G · X + suma) × R y después la defensa: UN solo punto de cálculo (`Dano`). `hechizo.dano` ya es B·E (con el pigmento); G = `hechizo.potencia`.
	r["base"] = hechizo.dano * hechizo.potencia * x + suma_x
	r["bruto"] = Dano.bruto(hechizo.dano, hechizo.potencia, x, float(r["mult"]), suma_x)
	r["dano"] = Dano.aplicar(hechizo.dano, hechizo.potencia, x, float(r["mult"]), defensa, suma_x)
	return r


## HC3 (18/10): el golpe lee del `Hechizo` (daño, fuerza, quema, moja, congela, aturde, ralentiza, interrumpe), ya no de tablas escritas aquí. Lo que SE QUEDA aquí son las reglas
## de interacción que dependen del estado del ENEMIGO (vapor si está mojado y recibe fuego, el rayo ×1,5 y el arco si está mojado, el hielo más largo si está mojado,
## el elemental curado por el agua y que arde más): son del que recibe, no del hechizo. A2: esas reglas viven en `decidir_golpe`; esto las APLICA.
func golpe(hechizo: Hechizo, direccion: Vector3) -> void:
	if muerto or hechizo == null:
		return
	var el: String = hechizo.elemento
	var dec: Dictionary = decidir_golpe(hechizo)
	var estaba_mojado: bool = mojado > 0.0
	if bool(dec["curado"]):
		_agua_elemental()                # lo cura y lo agranda UNA vez; ni mojado ni barrera de agua que lo proteja
		return
	var base: float = float(dec["base"])
	var mult: float = float(dec["mult"])

	mojado = float(dec["mojado"])
	quemando = float(dec["quemando"])
	congelado = float(dec["congelado"])
	if float(dec["lento"]) >= 0.0:
		lento = float(dec["lento"])
	if float(dec["interrumpe"]) >= 0.0:
		interrupcion = float(dec["interrumpe"])
		_carga = 0.0
	if bool(dec["vapor"]):
		texto_grande("¡Vapor!", Color(0.85, 0.9, 1.0))
	if bool(dec["arco"]):
		texto_grande("¡Descarga!", COLORES["rayo"])
		_arco_cercano(base * 0.5)
	elif el == "hielo" and estaba_mojado and congelado > 0.0:
		texto_grande("¡Congelado!", COLORES.get("hielo", Color(0.6, 0.9, 1.0)))
	for aviso in dec["avisos"]:
		_reaccionar(String(aviso))       # A4: una vez por golpe, nunca por fotograma

	var dano: float = float(dec["dano"])
	if elemental and el == "fuego" and _potenciado:
		_encoger()                             # el fuego le quita lo que le dio el agua
	if mult > 1.0:
		texto("¡Débil!", COLORES.get(debil, Color.WHITE), 0.28)
	elif mult < 1.0 and base > 0.0:
		texto("Resiste", Color(0.7, 0.7, 0.7), 0.28)

	if bool(dec["veneno"]):           # el veneno no hace nada a un elemental (no tiene carne); se queda el más largo / fuerte
		if envenenado <= 0.0:
			texto("Veneno", Color(0.55, 0.9, 0.35), 0.28)
		envenenado = maxf(envenenado, hechizo.veneno)
		_dps_veneno = maxf(_dps_veneno, hechizo.veneno_dps)
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() > 0.01 and hechizo.fuerza_golpe > 0.0:      # el empuje del viento (y la atracción) lo da Lanzador3D por push(): su fuerza_golpe es 0
		push(d, hechizo.fuerza_golpe, dano > 0.0)
	if bool(dec["aturde"]):
		_aturdir(hechizo.aturde)
	if dano > 0.0:
		_num_golpe = true
		_num_elemento = el
		_num_debil = mult > 1.0
		receive_damage(dano)
		_num_golpe = false
		var hs: float = Sensacion3D.hitstop_de(dano, mult > 1.0)
		_hitstop_compartido(hs)
		if not muerto:
			interrupcion = maxf(interrupcion, INTERRUPCION_GOLPE)
			_iniciar_hitstop(hs)
	_destello = maxf(_destello, DESTELLO_GOLPE)
	if not muerto:
		_reaccion_visual(el)
	_impacto_visual(el, mult > 1.0, d)
	PlayLog.event("golpe_goblin", {"elemento": el, "dano": snappedf(dano, 0.1), "vida": snappedf(health, 0.1),
		"mult": mult})


## A4: avisa de una reacción con nombre (catálogo de Mundo3D.REACCIONES) en el centro del cuerpo. Qué se ve y suena lo decide el Pipeline.
func _reaccionar(nombre: String, punto: Variant = null) -> void:
	var p: Vector3 = (punto as Vector3) if punto != null else _pos_mundo() + Vector3(0.0, altura * 0.5, 0.0)
	Mundo3D.avisar_reaccion(nombre, p, self)


func _aturdir(segundos: float) -> void:
	if stun_timer <= 0.0:
		_reaccionar("aturdido")                    # solo al empezar: volver a aturdir a uno ya aturdido no es un cambio
	stun_timer = segundos
	_carga = 0.0


## Fase 3 del pulso (C4): el frente de un pulso que corre por una veta con `aturde` deja sin sentido a quien la pisa (lo llama `Pulso3D._aturdir_en`). Sin daño.
func aturdir_pulso(segundos: float) -> void:
	if muerto:
		return
	_aturdir(segundos)


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
	if escudo_natural != null and is_instance_valid(escudo_natural) and escudo_natural.activo():
		cantidad = escudo_natural.absorber(cantidad, _num_elemento)     # E2: el escudo de naturaleza se come el daño (el fuego lo quema)
		if cantidad <= 0.0:
			return
	health -= cantidad
	_barra_t = TIEMPO_BARRA
	_destello = maxf(_destello, DESTELLO_DANO)
	_barra_destello = DESTELLO_BARRA
	_perdida_espera = RETARDO_PERDIDA
	_numero(cantidad)
	if health > 0.0 and not elemental:      # el elemental no tiene clip `hit`. 17/10: también aturdido (antes se saltaba y el rayo no se notaba)
		anim_orden = "hit"
		interrupcion = maxf(interrupcion, INTERRUPCION_DANO)
	if health <= 0.0:
		_morir()


## Gamefeel (28/10): el número de daño. Golpe: con «pop», del color de su elemento y más grande (con «!») si es su debilidad. Continuo: se suma al anterior si llega dentro de
## VENTANA_SUMA_MS (la quemadura de 3 s sale como un número que va subiendo, no como seis).
func _numero(cantidad: float) -> void:
	var p: Vector3 = position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0)
	if _num_golpe:
		var col: Color = Color(1, 0.95, 0.85)
		if _num_elemento != "" and COLORES.has(_num_elemento):
			col = (COLORES[_num_elemento] as Color).lerp(Color.WHITE, 0.3)
		flotante(mundo, p, str(int(round(cantidad))) + ("!" if _num_debil else ""), col, 1.45 if _num_debil else 1.0)
		return
	var ahora: int = Time.get_ticks_msec()
	if _num_continuo != null and is_instance_valid(_num_continuo) and ahora - _t_suma_ms < VENTANA_SUMA_MS:
		_suma_continua += cantidad
		_num_continuo.queue_free()
	else:
		_suma_continua = cantidad
	_t_suma_ms = ahora
	var col_c: Color = Color(0.85, 0.85, 0.85)
	if _num_elemento == "fuego":
		col_c = COLORES["fuego"]
	elif _num_elemento == "veneno":
		col_c = Color(0.55, 0.9, 0.35)
	_num_continuo = flotante(mundo, p, str(int(round(_suma_continua))), col_c, 0.8)
	_num_elemento = ""


## Gamefeel: la jugadora también se congela un instante cuando su golpe conecta (una fracción del hitstop del enemigo).
func _hitstop_compartido(hs: float) -> void:
	if Sensacion3D.ACTIVA and jugador != null and is_instance_valid(jugador) and jugador.has_method("hitstop"):
		jugador.hitstop(hs * Sensacion3D.HITSTOP_COMPARTIDO)


func texto(txt: String, color: Color, extra_alto: float = 0.0) -> void:
	Combate3D.flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA + extra_alto, 0), txt, color)


## Gamefeel lote 2: el polvo de la caída del vuelo del empujón (no si se hundió: ahí salpica el agua).
func _polvo_caida() -> void:
	if not se_hundio:
		Sensacion3D.polvo(mundo, _pos_mundo(), Sensacion3D.POLVO_CAIDA)


## Gamefeel lote 2: una REACCIÓN GRANDE (vapor, descarga, congelado sobre mojado, hundido…): rótulo grande, hitstop del mundo, temblor y su sonido
## (`Sensacion3D.reaccion_grande`). Con la sensación apagada, el texto pequeño de siempre.
func texto_grande(txt: String, color: Color, extra_alto: float = 0.0) -> void:
	var p: Vector3 = position + Vector3(0, altura + ALTO_BARRA_EXTRA + extra_alto + 0.15, 0)
	if not Sensacion3D.reaccion_grande(self, txt, color, p):
		texto(txt, color, extra_alto)


## Número o aviso que sube y se desvanece. Estático: lo usan también Jugador3D y Lanzador3D. Gamefeel (28/10): nace grande y encoge con rebote («pop») hasta `escala`;
## devuelve el Label3D (para sumarle daño continuo) o null.
static func flotante(en: Node, pos: Vector3, txt: String, color: Color, escala: float = 1.0) -> Label3D:
	if en == null or not en.is_inside_tree():
		return null
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
	l.scale = Vector3.ONE * escala * 1.7
	tw.tween_property(l, "scale", Vector3.ONE * escala, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(l.queue_free)
	return l


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
		pj.position = position + Vector3(0.0, _salto_y, 0.0) + respingo
		_dibujar_estado(delta)
		if _hitstop <= 0.0:
			_fin_hitstop()
		return
	_efectos(delta)
	_ia(delta)
	_ajustar_al_suelo(delta)
	if muerto:
		# `_ajustar_al_suelo` puede haberlo ahogado (`_hundirse` → `_morir(true)`, que ya pidió el clip `drown`): seguir con `_animar` pediría `idle`
		# y lo pisaría, y `pj.position` pelearía con el tween que lo hunde. Muerto, esta pasada se acaba aquí.
		return
	_animar()
	pj.position = position + Vector3(0.0, _salto_y, 0.0) + respingo
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
	if SALTO_ELEMENTOS.has(el) and _fase_empuje == FASE_NINGUNA:      # lanzado por el aire, el saltito de viento/tierra sobra
		if _tw_salto != null and _tw_salto.is_valid():
			_tw_salto.kill()
		_tw_salto = create_tween()
		_tw_salto.tween_method(func(t: float) -> void: _salto_y = SALTO_ALTO * sin(PI * t), 0.0, 1.0, SALTO_TIEMPO)
		_tw_salto.tween_callback(func() -> void: _salto_y = 0.0)


## Estrella de impacto del elemento sobre el enemigo y un temblor de cámara: más fuerte si es su punto débil (T-CP2 / MEJORAS_POTENCIA §2). Sin `_fx` en el mundo
## (escenarios sin ventana) no hace nada.
## Gamefeel (28/10): y un chorro de partículas en la DIRECCIÓN del golpe (`dir`; el golpe F, sin elemento, solo eso y en blanco).
func _impacto_visual(el: String, debil: bool, dir: Vector3 = Vector3.ZERO) -> void:
	if not muerto:
		_respingar(dir)
	var fx: Variant = mundo.get("_fx") if mundo != null else null
	if not (fx is Vfx3D) or not is_inside_tree():
		return
	if Sensacion3D.ACTIVA and Vector2(dir.x, dir.z).length() > 0.01:
		(fx as Vfx3D).golpe_direccional(global_position + Vector3(0.0, 0.55, 0.0), dir, el, 1.4 if debil else 1.0)
	if not Vfx3D.ELEMENTOS.has(el):
		return
	(fx as Vfx3D).golpe_estrella(global_position + Vector3(0.0, 0.6, 0.0), el, 1.5 if debil else 1.0)
	(fx as Vfx3D).temblor(TEMBLOR_DEBIL if debil else TEMBLOR_GOLPE)
	impactos_visuales += 1


## Gamefeel lote 3: el modelo da un tirón hacia donde va el golpe (o lejos de la jugadora si el golpe no trae dirección) y vuelve. Corre aunque esté en
## hitstop (el tween es del nodo, no de su IA): es justo lo que se ve mientras está congelado. El nodo, la colisión y el aviso no se mueven.
func _respingar(dir: Vector3) -> void:
	if not Sensacion3D.ACTIVA or not is_inside_tree() or Sensacion3D.RESPINGO <= 0.0:
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.01 and jugador != null and is_instance_valid(jugador):
		d = position - jugador.position
		d.y = 0.0
	if d.length() < 0.01:
		return
	var f: float = Sensacion3D.RESPINGO * (0.6 if elemental else 1.0)
	if _tw_respingo != null and _tw_respingo.is_valid():
		_tw_respingo.kill()
	Sensacion3D.cuenta["respingo"] = int(Sensacion3D.cuenta["respingo"]) + 1
	var t: float = maxf(Sensacion3D.T_RESPINGO, 0.02)
	_tw_respingo = create_tween()
	_tw_respingo.tween_property(self, "respingo", d.normalized() * f, t * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw_respingo.tween_property(self, "respingo", Vector3.ZERO, t * 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		if quemando <= 0.0:
			_reaccionar("consumido")                # se le acabó el fuego solo: el Pipeline corta las llamas del cuerpo con `consumido`
		_tick_fuego -= delta
		if _tick_fuego <= 0.0:
			_tick_fuego = 0.5
			_num_elemento = "fuego"
			receive_damage(ELEM_IGNITE if elemental else 3.0 * (MULT_DEBIL if debil == "fuego" else 1.0))
			if muerto:
				return
	_fuego_por_contacto(delta)
	if muerto:
		return
	if envenenado > 0.0:
		envenenado = maxf(0.0, envenenado - delta)
		_tick_veneno -= delta
		if _tick_veneno <= 0.0:
			_tick_veneno = TICK_VENENO
			_num_elemento = "veneno"
			receive_damage(_dps_veneno * TICK_VENENO)
			if muerto:
				return
		if envenenado <= 0.0:
			_dps_veneno = 0.0
	var estaba_mojado: bool = mojado > 0.0
	var estaba_congelado: bool = congelado > 0.0
	mojado = maxf(0.0, mojado - delta)
	congelado = maxf(0.0, congelado - delta)
	if estaba_mojado and mojado <= 0.0:
		_reaccionar("secado")
	if estaba_congelado and congelado <= 0.0:
		_reaccionar("derretido")
	lento = maxf(0.0, lento - delta)
	_t_anim = maxf(0.0, _t_anim - delta)
	_avanzar_empujado(delta)
	_ataque = maxf(0.0, _ataque - delta)
	_descanso = maxf(0.0, _descanso - delta)
	if elemental:
		_efectos_elemental(delta)


## --- A2 · El fuego pasa por contacto ---

## ¿Está ardiendo este enemigo? (quemadura activa). Es el «ardiendo» de la regla: el que prende lo inflamable que toca.
func esta_ardiendo() -> bool:
	return quemando > 0.0 and not muerto


## ¿Es inflamable AHORA? Todo enemigo vivo lo es, salvo si está mojado (el agua lo protege: fuego sobre mojado = vapor) o congelado.
func puede_prender() -> bool:
	return not muerto and mojado <= 0.0 and congelado <= 0.0


## Lo prende el contacto con una llama. Devuelve si prendió. No acorta una quemadura más larga (quedarse en la llama la mantiene).
func prender_por_contacto(segundos: float = QUEMA_CONTACTO) -> bool:
	if not puede_prender():
		return false
	var estaba: bool = quemando > 0.0
	quemando = maxf(quemando, maxf(segundos, ELEMENTAL_QUEMA) if elemental else segundos)
	if not estaba:
		_reaccionar("prendido")
		_destello = maxf(_destello, DESTELLO_DANO)
		PlayLog.event("goblin_prende_por_contacto", {"nombre": nombre})
	return true


func _radio_cuerpo() -> float:
	if _col != null and _col.shape is CapsuleShape3D:
		return (_col.shape as CapsuleShape3D).radius
	return RADIO_CUERPO_ENEMIGO


func _pos_mundo() -> Vector3:
	return global_position if is_inside_tree() else position


## Cada INTERVALO_CONTACTO_FUEGO s: si arde, prende lo inflamable que toca; si no, mira si lo toca algo que arde. Todo por CONTACTO de cuerpos.
func _fuego_por_contacto(delta: float) -> void:
	_t_contacto_fuego -= delta
	if _t_contacto_fuego > 0.0 or muerto or not is_inside_tree():
		return
	_t_contacto_fuego = INTERVALO_CONTACTO_FUEGO
	var arde: bool = esta_ardiendo()
	if not arde and not puede_prender():
		return                                  # mojado o congelado y sin fuego encima: nada que hacer
	var p: Vector3 = _pos_mundo()
	var r: float = _radio_cuerpo()
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if not is_instance_valid(n) or not (n is Reactivo3D):
			continue
		var o: Reactivo3D = n
		if arde:
			if o.can_burn() and o.toca_punto(p, r):      # can_burn ya excluye lo mojado y lo que no es inflamable
				o.ignite(p)
		elif o.emite_fuego_por_contacto() and o.toca_punto(p, r):
			arde = prender_por_contacto()
			break
	if not CONTACTO_ENTRE_ENEMIGOS:
		return
	for n in get_tree().get_nodes_in_group("combate3d"):
		if n == self or not is_instance_valid(n) or not (n is Combate3D):
			continue
		var otro: Combate3D = n
		if otro.muerto or absf(otro._pos_mundo().y - p.y) > maxf(altura, otro.altura):
			continue
		var d: Vector3 = otro._pos_mundo() - p
		d.y = 0.0
		if d.length() > r + otro._radio_cuerpo():
			continue
		if arde and not otro.esta_ardiendo():
			otro.prender_por_contacto()
		elif not arde and otro.esta_ardiendo():
			arde = prender_por_contacto()


func _ia(delta: float) -> void:
	# Retroceso por golpes (decae solo)
	if _empuje.length() > 0.1:
		_mover_paso(_empuje * delta, true)          # empujado: SÍ puede acabar en el agua honda (y hundirse); andando por su cuenta, no
		_empuje = _empuje.lerp(Vector3.ZERO, clampf(DECAIMIENTO_EMPUJE * delta, 0.0, 1.0))
	if elemental:
		stun_timer = 0.0
		interrupcion = 0.0
	if _fase_empuje != FASE_NINGUNA:
		# Volando o levantándose: ni anda, ni ataca, ni carga (el empuje horizontal de arriba sí sigue).
		_cancelar_ataque()
		_carga = 0.0
		moviendo = 0
		return
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
	if fijo and arquero:
		_ia_arquero_fijo(delta)
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
				_v_avance = v_base("run") * vel
				_mover_paso(_dir_hacia(meta, delta) * _v_avance * delta, false, true)
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
				_v_avance = v_base("walk") * (1.0 if es_goblin else 1.5) * vel
				if not _mover_paso(_dir_hacia(casa, delta) * _v_avance * delta, false, true):
					estado = "patrulla"
		_:
			_patrullar(delta, vel)


func _patrullar(delta: float, vel: float) -> void:
	_carga = 0.0
	moviendo = 1
	mirada = Vector3(_direccion, 0.0, 0.0)
	_v_avance = v_base("walk") * vel
	var paso := Vector3(_direccion * _v_avance * delta, 0.0, 0.0)
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
		# Modelo con varios cortes en su ataque (goblin asesino: dos cortes cruzados, Pj3D.momentos_corte): un golpe por corte, cada uno con el daño del golpe del guerrero.
		# La invulnerabilidad del jugador tras un golpe (Jugador3D.INVULNERABLE, 0,7 s) hace que el segundo corte solo cuente si el primero falló: ~el mismo daño por ataque.
		var cortes: Array = pj.momentos_corte("attack") if pj != null else []
		if cortes.size() >= 2:
			_iniciar_ataque(VEL_ANIM_GUERRERO, float(cortes[0]), _conectar)
			var total: float = _ataque
			for k in range(1, cortes.size()):
				get_tree().create_timer(total * float(cortes[k]), false).timeout.connect(_efecto_ataque.bind(_ataque_id, _conectar))
			return
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
		_v_avance = v_base("run") * vel
		_mover_paso(_dir_hacia(jugador.position, delta) * _v_avance * delta, false, true)
	elif dist < ARQUERO_MIN:
		_carga = 0.0
		moviendo = 1
		_v_avance = (v_base("run") if es_goblin else VEL_PATRULLA * 1.6) * vel
		if not _mover_paso(-mirada * _v_avance * delta):
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


## Arquero de puesto (`fijo`): se queda donde está, mira al jugador mientras lo ve (hasta ARQUERO_FIJO_ALCANCE, con línea libre) y dispara con el mismo ritmo que el
## arquero normal. Si lo pierde de vista deja de cargar y espera.
func _ia_arquero_fijo(delta: float) -> void:
	moviendo = 0
	var d: Vector3 = jugador.position - position if jugador != null and is_instance_valid(jugador) else Vector3.ZERO
	d.y = 0.0
	var ve: bool = jugador != null and is_instance_valid(jugador) and not jugador.muerto and d.length() <= ARQUERO_FIJO_ALCANCE \
		and Terreno3D.linea_libre(position, jugador.position)
	if jugador != null and is_instance_valid(jugador):
		var v: Vector3 = (jugador.position - _pos_jug_prev) / maxf(delta, 0.0001)
		_vel_jug = _vel_jug.lerp(v, SUAVIZADO_VEL_JUGADOR) if objetivo != null else Vector3.ZERO
		_pos_jug_prev = jugador.position
	if not ve:
		objetivo = null
		_carga = 0.0
		return
	if objetivo == null:
		flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0), "!", Color(1, 0.85, 0.2))
		Sfx3D.play(self, snd_alerta)
		PlayLog.event("goblin_ve_al_jugador", {"distancia": snappedf(d.length(), 0.1), "fijo": true})
	objetivo = jugador
	if d.length() > 0.05:
		mirada = d.normalized()
	if _descanso > 0.0:
		_carga = 0.0
		return
	_carga += delta
	if _carga >= PREPARAR_FLECHA:
		_carga = 0.0
		_descanso = DESCANSO_FLECHA
		_iniciar_ataque(VEL_ANIM_ARQUERO * ARQUERO_FIJO_RAFAGA, pj.momento_golpe("attack"), _soltar_flecha)


## Hacia dónde apuntar para acertar a quien se mueve: donde estará cuando llegue la flecha, a la velocidad que se le ha visto (una pasada de refinamiento: la distancia cambia al adelantarse).
func _con_adelanto(origen: Vector3, destino: Vector3) -> Vector3:
	var avance := Vector3(_vel_jug.x, 0.0, _vel_jug.z)
	var t: float = maxf(origen.distance_to(destino) / VEL_FLECHA, 0.1)
	t = maxf(origen.distance_to(destino + avance * t) / VEL_FLECHA, 0.1)
	return destino + avance * t


## Lanza la animación de ataque entera y programa el golpe/la flecha en su momento. Hasta que acaba no se mueve.
func _iniciar_ataque(vel_anim: float, momento: float, efecto: Callable) -> void:
	var dur: float = pj.duracion("attack")
	if dur <= 0.0:
		dur = T_ANIM_ATAQUE
		vel_anim = 1.0
		momento = 0.3
	# C3: entre el aviso y el golpe pasan al menos AvisoAtaque3D.T_MIN s. Si el clip golpea antes (un modelo sin clip de ataque: 0,24 s), se reproduce más despacio.
	# La flecha no lo necesita: a lo que tarda en soltarla se suma el vuelo.
	# 28/10: el clip se reproduce a vel_anim × ritmo (Pj3D.ritmo): lo que tarda de verdad es dur / (vel_anim · ritmo). `_ataque_vel` guarda solo vel_anim: el ritmo lo pone Pj3D.
	var r: float = ritmo()
	if AVISAR_ATAQUES and efecto != _soltar_flecha and dur / (vel_anim * r) * momento < AvisoAtaque3D.T_MIN:
		vel_anim = dur * momento / (AvisoAtaque3D.T_MIN * r)
	var total: float = dur / (vel_anim * r)
	_ataque = total
	_t_anim = total
	_ataque_vel = vel_anim
	anim_orden = "attack"
	_ataque_id += 1
	_golpe_pendiente = true
	get_tree().create_timer(total * momento, false).timeout.connect(_efecto_ataque.bind(_ataque_id, efecto))
	_avisar_ataque(efecto, total * momento)
	PlayLog.event("goblin_ataca", {"duracion": snappedf(total, 0.01), "efecto_en": snappedf(total * momento, 0.01)})


func _efecto_ataque(id: int, efecto: Callable) -> void:
	if id == _ataque_id:
		_golpe_pendiente = false
		efecto.call()
		_aviso = null                     # el aviso acaba solo en su instante (o lo fijó la flecha y vuela con ella): cancelar el ataque ya no lo toca


## C3: saca el aviso del ataque que empieza, con la MISMA zona que comprueba su golpe y el mismo tiempo (`t_golpe` s hasta el golpe):
##   · guerrero y asesino (`_conectar`): un círculo de radio RANGO_ATAQUE + 0,5 alrededor de él;
##   · elemental (`_golpe_elemental`): el rectángulo del puñetazo, delante de él (ELEM_ALCANCE_GOLPE × ELEM_ANCHO_GOLPE a cada lado, desde 0,3 por detrás);
##   · arquero (`_soltar_flecha`): un círculo de RADIO_IMPACTO_FLECHA que sigue a la jugadora mientras tensa y se queda donde suelta (`_soltar_flecha` lo fija con el vuelo).
## El asesino da dos cortes: el aviso marca el primero (el segundo solo cuenta si el primero falla).
func _avisar_ataque(efecto: Callable, t_golpe: float) -> void:
	_quitar_aviso()
	if not AVISAR_ATAQUES or mundo == null or not is_inside_tree():
		return
	if efecto == _soltar_flecha:
		if jugador == null or not is_instance_valid(jugador):
			return
		var t_vuelo: float = maxf(position.distance_to(jugador.position) / VEL_FLECHA, 0.1)
		_aviso = AvisoAtaque3D.circulo(mundo, jugador.position, RADIO_IMPACTO_FLECHA, t_golpe + t_vuelo, self)
		_aviso.seguir(jugador)
	elif efecto == _golpe_elemental:
		var k: float = _k_ref()
		_aviso = AvisoAtaque3D.rectangulo(mundo, position, mirada, ELEM_ALCANCE_GOLPE * k, ELEM_ANCHO_GOLPE * k, t_golpe, self, 0.3)
	else:
		_aviso = AvisoAtaque3D.circulo(mundo, position, RANGO_ATAQUE + 0.5, t_golpe, self)
	avisos_dados += 1
	_anticipar()


## Gamefeel (28/10): al empezar el aviso el cuerpo se ENCOGE un instante (coge impulso) y vuelve: el aviso se lee también en el enemigo, no solo en el suelo.
func _anticipar() -> void:
	if not Sensacion3D.ACTIVA or elemental or pj == null or not is_instance_valid(pj):
		return
	_cancelar_squash()
	_tw_squash = create_tween()
	_tw_squash.tween_method(_poner_squash, Vector3.ONE, ANTICIPA_ESCALA, 0.12).set_ease(Tween.EASE_OUT)
	_tw_squash.tween_method(_poner_squash, ANTICIPA_ESCALA, Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _quitar_aviso() -> void:
	if _aviso != null and is_instance_valid(_aviso):
		_aviso.cancelar()
	_aviso = null


## Golpe, parálisis, hielo o muerte: la animación se corta y el golpe/flecha pendiente ya no sale.
func _cancelar_ataque() -> void:
	if _golpe_pendiente:
		_quitar_aviso()
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
	if fijo:
		destino = _con_adelanto(origen, destino)
	var bloqueada: bool = not Terreno3D.linea_libre(position, jugador.position)
	var t_vuelo: float = maxf(origen.distance_to(destino) / VEL_FLECHA, 0.1)
	if _aviso != null and is_instance_valid(_aviso):
		if bloqueada:
			_aviso.cancelar()                                   # no va a llegar: que no avise de un golpe que no existe
		else:
			_aviso.fijar(Vector3(destino.x, jugador.position.y, destino.z), t_vuelo)     # C3: cae donde la suelta, cuando llega
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
	var t: float = t_vuelo
	var tw: Tween = flecha.create_tween()
	if not bloqueada:
		# Por tramos: así nota la burbuja del jugador (si hay lanzador) y cualquier llama que cruce (A2). Sin lanzador antes volaba de golpe.
		tw.tween_method(_vuelo_flecha.bind(flecha, origen, destino), 0.0, 1.0, t)
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
	else:
		# A2: la flecha es inflamable. Cruzar una llama (fogata, brasero, algo ardiendo) la deja ardiendo; ardiendo, prende lo inflamable que toca.
		if not flecha.has_meta("ardiendo") and _flecha_toca_fuego(p):
			_encender_flecha(flecha)
		if flecha.has_meta("ardiendo"):
			_prender_en(p, RADIO_FLECHA_FUEGO)


## ¿Toca la flecha, en `p`, algo que ESTÁ ARDIENDO y pasa la llama? Objetos (fogata/brasero encendidos, seto en llamas…) y otros enemigos ardiendo.
func _flecha_toca_fuego(p: Vector3) -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if is_instance_valid(n) and n is Reactivo3D and (n as Reactivo3D).emite_fuego_por_contacto() and (n as Reactivo3D).toca_punto(p, RADIO_FLECHA_FUEGO):
			return true
	for n in get_tree().get_nodes_in_group("combate3d"):
		if n == self or not is_instance_valid(n) or not (n is Combate3D) or not (n as Combate3D).esta_ardiendo():
			continue
		var otro: Combate3D = n
		var q: Vector3 = otro._pos_mundo()
		if Vector2(p.x - q.x, p.z - q.z).length() <= otro._radio_cuerpo() + RADIO_FLECHA_FUEGO and p.y >= q.y and p.y <= q.y + otro.altura:
			return true
	return false


## Deja la flecha ardiendo: lo dice la marca `ardiendo` (la leen `_flecha_llega` y las pruebas) y se ve naranja con brillo.
func _encender_flecha(flecha: Node3D) -> void:
	flecha.set_meta("ardiendo", true)
	if flecha is MeshInstance3D and (flecha as MeshInstance3D).material_override is StandardMaterial3D:
		var m: StandardMaterial3D = (flecha as MeshInstance3D).material_override
		m.albedo_color = COLOR_FLECHA_ARDIENDO
		m.emission_enabled = true
		m.emission = COLOR_FLECHA_ARDIENDO
		m.emission_energy_multiplier = 2.0


## Prende lo inflamable (objetos) cuyo cuerpo toca el punto `p` con un radio `radio`. Lo usa la flecha ardiendo, en vuelo y al impactar.
func _prender_en(p: Vector3, radio: float) -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if is_instance_valid(n) and n is Reactivo3D and (n as Reactivo3D).can_burn() and (n as Reactivo3D).toca_punto(p, radio):
			(n as Reactivo3D).ignite(p)


func _flecha_llega(flecha: Node3D, destino: Vector3, bloqueada: bool) -> void:
	var ardiendo: bool = false
	if is_instance_valid(flecha):
		var parada: bool = flecha.has_meta("parada")
		ardiendo = flecha.has_meta("ardiendo")
		flecha.queue_free()
		if parada:
			return
	if bloqueada or jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return
	var dx: float = jugador.position.x - destino.x
	var dz: float = jugador.position.z - destino.z
	if Vector2(dx, dz).length() <= RADIO_IMPACTO_FLECHA and absf(jugador.position.y + 0.8 - destino.y) < Terreno3D.ALTO_NIVEL:
		jugador.recibir_dano(DANO_FLECHA, position)
		if ardiendo:
			# A2: el impacto de una flecha ardiendo QUEMA. El jugador aún no tiene quemadura propia: si algún día define `quemar(segundos)`, se llama aquí.
			if jugador.has_method("quemar"):
				jugador.call("quemar", QUEMA_CONTACTO)
			flecha_ardiente_impacta.emit(jugador)
			_prender_en(destino, RADIO_FLECHA_FUEGO)


func _conectar() -> void:
	if muerto or jugador == null or not is_instance_valid(jugador) or stun_timer > 0.0 or interrupcion > 0.0 \
			or congelado > 0.0:
		return
	if _dist(jugador.position) <= RANGO_ATAQUE + 0.5 and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9:
		jugador.recibir_dano(DANO_GOLPE, position)


func _dist(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()


## D2: hacia dónde andar para llegar a `meta`. Si la línea recta está libre (la misma que usa para VER), va derecho como siempre. Si no (un muro, un río, un
## escalón de dos niveles en medio), sigue la ruta por casillas de `Caminos3D`: la recalcula cada PERIODO_CAMINO s, o al cambiar de casilla la meta, o si se sale
## de su ruta. Sin ruta (no hay camino, o es el elemental, que no cabe por los pasos de una casilla) devuelve la recta, que es lo que hacía antes.
func _dir_hacia(meta: Vector3, delta: float) -> Vector3:
	var recto: Vector3 = meta - position
	recto.y = 0.0
	if recto.length() < 0.0001:
		return Vector3.ZERO
	recto = recto.normalized()
	if elemental or (Terreno3D.linea_libre(position, meta) and Caminos3D.recta_andable(position, meta)):
		_ruta.clear()
		return recto
	var c_ini: Vector2i = Terreno3D.celda_de(position)
	var c_fin: Vector2i = Terreno3D.celda_de(meta)
	_t_ruta -= delta
	var pos_en_ruta: int = _ruta.find(c_ini)
	# Sin ruta (no la hay) también espera al periodo: si no, la buscaría en cada fotograma.
	if _t_ruta <= 0.0 or c_fin != _ruta_meta or (pos_en_ruta == -1 and not _ruta.is_empty()):
		_ruta = Caminos3D.camino(c_ini, c_fin)
		_ruta_meta = c_fin
		_t_ruta = PERIODO_CAMINO
		rutas_calculadas += 1
		pos_en_ruta = 0
	if _ruta.is_empty():
		return recto
	if pos_en_ruta == -1 or pos_en_ruta >= _ruta.size() - 1:
		return recto                       # ya está en la última casilla: el tramo final es en recta
	var sig: Vector3 = Terreno3D.centro_de(_ruta[pos_en_ruta + 1])
	var d: Vector3 = sig - position
	d.y = 0.0
	return d.normalized() if d.length() > 0.0001 else recto


## ¿Ve al jugador? Distancia + línea de visión (árboles, muros y torres de tierra la cortan).
func _ve(radio: float) -> bool:
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return false
	if _dist(jugador.position) > radio:
		return false
	return Terreno3D.linea_libre(position, jugador.position)


## Un goblin no sube ni nada: casillas a nivel 0 y que no sean agua. Desliza por los ejes.
## `empujado` = el paso lo da un empuje (no sus piernas): entonces el agua honda deja de ser pared y lo que lo lleve dentro lo hunde (ver `_puede_estar`).
## `por_ruta` (D2) = el paso sigue la ruta de `Caminos3D`: entonces puede cambiar de nivel (±1) hacia una casilla DE LA RUTA, que es lo que la ruta ya ha
## decidido que se puede subir/bajar. Sin eso, el goblin seguiría sin poder escalar un escalón aunque el camino pasara por él.
func _mover_paso(paso: Vector3, empujado: bool = false, por_ruta: bool = false) -> bool:
	if paso.length() < 0.0001:
		return false
	for v in [paso, Vector3(paso.x, 0.0, 0.0), Vector3(0.0, 0.0, paso.z)]:
		var vv: Vector3 = v
		if vv.length() < 0.0001:
			continue
		var destino: Vector3 = position + vv
		if _puede_estar(destino, empujado, por_ruta):
			position.x = destino.x
			position.z = destino.z
			return true
	return false


func _puede_estar(p: Vector3, empujado: bool = false, por_ruta: bool = false) -> bool:
	return _puede_estar_desde(position, p, empujado, por_ruta)


## 28/10 · A2: `_puede_estar` mirando desde una posición cualquiera `desde` (la del cuerpo, o la simulada de `prever_empuje`): una sola regla para el paso real y la previsión.
func _puede_estar_desde(desde: Vector3, p: Vector3, empujado: bool = false, por_ruta: bool = false) -> bool:
	var c: Vector2i = Terreno3D.celda_de(p)
	# A3: un cuerpo EMPUJADO entra en el agua honda no helada (no hay suelo que lo frene: por eso se hunde en `_ajustar_al_suelo`). Con sus piernas, nunca:
	# por eso esta salida va antes de las comprobaciones de suelo y solo existe con `empujado`. Misma regla de agua que el jugador usa para nadar (`_es_agua_honda`).
	if empujado and c != Terreno3D.celda_de(desde) and _es_agua_honda(c):
		return true
	if elemental and not _cabe_con_cuerpo(p, desde):
		return false
	# 20/10 (Pablo: colisiones cercanas al modelo y no a la cuadrícula): como el jugador, en una casilla bloqueada cuya forma real se conoce («parcial»: un barril,
	# una roca, un arbusto) solo choca contra esa forma, no contra la casilla entera. Sin forma conocida (agua, muro, telaraña…) sigue siendo la casilla.
	var parcial: bool = Terreno3D.es_parcial(c)
	if c == Terreno3D.celda_de(desde):
		if parcial and Terreno3D.choca_huella(c, p) and not Terreno3D.choca_huella(c, desde):
			return false
		return Terreno3D.en_mapa(c)
	if parcial and Terreno3D.choca_huella(c, p):
		return false
	# Se mueve por SU nivel (el de la casilla donde está): a nivel 0 es lo de siempre; en una terraza (Terra Fina) recorre la
	# terraza y puede bajar, pero no sube: pisable con `sube = false` y tope = su nivel.
	var nivel: int = Terreno3D.altura_en(Terreno3D.celda_de(desde))
	# D2: siguiendo la ruta, una casilla de la ruta que está a ±1 nivel SÍ se pisa (misma regla de arista que usó el A*). La altura de los pies la pone
	# `_ajustar_al_suelo` (sube de golpe con el bloque; baja a 6 u/s), por eso aquí no se exige el `y_pies` de abajo.
	if por_ruta and not elemental and _ruta.has(c):
		var nc: int = Terreno3D.altura_en(c)
		if absi(nc - nivel) <= Caminos3D.SALTO_MAX and Terreno3D.pisable(c, nc, false, nc, false, parcial):
			return true
	if not Terreno3D.pisable(c, nivel, false, nivel, false, parcial):
		return false
	# Un escalón (del puente al suelo) se sube; un bloque no.
	return absf(Terreno3D.y_pies(c) - desde.y) <= 0.6


## 9.13: el elemental mide 2,5 u de alto y su cuerpo (cápsula) tiene un radio de ~1 u, casi media casilla (la casilla mide 2,3).
## `_puede_estar` solo miraba la casilla del CENTRO, así que el centro podía llegar al borde de una pared y el cuerpo se le metía
## un radio entero en los árboles del borde (medido: el modelo con los brazos abiertos mide ±1,2 u). Aquí se comprueban cuatro
## puntos a un radio del centro (±X, ±Z): si alguno entra en una casilla NUEVA que no se pisa, no se avanza. Si ya estaba
## metido (un nivel que lo coloca pegado a una pared), se le deja salir: solo se rechaza ENTRAR en una casilla bloqueada.
## Solo el elemental: los goblins miden 0,32 de radio y no tenían el problema. Efecto de diseño: con 2,06 u de cuerpo, un hueco
## de una casilla (2,3) como la puerta de la sala solo lo cruza si va centrado; en la práctica se queda en su sala.
func _cabe_con_cuerpo(p: Vector3, desde: Vector3 = Vector3.INF) -> bool:
	if desde == Vector3.INF:
		desde = position
	var r: float = 0.7 * altura / ELEM_ALTO_REF
	for o in [Vector3(r, 0.0, 0.0), Vector3(-r, 0.0, 0.0), Vector3(0.0, 0.0, r), Vector3(0.0, 0.0, -r)]:
		var nueva: Vector2i = Terreno3D.celda_de(p + o)
		if nueva == Terreno3D.celda_de(desde + o):
			continue                                   # no cambia de casilla por ese lado: nada que comprobar
		if not Terreno3D.pisable(nueva, 0, false, 0, false):
			return false
	return true


## ¿Es agua HONDA para hundirse? La regla con la que el jugador nada (`Terreno3D.se_nada`: agua de verdad, no helada, y no el canal de ruinas que se vadea) más,
## si hay simulación, que la profundidad llegue a UMBRAL_NADO (una cuenca con un charquito es `es_agua` pero no se nada). Un puente («b») nunca es agua.
func _es_agua_honda(c: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.letra_de(c) == "b" or not Terreno3D.se_nada(c):
		return false
	return Terreno3D.agua_sim == null or Terreno3D.agua_sim.se_nada_en(c)


func _ajustar_al_suelo(delta: float) -> void:
	var c: Vector2i = Terreno3D.celda_de(position)
	if Terreno3D.es_agua(c):
		# A3: agua honda sin hielo bajo los pies (lo empujaron, el hielo se derritió, el agua subió): se hunde. El hielo sigue sosteniendo (con él `es_agua` es falso).
		if _es_agua_honda(c):
			_hundirse(c)
			return
		# Agua baja (no se nada): se le fue el suelo (hielo derretido): vuelve a su puesto, sin daño
		position = Vector3(casa.x, Terreno3D.y_pies(Terreno3D.celda_de(casa)), casa.z)
		estado = "patrulla"
		objetivo = null
		return
	if Terreno3D.altura_en(c) > 0:
		# Le han levantado un bloque debajo: sube con él
		position.y = Terreno3D.y_pies(c)
		return
	position.y = move_toward(position.y, Terreno3D.y_pies(c), 6.0 * delta)


## Pasa de volar a levantarse y de levantarse a nada cuando acaba cada clip (el tiempo se para mientras está congelado, como su animación).
func _avanzar_empujado(delta: float) -> void:
	if _fase_empuje == FASE_NINGUNA or congelado > 0.0:
		return
	_t_fase_empuje -= delta
	if _t_fase_empuje > 0.0:
		return
	if _fase_empuje == FASE_VOLANDO:
		_fase_empuje = FASE_LEVANTANDOSE
		_t_fase_empuje = pj.duracion("levantarse") if pj != null and is_instance_valid(pj) else 0.0
		pj.animacion_actual = ""
	else:
		_fase_empuje = FASE_NINGUNA
		_t_fase_empuje = 0.0


func _animar() -> void:
	pj.ritmo = ritmo()          # un solo punto: Pj3D multiplica por él todos los clips que no pidan lo contrario
	if _fase_empuje != FASE_NINGUNA:
		anim_orden = ""                 # el "hit" de este mismo golpe no pisa el vuelo
		if congelado > 0.0:
			pj.set_velocidad_animacion(0.0)
			return
		pj.set_velocidad_animacion(1.0, false)          # el vuelo va con la física del empuje: sin ritmo
		pj.jugar("empujado" if _fase_empuje == FASE_VOLANDO else "levantarse", true)
		if _fase_empuje == FASE_LEVANTANDOSE:
			pj.mirar(_dir_previa, 0.02)         # se gira poco a poco a su postura de antes mientras se incorpora
		return
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
		elif orden == Escudo3D.ROL_MANO_QUEMADA:
			pj.set_velocidad_animacion(1.0)
			pj.jugar(orden, true)
			_t_anim = maxf(_t_anim, pj.duracion(orden) / ritmo())        # sin esto el aturdimiento lo pasaría a reposo en el fotograma siguiente
		else:
			pj.set_velocidad_animacion(1.0)
			pj.jugar(orden)
		if orden == "hit":
			_t_anim = maxf(_t_anim, 0.35 / ritmo())
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
	var clip_andar: String = "run" if moviendo == 2 else "walk"
	if es_goblin and moviendo > 0:
		# 28/10 · sin patinar: el clip va a lo que pide el suelo (u/s reales, con ritmo y estados) · duración / zancada medida (ZANCADA_GOBLIN). Sin ritmo extra: ya va incluido en `_v_avance`.
		clip_andar = "run" if _v_avance > umbral_correr() else "walk"
		var dur_c: float = pj.duracion(clip_andar)
		var zanc: float = zancada_goblin(clip_andar)
		if dur_c > 0.0 and zanc > 0.0:
			pj.set_velocidad_animacion(clampf(_v_avance * dur_c / zanc, CLIP_ANDAR_MIN, CLIP_ANDAR_MAX), false)
	match moviendo:
		0:
			pj.jugar("idle")
		_:
			pj.jugar(clip_andar)
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
	defensa = Dano.DEF_ELEMENTAL
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

## Cae al agua honda en la casilla `c`: lo mismo que morir, pero ahogado (ver `_morir(true)`). Lo llama `_ajustar_al_suelo`.
func _hundirse(c: Vector2i) -> void:
	if muerto:
		return
	_punto_hundido = Vector3(position.x, Terreno3D.superficie_agua(c), position.z)
	_empuje = Vector3.ZERO
	_morir(true)


## `ahogado`: muere en el agua (A3): sin botín, no cae tumbado sino que se hunde bajo la superficie, avisa a Mundo3D para las burbujas y emite `hundido`.
func _morir(ahogado: bool = false) -> void:
	if muerto:
		return
	_quitar_aviso()
	if quemando > 0.0:
		_reaccionar("apagado_agua" if ahogado else "consumido")     # muere ardiendo: que se corten las llamas del cuerpo (el agua las apaga)
	muerto = true
	_fase_empuje = FASE_NINGUNA                       # muerto o hundido en pleno vuelo: no se levanta
	_t_fase_empuje = 0.0
	se_hundio = ahogado
	if pj != null:
		pj.apagar_sombra()      # V5: sin mancha en el suelo bajo un cuerpo caído o hundiéndose
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
	var dur_hundir: float = 0.0
	if ahogado:
		dur_hundir = _animar_ahogo()
	else:
		Jugador3D.una_vez(pj, "death")
	if not elemental:
		Sfx3D.play(self, snd_muere)
	var lista: Variant = mundo.get("_goblins")
	if lista is Array:
		(lista as Array).erase(pj)
	PlayLog.event("goblin_muere", {"nombre": nombre, "celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y], "ahogado": ahogado})
	Estado.i().enemigo_muerto.emit(Vector2(position.x, position.z), nombre)
	Sensacion3D.muerte(self)                          # gamefeel lote 2: temblor y, si era el último de la sala, cámara lenta
	if ahogado:
		_hundir_modelo(dur_hundir)
		return
	if oro > 0:
		Botin3D.soltar(mundo, jugador, oro, position)
	if not elemental and botin_goblin:
		BotinGoblin.soltar(mundo, position)       # materiales (colmillo): docs/MATERIALES_CUEVA.md
	var tw: Tween = create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(pj, "scale", pj.scale * 0.01, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(pj):
			pj.queue_free()
		queue_free())


## Pone el clip «Drowning» si el modelo lo trae Y el árbol de animación lo admite (el grafo reducido de los enemigos hoy no: ver el encargo del informe). Si no, la pose de
## muerte de siempre. Devuelve cuánto debe durar el hundimiento: lo que dura el clip (así la cabeza se pierde justo al acabar el forcejeo) o TIEMPO_HUNDIMIENTO sin clip.
## Ya no se espera al 60 % del clip: se empieza a bajar en el acto y es la curva (HUNDIMIENTO_CURVA) la que hace que al principio apenas se hunda.
func _animar_ahogo() -> float:
	if pj == null or not is_instance_valid(pj):
		return TIEMPO_HUNDIMIENTO
	var dur: float = pj.duracion(CLIP_AHOGARSE)
	if dur > 0.0:
		pj.animacion_actual = ""
		pj.set_velocidad_animacion(1.0, false)            # el hundimiento dura lo que el clip (así lo cuenta `dur`): sin ritmo
		pj.jugar(CLIP_AHOGARSE, true)
		if pj.animacion_actual == CLIP_AHOGARSE:
			return dur
	Jugador3D.una_vez(pj, "death")
	return TIEMPO_HUNDIMIENTO


## Altura relativa del hundimiento (0 = en la superficie, 1 = todo el recorrido) para el progreso `p` (0..1): curva potencial y, encima, rebotes de flotación
## que se apagan al final. Es función pura para poder medirla en las pruebas.
static func perfil_hundimiento(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return pow(p, HUNDIMIENTO_CURVA)


## Subida (en u, >= 0) por los rebotes de flotación en el progreso `p`: |seno| apagado con (1 - p), así nunca sube de la superficie y a p = 1 vale 0.
static func rebote_hundimiento(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return absf(sin(p * PI * HUNDIMIENTO_REBOTES)) * HUNDIMIENTO_REBOTE_ALTURA * (1.0 - p)


## El hundimiento en sí: avisa a Mundo3D («hundido», en la superficie, para las burbujas) y emite `hundido` UNA vez, en el contacto con el agua (no al final), y
## baja el modelo bajo el agua durante `duracion` s con la curva de arriba. El nodo no se libera hasta que acaba.
## Se mueve el modelo y no este nodo: `_physics_process` ya no corre (muerto) y es el que copiaba la posición. Sin botín.
func _hundir_modelo(duracion: float) -> void:
	texto_grande("¡Hundido!", COLORES["agua"], 0.1)
	duracion_hundimiento = maxf(duracion, 0.1)         # lo lee el Pipeline (`ReaccionesVfx3D.dura_hundimiento`): burbujas y sonido duran lo que el cuerpo tarda en bajar
	if Mundo3D.actual != null:
		Mundo3D.actual.avisar_impacto(_punto_hundido, AVISO_HUNDIDO, maxf(_radio_cuerpo(), 0.4) * 1.5)
	_reaccionar("hundido", _punto_hundido)          # A4: el mismo hecho que el aviso `impacto` de arriba (conviven: los usan consumidores distintos)
	hundido.emit(self)
	if pj == null or not is_instance_valid(pj):
		queue_free()
		return
	var y_ini: float = pj.position.y
	var y_fin: float = minf(_punto_hundido.y, y_ini) - altura - PROFUNDIDAD_EXTRA_HUNDIDO
	var modelo: Pj3D = pj
	var tw: Tween = create_tween()
	tw.tween_method(func(p: float) -> void:
		if is_instance_valid(modelo):
			modelo.position.y = lerpf(y_ini, y_fin, perfil_hundimiento(p)) + rebote_hundimiento(p),
		0.0, 1.0, maxf(duracion, 0.1))
	tw.tween_callback(func() -> void:
		if is_instance_valid(pj):
			pj.queue_free()
		queue_free())


## Moneda de oro que se recoge al pasar cerca. Gamefeel lote 2: al soltarse SALTA desde el cuerpo hasta su sitio (un arco con un botecito) y, ya en el suelo, si ella
## pasa a menos de RADIO_IMAN se IMANTA: vuela hacia ella acelerando y se recoge al llegar, con su «ting». Con `Sensacion3D.ACTIVA` = false, como antes: aparece en su sitio
## y se coge a menos de RADIO_COGER.
class Botin3D extends MeshInstance3D:
	const T_SALTO: float = 0.42          ## s del arco desde el cuerpo hasta donde se queda
	const ALTO_SALTO: float = 0.9        ## u que sube el arco
	const RADIO_IMAN: float = 2.4        ## u (en el plano) a las que empieza a ir hacia ella
	const ACEL_IMAN: float = 40.0        ## u/s² con que acelera hacia ella
	const VEL_IMAN_MAX: float = 14.0
	const RADIO_COGER: float = 1.1       ## u a las que se coge sin imán (el de siempre)
	const RADIO_LLEGA: float = 0.45      ## u a las que se coge cuando viene imantada
	var jugador: Jugador3D = null
	var cantidad: int = 10
	var imantada: bool = false
	var _t: float = 0.0
	var _base_y: float = 0.0
	var _vivo: bool = true
	var _t_salto: float = -1.0           ## < 0 = ya en su sitio
	var _desde: Vector3 = Vector3.ZERO
	var _hasta: Vector3 = Vector3.ZERO
	var _vel: float = 0.0

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
		b._hasta = pos + Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(0.2, 0.6))
		b._base_y = pos.y + 0.3
		if Sensacion3D.ACTIVA:
			b._desde = pos + Vector3(0.0, 0.6, 0.0)
			b._t_salto = 0.0
			b.position = b._desde
		else:
			b.position = b._hasta
		p_mundo.add_child(b)
		return b

	## ¿Está todavía saltando hacia su sitio? (las pruebas lo leen)
	func saltando() -> bool:
		return _t_salto >= 0.0

	func _process(delta: float) -> void:
		if not _vivo:
			return
		_t += delta
		rotate_y(delta * (2.0 if not imantada else 9.0))
		if _t_salto >= 0.0:
			_t_salto += delta
			var u: float = clampf(_t_salto / T_SALTO, 0.0, 1.0)
			var plano: Vector3 = _desde.lerp(_hasta, u)
			var arco: float = 4.0 * ALTO_SALTO * u * (1.0 - u)
			var bote: float = absf(sin(clampf((_t_salto - T_SALTO) / 0.18, 0.0, 1.0) * PI)) * 0.12
			position = Vector3(plano.x, lerpf(_desde.y, _base_y, u) + arco + bote, plano.z)
			if _t_salto >= T_SALTO + 0.18 or (_t_salto >= T_SALTO and _cerca_para_iman()):     # si ella ya está cerca, no espera al bote
				_t_salto = -1.0
				_t = 0.0
			return
		if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
			position.y = _base_y + sin(_t * 3.0) * 0.06
			return
		var hacia: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0) - position
		var d: float = Vector2(hacia.x, hacia.z).length()
		var misma_altura: bool = absf(jugador.position.y - _base_y) < 1.4
		if Sensacion3D.ACTIVA and misma_altura and (imantada or d < RADIO_IMAN):
			imantada = true
			_vel = minf(VEL_IMAN_MAX, _vel + ACEL_IMAN * delta)
			var paso: float = minf(_vel * delta, hacia.length())
			position += hacia.normalized() * paso
			if hacia.length() - paso <= RADIO_LLEGA:
				_coger()
			return
		position.y = _base_y + sin(_t * 3.0) * 0.06
		if d < RADIO_COGER and misma_altura:
			_coger()

	func _cerca_para_iman() -> bool:
		if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
			return false
		return Vector2(jugador.position.x - position.x, jugador.position.z - position.z).length() < RADIO_IMAN and absf(jugador.position.y - _base_y) < 1.4

	func _coger() -> void:
		_vivo = false
		Estado.i().dar_oro(cantidad)
		Combate3D.flotante(get_parent(), position + Vector3(0, 0.5, 0), "+%d oro" % cantidad, Color(1, 0.9, 0.4))
		if Sensacion3D.ACTIVA:
			Sfx.play(self, "moneda")
		PlayLog.event("oro", {"cantidad": cantidad, "total": Estado.i().oro})
		queue_free()

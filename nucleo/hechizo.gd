class_name Hechizo
extends RefCounted

## UN SOLO SITIO DONDE SE CONSTRUYE UN HECHIZO (HC1, 18/10; docs HECHIZO_CLASE.md).
##
## Datos puros, sin nodos: todos los parámetros de un hechizo con su valor por defecto (0, falso o vacío si no hay nada que decir). Se construyen
## con `Hechizo.construir(elemento, glifos, calidad)` en un orden fijo:
##   1. valores por defecto (los de los `var` de abajo)
##   2. modificadores del elemento (los campos de RuneData de hoy traducidos + `RuneData.modificadores`: duraciones de estado, fuerza del golpe…)
##   3. modificadores de los glifos (`Sigils.GLIFOS`): primero fija y sumas, después multiplicaciones
##   4. topes, y después los mínimos («suelos», como el de la barrera)
##   5. derivados: forma, niveles, coste, recarga, cast point (no se tocan a mano)
## Un modificador es `{campo, op, valor, tope, desde}` (ver Sigils.GLIFOS). Un glifo o un elemento nuevo es solo datos.
##
## UNIDADES (19/10, docs/ESPEC_HECHIZO.md §0.1): 1 casilla = 1 m. Todo lo que mide longitud va en METROS-CASILLA (semiejes, distancia_max, elevacion, altura_salida, radio_explosion, separacion…)
## y las velocidades en m/s. La conversión a unidades del motor (× `Terreno3D.casilla`) se hace SOLO en `HechizoVivo`, al ejecutar.
##
## HC1 es REFACTORIZACIÓN: aún no lo lee nadie. Convive con `Sigils.aplicar_v2` + `RuneData` + `Receta3D`, y `prueba_hechizo` comprueba que da los mismos números.

const EPS: float = 0.0001

## Los campos, por grupos, en el orden en que los enseñará el laboratorio (HC5). [nombre, grupo].
## Los campos nuevos de la ESPEC (19/10) se han metido en los grupos de siempre para no tocar el orden del lab: tiempo → movimiento, física → materia.
const CAMPOS: Array = [
	["semiejes", "forma"], ["grosor_min", "forma"], ["copias", "forma"], ["separacion", "forma"], ["dispersion", "forma"], ["crece", "forma"], ["escala_nace", "forma"], ["solidez", "forma"], ["resuena", "forma"],
	["velocidad", "movimiento"], ["aceleracion", "movimiento"], ["gravedad", "movimiento"], ["distancia_max", "movimiento"], ["elevacion", "movimiento"],
	["persiste", "movimiento"], ["permanencia", "movimiento"], ["retardo", "movimiento"], ["intervalo", "movimiento"],
	["altura_salida", "movimiento"], ["impulso_salida", "movimiento"], ["rebotes", "movimiento"], ["elasticidad", "movimiento"], ["retorna", "movimiento"], ["busca", "movimiento"], ["en_punto", "movimiento"],
	["dano", "combate"], ["dano_periodico", "combate"], ["potencia", "combate"], ["empuje", "combate"], ["fuerza_golpe", "combate"], ["perfora", "combate"], ["radio_explosion", "combate"], ["golpea_lanzador", "combate"],
	["quema", "estados"], ["moja", "estados"], ["congela", "estados"], ["congela_mojado", "estados"], ["aturde", "estados"],
	["ralentiza", "estados"], ["ralentiza_fuerza", "estados"], ["interrumpe", "estados"], ["veneno", "estados"], ["veneno_dps", "estados"], ["intensidad_estado", "estados"], ["deja", "estados"],
	["estado_materia", "materia"], ["pisable", "materia"], ["densidad", "materia"], ["temperatura", "materia"], ["humedad", "materia"], ["conductividad", "materia"],
	["choca_con", "choque"], ["color", "aspecto"], ["estela", "aspecto"], ["efecto_impacto", "aspecto"],
	["eventos", "eventos"],
]

## Los eventos que dispara un hechizo vivo (HC4, §2.3; H2, 29/10) y el catálogo CERRADO de acciones que puede llevar cada uno. Todo lo demás es datos: añadir un efecto
## nuevo a un glifo es una línea en su lista de modificadores (`op: "anade"` sobre `eventos.<nombre>`), nunca código por combinación.
## El «final» del hechizo son TRES eventos, y un hechizo dispara como mucho UNO por tramo (`HechizoVivo._terminar`):
##   al_impactar   un proyectil se paró por GOLPE (`motivo_fin` = golpe); salta después del `al_golpear` del objeto que lo paró
##   al_detenerse  un proyectil se paró SIN golpear: muro, suelo, alcance, tiempo, frenado o retorno
##   al_expirar    EXTINCIÓN: acaba la vida de lo que nace quieto (persiste + permanencia, o el haz). Un proyectil ya no lo dispara al pararse
## Todas las acciones de un evento se ordenan con `ordenar_acciones` (paso y orden de tabla del glifo que las puso, ver `_aplicar`); el `emitir_pulso` de ᚱ es una acción más del catálogo.
const EVENTOS: PackedStringArray = ["al_nacer", "al_golpear", "al_matar", "al_impactar", "al_detenerse", "al_expirar", "al_rebotar", "al_viajar"]
const ACCIONES: PackedStringArray = ["danar_area", "crear_hijo", "estado_suelo", "sonido", "vfx", "emitir_pulso"]
## Los tres eventos de final y el valor fino de `Sigils.GLIFOS[…]["momento"]` que corresponde a cada uno.
const EVENTOS_FINAL: PackedStringArray = ["al_impactar", "al_detenerse", "al_expirar"]
const MOMENTO_DE_FINAL: Dictionary = {"al_impactar": "impacto", "al_detenerse": "detencion", "al_expirar": "extincion"}
## `choca_con` es una máscara de bits; 0 = «la de siempre» = mundo + enemigos.
const CHOCA_MUNDO: int = 1
const CHOCA_ENEMIGOS: int = 2
## Límites de HC4 (§2.3): profundidad de hijos y hechizos vivos por lanzamiento.
const MAX_PROFUNDIDAD: int = 2
const MAX_VIVOS: int = 32
## Límites globales de seguridad (ESPEC_HECHIZO §1.9). Se aplican al final de `construir()` y de `con()`: ni los glifos ni el laboratorio pueden saltárselos.
const LIM_SEMIEJE_HORIZONTAL: float = 3.0     ## m (6 m de ancho o fondo total)
const LIM_SEMIEJE_ALTO: float = 2.0           ## m (4 niveles: el límite físico; 30/10, antes 1,0 = 2 niveles)
const LIM_ELEVACION: float = 2.0              ## m
const LIM_DISTANCIA: float = 8.0              ## m (la flecha llega a 6 con 5 glifos)
const LIM_VIDA_S: float = 25.0                ## s: persiste + permanencia
const LIM_COPIAS: int = 8                     ## el glifo topa en 4; el laboratorio puede subir a 8
const MAX_GLIFOS: int = 6                     ## glifos máximos por hechizo (ESPEC §1.9): el mismo número que los huecos de la página del libro. Lo aplican el libro y el lab (Mayús+L lo quita); `construir()` no cuenta glifos.
## Velocidad (m/s) a la que se desplaza algo con `distancia_max` > 0 pero `velocidad` = 0: la de los volúmenes que viajaban por tandas (8 casillas/s).
const VELOCIDAD_VIAJE_DEFECTO: float = 8.0
## RAYO («haz», 21/10, decisión de Pablo): ᛁ `linea` + elemento = un haz recto desde la mano hacia donde apunta; el MURO es solo de `barrera`. «Rayo» es también el elemento relámpago (ᛊ):
## en el código la forma se llama `haz`. Es INSTANTÁNEO (aplica el golpe del elemento a todo el recorrido al nacer) y se queda dibujado `HAZ_DURA_S` s (+ `permanencia`). Se para en casillas
## sólidas y en barreras. Alcance: `HAZ_ALCANCE_BASE` m con una ᛁ y +`HAZ_ALCANCE_POR_GLIFO` por cada ᛁ sucesiva (X o Z da igual), tope `HAZ_ALCANCE_MAX`. Con barrera es un muro y con flecha un
## proyectil largo: no hay haz. El ancho lo pone el dibujo (`HAZ_ANCHO`); el recorrido es de una casilla de ancho.
const HAZ_ALCANCE_BASE: float = 3.0           ## m con una sola ᛁ
const HAZ_ALCANCE_POR_GLIFO: float = 1.0      ## m más por cada ᛁ sucesiva
const HAZ_ALCANCE_MAX: float = 6.0            ## m (≤ LIM_DISTANCIA)
const HAZ_ANCHO: float = 0.35                 ## m de grosor del dibujo (el golpe cubre la casilla entera)
const HAZ_DURA_S: float = 0.9                 ## s que se ve el haz (+ `permanencia`)
## Tamaño EN VUELO de un proyectil (hechizo con `velocidad` > 0, o sea el de la flecha) respecto a sus semiejes. Decisión de Pablo (21/10, tras el playtest): el proyectil de
## «flecha + elemento» medía 0,5 casillas de ancho (≈ 1,15 u, más que la chibi) y era demasiado grande; ahora mide la mitad. AJUSTABLE: 1.0 lo deja como estaba.
## Vive aquí y no en `RADIO_BASE_V2` porque de ese salen la barrera, el muro, la columna y el paso de cada glifo de eje, y el rasterizado de casillas de lo que está quieto.
## Solo escala lo que se VE volar (VFX del proyectil) y lo que CHOCA (radio de acierto, `HechizoVivo._radio_u`): los semiejes, el coste, la forma y las zonas/explosiones no cambian.
const ESCALA_PROYECTIL: float = 0.5
## Lo que dura una `permanencia` o `persiste` ya multiplicada por la calidad también pasa por el límite de arriba.
## Resistencia de una barrera por cada ×1 de solidez: la `AGUANTE_SOLIDEZ_V2` de HechizoVivo (30), que ahora vive aquí (ESPEC §1.4 dice «base 10»: se mantiene 30 para no cambiar lo que aguanta hoy).
const RESISTENCIA_POR_SOLIDEZ: float = 30.0
## Altura de la mano sobre el suelo en u (la de siempre para un proyectil): `altura_salida` la guarda en metros (÷ casilla).
const ALTURA_MANO_U: float = 0.9
## Propiedades de solo lectura (derivadas): `copiar()` no las copia.
const SOLO_LECTURA: PackedStringArray = ["semiejes", "semiejes_glifos", "volumen", "superficie", "masa", "resistencia", "flota", "anclado", "protege", "se_expande", "se_repite", "rebota", "haz", "alcance_haz", "persistente", "solido_quieto"]
## 24/10 (decisión de Pablo): un SÓLIDO QUIETO (tierra o hielo que no es haz ni viaja) nace donde apuntas (`en_punto`) y no en la casilla de quien lo lanza. Medido con
## `escenario_libro_combinaciones`: 36 recetas de tierra/hielo con solo ᛏ, ᚢ o ᚱ nacían en la casilla de la jugadora, `Lanzador3D.construir_tierra` las rechazaba («encima del jugador»)
## sin ningún aviso y la tinta y la recarga ya estaban cobradas. Un bloque no puede nacer ahí, así que nace en el punto apuntado dentro del anillo de alcance, como la barrera
## (ESPEC §1.2; es lo que hacía el antiguo glifo pilar). `false` devuelve el comportamiento anterior.
const SOLIDO_QUIETO_EN_PUNTO: bool = true
## Etiqueta con la que `origen["en_punto"]` dice que lo puso esta regla y no un glifo ni el laboratorio.
const ORIGEN_EN_PUNTO_SOLIDO: String = "derivado:solido"
## Las condiciones que puede pedir una regla `momento_si` de un glifo (Sigils.GLIFOS): la primera que se cumpla cambia el momento de ejecución.
const CONDICIONES_MOMENTO: PackedStringArray = ["viaja", "persistente"]

## Qué propiedad de la receta (`Sigils.aplicar_v2(...)["props"]`) es cada campo. Cuenta como «propiedad usada» (encarece el hechizo) cuando algún glifo lo toca.
const PROPIEDAD_DE: Dictionary = {"distancia_max": "viaja", "solidez": "solidez", "copias": "copias", "rebotes": "rebotes", "crece": "crece", "resuena": "resuena", "permanencia": "permanencia"}

## HC5: lo que el laboratorio deja tocar en vivo. Numéricos: {paso, min, max}; «bool» se alterna; «lista» recorre sus valores. Lo que no está aquí se enseña pero no se toca
## (color, deja, estela, efecto_impacto, eventos: son nombres o listas, no números).
const EDITABLES: Dictionary = {
	"semiejes.x": {"paso": 0.05, "min": 0.10, "max": 3.0}, "semiejes.y": {"paso": 0.05, "min": 0.10, "max": 2.0}, "semiejes.z": {"paso": 0.05, "min": 0.10, "max": 3.0},
	"grosor_min": {"paso": 0.05, "min": 0.05, "max": 0.5}, "separacion": {"paso": 0.25, "min": 0.0, "max": 3.0}, "dispersion": {"paso": 5.0, "min": 0.0, "max": 90.0},
	"copias": {"paso": 1.0, "min": 1.0, "max": 8.0}, "crece": {"paso": 0.1, "min": 0.0, "max": 3.0}, "escala_nace": {"paso": 0.1, "min": 0.05, "max": 1.0}, "solidez": {"paso": 0.5, "min": 0.0, "max": 5.0},
	"resuena": {"paso": 1.0, "min": 0.0, "max": 12.0},
	"velocidad": {"paso": 0.5, "min": 0.0, "max": 20.0}, "aceleracion": {"paso": 0.5, "min": -10.0, "max": 20.0}, "gravedad": {"paso": 0.1, "min": 0.0, "max": 3.0},
	"distancia_max": {"paso": 0.5, "min": 0.0, "max": 8.0}, "elevacion": {"paso": 0.25, "min": 0.0, "max": 2.0}, "altura_salida": {"paso": 0.05, "min": 0.0, "max": 2.0},
	"impulso_salida": {"paso": 0.1, "min": 0.0, "max": 5.0},
	"persiste": {"paso": 0.5, "min": 0.0, "max": 25.0}, "permanencia": {"paso": 0.5, "min": 0.0, "max": 25.0}, "retardo": {"paso": 0.1, "min": 0.0, "max": 5.0}, "intervalo": {"paso": 0.05, "min": 0.05, "max": 2.0},
	"rebotes": {"paso": 1.0, "min": 0.0, "max": 6.0}, "elasticidad": {"paso": 0.1, "min": 0.0, "max": 1.0},
	"retorna": {"tipo": "bool"}, "en_punto": {"tipo": "bool"}, "busca": {"paso": 0.25, "min": 0.0, "max": 4.0},
	"dano": {"paso": 5.0, "min": 0.0, "max": 300.0}, "dano_periodico": {"paso": 1.0, "min": 0.0, "max": 100.0}, "potencia": {"paso": 0.25, "min": 0.0, "max": 5.0},
	"empuje": {"paso": 0.1, "min": 0.0, "max": 1.0}, "fuerza_golpe": {"paso": 100.0, "min": 0.0, "max": 3000.0},
	"perfora": {"paso": 1.0, "min": 0.0, "max": 5.0}, "radio_explosion": {"paso": 0.25, "min": 0.0, "max": 5.0}, "golpea_lanzador": {"tipo": "bool"},
	"quema": {"paso": 0.5, "min": 0.0, "max": 20.0}, "moja": {"paso": 0.5, "min": 0.0, "max": 20.0}, "congela": {"paso": 0.5, "min": 0.0, "max": 20.0},
	"congela_mojado": {"paso": 0.5, "min": 0.0, "max": 20.0}, "aturde": {"paso": 0.1, "min": 0.0, "max": 10.0}, "ralentiza": {"paso": 0.5, "min": 0.0, "max": 20.0},
	"ralentiza_fuerza": {"paso": 0.05, "min": 0.0, "max": 1.0}, "interrumpe": {"paso": 0.1, "min": 0.0, "max": 5.0}, "veneno": {"paso": 0.5, "min": 0.0, "max": 20.0},
	"veneno_dps": {"paso": 0.5, "min": 0.0, "max": 30.0}, "intensidad_estado": {"paso": 0.25, "min": 0.0, "max": 5.0},
	"estado_materia": {"tipo": "lista", "valores": ["solido", "liquido", "plasma", "energia", "gas", "campo"]}, "pisable": {"tipo": "bool"},
	"densidad": {"paso": 0.1, "min": 0.0, "max": 5.0}, "temperatura": {"paso": 0.25, "min": -1.0, "max": 1.0}, "humedad": {"paso": 0.1, "min": 0.0, "max": 1.0}, "conductividad": {"paso": 0.1, "min": 0.0, "max": 1.0},
	"choca_con": {"paso": 1.0, "min": 0.0, "max": 3.0},
}
## Los derivados que enseña la tabla (no se tocan: salen de lo demás).
const DERIVADOS: PackedStringArray = ["forma", "cast_point", "niveles", "viaja", "coste", "coste_tinta", "n_glifos", "nivel_potencia", "n_glifos_dano", "nivel_dano", "recarga", "volumen", "superficie", "masa", "resistencia",
	"flota", "anclado", "protege", "se_expande", "se_repite", "rebota", "haz", "alcance_haz"]

# --- Forma y volumen ---
## Casillas de semieje (X ancho, Y alto, Z fondo). Se guardan como tres `float` (64 bits) y no como un Vector3 (32 bits): así los números son EXACTAMENTE los de
## `Sigils.aplicar_v2` y el rasterizado de casillas no cambia ni en los casos límite. `semiejes` es la vista en Vector3 (solo lectura; se escribe con «semiejes.x»).
var semieje_x: float = Sigils.RADIO_BASE_V2
var semieje_y: float = Sigils.RADIO_BASE_V2
var semieje_z: float = Sigils.RADIO_BASE_V2
var semiejes: Vector3:
	get:
		return Vector3(semieje_x, semieje_y, semieje_z)
## Factor de tamaño en vuelo: `ESCALA_PROYECTIL` si es un proyectil (`velocidad` > 0), 1 si no. Es un getter (no un campo derivado en `_derivar`) para que siga a `velocidad` si se edita en el lab.
var escala_vuelo: float:
	get:
		return ESCALA_PROYECTIL if velocidad > 0.0 else 1.0
## Los semiejes tal como se ven y chocan EN VUELO (= `semiejes` × `escala_vuelo`). Los que dibujan o hacen chocar al proyectil leen este, no `semiejes`.
var semiejes_vuelo: Vector3:
	get:
		return semiejes * escala_vuelo
var grosor_min: float = 0.10           ## m: ningún semieje baja de aquí (un muro fino no desaparece) · ESPEC §1.1 · 24/10: = RADIO_BASE_V2 (con 0,15 recortaba la base nueva)
var copias: int = 1                    ## n volúmenes repartidos en X
var separacion: float = 0.5            ## m entre copias (hoy, el ancho de cada copia) · ESPEC §1.6
var dispersion: float = 15.0           ## grados que se abre el abanico de copias (hoy no hay abanico) · ESPEC §1.6
var crece: float = 0.0                 ## m/s de radio al nacer (ESPEC §1.3: antes «escala por segundo»; HechizoVivo lo aplica así desde el 24/10: tiempo = (semieje − semieje × escala_nace) / crece)
var escala_nace: float = 0.3           ## fracción del tamaño con la que nace un volumen que crece · antes `ESCALA_NACE_V2`
var resuena: float = 0.0               ## casillas de alcance del PULSO que suelta el volumen (ᚱ «pulso», +4 por glifo, tope 12); 0 = no resuena. Cuándo lo suelta: `momento_de("raido")` (PLAN_PULSO_RESONANTE §10 bis)
var solidez: float = 0.0               ## 0 = no bloquea; con barrera, 1·1,5^n (diverge del doc, que dice 1: hoy «sin barrera» es la ausencia de la propiedad)

# --- Movimiento ---
var velocidad: float = 0.0             ## m/s (0 = quieto; con `distancia_max` > 0 y velocidad 0, HechizoVivo usa 8 m/s) · HC4
var aceleracion: float = 0.0           ## m/s², negativa = frena · HC4
var gravedad: float = 1.0              ## caída: 1 = como un objeto; el elemento lo multiplica por su estado (§2). Solo afecta a lo que se desplaza · ESPEC §1.2
var distancia_max: float = 0.0         ## m (casillas) que recorre (0 = quieto; hoy `viaja`)
var elevacion: float = 0.0             ## m sobre el suelo a los que nace (glifo futuro «flota») · ESPEC §1.2
var persiste: float = 0.0              ## s de VIDA NATURAL del elemento, YA multiplicados por la calidad del trazo. Solo cuenta para lo que nace quieto (ESPEC §0.3)
var permanencia: float = 0.0           ## s EXTRA que se queda donde nace o donde se para (ᛉ Permanencia, barrera), ya multiplicados por la calidad · ESPEC §0.3
var retardo: float = 0.0               ## s entre lanzar y nacer (glifo aparcado) · ESPEC §1.3
var intervalo: float = 0.25            ## s entre pulsos de una zona · antes `TICK_ZONA_V2`
var altura_salida: float = ALTURA_MANO_U / Terreno3D.casilla   ## m sobre el suelo desde donde sale un PROYECTIL (0,9 u de la mano ≈ 0,39 m). Los hechizos sin velocidad no la usan: nacen en su casilla · HC4
## m/s HACIA ARRIBA con los que sale un PROYECTIL que cae (gravedad > 0): lo lanza en arco en vez de en horizontal. 21/10, Pablo: la flecha de agua caía a 1 casilla
## (sale a 0,9 u y a 4 u/s con gravedad ×0,5: toca el suelo en 0,6 s); con 1,6 m/s (3,7 u/s) sube ~1,4 u y aterriza a ~3 casillas, su alcance. El agua lo trae en su .tres.
var impulso_salida: float = 0.0
var rebotes: int = 0                   ## cambios de dirección al chocar
var elasticidad: float = 0.2           ## 0–1: velocidad que conserva al rebotar · ESPEC §1.4 (aún no la lee nadie)
var retorna: bool = false              ## vuelve al lanzador al acabar · HC4
var en_punto: bool = false            ## nace donde apunta el cursor (dentro del anillo de alcance) y no en el lanzador · 18/10 diseño de Pablo («cast on point»)
var busca: float = 0.0                 ## fuerza de giro hacia un objetivo (0 = recto) · HC4

# --- Daño y combate ---
var dano: float = 1.0                  ## daño base B × E. 29/10 (DANO_Y_TINTA): fuego, agua, tierra y viento lo ponen `construir` desde la potencia (`Dano.base_elemental`); hielo y rayo (aparcados) conservan RuneData.damage. No depende de la calidad
var dano_periodico: float = 0.0        ## puntos/s de una zona de plasma · antes `FRAC_DANO_ZONA_V2` (20 % del daño por pulso)
var potencia: float = 1.0              ## G de `Dano`: factor del daño por glifos con efecto propio sobre el impacto (glifo amplificar, aparcado) · ESPEC §1.5. Hoy 1,0; NO es el nivel de potencia (ese es `nivel_potencia`)
var empuje: float = 0.0                ## 0..1: cuánto empuja un campo de gas (la zona) y qué fracción de la fuerza máxima es
var fuerza_golpe: float = 400.0        ## fuerza con que empuja a un enemigo al golpearlo, ANTES de MULT_EMPUJE y del suelo de Combate3D (0 = no empuja: el viento lo empuja el Lanzador). 400 = la de siempre para lo que no tiene valor propio
var perfora: int = 0                   ## enemigos que atraviesa antes de pararse · HC4
var radio_explosion: float = 0.0       ## casillas de daño en área al golpear · HC4 (con un evento)
var golpea_lanzador: bool = false      ## puede herir a quien lo lanzó · HC4

# --- Estados que deja al golpear (segundos; 0 = no lo aplica) ---
var quema: float = 0.0
var moja: float = 0.0
var congela: float = 0.0
var congela_mojado: float = 0.0        ## lo que congela si el enemigo ya estaba mojado
var aturde: float = 0.0
var ralentiza: float = 0.0             ## segundos
var ralentiza_fuerza: float = 0.0      ## 0..1: cuánto frena (hoy Combate3D multiplica por 0,6 = 0,4 de fuerza)
var interrumpe: float = 0.0
var veneno: float = 0.0                ## segundos que dura el veneno que deja al golpear (0 = no envenena) · HC4
var veneno_dps: float = 3.0            ## daño por segundo mientras dura (solo cuenta si `veneno` > 0)
var intensidad_estado: float = 1.0     ## × todas las duraciones de estado (ESPEC §1.5; aún no la lee nadie)
var deja: String = ""                  ## estado de suelo que deja ("quemado", "mojado", "helado")

# --- Materia ---
var estado_materia: String = "solido"  ## "solido" | "liquido" | "plasma" | "energia" | "gas" | "campo"
var pisable: bool = false
var densidad: float = 1.0              ## unidad/m³ (masa = densidad × volumen) · el elemento la fija (ESPEC §2)
var temperatura: float = 0.0           ## −1 (frío) … +1 (calor). Solo se rellena: las reacciones saldrán de aquí en la fase de cálculo
var humedad: float = 0.0               ## 0…1
var conductividad: float = 0.0         ## 0…1

# --- Choque y aspecto ---
var choca_con: int = 0                 ## máscara de lo que lo para (0 = la de siempre: mundo + enemigos) · HC4
var color: Color = Color.WHITE
var estela: String = ""                ## nombre de VFX, lo resuelve el Pipeline · HC4
var efecto_impacto: String = ""        ## nombre de VFX que suena al golpear (lo resuelve el Pipeline: llega por la señal `vfx_hechizo` del lanzador)
## Eventos: nombre (EVENTOS) -> lista de acciones [{accion: <ACCIONES>, …parámetros}]. Vacío = no hace nada. Se rellena con modificadores «anade».
var eventos: Dictionary = {}

# --- Identidad y entrada (no son modificables) ---
var elemento: String = ""              ## "fuego", "agua", "hielo", "rayo", "tierra", "viento", "" (el tiempo no tiene nombre en Objetos)
var etiquetas: Array[String] = []
var calidad: float = 1.0
var fuente: RuneData = null            ## el RuneData del elemento con que se construyó (HC2: aún lo piden Combate3D y los reactivos; HC3 lo sustituye por los campos)
var glifos: Dictionary = {}            ## los contadores con que se construyó (nombre V2 -> n)
var ignorados: PackedStringArray = PackedStringArray()   ## glifos que la tabla no conoce
var profundidad: int = 0               ## 0 = el hechizo lanzado; un hijo creado por `crear_hijo` vale la del padre + 1 (tope MAX_PROFUNDIDAD)

# --- Derivados (se calculan al final de `construir`) ---
var _glifos_x: float = 0.0             ## lo que dieron los glifos antes de los mínimos (el coste cuenta ESTO: la barrera no encarece)
var _glifos_y: float = 0.0
var _glifos_z: float = 0.0
var semiejes_glifos: Vector3:
	get:
		return Vector3(_glifos_x, _glifos_y, _glifos_z)
## Derivados de solo lectura (ESPEC §1.4 y §1.7): salen de los campos, nunca se fijan a mano.
var volumen: float:
	get:
		return 4.0 / 3.0 * PI * semieje_x * semieje_y * semieje_z                ## m³ del elipsoide
var superficie: float:
	get:
		return _superficie_elipsoide(semieje_x, semieje_y, semieje_z)           ## m²
var masa: float:
	get:
		return densidad * volumen
var resistencia: float:
	get:
		return RESISTENCIA_POR_SOLIDEZ * solidez                                 ## puntos que aguanta antes de romperse (hoy 30 por ×1)
var flota: bool:
	get:
		return elevacion > 0.0
var anclado: bool:
	get:
		return permanencia > 0.0
var protege: bool:
	get:
		return solidez > 0.0
var se_expande: bool:
	get:
		return crece > 0.0
var se_repite: bool:
	get:
		return copias > 1
var rebota: bool:
	get:
		return rebotes > 0
## ¿El volumen SE QUEDA? (lo usa el momento de ejecución, PLAN_PULSO_RESONANTE §10 bis): no viaja y tiene solidez (barrera), permanencia (ᛉ) o un elemento sólido (tierra, hielo). Un haz
## es instantáneo: no se queda.
var persistente: bool:
	get:
		return not haz and not (viaja or velocidad > 0.0) and (solidez > 0.0 or permanencia > 0.0 or estado_materia == "solido")
## ¿Es un sólido (tierra, hielo) que se queda quieto donde nace? (ni haz, ni flecha, ni velocidad). Lo que decide `SOLIDO_QUIETO_EN_PUNTO`.
var solido_quieto: bool:
	get:
		return estado_materia == "solido" and not haz and not (viaja or velocidad > 0.0)
## RAYO (21/10): ¿es un haz? = se dibujó alguna ᛁ (`linea_x`/`linea_z`) y no hay barrera (`solidez`) ni flecha (`distancia_max`). Ver `HAZ_*`. Sale de los glifos y de dos campos, así que si el laboratorio
## le da solidez o alcance de proyectil deja de serlo.
var haz: bool:
	get:
		return Sigils.HAZ_ACTIVO and glifos_linea() > 0 and solidez <= 0.0 and distancia_max <= 0.0 and estado_materia != "solido"     # 29/10: la tierra y el hielo con ᛁ son un bloque ancho o largo, no un chorro (el haz no construye)
## Alcance del haz en m (0 si no es haz).
var alcance_haz: float:
	get:
		if not haz:
			return 0.0
		return clampf(HAZ_ALCANCE_BASE + HAZ_ALCANCE_POR_GLIFO * float(maxi(glifos_linea() - 1, 0)), 0.0, minf(HAZ_ALCANCE_MAX, LIM_DISTANCIA))
var forma: String = "x_mano"           ## nombre derivado: x_mano | alto | abajo (un haz siempre sale con la mano al frente)
var cast_point: String = ""            ## id de la variación de CastPoints para esa forma
var niveles: int = 1
var viaja: bool = false
var coste: float = 1.0                 ## tamaño relativo (la esfera base sin propiedades vale 1). 29/10: ya NO es la tinta; solo informa del volumen (lab, pruebas)
var coste_tinta: float = 0.0           ## 29/10 (DANO_Y_TINTA): T_base(potencia) × (1 + recargos), ANTES de la rebaja del pigmento. Lo calcula `Dano.tinta`
var n_glifos: int = 0                  ## 29/10: glifos de la receta (los conocidos; el elemento no cuenta). De aquí sale la potencia
var nivel_potencia: int = 0            ## 29/10: Dano.LIGERA / MEDIA / ALTA según `n_glifos` (la potencia de la TINTA)
var n_glifos_dano: int = 0             ## H3: glifos OFENSIVOS (los que tienen `Sigils.cuenta_dano`: sin ᛁ ni ᛏ). De aquí sale el daño base
var nivel_dano: int = 0                ## H3: Dano.LIGERA / MEDIA / ALTA según `n_glifos_dano` (cortes 1-2 · 3-4 · 5-6)
var recarga: float = 0.0

## De dónde viene el valor de cada campo (HC5): "defecto" · "elemento" · "glifo:<nombre>" · "calidad". Los componentes de semiejes llevan «semiejes.x».
var origen: Dictionary = {}
var _tocados: Dictionary = {}          ## campos que algún glifo ha tocado (para `desde` y para contar propiedades)


## Cuántas veces se ha llamado a `construir` (H1 del PLAN_SISTEMA_HECHIZOS, 29/10). Solo lo leen las pruebas: un lanzamiento del libro construye UNA vez (`_preparar_pagina`) y la previsión, ninguna.
static var construidos: int = 0


## Construye el hechizo de un elemento con unos glifos. `glifos` = nombre V2 -> cuántas veces (los nombres con alias, como «levitacion», se resuelven).
## `permitir_cinematico` (20/10): una runa cinemática (la del tiempo; `RuneData.cinematico`) solo se construye si quien llama lo pide con `true`, y solo lo hace una
## cinemática o un evento de guion; el libro y los laboratorios no lo pasan nunca. Sin él devuelve null (y avisa), no un hechizo «sin elemento» que pasaría por bueno.
static func construir(elemento_rune: RuneData, contadores: Dictionary, calidad_trazo: float = 1.0, permitir_cinematico: bool = false) -> Hechizo:
	construidos += 1
	if elemento_rune != null and elemento_rune.cinematico and not permitir_cinematico:
		push_warning("Hechizo.construir: «%s» es una runa cinemática (no la lanza el jugador); pide permitir_cinematico = true si es un evento de guion." % elemento_rune.display_name)
		return null
	var h := Hechizo.new()
	CapaBases.aplicar_defectos(h)          # 1. los defectos: los del `var`, salvo lo que el laboratorio haya tocado en «Bases» (vacía en el juego normal)
	h.calidad = calidad_trazo
	h.fuente = elemento_rune
	# 2. el elemento
	if elemento_rune != null:
		h.elemento = Objetos.elemento_de(elemento_rune)
		h.color = elemento_rune.color
		h.etiquetas = elemento_rune.tags.duplicate()
		h._aplicar(_modificadores_de_elemento(elemento_rune), "elemento", false)
	# 3. y 4. los glifos
	var lista: Array = []
	for nombre in contadores:
		var n: int = maxi(int(contadores[nombre]), 0)
		var v2: String = Sigils.glifo_v2(String(nombre))
		if n == 0:
			continue
		if not Sigils.GLIFOS.has(v2):
			h.ignorados.append(String(nombre))
			continue
		h.glifos[v2] = int(h.glifos.get(v2, 0)) + n
	for nombre in Sigils.GLIFOS:             # en el orden de la tabla, no en el de dibujo: la receta es un multiconjunto
		if not h.glifos.has(nombre):
			continue
		for m in CapaBases.modificadores_glifo(nombre):      # = Sigils.GLIFOS[nombre]["modificadores"] salvo que «Bases» los haya tocado
			var mod: Dictionary = (m as Dictionary).duplicate()
			mod["n"] = int(h.glifos[nombre])
			mod["de"] = "glifo:%s" % nombre
			lista.append(mod)
	h._aplicar(lista, "glifo", true)
	# 29/10 (DANO_Y_TINTA): el daño base de fuego, agua, tierra y viento sale de la potencia (nº de glifos) y del elemento; hielo y rayo conservan el suyo.
	if Dano.tiene_tabla(h.elemento):
		h.dano = Dano.base_elemental(h._contar_glifos_dano(), h.elemento)
		h.origen["dano"] = "potencia"
	# la calidad del trazo solo alarga lo que dura: la vida natural y la permanencia
	if h.persiste > 0.0:
		h.persiste *= Sigils.quality_factor(h.calidad)
		h.origen["persiste"] = "calidad"
	if h.permanencia > 0.0:
		h.permanencia *= Sigils.quality_factor(h.calidad)
		h.origen["permanencia"] = "calidad"
	h._limitar()
	h._derivar()
	return h


## Límites globales de seguridad (ESPEC §1.9), al final de `construir()` y de `con()`. Un semieje tampoco baja de `grosor_min`.
func _limitar() -> void:
	semieje_x = clampf(semieje_x, grosor_min, LIM_SEMIEJE_HORIZONTAL)
	semieje_z = clampf(semieje_z, grosor_min, LIM_SEMIEJE_HORIZONTAL)
	semieje_y = clampf(semieje_y, grosor_min, LIM_SEMIEJE_ALTO)
	elevacion = clampf(elevacion, 0.0, LIM_ELEVACION)
	distancia_max = clampf(distancia_max, 0.0, LIM_DISTANCIA)
	persiste = clampf(persiste, 0.0, LIM_VIDA_S)
	permanencia = clampf(permanencia, 0.0, LIM_VIDA_S - persiste)       # persiste + permanencia ≤ 25 s: primero la vida natural, la permanencia se queda con el resto
	copias = clampi(copias, 1, LIM_COPIAS)


## Los campos de RuneData de hoy, traducidos a modificadores «fija», más los `modificadores` propios del .tres (HC3: ahí viven las duraciones de estado, la fuerza del golpe y el daño extra de la tierra).
static func _modificadores_de_elemento(r: RuneData) -> Array:
	var lista: Array = []
	for par in [["dano", r.damage], ["persiste", r.persiste], ["empuje", r.empuje], ["pisable", r.pisable], ["deja", r.deja], ["estado_materia", r.estado]]:
		lista.append({"campo": par[0], "op": "fija", "valor": par[1], "n": 1})
	var propios: Dictionary = CapaBases.modificadores_elemento(r)       # los del .tres, o los de «Bases» si se tocaron
	for campo in propios:
		var m: Dictionary = (propios[campo] as Dictionary).duplicate()
		m["campo"] = String(campo)
		m["n"] = 1
		lista.append(m)
	return lista


## Aplica una lista de modificadores: fija y sumas, luego multiplicaciones, luego los topes de cada campo y al final los mínimos.
func _aplicar(lista: Array, etiqueta: String, marca_tocados: bool) -> void:
	var topes: Dictionary = {}
	for rango in ["fija", "suma", "multiplica"]:
		for m in lista:
			var op_m: String = String(m["op"])
			if (op_m if op_m != "suma_decreciente" else "suma") != rango:       # la suma decreciente va en el rango de las sumas
				continue
			var campo: String = String(m["campo"])
			var v: float = 0.0
			var n: int = int(m.get("n", 1))
			# `salta`: los k primeros glifos no cuentan (la barrera: el 1.º da «en_punto», cada glifo SUCESIVO suma +1 s de persistencia)
			n = maxi(n - int(m.get("salta", 0)), 0)
			if n == 0 and rango != "fija":
				continue                                # sin glifos que cuenten no se toca el campo (ni «desde», ni «tocado», ni el origen)
			if rango == "fija":
				_escribir(campo, _valor_de(m["valor"]))
			else:
				if m.has("desde") and not _tocados.has(campo):
					_escribir(campo, float(m["desde"]))
				v = float(_leer(campo))
				if op_m == "suma_decreciente":
					v += float(m["valor"]) * Sigils.serie_decreciente(float(m["factor"]), n)
				else:
					v = v + float(m["valor"]) * float(n) if rango == "suma" else v * pow(float(m["valor"]), float(n))
				_escribir(campo, v)
			if marca_tocados:
				_tocados[campo] = true
			origen[campo] = String(m.get("de", etiqueta))
			if m.has("tope"):
				topes[campo] = minf(float(topes.get(campo, INF)), float(m["tope"]))
	for m in lista:                                  # los eventos se añaden al final, en el orden de la lista (no tienen orden entre sumas y multiplicaciones)
		if String(m["op"]) == "anade":
			var nombre_ev: String = String(m["campo"]).trim_prefix("eventos.")
			var acciones: Array = eventos.get(nombre_ev, []) as Array
			var glifo_de: String = String(m.get("de", "")).trim_prefix("glifo:") if String(m.get("de", "")).begins_with("glifo:") else ""
			for _k in range(int(m.get("n", 1))):
				var a: Dictionary = (m["valor"] as Dictionary).duplicate(true)
				a["paso"] = int(Sigils.GLIFOS.get(glifo_de, {}).get("paso", Sigils.PASO_DEFECTO))       # H2: el orden fijo de §2.4 también para los eventos
				a["orden"] = _orden_de_glifo(glifo_de)
				acciones.append(a)
			eventos[nombre_ev] = acciones
			origen["eventos"] = String(m.get("de", etiqueta))
			if marca_tocados:
				_tocados["eventos"] = true
	for campo in topes:
		if _leer(String(campo)) > float(topes[campo]):
			_escribir(String(campo), float(topes[campo]))
	_glifos_x = semieje_x
	_glifos_y = semieje_y
	_glifos_z = semieje_z
	for m in lista:
		if String(m["op"]) == "minimo":
			var campo: String = String(m["campo"])
			_escribir(campo, maxf(float(_leer(campo)), float(_valor_de(m["valor"]))))
			origen[campo] = String(m.get("de", etiqueta))


## Un valor simbólico («@radio_barrera», «@velocidad_flecha») se resuelve aquí; cualquier otro se devuelve tal cual.
static func _valor_de(v: Variant) -> Variant:
	if v is String:
		match String(v):
			"@radio_barrera":
				return Sigils.radio_barrera_casillas()
			"@velocidad_flecha":
				return Sigils.velocidad_flecha()
	return v


## Lee un campo; «semiejes.x» lee un componente.
func _leer(campo: String) -> Variant:
	if campo.begins_with("semiejes."):
		return get("semieje_" + campo.substr(9))
	return get(campo)


## Escribe un campo respetando su tipo (int, float, bool, String); «semiejes.x» escribe un componente.
func _escribir(campo: String, valor: Variant) -> void:
	if campo.begins_with("semiejes."):
		set("semieje_" + campo.substr(9), float(valor))
		return
	var actual: Variant = get(campo)
	if actual is int:
		set(campo, int(roundf(float(valor))))
	elif actual is float:
		set(campo, float(valor))
	elif actual is bool:
		set(campo, bool(valor))
	else:
		set(campo, valor)


## H3: los glifos de la receta que suman al daño (`Sigils.cuenta_dano`).
func _contar_glifos_dano() -> int:
	var n: int = 0
	for k in glifos:
		if Sigils.cuenta_dano(String(k)):
			n += maxi(int(glifos[k]), 0)
	return n


## 5. Lo que sale de lo anterior.
func _derivar() -> void:
	viaja = distancia_max > 0.0
	forma = "x_mano" if (haz or (estado_materia == "solido" and Sigils.HAZ_ACTIVO and glifos_linea() > 0 and solidez <= 0.0 and distancia_max <= 0.0)) else nombre_derivado(semieje_x, semieje_y, semieje_z, viaja)       # un haz sale con la mano al frente (= GeometriaV2.nombre_derivado con g["haz"])
	niveles = maxi(1, roundi(2.0 * semieje_y))
	cast_point = CastPoints.variacion_de(forma)
	var base: float = 4.0 / 3.0 * PI * pow(Sigils.RADIO_BASE_V2, 3.0)
	var vol: float = 4.0 / 3.0 * PI * _glifos_x * _glifos_y * _glifos_z
	var props_usadas: Dictionary = propiedades_usadas()
	coste = vol / base * (1.0 + Sigils.COSTE_PROP_V2 * float(props_usadas.size())) * Sigils.recargo_continuo(props_usadas)
	n_glifos = 0
	for k in glifos:
		n_glifos += maxi(int(glifos[k]), 0)
	nivel_potencia = Dano.nivel(n_glifos)
	n_glifos_dano = _contar_glifos_dano()
	nivel_dano = Dano.nivel_dano(n_glifos_dano)
	coste_tinta = Dano.tinta_de(self)       # 29/10 + H4: la tinta sale del hechizo construido (potencia + aportes de glifos + recargos), no del volumen
	recarga = Sigils.cooldown_v2(glifos)
	for campo in DERIVADOS:
		origen[campo] = "derivado"
	# Un sólido quieto nace donde apuntas. Lo que ya puso un glifo (la barrera) o el laboratorio se respeta; si el laboratorio lo hace viajar después, se retira lo que puso esta regla.
	if SOLIDO_QUIETO_EN_PUNTO and String(origen.get("en_punto", "")) != "lab":
		if solido_quieto and not en_punto:
			en_punto = true
			origen["en_punto"] = ORIGEN_EN_PUNTO_SOLIDO
		elif not solido_quieto and String(origen.get("en_punto", "")) == ORIGEN_EN_PUNTO_SOLIDO:
			en_punto = false
			origen.erase("en_punto")


## Superficie aproximada de un elipsoide (fórmula de Knud Thomsen, error < 1,1 %).
static func _superficie_elipsoide(a: float, b: float, c: float) -> float:
	var p: float = 1.6075
	return 4.0 * PI * pow((pow(a * b, p) + pow(a * c, p) + pow(b * c, p)) / 3.0, 1.0 / p)


## Eje en el que más se estira: "x" | "y" | "z", o "esfera" si no se ha estirado ninguno. (Empate: gana Z, luego Y, luego X.)
static func eje_dominante(sx: float, sy: float, sz: float) -> String:
	var v: Dictionary = {"x": sx, "y": sy, "z": sz}
	var mayor: String = "z"
	for e in ["y", "x"]:
		if float(v[e]) > float(v[mayor]) + EPS:
			mayor = e
	return mayor if float(v[mayor]) > Sigils.RADIO_BASE_V2 + EPS else "esfera"


## Nombre para la animación de lanzar, el cast point y el VFX: lo que viaja o se estira hacia delante sale con la mano al frente («x_mano»), lo que domina en altura
## se eleva («alto») y lo plano y quieto va al suelo («abajo»). Es la misma regla que `Lanzador3D.GeometriaV2.nombre_derivado`.
static func nombre_derivado(sx: float, sy: float, sz: float, viaja_: bool) -> String:
	var dom: String = eje_dominante(sx, sy, sz)
	if viaja_ or (dom == "z" and sz > sx + EPS and sz > sy + EPS):
		return "x_mano"
	if dom == "y":
		return "alto"
	if dom != "esfera" and sy <= Sigils.RADIO_BASE_V2 + EPS:
		return "abajo"
	return "x_mano"


## Las propiedades que algún glifo ha tocado, en el formato de `Sigils.aplicar_v2(...)["props"]`: {param: valor}.
func propiedades_usadas() -> Dictionary:
	var salida: Dictionary = {}
	for campo in PROPIEDAD_DE:
		if campo == "permanencia":
			# Solo cuenta (y encarece) la parte del glifo ᛉ: el segundo en adelante de la barrera también suma permanencia, pero eso es tiempo extra, no una propiedad nueva.
			var n: int = int(glifos.get("permanencia", 0))
			if n > 0 and Sigils.GLIFOS.has("permanencia"):
				var m: Dictionary = (Sigils.GLIFOS["permanencia"]["modificadores"] as Array)[0]       # H1: de la tabla GLIFOS (suma `valor` por glifo, con `tope`; parte de 0)
				salida["permanencia"] = minf(float(m["valor"]) * float(n), float(m["tope"]))
		elif _tocados.has(campo):
			salida[PROPIEDAD_DE[campo]] = float(_leer(String(campo)))
	return salida


## La geometría en el formato de siempre (el de `Lanzador3D.GeometriaV2.evaluar`): {x, y, z, props, x_glifos, z_glifos, nombre, viaja, y_tope, valida, aviso}.
## Es lo que leen `GeometriaV2.celdas`, el VFX por estado y el laboratorio mientras no pasen a leer el Hechizo directamente.
func geo() -> Dictionary:
	return {"x": semieje_x, "y": semieje_y, "z": semieje_z, "props": propiedades_usadas(), "x_glifos": _glifos_x, "z_glifos": _glifos_z,
		"nombre": forma, "viaja": viaja, "y_tope": niveles - 1, "valida": true, "aviso": "", "haz": haz}


## Cuántas ᛁ (`linea_x` + `linea_z`) lleva el hechizo.
func glifos_linea() -> int:
	return maxi(int(glifos.get("linea_x", 0)), 0) + maxi(int(glifos.get("linea_z", 0)), 0)


## MOMENTO DE EJECUCIÓN de un glifo en ESTE hechizo (PLAN_PULSO_RESONANTE §10 bis; Sigils.GLIFOS[…]["momento"]): "inicio" | "continuo" | "final". Es un dato del glifo; si trae reglas
## `momento_si` se aplica la primera que se cumpla (p. ej. ᚱ: «viaja» → final, «persistente» → continuo). Un glifo que no está en la tabla vale `Sigils.MOMENTO_DEFECTO`.
func momento_de(glifo: String) -> String:
	var d: Dictionary = Sigils.GLIFOS.get(glifo, {})
	for regla in (d.get("momento_si", []) as Array):
		if _cumple_momento(String((regla as Dictionary).get("cuando", ""))):
			return String((regla as Dictionary).get("es", Sigils.MOMENTO_DEFECTO))
	return String(d.get("momento", Sigils.MOMENTO_DEFECTO))


func _cumple_momento(cuando: String) -> bool:
	match cuando:
		"viaja":
			return viaja or velocidad > 0.0
		"persistente":
			return persistente
	return false


## Lo que HACEN los glifos del hechizo en un momento, en el ORDEN FIJO de GLIFOS_RECETA §2.4 (el `paso` de cada glifo y, a igualdad, el orden de la tabla `Sigils.GLIFOS`; nunca el orden
## en que se dibujaron): [{glifo, accion, n (cuántos glifos), paso}]. Solo cuentan los glifos con `accion` (los demás ya hacen lo suyo dentro del ciclo de vida).
func acciones_en(momento: String) -> Array:
	return _acciones_de([momento])


## H2: las acciones de glifo que salen en el final de un tramo que acaba por `causa`: las de momento «final» (los tres finales) más las del momento fino que toca
## («impacto» si `causa` = golpe, «extincion» si `causa` = «extincion», «detencion» en cualquier otro caso: muro, suelo, alcance, tiempo, frenado, retorno). Mismo orden que `acciones_en`.
func acciones_en_fin(causa: String) -> Array:
	var fino: String = "extincion" if causa == "extincion" else ("impacto" if causa == "golpe" else "detencion")
	return _acciones_de([Sigils.MOMENTO_FINAL, fino])


func _acciones_de(momentos: Array) -> Array:
	var lista: Array = []
	var orden: int = 0
	for glifo in Sigils.GLIFOS:
		orden += 1
		if not glifos.has(glifo):
			continue
		var d: Dictionary = Sigils.GLIFOS[glifo]
		if not d.has("accion") or not momentos.has(momento_de(String(glifo))):
			continue
		lista.append({"glifo": String(glifo), "accion": String(d["accion"]), "n": int(glifos[glifo]), "paso": int(d.get("paso", Sigils.PASO_DEFECTO)), "orden": orden})
	return ordenar_acciones(lista)


## El lugar de un glifo en la tabla `Sigils.GLIFOS` (1…); 0 si no es de la tabla (acciones del laboratorio, del elemento o de `radio_explosion`).
static func _orden_de_glifo(glifo: String) -> int:
	var orden: int = 0
	for g in Sigils.GLIFOS:
		orden += 1
		if String(g) == glifo:
			return orden
	return 0


## EL ORDEN FIJO de GLIFOS_RECETA §2.4: por `paso` (1 volumen · 2 copias · 3 vida · 4 materia · 5 daño y efectos) y, dentro del mismo paso, por `orden` (el de la tabla `Sigils.GLIFOS`).
## Nunca por el orden en que se dibujaron los glifos. Devuelve la lista ordenada (la misma, in situ).
static func ordenar_acciones(lista: Array) -> Array:
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["paso"]) != int(b["paso"]):
			return int(a["paso"]) < int(b["paso"])
		if int(a["orden"]) != int(b["orden"]):
			return int(a["orden"]) < int(b["orden"])
		return int(a.get("i", 0)) < int(b.get("i", 0)))        # `i` = posición en la lista (el sort de Godot no es estable): a igualdad, el orden en que se añadieron
	return lista


## La figura que dibuja el VFX de un elemento: «haz» (ᛁ), «barrera» (solidez), «proyectil» (viaja), «pulso» (crece) o «esfera». Es la que decide `VfxElemento3D`.
func figura() -> String:
	if haz:
		return "haz"
	if solidez > 0.0:
		return "barrera"
	if viaja or velocidad > 0.0:
		return "proyectil"
	if crece > 0.0:
		return "pulso"
	return "esfera"


## Una copia independiente (los hijos de `crear_hijo` parten de ella y le cambian campos). No copia el RuneData (se comparte) ni toca los derivados: se copian tal cual.
func copiar() -> Hechizo:
	var c := Hechizo.new()
	for p in get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var nombre: String = String(p["name"])
		if SOLO_LECTURA.has(nombre):      # vistas y derivados de solo lectura
			continue
		var v: Variant = get(nombre)
		if v is Dictionary or v is Array:
			v = v.duplicate(true)
		c.set(nombre, v)
	return c


## Cambia campos de golpe (los `cambios` de `crear_hijo` y las sobrescrituras del laboratorio: {campo: valor}); «semiejes.x» vale, y también «eventos» (diccionario entero).
## Un campo que es una «propiedad» de la receta (distancia_max, copias, rebotes, crece, solidez) cuenta como usado, igual que si lo hubiera dado un glifo, y los derivados
## (forma, viaja, coste…) se recalculan. El coste sigue siendo el de los glifos dibujados: tocar un número en el lab no encarece el hechizo. Devuelve self.
func con(cambios: Dictionary) -> Hechizo:
	for campo in cambios:
		var v: Variant = cambios[campo]
		if String(campo) == "eventos":
			eventos = (v as Dictionary).duplicate(true)
		else:
			_escribir(String(campo), v)
		if PROPIEDAD_DE.has(String(campo)):
			_tocados[String(campo)] = true
		origen[String(campo)] = "lab"
	_limitar()
	_derivar()
	return self


## HC5: la tabla completa del hechizo construido, una fila por campo: {campo, grupo, valor, defecto, origen, tipo_origen, difiere, editable}.
## `origen` = de dónde viene el valor («defecto», «elemento», «glifo:<nombre>», «calidad», «lab» si lo tocó el laboratorio, «derivado»); `tipo_origen` es la parte antes de los «:».
## `semiejes` sale en sus tres componentes (semiejes.x/y/z) y `eventos` en una sola fila resumida. Después van los derivados.
func tabla() -> Array:
	var filas: Array = []
	for par in CAMPOS:
		var campo: String = String(par[0])
		if campo == "semiejes":
			for eje in ["x", "y", "z"]:
				filas.append(_fila("semiejes." + eje, String(par[1])))
		else:
			filas.append(_fila(campo, String(par[1])))
	for campo in DERIVADOS:
		filas.append({"campo": campo, "grupo": "derivado", "valor": get(campo), "defecto": defecto(campo), "origen": "derivado", "tipo_origen": "derivado", "difiere": false, "editable": false})
	return filas


func _fila(campo: String, grupo: String) -> Dictionary:
	var valor: Variant = _leer(campo)
	var def: Variant = defecto(campo)
	var o: String = String(origen.get(campo, "defecto"))
	var distinto: bool
	if valor is float and def is float:
		distinto = not is_equal_approx(float(valor), float(def))
	else:
		distinto = valor != def
	if campo == "eventos":
		valor = "%d acciones" % _acciones_totales() if distinto else "ninguno"
		def = "ninguno"
	return {"campo": campo, "grupo": grupo, "valor": valor, "defecto": def, "origen": o, "tipo_origen": o.get_slice(":", 0), "difiere": distinto, "editable": EDITABLES.has(campo)}


func _acciones_totales() -> int:
	var n: int = 0
	for e in eventos:
		n += (eventos[e] as Array).size()
	return n


## Las sobrescrituras del laboratorio como modificadores LISTOS PARA PEGAR: una línea por campo, en el formato de `Sigils.GLIFOS` (lista de {campo, op, valor}) y en el de
## `RuneData.modificadores` de un .tres ({campo: {op, valor}}). Siempre «fija»: es el valor que se probó, tal cual.
static func texto_modificadores(cambios: Dictionary) -> String:
	if cambios.is_empty():
		return "# (sin cambios)"
	var campos: Array = cambios.keys()
	campos.sort()
	var glifo: PackedStringArray = PackedStringArray()
	var tres: PackedStringArray = PackedStringArray()
	for campo in campos:
		var v: Variant = cambios[campo]
		var txt: String = var_to_str(v) if not (v is float) else str(snappedf(float(v), 0.0001))
		glifo.append("\t\t{\"campo\": \"%s\", \"op\": \"fija\", \"valor\": %s}," % [campo, txt])
		tres.append("\"%s\": {\"op\": \"fija\", \"valor\": %s}" % [campo, txt])
	return "# En Sigils.GLIFOS[<glifo>][\"modificadores\"]:\n[\n%s\n]\n# En un *_rune.tres (modificadores = {...}):\nmodificadores = {%s}" % ["\n".join(glifo), ", ".join(tres)]


## Todos los campos (y los derivados) en un diccionario seguro para PlayLog/JSON: Vector3 → [x, y, z], Color → html.
func a_diccionario() -> Dictionary:
	var d: Dictionary = {}
	for par in CAMPOS:
		d[par[0]] = _plano(get(String(par[0])))
	d["elemento"] = elemento
	d["calidad"] = calidad
	for campo in DERIVADOS:
		d[campo] = get(campo)
	d["semiejes_glifos"] = _plano(semiejes_glifos)
	d["glifos"] = glifos.duplicate()
	d["origen"] = origen.duplicate()
	return d


## H7 (29/10, PLAN_SISTEMA_HECHIZOS §3): lo que el libro enseña de un hechizo SIN lanzarlo. Datos puros: la potencia y el nivel de daño con su nombre, y los números tal cual (la tinta es `coste_tinta`,
## antes de la rebaja del pigmento: lo que Tinta rebaja se le dice a `Lanzador3D.tinta_prevista`).
func resumen() -> Dictionary:
	return {"potencia": String(Dano.NOMBRES[nivel_potencia]), "nivel_dano": String(Dano.NOMBRES[nivel_dano]), "dano": dano, "tinta": coste_tinta, "recarga": recarga, "forma": forma,
		"en_punto": en_punto, "haz": haz, "n_glifos": n_glifos, "n_glifos_dano": n_glifos_dano}


## Campos que `diferencia` no compara: son el «por qué» (origen, glifos) o un derivado de otro campo ya comparado (`semiejes_glifos`).
const DIF_SALTAR: PackedStringArray = ["origen", "glifos", "semiejes_glifos"]
## Derivados que `texto_cambio` no nombra: repiten (volumen, masa…) o no le dicen nada a quien dibuja (cast_point, niveles). Siguen en `diferencia`.
const DIF_SIN_FRASE: PackedStringArray = ["coste", "volumen", "superficie", "masa", "resistencia", "flota", "anclado", "protege", "se_expande", "se_repite", "rebota", "persistente", "solido_quieto",
	"cast_point", "niveles", "viaja", "alcance_haz", "n_glifos", "n_glifos_dano", "forma", "haz", "persiste"]


## La tabla plana que compara `diferencia`: `a_diccionario()` con los semiejes en tres campos («semiejes.x»…) para poder decir «+1 casilla de ancho».
func _comparable() -> Dictionary:
	var d: Dictionary = a_diccionario()
	d.erase("semiejes")
	d["semiejes.x"] = semieje_x
	d["semiejes.y"] = semieje_y
	d["semiejes.z"] = semieje_z
	for c in DIF_SALTAR:
		d.erase(c)
	return d


## H7: los campos que cambian entre `anterior` y este hechizo: [{campo, antes, despues, glifo}]. `glifo` es el id del glifo que lo puso (el `origen` «glifo:<nombre>» del campo en este hechizo o,
## si ya no lo tiene este —un glifo quitado—, en el anterior), o "" si es un derivado, el elemento o el daño por potencia. Orden: el de la tabla (CAMPOS) y después los derivados.
func diferencia(anterior: Hechizo) -> Array:
	var salida: Array = []
	if anterior == null:
		return salida
	var nuevo: Dictionary = _comparable()
	var viejo: Dictionary = anterior._comparable()
	for campo in nuevo:
		var a: Variant = viejo.get(campo)
		var b: Variant = nuevo[campo]
		var igual: bool
		if (a is float or a is int) and (b is float or b is int):
			igual = is_equal_approx(float(a), float(b))
		else:
			igual = a == b
		if igual:
			continue
		var glifo: String = ""
		for o in [origen, anterior.origen]:
			var etiqueta: String = String((o as Dictionary).get(campo, ""))
			if etiqueta.begins_with("glifo:"):
				glifo = etiqueta.trim_prefix("glifo:")
				break
			if etiqueta == "calidad":
				glifo = _glifo_del_campo(campo)      # la calidad solo estira lo que ya puso un glifo (permanencia, persiste): el glifo sigue siendo el dueño
				if glifo != "":
					break
		salida.append({"campo": campo, "antes": a, "despues": b, "glifo": glifo})
	return salida


## El glifo de la receta cuya tabla toca `campo` (el primero por orden de tabla); "" si ninguno.
func _glifo_del_campo(campo: String) -> String:
	for g in Sigils.GLIFOS:
		if not glifos.has(g):
			continue
		for m in (Sigils.GLIFOS[g].get("modificadores", []) as Array):
			if String((m as Dictionary).get("campo", "")) == campo:
				return String(g)
	return ""


## «2» o «2,5»: un número con coma decimal y sin ceros de más.
static func texto_numero(v: float, decimales: int = 1) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return (("%." + str(decimales) + "f") % v).replace(".", ",")


## «2,0»: segundos con un decimal fijo y coma (la recarga).
static func texto_segundos(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


static func _con_signo(v: float) -> String:
	return ("+" if v > 0.0 else "−") + texto_numero(absf(v))


static func _casillas(v: float, que: String) -> String:
	var n: float = absf(v)
	return "%s %s de %s" % [_con_signo(v), "casilla" if absf(n - 1.0) < 0.05 else "casillas", que]


## Las frases de una diferencia, una por campo que merece frase: [{texto, numerico}]. `numerico` = es un número del resumen (daño, tinta, recarga, niveles) y no lo que hizo el glifo; el libro las pone en
## líneas distintas. Los campos de glifo salen primero y en el orden de `diferencia`.
static func frases_cambio(dif: Array) -> Array:
	var propias: Array = []
	var numeros: Array = []
	for d in dif:
		var campo: String = String(d["campo"])
		if DIF_SIN_FRASE.has(campo):
			continue
		var a: Variant = d["antes"]
		var b: Variant = d["despues"]
		var texto: String = ""
		var numerico: bool = false
		var delta: float = (float(b) - float(a)) if ((a is float or a is int) and (b is float or b is int)) else 0.0
		match campo:
			"semiejes.x":
				texto = _casillas(delta * 2.0, "ancho")
			"semiejes.y":
				texto = _casillas(delta * 2.0, "alto")
			"semiejes.z":
				texto = _casillas(delta * 2.0, "fondo")
			"distancia_max":
				texto = "%s m de alcance" % _con_signo(delta)
			"permanencia":
				texto = "%s s de permanencia" % _con_signo(delta)
			"copias":
				texto = "%s %s" % [_con_signo(delta), "copia" if absf(delta) < 1.5 else "copias"]
			"dano":
				texto = "daño %s → %s" % [texto_numero(float(a)), texto_numero(float(b))]
				numerico = true
			"coste_tinta":
				texto = "tinta %s → %s" % [texto_numero(float(a)), texto_numero(float(b))]
				numerico = true
			"recarga":
				texto = "recarga %s → %s s" % [texto_segundos(float(a)), texto_segundos(float(b))]
				numerico = true
			"nivel_potencia":
				texto = "potencia %s → %s" % [Dano.NOMBRES[clampi(int(a), 0, 2)], Dano.NOMBRES[clampi(int(b), 0, 2)]]
				numerico = true
			"nivel_dano":
				texto = "nivel de daño %s → %s" % [Dano.NOMBRES[clampi(int(a), 0, 2)], Dano.NOMBRES[clampi(int(b), 0, 2)]]
				numerico = true
			"en_punto":
				texto = "nace donde apuntas" if bool(b) else "ya no nace donde apuntas"
			"solidez":
				texto = "bloquea el paso" if float(b) > float(a) else "ya no bloquea"
			"crece":
				texto = "se expande %s m/s" % texto_numero(float(b))
			"eventos":
				texto = "efectos %d → %d" % [_acciones_en(a as Dictionary), _acciones_en(b as Dictionary)]
			_:
				if (a is float or a is int) and (b is float or b is int):
					texto = "%s: %s → %s" % [campo, texto_numero(float(a), 2), texto_numero(float(b), 2)]
				elif a is bool and b is bool:
					texto = "%s: %s → %s" % [campo, "sí" if a else "no", "sí" if b else "no"]
				else:
					texto = "%s: %s → %s" % [campo, str(a), str(b)]
		(numeros if numerico else propias).append({"texto": texto, "numerico": numerico})
	return propias + numeros


static func _acciones_en(eventos_: Dictionary) -> int:
	var n: int = 0
	for e in eventos_:
		n += (eventos_[e] as Array).size()
	return n


## H7: la diferencia en una frase corta por campo («+1 casilla de ancho · daño 13 → 26 · tinta 8 → 18»); "" si nada que contar.
static func texto_cambio(dif: Array) -> String:
	var trozos: PackedStringArray = PackedStringArray()
	for f in frases_cambio(dif):
		trozos.append(String((f as Dictionary)["texto"]))
	return " · ".join(trozos)


static func _plano(v: Variant) -> Variant:
	if v is Vector3:
		return [(v as Vector3).x, (v as Vector3).y, (v as Vector3).z]
	if v is Color:
		return (v as Color).to_html()
	return v


## El valor por defecto de un campo (el del `var`): se lee de un Hechizo recién creado, así no hay dos copias.
static func defecto(campo: String) -> Variant:
	var h := Hechizo.new()
	CapaBases.aplicar_defectos(h)          # refleja «Bases»; sin ella es el `var`
	return h._leer(campo)


## El defecto ORIGINAL (el del `var`), sin la capa de «Bases»: lo que el lab compara para saber qué se tocó y qué se exporta.
static func defecto_original(campo: String) -> Variant:
	return Hechizo.new()._leer(campo)


## Texto para depurar: los campos que difieren del defecto, con de dónde vienen, y los derivados.
func describir() -> String:
	var lineas: PackedStringArray = PackedStringArray()
	lineas.append("Hechizo %s %s (calidad %.2f) · glifos %s" % [elemento if elemento != "" else "sin elemento", forma, calidad, str(glifos)])
	for par in CAMPOS:
		var campo: String = String(par[0])
		var v: Variant = get(campo)
		if v != defecto(campo):
			lineas.append("  %s = %s  (%s)" % [campo, str(v), String(origen.get(campo, origen.get(campo + ".x", "defecto")))])
	lineas.append("  potencia: %d glifos (tinta, %s) · %d ofensivos (daño %s)" % [n_glifos, Dano.NOMBRES[nivel_potencia], n_glifos_dano, Dano.NOMBRES[nivel_dano]])
	lineas.append("  coste %.2f (%.1f tinta) · recarga %.2f s · niveles %d · cast point '%s'" % [coste, coste_tinta, recarga, niveles, cast_point])
	return "\n".join(lineas)

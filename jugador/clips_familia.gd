class_name ClipsFamilia
extends RefCounted

## Los clips de una familia (docs/PLAN_RIGGING.md §3.6) para un modelo que no trae los suyos: se leen del GLB de otro modelo con los MISMOS
## nombres de hueso Mixamo y se pasan al esqueleto del nuevo (retarget en código, una vez por sesión).
##
## Por qué hace falta retarget: los dos esqueletos se llaman igual pero NO tienen la misma pose de reposo (cada hueso tiene su propio eje local y
## proporciones distintas: elfo_base tiene piernas más largas y la cadera a 0,48 u de 0,98; chibi_elf a 0,64 de 1,7). Una pista de rotación de Godot
## es el giro LOCAL absoluto, así que copiarla tal cual tuerce el cuerpo. Aquí se copia el MOVIMIENTO: lo que cada hueso gira en el espacio del modelo
## respecto a su reposo (`delta = global_animado · global_reposo⁻¹`) se aplica al reposo del esqueleto destino y se vuelve a pasar a local.
## Es lo que hace el importador de Godot con BoneMap + Rest Fixer, pero sin tocar el GLB. Los huesos que la fuente no tiene (los dedos) siguen a su
## padre en su pose de reposo. La traslación de la cadera se reescala con la relación de alturas de cadera, y todo el clip se sube/baja la misma
## cantidad fija para que, con el Idle, el pie más bajo quede a la altura que tiene en el reposo (pies en el suelo).
## Un modelo puede tomar clips de VARIOS GLB y con otros nombres (FUENTES: el goblin asesino usa Gribble para moverse y el goblin guerrero para las reacciones), y un
## clip suelto de otro GLB se traduce con `traducir_clip` (el empujado y levantarse de Pj3D).

## CLIPS NUEVOS DE LA JUGADORA (24/10): los generó Pablo en Meshy con el esqueleto ligero de la elfa (28 huesos `mixamorig`) y arte/meshy/clips_jugadora.py los recorta y
## renombra en arte/meshy/jugadora_clips.glb (solo esqueleto y clips). Los nombres de destino son los roles de Pj3D.SINONIMOS. «referencia»: el Saludo (de pie, con los pies
## en el suelo) fija la altura de los pies, porque el GLB no trae Idle.
##   abrir_cofre  se inclina y baja las dos manos (cofre legendario, SecuenciaCofreLegendario3D)   agacharse  se agacha con las manos juntas y se levanta (cofres pequeños, coger del suelo)
##   ofrecer      de pie, adelanta la mano derecha con la palma abierta                             saludo     saluda con la mano
##   empujar      empujando andando, en bucle y sin avance (un ciclo de paso)
const RUTA_CLIPS_JUGADORA: String = "res://arte/meshy/jugadora_clips.glb"
const FUENTE_CLIPS_JUGADORA: Dictionary = {
	"ruta": RUTA_CLIPS_JUGADORA, "referencia": "Saludo", "clips": {
		"abrir_cofre": "AbrirCofre", "agacharse": "Agacharse", "ofrecer": "Ofrecer", "saludo": "Saludo", "empujar": "Empujar",
	},
	# Las proporciones de cada elfa difieren (piernas, cadera) y en una agachada la cadera retargeteada hunde o levanta la suela unos centímetros: se corrige en cada fotograma.
	"plantar": ["AbrirCofre", "Agacharse", "Ofrecer", "Saludo", "Empujar"]}

## CLIPS DE COGER, CARGAR Y LANZAR (4/11): Meshy «Willow Fernstep» pasada a Mixamo (la MISMA jugadora que jugadora_base: mismos 65 huesos). arte/meshy/clips_carga.py recorta y renombra los seis clips
## en arte/meshy/jugadora_carga_clips.glb (solo esqueleto y clips, 0,5 MB; el GLB de 20 MB con malla no está en el repo). Los nombres de destino son los roles de Pj3D.SINONIMOS y los instantes
## medidos (la suelta, las manos abajo) están en Pj3D.INSTANTE_CLIP. «referencia»: CargarIdle (de pie, pies en el suelo) fija la altura de los pies.
##   cargar_idle   quieta con las dos manos sobre la cabeza (bucle)         cargar_andar  un ciclo de paso con las manos arriba, en el sitio (bucle)
##   levantar      se agacha, coge del suelo y lo sube sobre la cabeza       lanzar_objeto  anticipación, suelta al frente con las dos manos y remate
##   dejar_objeto  baja el objeto al suelo, lo deja y se levanta             coger_lanzar   se agacha, coge con la derecha, da un paso y lanza (objetos pequeños, sin cargarlos)
## `dejar_objeto` y `levantar` (el mismo clip al revés) vienen con TODO el cuerpo 0,17 más alto que el resto (cadera 1,02 en vez de 0,85: flotaba): `plantar` les pone la suela en el suelo.
const RUTA_CLIPS_CARGA: String = "res://arte/meshy/jugadora_carga_clips.glb"
const FUENTE_CLIPS_CARGA: Dictionary = {
	"ruta": RUTA_CLIPS_CARGA, "referencia": "CargarIdle", "clips": {
		"cargar_idle": "CargarIdle", "cargar_andar": "CargarAndar", "lanzar_objeto": "LanzarObjeto", "dejar_objeto": "DejarObjeto", "levantar": "Levantar", "coger_lanzar": "CogerLanzar",
	},
	"plantar": ["DejarObjeto", "Levantar"]}

## Los tres casts a UNA mano del Pipeline (diario 150: CastOneHandFront / Up / Ground, la otra mano sujeta el libro) viven en woodland_wanderer_suave.glb. La jugadora nueva (jugadora_base)
## los toma de ahí traducidos a su esqueleto (los tres sirven también de pose de referencia del brazo del libro, BrazoLibro3D). Los nombres se conservan: son los de Pj3D.SINONIMOS.
const RUTA_UNA_MANO: String = "res://arte/modelos/woodland_wanderer_suave.glb"
const FUENTE_UNA_MANO: Dictionary = {
	"ruta": RUTA_UNA_MANO, "referencia": "Idle", "clips": {
		"CastOneHandFront": "CastOneHandFront", "CastOneHandUp": "CastOneHandUp", "CastOneHandGround": "CastOneHandGround",
	}}

## CLIPS DE MIXAMO (5/11, diario 385): clips de la librería de Mixamo (esqueleto Y Bot, los MISMOS 65 huesos que jugadora_base) juntados en un GLB por herramientas/mixamo_clips_a_glb.gd.
## Entran por el mismo retarget que el resto de fuentes. «referencia»: el Idle de Mixamo (de pie, pies en el suelo). «centrar»: los clips «in place» de Mixamo traen la cadera puesta a
## un lado (Two_Hand_Spell_Casting, 0,33 alturas de cadera). Nombres de destino con prefijo «Mixamo_» para no pisar los roles de la elfa (chibi_elf va antes y gana de todos modos):
##   Mixamo_CastDosManos  conjuro a dos manos, una vez (3,4 s)        Mixamo_Nadar      nado de crol, avanza la cadera (4,5 s)
##   Mixamo_Flotar        de pie en el agua moviendo brazos, bucle    Mixamo_Voltereta  de pie, voltereta adelante y de pie; avanza ~4 alturas de cadera (2,4 s)
## Para usar uno como rol del juego basta cambiar aquí su nombre de destino por el del rol de Pj3D.SINONIMOS (y quitarlo de la fuente que lo diera antes).
## 5/11 (Pablo: «los marcados en negrita… las que veas buenas no las borres, déjalas porque pueden valer, como alt»): los 16 de docs/CLIPS_MIXAMO_CANDIDATOS.md entran
## como ALTERNATIVAS con su nombre Mixamo_* (ningún rol cambia de clip) repartidos por familia: jugadora, goblins (arquero y guerrero: rig de 27 huesos, el retarget
## solo copia los huesos que existen en el destino), ancianas (Marimanta y el chamán, 65 huesos) y NPC (alquimista). Se miran en LabJugadora3D (jugadora) y en
## LabHumanoide3D con «como el juego» (el resto). Los 21 clips van en UN solo GLB (arte/meshy/mixamo_clips.glb, herramientas/mixamo_clips_a_glb.gd).
##   Jugadora: Mixamo_CastArea1 / 2 (conjuro a dos manos hacia el suelo / recoger y soltar, una vez) · Mixamo_Curar (curación a una mano) · Mixamo_GolpeGrande (golpe recibido grande
##   de frente) · Mixamo_MorirAtras (cae muerta de espaldas) · Mixamo_Incorporarse (se levanta del suelo) · Mixamo_EmpujePesado (empuja algo pesado, bucle) · Mixamo_Beber (8,9 s) ·
##   Mixamo_AbrirTapa (abre la tapa de un cofre, 8,9 s). Goblins: Mixamo_TensarArco · Mixamo_Disparar (el retroceso del disparo) · Mixamo_GritoGuerra (provocación con hacha).
##   Ancianas: Mixamo_Rezar (de pie, balanceándose). NPC: Mixamo_Tabernero (sirve bebidas, 13,6 s).
## Los nombres de destino no contienen ninguna clave de Pj3D.SINONIMOS (hit, idle, walk, empujar, levantarse…): el tercer barrido de `_buscar_clip` busca por «contains».
## 5/11 (Pablo): Mixamo_Voltereta y Mixamo_Beber son YA los roles `roll` y `drink` de la jugadora (Pj3D.CLIPS_DE["jugadora_base"]); los casts y Curar se quedan como alternativas
## para hechizos distintos (muro, pilar…). Old_Man_Idle / Old_Man_Walk se probaron y se RETIRARON: llevan las manos juntas en la barriga, el bastón plantado de Marimanta y el
## chamán no encuentra la mano (se queda suelto) y el andar parece gesticular; no sirven con bastón. Siguen dentro del GLB por si hace falta un anciano sin bastón.
const RUTA_CLIPS_MIXAMO: String = "res://arte/meshy/mixamo_clips.glb"
const FUENTE_CLIPS_MIXAMO: Dictionary = {
	# centrar (medido con prueba_mixamo_clips.gd, desvío medio en alturas de cadera): Two_Hand_Spell_Casting 0,33 · Treading_Water · Magic_Heal 0,26. Push (0,59, recorre 1,17) y
	# Standing_React_Large_From_Front_2 (0,70, recorre 1,09) NO se centran: se desplazan de verdad (empuja andando; el golpe la echa atrás).
	"ruta": RUTA_CLIPS_MIXAMO, "referencia": "Idle", "centrar": ["Two_Hand_Spell_Casting", "Treading_Water", "Magic_Heal"], "clips": {
		"Mixamo_CastDosManos": "Two_Hand_Spell_Casting", "Mixamo_Nadar": "Swimming", "Mixamo_Flotar": "Treading_Water", "Mixamo_Voltereta": "Stand_To_Roll",
		"Mixamo_CastArea1": "Standing_2H_Magic_Area_Attack_01", "Mixamo_CastArea2": "Standing_2H_Magic_Area_Attack_02", "Mixamo_Curar": "Magic_Heal",
		"Mixamo_GolpeGrande": "Standing_React_Large_From_Front_2", "Mixamo_MorirAtras": "Falling_Back_Death", "Mixamo_Incorporarse": "Getting_Up",
		"Mixamo_EmpujePesado": "Push", "Mixamo_Beber": "Drinking", "Mixamo_AbrirTapa": "Opening_A_Lid",
	}}
const FUENTE_MIXAMO_GOBLIN: Dictionary = {
	"ruta": RUTA_CLIPS_MIXAMO, "referencia": "Idle", "clips": {
		"Mixamo_TensarArco": "Standing_Draw_Arrow", "Mixamo_Disparar": "Standing_Aim_Recoil", "Mixamo_GritoGuerra": "Standing_Taunt_Battlecry",
	}}
const FUENTE_MIXAMO_ANCIANA: Dictionary = {
	"ruta": RUTA_CLIPS_MIXAMO, "referencia": "Idle", "clips": {
		"Mixamo_Rezar": "Praying_2",
	}}
const FUENTE_MIXAMO_NPC: Dictionary = {
	"ruta": RUTA_CLIPS_MIXAMO, "referencia": "Idle", "centrar": ["Bartending"], "clips": {"Mixamo_Tabernero": "Bartending"}}   # la cadera a 0,49 alturas hacia atrás; se mueve 0,39 por la barra

## Modelos que SÍ traen AnimationPlayer propio (la elfa jugadora) y solo reciben clips de más: id de GLB -> fuentes (mismo formato que FUENTES). Nunca pisan un clip que ya tenga.
const EXTRAS: Dictionary = {
	"woodland_wanderer_suave": [FUENTE_CLIPS_JUGADORA, FUENTE_CLIPS_CARGA],
	"woodland_wanderer": [FUENTE_CLIPS_JUGADORA, FUENTE_CLIPS_CARGA],
	"chibi_elf": [FUENTE_CLIPS_JUGADORA, FUENTE_CLIPS_CARGA],
	"chibi_elf_v2": [FUENTE_CLIPS_JUGADORA, FUENTE_CLIPS_CARGA],
	# 5/11: alternativas de Mixamo (ver FUENTE_MIXAMO_*). Los goblins tienen el rig de Meshy de 27 huesos (sin dedos ni Toe_End): se copian los huesos que tienen.
	"goblin_archer_chibi": [FUENTE_MIXAMO_GOBLIN],
	"goblin_warrior_chibi": [FUENTE_MIXAMO_GOBLIN],
	"marimanta": [FUENTE_MIXAMO_ANCIANA],
	"alchemist_elf": [FUENTE_MIXAMO_NPC],
}

## Modelo (id de GLB) -> de dónde toma sus clips. Solo para modelos que NO traen AnimationPlayer propio. Cada fuente es un GLB de la familia (mismos
## nombres de hueso Mixamo, aunque no la misma pose de reposo) con:
##   · «ruta»: el GLB (con esqueleto y AnimationPlayer; la malla da igual y puede faltar: arte/meshy/solo_clips.py la quita);
##   · «referencia»: el clip de la fuente con el que los pies de la fuente pisan el suelo del destino (el reposo de pie; por defecto «Idle»);
##   · «clips»: {nombre en el destino: nombre en la fuente}. Vacío = todos los de la fuente con su propio nombre;
##   · «centrar» (opcional): nombres de clip de la fuente cuya cadera se centra sobre el personaje (`_centrar_cadera`).
## Si dos fuentes dan el mismo nombre de clip, gana la primera.
## SANTA COMPAÑA (9/11): la Willow Fernstep de Meshy pasada por Mixamo (los mismos huesos que jugadora_base), recortada a esqueleto
## y clips con arte/meshy/solo_clips.py (0,3 MB; el GLB con malla son 19 MB y no entra en el repo). Trae cuatro, y de ellos importan
## dos, uno para cada portador de la procesión:
##   Spear_Walk     anda con la mano CERRADA sobre un mango, como quien lleva una lanza: el que porta la cruz-bastón
##   Unsteady_Walk  anda tambaleándose, de ánima: el que porta la vela
## Las entradas van por ID DE PERSONAJE, no por GLB, porque las dos variantes comparten modelo (ver Pj3D.MODELO_DE).
const RUTA_CLIPS_SANTA: String = "res://arte/meshy/santa_compana_clips.glb"
## 9/11 (Pablo: «mira cómo no está bien al andar»): el andar va con el nombre «Walking», NO con el rol «walk». Pj3D.SINONIMOS
## busca el rol walk como ["walking", "walk"] EN ESE ORDEN, así que mientras el clip se llamó «walk» el juego seguía andando con
## el «Walking» de la elfa y el andar de cada portador no se usaba nunca. Y ese Walking es el que se ve cruzado: medido con
## herramientas/medidas_piernas_clip.gd, junta los pies a 0,045 cuando en reposo están a 0,196 (anda sobre una línea, y con la
## túnica ancha las piernas se solapan). Unsteady_Walk los separa 0,12-0,26 y Spear_Walk, 0,068.
const FUENTE_SANTA_CRUZ: Dictionary = {
	"ruta": RUTA_CLIPS_SANTA, "referencia": "Spear_Walk", "clips": {"Walking": "Spear_Walk", "run": "Running"}}
const FUENTE_SANTA_VELA: Dictionary = {
	"ruta": RUTA_CLIPS_SANTA, "referencia": "Walking", "clips": {"Walking": "Unsteady_Walk", "run": "Running"}}

const FUENTES: Dictionary = {
	"elfo_base": [
		{"ruta": "res://arte/modelos/chibi_elf.glb", "referencia": "Idle", "clips": {}},
	],
	# Jugadora base (23/10, Meshy «Willow Fernstep» pasada a Mixamo, 65 huesos con dedos + headfront): los 22 clips de la elfa actual.
	"jugadora_base": [
		{"ruta": "res://arte/modelos/chibi_elf.glb", "referencia": "Idle", "clips": {}},
		FUENTE_CLIPS_JUGADORA,       # 24/10: abrir_cofre, agacharse, ofrecer, saludo y empujar (ver arriba)
		FUENTE_UNA_MANO,             # 24/10: los tres casts a una mano (CastOneHandFront / Up / Ground)
		FUENTE_CLIPS_CARGA,          # 4/11: cargar_idle, cargar_andar, levantar, lanzar_objeto, dejar_objeto y coger_lanzar (ver arriba)
		FUENTE_CLIPS_MIXAMO,         # 5/11: Mixamo_CastDosManos, Mixamo_Nadar, Mixamo_Flotar y Mixamo_Voltereta (ver arriba)
	],
	# Chamán goblin (28/10): el esqueleto de Marimanta (66 huesos con las MISMAS bases de hueso: tools/autorig_chaman.py) y sus 7 clips (idle, andar de anciana, hablar, tramar, correr); las reacciones
	# (hit, death, ahogarse), del goblin guerrero como las del asesino. `trazar` y `clavar` los genera AnimacionesChaman. Con `{}` se traen todos los de Marimanta con su nombre.
	"goblin_chaman_rig": [
		{"ruta": "res://arte/modelos/marimanta.glb", "referencia": "Idle_02", "clips": {}},
		{"ruta": "res://arte/modelos/goblin_warrior_chibi.glb", "referencia": "Idle", "clips": {
			"hit": "SlapReaction", "death": "Die", "drowning": "Drowning",
		}},
		FUENTE_MIXAMO_ANCIANA,       # 5/11: Mixamo_Rezar, alternativa para mirar (los Old_Man_* se retiraron: no sujetan el bastón)
	],
	# Santa Compaña (9/11): el rig sale de tools/autorig_fantasma.py con el fantasma de donante, así que su esqueleto es el de
	# elfo_base y hereda los 22 clips de la elfa. Lo único que cambia entre las dos variantes es el ANDAR, y por eso van por id.
	# Fantasma elfo (10/11, Pablo: «el fantasma se bloquea en el laboratorio»). Su esqueleto es el de elfo_base (tools/autorig_fantasma.py),
	# pero se añadió al LabHumanoide3D sin esta entrada: cargaba con CERO clips y se quedaba clavado en reposo, sin que nada fallara.
	# Hereda los clips de la elfa, igual que elfo_base, salvo el ANDAR (Pablo, 10/11: «ponle el andar tipo zombi»): el tambaleante
	# Unsteady_Walk, que entra como «Walking» por la misma razón que en la procesión (ver FUENTE_SANTA_VELA). Va primero y gana.
	"fantasma_elfo_rig": [
		FUENTE_SANTA_VELA,
		{"ruta": "res://arte/modelos/chibi_elf.glb", "referencia": "Idle", "clips": {}},
	],
	"santa_compana_cruz": [
		FUENTE_SANTA_CRUZ,
		{"ruta": "res://arte/modelos/chibi_elf.glb", "referencia": "Idle", "clips": {}},
	],
	"santa_compana_vela": [
		FUENTE_SANTA_VELA,
		{"ruta": "res://arte/modelos/chibi_elf.glb", "referencia": "Idle", "clips": {}},
	],
	# Goblin asesino (22/10): el movimiento sale de «Gribble the Goblin, All Animations» (Meshy; solo su esqueleto y sus clips) y las reacciones, de los
	# clips del goblin guerrero (el mismo rig de Meshy). Nombres de destino = los de los roles de Pj3D.SINONIMOS.
	"goblin_asesino": [
		{"ruta": "res://arte/meshy/gribble_clips.glb", "referencia": "Combat_Stance", "centrar": ["Combat_Stance"], "clips": {
			"idle": "Combat_Stance",                              # guardia con las rodillas dobladas
			"walk": "Crouch_Walk_with_Torch",                     # el andar agazapado hacia delante (lleva el brazo de la antorcha)
			"run": "Running",
			"paso_lado": "Cautious_Crouch_Walk_Right_inplace",    # agazapado, pero de LADO (no sirve para avanzar)
			"guardia": "_01a165a5_cbee_74b5_b15b_32bb9f9f273a",   # sin nombre: pasos de boxeador con la guardia alta; avanza (no es un ataque)
		}},
		{"ruta": "res://arte/modelos/goblin_warrior_chibi.glb", "referencia": "Idle", "clips": {
			"hit": "SlapReaction", "death": "Die", "drowning": "Drowning",
		}},
	],
}

## Muestreo de los clips traducidos (los de la fuente van a 30 fps).
const FPS_MUESTREO: float = 30.0
## Cadera de la fuente por debajo de esto (u) = no se puede calcular la relación de alturas: se deja la escala en 1.
const CADERA_MIN: float = 0.01
## Terminaciones de los huesos que cuentan como «suela» para apoyar los pies (el más bajo de ellos manda).
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]
## Clip de la fuente con el que se mide la altura de los pies si la fuente no dice otro (el reposo de pie).
const CLIP_REFERENCIA: String = "Idle"

## TOPE DE HUNDIMIENTO (9/11, Pablo: «sí, arréglalo»). El retarget sube o baja cada clip una cantidad FIJA, medida con el clip de referencia
## (el reposo de pie). Eso vale mientras el personaje esté de pie, pero no cuando el clip lo tumba o lo arrodilla: ahí las proporciones del
## destino no son las de la fuente y el cuerpo acaba por debajo del suelo. Medido con herramientas/medidas_hundimiento.gd (fracción del alto):
##   Dead                -0,229  al caer, el cuerpo TUMBADO entero se mete bajo el suelo
##   ChargedGroundSlam   -0,057  se arrodilla y la rodilla queda enterrada
##   RollDodge           -0,083  la voltereta
## Y no es cosa de un personaje: la jugadora se hunde en los mismos tres (Dead -0,130). Así que en cada fotograma se sube lo justo para que
## nada quede bajo el suelo. SOLO SUBE, nunca baja: un clip puede estar en el aire (saltos, nadar) y eso no se toca.
## Qué cuenta para el tope: NO vale mirar solo la «suela», porque en una muerte de espaldas lo que toca el suelo es la espalda y subir la
## figura por el pie la dejaría flotando. Tampoco vale mirar TODOS los huesos: al rodar, las manos pasan por el suelo y los dedos llegan a
## -0,24, así que la voltereta botaría 0,24 por culpa de un meñique. Se miran el tronco y las piernas, y se deja fuera la cadena del brazo.
## Lo que esto cuesta: en la voltereta el mayor salto vertical de la cadera entre dos fotogramas pasa de 0,097 a 0,121 del alto (el tope
## levanta mientras el cuerpo rueda). A cambio, en la muerte BAJA de 0,452 a 0,288: la caída queda menos brusca que antes.
const APOYO_FUERA: PackedStringArray = ["Shoulder", "Arm", "Hand", "Thumb", "Index", "Middle", "Ring", "Pinky"]
## El suelo está en y = 0 en el espacio del esqueleto (el reposo apoya ahí los pies). Los huesos van DENTRO de la carne, así que dejar el más
## bajo justo en 0 todavía mete algo de malla bajo el suelo; es mucho mejor que los 0,23 de antes y no levanta la figura de más.
const SUELO_Y: float = 0.0
## false = sin tope (para medir el antes y el después en las pruebas; hay que vaciar la caché con `vaciar_cache()`).
static var tope_hundimiento_activo: bool = true
## Tolerancia (en grados) de la rotación del nodo del esqueleto respecto al modelo: por encima, el retarget asume que fuente y destino difieren y avisa.
const GIRO_NODO_TOL: float = 1.0

## ALINEAR EL REPOSO (24/10, Pipeline, diario 255; el «Rest Fixer» de PLAN_RIGGING §4): id del GLB destino -> huesos (nombre sin «mixamorig_» ni lado) cuyo TRAMO
## (de su articulación a la del hijo) se alinea con el de la fuente antes de copiar el movimiento. Sin alinear, el retarget copia el giro de cada hueso
## RESPECTO A SU REPOSO, así que una diferencia de reposo pasa entera al destino: chibi_elf tiene en reposo la rodilla doblada hacia ATRÁS (muslo −10,7°,
## espinilla +22°, 31° de ángulo) y sus clips la llevan hacia delante (idle: muslo +12,7°, espinilla −13,8°); jugadora_base tiene la pierna recta en
## reposo (6,6°), así que heredaba esos 31° de más: rodillas a 63–69° en idle y la cadera 8 cm más baja (medido en
## herramientas/prueba_rigging_postura.gd). Lo mismo los brazos: su reposo en A (31° de la vertical) frente al de la fuente (40°) los dejaba pegados al cuerpo y
## adelantados (idle: 4° de apertura y 8° hacia delante; chibi_elf, 12° y 0°). Alineado, el tramo del destino apunta adonde apunta el de la fuente (el giro
## sobre su propio eje sigue siendo el de antes). Solo los huesos listados: la columna, el cuello y la cabeza de jugadora_base van mejor sin alinear (su
## reposo es el de la malla y ya quedan a ≤5° de los de chibi_elf), y el pie y la mano conservan su reposo. Los clips de otros destinos (goblins, elfo_base,
## EXTRAS de la elfa) no cambian.
const ALINEAR_REPOSO: Dictionary = {
	# 24/10 (Pablo: «la postura de las manos al andar»): también la muñeca («Hand»: el tramo muñeca → primera falange, si la fuente tiene un hijo con el mismo
	# nombre; si no, queda como estaba). Los dedos no se alinean: no tienen pista en la fuente y su reposo lo cierra Pj3D.MANO_RELAJADA.
	# 25/10 (Pablo: «los pies están girados»): también el pie («Foot»: tramo tobillo → base de los dedos). Sin alinearlo, el pie izquierdo apuntaba 11,5° hacia
	# DENTRO en idle y el derecho 1,4°, cuando la fuente los lleva hacia fuera; el tramo alineado copia la orientación del pie de la fuente.
	"jugadora_base": ["UpLeg", "Leg", "Arm", "ForeArm", "Hand", "Foot"],
	# 5/11 (Pablo: «en el alquimista revisa tabernero, están los brazos mal, no se posicionan adelante»): los rigs de Meshy de 27 huesos (alquimista, goblins) tienen el reposo de los
	# brazos distinto al Y Bot de Mixamo y los clips de Mixamo (solo entran por EXTRAS: sus clips propios no pasan por aquí) les dejaban los brazos caídos y atrás. Solo brazos.
	"alchemist_elf": ["Arm", "ForeArm", "Hand"],
	"goblin_archer_chibi": ["Arm", "ForeArm", "Hand"],
	"goblin_warrior_chibi": ["Arm", "ForeArm", "Hand"],
}
## false = retarget de antes sin alinear (para medir el antes y el después en las pruebas; hay que vaciar la caché con `vaciar_cache()`).
static var alinear_activo: bool = true

static var _cache: Dictionary = {}     ## id del GLB destino -> {nombre de clip: Animation}
static var _cache_clip: Dictionary = {}    ## id|ruta|clip -> Animation traducida suelta (ver `traducir_clip`)


static func tiene_fuente(glb_id: String) -> bool:
	return FUENTES.has(glb_id)


## Olvida los clips ya traducidos (las pruebas que comparan con y sin `alinear_activo`). Los Pj3D ya cargados conservan los suyos.
static func vaciar_cache() -> void:
	_cache.clear()
	_cache_clip.clear()


## Los huesos que se alinean al reposo de la fuente en el destino `glb_id` (ALINEAR_REPOSO), o ninguno.
static func alinear_de(glb_id: String) -> Array:
	return (ALINEAR_REPOSO.get(glb_id, []) as Array) if alinear_activo else []


static func tiene_extras(glb_id: String) -> bool:
	return EXTRAS.has(glb_id)


## Los clips de más (EXTRAS) de un modelo que ya trae los suyos, traducidos a su esqueleto `sk_d`. Mismas reglas que `clips_para`, y los clips que la fuente marca como «plantar»
## apoyan la suela más baja a la altura que tiene el Idle PROPIO del modelo (`ap`), no a la del reposo del esqueleto: la elfa jugadora pisa 2 % del alto por debajo de su reposo.
static func extras_para(glb_id: String, modelo_d: Node3D, sk_d: Skeleton3D, ap: AnimationPlayer = null) -> Dictionary:
	var clave: String = "extras|" + glb_id
	if _cache.has(clave):
		return _cache[clave]
	var res: Dictionary = {}
	var objetivo: float = NAN
	if ap != null and ap.has_animation(CLIP_REFERENCIA):
		objetivo = _suela_de_clip(sk_d, ap.get_animation(CLIP_REFERENCIA))
	for f in (EXTRAS.get(glb_id, []) as Array):
		var fuente: Dictionary = (f as Dictionary).duplicate()
		if not is_nan(objetivo):
			fuente["suela_objetivo"] = objetivo
		_traer_de(fuente, modelo_d, sk_d, res, alinear_de(glb_id))
	if not res.is_empty():
		_cache[clave] = res
	return res


## Altura (espacio del esqueleto) de la suela más baja de `sk` con el clip `an` en su primer fotograma. El clip es de ESTE esqueleto (sus pistas, sus huesos).
static func _suela_de_clip(sk: Skeleton3D, an: Animation) -> float:
	var cadera: int = sk.find_bone("mixamorig_Hips")
	var rot: Dictionary = {}
	var p_cad: Vector3 = sk.get_bone_rest(cadera).origin if cadera >= 0 else Vector3.ZERO
	for t in range(an.get_track_count()):
		var b: int = sk.find_bone(String(an.track_get_path(t)).get_slice(":", 1))
		if b < 0 or an.track_get_key_count(t) == 0:
			continue
		if an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot[b] = an.rotation_track_interpolate(t, 0.0)
		elif an.track_get_type(t) == Animation.TYPE_POSITION_3D and b == cadera:
			p_cad = an.position_track_interpolate(t, 0.0)
	var g: Dictionary = {}
	var minimo: float = INF
	for i in _Ctx._orden(sk):
		var q: Quaternion = rot.get(i, _Ctx._quat(sk.get_bone_rest(i).basis))
		var loc := Transform3D(Basis(q), p_cad if i == cadera else sk.get_bone_rest(i).origin)
		var p: int = sk.get_bone_parent(i)
		g[i] = loc if p < 0 else (g[p] as Transform3D) * loc
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				minimo = minf(minimo, (g[i] as Transform3D).origin.y)
				break
	return minimo if minimo != INF else NAN


## Los clips de la familia ya traducidos al esqueleto `sk_d` del modelo `modelo_d` (raíz de la escena del GLB `glb_id`). Las pistas llevan la ruta
## del esqueleto relativa a `modelo_d`, así que el AnimationPlayer ha de colgar de `modelo_d` (root_node = ".."). Vacío si algo falla.
static func clips_para(glb_id: String, modelo_d: Node3D, sk_d: Skeleton3D) -> Dictionary:
	if _cache.has(glb_id):
		return _cache[glb_id]
	var res: Dictionary = {}
	for f in (FUENTES.get(glb_id, []) as Array):
		_traer_de(f as Dictionary, modelo_d, sk_d, res, alinear_de(glb_id))
	if not res.is_empty():
		_cache[glb_id] = res
	return res


## Un clip suelto de OTRO GLB de la familia (p. ej. el BeHit_FlyUp del empujado) traducido al esqueleto `sk_d`, o null. Sin la subida de pies de los clips
## de `clips_para`: quien lo use (Pj3D._construir_clip) reescribe la cadera con sus propias alturas y solo toma de aquí la traslación RELATIVA y los giros.
## `escala_cadera` > 0 sustituye la relación de alturas de cadera por esa escala (para vuelos y caídas, que deben ser del mismo tamaño RELATIVO al modelo entero).
static func traducir_clip(glb_id: String, ruta: String, clip: String, modelo_d: Node3D, sk_d: Skeleton3D, escala_cadera: float = 0.0) -> Animation:
	var clave: String = glb_id + "|" + ruta + "|" + clip
	if _cache_clip.has(clave):
		return _cache_clip[clave] as Animation
	var res: Animation = null
	var fuente: Node3D = _abrir(ruta)
	if fuente != null:
		var sks: Array[Node] = fuente.find_children("*", "Skeleton3D", true, false)
		var aps: Array[Node] = fuente.find_children("*", "AnimationPlayer", true, false)
		if not sks.is_empty() and not aps.is_empty() and (aps[0] as AnimationPlayer).has_animation(clip):
			var c := _Ctx.new()
			c.preparar(fuente, sks[0] as Skeleton3D, modelo_d, sk_d, alinear_de(glb_id))
			if escala_cadera > 0.0:
				c.escala_cadera = escala_cadera
			res = (c.traducir((aps[0] as AnimationPlayer).get_animation(clip), String(modelo_d.get_path_to(sk_d)) + ":") as Array)[0]
		fuente.free()
	_cache_clip[clave] = res
	return res


static func _abrir(ruta: String) -> Node3D:
	if ruta == "" or not ResourceLoader.exists(ruta):
		return null
	var sc: PackedScene = load(ruta) as PackedScene
	return sc.instantiate() as Node3D if sc != null else null


## Traduce los clips de la fuente `f` (ver FUENTES) y los añade a `res` (sin pisar los que ya estén). `alinear`: ver ALINEAR_REPOSO.
static func _traer_de(f: Dictionary, modelo_d: Node3D, sk_d: Skeleton3D, res: Dictionary, alinear: Array = []) -> void:
	var fuente: Node3D = _abrir(String(f.get("ruta", "")))
	if fuente == null:
		return
	var sks: Array[Node] = fuente.find_children("*", "Skeleton3D", true, false)
	var aps: Array[Node] = fuente.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		fuente.free()
		return
	var ap_s: AnimationPlayer = aps[0] as AnimationPlayer
	var c := _Ctx.new()
	c.preparar(fuente, sks[0] as Skeleton3D, modelo_d, sk_d, alinear)
	var base: String = String(modelo_d.get_path_to(sk_d)) + ":"
	# 1) la altura de los pies: con el clip de referencia de la fuente, cuánto hay que subir/bajar la cadera destino.
	var referencia: String = String(f.get("referencia", CLIP_REFERENCIA))
	var sube: float = 0.0
	if ap_s.has_animation(referencia):
		c.sube = 0.0
		var medido: Array = c.traducir(ap_s.get_animation(referencia), base)
		sube = c.suela_reposo - float(medido[1])
	c.sube = sube
	# El tope de hundimiento se enciende AQUÍ, no antes: la pasada de arriba mide con el clip de referencia cuánto hay que subir el
	# clip entero, y si el tope ya estuviera puesto falsearía esa medida. No se usa en `traducir_clip` (el empujado y levantarse de
	# Pj3D), que reescribe la cadera con sus propias alturas y no quiere que nadie le toque la vertical.
	c.tope = tope_hundimiento_activo
	# 2) los clips pedidos (o todos, con su nombre)
	var pedidos: Dictionary = (f.get("clips", {}) as Dictionary).duplicate()
	if pedidos.is_empty():
		for nombre in ap_s.get_animation_list():
			pedidos[nombre] = nombre
	for destino in pedidos.keys():
		var origen: String = String(pedidos[destino])
		if res.has(destino):
			continue
		if not ap_s.has_animation(origen):
			push_warning("ClipsFamilia: la fuente %s no tiene el clip «%s»" % [f.get("ruta", ""), origen])
			continue
		c.plantar = (f.get("plantar", []) as Array).has(origen)
		c.suela_objetivo = float(f.get("suela_objetivo", NAN))
		var traducido: Animation = (c.traducir(ap_s.get_animation(origen), base) as Array)[0]
		if (f.get("centrar", []) as Array).has(origen):
			_centrar_cadera(traducido, sk_d)
		res[destino] = traducido
	fuente.free()


## Quita al clip `an` el desplazamiento medio de la cadera en el plano del suelo, para que quede centrado sobre el personaje (los clips «en el sitio» de Mixamo traen la
## postura puesta a un lado: Combat_Stance de Gribble desplaza la cadera 0,34 de su alto de cadera). La altura no se toca.
static func _centrar_cadera(an: Animation, sk_d: Skeleton3D) -> void:
	var cadera: int = sk_d.find_bone("mixamorig_Hips")
	if cadera < 0:
		return
	var reposo: Vector3 = sk_d.get_bone_rest(cadera).origin
	for t in range(an.get_track_count()):
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(an.track_get_path(t)).ends_with("mixamorig_Hips"):
			continue
		var n: int = an.track_get_key_count(t)
		if n == 0:
			continue
		var media := Vector2.ZERO
		for k in range(n):
			var v: Vector3 = an.track_get_key_value(t, k)
			media += Vector2(v.x, v.z)
		media /= float(n)
		var corrige := Vector2(media.x - reposo.x, media.y - reposo.z)
		for k in range(n):
			var v2: Vector3 = an.track_get_key_value(t, k)
			an.track_set_key_value(t, k, Vector3(v2.x - corrige.x, v2.y, v2.z - corrige.y))


## Estado del retarget entre una fuente y un destino.
class _Ctx:
	var sk_s: Skeleton3D
	var sk_d: Skeleton3D
	var orden_d: Array = []                       ## índices de hueso destino, padres antes que hijos
	var orden_s: Array = []
	var mapa: Array = []                          ## hueso destino -> hueso fuente (-1 = no existe en la fuente)
	var rs: Quaternion = Quaternion.IDENTITY      ## rotación del esqueleto fuente respecto a la raíz de su escena
	var rd: Quaternion = Quaternion.IDENTITY
	var gr_s: Array = []                          ## rotación global de reposo (espacio de la raíz) de cada hueso
	var gr_d: Array = []
	var rl_d: Array = []                          ## rotación local de reposo destino
	var rl_s: Array = []
	var cadera_s: int = -1
	var cadera_d: int = -1
	var escala_cadera: float = 1.0
	var suela_d: Array = []                       ## huesos destino que cuentan como suela
	var apoyo_d: Array = []                       ## huesos destino que cuentan para el tope de hundimiento (tronco y piernas: ver APOYO_FUERA)
	var tope: bool = false                        ## true = en cada fotograma sube lo justo para que ningún hueso de `apoyo_d` quede bajo el suelo
	var suela_reposo: float = 0.0                 ## altura del hueso de suela más bajo con el esqueleto destino en reposo
	var sube: float = 0.0                         ## cuánto se desplaza en vertical la cadera destino en todos los clips
	var plantar: bool = false                     ## true = en CADA fotograma la cadera sube o baja lo justo para que la suela más baja quede a `suela_objetivo` (agachadas, empujar)
	var suela_objetivo: float = NAN               ## altura de esa suela con `plantar` (NAN = la del reposo del esqueleto destino, `suela_reposo`)
	var alin: Array = []                          ## hueso destino -> giro (espacio de la raíz) que lleva su tramo de reposo al de la fuente (identidad = sin alinear)

	func preparar(raiz_s: Node3D, p_sk_s: Skeleton3D, raiz_d: Node3D, p_sk_d: Skeleton3D, alinear: Array = []) -> void:
		sk_s = p_sk_s
		sk_d = p_sk_d
		rs = _giro_a_raiz(sk_s, raiz_s)
		rd = _giro_a_raiz(sk_d, raiz_d)
		if rs.angle_to(rd) > deg_to_rad(GIRO_NODO_TOL):
			push_warning("ClipsFamilia: el esqueleto fuente y el destino no están orientados igual en su escena (%.1f°)" % rad_to_deg(rs.angle_to(rd)))
		orden_s = _orden(sk_s)
		orden_d = _orden(sk_d)
		for i in range(sk_s.get_bone_count()):
			gr_s.append(rs * _quat(sk_s.get_bone_global_rest(i).basis))
			rl_s.append(_quat(sk_s.get_bone_rest(i).basis))
		var min_y: float = INF
		for i in range(sk_d.get_bone_count()):
			gr_d.append(rd * _quat(sk_d.get_bone_global_rest(i).basis))
			rl_d.append(_quat(sk_d.get_bone_rest(i).basis))
			mapa.append(sk_s.find_bone(sk_d.get_bone_name(i)))
			for fin in HUESOS_SUELA:
				if sk_d.get_bone_name(i).ends_with(fin):
					suela_d.append(i)
					min_y = minf(min_y, sk_d.get_bone_global_rest(i).origin.y)
					break
			# Tope de hundimiento: cuentan el tronco y las piernas, no la cadena del brazo (ver APOYO_FUERA). Y solo huesos que la
			# FUENTE también tiene, o sea, los que el clip anima de verdad: los de la capa y demás añadidos del destino los mueve
			# otro (la ropa), el retarget no responde de ellos, y una capa que roza el suelo al rodar es normal. Contándolos, la
			# voltereta de la jugadora levantaba al personaje 0,18 del alto por un pliegue de tela.
			var del_brazo: bool = false
			for fuera in APOYO_FUERA:
				if sk_d.get_bone_name(i).contains(fuera):
					del_brazo = true
					break
			if not del_brazo and sk_s.find_bone(sk_d.get_bone_name(i)) >= 0:
				apoyo_d.append(i)
		suela_reposo = min_y if min_y != INF else 0.0
		alin.resize(sk_d.get_bone_count())
		alin.fill(Quaternion.IDENTITY)
		for i in range(sk_d.get_bone_count()):
			if int(mapa[i]) >= 0 and _se_alinea(sk_d.get_bone_name(i), alinear):
				alin[i] = _giro_alinear(i, int(mapa[i]))
		cadera_s = sk_s.find_bone("mixamorig_Hips")
		cadera_d = sk_d.find_bone("mixamorig_Hips")
		if cadera_s >= 0 and cadera_d >= 0:
			var hs: float = sk_s.get_bone_rest(cadera_s).origin.y
			if hs > CADERA_MIN:
				escala_cadera = sk_d.get_bone_rest(cadera_d).origin.y / hs

	## Traduce `an` (de la fuente) al destino. Devuelve [Animation, altura media del pie más bajo (sin contar `sube`)].
	func traducir(an: Animation, prefijo: String) -> Array:
		var dest := Animation.new()
		dest.length = an.length
		dest.loop_mode = an.loop_mode
		var n_d: int = sk_d.get_bone_count()
		var pista_rot: Array = []     # hueso destino -> pista de rotación de la fuente (-1 = sin pista, se queda en reposo)
		pista_rot.resize(sk_s.get_bone_count())
		pista_rot.fill(-1)
		var pista_pos: int = -1
		for t in range(an.get_track_count()):
			var hueso: String = String(an.track_get_path(t)).get_slice(":", 1)
			var b: int = sk_s.find_bone(hueso)
			if b < 0:
				continue
			if an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				pista_rot[b] = t
			elif an.track_get_type(t) == Animation.TYPE_POSITION_3D and b == cadera_s:
				pista_pos = t
		# Pistas destino: una de rotación por hueso con equivalente + la posición de la cadera.
		var pd_rot: Array = []
		pd_rot.resize(n_d)
		pd_rot.fill(-1)
		for i in range(n_d):
			if int(mapa[i]) >= 0:
				var t_n: int = dest.add_track(Animation.TYPE_ROTATION_3D)
				dest.track_set_path(t_n, NodePath(prefijo + sk_d.get_bone_name(i)))
				pd_rot[i] = t_n
		var t_pos: int = -1
		if cadera_d >= 0 and cadera_s >= 0:
			t_pos = dest.add_track(Animation.TYPE_POSITION_3D)
			dest.track_set_path(t_pos, NodePath(prefijo + sk_d.get_bone_name(cadera_d)))
		var pasos: int = maxi(int(ceil(an.length * FPS_MUESTREO)), 1)
		var suma_suela: float = 0.0
		var r_cad_d: Vector3 = sk_d.get_bone_rest(cadera_d).origin if cadera_d >= 0 else Vector3.ZERO
		var r_cad_s: Vector3 = sk_s.get_bone_rest(cadera_s).origin if cadera_s >= 0 else Vector3.ZERO
		for k in range(pasos + 1):
			var tiempo: float = minf(float(k) / FPS_MUESTREO, an.length)
			# Fuente: rotaciones globales animadas.
			var ga_s: Array = []
			ga_s.resize(sk_s.get_bone_count())
			for i in orden_s:
				var p: int = sk_s.get_bone_parent(i)
				var loc: Quaternion = rl_s[i]
				if int(pista_rot[i]) >= 0:
					loc = an.rotation_track_interpolate(int(pista_rot[i]), tiempo)
				ga_s[i] = (rs if p < 0 else ga_s[p] as Quaternion) * loc
			# Destino: el movimiento de la fuente sobre el reposo destino.
			var ga_d: Array = []
			ga_d.resize(n_d)
			var pos: Array = []
			pos.resize(n_d)
			var p_cad: Vector3 = r_cad_d
			if pista_pos >= 0:
				var delta_p: Vector3 = an.position_track_interpolate(pista_pos, tiempo) - r_cad_s
				p_cad = r_cad_d + rd.inverse() * (rs * delta_p) * escala_cadera
			p_cad.y += sube
			var suelo: float = INF
			var apoyo: float = INF
			for i in orden_d:
				var p: int = sk_d.get_bone_parent(i)
				var j: int = int(mapa[i])
				if j >= 0:
					ga_d[i] = ((ga_s[j] as Quaternion) * (gr_s[j] as Quaternion).inverse()) * (alin[i] as Quaternion) * (gr_d[i] as Quaternion)
				else:
					ga_d[i] = (rd if p < 0 else ga_d[p] as Quaternion) * (rl_d[i] as Quaternion)
				var padre_q: Quaternion = rd if p < 0 else ga_d[p] as Quaternion
				if int(pd_rot[i]) >= 0:
					dest.rotation_track_insert_key(int(pd_rot[i]), tiempo, (padre_q.inverse() * (ga_d[i] as Quaternion)).normalized())
				# Posición (espacio del esqueleto) para medir los pies.
				if p < 0:
					pos[i] = p_cad if i == cadera_d else sk_d.get_bone_rest(i).origin
				else:
					pos[i] = (pos[p] as Vector3) + (rd.inverse() * (ga_d[p] as Quaternion)) * sk_d.get_bone_rest(i).origin
				if suela_d.has(i):
					suelo = minf(suelo, (pos[i] as Vector3).y)
				if apoyo_d.has(i):
					apoyo = minf(apoyo, (pos[i] as Vector3).y)
			if plantar and suelo != INF:
				# Pies en el suelo en cada fotograma: toda la figura sube o baja lo que la suela más baja se aleja de su sitio.
				var corrige: float = (suela_reposo if is_nan(suela_objetivo) else suela_objetivo) - suelo
				p_cad.y += corrige
				suelo += corrige
			elif tope and apoyo != INF and apoyo < SUELO_Y:
				# Tope de hundimiento (ver arriba): nada del tronco ni de las piernas por debajo del suelo. SOLO SUBE.
				var sube_tope: float = SUELO_Y - apoyo
				p_cad.y += sube_tope
				suelo += sube_tope
			if t_pos >= 0:
				dest.position_track_insert_key(t_pos, tiempo, p_cad)
			suma_suela += (suelo if suelo != INF else 0.0) - sube
		return [dest, suma_suela / float(pasos + 1)]

	static func _quat(b: Basis) -> Quaternion:
		return b.orthonormalized().get_rotation_quaternion()

	## ¿El hueso `nombre` está en la lista `alinear` (nombres sin prefijo ni lado: «UpLeg» vale para mixamorig_LeftUpLeg y mixamorig_RightUpLeg)?
	static func _se_alinea(nombre: String, alinear: Array) -> bool:
		for a in alinear:
			for pre in ["_", ":", "Left", "Right"]:
				if nombre.ends_with(pre + String(a)):
					return true
		return false

	## Giro mínimo (espacio de la raíz) que lleva el tramo de reposo del hueso destino `i` (de su articulación a la de su hijo) al del hueso fuente `j`
	## (al hijo del mismo nombre). Identidad si el hueso no tiene un hijo común a los dos esqueletos.
	func _giro_alinear(i: int, j: int) -> Quaternion:
		for h in sk_d.get_bone_children(i):
			var hs: int = sk_s.find_bone(sk_d.get_bone_name(h))
			if hs < 0 or sk_s.get_bone_parent(hs) != j:
				continue
			var dir_d: Vector3 = rd * (sk_d.get_bone_global_rest(h).origin - sk_d.get_bone_global_rest(i).origin)
			var dir_s: Vector3 = rs * (sk_s.get_bone_global_rest(hs).origin - sk_s.get_bone_global_rest(j).origin)
			if dir_d.length() < CADERA_MIN * 0.01 or dir_s.length() < CADERA_MIN * 0.01:
				return Quaternion.IDENTITY
			return Quaternion(dir_d.normalized(), dir_s.normalized())
		return Quaternion.IDENTITY

	## Rotación del nodo `n` respecto a la raíz `raiz` (producto de las rotaciones de los nodos intermedios).
	static func _giro_a_raiz(n: Node3D, raiz: Node3D) -> Quaternion:
		var q: Quaternion = Quaternion.IDENTITY
		var actual: Node = n
		while actual != null and actual != raiz:
			if actual is Node3D:
				q = _quat((actual as Node3D).transform.basis) * q
			actual = actual.get_parent()
		return q

	## Índices de hueso con los padres antes que los hijos.
	static func _orden(sk: Skeleton3D) -> Array:
		var res: Array = []
		var visto: Dictionary = {}
		for i in range(sk.get_bone_count()):
			var cadena: Array = []
			var b: int = i
			while b >= 0 and not visto.has(b):
				cadena.push_front(b)
				visto[b] = true
				b = sk.get_bone_parent(b)
			res.append_array(cadena)
		return res

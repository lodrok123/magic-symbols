class_name Pj3D
extends Node3D

## Un personaje del pipeline como modelo 3D vivo (la chibi, hero_v2...). Sin sprites ni atlas:
## se carga el GLB maestro de res://arte/modelos/<id>.glb, se apoya en el suelo y se anima con el
## AnimationPlayer del propio modelo. Se gira libremente hacia donde se mueve (no hay 8 filas).

const SINONIMOS: Dictionary = {
	"idle": ["idle"],
	"walk": ["walking", "walk"],
	"walk02": ["walk002"],
	"walk_back": ["walk_backward", "walkbackward", "walk_back"],
	"run": ["running", "run"],
	# El cast genérico es el que se queda en su sitio (4.8: MageSoellCast001 arrastraba la cadera 0,36).
	"cast": ["magesoellcast003", "charged_spell_cast_001", "magesoellcast001", "magespellcast001", "spell_cast",
		"spellcast", "soellcast", "cast"],
	# Clips de lanzar por forma (ANIM_CAST); sin ellos, "leer" (readandwrite).
	"cast_proyectil": ["magesoellcast003"],
	"cast_corro": ["chargedgroundslam"],
	"cast_columna": ["chargedspellcast002"],
	"cast_muro": ["magesoellcast002"],
	# T-CP1 (18/10): el empuje a dos manos (variación x_empuje) y los tres clips a UNA mano del Pipeline (diario 150; están en woodland_wanderer_suave.glb).
	"cast_empuje": ["magesoellcast001"],
	"cast_mano_frente": ["castonehandfront"],
	"cast_mano_alto": ["castonehandup"],
	"cast_mano_suelo": ["castonehandground"],
	"hit": ["hit_reaction", "hit", "facepunchreaction", "slapreaction"],
	"death": ["shot_and_fall_backward", "shot_in_the_back_and_fall", "death", "dead", "die"],
	# Ahogarse (diario 231): el clip «Drowning» de los goblins. Sin esta entrada el rol solo se encontraba por el segundo barrido (`contains("drown")`).
	"drown": ["drowning", "drown", "ahogarse"],
	# Ser empujado y levantarse (22/10): los dos clips se traen de goblin_behit_flyup.glb y goblin_stand_up.glb (ver `_preparar_empujado`) con estos nombres.
	# OJO: no llamarlos «…hit…» (el segundo barrido de `_buscar_clip` busca por «contains» y el rol `hit` se llevaría el empujado).
	"empujado": ["empujado"],
	"levantarse": ["levantarse"],
	# Mano quemada (22/10): el clip se construye por código sobre el Idle (`_preparar_mano_quemada`); sin «hit» ni «burn» en el nombre por el mismo motivo de arriba.
	"mano_quemada": ["manoquemada"],
	"talk": ["stand_talking", "talking", "hablar"],
	# Clips propios del elfo (22/10, Pablo, Tripo): saludar (greet_02, una vez) y celebrar (cheer, una vez). Sin rol previo que encaje: `wave` es el
	# saludo con la mano de la elfa (wave/hello) y no se mezcla con ellos.
	"saludo": ["greet_02", "greet"],
	"celebrar": ["cheer"],
	"attack": ["leftslash", "slash", "attack", "punch"],
	"leer": ["readandwrite", "reading", "read", "writing"],
	"wave": ["wave", "hello"],
	"roll": ["roll_dodge_1", "roll_dodge", "rolldodge", "roll"],
	"swim": ["swim_forward", "swimforward"],
	"drink": ["standanddrink", "drink_potion"],
	"pick_up": ["collectobject", "pick_up"],
}

## Qué clip de lanzar va con cada forma de Vfx3D.FORMAS (la tabla `anim_cast` de DISENO_FUTURO §0b): el rol de
## SINONIMOS que se busca en el GLB. Elegidos mirando los clips de la elfa: proyectil = lanzamiento al frente
## (MageSoellCast003); corro = golpe de manos al suelo (ChargedGroundSlam); columna = brazos alzados
## (ChargedSpellCast002); muro = brazos abiertos de lado (MageSoellCast002). Todos se quedan en su sitio
## (cadera < 0,3 alturas). Una forma sin entrada, o cuyo clip no exista en el GLB, usa `leer` (readandwrite).
const ANIM_CAST: Dictionary = {
	"proyectil": "cast_proyectil",
	"corro": "cast_corro",
	"columna": "cast_columna",
	"muro": "cast_muro",
}

## Clips que un personaje tiene con otro nombre del que dice SINONIMOS: id -> {rol: clip}. Se miran primero.
## goblin_warrior_chibi: su HitReaction arrastra la cadera 1,25 alturas (4.8 lo detectó); SlapReaction se queda en su sitio.
const CLIPS_DE: Dictionary = {
	"goblin_warrior_chibi": {"hit": "slapreaction"},
	"goblin_espadachin": {"hit": "slapreaction"},
	# El arquero no tiene clips de espada ni de retroceso con esos nombres: dispara con ArcheryShot y retrocede con Walk002.
	"goblin_archer_chibi": {"attack": "archeryshot", "walk_back": "walk002"},
	# Elemental de bosque: su único clip de golpe recibido es el de FUEGO (Meshy «Hit_Fire_Reaction», 4,7 s; el GLB lo trae
	# como `hit_fire`). El Juego puede usarlo como `hit` o pedirlo por su nombre.
	"elemental_bosque": {"hit": "hit_fire"},
	# Loberno (13/10, Meshy «lobo_anim»): su correr se llama Gallop y sus golpes recibidos Idle_HitReact1/2 (el 2 se pide por su nombre).
	"loberno": {"run": "gallop", "hit": "idle_hitreact1"},
	# Lince cornudo (14/10, Meshy «Horned Lynx Pup» sobre el esqueleto Fox/Wolf): sustituye al gato de la mascota. Mismos nombres de clip que el loberno.
	"lince": {"run": "gallop", "hit": "idle_hitreact1"},
}

## Roles a los que se quita el desplazamiento de la cadera al cargar (el Juego mueve al personaje): id -> [roles]. elfo_base: su walk (Tripo) avanza la cadera
## ~2,9 alturas de cadera por ciclo.
const RAIZ_ANULADA: Dictionary = {
	"elfo_base": ["walk"],
}

## Rol que se usa en su lugar cuando el personaje no tiene clip para el pedido: id -> {rol pedido: rol sustituto}. Solo para los ids listados.
const ROL_SUSTITUTO: Dictionary = {
	"elfo_base": {"run": "walk"},
}

## Clips mínimos por tipo de personaje (la misma lista que docs/ASSETS_PENDIENTES.md §1).
const MINIMOS: Dictionary = {
	"heroe": ["idle", "walk", "run", "cast", "hit", "death", "roll", "leer", "swim"],
	"goblin": ["idle", "walk", "attack", "hit", "death"],
	"arquero": ["idle", "walk", "walk_back", "attack", "hit", "death"],
	"npc": ["idle", "walk", "talk"],
	# Elemental de bosque (Meshy «Verdant Guardian»): es un jefe lento. Su `hit` es el de fuego (ver CLIPS_DE). Tiene `cast` (el hechizo de las enredaderas) y `run`.
	"elemental": ["idle", "walk", "run", "attack", "cast", "hit", "death"],
	# Bestia de cuatro patas (loberno): sin cast ni talk.
	"bestia": ["idle", "walk", "run", "attack", "hit", "death"],
}

## Roles cuyo clip debe quedarse en su sitio: la cadera no se aleja de donde empieza (en alturas de cadera).
## death, roll y swim sí se desplazan a propósito. `drown` se queda en sitio (el hundimiento lo hace Combate3D bajando el nodo); no está en MINIMOS a
## propósito: no todos los modelos de goblin futuros lo traerán y sin él `Combate3D` ya cae con la pose de muerte.
const EN_SITIO: Array = ["idle", "walk", "walk_back", "run", "cast", "attack", "hit", "leer", "talk", "wave", "drown"]
## Roles que van y vuelven en vez de saltar del final al principio (readandwrite termina 16º torcido respecto a como empieza).
const PINGPONG: Array = ["leer"]
const DESPLAZA_MAX: float = 0.35
## Altura plausible del modelo tal como viene (los GLB de Meshy miden ~1,7): fuera de esto, cm contra m.
const ALTO_BRUTO: Vector2 = Vector2(0.5, 4.0)

## Si cada personaje se valida al cargarlo (una vez por id y sesión).
static var validar_al_cargar: bool = true
static var _validados: Dictionary = {}

## Proporciones por personaje: [cabeza, piernas, torso] (ver proporcion_chibi.gd). 1 = como viene.
## chibi_test es la elfa ANTIGUA (cabeza muy grande y piernas cortas): así se parece a bookseller_chibi.
## La elfa nueva (chibi_elf desde el 5 de octubre, hecha a partir de la librera) ya viene bien: sin corrección.
const PROPORCIONES: Dictionary = {
	"chibi_test": [0.76, 1.4, 1.1],
}

## Postura por personaje: [cabeza, cuello, columna, brazos, rodillas, pies, pelvis] en grados (ver ProporcionChibi). Los clips de Meshy
## dejan a la elfa cabizbaja y con los hombros encogidos (se ve de lado); esto la yergue sin volver a renderizar.
## Se afina en vivo en PruebaTest2 con , . (cabeza; Shift: brazos) y U I (rodillas; Shift: pies) y Y O (pelvis); el valor bueno se apunta aquí.
const POSTURAS: Dictionary = {
	# Afinado por Pablo el 5/10 mirando de lado y de frente (la cabeza va en negativo: el eje X local del hueso
	# apunta al revés de lo que se supuso; en cuello y columna no).
	"chibi_elf": [-4.0, 8.0, 6.0, 24.0, 12.0, 0.0, -14.0],
	"chibi_elf_v2": [-4.0, 8.0, 6.0, 24.0, 12.0, 0.0, -14.0],
}

## Variantes que comparten GLB: el id del personaje -> el modelo que carga. El equipo (Equipo3D.EQUIPO),
## la altura y la postura se buscan por el id del personaje, así que una variante solo cambia lo que lleva.
const MODELO_DE: Dictionary = {
	"goblin_espadachin": "goblin_warrior_chibi",
	# La elfa jugadora: el id conserva los ajustes (FACTOR_ZANCADA, CORRECCION_POSTURA) y el GLB es la versión con los
	# pesos de piel suavizados en mangas y abrigo (woodland_wanderer.glb queda como original, sin suavizar).
	"woodland_wanderer": "woodland_wanderer_suave",
	"woodland_wanderer_orig": "woodland_wanderer",   # solo para el laboratorio: la elfa sin suavizar, para comparar
	# 13/10: el loberno usa el modelo Emberstride (Meshy) pasado al esqueleto «Wolf» de 51 huesos (ver DIARIO 54). El GLB anterior (rig de Meshy,
	# con las tiras del cuello deformadas) queda como `loberno.glb` solo para compararlo en el laboratorio.
	# 16/10 (Pablo, Bosque 01) se había elegido `loberno.glb`; 17/10 Pablo dice que es una versión antigua y que el bueno es `emberheart` (Meshy,
	# esqueleto «Wolf», DIARIO 56): vuelve aquí. `loberno.glb` y `emberstride.glb` quedan sin uso (a borrar por el Pipeline, dueño de arte/modelos).
	"loberno": "emberheart",
	# Sin entrada aquí el id carga el GLB de su mismo nombre.
}

var id: String = ""
var proporcion: ProporcionChibi = null
var modo_luz: int = 1            ## 0 = plana (sin sombreado), 1 = luz suave
var animacion_actual: String = ""

var _modelo: Node3D = null
var _equipo: Array[Node3D] = []
var _ap: AnimationPlayer = null
var _arbol: ArbolAnimPj = null   ## A1: la máquina de estados de la animación (ArbolAnimPj). Es lo ÚNICO que reproduce clips: `_ap` solo se lee.
## Qué estados existen: ArbolAnimPj.GRAFO_HEROE (todos) o GRAFO_REDUCIDO (enemigos: idle, andar, correr, atacar, lanzar, golpeado, muerto).
var grafo: String = ArbolAnimPj.GRAFO_HEROE:
	set(v):
		grafo = v
		if _arbol != null:
			_arbol.grafo = v
var _materiales: Array[StandardMaterial3D] = []
var _caja: AABB = AABB()

# --- V5 «personajes juguete» (docs/PLAN_EOW_VISUAL.md): rim de color, silueta tras paredes y sombra de contacto ---
## Interruptores (static var para poder apagarlos desde una prueba o una captura «antes» sin tocar el código). Cada cosa se apaga sola.
static var rim_activo: bool = true                 ## el fresnel de color en el borde (MaterialPersonaje3D.rim)
static var silueta_activa: bool = true             ## la silueta a través de lo que tapa a la JUGADORA
static var silueta_enemigos: bool = false          ## lo mismo para los enemigos (apagado: con muchos goblins sería un enjambre de manchas)
static var sombra_contacto_activa: bool = true     ## la mancha suave bajo los pies (SombraContacto3D)
static var pbr_juguete_activo: bool = true         ## rugosidad media-alta en vez de 1,0 (sin ello no hay brillo de plástico)

## V5 punto 5: shader de juguete (rampa de 3 tonos + matcap, sin PBR) en lugar del StandardMaterial3D. false = lo de antes. Constantes en MaterialPersonaje3D
## (MATCAP_INTENSIDAD, SOMBRA_JUGUETE_COLOR, PISO_SOMBRA, BRILLO_LUZ). Hay que fijarlo ANTES de cargar() el personaje.
static var material_juguete: bool = true
var _juguete: Array = []                           ## [material de control, ShaderMaterial, último estado copiado] por superficie opaca

const ROUGHNESS_JUGUETE: float = 0.72              ## media-alta: un brillo ancho y suave, no un espejo (metalness sigue en 0)
const RIM_POTENCIA: float = 7.0                    ## cuánto se pega el brillo a la arista (más = más fino). 21/10 (Pablo): con 1,8 / 1,1 rodeaba al personaje como un halo
const RIM_INTENSIDAD: float = 0.6               ## 22/10: con potencia 3,0 y 0,5 el rim cubría casi media superficie (en una pose inclinada, capa y gorro enteros) y velaba al personaje de pálido en zonas oscuras (fondo del cauce); con 7,0 solo la arista. Ver RIM_COBERTURA_MAX
static var rim_solo_jugadora: bool = true           ## 21/10 (Pablo): el rim solo en la jugadora; NPC y enemigos sin borde (el material sigue, a intensidad 0, por la silueta)
const RIM_UMBRAL_VISIBLE: float = 0.08          ## brillo añadido por el rim a partir del cual se nota sobre el color del personaje
const RIM_COBERTURA_MAX: float = 0.30           ## fracción máxima de la superficie (normales uniformes en el hemisferio visto) donde el rim supera ese umbral
const RIM_JUGADORA: Color = Color(1.0, 0.72, 0.42)   ## cálido: la elfa es lo que el ojo debe encontrar primero
const RIM_NPC: Color = Color(1.0, 0.86, 0.66)        ## cálido pálido, para que no compita con la jugadora
const RIM_ENEMIGO: Color = Color(0.55, 0.72, 1.0)    ## frío por defecto; Combate3D lo cambia al color de su debilidad (set_rol_visual)
const SILUETA_COLOR: Color = Color(1.0, 0.8, 0.5, 0.42)
const SILUETA_SESGO_ALTURAS: float = 0.4           ## cuánto más cerca (en alturas del personaje) debe estar lo que lo tapa para dibujar la silueta
const SOMBRA_DIAMETRO_ALTURAS: float = 0.7         ## diámetro de la mancha en alturas del modelo
const SOMBRA_ALFA: float = 0.36
const IDS_JUGADORA: Array = ["woodland_wanderer", "chibi_elf", "chibi_test"]   ## prefijos de id que son la jugadora (rol «jugadora»)

var rol_visual: String = "npc"                     ## «jugadora» | «npc» | «enemigo»: decide el color del rim y si lleva silueta
var _rim_mat: ShaderMaterial = null
var _sil_mat: ShaderMaterial = null
var _sombra: MeshInstance3D = null
var _caja_vacia: bool = true
var _yaw: float = 0.0
var _chispas: Node3D = null      ## BoneAttachment3D con las partículas de la mano mientras se lanza
var _sk_ahora: Skeleton3D = null              ## caché de `hueso_ahora` (se pide cada fotograma)
var _huesos_ahora: Dictionary = {}            ## nombre pedido -> índice de hueso


func cargar(p_id: String) -> bool:
	id = p_id
	var ruta: String = "res://arte/modelos/%s.glb" % glb_de(id)
	if not ResourceLoader.exists(ruta):
		push_warning("Pj3D: falta %s. Ejecuta poc_25d\\COPIAR_MODELOS.cmd y abre Godot para que lo importe." % ruta)
		return false
	var escena: PackedScene = load(ruta) as PackedScene
	if escena == null:
		push_warning("Pj3D: %s no se pudo cargar como escena." % ruta)
		return false
	_modelo = escena.instantiate() as Node3D
	add_child(_modelo)
	_apoyar_en_el_suelo(_modelo)
	_preparar_materiales(_modelo)

	var aps: Array[Node] = _modelo.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		_ap = _poner_clips_de_familia(glb_de(id))
		if _ap != null:
			aps.append(_ap)
	if not aps.is_empty():
		_ap = aps[0] as AnimationPlayer
		for nombre in _ap.get_animation_list():
			_ap.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
		_preparar_empujado()
		_preparar_mano_quemada()
		_arbol = ArbolAnimPj.new()
		_arbol.name = "ArbolAnim"
		_ap.get_parent().add_child(_arbol)
		_arbol.montar(_ap, grafo)

	_anular_raiz("roll")
	_colocar_nado()
	_acortar_paso()
	_aplicar_factor_zancada()
	_corregir_postura()
	# Elemental de bosque: sus clips traen la cadera desplazada (attack se adelanta 0,3 y acaba 8 cm fuera de sitio; walk se
	# balancea ±0,33; hit_fire acaba 7 cm atrás). El Juego es quien lo mueve, así que se queda en su sitio: si no, al
	# cambiar de clip el modelo salta de golpe (los «tirones»).
	if id.begins_with("elemental"):
		for rol in ["attack", "walk", "hit"]:
			_anular_raiz(rol)
	for rol in (RAIZ_ANULADA.get(id, []) as Array):
		_anular_raiz(String(rol))
	_crear_proporcion()
	_equipo = Equipo3D.equipar(id, _modelo)
	_crear_sombra()
	set_rol_visual(_rol_por_defecto())
	set_modo_luz(modo_luz)
	jugar("idle")
	if validar_al_cargar and not _validados.has(id):
		_validados[id] = true
		var avisos: PackedStringArray = validar()
		for a in avisos:
			push_warning("Pj3D[%s]: %s" % [id, a])
	return true


## Modelos sin animaciones propias (elfo_base, de Tripo): se les monta un AnimationPlayer con los clips de su familia, traducidos a su esqueleto
## (ClipsFamilia, PLAN_RIGGING §3.6). Devuelve null si el GLB no tiene familia o no se pudo.
func _poner_clips_de_familia(glb_id: String) -> AnimationPlayer:
	if not ClipsFamilia.tiene_fuente(glb_id):
		return null
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var clips: Dictionary = ClipsFamilia.clips_para(glb_id, _modelo, sks[0] as Skeleton3D)
	if clips.is_empty():
		push_warning("Pj3D[%s]: no se pudieron traer los clips de la familia" % id)
		return null
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	_modelo.add_child(ap)
	ap.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	for nombre in clips.keys():
		lib.add_animation(nombre, clips[nombre] as Animation)
	ap.add_animation_library("", lib)
	return ap


## Id del GLB que carga un personaje (el suyo, o el del que comparte modelo).
static func glb_de(p_id: String) -> String:
	return String(MODELO_DE.get(p_id, p_id))


## Quita y vuelve a poner el equipo (p. ej. tras cambiar Equipo3D.nivel_grimorio).
func reequipar() -> void:
	for p in _equipo:
		if is_instance_valid(p) and p.get_parent() is BoneAttachment3D:
			p.get_parent().free()
	_equipo = Equipo3D.equipar(id, _modelo)


## Cambia el grimorio de la elfa (1 botánico, 2 rúnico, 3 legendario) y la vuelve a equipar.
func set_nivel_grimorio(n: int) -> void:
	Equipo3D.nivel_grimorio = clampi(n, 1, 3)
	reequipar()


## Si el personaje tiene proporciones propias, cuelga del esqueleto un ProporcionChibi.
func _crear_proporcion() -> void:
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0] as Skeleton3D
	proporcion = ProporcionChibi.new()
	proporcion.name = "ProporcionChibi"
	sk.add_child(proporcion)
	proporcion.preparar()
	var p: Array = PROPORCIONES.get(id, [1.0, 1.0, 1.0])
	set_proporcion(float(p[0]), float(p[1]), float(p[2]))
	var q: Array = POSTURAS.get(id, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))


## Cambia las proporciones en vivo; la altura (set_alto) se recalcula con ellas.
func set_proporcion(cabeza: float, piernas: float, torso: float) -> void:
	if proporcion == null:
		return
	var alto_antes: float = alto_modelo() * scale.y
	proporcion.cabeza = cabeza
	proporcion.piernas = piernas
	proporcion.torso = torso
	if alto_antes > 0.0:
		set_alto(alto_antes)


## Cambia la postura en vivo (grados; ver ProporcionChibi). No afecta a la altura medida.
func set_postura(cabeza: float, cuello: float, columna: float, brazos: float, rodillas: float = 0.0, pies: float = 0.0, pelvis: float = 0.0) -> void:
	if proporcion == null:
		return
	proporcion.cabeza_atras = cabeza
	proporcion.cuello_atras = cuello
	proporcion.columna_atras = columna
	proporcion.brazos_abrir = brazos
	proporcion.rodillas_estirar = rodillas
	proporcion.pies_abrir = pies
	proporcion.pelvis_atras = pelvis


func postura() -> Array:
	if proporcion == null:
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	return [proporcion.cabeza_atras, proporcion.cuello_atras, proporcion.columna_atras, proporcion.brazos_abrir,
		proporcion.rodillas_estirar, proporcion.pies_abrir, proporcion.pelvis_atras]


## Sombra de contacto bajo los pies (V5): la misma mancha suave que el decorado (SombraContacto3D) en vez del disco duro de antes, para que el
## personaje y las piezas se vean igual de asentados. Va en unidades del modelo (el `scale` del Pj3D la agranda con él). Se apaga con
## `apagar_sombra()` al morir/hundirse: si no, una mancha se quedaría en el suelo bajo un cuerpo que se hunde en el agua.
func _crear_sombra() -> void:
	if _sombra != null and is_instance_valid(_sombra):
		_sombra.queue_free()
		_sombra = null
	if not sombra_contacto_activa:
		return
	var d: float = alto_modelo() * SOMBRA_DIAMETRO_ALTURAS
	_sombra = SombraContacto3D.poner(self, d, d, 0.02, SOMBRA_ALFA)


## Quita la sombra de contacto (el personaje muere, se hunde o desaparece).
func apagar_sombra() -> void:
	if _sombra != null and is_instance_valid(_sombra):
		_sombra.visible = false


## ¿Cuál es el rol visual de este id? La jugadora por prefijo de id; el resto, NPC (Combate3D lo pasa a «enemigo» al equiparse).
func _rol_por_defecto() -> String:
	for p in IDS_JUGADORA:
		if id.begins_with(String(p)):
			return "jugadora"
	return "npc"


## Fija el rol visual: el color del rim (`color_rim` alfa 0 = el de serie del rol) y si lleva silueta a través de paredes.
func set_rol_visual(rol: String, color_rim: Color = Color(0, 0, 0, 0)) -> void:
	rol_visual = rol
	if _rim_mat == null:
		return
	var c: Color = color_rim
	if c.a <= 0.0:
		c = RIM_JUGADORA if rol == "jugadora" else (RIM_ENEMIGO if rol == "enemigo" else RIM_NPC)
	_rim_mat.set_shader_parameter("color", Vector3(c.r, c.g, c.b))
	_rim_mat.set_shader_parameter("intensidad", _intensidad_rim())
	var con_silueta: bool = silueta_activa and (rol == "jugadora" or (silueta_enemigos and rol == "enemigo"))
	_rim_mat.next_pass = _sil_mat if con_silueta else null
	_actualizar_silueta()


## El sesgo de la silueta va en unidades de mundo: depende de lo alto que mide el personaje YA escalado.
func _actualizar_silueta() -> void:
	if _sil_mat != null:
		_sil_mat.set_shader_parameter("sesgo", alto_modelo() * scale.y * SILUETA_SESGO_ALTURAS)


## Pies en el origen y el centro del modelo sobre la vertical.
func _apoyar_en_el_suelo(modelo: Node3D) -> void:
	_caja_vacia = true
	_acumular_caja(modelo, Transform3D.IDENTITY)
	if _caja_vacia:
		return
	var cx: float = _caja.position.x + _caja.size.x * 0.5
	var cz: float = _caja.position.z + _caja.size.z * 0.5
	modelo.position -= Vector3(cx, _caja.position.y, cz)


func _acumular_caja(n: Node, acum: Transform3D) -> void:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null:
			var caja_mi: AABB = t * mi.mesh.get_aabb()
			if _caja_vacia:
				_caja = caja_mi
				_caja_vacia = false
			else:
				_caja = _caja.merge(caja_mi)
	for h in n.get_children():
		_acumular_caja(h, t)


## Copia los materiales (sin metal: sin reflejos se ve negro) para poder alternar luz plana y suave.
func _preparar_materiales(modelo: Node3D) -> void:
	var mallas: Array[Node] = modelo.find_children("*", "MeshInstance3D", true, false)
	for n in mallas:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_active_material(s)
			if mat is StandardMaterial3D:
				var copia: StandardMaterial3D = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				copia.metallic = 0.0
				copia.roughness = ROUGHNESS_JUGUETE if pbr_juguete_activo else 1.0
				# Rim (+ silueta encadenada): solo en superficies opacas. Un material con alfa (pelo, hojas) pintaría el rim sobre el recorte.
				if rim_activo and copia.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
					if _rim_mat == null:
						_rim_mat = MaterialPersonaje3D.rim(RIM_NPC, RIM_POTENCIA, RIM_INTENSIDAD)
						_sil_mat = MaterialPersonaje3D.silueta(SILUETA_COLOR, 0.4)
					copia.next_pass = _rim_mat
				# Juguete (V5 punto 5): las superficies opacas se pintan con el shader de rampa + matcap; `copia` queda como material de control
				# (Combate3D le escribe el tinte; sincronizar_juguete() lo pasa al shader). Las de alfa (pelo, hojas) conservan su StandardMaterial3D.
				if material_juguete and copia.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and copia.cull_mode != BaseMaterial3D.CULL_FRONT:
					var sm: ShaderMaterial = MaterialPersonaje3D.juguete(copia)
					sm.next_pass = copia.next_pass
					_juguete.append([copia, sm, [copia.albedo_color, copia.emission_enabled, copia.emission, copia.emission_energy_multiplier, copia.shading_mode]])
					mi.set_surface_override_material(s, sm)
				else:
					mi.set_surface_override_material(s, copia)
				_materiales.append(copia)


## Copia a los shaders de juguete lo que Combate3D (o set_modo_luz) escribió en los materiales de control. Solo toca los uniforms si algo cambió.
func sincronizar_juguete() -> void:
	for e in _juguete:
		var base: StandardMaterial3D = e[0]
		var estado: Array = e[2]
		if base.albedo_color != estado[0] or base.emission_enabled != estado[1] or base.emission != estado[2] \
				or base.emission_energy_multiplier != estado[3] or base.shading_mode != estado[4]:
			MaterialPersonaje3D.copiar_estado(base, e[1])
			e[2] = [base.albedo_color, base.emission_enabled, base.emission, base.emission_energy_multiplier, base.shading_mode]


## Color de la sombra suave de los personajes de juguete (frío o cálido según la zona).
func set_sombra_juguete(c: Color) -> void:
	for e in _juguete:
		(e[1] as ShaderMaterial).set_shader_parameter("sombra_color", Vector3(c.r, c.g, c.b))


func set_modo_luz(m: int) -> void:
	modo_luz = m
	for mat in _materiales:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if m == 0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	sincronizar_juguete()
	# La luz plana es el modo «sin sombreado» del laboratorio: sin rim (un borde que brilla en un muñeco plano lo estropea). La silueta sigue.
	if _rim_mat != null:
		_rim_mat.set_shader_parameter("intensidad", _intensidad_rim())


## Intensidad del rim según el modo de luz y el rol (con `rim_solo_jugadora`, solo la jugadora brilla en el borde).
func _intensidad_rim() -> float:
	if modo_luz == 0 or (rim_solo_jugadora and rol_visual != "jugadora"):
		return 0.0
	return RIM_INTENSIDAD


## Alto del modelo tal como viene (antes de escalar), medido por su caja. 1,7 si no se pudo medir.
func alto_modelo() -> float:
	if _caja_vacia or _caja.size.y <= 0.0001:
		return 1.7
	return _caja.size.y + _cambio_por_proporcion()


## Lo que crece o encoge el modelo por sus proporciones, en unidades del modelo.
func _cambio_por_proporcion() -> float:
	if proporcion == null:
		return 0.0
	var sk: Skeleton3D = proporcion.get_skeleton()
	if sk == null:
		return 0.0
	# Transformación del esqueleto respecto a la raíz del modelo.
	var t := Transform3D.IDENTITY
	var n: Node = sk
	while n != null and n != _modelo:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	var escala: float = t.basis.get_scale().y
	var cabeza_y: float = 0.0
	var hc: int = proporcion._cabeza
	if hc >= 0:
		cabeza_y = (t * sk.get_bone_global_rest(hc).origin).y
	var alto_cabeza: float = maxf(0.0, (_caja.position.y + _caja.size.y) - cabeza_y) / maxf(escala, 0.0001)
	return proporcion.cambio_de_altura(alto_cabeza) * escala


## Escala el personaje para que mida `alto` unidades.
func set_alto(alto: float) -> void:
	set_escala(alto / alto_modelo())


func set_escala(s: float) -> void:
	scale = Vector3.ONE * s
	_actualizar_silueta()


## Gira suavemente hacia `d` (vector en el plano del suelo).
func mirar(d: Vector3, delta: float) -> void:
	if d.length() < 0.001:
		return
	var objetivo: float = atan2(d.x, d.z)
	_yaw = lerp_angle(_yaw, objetivo, clampf(delta * 12.0, 0.0, 1.0))
	rotation.y = _yaw


## Velocidad del clip de lanzar (1 = original). Se acelera el clip ENTERO (mismos fotogramas, en menos tiempo), no se recortan fotogramas.
## Va como velocidad propia de la reproducción (play(..., custom_speed)), así que no choca con set_velocidad_animacion.
const VEL_CAST: float = 1.6


## Empieza a lanzar un hechizo de `forma` y `elemento` (el "modo lanzar" de DISENO_FUTURO §0b): el clip de ANIM_CAST (o readandwrite) en bucle y
## partículas sutiles del elemento en la mano que lanza. Devuelve lo que dura el clip. Se termina con soltar_lanzar(). Solo el nombre del elemento:
## cómo se ve lo decide Vfx3D.
## T-CP1 (18/10): con `punto` (id de una variación de CastPoints) se usa el CAST POINT: el clip recortado, a su velocidad, con el libro en la mano que dice
## la variación y el brazo del libro quieto; `fraccion_clip()` dice por dónde va. Si el id no existe o su clip no está en el GLB, se lanza como siempre.
## El libro YA NO vuelve al cinto aquí (lo contrario de lo que pide el diseño): se queda en la mano mientras dura el lanzamiento y lo devuelve
## `soltar_lanzar()` al acabar.
func lanzar(forma: String, elemento: String, punto: String = "") -> float:
	if _ap == null:
		return 0.0
	_quitar_chispas()
	if punto != "" and CastPoints.existe(punto):
		var d: float = _lanzar_punto(punto, elemento)
		if d > 0.0:
			return d
	_cp = {}
	_brazo_libro_peso(0.0)
	var rol: String = String(ANIM_CAST.get(forma, "leer"))
	var clip: String = _buscar_clip(rol)
	if clip == "":
		rol = "leer"
		clip = _buscar_clip(rol)
	animacion_actual = ""
	jugar(rol, false, VEL_CAST)
	if animacion_actual != rol:
		return 0.0                                  # el árbol lo prohíbe (p. ej. nadando): no se lanza
	_poner_chispas(elemento)
	# Dura menos por ir más rápido: el Juego espera este tiempo para llamar a soltar_lanzar().
	return _ap.get_animation(clip).length / VEL_CAST if clip != "" else 0.0


## Para las partículas de la mano y vuelve a idle. `devolver_libro` false = el libro se queda en la mano (Jugador3D.terminar_apuntar lo usa al SOLTAR
## para lanzar: el libro tiene que seguir en la mano durante el lanzamiento); true = lo guarda en el cinto (el final de siempre).
func soltar_lanzar(devolver_libro: bool = true) -> void:
	_quitar_chispas()
	_cp = {}
	_brazo_libro_peso(0.0)
	if _arbol != null:
		_arbol.vel_global = 1.0
		_arbol.retenido = false
	if devolver_libro:
		libro_en_manos(false, 0.15)
	animacion_actual = ""
	jugar("idle")


# --- T-CP1: cast points ---

## El lanzamiento por cast point en curso ({} = ninguno): id, clip, len (s del clip entero), a / b (s del recorte), t_inst (s del instante), vel,
## sostener (s que se congela tras el instante), hold (s que le quedan de congelado), paso (true cuando ya pasó el instante), fin (true al llegar a `b`).
var _cp: Dictionary = {}
var _brazo: BrazoLibro3D = null
var _libro_lado: String = "izquierda"          ## la mano en la que está ahora el libro


## Empieza el clip recortado de la variación `id`. Devuelve los segundos que dura (con la velocidad y el factor del elemento, más el `sostener`), o 0 si no
## se puede (variación sin clip en este GLB): entonces `lanzar` cae al camino de siempre.
func _lanzar_punto(id: String, elemento: String) -> float:
	var d: Dictionary = CastPoints.datos(id)
	var rol: String = CastPoints.rol_clip(id)
	var clip: String = _buscar_clip(rol)
	if clip == "" and rol != String(d["clip"]):
		rol = String(d["clip"])                 # la variación pide un clip a una mano y este GLB no lo trae: el original
		clip = _buscar_clip(rol)
	if clip == "" or _arbol == null or _arbol.motivo_prohibida(_arbol.estado, "lanzar_" + id) != "":
		return 0.0
	var largo: float = _ap.get_animation(clip).length
	var rec: Vector2 = CastPoints.recorte(id)
	var vel: float = float(d["velocidad"]) / maxf(CastPoints.escala_tiempo(elemento), 0.05)
	var a: float = rec.x * largo
	var b: float = rec.y * largo
	var t_inst: float = a + clampf(float(d["instante"]), 0.0, 1.0) * (b - a)
	var una_mano: bool = CastPoints.es_una_mano(id) and rol == String(d["clip_una_mano"])
	var lado: String = CastPoints.mano_libro(id) if not una_mano else "izquierda"
	# El libro en la mano que corresponde (si ya estaba en la otra, pasa a esta).
	libro_en_manos(true, 0.3, lado, true)           # lanzando: el libro está «en_mano_cerrado»
	# El brazo del libro quieto (solo con el clip original: el de una mano ya trae el brazo del libro en su sitio).
	_brazo_libro_lado(lado)
	_brazo_libro_peso(CastPoints.peso_brazo if CastPoints.brazo_activo and not una_mano else 0.0)
	# El clip recortado [a, b] es un estado propio del árbol (sin bucle: al llegar a `b` se queda en ese fotograma).
	_arbol.vel_global = 1.0
	_arbol.pedir("lanzar_" + id, clip, {"desde": a, "hasta": b, "bucle": Animation.LOOP_NONE, "vel": vel, "mezcla": MEZCLA_CLIPS})
	animacion_actual = rol
	_cp = {"id": id, "clip": clip, "len": largo, "a": a, "b": b, "t_inst": t_inst, "vel": vel, "sostener": float(d["sostener"]), "hold": 0.0,
		"paso": false, "fin": false, "lado": lado, "una_mano": una_mano}
	_poner_chispas(elemento, "derecha" if lado == "izquierda" else "izquierda")
	return (b - a) / vel + float(d["sostener"])


## ¿Hay un lanzamiento por cast point en curso?
func cast_activo() -> bool:
	return not _cp.is_empty()


## Por dónde va el clip recortado: 0 en `inicio`, 1 en `fin` (el `instante` de CastPoints se mide en esta escala). -1 si no hay lanzamiento por cast point.
func fraccion_clip() -> float:
	if _cp.is_empty() or _arbol == null:
		return -1.0
	var rango: float = float(_cp["b"]) - float(_cp["a"])
	return clampf(_arbol.posicion() / maxf(rango, 0.0001), 0.0, 1.0)


## Segundos (de juego) que tarda el clip en llegar al instante desde que arranca. 0 si no hay lanzamiento por cast point.
func tiempo_instante() -> float:
	if _cp.is_empty():
		return 0.0
	return (float(_cp["t_inst"]) - float(_cp["a"])) / maxf(float(_cp["vel"]), 0.0001)


## ¿Ya ha pasado el clip por el instante? (con `sostener` el clip queda congelado exactamente en él.)
func paso_instante() -> bool:
	return not _cp.is_empty() and bool(_cp["paso"])


func punto_activo() -> String:
	return String(_cp.get("id", ""))


## Dónde está el punto del que nace el hechizo, en el mundo: `origen` de CastPoints (mano_libre · manos_alto · suelo_delante); `dir` es hacia donde se lanza
## (en el plano). La mano libre es la contraria a la del libro.
func posicion_punto(origen: String, dir: Vector3, lado_libro: String = "") -> Vector3:
	var lado: String = lado_libro if lado_libro != "" else String(_cp.get("lado", "izquierda"))
	var libre: String = "derecha" if lado == "izquierda" else "izquierda"
	match origen:
		"manos_alto":
			var m: Vector3 = posicion_mano(libre)
			return Vector3(global_position.x, maxf(m.y, global_position.y + alto_modelo() * scale.y), global_position.z)
		"suelo_delante":
			var d: Vector3 = Vector3(dir.x, 0.0, dir.z)
			d = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
			return global_position + d * Terreno3D.casilla
	return posicion_mano(libre)


## Posición en el mundo de una mano ("izquierda" | "derecha"); si no hay esqueleto, un punto a la altura del pecho.
func posicion_mano(lado: String) -> Vector3:
	var sk: Skeleton3D = _esqueleto()
	if sk != null:
		var h: int = Equipo3D._hueso(sk, "LeftHand" if lado == "izquierda" else "RightHand")
		if h >= 0:
			return sk.global_transform * sk.get_bone_global_pose(h).origin
	return global_transform * Vector3(0.28 if lado == "derecha" else -0.28, 0.85, 0.30)


func _esqueleto() -> Skeleton3D:
	if _modelo == null:
		return null
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	return sks[0] as Skeleton3D if not sks.is_empty() else null


## El modificador del brazo del libro, creado la primera vez que se pide (con la pose de `Readandwrite`). Null si el modelo no puede (sin esqueleto o sin ese clip).
func _brazo_libro() -> BrazoLibro3D:
	if _brazo != null and is_instance_valid(_brazo):
		return _brazo
	var sk: Skeleton3D = _esqueleto()
	if sk == null or _ap == null:
		return null
	# La pose «libro recogido con la palma arriba» sale de CastOneHandFront (el Pipeline la hizo con la mano izquierda sujetando el libro, diario 150);
	# si el GLB no la trae, de Readandwrite (la lectura, con el libro más vertical).
	var clip: String = _buscar_clip("cast_mano_frente")
	var t_ref: float = BrazoLibro3D.T_REF_UNA_MANO
	if clip == "":
		clip = _buscar_clip("leer")
		t_ref = BrazoLibro3D.T_REF_POR_DEFECTO
	if clip == "":
		return null
	var m := BrazoLibro3D.new()
	m.name = "BrazoLibro"
	m.influence = 0.0
	sk.add_child(m)
	if not m.preparar(_ap.get_animation(clip), t_ref):
		m.queue_free()
		return null
	_brazo = m
	return _brazo


func _brazo_libro_peso(w: float) -> void:
	if w <= 0.0 and (_brazo == null or not is_instance_valid(_brazo)):
		return
	var b: BrazoLibro3D = _brazo_libro()
	if b != null:
		b.influence = clampf(w, 0.0, 1.0)


func _brazo_libro_lado(lado: String) -> void:
	var b: BrazoLibro3D = _brazo_libro()
	if b != null:
		b.lado = lado


## Cada fotograma: si hay un lanzamiento por cast point, congela el clip en el instante (si `sostener`) y al llegar a `fin`.
func _process(delta: float) -> void:
	if not _juguete.is_empty():
		sincronizar_juguete()    # juguete: el tinte que Combate3D escribe en el material de control pasa al shader
	if _cp.is_empty() or _arbol == null or not _arbol.listo():
		return
	# `posicion()` es relativa al recorte [a, b]; el instante, en segundos absolutos del clip como siempre. El congelado es la velocidad 0 del árbol:
	# se queda en el primer fotograma que pasa del instante (≤ 1 fotograma de diferencia con el seek exacto de antes).
	var t: float = float(_cp["a"]) + _arbol.posicion()
	if float(_cp["hold"]) > 0.0:
		_cp["hold"] = float(_cp["hold"]) - delta
		if float(_cp["hold"]) <= 0.0:
			_arbol.retenido = false
		return
	if not bool(_cp["paso"]) and t >= float(_cp["t_inst"]):
		_cp["paso"] = true
		if float(_cp["sostener"]) > 0.0:
			_arbol.retenido = true
			_cp["hold"] = float(_cp["sostener"])
			return
	if not bool(_cp["fin"]) and t >= float(_cp["b"]) - 0.001:
		_cp["fin"] = true
		_arbol.retenido = true


func _poner_chispas(elemento: String, mano: String = "derecha") -> void:
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0] as Skeleton3D
	var h: int = Equipo3D._hueso(sk, "RightHand" if mano == "derecha" else "LeftHand")
	if h < 0:
		return
	var at := BoneAttachment3D.new()
	at.bone_name = sk.get_bone_name(h)
	sk.add_child(at)
	# Las partículas se miden en el mundo (para un personaje de una unidad de alto) y se pasan al espacio del hueso.
	var mundo: float = alto_modelo() * scale.y
	var local: float = maxf(at.global_transform.basis.get_scale().y, 0.0001)
	var v := Vfx3D.new()
	var gp: GPUParticles3D = v.chispas_mano(elemento, mundo / local)
	v.free()
	at.add_child(gp)
	_chispas = at


## --- 5.9 Transición del libro: el grimorio APARECE EN LAS MANOS al abrir el libro y se deshace al cerrarlo ---
## Es una copia aparte del grimorio (el de la cadera/espalda no se toca ni se "coge"): una pieza nueva en la mano izquierda que
## crece desde 0 en `dur` s con unas motas del elemento (o blancas) y, al cerrar, se encoge y se borra. El tween ignora el
## `Engine.time_scale` (el libro abierto va al 30 %): dura `dur` segundos REALES.
## T-CP1 (18/10, diario 150): el libro descansa en la PALMA de la mano, que va hacia arriba (en los clips CastOneHand* y en la pose del brazo del libro).
## Medido en el esqueleto: en la mano izquierda la normal de la palma es el eje +X del hueso (en reposo, con la palma hacia abajo, X apunta al suelo; en
## CastOneHand* apunta arriba, 0,87), los dedos van por +Y y la palma ocupa X ≈ 0,04…0,07, Y ≈ 0,04…0,11. Así que el libro (su espesor 0,068 es su eje Z) se
## gira 90° en Y (su normal pasa a ser la de la palma), y su centro queda sobre la palma: x = 0,066 + media espesor (0,034) ≈ 0,10, y = centro de la palma,
## z = ancho medio. Antes: (0, 0,10, 0,05) y giro (90, 0, 0): el libro de canto, con la normal a lo largo de los dedos (lo ajustó la pose de Readandwrite, que lo
## sostiene casi vertical, leyendo). En la derecha el rig es el espejo: x → −x y los giros en Y y Z cambian de signo (`_libro_pose`).
var libro_mano: Array = [Vector3(0.10, 0.08, -0.01), Vector3(0.0, 90.0, 0.0)]    ## posición y giro respecto a la mano izquierda
var _libro: Node3D = null

## A2 · EL LIBRO ES UNA MÁQUINA DE ESTADOS, no tres tweens sueltos (ya se mataron entre sí una vez: el libro «cosido» a la mano). Cuatro estados:
##   `cinto`            el libro del cinto a la vista; no hay libro en la mano.
##   `en_mano_abierto`  el libro en la mano mientras se apunta/lee (`apuntar()`, el laboratorio).
##   `en_mano_cerrado`  el libro en la mano durante el lanzamiento por cast point (`libro_en_manos(..., cerrado = true)`).
##   `volando`          el libro de la mano vuela de vuelta al cinto.
## UNA función de transición (`libro_en_manos`) y UN tween (`_libro_tween`: el de aparecer o el de volar; nunca los dos). Reglas: cerrar mientras VUELA no hace
## nada (el vuelo sigue; antes un segundo `false` seguido lo mataba y dejaba el libro a medio tamaño); abrir mientras vuela remata el vuelo (el libro llega
## al cinto) y saca otro; cerrar mientras APARECE lo recoge desde donde esté. `libro_asentar()` termina al instante lo que esté en marcha.
const LIBRO_ESTADOS: PackedStringArray = ["cinto", "en_mano_abierto", "en_mano_cerrado", "volando"]
signal libro_estado_cambiado(de: String, a: String)
var _libro_estado: String = "cinto"
var _libro_tween: Tween = null
var _libro_viejo: Node3D = null              ## el libro que está volando al cinto
var _libro_lleno: Vector3 = Vector3.ONE      ## la escala a la que se queda el libro en la mano


func libro_estado() -> String:
	return _libro_estado


func _libro_poner(e: String) -> void:
	if e == _libro_estado:
		return
	var de: String = _libro_estado
	_libro_estado = e
	libro_estado_cambiado.emit(de, e)


## El libro del cinto (la pieza "grimorio" de Equipo3D.EQUIPO): se esconde mientras el personaje lo sostiene y vuelve a verse
## cuando el de la mano llega a él. Null si el personaje no lleva grimorio.
func _libro_cinto() -> Node3D:
	for p in _equipo:
		if is_instance_valid(p) and p.name == "grimorio":
			return p
	return null


## Remata una vuelta al cinto que siga en marcha: borra el libro de la mano y muestra el del cinto. Termina en `cinto`.
func _acabar_vuelta_libro() -> void:
	if _libro_tween != null and _libro_tween.is_valid():
		_libro_tween.kill()
	_libro_tween = null
	if _libro_viejo != null and is_instance_valid(_libro_viejo) and _libro_viejo.get_parent() != null:
		_libro_viejo.get_parent().queue_free()
	_libro_viejo = null
	var c: Node3D = _libro_cinto()
	if c != null:
		c.visible = true
	_libro_poner("cinto")


## Hace avanzar `delta` s el tween del libro (aparecer o volar). Solo para las pruebas y el laboratorio: en juego lo mueve el motor.
func libro_avanzar(delta: float) -> void:
	if _libro_tween != null and _libro_tween.is_valid():
		_libro_tween.custom_step(delta)


## Termina YA lo que el libro tenga en marcha (aparecer: llega a su tamaño; volar: llega al cinto). Lo usan las pruebas y el cierre del laboratorio.
func libro_asentar() -> void:
	if _libro_estado == "volando":
		_acabar_vuelta_libro()
		return
	if _libro_tween != null and _libro_tween.is_valid():
		_libro_tween.kill()
	_libro_tween = null
	if _libro != null and is_instance_valid(_libro):
		_libro.scale = _libro_lleno


## ¿El libro está en un estado coherente? (un solo sitio: o en la mano o en el cinto, y el estado dice cuál.) Lo comprueba la prueba de las 1 000 secuencias.
func libro_valido() -> bool:
	if not LIBRO_ESTADOS.has(_libro_estado):
		return false
	var en_mano: bool = _libro != null and is_instance_valid(_libro) and _libro.is_inside_tree()
	match _libro_estado:
		"cinto":
			return not en_mano and _libro_viejo == null
		"volando":
			return not en_mano and _libro_viejo != null and is_instance_valid(_libro_viejo) and _libro_tween != null and _libro_tween.is_valid()
		_:
			return en_mano and _libro_viejo == null
	return false


## Un paso (k de 0 a 1) del vuelo del libro de la mano al cinto. El destino se vuelve a leer en cada paso: el cinto se mueve con la cadera.
func _volar_libro(k: float, viejo: Node3D, cinto: Node3D, t0: Transform3D, q0: Quaternion, s0: Vector3) -> void:
	if not is_instance_valid(viejo) or not is_instance_valid(cinto):
		return
	var d: Transform3D = cinto.global_transform
	var q: Quaternion = q0.slerp(d.basis.get_rotation_quaternion(), k)
	var s: Vector3 = s0.lerp(d.basis.get_scale(), k)
	viejo.global_transform = Transform3D(Basis(q).scaled(s), t0.origin.lerp(d.origin, k))


## Posición y giro del libro respecto a la mano `mano`: los de `libro_mano` en la izquierda y su espejo en la derecha.
func _libro_pose(mano: String) -> Array:
	var p: Vector3 = libro_mano[0] as Vector3
	var r: Vector3 = libro_mano[1] as Vector3
	if mano == "derecha":
		return [Vector3(-p.x, p.y, p.z), Vector3(r.x, -r.y, -r.z)]
	return [p, r]


## Cambia el libro de mano sin cerrarlo (el mismo nodo, otro BoneAttachment3D), con la pose espejada de esa mano.
func _pasar_libro(mano: String) -> void:
	var sk: Skeleton3D = _esqueleto()
	if sk == null or _libro == null or not is_instance_valid(_libro):
		return
	var h: int = Equipo3D._hueso(sk, "LeftHand" if mano == "izquierda" else "RightHand")
	if h < 0:
		return
	var at := BoneAttachment3D.new()
	at.name = "LibroMano"
	at.bone_name = sk.get_bone_name(h)
	sk.add_child(at)
	var viejo_at: Node = _libro.get_parent()
	if viejo_at != null:
		viejo_at.remove_child(_libro)
		viejo_at.queue_free()
	at.add_child(_libro)
	var escala: float = 1.0
	var n: Node = sk
	while n != null and n != _modelo:
		if n is Node3D:
			escala *= (n as Node3D).scale.y
		n = n.get_parent()
	var pose_libro: Array = _libro_pose(mano)
	_libro.position = (pose_libro[0] as Vector3) / maxf(escala, 0.0001)
	_libro.rotation_degrees = pose_libro[1] as Vector3
	_libro_lado = mano


## `mano`: en cuál se sostiene (izquierda por defecto; T-CP1: con clips que lanzan con la izquierda, el libro va a la derecha). Si el libro ya está
## en la otra mano, pasa a esta. `cerrado`: el estado en mano es `en_mano_cerrado` (lanzando) en vez de `en_mano_abierto` (apuntando).
## Es LA transición del libro (ver arriba): `abrir` true saca el libro a la mano; false lo manda al cinto volando.
func libro_en_manos(abrir: bool, dur: float = 0.3, mano: String = "izquierda", cerrado: bool = false) -> void:
	if _modelo == null:
		return
	if not abrir:
		if _libro == null or not is_instance_valid(_libro):
			_libro = null
			# Sin libro en la mano: el del cinto tiene que estar a la vista (salvo que ya venga volando de vuelta: entonces el vuelo sigue).
			if _libro_estado != "volando":
				var c0: Node3D = _libro_cinto()
				if c0 != null:
					c0.visible = true
				_libro_poner("cinto")
			return
		if _libro_tween != null and _libro_tween.is_valid():
			_libro_tween.kill()                       # (el de aparecer, si seguía: el libro se recoge desde el tamaño que tenga)
		var viejo: Node3D = _libro
		_libro = null
		var cinto: Node3D = _libro_cinto()
		_libro_viejo = viejo
		_libro_tween = viejo.create_tween().set_ignore_time_scale(true)
		if cinto == null:
			# Sin libro de cinto (otro personaje): se encoge y se borra, como antes.
			_libro_tween.tween_property(viejo, "scale", viejo.scale * 0.02, dur).set_ease(Tween.EASE_IN)
		else:
			# El libro de la mano VUELA al cinto (posición, giro y tamaño) y al llegar se esconde y se muestra el del cinto.
			var t0: Transform3D = viejo.global_transform
			var q0: Quaternion = t0.basis.get_rotation_quaternion()
			var s0: Vector3 = t0.basis.get_scale()
			_libro_tween.tween_method(_volar_libro.bind(viejo, cinto, t0, q0, s0), 0.0, 1.0, maxf(dur, 0.3)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_libro_tween.tween_callback(_acabar_vuelta_libro)
		_libro_poner("volando")
		return
	var destino: String = "en_mano_cerrado" if cerrado else "en_mano_abierto"
	if _libro != null and is_instance_valid(_libro):
		if mano != _libro_lado:
			_pasar_libro(mano)
		_libro_poner(destino)
		return
	_libro_lado = mano
	# Si aún estaba volviendo al cinto, se remata antes de sacar otro.
	if _libro_estado == "volando":
		_acabar_vuelta_libro()
	if _libro_tween != null and _libro_tween.is_valid():
		_libro_tween.kill()
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0] as Skeleton3D
	var h: int = Equipo3D._hueso(sk, "LeftHand" if mano == "izquierda" else "RightHand")
	if h < 0:
		h = Equipo3D._hueso(sk, "RightHand" if mano == "izquierda" else "LeftHand")
	if h < 0:
		return
	var escala: float = 1.0
	var n: Node = sk
	while n != null and n != _modelo:
		if n is Node3D:
			escala *= (n as Node3D).scale.y
		n = n.get_parent()
	var at := BoneAttachment3D.new()
	at.name = "LibroMano"
	at.bone_name = sk.get_bone_name(h)
	sk.add_child(at)
	var g: Node3D = Equipo3D.pieza("grimorio")
	var pose_libro: Array = _libro_pose(mano)
	g.position = (pose_libro[0] as Vector3) / maxf(escala, 0.0001)
	g.rotation_degrees = pose_libro[1] as Vector3
	var lleno: Vector3 = Vector3.ONE / maxf(escala, 0.0001)
	g.scale = lleno * 0.02
	at.add_child(g)
	_libro = g
	_libro_lleno = lleno
	_libro_poner(destino)
	# El libro del cinto desaparece mientras el personaje lo sostiene (vuelve en _acabar_vuelta_libro).
	var cinto_oculto: Node3D = _libro_cinto()
	if cinto_oculto != null:
		cinto_oculto.visible = false
	_libro_tween = g.create_tween().set_ignore_time_scale(true)
	_libro_tween.tween_property(g, "scale", lleno, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Unas motas que suben al aparecer (las de la mano que lanza, en blanco).
	var mundo: float = alto_modelo() * scale.y
	var local: float = maxf(at.global_transform.basis.get_scale().y, 0.0001)
	var v := Vfx3D.new()
	var gp: GPUParticles3D = v.chispas_mano("viento", mundo / local)
	v.free()
	gp.one_shot = true
	gp.lifetime = maxf(dur * 2.5, 0.6)
	gp.explosiveness = 0.8
	at.add_child(gp)
	gp.emitting = true
	get_tree().create_timer(gp.lifetime + 0.4, true, false, true).timeout.connect(gp.queue_free)


## --- 6.11 Apuntar: el libro en las manos y `readandwrite` SOSTENIDO mientras se apunta; el `cast` solo al soltar ---
## Flujo del Juego (cadena de casteo 6.2):  T/página → `apuntar()`  ·  mientras se apunta, no hace falta llamar a nada más  ·
## al soltar/confirmar → `lanzar(forma, elemento)` (cierra el libro y pone el clip de lanzar)  ·  al terminar → `soltar_lanzar()`.
## Si se cancela el apuntado: `cancelar_apuntar()`. `readandwrite` va y vuelve (PINGPONG): sin salto al repetirse.
func apuntar() -> void:
	_quitar_chispas()
	animacion_actual = ""
	jugar("leer")
	libro_en_manos(true)


func cancelar_apuntar() -> void:
	libro_en_manos(false, 0.15)
	soltar_lanzar()


## --- 6.12 Clips nuevos del héroe ---
## (a) GIRO AL ANDAR: `giro_al_andar(grados)` con el cambio de rumbo (grados, + = izquierda). Si pasa de 35º mezcla ~0,4 s con
## el arranque de `Walk002` (el tronco gira hacia el lado) y vuelve a `walk`. Solo actúa si va andando; no cambia `animacion_actual`.
## Walk002 gira hacia un solo lado: para el otro, el mismo clip se ve igual de suave (es una torsión corta, no una vuelta).
var _giro_activo: bool = false


func giro_al_andar(grados: float) -> void:
	if _arbol == null or _giro_activo or absf(grados) < 35.0:
		return
	if animacion_actual != "walk" and animacion_actual != "run":
		return
	var clip: String = _buscar_clip("walk02")
	if clip == "":
		return
	if not _arbol.pedir("giro", clip, {"bucle": Animation.LOOP_NONE, "mezcla": 0.12}):
		return
	_giro_activo = true
	var rol: String = animacion_actual
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		_giro_activo = false
		if animacion_actual == rol:
			_reproducir(rol, false, 1.0, 0.2, true))


## (b) VOLTERETA: `rodar()` reproduce `roll_dodge` UNA vez, sin desplazamiento de la cadera (lo mueve el Juego: ≤ 1 casilla, 4 s de
## espera). Devuelve lo que dura. Termina en `idle` con `soltar_rodar()` (o `jugar("idle")`).
func rodar() -> float:
	if _ap == null:
		return 0.0
	animacion_actual = ""
	jugar("roll", true)
	return duracion("roll")


func soltar_rodar() -> void:
	animacion_actual = ""
	jugar("idle")


## 11/10 (Pablo, con un vídeo de un gato real de referencia: «no adelantaría tanto las patas»): personajes cuyas patas se estiran
## demasiado al andar. id -> [rol del clip, factor, huesos de las patas]. Cada hueso de la lista gira solo `factor` de lo que giraba
## respecto a su postura MEDIA del ciclo: mismo ritmo y misma postura de fondo, pero pasos más cortos y patas más debajo del cuerpo.
## Los huesos del gato (Meshy los llama Bone_0xx) se sacaron midiendo el esqueleto: delanteras 030-027 y 035-032, traseras 009-006 y
## 014-011 (las que más giran en `walk`: 26°, 34°, 46° y 22° de la cadera a la pata).
const PASO_CORTO: Dictionary = {
	# 11/10 (ajustado con Pablo en el laboratorio LabGato3D): [rol, factor delanteras, factor traseras, factor resto, huesos delanteros,
	# huesos traseros, factor propio por hueso (opcional), extras (opcional)]. «Resto» = columna, cola, cabeza... (todo hueso con rotación que no sea de pata).
	"gato_guardabosques": ["walk", 0.23, 0.53, 0.50,
		["Bone_030", "Bone_029", "Bone_028", "Bone_027", "Bone_035", "Bone_034", "Bone_033", "Bone_032"],
		["Bone_009", "Bone_008", "Bone_007", "Bone_006", "Bone_014", "Bone_013", "Bone_012", "Bone_011"],
		# Factor propio por hueso: pisa al del grupo. Articulaciones de las patas a 0,35 (con factores bajos quedaban rígidas como palos);
		# cuello (025) y cabeza (024) a 0,25 para que la cabeza vaya estable (tutorial de Rusty Animator, «cat walk cycle»).
		{"Bone_029": 0.35, "Bone_034": 0.35, "Bone_028": 0.35, "Bone_033": 0.35,
		"Bone_008": 0.35, "Bone_013": 0.35, "Bone_007": 0.35, "Bone_012": 0.35, "Bone_025": 0.25, "Bone_024": 0.25},
		# Extras (11/10, «lockeado» por Pablo en LabGato3D; los números salen de allí, ver lab_gato_3d.gd):
		# · vaiven: grados que la articulación se DOBLA de más y vuelve, una vez por ciclo, con el máximo cuando su pie va por el aire
		#   (como en el vídeo de referencia: la muñeca se pliega al levantar la mano). Codo 028/033, muñeca 027/032, corvejón 007/012.
		# · eje: eje (espacio del padre) en que ese hueso dobla, medido; las dos patas de cada par van en espejo. Sin entrada = X.
		# · fase: momento del ciclo en que el pie de esa pata está más alto (medido en el clip walk).
		# · cola / retraso_cola: cada hueso de la cola, de la base a la punta, va retraso_cola (fracción del ciclo) más tarde que el anterior.
		{"vaiven": {"Bone_027": 35.0, "Bone_032": 35.0, "Bone_028": 15.0, "Bone_033": 15.0, "Bone_007": 25.0, "Bone_012": 25.0},
		"eje": {"Bone_028": Vector3(-29.1, 0.0, 9.1), "Bone_033": Vector3(-17.5, 0.0, 21.1), "Bone_032": Vector3(-2.4, 0.0, 28.4),
			"Bone_027": Vector3(-24.2, 0.0, 17.1), "Bone_007": Vector3(-28.9, 0.0, 9.0), "Bone_012": Vector3(-29.6, 0.0, 3.1)},
		"fase": {"Bone_028": 0.25, "Bone_027": 0.25, "Bone_012": 0.25, "Bone_033": 0.72, "Bone_032": 0.72, "Bone_007": 0.72},
		"cola": ["Bone_023", "Bone_022", "Bone_021", "Bone_020", "Bone_019", "Bone_018", "Bone_017", "Bone_016", "Bone_015"],
		"retraso_cola": 0.03}],
}

## Velocidad del clip por personaje (se multiplica por la de VEL_CLIP): id -> {clip: factor}. El gato anda a 0,27: con los pasos tan
## cortos de PASO_CORTO, a velocidad normal movía las patas demasiado deprisa para lo poco que avanzan.
const VEL_CLIP_PJ: Dictionary = {"gato_guardabosques": {"walk": 0.405}, "lince": {"walk": 0.5}}   # 11/10: 0,27 en el laboratorio; Pablo pidió +50 % (con VEL_GATO igual, para que no patine)


## Factor de zancada por personaje y clip (12/10, Pablo con LabHumanoide3D): id -> {clip: {grupo: factor}}. Cada hueso del grupo gira solo
## `factor` de lo que se aleja de su postura media del ciclo (media.slerp(original, factor)): 1 = el clip tal cual, 0 = quieto. Los grupos se
## deducen del esqueleto: lo que cuelga de un UpLeg es «piernas», de un Shoulder «brazos», lo demás «resto». Es la misma cuenta del
## laboratorio, y se aplica ANTES de CORRECCION_POSTURA (el giro fijo va encima, como allí). El nombre del clip es el del GLB (exacto).
const FACTOR_ZANCADA: Dictionary = {
	"woodland_wanderer": {"Walking": {"brazos": 0.44}},
}


func _aplicar_factor_zancada() -> void:
	if _ap == null or not FACTOR_ZANCADA.has(id):
		return
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0] as Skeleton3D
	var por_clip: Dictionary = FACTOR_ZANCADA[id]
	for nombre in por_clip.keys():
		if not _ap.has_animation(nombre):
			continue
		var an: Animation = _ap.get_animation(nombre)
		if an.has_meta("factor_zancada"):
			continue          # el clip es del recurso importado (compartido): una sola vez aunque haya dos instancias
		an.set_meta("factor_zancada", true)
		var factores: Dictionary = por_clip[nombre]
		for t in range(an.get_track_count()):
			if an.track_get_type(t) != Animation.TYPE_ROTATION_3D or an.track_get_key_count(t) < 2:
				continue
			var hueso: String = str(an.track_get_path(t)).get_slice(":", 1)
			var grupo: String = "resto"
			var b: int = sk.find_bone(hueso)
			while b >= 0:
				var n: String = sk.get_bone_name(b)
				if n.ends_with("UpLeg"):
					grupo = "piernas"
					break
				if n.ends_with("Shoulder"):
					grupo = "brazos"
					break
				b = sk.get_bone_parent(b)
			if not factores.has(grupo):
				continue
			var k: float = float(factores[grupo])
			var qs: Array = []
			for i in range(an.track_get_key_count(t)):
				qs.append(an.track_get_key_value(t, i))
			var q0: Quaternion = qs[0]
			var suma := Vector4.ZERO
			for q in qs:
				var qq: Quaternion = q
				if qq.dot(q0) < 0.0:
					qq = Quaternion(-qq.x, -qq.y, -qq.z, -qq.w)      # mismo giro en el otro hemisferio: para promediar bien
				suma += Vector4(qq.x, qq.y, qq.z, qq.w)
			var media: Quaternion = Quaternion(suma.x, suma.y, suma.z, suma.w).normalized()
			for i in range(qs.size()):
				an.track_set_key_value(t, i, media.slerp(qs[i] as Quaternion, k))


## Corrección de postura por personaje (11/10, Pablo con LabGrandmaster3D): id -> {hueso: giro fijo en grados X, Y, Z}. Se aplica a
## TODOS los clips del personaje: q_nueva = giro · q_clip (giro en el espacio del hueso padre, mismo orden de ejes que Quaternion.from_euler,
## igual que el laboratorio). Arregla la postura del modelo de Meshy sin tocar el GLB, así que sobrevive a re-exportarlo.
const CORRECCION_POSTURA: Dictionary = {
	"woodland_wanderer": {
		"mixamorig_LeftShoulder": Vector3(0.0, 19.0, 0.0),
		"mixamorig_LeftHand": Vector3(0.0, 0.0, 31.5),
		"mixamorig_RightArm": Vector3(4.5, 12.0, -3.5),
		"mixamorig_RightHand": Vector3(0.0, -25.0, -35.0),
		"mixamorig_RightShoulder": Vector3(0.0, -12.5, -0.5),
	},
	"grandmaster": {
		"mixamorig_LeftUpLeg": Vector3(7.0, 0.0, 0.0),
		"mixamorig_LeftLeg": Vector3(4.0, 8.5, 0.0),
		"mixamorig_LeftToeBase": Vector3(22.5, 0.0, -18.5),
		"mixamorig_RightFoot": Vector3(28.0, 0.0, 35.0),
		"mixamorig_RightToeBase": Vector3(13.5, 1.0, 32.0),
		"mixamorig_RightToe_End": Vector3(0.0, 0.0, 14.5),
	},
}


func _corregir_postura() -> void:
	if _ap == null or not CORRECCION_POSTURA.has(id):
		return
	var giros: Dictionary = CORRECCION_POSTURA[id]
	for nombre in _ap.get_animation_list():
		var an: Animation = _ap.get_animation(nombre)
		if an.has_meta("postura_corregida"):
			continue          # el clip es del recurso importado (compartido): una sola vez aunque haya dos instancias
		an.set_meta("postura_corregida", true)
		for t in range(an.get_track_count()):
			if an.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var hueso: String = str(an.track_get_path(t)).get_slice(":", 1)
			if not giros.has(hueso):
				continue
			var g: Vector3 = giros[hueso]
			var extra: Quaternion = Quaternion.from_euler(Vector3(deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z)))
			for i in range(an.track_get_key_count(t)):
				an.track_set_key_value(t, i, extra * (an.track_get_key_value(t, i) as Quaternion))


func _acortar_paso() -> void:
	if _ap == null or not PASO_CORTO.has(id):
		return
	var d: Array = PASO_CORTO[id]
	var clip: String = _buscar_clip(String(d[0]))
	if clip == "":
		return
	var an: Animation = _ap.get_animation(clip)
	if an.has_meta("paso_acortado"):
		return          # el clip es del recurso importado (compartido): una sola vez aunque haya dos gatos
	an.set_meta("paso_acortado", true)
	var k_del: float = float(d[1])
	var k_tras: float = float(d[2])
	var k_resto: float = float(d[3])
	var huesos_del: Array = d[4]
	var huesos_tras: Array = d[5]
	var k_hueso: Dictionary = d[6] if d.size() > 6 else {}
	var extra: Dictionary = d[7] if d.size() > 7 else {}
	var vaiven: Dictionary = extra.get("vaiven", {})
	var cola: Array = extra.get("cola", [])
	var L: float = an.length
	for t in range(an.get_track_count()):
		if an.track_get_type(t) != Animation.TYPE_ROTATION_3D or an.track_get_key_count(t) < 2:
			continue
		var hueso: String = str(an.track_get_path(t)).get_slice(":", 1)
		var k: float = k_resto
		if huesos_del.has(hueso):
			k = k_del
		elif huesos_tras.has(hueso):
			k = k_tras
		k = float(k_hueso.get(hueso, k))
		var n: int = an.track_get_key_count(t)
		var q0: Quaternion = an.track_get_key_value(t, 0)
		var suma := Vector4.ZERO
		for i in range(n):
			var q: Quaternion = an.track_get_key_value(t, i)
			if q.dot(q0) < 0.0:
				q = Quaternion(-q.x, -q.y, -q.z, -q.w)      # el mismo giro en el otro hemisferio: para promediar bien
			suma += Vector4(q.x, q.y, q.z, q.w)
		var media: Quaternion = Quaternion(suma.x, suma.y, suma.z, suma.w).normalized()
		var vals: Array = []
		for i in range(n):
			var q2: Quaternion = an.track_get_key_value(t, i)
			vals.append(media.slerp(q2, k))
		if vaiven.has(hueso):
			var amp: float = deg_to_rad(float(vaiven[hueso]))
			var eje: Vector3 = (extra.get("eje", {}) as Dictionary).get(hueso, Vector3.RIGHT)
			var fase: float = float((extra.get("fase", {}) as Dictionary).get(hueso, 0.0))
			for i in range(n):
				var ph: float = TAU * (an.track_get_key_time(t, i) / L - fase)
				vals[i] = Quaternion(eje.normalized(), amp * cos(ph)) * (vals[i] as Quaternion)
		var ic: int = cola.find(hueso)
		var retraso: float = float(extra.get("retraso_cola", 0.0)) * float(ic + 1) * L if ic >= 0 else 0.0
		for i in range(n):
			var nuevo: Quaternion = vals[i]
			if retraso > 0.0:
				nuevo = _muestrear_bucle(an, t, vals, an.track_get_key_time(t, i) - retraso)
			an.track_set_key_value(t, i, nuevo)


## Valor de la pista `t` (con valores `vals` en sus claves) en `tiempo`, dando la vuelta al ciclo (para retrasar la cola sin cortes).
func _muestrear_bucle(an: Animation, t: int, vals: Array, tiempo: float) -> Quaternion:
	var L: float = an.length
	tiempo = fposmod(tiempo, L)
	var n: int = vals.size()
	for i in range(n):
		var t0: float = an.track_get_key_time(t, i)
		var j: int = (i + 1) % n
		var t1: float = an.track_get_key_time(t, j) if j > 0 else an.track_get_key_time(t, 0) + L
		var tt: float = tiempo if tiempo >= t0 else tiempo + L
		if tt >= t0 and tt <= t1:
			return (vals[i] as Quaternion).slerp(vals[j], (tt - t0) / maxf(t1 - t0, 0.00001))
	return vals[0]


## ===================================================================================================================================
##  SER EMPUJADO Y LEVANTARSE (22/10): dos clips de otros GLB (Mixamo, los mismos 28 huesos con los mismos nombres que los goblins).
##    · goblin_behit_flyup.glb · «BeHit_FlyUp», 1,5 s: sale despedido hacia atrás y acaba tumbado. Rol `empujado`.
##    · goblin_stand_up.glb · «Stand_Up1», 8,27 s: se levanta del suelo. Se recorta al tramo útil y se acelera. Rol `levantarse`.
##  No se duplica ningún archivo: al cargar un goblin se LEEN esos GLB (una vez por sesión, en `_fuentes`) y se vuelcan a la librería del AnimationPlayer
##  del goblin como dos animaciones nuevas, «Empujado» y «Levantarse», ya remuestreadas a 30 fps. Qué se trae:
##    · TODAS las pistas de ROTACIÓN (los clips solo traen rotación en los huesos + traslación en la cadera: ninguna otra traslación que descartar).
##    · La traslación de la CADERA, reescrita: x/z fijas (en la posición de reposo de su Idle: el empuje horizontal lo pone el juego) y la y
##      reescalada (ver `_construir_clip`).
## ===================================================================================================================================
const FUENTE_EMPUJADO: String = "res://arte/modelos/goblin_behit_flyup.glb"
const FUENTE_LEVANTARSE: String = "res://arte/modelos/goblin_stand_up.glb"
const CLIP_FUENTE_EMPUJADO: String = "BeHit_FlyUp"
const CLIP_FUENTE_LEVANTARSE: String = "Stand_Up1"
const ANIM_EMPUJADO: String = "Empujado"
const ANIM_LEVANTARSE: String = "Levantarse"
## Modelos (GLB) de goblin que admiten los dos clips (comparten esqueleto Mixamo de 28 huesos).
const MODELOS_EMPUJABLES: Array = ["goblin_warrior_chibi", "goblin_archer_chibi"]
## Cuánto de alto vuela la cadera respecto al clip original (1 = como en el clip: sube ~0,75 alturas del modelo, o sea lo mismo en proporción
## al goblin del juego, que es el modelo escalado). Se aplica a la subida medida desde la cadera de pie.
const EMPUJADO_ESCALA_VUELO: float = 1.0
## Tramo útil de Stand_Up1 (s del clip original): de 0 a ~1,7 s está tumbado sin moverse y de ~6,4 s a 8,27 s ya está de pie quieto.
## Se reproduce a LEVANTARSE_VEL × (4,7 s / 4 = ~1,2 s).
const LEVANTARSE_DESDE: float = 1.7
const LEVANTARSE_HASTA: float = 6.4
const LEVANTARSE_VEL: float = 4.0
const EMPUJADO_FPS: float = 30.0
## Suelo mínimo (altura del hueso más bajo, en unidades del modelo) del cuerpo tumbado: el de su pose de muerte, pero nunca por debajo de esto. El del arquero (Dead) queda ~0,08 más abajo
## que el del guerrero (Die) y al tumbarse el torso se hundía en el suelo (medido en capturas).
const EMPUJADO_SUELO_MIN: float = -0.10

static var _fuentes: Dictionary = {}              ## ruta+clip -> Animation leída del GLB origen (una vez por sesión)
var _cadera_de_pie: Transform3D = Transform3D.IDENTITY   ## pose de la cadera en espacio de esqueleto con el Idle (referencia del escudo)
var _poses_de_pie: Array = []                     ## pose de TODOS los huesos con el Idle (espacio de esqueleto)
var _hueso_cadera: int = -1
var _sk_empuje: Skeleton3D = null


static func admite_empujado(p_id: String) -> bool:
	return MODELOS_EMPUJABLES.has(glb_de(p_id))


## ¿Trae este personaje los clips de empujado y levantarse (y su árbol los admite)?
func tiene_empujado() -> bool:
	return duracion("empujado") > 0.0 and duracion("levantarse") > 0.0


static func _animacion_fuente(ruta: String, nombre: String) -> Animation:
	var k: String = ruta + "|" + nombre
	if _fuentes.has(k):
		return _fuentes[k] as Animation
	var an: Animation = null
	if ResourceLoader.exists(ruta):
		var sc: PackedScene = load(ruta) as PackedScene
		if sc != null:
			var n: Node = sc.instantiate()
			var aps: Array[Node] = n.find_children("*", "AnimationPlayer", true, false)
			if not aps.is_empty() and (aps[0] as AnimationPlayer).has_animation(nombre):
				an = (aps[0] as AnimationPlayer).get_animation(nombre).duplicate() as Animation
			n.free()
	_fuentes[k] = an
	return an


## Rotaciones por hueso de `an` en `t` (nombre de hueso -> Quaternion).
static func _rots_en(an: Animation, t: float) -> Dictionary:
	var r: Dictionary = {}
	for i in range(an.get_track_count()):
		if an.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			r[String(an.track_get_path(i)).get_slice(":", 1)] = an.rotation_track_interpolate(i, t)
	return r


static func _pista_cadera(an: Animation) -> int:
	for i in range(an.get_track_count()):
		if an.track_get_type(i) == Animation.TYPE_POSITION_3D and String(an.track_get_path(i)).to_lower().ends_with("hips"):
			return i
	return -1


## Cinemática directa: pose de cada hueso en espacio de esqueleto con las rotaciones `rots` (los huesos sin pista se quedan en reposo) y la cadera en `pos_cadera`.
func _fk(rots: Dictionary, pos_cadera: Vector3) -> Array:
	var n: int = _sk_empuje.get_bone_count()
	var g: Array = []
	g.resize(n)
	for i in range(n):
		var r: Transform3D = _sk_empuje.get_bone_rest(i)
		var nom: String = _sk_empuje.get_bone_name(i)
		var b: Basis = Basis(rots[nom] as Quaternion) if rots.has(nom) else r.basis
		var o: Vector3 = pos_cadera if i == _hueso_cadera else r.origin
		var loc := Transform3D(b, o)
		var p: int = _sk_empuje.get_bone_parent(i)
		g[i] = loc if p < 0 else (g[p] as Transform3D) * loc
	return g


## Lo más bajo que queda ningún hueso respecto a la cadera (<= 0 cuando está de pie; ~ −0,05 tumbado).
func _bajo_cadera(rots: Dictionary) -> float:
	var g: Array = _fk(rots, Vector3.ZERO)
	var mn: float = 0.0
	var h: float = (g[_hueso_cadera] as Transform3D).origin.y
	for t in g:
		mn = minf(mn, (t as Transform3D).origin.y - h)
	return mn


func _preparar_empujado() -> void:
	if _ap == null or not admite_empujado(id):
		return
	if _ap.has_animation(ANIM_EMPUJADO) and _ap.has_animation(ANIM_LEVANTARSE):
		_enganchar_sk_empuje()
		return
	var idle_n: String = _buscar_clip("idle")
	var muerte_n: String = _buscar_clip("death")
	var fly: Animation = _animacion_fuente(FUENTE_EMPUJADO, CLIP_FUENTE_EMPUJADO)
	var up: Animation = _animacion_fuente(FUENTE_LEVANTARSE, CLIP_FUENTE_LEVANTARSE)
	if idle_n == "" or muerte_n == "" or fly == null or up == null or not _enganchar_sk_empuje():
		push_warning("Pj3D[%s]: no se pudieron traer los clips de empujado y levantarse" % id)
		return
	var idle: Animation = _ap.get_animation(idle_n)
	var muerte: Animation = _ap.get_animation(muerte_n)
	var t_i: int = _pista_cadera(idle)
	var t_m: int = _pista_cadera(muerte)
	var t_f: int = _pista_cadera(fly)
	var t_u: int = _pista_cadera(up)
	if t_i < 0 or t_m < 0 or t_f < 0 or t_u < 0:
		return
	# De pie: la cadera del Idle (su altura y su x/z). El suelo del cuerpo TUMBADO: lo más bajo que llega ningún hueso en la pose final de SU clip de
	# muerte (la que ya se da por buena sobre el suelo): ningún hueso del empujado ni del levantarse baja de ahí.
	var p_idle: Vector3 = idle.track_get_key_value(t_i, 0)
	var rots_idle: Dictionary = _rots_en(idle, 0.0)
	_poses_de_pie = _fk(rots_idle, p_idle)
	_cadera_de_pie = _poses_de_pie[_hueso_cadera]
	var rots_m: Dictionary = _rots_en(muerte, muerte.length)
	var p_m: Vector3 = muerte.track_get_key_value(t_m, muerte.track_get_key_count(t_m) - 1)
	var suelo: float = maxf(p_m.y + _bajo_cadera(rots_m), EMPUJADO_SUELO_MIN)
	var xz := Vector2(p_idle.x, p_idle.z)
	# Empujado: la cadera sale con el pie más bajo a la misma altura que el del Idle y sube EMPUJADO_ESCALA_VUELO × lo que sube en el clip.
	var y_ini: float = p_idle.y + _bajo_cadera(rots_idle) - _bajo_cadera(_rots_en(fly, 0.0))
	var r1: Array = _construir_clip(fly, t_f, 0.0, fly.length, 1.0, y_ini, EMPUJADO_ESCALA_VUELO, suelo, xz)
	# Levantarse: empieza donde acabó el empujado y acaba con la cadera a la altura del Idle (la subida del clip, escalada para que case).
	var y_u0: float = (up.position_track_interpolate(t_u, LEVANTARSE_DESDE)).y
	var y_u1: float = (up.position_track_interpolate(t_u, LEVANTARSE_HASTA)).y
	var k: float = (p_idle.y - float(r1[1])) / maxf(y_u1 - y_u0, 0.001)
	var r2: Array = _construir_clip(up, t_u, LEVANTARSE_DESDE, LEVANTARSE_HASTA, LEVANTARSE_VEL, float(r1[1]), k, suelo, xz)
	var lib: AnimationLibrary = _ap.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		_ap.add_animation_library("", lib)
	lib.add_animation(ANIM_EMPUJADO, r1[0] as Animation)
	lib.add_animation(ANIM_LEVANTARSE, r2[0] as Animation)


func _enganchar_sk_empuje() -> bool:
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return false
	_sk_empuje = sks[0] as Skeleton3D
	_hueso_cadera = _sk_empuje.find_bone("mixamorig_Hips")
	if _hueso_cadera < 0:
		return false
	if _cadera_de_pie == Transform3D.IDENTITY and _ap != null:
		var idle_n: String = _buscar_clip("idle")
		if idle_n != "":
			var idle: Animation = _ap.get_animation(idle_n)
			var t_i: int = _pista_cadera(idle)
			if t_i >= 0:
				_poses_de_pie = _fk(_rots_en(idle, 0.0), idle.track_get_key_value(t_i, 0))
				_cadera_de_pie = _poses_de_pie[_hueso_cadera]
	return true


## Remuestrea `src` (tramo `desde`..`hasta`, `vel` veces más deprisa) a EMPUJADO_FPS con las pistas de rotación y la cadera reescrita:
## x/z = `xz`; y = `y_ini + (y_clip(t) − y_clip(desde)) × k`, y nunca más baja de lo que deja un hueso por debajo de `suelo` (ni el cuerpo tumbado ni la cabeza
## de camino al suelo se hunden). Devuelve [Animation, y de la cadera en el último fotograma].
func _construir_clip(src: Animation, t_cad: int, desde: float, hasta: float, vel: float, y_ini: float, k: float, suelo: float, xz: Vector2) -> Array:
	var dur: float = (hasta - desde) / vel
	var n: int = maxi(int(ceil(dur * EMPUJADO_FPS)), 2)
	var dest := Animation.new()
	dest.length = dur
	dest.loop_mode = Animation.LOOP_NONE
	var prefijo: String = String(_ap.get_node(_ap.root_node).get_path_to(_sk_empuje)) + ":"
	var pistas: Dictionary = {}                          # hueso -> índice de pista destino
	var origen: Dictionary = {}                          # hueso -> índice de pista origen
	for i in range(src.get_track_count()):
		if src.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var nom: String = String(src.track_get_path(i)).get_slice(":", 1)
		if _sk_empuje.find_bone(nom) < 0:
			continue
		var d: int = dest.add_track(Animation.TYPE_ROTATION_3D)
		dest.track_set_path(d, NodePath(prefijo + nom))
		pistas[nom] = d
		origen[nom] = i
	var t_pos: int = dest.add_track(Animation.TYPE_POSITION_3D)
	dest.track_set_path(t_pos, NodePath(prefijo + _sk_empuje.get_bone_name(_hueso_cadera)))
	var y0: float = src.position_track_interpolate(t_cad, desde).y
	var y_fin: float = y_ini
	for f in range(n + 1):
		var u: float = dur * float(f) / float(n)
		var ts: float = desde + (hasta - desde) * float(f) / float(n)
		var rots: Dictionary = {}
		for nom in pistas.keys():
			var q: Quaternion = src.rotation_track_interpolate(int(origen[nom]), ts)
			rots[nom] = q
			dest.rotation_track_insert_key(int(pistas[nom]), u, q)
		var y: float = y_ini + (src.position_track_interpolate(t_cad, ts).y - y0) * k
		y = maxf(y, suelo - _bajo_cadera(rots))
		dest.position_track_insert_key(t_pos, u, Vector3(xz.x, y, xz.y))
		y_fin = y
	return [dest, y_fin]


## Transformadas MUNDIALES de la cadera: [actual, de pie]. Su cociente es cómo se ha movido el cuerpo (lo usa el escudo para ir con él mientras vuela).
## Vacío si el personaje no tiene esqueleto.
func cadera_mundo() -> Array:
	if _sk_empuje == null or _hueso_cadera < 0 or not _sk_empuje.is_inside_tree():
		return []
	var w: Transform3D = _sk_empuje.global_transform
	return [w * _sk_empuje.get_bone_global_pose(_hueso_cadera), w * _cadera_de_pie]


## Lo mismo para cualquier hueso (p. ej. el antebrazo que lleva el escudo): [transformada mundial ahora, transformada mundial de pie]. Vacío si no existe.
func hueso_mundo(hueso: String) -> Array:
	if _sk_empuje == null or not _sk_empuje.is_inside_tree() or _poses_de_pie.is_empty():
		return []
	var h: int = _sk_empuje.find_bone(hueso)
	if h < 0:
		return []
	var w: Transform3D = _sk_empuje.global_transform
	return [w * _sk_empuje.get_bone_global_pose(h), w * (_poses_de_pie[h] as Transform3D)]


## Transformada MUNDIAL de `hueso` AHORA MISMO (la escala del modelo va dentro de su base), o null si no hay esqueleto o hueso. A diferencia de `hueso_mundo` no necesita
## la pose de pie: sirve para colgarle algo a mano cada fotograma (el escudo del goblin). `hueso` = nombre completo o el final (`LeftForeArm`).
func hueso_ahora(hueso: String) -> Variant:
	if _sk_ahora == null or not is_instance_valid(_sk_ahora):
		_sk_ahora = _esqueleto()
		_huesos_ahora.clear()
	var sk: Skeleton3D = _sk_ahora
	if sk == null or not sk.is_inside_tree():
		return null
	if not _huesos_ahora.has(hueso):
		var h0: int = sk.find_bone(hueso)
		_huesos_ahora[hueso] = h0 if h0 >= 0 else Equipo3D._hueso(sk, hueso)
	var h: int = int(_huesos_ahora[hueso])
	if h < 0:
		return null
	return sk.global_transform * sk.get_bone_global_pose(h)


## Muestra u oculta la pieza de equipo `pieza` (el id de `Equipo3D.EQUIPO`: «escudo», «garrote»…). Devuelve cuántas cambió. Lo usa el escudo del goblin (`Escudo3D`)
## para que el de adorno del brazo no se duplique con el de verdad.
func poner_equipo_visible(pieza: String, visible_: bool) -> int:
	var n: int = 0
	for p in _equipo:
		if is_instance_valid(p) and String(p.get_meta("equipo_id", "")) == pieza:
			p.visible = visible_
			n += 1
	return n


## ===================================================================================================================================
##  MANO QUEMADA (22/10): el clip del goblin que se sacude la mano del escudo cuando se le consume ardiendo (`Escudo3D._quemar_mano`, diario 239).
##  NO hay ningún clip así en los GLB de goblins (ni en arte/meshy/: se miraron los nombres) y no se trae ninguno de fuera: se CONSTRUYE POR CÓDIGO sobre el
##  Idle del propio goblin, como Empujado/Levantarse (misma librería, remuestreado a 30 fps): todas las pistas del Idle tal cual y, encima, la pose del brazo
##  que lleva el escudo (se alza, se dobla el codo, la mano se agita) y un encogimiento del torso. Dura MANO_QUEMADA_DUR = `Escudo3D.T_MANO_QUEMADA`.
## ===================================================================================================================================
const ANIM_MANO_QUEMADA: String = "ManoQuemada"
const MANO_QUEMADA_DUR: float = 1.2
const MANO_QUEMADA_HZ: float = 9.0              ## sacudidas por segundo de la mano
const MANO_QUEMADA_SUBE: float = 0.12           ## fracción del clip que tarda en llegar a la pose (el pinchazo de dolor es rápido)
const MANO_QUEMADA_BAJA: float = 0.8            ## fracción del clip desde la que vuelve a la pose del Idle (el aturdimiento acaba en reposo)
const MANO_QUEMADA_APAGA: float = 0.35          ## cuánto se apaga la sacudida a lo largo del clip (0 = igual, 1 = acaba quieta)
## Hueso -> [eje local, grados de la POSTURA (se llega a ella y se mantiene), grados de la SACUDIDA (oscila con MANO_QUEMADA_HZ)].
const MANO_QUEMADA_HUESOS: Dictionary = {
	"mixamorig_LeftArm": [Vector3(0.0, 0.0, 1.0), 40.0, 8.0],
	"mixamorig_LeftForeArm": [Vector3(1.0, 0.0, 0.0), -70.0, 10.0],
	"mixamorig_LeftHand": [Vector3(0.0, 0.0, 1.0), 0.0, 50.0],
	"mixamorig_Spine1": [Vector3(1.0, 0.0, 0.0), 18.0, 0.0],
}


## Cuánto de la pose (0..1) hay en el instante normalizado `u` (0..1): sube rápido, se mantiene y vuelve al final.
static func envolvente_mano_quemada(u: float) -> float:
	return smoothstep(0.0, MANO_QUEMADA_SUBE, u) * (1.0 - smoothstep(MANO_QUEMADA_BAJA, 1.0, u))


## El giro (local, se multiplica por la derecha) que se le añade a `hueso` en el instante normalizado `u` del clip.
static func giro_mano_quemada(hueso: String, u: float) -> Quaternion:
	var d: Array = MANO_QUEMADA_HUESOS[hueso]
	var e: float = envolvente_mano_quemada(u)
	var sacudida: float = float(d[2]) * e * (1.0 - MANO_QUEMADA_APAGA * u) * sin(TAU * MANO_QUEMADA_HZ * MANO_QUEMADA_DUR * u)
	return Quaternion((d[0] as Vector3).normalized(), deg_to_rad(float(d[1]) * e + sacudida))


## ¿Trae este personaje el clip (construido o heredado de su GLB)?
func tiene_mano_quemada() -> bool:
	return duracion("mano_quemada") > 0.0


func _preparar_mano_quemada() -> void:
	if _ap == null or not admite_empujado(id) or _ap.has_animation(ANIM_MANO_QUEMADA):
		return
	var idle_n: String = _buscar_clip("idle")
	var sk: Skeleton3D = _esqueleto()
	if idle_n == "" or sk == null:
		return
	var idle: Animation = _ap.get_animation(idle_n)
	var prefijo: String = String(_ap.get_node(_ap.root_node).get_path_to(sk)) + ":"
	var dest := Animation.new()
	dest.length = MANO_QUEMADA_DUR
	dest.loop_mode = Animation.LOOP_NONE
	var n: int = maxi(int(ceil(MANO_QUEMADA_DUR * EMPUJADO_FPS)), 2)
	for i in range(idle.get_track_count()):
		var tipo: int = idle.track_get_type(i)
		if tipo != Animation.TYPE_ROTATION_3D and tipo != Animation.TYPE_POSITION_3D:
			continue
		var nom: String = String(idle.track_get_path(i)).get_slice(":", 1)
		if sk.find_bone(nom) < 0:
			continue
		var d: int = dest.add_track(tipo)
		dest.track_set_path(d, NodePath(prefijo + nom))
		for f in range(n + 1):
			var u: float = float(f) / float(n)
			var ts: float = fposmod(MANO_QUEMADA_DUR * u, maxf(idle.length, 0.001))
			if tipo == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = idle.rotation_track_interpolate(i, ts)
				if MANO_QUEMADA_HUESOS.has(nom):
					q = q * giro_mano_quemada(nom, u)
				dest.rotation_track_insert_key(d, MANO_QUEMADA_DUR * u, q)
			else:
				dest.position_track_insert_key(d, MANO_QUEMADA_DUR * u, idle.position_track_interpolate(i, ts))
	var lib: AnimationLibrary = _ap.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		_ap.add_animation_library("", lib)
	lib.add_animation(ANIM_MANO_QUEMADA, dest)


## Quita al clip `rol` el desplazamiento horizontal de la cadera (el personaje rueda en el sitio y lo mueve el Juego). Idempotente.
func _anular_raiz(rol: String) -> void:
	if _ap == null:
		return
	var clip: String = _buscar_clip(rol)
	if clip == "":
		return
	var an: Animation = _ap.get_animation(clip)
	for t in range(an.get_track_count()):
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D or an.track_get_key_count(t) < 2:
			continue
		if not str(an.track_get_path(t)).to_lower().contains("hips"):
			continue
		var p0: Vector3 = an.track_get_key_value(t, 0)
		for k in range(an.track_get_key_count(t)):
			var v: Vector3 = an.track_get_key_value(t, k)
			an.track_set_key_value(t, k, Vector3(p0.x, v.y, p0.z))


## 15/10 (DIARIO 94) · NADO: el clip `swim` (SwimForward de Meshy) viene con la cadera MUY por debajo del origen (y ≈ −0,75 en unidades del modelo,
## frente a 0,74 de pie: el cuerpo tumbado quedaba 0,5 u BAJO los pies del personaje, o sea bajo el fondo del pozo o bajo un agua casi opaca) y con la
## cadera avanzando ~4,6 unidades del modelo (≈ 2,7 u en el juego) en cada vuelta de 4,5 s: el modelo se alejaba del jugador y volvía de golpe.
## Se arregla en el propio clip, como `_anular_raiz` con la voltereta: la cadera se queda sobre el origen (el Juego mueve al personaje) y se sube hasta
## `NADO_CADERA` × la altura de su cadera de pie (0,93: tumbado, con la espalda a ras de agua cuando los pies van a `superficie − HUNDIDO`, 0,35 u).
## Idempotente (las animaciones se comparten entre instancias del mismo GLB): fija la MEDIA de y y la x/z al valor pedido, no suma.
const NADO_CADERA: float = 0.93


func _colocar_nado() -> void:
	if _ap == null:
		return
	var swim: String = _buscar_clip("swim")
	var idle: String = _buscar_clip("idle")
	if swim == "" or idle == "":
		return
	var y_pie: float = NAN
	var an_i: Animation = _ap.get_animation(idle)
	for t in range(an_i.get_track_count()):
		if an_i.track_get_type(t) == Animation.TYPE_POSITION_3D and str(an_i.track_get_path(t)).to_lower().contains("hips") \
				and an_i.track_get_key_count(t) > 0:
			y_pie = (an_i.track_get_key_value(t, 0) as Vector3).y
	if is_nan(y_pie):
		return
	var an: Animation = _ap.get_animation(swim)
	for t in range(an.get_track_count()):
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D or an.track_get_key_count(t) < 2:
			continue
		if not str(an.track_get_path(t)).to_lower().contains("hips"):
			continue
		var n: int = an.track_get_key_count(t)
		var media: float = 0.0
		for k in range(n):
			media += (an.track_get_key_value(t, k) as Vector3).y
		media /= float(n)
		var dy: float = y_pie * NADO_CADERA - media
		for k in range(n):
			var v: Vector3 = an.track_get_key_value(t, k)
			an.track_set_key_value(t, k, Vector3(0.0, v.y + dy, 0.0))


## (c) BEBER: `beber(dur = 1.5)` pone la poción (50 % de su tamaño en el suelo) en la mano derecha, reproduce `stand_drink` recortado
## a la parte en que bebe (de ~2,0 s a ~6,0 s del clip, acelerado para durar `dur`) y al terminar la quita y vuelve a `idle`. El Juego
## bloquea el movimiento ese tiempo. Devuelve `dur`. Emite `bebida_terminada` al acabar.
signal bebida_terminada
const BEBER_DESDE: float = 2.0
const BEBER_HASTA: float = 6.0
var _bebiendo: bool = false


func beber(dur: float = 1.5) -> float:
	if _arbol == null or _bebiendo:
		return 0.0
	var clip: String = _buscar_clip("drink")
	if clip == "":
		return 0.0
	# El tramo que bebe (2…6 s del clip) es el estado «beber», acelerado para durar `dur`. Sin bucle: al llegar a 6 s se queda ahí hasta el idle.
	if not _arbol.pedir("beber", clip, {"desde": BEBER_DESDE, "hasta": BEBER_HASTA, "bucle": Animation.LOOP_NONE,
			"vel": (BEBER_HASTA - BEBER_DESDE) / maxf(dur, 0.2), "mezcla": 0.0}):
		return 0.0
	_bebiendo = true
	equipar("pocion")
	animacion_actual = "drink"
	_arbol.vel_global = 1.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(dur)
	tw.tween_callback(func() -> void:
		_bebiendo = false
		desequipar("pocion")
		animacion_actual = ""
		jugar("idle")
		bebida_terminada.emit())
	return dur


## Cuelga una pieza de Equipo3D.pieza(id) en una mano (por defecto la derecha) a un tamaño relativo al personaje; devuelve el
## nodo. Las que ya cuelgan del esqueleto (arma, escudo, grimorio) no se tocan. `Pj3D.equipar("pocion")` = poción en la mano.
## `PIEZAS_MANO` da por id: [hueso, posición, giro en grados, alto relativo al personaje].
const PIEZAS_MANO: Dictionary = {
	"pocion": ["LeftHand", Vector3(0.0, 0.08, 0.04), Vector3(0.0, 0.0, 0.0), 0.225],
}
var _piezas_mano: Dictionary = {}


func equipar(pieza_id: String) -> Node3D:
	if _modelo == null or not PIEZAS_MANO.has(pieza_id):
		return null
	desequipar(pieza_id)
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var sk: Skeleton3D = sks[0] as Skeleton3D
	var d: Array = PIEZAS_MANO[pieza_id]
	var h: int = Equipo3D._hueso(sk, String(d[0]))
	if h < 0:
		return null
	var escala: float = 1.0
	var n: Node = sk
	while n != null and n != _modelo:
		if n is Node3D:
			escala *= (n as Node3D).scale.y
		n = n.get_parent()
	var at := BoneAttachment3D.new()
	at.name = "Mano_" + pieza_id
	at.bone_name = sk.get_bone_name(h)
	sk.add_child(at)
	var p: Node3D = Equipo3D.pieza(pieza_id)
	var tam_modelo: float = Equipo3D.MEDIDA_PIEZA.get(pieza_id, 0.4)
	# alto relativo: la pieza mide `tam_modelo` en unidades del goblin (1,7); se lleva a (alto rel × alto del personaje) en el mundo.
	var f: float = (float(d[3]) * maxf(alto_modelo(), 0.01)) / maxf(tam_modelo, 0.0001)
	p.position = (d[1] as Vector3) / maxf(escala, 0.0001)
	p.rotation_degrees = d[2] as Vector3
	p.scale = Vector3.ONE * f / maxf(escala, 0.0001)
	at.add_child(p)
	_piezas_mano[pieza_id] = at
	return p


func desequipar(pieza_id: String = "") -> void:
	if pieza_id == "":
		for k in _piezas_mano.keys():
			desequipar(String(k))
		return
	var at: Variant = _piezas_mano.get(pieza_id)
	if at != null and is_instance_valid(at):
		(at as Node).queue_free()
	_piezas_mano.erase(pieza_id)


func _quitar_chispas() -> void:
	if _chispas != null and is_instance_valid(_chispas):
		_chispas.queue_free()
	_chispas = null


## Segundos de mezcla al cambiar de clip en `jugar` (0 = salto seco).
const MEZCLA_CLIPS: float = 0.15
## Velocidad propia de algunos roles (1 = original), además de la que pida quien llama. 10/10 (Pablo): la voltereta al DOBLE de velocidad.
## El clip se reproduce entero, solo que en la mitad de tiempo; `duracion(rol)` ya devuelve lo que dura de verdad (el Juego la usa para
## el tiempo y la distancia de la voltereta).
const VEL_CLIP: Dictionary = {"roll": 2.0}


func jugar(nombre: String, una_vez: bool = false, vel: float = 1.0) -> void:
	if _arbol == null:
		return
	# Un personaje sin el clip pedido usa su sustituto (elfo_base no trae `run`: corre con `walk`).
	var sustituto: String = String((ROL_SUSTITUTO.get(id, {}) as Dictionary).get(nombre, ""))
	if sustituto != "" and _buscar_clip(nombre) == "":
		nombre = sustituto
	if nombre == animacion_actual:
		return
	_reproducir(nombre, una_vez, vel, MEZCLA_CLIPS)


## El nombre del ESTADO del árbol para un rol de clip: los del héroe en español (andar, correr, nadar, apuntar, golpeado, rodar, beber, muerto, atacar),
## los de lanzar como «lanzar» / «lanzar_<forma>», y el resto con el nombre del rol (talk, walk_back...).
const ESTADO_DE: Dictionary = {"walk": "andar", "run": "correr", "swim": "nadar", "leer": "apuntar", "hit": "golpeado", "roll": "rodar",
	"drink": "beber", "death": "muerto", "attack": "atacar", "cast": "lanzar"}


static func estado_de(rol: String) -> String:
	if ESTADO_DE.has(rol):
		return String(ESTADO_DE[rol])
	if rol.begins_with("cast_"):
		return "lanzar_" + rol.substr(5)
	return rol


## Pide al árbol el clip del rol `nombre`. `una_vez`: el clip se reproduce entero y se queda en su último fotograma (muerte, golpe, disparo); para repetirlo hay
## que pasar antes por otro clip (jugar("idle")) o poner animacion_actual = "". Sin `una_vez` va en bucle (`leer`, en ida y vuelta). `forzar` salta la
## comprobación de que ya esté puesto. Si la regla del árbol lo prohíbe no cambia nada (ni animacion_actual).
func _reproducir(nombre: String, una_vez: bool, vel: float, mezcla: float, _forzar: bool = false) -> void:
	var clip: String = _buscar_clip(nombre)
	if clip == "":
		return
	var bucle: int = Animation.LOOP_NONE if una_vez else (Animation.LOOP_PINGPONG if PINGPONG.has(nombre) else Animation.LOOP_LINEAR)
	# Mezcla corta con el clip anterior. Sin ella el cambio es un salto seco: en el elemental la cadera pasa de 0,81 (idle) a 0,65
	# (walk) de golpe, y si la IA alterna quieto/andando en el borde del rango se ve como tirones. Medido en los GLB.
	var v: float = vel * float(VEL_CLIP.get(nombre, 1.0)) * float(VEL_CLIP_PJ.get(id, {}).get(nombre, 1.0))
	if _arbol.pedir(estado_de(nombre), clip, {"bucle": bucle, "vel": v, "mezcla": mezcla}):
		animacion_actual = nombre


## Lo que dura el clip de `nombre` (s) a su velocidad normal (la de VEL_CLIP si la tiene: la voltereta va al doble), o 0 si no existe.
## La IA lo usa para no cortar una animación a medias (p. ej. el disparo del arquero dura 5 s, no 0,8).
func duracion(nombre: String) -> float:
	if _ap == null:
		return 0.0
	var clip: String = _buscar_clip(nombre)
	return _ap.get_animation(clip).length / float(VEL_CLIP.get(nombre, 1.0)) if clip != "" else 0.0


## En qué momento del clip `nombre` sale el golpe/la flecha, como fracción de su duración (0..1). Medido a ojo en el clip:
## ArcheryShot alza el arco hacia 1,5 s, apunta de 2,3 a 4,1 s y suelta a ~4,2 s (0,84).
## 6.13 FOTOGRAMA DE APUNTADO del arquero: segundo del clip (a velocidad 1) con los brazos extendidos y el arco en alto; el clip
## se bloquea ahí mientras apunta y se suelta desde ahí. En ArcheryShot los brazos están extendidos de ~2,8 s a ~3,7 s; se bloquea en 3,0 s.
## `momento_golpe` sigue siendo la fracción (de la duración con que se reproduce) en la que sale la flecha.
const FOTOGRAMA_APUNTADO: Dictionary = {"goblin_archer_chibi": {"attack": 3.0}}
const MOMENTO_GOLPE: Dictionary = {"goblin_archer_chibi": {"attack": 0.84}}

## Segundo del clip `nombre` en que se bloquea al apuntar (0 si el personaje no tiene fotograma de bloqueo).
func fotograma_apuntado(nombre: String) -> float:
	return float((FOTOGRAMA_APUNTADO.get(id, {}) as Dictionary).get(nombre, 0.0))


## Pone el clip `nombre` en su fotograma de apuntado y lo CONGELA (la animación se aguanta mientras se apunta). Devuelve false si no
## tiene fotograma de bloqueo (entonces se usa `jugar(nombre, true)` como siempre).
func apuntar_clip(nombre: String = "attack") -> bool:
	var t: float = fotograma_apuntado(nombre)
	var clip: String = _buscar_clip(nombre)
	if _arbol == null or t <= 0.0 or clip == "":
		return false
	# El clip desde el fotograma de apuntado hasta el final, RETENIDO (velocidad 0): es el estado «atacar_apuntado». Al soltar sigue desde ahí.
	if not _arbol.pedir(estado_de(nombre) + "_apuntado", clip, {"desde": t, "bucle": Animation.LOOP_NONE, "mezcla": 0.0, "retenido": true}):
		return false
	animacion_actual = nombre
	return true


## Suelta el apuntado: el clip sigue desde donde estaba (velocidad `vel`, 1 por defecto) hasta que sale la flecha y termina.
func soltar_apuntado(vel: float = 1.0) -> void:
	if _arbol != null:
		_arbol.retenido = false
		_arbol.vel_global = vel


func momento_golpe(nombre: String) -> float:
	return float((MOMENTO_GOLPE.get(id, {}) as Dictionary).get(nombre, 0.5))


## Velocidad de las animaciones (1 = normal). Sirve para que la elfa siga animada a velocidad normal
## cuando el mundo va a cámara lenta (grimorio abierto): se le pasa 1 / Engine.time_scale.
func set_velocidad_animacion(v: float) -> void:
	if _arbol != null:
		_arbol.vel_global = v


## La velocidad de animación puesta con `set_velocidad_animacion` (1 si no hay árbol).
func velocidad_animacion() -> float:
	return _arbol.vel_global if _arbol != null else 1.0


## El estado de animación al que ha ido el personaje (idle, andar, lanzar_x_mano…) y el clip que reproduce; «» si no hay árbol.
func estado_anim() -> String:
	return _arbol.estado if _arbol != null else ""


func clip_actual() -> String:
	return _arbol.clip_actual() if _arbol != null else ""


## El árbol de animación (para el laboratorio F5 y las pruebas; no para reproducir clips).
func arbol() -> ArbolAnimPj:
	return _arbol


## Deja el personaje en el instante `t` (s) del clip del rol, quieto. Solo para pruebas y laboratorios (poner una pose conocida).
func pose_fija(rol: String, t: float) -> bool:
	var clip: String = _buscar_clip(rol)
	if _arbol == null or clip == "":
		return false
	animacion_actual = rol
	return _arbol.pedir("pose_" + rol, clip, {"desde": t, "bucle": Animation.LOOP_NONE, "mezcla": 0.0, "retenido": true})


func lista_clips() -> PackedStringArray:
	if _ap == null:
		return PackedStringArray()
	return _ap.get_animation_list()


## El nombre del clip del GLB que usa el rol `rol` ("" si no hay). Para pruebas y laboratorios.
func clip_de(rol: String) -> String:
	return _buscar_clip(rol) if _ap != null else ""


func _buscar_clip(nombre: String) -> String:
	var lista: PackedStringArray = _ap.get_animation_list()
	var propios: Dictionary = CLIPS_DE.get(id, {})
	if propios.has(nombre):
		var k0: String = String(propios[nombre]).to_lower()
		for n in lista:
			if n.to_lower() == k0:
				return n
	var claves: Array = SINONIMOS.get(nombre, [nombre])
	for c in claves:
		var k: String = String(c).to_lower()
		for n in lista:
			if n.to_lower() == k:
				return n
	for c in claves:
		var k2: String = String(c).to_lower()
		for n in lista:
			if n.to_lower().contains(k2):
				return n
	return ""


## Tipo de personaje para la lista mínima de clips: heroe, goblin, arquero o npc.
static func tipo_de(p_id: String) -> String:
	if p_id.begins_with("goblin_archer"):
		return "arquero"
	if p_id.begins_with("goblin"):
		return "goblin"
	if p_id.begins_with("elemental"):
		return "elemental"
	if p_id.begins_with("lober") or p_id == "lince":
		return "bestia"
	if p_id.begins_with("chibi_elf") or p_id == "chibi_test" or p_id.begins_with("hero") or p_id.begins_with("woodland_wanderer"):
		return "heroe"
	return "npc"


## Comprueba el GLB cargado (DISENO_FUTURO §5, versión 3D): clips mínimos de su tipo, que los clips "en su sitio"
## no arrastren la cadera, y que la escala del modelo sea la de un personaje de ~1,7. Devuelve los avisos
## (vacío = todo bien); cargar() los saca por consola, como hacía ActorAnimator._check_sheets.
func validar() -> PackedStringArray:
	var avisos := PackedStringArray()
	if _modelo == null:
		return avisos
	if _ap == null:
		avisos.append("el GLB no trae AnimationPlayer: no hay ningún clip")
		return avisos
	var tipo: String = tipo_de(id)
	for rol in MINIMOS[tipo]:
		var clip: String = _buscar_clip(String(rol))
		if clip == "":
			var buscado: Array = CLIPS_DE.get(id, {}).values() + SINONIMOS.get(rol, [rol])
			avisos.append("falta el clip '%s' de un %s (busca: %s). Clips del GLB: %s" % [rol, tipo,
				", ".join(PackedStringArray(buscado)), ", ".join(_ap.get_animation_list())])
			continue
		if EN_SITIO.has(rol):
			var d: float = _desplazamiento(clip)
			if d > DESPLAZA_MAX:
				avisos.append("el clip '%s' (%s) arrastra la cadera %.2f alturas de cadera: se verá fuera de su sitio" % [rol, clip, d])
	if not _caja_vacia and (_caja.size.y < ALTO_BRUTO.x or _caja.size.y > ALTO_BRUTO.y):
		avisos.append("el modelo mide %.2f unidades tal como viene (se espera %.1f–%.1f, ~1,7): ¿escala en cm o en m?" % [
			_caja.size.y, ALTO_BRUTO.x, ALTO_BRUTO.y])
	return avisos


## Cuánto se aleja la cadera de su primera posición en el plano del suelo durante un clip, en alturas de cadera
## (0 = en su sitio). Lee la pista de posición del hueso "Hips"; 0 si el clip no la tiene.
func _desplazamiento(clip: String) -> float:
	var anim: Animation = _ap.get_animation(clip)
	if anim == null:
		return 0.0
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not String(anim.track_get_path(i)).to_lower().ends_with("hips"):
			continue
		var n: int = anim.track_get_key_count(i)
		if n < 2:
			return 0.0
		var p0: Vector3 = anim.track_get_key_value(i, 0)
		var alto: float = maxf(absf(p0.y), 0.0001)
		var mas: float = 0.0
		for k in range(1, n):
			var p: Vector3 = anim.track_get_key_value(i, k)
			mas = maxf(mas, Vector2(p.x - p0.x, p.z - p0.z).length())
		return mas / alto
	return 0.0



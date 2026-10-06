class_name Pj3D
extends Node3D

## Un personaje del pipeline como modelo 3D vivo (la chibi, hero_v2...). Sin sprites ni atlas:
## se carga el GLB maestro de res://poc_25d/<id>.glb, se apoya en el suelo y se anima con el
## AnimationPlayer del propio modelo. Se gira libremente hacia donde se mueve (no hay 8 filas).

const SINONIMOS: Dictionary = {
	"idle": ["idle"],
	"walk": ["walking", "walk"],
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
	"hit": ["hit_reaction", "hit", "facepunchreaction", "slapreaction"],
	"death": ["shot_and_fall_backward", "shot_in_the_back_and_fall", "death", "dead", "die"],
	"talk": ["stand_talking", "talking"],
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
}

## Clips mínimos por tipo de personaje (la misma lista que docs/ASSETS_PENDIENTES.md §1).
const MINIMOS: Dictionary = {
	"heroe": ["idle", "walk", "run", "cast", "hit", "death", "roll", "leer", "swim"],
	"goblin": ["idle", "walk", "attack", "hit", "death"],
	"arquero": ["idle", "walk", "walk_back", "attack", "hit", "death"],
	"npc": ["idle", "walk", "talk"],
}

## Roles cuyo clip debe quedarse en su sitio: la cadera no se aleja de donde empieza (en alturas de cadera).
## death, roll y swim sí se desplazan a propósito.
const EN_SITIO: Array = ["idle", "walk", "walk_back", "run", "cast", "attack", "hit", "leer", "talk", "wave"]
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
}

var id: String = ""
var proporcion: ProporcionChibi = null
var modo_luz: int = 1            ## 0 = plana (sin sombreado), 1 = luz suave
var animacion_actual: String = ""

var _modelo: Node3D = null
var _equipo: Array[Node3D] = []
var _ap: AnimationPlayer = null
var _materiales: Array[StandardMaterial3D] = []
var _caja: AABB = AABB()
var _caja_vacia: bool = true
var _yaw: float = 0.0
var _chispas: Node3D = null      ## BoneAttachment3D con las partículas de la mano mientras se lanza


func cargar(p_id: String) -> bool:
	id = p_id
	var ruta: String = "res://poc_25d/%s.glb" % glb_de(id)
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
	if not aps.is_empty():
		_ap = aps[0] as AnimationPlayer
		for nombre in _ap.get_animation_list():
			_ap.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR

	_crear_proporcion()
	_equipo = Equipo3D.equipar(id, _modelo)
	_crear_sombra()
	set_modo_luz(modo_luz)
	jugar("idle")
	if validar_al_cargar and not _validados.has(id):
		_validados[id] = true
		var avisos: PackedStringArray = validar()
		for a in avisos:
			push_warning("Pj3D[%s]: %s" % [id, a])
	return true


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


## Disco oscuro bajo los pies, como la sombra de los sprites.
func _crear_sombra() -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = 0.55
	disco.bottom_radius = 0.55
	disco.height = 0.01
	disco.radial_segments = 24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	disco.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = disco
	mi.position = Vector3(0.0, 0.02, 0.0)
	add_child(mi)


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
				copia.roughness = 1.0
				mi.set_surface_override_material(s, copia)
				_materiales.append(copia)


func set_modo_luz(m: int) -> void:
	modo_luz = m
	for mat in _materiales:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if m == 0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL


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


## Gira suavemente hacia `d` (vector en el plano del suelo).
func mirar(d: Vector3, delta: float) -> void:
	if d.length() < 0.001:
		return
	var objetivo: float = atan2(d.x, d.z)
	_yaw = lerp_angle(_yaw, objetivo, clampf(delta * 12.0, 0.0, 1.0))
	rotation.y = _yaw


## Empieza a lanzar un hechizo de `forma` y `elemento` (el "modo lanzar" de DISENO_FUTURO §0b): el clip de
## ANIM_CAST (o readandwrite) en bucle y partículas sutiles del elemento en la mano derecha. Devuelve lo que dura
## el clip. Se termina con soltar_lanzar(). Solo el nombre del elemento: cómo se ve lo decide Vfx3D.
func lanzar(forma: String, elemento: String) -> float:
	if _ap == null:
		return 0.0
	_quitar_chispas()
	var rol: String = String(ANIM_CAST.get(forma, "leer"))
	var clip: String = _buscar_clip(rol)
	if clip == "":
		rol = "leer"
		clip = _buscar_clip(rol)
	animacion_actual = ""
	jugar(rol)
	_poner_chispas(elemento)
	return _ap.get_animation(clip).length if clip != "" else 0.0


## Para las partículas de la mano y vuelve a idle.
func soltar_lanzar() -> void:
	_quitar_chispas()
	animacion_actual = ""
	jugar("idle")


func _poner_chispas(elemento: String) -> void:
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0] as Skeleton3D
	var h: int = Equipo3D._hueso(sk, "RightHand")
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


func _quitar_chispas() -> void:
	if _chispas != null and is_instance_valid(_chispas):
		_chispas.queue_free()
	_chispas = null


func jugar(nombre: String) -> void:
	if _ap == null or nombre == animacion_actual:
		return
	var clip: String = _buscar_clip(nombre)
	if clip == "":
		return
	animacion_actual = nombre
	_ap.play(clip)


## Velocidad de las animaciones (1 = normal). Sirve para que la elfa siga animada a velocidad normal
## cuando el mundo va a cámara lenta (grimorio abierto): se le pasa 1 / Engine.time_scale.
func set_velocidad_animacion(v: float) -> void:
	if _ap != null:
		_ap.speed_scale = v


func lista_clips() -> PackedStringArray:
	if _ap == null:
		return PackedStringArray()
	return _ap.get_animation_list()


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
	if p_id.begins_with("chibi_elf") or p_id == "chibi_test" or p_id.begins_with("hero"):
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

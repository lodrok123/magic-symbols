class_name GlifoComunVfx
extends Node
## EFECTOS COMUNES DE GLIFO (24/11/2026, sesión HECHIZOS; Pablo eligió «efectos comunes de glifo» tras docs/MYSTRALIA_VFX_HECHIZOS_CODIGO_2026-11-24.md §2:
## Mystralia tiene un `CommonFxSpellConfig` con rebote, multidisparo, empuje… que NO dependen del elemento).
## Idea: cada glifo que cambia lo que pasa enseña SU runa, pequeña y un instante, justo donde actúa. El elemento ya lo cuenta el VFX del toy; esto cuenta el GLIFO.
## No se dibuja nada nuevo: la runa es su PNG del libro (`art/ui/glyphs/<glifo>.png`, blanca: se tiñe) y el aro es el de ᛒ (`GlifoSueloVfx.textura_anillo`).
##   · ᚠ repetición: al soltar, la runa en la mano y un abanico de trazos cortos por donde sale cada copia (en ráfaga, trazos en fila).
##   · ᚢ rebote: en cada rebote, la runa en el punto y un aro plano contra la pared (perpendicular a la normal).
##   · el HIJO (anidación, de momento solo el prototipo del libro rojo): un aro que se cierra («nudo») y la runa del sello del hijo, donde nace.
## Solo representa: escucha al Lanzador y a cada HechizoVivo y nunca toca la lógica. Sin luces (el presupuesto de luces es del toy). `activo = false` lo calla.
## Uso:   GlifoComunVfx.conectar(lanzador, mundo)

const RUTA_RUNA: String = "res://art/ui/glyphs/%s.png"
## Color de las runas: el de la tinta del libro, neutro (no es el del elemento: así se lee «esto es el glifo»). A decidir por Pablo.
const COLOR_GLIFO: Color = Color(1.0, 0.93, 0.80)
const LADO_RUNA_M: float = 0.55
const LADO_ARO_M: float = 0.9
const ALTO_SOBRE_MANO_M: float = 0.55          ## la runa de ᚠ, por encima de la mano
const T_NACE_S: float = 0.08
const T_QUIETA_S: float = 0.22
const T_APAGA_S: float = 0.30
const LARGO_TRAZO_M: float = 0.9               ## trazos del abanico de ᚠ
const ANCHO_TRAZO_M: float = 0.07

static var activo: bool = true
static var cuenta: Dictionary = {"repeticion": 0, "rebote": 0, "hijo": 0}    ## cuántos ha dibujado de cada (pruebas)
static var _texturas: Dictionary = {}

var lz: Lanzador3D = null
var mundo: Node3D = null


static func conectar(lanzador: Lanzador3D, mundo_: Node3D) -> GlifoComunVfx:
	var g := GlifoComunVfx.new()
	g.name = "GlifoComunVfx"
	g.lz = lanzador
	g.mundo = mundo_
	mundo_.add_child(g)
	if lanzador != null:
		lanzador.hechizo_vivo_creado.connect(g._al_crear)
		lanzador.child_entered_tree.connect(g._al_entrar)
	return g


# ------------------------------------------------------------------------------------------------ escucha

## Cada HechizoVivo que entra (también las copias y los hijos): sus rebotes llevan ᚢ.
func _al_entrar(n: Node) -> void:
	if n is HechizoVivo and not (n as HechizoVivo).rebotado.is_connected(_al_rebotar):
		(n as HechizoVivo).rebotado.connect(_al_rebotar)


func _al_rebotar(pos: Vector3, normal: Vector3) -> void:
	if activo and mundo != null and is_instance_valid(mundo):
		rebote(mundo, pos, normal)


## Una vez por disparo (el Lanzador lo emite con el primer HechizoVivo; las demás copias las crea `HechizoVivo.crear` por dentro).
func _al_crear(vivo: HechizoVivo) -> void:
	if not activo or vivo == null or vivo.h == null or vivo.h.profundidad != 0 or not vivo.h.proyectil or mundo == null:
		return
	var h: Hechizo = vivo.h
	var n: int = HechizoVivo.copias_de_proyectil(h)
	if n <= 1 and not h.rafaga:
		return
	var base: Vector3 = lz.ultimo_disparo.get("dir", Vector3.ZERO) as Vector3 if lz != null else Vector3.ZERO
	if base.length() < 0.01:
		base = Vector3(vivo.v.x, 0.0, vivo.v.z)
	var mano: Vector3 = vivo.p
	var dirs: Array = []
	var desvios: Array = []
	if h.rafaga:
		dirs = [base]                                  # ᚠ en ráfaga: salen en fila por la misma línea
	else:
		for i in range(n):
			var s: Dictionary = HechizoVivo.salida_de_copia(h, i, n, base)      # las copias salen PARALELAS, separadas a un lado (`desvio`), no en ángulo
			dirs.append(s["dir"])
			desvios.append(s["desvio"])
		mano -= desvios[0] as Vector3                  # el que avisa es la copia 0, que ya nace en su desvío: la mano es su origen menos él
	copias(mundo, mano, dirs, h.rafaga, desvios)


# ------------------------------------------------------------------------------------------------ dibujos (públicos: el lab y el prototipo los llaman)

## ᚠ: la runa sobre la mano y un trazo corto por cada copia (en ráfaga, tres trazos seguidos en la misma línea).
## `desvios` (opcional, uno por dirección): dónde sale cada copia respecto a la mano (`HechizoVivo.salida_de_copia`).
func copias(padre: Node, mano: Vector3, dirs: Array, en_fila: bool = false, desvios: Array = []) -> Node3D:
	var raiz: Node3D = _raiz(padre, "GlifoRepeticion", mano)
	_runa(raiz, "repeticion", Vector3(0.0, ALTO_SOBRE_MANO_M, 0.0))
	var trazos: Array = []                         # [dirección, desde (m), largo (×), desvío]
	if en_fila:
		var d: Vector3 = _plano(dirs[0] if not dirs.is_empty() else Vector3.RIGHT)
		for k in range(3):
			trazos.append([d, 0.35 + float(k) * 0.45, 0.6, Vector3.ZERO])
	else:
		for i in range(dirs.size()):
			var dv: Vector3 = desvios[i] as Vector3 if i < desvios.size() else Vector3.ZERO
			trazos.append([_plano(dirs[i] as Vector3), 0.35, 1.0, Vector3(dv.x, 0.0, dv.z)])
	for t in trazos:
		_trazo(raiz, t[0] as Vector3, float(t[1]), LARGO_TRAZO_M * float(t[2]), t[3] as Vector3)
	_animar(raiz)
	cuenta["repeticion"] = int(cuenta["repeticion"]) + 1
	return raiz


## ᚢ: la runa en el punto del rebote y un aro plano contra lo que rebotó.
func rebote(padre: Node, pos: Vector3, normal: Vector3) -> Node3D:
	var raiz: Node3D = _raiz(padre, "GlifoRebote", pos)
	_runa(raiz, "rebote", Vector3(0.0, 0.35, 0.0))
	var aro: MeshInstance3D = _aro(raiz, LADO_ARO_M)
	var n: Vector3 = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	aro.basis = _base_con_y(n)
	_animar(raiz)
	cuenta["rebote"] = int(cuenta["rebote"]) + 1
	return raiz


## El hijo nace: un aro que se CIERRA sobre el punto (se lee «aquí se ata») y, al cerrarse, la runa del sello del hijo.
func hijo_nace(padre: Node, pos: Vector3, elemento: String) -> Node3D:
	var raiz: Node3D = _raiz(padre, "GlifoHijo", pos)
	var aro: MeshInstance3D = _aro(raiz, LADO_ARO_M * 1.8)
	aro.position.y = 0.05
	var runa: MeshInstance3D = _runa(raiz, elemento, Vector3(0.0, 0.6, 0.0))
	runa.scale = Vector3.ONE * 0.01
	var tw: Tween = raiz.create_tween()
	tw.tween_property(aro, "scale", Vector3.ONE * 0.35, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(runa, "scale", Vector3.ONE, T_NACE_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(T_QUIETA_S)
	tw.tween_callback(_apagar.bind(raiz))
	cuenta["hijo"] = int(cuenta["hijo"]) + 1
	return raiz


# ------------------------------------------------------------------------------------------------ piezas

static func textura(glifo: String) -> Texture2D:
	if not _texturas.has(glifo):
		var ruta: String = RUTA_RUNA % glifo
		_texturas[glifo] = load(ruta) if ResourceLoader.exists(ruta) else null
	return _texturas[glifo]


func _raiz(padre: Node, nombre: String, pos: Vector3) -> Node3D:
	var r := Node3D.new()
	r.name = nombre
	padre.add_child(r)
	r.global_position = pos
	return r


func _material(tex: Texture2D, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true                        # que se lea por encima del VFX del elemento
	m.render_priority = 10
	m.albedo_texture = tex
	m.albedo_color = COLOR_GLIFO
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


## La runa del glifo, de cara a la cámara. Sin PNG (un glifo sin dibujo), nada.
func _runa(raiz: Node3D, glifo: String, desplaza: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Runa_" + glifo
	var q := QuadMesh.new()
	q.size = Vector2(LADO_RUNA_M, LADO_RUNA_M)
	mi.mesh = q
	mi.material_override = _material(textura(glifo), true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = desplaza
	mi.visible = textura(glifo) != null
	raiz.add_child(mi)
	return mi


## Aro plano (en XZ del nodo).
func _aro(raiz: Node3D, lado: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Aro"
	var pm := PlaneMesh.new()
	pm.size = Vector2(lado, lado)
	mi.mesh = pm
	mi.material_override = _material(GlifoSueloVfx.textura_anillo(), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	return mi


## Un trazo plano y fino a la altura de la mano, de `desde` a `desde + largo` por `d`.
func _trazo(raiz: Node3D, d: Vector3, desde: float, largo: float, desvio: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Trazo%d" % raiz.get_child_count()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ANCHO_TRAZO_M, largo)
	mi.mesh = pm
	mi.material_override = _material(null, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	mi.basis = Basis(Vector3.UP, atan2(d.x, d.z))
	mi.position = desvio + d * (desde + largo * 0.5)


static func _plano(d: Vector3) -> Vector3:
	var p := Vector3(d.x, 0.0, d.z)
	return p.normalized() if p.length() > 0.001 else Vector3.RIGHT


## Una base cuyo eje Y es `n` (para tumbar un plano contra una pared).
static func _base_con_y(n: Vector3) -> Basis:
	var x: Vector3 = n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(n).normalized()
	return Basis(x, n, z)


## Nace (crece con un pequeño rebote), se queda un instante y se apaga.
func _animar(raiz: Node3D) -> void:
	raiz.scale = Vector3.ONE * 0.6
	var tw: Tween = raiz.create_tween()
	tw.tween_property(raiz, "scale", Vector3.ONE, T_NACE_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(T_QUIETA_S)
	tw.tween_callback(_apagar.bind(raiz))


func _apagar(raiz: Node3D) -> void:
	if not is_instance_valid(raiz):
		return
	var tw: Tween = raiz.create_tween().set_parallel(true)
	for c in raiz.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is StandardMaterial3D:
			var m: StandardMaterial3D = (c as MeshInstance3D).material_override
			tw.tween_property(m, "albedo_color:a", 0.0, T_APAGA_S)
	tw.tween_property(raiz, "scale", raiz.scale * 1.15, T_APAGA_S)
	tw.chain().tween_callback(raiz.queue_free)

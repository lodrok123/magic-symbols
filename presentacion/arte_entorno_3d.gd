extends Node3D
## ArteEntorno3D · lo que se VE de los estados del suelo y de la naturaleza con el arte que entregó Pablo el 6/11/2026 (R1-R3 ya tenían los datos; faltaba el dibujo).
##
## Escucha a `EstadosSuelo3D` (`cambio`, `material_cambiado`) y dibuja, sin decidir nada:
##   · ESCOMBRO (y la costra del magma): 2-3 trozos pequeños de `escombro_terreno.glb` (Meshy «Rocky Dirt Terrain», un terreno con guijarros de 1 u de lado) por casilla, con giro y sitio
##     ALEATORIOS pero con SEMILLA por casilla (la misma casilla sale siempre igual), que se quitan cuando el estado se va. Si el escombro es COSTRA de magma (`EstadosSuelo3D.es_costra`)
##     los trozos son las piedras de magma (`piedra_est_magma_N`, las que ya existían: albedo y emisivo de `rocas_magma_*`). El suelo de debajo lo pinta el shader del terreno (`prueba_test2.gd`).
##   · VAPOR: un solo emisor por casilla con el estado `vapor` (hoja `art/fx/vapor.png`, 6×4, bucle), tinte blanco-azulado; muere al caducar.
##   · BROTE de naturaleza: al germinar una casilla (`poner_material(c, "hierba")`) nace una plantita (`art/fx/naturaleza.png`, 6×3, 18 fotogramas, NO hace bucle: nace y se queda en el último).
## Estáticos reutilizables: `vapor_emisor` (también lo usan `Vfx3D.vapor` y `VfxPuzle3D.vapor`: el vapor de los cruces) y `brote` (el adorno del enraizado, `ReaccionesVfx3D`).
## Sin class_name a propósito (Godot cerrado: un class_name nuevo pide reimportar); se usa con `preload`.
##
## TOPES: `MAX_ROCAS_ESCOMBRO` nodos de roca vivos a la vez (al pasarse se retira la casilla más antigua), un pool de nodos por modelo (no se crea nada nuevo mientras haya libres)
## y `MAX_BROTES` plantas. El vapor lo topa `EstadosSuelo3D.MAX_CASILLAS_VIVAS` (20 casillas = 20 emisores).

const HOJA_VAPOR: String = "res://art/fx/vapor.png"              ## 768×512 = 6×4 fotogramas de 128, alfa de serie, hace bucle
const HOJA_NATURALEZA: String = "res://art/fx/naturaleza.png"    ## 768×384 = 6×3 fotogramas de 128, alfa de serie, NO hace bucle
const VAPOR_COLUMNAS: int = 6
const VAPOR_FILAS: int = 4
const NATURALEZA_COLUMNAS: int = 6
const NATURALEZA_FILAS: int = 3
const NATURALEZA_FOTOGRAMAS: int = 18
const VAPOR_VIDA_S: float = 2.4
const VAPOR_TINTE: Color = Color(0.86, 0.93, 1.0, 0.6)           ## blanco-azulado leve: el humo de lo quemado es gris/negro, éste no

const RUTA_TERRENO: String = "res://arte/meshy/piezas/escombro_terreno.glb"
const RUTA_MAGMA: String = "res://arte/meshy/piezas/piedra_est_magma_%d.glb"
const VARIANTES_MAGMA: int = 5

const MAX_ROCAS_ESCOMBRO: int = 40       ## nodos de roca vivos a la vez (sumando todas las casillas)
const TROZOS_MIN: int = 2                ## trozos por casilla: 2 o 3
const TROZOS_MAX: int = 3
const LADO_MIN: float = 0.25             ## lado de cada trozo (u): el modelo se normaliza a su huella y se escala a esto
const LADO_MAX: float = 0.35
const DISPERSION: float = 0.7            ## u a cada lado del centro de la casilla (la casilla mide 2,3)
const MAX_BROTES: int = 24
const BROTE_S: float = 1.4               ## lo que tarda en nacer (los 18 fotogramas)
const BROTE_TAM: float = 1.5             ## u de lado del dibujo de la planta (un fotograma = 128 px)

var _estados: EstadosSuelo3D = null
var _rocas: Dictionary = {}              ## Vector2i -> Array[Node3D] (en orden de llegada: la primera es la más antigua)
var _libres: Dictionary = {}             ## ruta -> Array[Node3D]: el pool
var _huellas: Dictionary = {}            ## ruta -> float: lado de la huella del modelo sin escalar
var _vapor: Dictionary = {}              ## Vector2i -> GPUParticles3D
var _brotes: Dictionary = {}             ## Vector2i -> Sprite3D
var _vivas: int = 0
var _reloj: float = 0.0


## Se engancha al dueño del estado del suelo. Idempotente.
func conectar(estados: EstadosSuelo3D) -> void:
	if _estados == estados:
		return
	_estados = estados
	if not _estados.cambio.is_connected(_al_cambiar):
		_estados.cambio.connect(_al_cambiar)
	if not _estados.material_cambiado.is_connected(_al_material):
		_estados.material_cambiado.connect(_al_material)


## Nodos de roca vivos ahora (los del pool que esperan no cuentan).
func rocas_vivas() -> int:
	return _vivas


func rocas_en(c: Vector2i) -> int:
	return (_rocas.get(c, []) as Array).size()


func vapores_vivos() -> int:
	return _vapor.size()


func brotes_vivos() -> int:
	return _brotes.size()


## Cada medio segundo comprueba que lo dibujado sigue siendo cierto: `EstadosSuelo3D.limpiar()` (cambio de mapa, cargar partida) vacía los estados SIN avisar por `cambio`.
func _process(delta: float) -> void:
	_reloj += delta
	if _reloj < 0.5 or _estados == null:
		return
	_reloj = 0.0
	for c in _rocas.keys():
		if not _estados.tiene(c as Vector2i, EstadosSuelo3D.ESCOMBRO):
			_quitar_escombro(c as Vector2i)
	for c in _vapor.keys():
		if not _estados.tiene(c as Vector2i, EstadosSuelo3D.VAPOR):
			_quitar_vapor(c as Vector2i)


func _al_cambiar(c: Vector2i, estado: String, si: bool) -> void:
	match estado:
		EstadosSuelo3D.ESCOMBRO:
			if si:
				_poner_escombro(c)
			else:
				_quitar_escombro(c)
		EstadosSuelo3D.VAPOR:
			if si:
				_poner_vapor(c)
			else:
				_quitar_vapor(c)


func _al_material(c: Vector2i, material: String) -> void:
	if material == "hierba":
		_poner_brote(c)


# --- Escombro -------------------------------------------------------------------------------------------------------------------------------------------------------

func _centro(c: Vector2i) -> Vector3:
	var y: float = Terreno3D.alto_agua if Terreno3D.es_agua(c) else Terreno3D.alto_suelo
	return Lanzador3D.centro_de(c, y)


## Semilla por casilla: la misma casilla da siempre los mismos trozos (determinista; también para la prueba y para dos jugadores que miren lo mismo).
static func semilla_de(c: Vector2i) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ 0x5bd1e995)


func _poner_escombro(c: Vector2i) -> void:
	if _rocas.has(c):
		return                                            # ya dibujado (renovar el reloj no avisa, pero por si acaso)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla_de(c)
	var n: int = rng.randi_range(TROZOS_MIN, TROZOS_MAX)
	while _vivas + n > MAX_ROCAS_ESCOMBRO and not _rocas.is_empty():
		_quitar_escombro(_rocas.keys()[0] as Vector2i)    # la casilla más antigua cede su sitio (el diccionario conserva el orden de llegada)
	var costra: bool = _estados != null and _estados.es_costra(c)
	var centro: Vector3 = _centro(c)
	var lista: Array = []
	for i in range(n):
		var ruta: String = (RUTA_MAGMA % rng.randi_range(0, VARIANTES_MAGMA - 1)) if costra else RUTA_TERRENO
		var roca: Node3D = _sacar(ruta)
		var lado: float = rng.randf_range(LADO_MIN, LADO_MAX)
		var huella: float = maxf(float(_huellas.get(ruta, 1.0)), 0.001)
		roca.scale = Vector3.ONE * (lado / huella)
		roca.rotation = Vector3(0.0, rng.randf() * TAU, 0.0)
		roca.position = centro + Vector3(rng.randf_range(-DISPERSION, DISPERSION), 0.02, rng.randf_range(-DISPERSION, DISPERSION))
		roca.visible = true
		lista.append(roca)
	_rocas[c] = lista
	_vivas += lista.size()


func _quitar_escombro(c: Vector2i) -> void:
	if not _rocas.has(c):
		return
	for r in _rocas[c]:
		var roca: Node3D = r
		roca.visible = false
		var ruta: String = String(roca.get_meta("ruta", ""))
		if not _libres.has(ruta):
			_libres[ruta] = []
		(_libres[ruta] as Array).append(roca)             # vuelve al pool: la próxima vez no se instancia nada
		_vivas -= 1
	_rocas.erase(c)


## Un nodo de roca del modelo `ruta`: del pool si hay, si no uno nuevo (la primera vez que se pide el modelo mide su huella).
func _sacar(ruta: String) -> Node3D:
	var libres: Array = _libres.get(ruta, [])
	if not libres.is_empty():
		return libres.pop_back() as Node3D
	var ps: PackedScene = load(ruta) as PackedScene
	var nodo: Node3D = null
	if ps != null:
		nodo = ps.instantiate() as Node3D
	if nodo == null:
		push_warning("ArteEntorno3D: no se pudo cargar «%s»; se pone un cubito de relleno" % ruta)
		nodo = MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(1.0, 0.5, 1.0)
		(nodo as MeshInstance3D).mesh = caja
	if not _huellas.has(ruta):
		_huellas[ruta] = _huella(nodo)
	nodo.set_meta("ruta", ruta)
	_sin_sombra(nodo)
	add_child(nodo)
	return nodo


## Lado de la huella (x/z) del mayor mesh del modelo, sin escalar.
static func _huella(n: Node) -> float:
	var m: float = 0.0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var s: Vector3 = (n as MeshInstance3D).mesh.get_aabb().size
		m = maxf(s.x, s.z)
	for h in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = h
		if mi.mesh != null:
			var s2: Vector3 = mi.mesh.get_aabb().size
			m = maxf(m, maxf(s2.x, s2.z))
	return m


static func _sin_sombra(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # trozos de 0,3 u: la sombra no se lee y cuesta
	for h in n.get_children():
		_sin_sombra(h)


# --- Vapor ----------------------------------------------------------------------------------------------------------------------------------------------------------

func _poner_vapor(c: Vector2i) -> void:
	if _vapor.has(c):
		return                                            # un solo emisor por casilla
	var gp: GPUParticles3D = vapor_emisor(self, _centro(c) + Vector3(0.0, 0.15, 0.0), 1.2, true, 0.55)
	_vapor[c] = gp


## Apaga el emisor (lo que ya salió se disipa solo) y lo libera cuando acaba; deja de contar al instante.
func _quitar_vapor(c: Vector2i) -> void:
	var gp: GPUParticles3D = _vapor.get(c) as GPUParticles3D
	_vapor.erase(c)
	if gp == null or not is_instance_valid(gp):
		return
	gp.emitting = false
	if gp.is_inside_tree():
		get_tree().create_timer(VAPOR_VIDA_S + 0.3, false).timeout.connect(gp.queue_free)
	else:
		gp.queue_free()


## EL vapor del juego: bocanadas del flipbook `vapor.png` (24 fotogramas en bucle) que suben y se abren, con un tinte blanco-azulado. De un disparo, o `continuo` (devuelve el emisor:
## `emitting = false` lo apaga). `esc` escala el tamaño; `radio` es lo que se abre la zona de la que salen (u, antes de `esc`).
static func vapor_emisor(padre: Node3D, pos: Vector3, esc: float = 1.0, continuo: bool = false, radio: float = 0.25) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = 6 if continuo else 8
	gp.lifetime = VAPOR_VIDA_S
	gp.one_shot = not continuo
	gp.explosiveness = 0.0 if continuo else 0.8
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 8, 10))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 22.0
	pm.initial_velocity_min = 0.25 * esc
	pm.initial_velocity_max = 0.6 * esc
	pm.gravity = Vector3(0.0, 0.25, 0.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radio * esc
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.anim_speed_min = 1.0                               # un ciclo completo de la hoja por vida de partícula
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0                              # cada bocanada empieza en un fotograma distinto: no respiran todas a la vez
	pm.anim_offset_max = 1.0
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.5))
	curva.add_point(Vector2(1.0, 1.3))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var g := Gradient.new()                               # nace y muere transparente: nada aparece ni desaparece de golpe
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	g.colors = PackedColorArray([Color(VAPOR_TINTE.r, VAPOR_TINTE.g, VAPOR_TINTE.b, 0.0), VAPOR_TINTE,
		Color(VAPOR_TINTE.r, VAPOR_TINTE.g, VAPOR_TINTE.b, VAPOR_TINTE.a * 0.7), Color(VAPOR_TINTE.r, VAPOR_TINTE.g, VAPOR_TINTE.b, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.particles_anim_h_frames = VAPOR_COLUMNAS
	sm.particles_anim_v_frames = VAPOR_FILAS
	sm.particles_anim_loop = true
	var tex: Texture2D = load(HOJA_VAPOR) as Texture2D
	if tex != null:
		sm.albedo_texture = tex
	else:
		sm.albedo_color = Color(1, 1, 1, 0)               # sin hoja no se pinta un cuadrado blanco
		push_warning("ArteEntorno3D: falta %s" % HOJA_VAPOR)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.3 * esc
	q.orientation = PlaneMesh.FACE_Z
	q.material = sm
	gp.draw_pass_1 = q
	gp.position = pos
	padre.add_child(gp)
	gp.emitting = true
	if not continuo and padre.is_inside_tree():
		padre.get_tree().create_timer(VAPOR_VIDA_S + 0.4, false).timeout.connect(gp.queue_free)
	return gp


# --- Brote de naturaleza ---------------------------------------------------------------------------------------------------------------------------------------------

func _poner_brote(c: Vector2i) -> void:
	if _brotes.has(c):
		return
	while _brotes.size() >= MAX_BROTES:
		var vieja: Vector2i = _brotes.keys()[0]
		var s: Sprite3D = _brotes[vieja] as Sprite3D
		_brotes.erase(vieja)
		if s != null and is_instance_valid(s):
			s.queue_free()
	_brotes[c] = brote(self, _centro(c), 1.0, 0.0)


## Una plantita que NACE (los 18 fotogramas de `naturaleza.png`, sin bucle) y se queda en el último. `dura` > 0: se libera pasado ese tiempo (el adorno del enraizado); 0 = se queda
## hasta que el que la puso la quite. Devuelve el Sprite3D.
static func brote(padre: Node3D, pos: Vector3, esc: float = 1.0, dura: float = 0.0) -> Sprite3D:
	var s := Sprite3D.new()
	var tex: Texture2D = load(HOJA_NATURALEZA) as Texture2D
	s.texture = tex
	s.hframes = NATURALEZA_COLUMNAS
	s.vframes = NATURALEZA_FILAS
	s.frame = 0
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y        # gira hacia la cámara pero no se tumba con ella: la planta crece de pie
	s.shaded = false
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.double_sided = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var px: float = BROTE_TAM * esc / 128.0               # un fotograma son 128 px
	s.pixel_size = px
	s.offset = Vector2(0.0, 64.0)                         # el pie del dibujo en el punto (el sprite se centra: se sube media altura)
	s.position = pos
	padre.add_child(s)
	if s.is_inside_tree():
		var tw: Tween = s.create_tween()
		tw.tween_method(func(f: float) -> void: s.frame = clampi(int(f), 0, NATURALEZA_FOTOGRAMAS - 1), 0.0, float(NATURALEZA_FOTOGRAMAS), BROTE_S)
		if dura > 0.0:
			tw.tween_interval(maxf(dura - BROTE_S, 0.0))
			tw.tween_callback(s.queue_free)
	else:
		s.frame = NATURALEZA_FOTOGRAMAS - 1               # sin árbol no hay animación que ver: ya nacida
	return s

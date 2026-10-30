extends Node3D

## CATÁLOGO DE ASSETS de la prueba pastel: todas las piezas de las bibliotecas de Meshy (bosque, objetos,
## magia) en fila, a la medida con la que salen en la maqueta de Test 2, con su nombre encima; y los
## personajes chibi uno al lado de otro, a la misma altura, para comparar proporciones.
## Sirve para revisar de un vistazo qué pieza está mal (rota, mezclada, mal medida, mal orientada).
##
## Teclas: 1 piezas · 2 personajes · P sueltas · O objetos 2D · Q/E girar todo · R/F inclinación · +/- zoom · flechas mover · L luz
##         (personajes) 3/4 cabeza · 5/6 piernas · 7/8 torso de los que tienen proporciones (chibi_elf)
##                      0 proporciones originales / ajustadas · A siguiente animación
##
## OBJETOS 2D (tecla O, 30/10): el MOSTRADOR de los iconos de objeto de `presentacion/ui/laminas/objeto_<id>.png` (los 27 recortados de
## `arte/laminas/objetos_lamina_01.webp` y los de antes), cada uno como una TARJETA de pie con RELIEVE: el icono delante y, detrás, CAPAS_RELIEVE
## siluetas oscuras desplazadas hacia atrás (una extrusión) más un contorno; así se ve si el dibujo aguanta como pieza con volumen y no solo como
## estampa plana. Son RECOGIBLES: un clic en la tarjeta la mete en la bolsa (`Estado.agregar`, con su aviso) y con I se abre la `BolsaUI` de verdad,
## para ver el icono en su hueco con marco de calidad y número. X vacía la bolsa. La capacidad se sube a los 20 huecos para que quepan muchos.

const BIBLIOTECAS: Array = ["res://arte/meshy/bosque.glb", "res://arte/meshy/objetos.glb",
	"res://arte/meshy/magia.glb"]
const PERSONAJES: Array = ["chibi_elf_v2", "chibi_elf", "elfo_base", "bookseller_chibi", "goblin_warrior_chibi", "goblin_espadachin", "goblin_base", "marimanta","goblin_asesino", "jugadora_base", "chibi_test"]
## Vista de piezas SUELTAS (tecla P): las `.glb` de meshy/piezas (las que gana la maqueta por id) y las de
## meshy/comparar (versiones a otra calidad, p. ej. `arbol_redondo_4k`, para verlas junto a la actual).
const CARPETAS_SUELTAS: Array = ["res://arte/meshy/piezas/", "res://arte/meshy/comparar/"]
const MAX_BYTES_SUELTA: int = 3000000   ## las bibliotecas grandes de piezas/ (bosque_*, campamento...) pesan más
const POR_FILA: int = 6
const HUECO: float = 3.4
const RUTA_ICONOS: String = "res://presentacion/ui/laminas/"
const LADO_TARJETA: float = 1.8          ## u: lado del icono de pie
const CAPAS_RELIEVE: int = 10            ## siluetas oscuras detrás del icono
const GROSOR_CAPA: float = 0.022         ## u entre capa y capa (relieve total ≈ 0,22 u)
const CONTORNO: float = 0.025            ## u: cuánto asoma la silueta del contorno por los bordes
const COLOR_RELIEVE_FRENTE: Color = Color(0.36, 0.27, 0.2)
const COLOR_RELIEVE_FONDO: Color = Color(0.14, 0.1, 0.08)
const POR_FILA_OBJETOS: int = 8
const HUECO_OBJETOS: float = 2.6
const FONDO_OBJETOS: float = 1.9            ## las filas van a HUECO_OBJETOS × esto de fondo: el rótulo va en el suelo, delante de la tarjeta

@export var modo: int = 0             ## 0 piezas, 1 personajes, 2 sueltas, 3 objetos 2D
@export var uniforme: bool = true     ## piezas todas al mismo tamaño (para ver la forma) o a su medida de la maqueta
@export var solo_biblioteca: String = ""  ## "bosque", "objetos" o "magia" para ver solo una
@export var solo_pieza: String = ""       ## id de una pieza para verla sola
@export var giro: float = 25.0        ## grados alrededor de la vertical
@export var inclinacion: float = 30.0 ## grados sobre el horizonte de la cámara
@export var zoom: float = 0.0         ## 0 = automático
@export var foco: Vector3 = Vector3.INF
@export var limpio: bool = false       ## sin textos ni rayas (para sacar imágenes de referencia)

var _raiz: Node3D = null
var _camara: Camera3D = null
var _hud: Label = null
var _centro: Vector3 = Vector3.ZERO
var _tam: float = 10.0
var _luz_suave: bool = true
var _originales: bool = false
var _anim: int = 0
var _bolsa: BolsaUI = null
var _cogidos: int = 0


## Pone a todos los personajes en una animación (idle, walk, run...).
func animar(nombre: String) -> void:
	for h in _raiz.get_children():
		if h is Pj3D:
			(h as Pj3D).jugar(nombre)


## Línea del HUD con las proporciones de los personajes ajustables.
func _texto_proporciones() -> void:
	var t: PackedStringArray = PackedStringArray()
	for h in _raiz.get_children():
		if h is Pj3D and (h as Pj3D).proporcion != null:
			var pr: ProporcionChibi = (h as Pj3D).proporcion
			t.append("%s: cabeza %.2f · piernas %.2f · torso %.2f" % [(h as Pj3D).id, pr.cabeza, pr.piernas, pr.torso])
	var lineas: PackedStringArray = _hud.text.split("\n")
	_hud.text = lineas[0] + "\n" + lineas[1] + "\n" + "  ".join(t)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.94, 1.0)
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sol.light_energy = 0.75
	sol.shadow_enabled = true
	add_child(sol)

	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200.0, 200.0)
	suelo.mesh = plano
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.78, 0.88, 0.72)
	ms.roughness = 1.0
	suelo.material_override = ms
	add_child(suelo)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.far = 400.0
	add_child(_camara)

	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 8.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_montar()


func _montar() -> void:
	if _raiz != null:
		_raiz.free()
	_raiz = Node3D.new()
	add_child(_raiz)
	if modo == 0:
		_montar_piezas()
	elif modo == 2:
		_montar_sueltas()
	elif modo == 3:
		_montar_objetos()
	else:
		_montar_personajes()
	if foco != Vector3.INF:
		_centro = foco
	if limpio:
		_hud.visible = false
		for h in _raiz.get_children():
			if h is Label3D or (h is MeshInstance3D and (h as MeshInstance3D).mesh is BoxMesh):
				(h as Node3D).visible = false
	if zoom > 0.0:
		_tam = zoom
	_colocar_camara()


func _montar_piezas() -> void:
	var medidas: Dictionary = _medidas_maqueta()
	var i: int = 0
	var avisos: PackedStringArray = PackedStringArray()
	for ruta in BIBLIOTECAS:
		var r: String = String(ruta)
		if solo_biblioteca != "" and not r.contains(solo_biblioteca):
			continue
		if not ResourceLoader.exists(r):
			avisos.append("falta " + r.get_file())
			continue
		var lib: Node3D = (load(r) as PackedScene).instantiate() as Node3D
		for pieza in _piezas_de(lib):
			var id: String = String(pieza.name)
			if solo_pieza != "" and id != solo_pieza:
				continue
			var copia: Node3D = pieza.duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			var caja: AABB = _caja(copia, Transform3D.IDENTITY)
			var cont := Node3D.new()
			cont.add_child(copia)
			var alto: float = float(medidas.get(id, 1.0))
			var f: float = alto / maxf(caja.size.y, 0.0001)
			if _medidas_ancho().has(id):
				f = float(_medidas_ancho()[id]) / maxf(caja.size.x, caja.size.z)
			if uniforme:
				alto = 2.2 * caja.size.y / maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
				f = 2.2 / maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
			copia.scale *= f
			copia.position = -Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5) * f
			cont.position = Vector3(float(i % POR_FILA) * HUECO, 0.0, float(floori(float(i) / float(POR_FILA))) * HUECO * 1.1)
			cont.rotation_degrees.y = giro
			_raiz.add_child(cont)
			var l := Label3D.new()
			l.text = "%s  (%d tri)" % [id, _triangulos(copia)]
			l.font_size = 40
			l.outline_size = 10
			l.pixel_size = 0.009
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.position = cont.position + Vector3(0.0, (2.5 if uniforme else maxf(alto, 0.4) + 0.35), 0.0)
			_raiz.add_child(l)
			i += 1
		lib.free()
	var filas: int = int(ceil(float(i) / float(POR_FILA)))
	_centro = Vector3(float(POR_FILA - 1) * HUECO * 0.5, 1.0, float(filas - 1) * HUECO * 1.1 * 0.5)
	_tam = float(filas) * HUECO * 1.1 + 3.0
	_hud.text = "CATÁLOGO · %d piezas %s\n1 piezas · 2 personajes · Q/E girar · R/F inclinación · +/- zoom · flechas · L luz" % [i, " ".join(avisos)]


## Piezas sueltas (modo 2). Todas al mismo tamaño para comparar la forma; el rótulo lleva id, triángulos y KB.
## Por qué existe: el modo 0 solo carga las tres bibliotecas y no enseña lo que `Pieza3D` coge suelto por id.
func _montar_sueltas() -> void:
	var rutas: Array[String] = []
	for carpeta in CARPETAS_SUELTAS:
		var d: DirAccess = DirAccess.open(String(carpeta))
		if d == null:
			continue
		for f in d.get_files():
			var nombre: String = f.trim_suffix(".import")
			if nombre.ends_with(".glb") and not rutas.has(String(carpeta) + nombre):
				rutas.append(String(carpeta) + nombre)
	rutas.sort_custom(func(a: String, b: String) -> bool: return a.get_file() < b.get_file())
	var i: int = 0
	var saltadas: int = 0
	for r in rutas:
		var id: String = r.get_file().get_basename()
		if solo_pieza != "" and not id.begins_with(solo_pieza):
			continue
		var fa: FileAccess = FileAccess.open(r, FileAccess.READ)
		var kb: int = 0
		if fa != null:
			if fa.get_length() > MAX_BYTES_SUELTA:
				saltadas += 1
				continue
			kb = floori(fa.get_length() / 1024.0)
		if not ResourceLoader.exists(r):
			continue
		var lib: Node3D = (load(r) as PackedScene).instantiate() as Node3D
		var copia: Node3D = lib
		var caja: AABB = _caja(copia, Transform3D.IDENTITY)
		var lado: float = maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
		if lado < 0.0001:
			lib.free()
			continue
		var f: float = 2.2 / lado
		var cont := Node3D.new()
		cont.add_child(copia)
		copia.scale *= f
		copia.position = -Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5) * f
		cont.position = Vector3(float(i % POR_FILA) * HUECO, 0.0, float(floori(float(i) / float(POR_FILA))) * HUECO * 1.1)
		cont.rotation_degrees.y = giro
		_raiz.add_child(cont)
		var l := Label3D.new()
		l.text = "%s\n%d tri · %d KB" % [id, _triangulos(copia), kb]
		l.font_size = 40
		l.outline_size = 10
		l.pixel_size = 0.009
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = cont.position + Vector3(0.0, 2.7, 0.0)
		_raiz.add_child(l)
		i += 1
	var filas: int = maxi(1, int(ceil(float(i) / float(POR_FILA))))
	_centro = Vector3(float(POR_FILA - 1) * HUECO * 0.5, 1.0, float(filas - 1) * HUECO * 1.1 * 0.5)
	_tam = float(filas) * HUECO * 1.1 + 3.0
	_hud.text = "PIEZAS SUELTAS · %d (omitidas %d bibliotecas grandes)\n1 bibliotecas · 2 personajes · P sueltas · Q/E girar · R/F inclinación · +/- zoom · flechas" % [i, saltadas]


## Objetos 2D (modo 3): los iconos como tarjetas con relieve, en rejilla y recogibles con un clic (ver cabecera).
func _montar_objetos() -> void:
	if _bolsa == null:
		_bolsa = BolsaUI.new()
		add_child(_bolsa)
	Estado.i().capacidad = maxi(Estado.i().capacidad, 20)
	var ids: Array[String] = _iconos_objeto()
	var i: int = 0
	for id in ids:
		if solo_pieza != "" and not id.begins_with(solo_pieza):
			continue
		var tex: Texture2D = BolsaUI.tex("objeto_" + id)
		if tex == null:
			continue
		var cont := Node3D.new()
		cont.name = "objeto_" + id
		cont.position = Vector3(float(i % POR_FILA_OBJETOS) * HUECO_OBJETOS, 0.0, float(floori(float(i) / float(POR_FILA_OBJETOS))) * HUECO_OBJETOS * FONDO_OBJETOS)
		cont.rotation_degrees.y = giro
		_raiz.add_child(cont)
		var alto: float = LADO_TARJETA * 0.5 + 0.12
		# El relieve: siluetas oscuras de atrás hacia delante, cada una un poco más clara, y todas asoman por los bordes (contorno).
		for k in range(CAPAS_RELIEVE, 0, -1):
			var u: float = float(k - 1) / float(maxi(CAPAS_RELIEVE - 1, 1))
			var capa: Sprite3D = _tarjeta(tex, COLOR_RELIEVE_FONDO.lerp(COLOR_RELIEVE_FRENTE, 1.0 - u))
			capa.position = Vector3(0.0, alto, -float(k) * GROSOR_CAPA)
			var f: float = (LADO_TARJETA + CONTORNO * 2.0) / LADO_TARJETA
			capa.scale = Vector3(f, f, 1.0)
			cont.add_child(capa)
		var frente: Sprite3D = _tarjeta(tex, Color.WHITE)
		frente.position = Vector3(0.0, alto, 0.0)
		cont.add_child(frente)
		# La zona que atiende el clic.
		var area := Area3D.new()
		area.set_meta("objeto", id)
		var cs := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(LADO_TARJETA, LADO_TARJETA, float(CAPAS_RELIEVE) * GROSOR_CAPA + 0.05)
		cs.shape = caja
		cs.position = Vector3(0.0, alto, -float(CAPAS_RELIEVE) * GROSOR_CAPA * 0.5)
		area.add_child(cs)
		cont.add_child(area)
		var l := Label3D.new()
		l.text = "%s\n%s" % [id, String(BD.objeto(id).get("nombre", ""))]
		l.font_size = 30
		l.outline_size = 10
		l.pixel_size = 0.0065
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = cont.position + Vector3(0.0, 0.05, 1.35)   # en el suelo, delante de la tarjeta (no tapa la fila de atrás)
		_raiz.add_child(l)
		i += 1
	var filas: int = maxi(1, int(ceil(float(i) / float(POR_FILA_OBJETOS))))
	_centro = Vector3(float(POR_FILA_OBJETOS - 1) * HUECO_OBJETOS * 0.5, 0.9, float(filas - 1) * HUECO_OBJETOS * FONDO_OBJETOS * 0.5)
	_tam = float(filas) * HUECO_OBJETOS * FONDO_OBJETOS * 0.62 + 3.0
	_hud_objetos()


func _tarjeta(tex: Texture2D, color: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = LADO_TARJETA / float(maxi(tex.get_width(), 1))
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.alpha_scissor_threshold = 0.5
	s.shaded = true
	s.double_sided = true
	s.modulate = color
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return s


func _tarjetas() -> int:
	var n: int = 0
	for h in _raiz.get_children():
		if h is Node3D and h.name.begins_with("objeto_"):
			n += 1
	return n


func _hud_objetos(aviso: String = "") -> void:
	var e: Estado = Estado.i()
	var total: int = 0
	for k in e.items:
		total += int(e.items[k])
	_hud.text = "OBJETOS 2D · %d iconos · en la bolsa %d (%d ids de %d huecos) %s\nclic coge · I bolsa · X vaciar · 1 piezas · 2 personajes · P sueltas · Q/E girar · R/F inclinación · +/- zoom · flechas" % [_tarjetas(), total, e.items.size(), e.capacidad, aviso]


## Los `objeto_<id>.png` de la carpeta de láminas (en un exportado solo quedan los `.import`), ordenados por id.
func _iconos_objeto() -> Array[String]:
	var res: Array[String] = []
	var d: DirAccess = DirAccess.open(RUTA_ICONOS)
	if d == null:
		return res
	for f in d.get_files():
		var nombre: String = f.trim_suffix(".import")
		if nombre.begins_with("objeto_") and nombre.ends_with(".png"):
			var id: String = nombre.trim_prefix("objeto_").trim_suffix(".png")
			if not res.has(id):
				res.append(id)
	res.sort()
	return res


## Un clic sobre una tarjeta la coge: la mete en la bolsa con su aviso y la tarjeta da un botecito.
func _clic_objeto(pos: Vector2) -> void:
	var desde: Vector3 = _camara.project_ray_origin(pos)
	var dir: Vector3 = _camara.project_ray_normal(pos)
	var q := PhysicsRayQueryParameters3D.create(desde, desde + dir * 300.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit["collider"] as Node).has_meta("objeto"):
		return
	var area: Node3D = hit["collider"] as Node3D
	var id: String = String(area.get_meta("objeto"))
	var entra: int = Estado.i().agregar(id, 1)
	if entra <= 0:
		_hud_objetos("· LA BOLSA ESTÁ LLENA (X la vacía)")
		return
	_cogidos += 1
	if Sensacion3D.ACTIVA:
		Sfx.play(self, "logro_brillo")
	var cont: Node3D = area.get_parent() as Node3D
	var tw: Tween = create_tween()
	tw.tween_property(cont, "position:y", 0.25, 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cont, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)
	_hud_objetos("· cogido %s" % id)


## Las piezas son los hijos de la raíz de la biblioteca (o del primer nivel que tenga varios).
func _piezas_de(lib: Node3D) -> Array[Node3D]:
	var n: Node = lib
	while n.get_child_count() == 1 and not (n.get_child(0) is MeshInstance3D):
		n = n.get_child(0)
	var res: Array[Node3D] = []
	for h in n.get_children():
		if h is Node3D:
			res.append(h as Node3D)
	return res


func _montar_personajes() -> void:
	var x: float = 0.0
	for id in PERSONAJES:
		if not ResourceLoader.exists("res://arte/modelos/%s.glb" % Pj3D.glb_de(String(id))):
			continue
		var pj := Pj3D.new()
		pj.position = Vector3(x, 0.0, 0.0)
		_raiz.add_child(pj)
		pj.cargar(String(id))
		pj.set_alto(1.0)
		pj.rotation_degrees.y = giro
		var l := Label3D.new()
		l.text = String(id)
		l.font_size = 40
		l.outline_size = 10
		l.pixel_size = 0.0015
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(x, 1.12, 0.0)
		_raiz.add_child(l)
		# Rayas cada 1/6 del alto para medir cabezas.
		for k in range(7):
			var raya := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.9, 0.004, 0.004)
			raya.mesh = b
			raya.position = Vector3(x, float(k) / 6.0, -0.45)
			_raiz.add_child(raya)
		x += 1.3
	_centro = Vector3(x * 0.5 - 0.65, 0.55, 0.0)
	_tam = maxf(1.6, x / 1.7)
	_hud.text = "PERSONAJES a la misma altura (rayas cada 1/6)\n1 piezas · 2 personajes · Q/E girar · R/F inclinación · +/- zoom · 3/4 cabeza · 5/6 piernas · 7/8 torso · 0 original/ajustada · A animación"
	_texto_proporciones()


func _triangulos(n: Node) -> int:
	var t: int = 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in range(m.get_surface_count()):
			var arr: Array = m.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				t += floori((idx as PackedInt32Array).size() / 3.0)
			else:
				t += floori((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
	for h in n.get_children():
		t += _triangulos(h)
	return t


func _caja(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


## Las mismas medidas que la maqueta, para ver las piezas tal como salen allí.
func _medidas_maqueta() -> Dictionary:
	var s: Script = load("res://presentacion/prueba_test2.gd") as Script
	if s != null and s.get_script_constant_map().has("MEDIDA"):
		return s.get_script_constant_map()["MEDIDA"]
	return {}


func _medidas_ancho() -> Dictionary:
	var s: Script = load("res://presentacion/prueba_test2.gd") as Script
	if s != null and s.get_script_constant_map().has("MEDIDA_ANCHO"):
		return s.get_script_constant_map()["MEDIDA_ANCHO"]
	return {}


func _colocar_camara() -> void:
	_camara.size = _tam
	var e: float = deg_to_rad(inclinacion)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_camara.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _centro - dir * 60.0)


func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if v != Vector3.ZERO:
		_centro += v * delta * _tam * 0.6
		_colocar_camara()


func _unhandled_input(ev: InputEvent) -> void:
	if modo == 3 and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_clic_objeto((ev as InputEventMouseButton).position)
		return
	if not (ev is InputEventKey) or not (ev as InputEventKey).pressed:
		return
	match (ev as InputEventKey).keycode:
		KEY_O:
			modo = 3
			_montar()
		KEY_X:
			if modo == 3:
				Estado.i().items.clear()
				Estado.i().cambiado.emit()
				_hud_objetos()
		KEY_1:
			modo = 0
			_montar()
		KEY_2:
			modo = 1
			_montar()
		KEY_P:
			modo = 2
			_montar()
		KEY_Q, KEY_E:
			giro += 30.0 if (ev as InputEventKey).keycode == KEY_E else -30.0
			for h in _raiz.get_children():
				if h is Pj3D or (h is Node3D and not (h is Label3D) and not (h is MeshInstance3D)):
					(h as Node3D).rotation_degrees.y = giro
		KEY_R:
			inclinacion = clampf(inclinacion + 5.0, 0.0, 90.0)
			_colocar_camara()
		KEY_F:
			inclinacion = clampf(inclinacion - 5.0, 0.0, 90.0)
			_colocar_camara()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_tam *= 0.85
			_colocar_camara()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_tam /= 0.85
			_colocar_camara()
		KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			var k: int = (ev as InputEventKey).keycode
			var d: float = 0.03 if k == KEY_4 or k == KEY_6 or k == KEY_8 else -0.03
			for h in _raiz.get_children():
				if h is Pj3D and (h as Pj3D).proporcion != null:
					var pr: ProporcionChibi = (h as Pj3D).proporcion
					var c: float = pr.cabeza + (d if k == KEY_3 or k == KEY_4 else 0.0)
					var pi: float = pr.piernas + (d if k == KEY_5 or k == KEY_6 else 0.0)
					var t: float = pr.torso + (d if k == KEY_7 or k == KEY_8 else 0.0)
					(h as Pj3D).set_proporcion(c, pi, t)
			_texto_proporciones()
		KEY_0:
			_originales = not _originales
			for h in _raiz.get_children():
				if h is Pj3D and (h as Pj3D).proporcion != null:
					var pj: Pj3D = h as Pj3D
					var p: Array = [1.0, 1.0, 1.0] if _originales else Pj3D.PROPORCIONES.get(pj.id, [1.0, 1.0, 1.0])
					pj.set_proporcion(float(p[0]), float(p[1]), float(p[2]))
			_texto_proporciones()
		KEY_A:
			_anim += 1
			for h in _raiz.get_children():
				if h is Pj3D:
					var lista: Array = ["idle", "walk", "run"]
					(h as Pj3D).jugar(String(lista[_anim % lista.size()]))
		KEY_L:
			_luz_suave = not _luz_suave
			for h in _raiz.get_children():
				if h is Pj3D:
					(h as Pj3D).set_modo_luz(1 if _luz_suave else 0)

class_name TrampaPared3D
extends Area3D

## TRAMPA DE PARED (5/11/2026; docs/TRAMPAS_PARED_2026-11-05.md). Una pieza pegada a un muro que LANZA UN HECHIZO REAL de forma recurrente: el mismo `Hechizo` / `HechizoVivo` que lanza la jugadora (por eso el
## agua lo apaga, el viento lo desvía, enciende setos, cuerdas y barriles, y daña a los enemigos con las vías de siempre). Es la clase BASE: la cabeza de dragón (`TrampaDragon3D`, un chorro continuo) y el
## mascarón de flechas (`TrampaFlechas3D`, un disparo cada tanto) solo ponen el ciclo y el dibujo.
##
## DÓNDE ESTÁ. `celda` es la casilla del MURO en el que va metida (una `#`); `mira` (n|e|s|o) es hacia dónde da: la casilla de delante es donde sale lo que lanza. El nodo se coloca en la cara del muro (centro
## de la casilla + media casilla hacia `mira`), a ras del suelo de la casilla de delante, con su +Z local apuntando hacia fuera del muro. No bloquea nada (es un adorno con boca): quien se pega a ella la atraviesa.
##
## QUÉ LANZA. `lanzar_hechizo_vivo(hechizo, origen, dir)` = `HechizoVivo.crear` desde la boca, con el `Lanzador3D` de la jugadora (grupo `spellcaster`): sin tinta, sin recarga, sin la animación de la jugadora, pero
## con TODO lo demás (sonido del hechizo, dibujo FuegoToy/AguaToy, reacciones, estados de suelo). A la JUGADORA la hiere la propia trampa con `Jugador3D.recibir_dano` (un haz no hiere al lanzador, y el proyectil con
## `golpea_lanzador` no la hiere en los primeros 0,25 s ni se para al herirla): respeta su invulnerabilidad de 0,7 s, la defensa, el bálsamo y la burbuja de barrera.
##
## CÓMO SE DESACTIVA. Un hechizo de AGUA o de HIELO que le da (`apaga_con_agua`, por defecto sí) la apaga `T_AGUA_S` s; `apagar(s)` / `encender()` son las acciones del mapa (`hace=<id>.apagar(8)`); un muro de tierra o
## una barrera delante de la boca para el chorro / la flecha como a cualquier hechizo. Mientras está apagada no avisa ni lanza.

signal apagada                     ## se desactivó (agua, hielo o una regla)
signal encendida_otra_vez          ## volvió a funcionar

const DIRS: Dictionary = {"n": Vector3(0.0, 0.0, -1.0), "e": Vector3(1.0, 0.0, 0.0), "s": Vector3(0.0, 0.0, 1.0), "o": Vector3(-1.0, 0.0, 0.0)}
const DIRS_CELDA: Dictionary = {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "o": Vector2i(-1, 0)}
const RUNAS: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "tierra": "earth", "viento": "wind"}
const T_AGUA_S: float = 8.0               ## s que dura apagada por agua o hielo
const ALTO_CUERPO_U: float = 1.8          ## alto de la caja con la que recibe hechizos (u)
const COLOR_PIEDRA: Color = Color(0.42, 0.38, 0.34)
const COLOR_PIEDRA_OSCURA: Color = Color(0.24, 0.21, 0.19)
const COLOR_BRASA: Color = Color(1.0, 0.36, 0.08)         ## rojo-naranja de la rampa de FuegoToy: nunca amarillo dominante
const COLOR_BRASA_VIVA: Color = Color(1.0, 0.5, 0.12)

var celda: Vector2i = Vector2i.ZERO         ## la casilla de MURO en la que va
var mira: String = "s"
var dir: Vector3 = Vector3(0.0, 0.0, 1.0)   ## hacia fuera del muro (mundo)
var elemento: String = "fuego"
var alcance: int = 5                        ## casillas de chorro / de vuelo de la flecha
var apaga_con_agua: bool = true
var activa: bool = true                     ## false = desactivada (agua o regla)
var desfase_s: float = 0.0
var cerca: float = 0.0                      ## casillas: 0 = siempre funciona; > 0 = DORMIDA (ciclo parado, sin lanzar) mientras la jugadora esté a más casillas que éstas de la casilla de delante

var lanzamientos: int = 0                   ## cuántos hechizos ha lanzado (las pruebas)
var _lanz: Lanzador3D = null
var _mundo: Node = null
var _apagada_t: float = 0.0                 ## s que le quedan apagada (> 0); con `_apagada_fija` no corre
var _apagada_fija: bool = false             ## apagada por una regla sin límite de tiempo
var _lanzando: bool = false                 ## true mientras lanza: no se golpea a sí misma con su propio chorro
var _luz: OmniLight3D = null
var _mats: Array[StandardMaterial3D] = []


## Coloca la trampa en la cara del muro `p_celda` que da a `p_mira`. Se llama ANTES de colgarla del árbol.
func preparar(p_celda: Vector2i, p_mira: String, p_elemento: String, p_alcance: int, p_mundo: Node = null) -> void:
	celda = p_celda
	mira = p_mira if DIRS.has(p_mira) else "s"
	dir = DIRS[mira]
	elemento = p_elemento if RUNAS.has(p_elemento) else ("" if p_elemento == "ninguno" else "fuego")
	alcance = p_alcance
	_mundo = p_mundo
	var delante: Vector2i = celda + celda_delante_offset()
	var suelo: float = Terreno3D.y_pies(delante) if Terreno3D.hay_mundo() and Terreno3D.en_mapa(delante) else Terreno3D.alto_suelo
	var centro: Vector3 = Terreno3D.centro_de(celda, suelo)
	position = centro + dir * (Terreno3D.casilla * 0.5)
	rotation.y = atan2(dir.x, dir.z)


func celda_delante_offset() -> Vector2i:
	return Vector2i(int(roundf(dir.x)), int(roundf(dir.z)))


func celda_delante() -> Vector2i:
	return celda + celda_delante_offset()


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	var prof: float = prof_cuerpo()
	caja.size = Vector3(1.6, ALTO_CUERPO_U, prof)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO_CUERPO_U * 0.5, prof * 0.5)
	add_child(forma)
	_luz = OmniLight3D.new()
	_luz.name = "Luz"
	_luz.light_color = COLOR_BRASA
	_luz.light_energy = 0.0
	_luz.omni_range = 4.5
	_luz.shadow_enabled = false
	_luz.position = boca_local()
	add_child(_luz)
	_construir()
	set_physics_process(true)


## Cuánto sale de la pared (u) la caja con la que recibe hechizos. TIENE que acabar ANTES de donde nace lo que lanza (la ranura, el origen del haz): un proyectil que nace dentro de un Area3D reactivo se
## golpea a sí mismo y se para ahí (medido en la primera versión: la flecha de fuego moría en la propia ranura).
func prof_cuerpo() -> float:
	return 0.9


## Lo que dibuja cada trampa (primitivas hasta que haya modelo). Los hijos lo rellenan.
func _construir() -> void:
	pass


## La boca en coordenadas locales (+Z hacia fuera del muro). Los hijos la fijan.
func boca_local() -> Vector3:
	return Vector3(0.0, 1.2, 1.0)


func boca_mundo() -> Vector3:
	return to_global(boca_local()) if is_inside_tree() else position + dir * boca_local().z + Vector3(0.0, boca_local().y, 0.0)


## Altura de la boca sobre el suelo de la casilla de delante (u).
func altura_boca_u() -> float:
	return boca_local().y


## El lanzador de la jugadora (grupo `spellcaster`). null si el nivel no tiene (la trampa no lanza nada).
func lanzador() -> Lanzador3D:
	if _lanz != null and is_instance_valid(_lanz):
		return _lanz
	if is_inside_tree():
		_lanz = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D
	return _lanz


func jugadora() -> Node3D:
	var l: Lanzador3D = lanzador()
	if l == null or l.jugador == null or not is_instance_valid(l.jugador):
		return null
	return l.jugador


## El hechizo de la trampa: `elemento` + los glifos que pida el hijo, con la boca como altura de salida. null si no se puede construir.
func construir_hechizo(glifos: Dictionary, cambios: Dictionary = {}) -> Hechizo:
	if not RUNAS.has(elemento):
		return null
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % RUNAS[elemento]) as RuneData
	if rune == null:
		return null
	var h: Hechizo = Hechizo.construir(rune, glifos)
	if h == null:
		return null
	var c: Dictionary = {"altura_salida": altura_boca_u() / Terreno3D.casilla}
	c.merge(cambios, true)
	return h.con(c)


## Lanza `hechizo` desde `origen` hacia `d` por el camino de la jugadora. Devuelve el HechizoVivo (null si no hay lanzador).
func lanzar_hechizo_vivo(hechizo: Hechizo, origen: Vector3, d: Vector3) -> HechizoVivo:
	var l: Lanzador3D = lanzador()
	if l == null or hechizo == null:
		return null
	_lanzando = true
	var hv: HechizoVivo = HechizoVivo.crear(hechizo, origen, d, l)
	_lanzando = false
	lanzamientos += 1
	return hv


## Hiere a la jugadora con la vía de siempre (invulnerabilidad, defensa, bálsamo y burbuja incluidos). true si la golpea.
func herir_jugadora(cantidad: float, desde: Vector3) -> bool:
	var j: Node3D = jugadora()
	if j == null or bool(j.get("muerto")) or not j.has_method("recibir_dano"):
		return false
	var vida: float = float(j.get("vida"))
	j.call("recibir_dano", cantidad, desde)
	return float(j.get("vida")) < vida


# ---------------------------------------------------------------------------------------------------------------------
#  Contrato con los hechizos (el agua la apaga)
# ---------------------------------------------------------------------------------------------------------------------

## 13/11 (tarea 11): por propiedades (`Materia.via`): la humedad que riega («agua») o el frío («hielo») la apagan. La naturaleza (humedad 0,5) no, como antes.
func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if _lanzando or not apaga_con_agua:
		return
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	if e == "agua" or e == "hielo":
		apagar(T_AGUA_S)


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	if _lanzando or not apaga_con_agua or not activa:
		return false
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	return e == "agua" or e == "hielo"


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return boca_mundo()


# ---------------------------------------------------------------------------------------------------------------------
#  Apagar / encender (reglas del mapa, agua, hielo)
# ---------------------------------------------------------------------------------------------------------------------

## Apaga la trampa `segundos` s (0 o menos = hasta `encender`).
func apagar(segundos: float = 0.0) -> void:
	var estaba: bool = activa
	activa = false
	if segundos > 0.0:
		_apagada_fija = false
		_apagada_t = maxf(_apagada_t, segundos)
	else:
		_apagada_fija = true
		_apagada_t = 0.0
	_al_apagar()
	if estaba:
		apagada.emit()


func encender() -> void:
	if activa:
		return
	activa = true
	_apagada_fija = false
	_apagada_t = 0.0
	_al_encender()
	encendida_otra_vez.emit()


## Los hijos paran lo suyo / lo reanudan.
func _al_apagar() -> void:
	pass


func _al_encender() -> void:
	pass


## ¿Está dormida por lejanía? (`cerca` > 0 y la jugadora a más de `cerca` casillas de la casilla de delante.) Sin jugadora no se duerme: las pruebas sin ella siguen funcionando.
func dormida() -> bool:
	if cerca <= 0.0:
		return false
	var j: Node3D = jugadora()
	if j == null:
		return false
	return Vector2(Terreno3D.celda_de(j.position) - celda_delante()).length() > cerca


## Cuenta atrás de la desactivación temporal. Los hijos la llaman al principio de su `_physics_process`; devuelve true si sigue apagada.
func _contar_apagada(delta: float) -> bool:
	if activa:
		return false
	if not _apagada_fija:
		_apagada_t -= delta
		if _apagada_t <= 0.0:
			encender()
			return false
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  Ayudas de dibujo
# ---------------------------------------------------------------------------------------------------------------------

func _material(color: Color, brillo: float = 0.0, sin_luz: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if brillo > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = brillo
	if sin_luz:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _caja(nombre: String, tam: Vector3, pos: Vector3, mat: Material, padre: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	(padre if padre != null else self).add_child(mi)
	return mi


func _esfera(nombre: String, radio: float, pos: Vector3, mat: Material, padre: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var s := SphereMesh.new()
	s.radius = radio
	s.height = radio * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	(padre if padre != null else self).add_child(mi)
	return mi


## MODELO DE MESHY CON ESQUELETO PUESTO AQUÍ (5/11/2026). Meshy entrega UNA malla sin rig, normalizada a 1 de alto; esto la cuelga en `Modelo` (escala `escala`, posición `pos`) con un Skeleton3D
## en cadena (`nombres[k]` con pivote `pivotes[k]`, en coordenadas del modelo, cada uno hijo del anterior) y los pesos que dé `pesos(p) -> Array` (uno por hueso, suman 1) para cada vértice.
## Devuelve el Skeleton3D (null si el modelo no está o no trae malla). Los hijos lo posan con set_bone_pose_rotation / _position.
func _modelo_con_huesos(ruta: String, escala: float, pos: Vector3, nombres: Array, pivotes: Array, pesos: Callable) -> Skeleton3D:
	if not ResourceLoader.exists(ruta):
		return null
	var escena: PackedScene = load(ruta) as PackedScene
	if escena == null:
		return null
	var suelto: Node = escena.instantiate()
	var fuente: MeshInstance3D = _primera_malla(suelto)
	if fuente == null or fuente.mesh == null:
		suelto.free()
		return null
	var a: Array = fuente.mesh.surface_get_arrays(0)
	var mat: Material = fuente.get_active_material(0)
	suelto.free()
	var n: int = nombres.size()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var huesos := PackedInt32Array()
	var ws := PackedFloat32Array()
	huesos.resize(v.size() * 4)
	ws.resize(v.size() * 4)
	for i in v.size():
		var w: Array = pesos.call(v[i])
		for k in range(4):
			huesos[i * 4 + k] = mini(k, n - 1)
			ws[i * 4 + k] = float(w[k]) if k < w.size() else 0.0
	a[Mesh.ARRAY_BONES] = huesos
	a[Mesh.ARRAY_WEIGHTS] = ws
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	am.surface_set_material(0, mat)
	var modelo := Node3D.new()
	modelo.name = "Modelo"
	modelo.position = pos
	modelo.scale = Vector3.ONE * escala
	add_child(modelo)
	var esq := Skeleton3D.new()
	esq.name = "Esqueleto"
	modelo.add_child(esq)
	var skin := Skin.new()
	for k in range(n):
		esq.add_bone(nombres[k])
		if k > 0:
			esq.set_bone_parent(k, k - 1)
		var rel: Vector3 = (pivotes[k] as Vector3) - ((pivotes[k - 1] as Vector3) if k > 0 else Vector3.ZERO)
		esq.set_bone_rest(k, Transform3D(Basis(), rel))
		esq.set_bone_pose_position(k, rel)
		skin.add_bind(k, Transform3D(Basis(), pivotes[k]).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.name = "Malla"
	mi.mesh = am
	mi.skin = skin
	esq.add_child(mi)
	mi.skeleton = NodePath("..")
	return esq


func _primera_malla(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for h in n.get_children():
		var m: MeshInstance3D = _primera_malla(h)
		if m != null:
			return m
	return null


## Caja envolvente de todo lo que cuelga de la trampa, en coordenadas locales (las pruebas lo miden): Vector3(ancho, alto, saliente).
func medidas() -> Dictionary:
	var minimo := Vector3(INF, INF, INF)
	var maximo := Vector3(-INF, -INF, -INF)
	var pila: Array = [self]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		pila.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
			var mi: MeshInstance3D = n
			var aabb: AABB = mi.get_aabb()
			var rel: Transform3D = global_transform.affine_inverse() * mi.global_transform
			for i in range(8):
				var q: Vector3 = rel * aabb.get_endpoint(i)
				minimo = minimo.min(q)
				maximo = maximo.max(q)
	var t: Vector3 = maximo - minimo
	return {"ancho": t.x, "alto": t.y, "saliente": maximo.z, "min": minimo, "max": maximo}

class_name TroncoPuente3D
extends Area3D

## TRONCO-PUENTE (Juego, 16/10; Bosque 01, «P» de la hoja). Un tronco en pie, con enredaderas, en la orilla opuesta del río: al
## recibir un hechizo de FUEGO (la hoja dice «flecha de fuego») cae SIEMPRE hacia delante, cruzando el río, y se queda de puente.
##
## Por qué no es el `PuenteReactivo3D` (marcador `P`): aquel tiende losas de piedra bajo el agua; aquí el diseño pide un tronco que se
## ve de pie y cae. Mismo final: la casilla del río pasa a letra `b` (puente) y se libera, igual que `PruebaTest2._al_tender_losa`.
##
## Contrato de hechizos (Lanzador3D): un Area3D en la capa CAPA_REACTIVO con `on_spell_hit`, `spell_reacts` y `punto_activacion`.
## HACIA DÓNDE CAE lo dice el marcador de datos (`grupo = "tronco_puente"`): su eje X local (el giro del marcador). Lo coloca
## escenas/bosque_01_3d.gd leyendo `_marcas` de la maqueta; este nodo solo sabe de una base, una dirección y la casilla del río.
##
## PROVISIONAL (modelo): el tronco es un cilindro y las enredaderas son anillos verdes. Falta el modelo de verdad (en pie y caído,
## con enredaderas); cuando exista, solo hay que sustituir `_construir_visual`.

signal caido

const RADIO: float = 0.28
const LARGO: float = 3.4                 ## u: cubre la casilla del río (2,3) y apoya en las dos orillas
const T_CAIDA: float = 1.0
const COLOR_CORTEZA: Color = Color(0.36, 0.25, 0.16)
const COLOR_ENREDADERA: Color = Color(0.26, 0.55, 0.22)

var mundo: Variant = null
var celda_puente: Vector2i = Vector2i(-1, -1)
var direccion: Vector3 = Vector3.LEFT    ## horizontal y unitaria: hacia dónde cae
var cayo: bool = false
var _pivote: Node3D = null
var _forma: CollisionShape3D = null


## `base`: dónde apoya el pie (mundo, a la altura del suelo de la orilla). `p_dir`: hacia dónde cae. `p_celda`: la casilla del río que cubrirá.
func preparar(p_mundo: Variant, base: Vector3, p_dir: Vector3, p_celda: Vector2i) -> void:
	mundo = p_mundo
	celda_puente = p_celda
	direccion = Vector3(p_dir.x, 0.0, p_dir.z).normalized()
	position = base
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	_pivote = Node3D.new()
	_pivote.name = "pivote"
	_pivote.position = Vector3(0.0, RADIO, 0.0)
	add_child(_pivote)
	_construir_visual()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = LARGO
	_forma = CollisionShape3D.new()
	_forma.shape = cap
	_forma.position = Vector3(0.0, LARGO * 0.5, 0.0)
	add_child(_forma)


func _construir_visual() -> void:
	var cil := CylinderMesh.new()
	cil.top_radius = RADIO * 0.9
	cil.bottom_radius = RADIO
	cil.height = LARGO
	var corteza := StandardMaterial3D.new()
	corteza.albedo_color = COLOR_CORTEZA
	corteza.roughness = 0.95
	cil.material = corteza
	var tronco := MeshInstance3D.new()
	tronco.name = "tronco"
	tronco.mesh = cil
	tronco.position = Vector3(0.0, LARGO * 0.5 - RADIO, 0.0)
	_pivote.add_child(tronco)
	var verde := StandardMaterial3D.new()
	verde.albedo_color = COLOR_ENREDADERA
	verde.roughness = 0.9
	for i in range(6):
		var anillo := TorusMesh.new()
		anillo.inner_radius = RADIO * 1.0
		anillo.outer_radius = RADIO * 1.32
		anillo.material = verde
		var mi := MeshInstance3D.new()
		mi.name = "enredadera_%d" % i
		mi.mesh = anillo
		mi.position = Vector3(0.0, (float(i) + 0.6) * LARGO / 6.6 - RADIO, 0.0)
		mi.rotation_degrees = Vector3(float((i * 37) % 17) - 8.0, float(i * 53), float((i * 29) % 15) - 7.0)
		_pivote.add_child(mi)


func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data != null and rune_data.tags.has("calor"):
		caer()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return not cayo and rune_data != null and rune_data.tags.has("calor")


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, LARGO * 0.5, 0.0))


func nivel_altura() -> int:
	return 1


## El tronco cae hacia `direccion` (eje de giro horizontal perpendicular); al terminar, la casilla del río pasa a puente.
func caer() -> void:
	if cayo:
		return
	cayo = true
	_forma.set_deferred("disabled", true)
	if mundo != null and mundo.get("_fx") != null:
		(mundo.get("_fx") as Vfx3D).chispazo(punto_activacion(), "fuego")
	var eje: Vector3 = Vector3.UP.cross(direccion).normalized()
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: _pivote.basis = Basis(eje, a), 0.0, PI * 0.5, T_CAIDA) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_al_caer)


func _al_caer() -> void:
	Terreno3D.poner_letra(celda_puente, "b")
	if mundo != null:
		mundo.call("_liberar", celda_puente)
	caido.emit()

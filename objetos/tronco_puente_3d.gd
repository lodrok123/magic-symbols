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
## MODELO (16/10, Pipeline, ARTE §15): `PiezaBosque3D` trae `tronco_puente_pie` (origen en el centro de la base, 2,6 de alto, huella ≈ 1,4 × 1,6 con
## piedras y vainas) y `tronco_puente_caido` (origen en el pie, tumbado hacia +X, 2,6 de largo). El caído mide 2,6 y el hueco que hay que cubrir
## 3,4 (la casilla del río, 2,3, más las dos orillas): se escala ×(3,4 / 2,6) = 1,31. Mientras cae, el de pie se estira a esa misma escala para que
## el cambio al caído no salte de largo. Sin la lámina (`PiezaBosque3D` devuelve null) vuelve el cilindro con anillos verdes de antes.

signal caido

const RADIO: float = 0.28
const LARGO: float = 3.4                 ## u: cubre la casilla del río (2,3) y apoya en las dos orillas
const T_CAIDA: float = 1.0
const T_ARDE: float = 1.2                ## s que arde un fuego pequeño en la base antes de que el tronco empiece a caer
## ¿Al terminar de caer se cambia al modelo `tronco_puente_caido`? NO (Pablo, 16/10): ese modelo es OSCURO, o sea una versión «quemada», y el tronco
## no debe quedar chamuscado. Se queda el MISMO modelo de pie, ya tumbado (la caída lo estira a la escala del hueco). El oscuro queda para
## troncos que sí se quemen y así tengan reactividad (otros troncos del bosque), no para este. Con true vuelve el cambio de antes.
const CAMBIAR_A_CAIDO_OSCURO: bool = false
const LARGO_MODELO: float = 2.6          ## largo/alto de los dos modelos tal como salen de la lámina
const ESCALA_CAIDO: float = LARGO / LARGO_MODELO
const COLOR_CORTEZA: Color = Color(0.36, 0.25, 0.16)
const COLOR_ENREDADERA: Color = Color(0.26, 0.55, 0.22)

var mundo: Variant = null
var celda_puente: Vector2i = Vector2i(-1, -1)
var direccion: Vector3 = Vector3.LEFT    ## horizontal y unitaria: hacia dónde cae
var cayo: bool = false
var _pivote: Node3D = null
var _forma: CollisionShape3D = null
var _alto: float = LARGO                 ## alto del tronco en pie (para la forma de golpeo y el punto de activación)
var _caido_modelo: MeshInstance3D = null ## el modelo del tronco ya caído (null si se usa el cilindro)
var _llama: Node3D = null                ## el fuego pequeño de la base mientras prende


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
	cap.height = _alto
	_forma = CollisionShape3D.new()
	_forma.shape = cap
	_forma.position = Vector3(0.0, _alto * 0.5, 0.0)
	add_child(_forma)


func _construir_visual() -> void:
	var pie: MeshInstance3D = PiezaBosque3D.crear("tronco_puente_pie")
	var caido: MeshInstance3D = PiezaBosque3D.crear("tronco_puente_caido")
	if pie != null and caido != null:
		# El pivote gira alrededor del eje del tronco tumbado (a RADIO del suelo): el modelo de pie baja ese RADIO dentro del pivote.
		pie.position = Vector3(0.0, -RADIO, 0.0)
		_pivote.add_child(pie)
		caido.rotation.y = atan2(-direccion.z, direccion.x)       # su +X local mira hacia donde cae
		caido.scale = Vector3.ONE * ESCALA_CAIDO
		caido.visible = false
		add_child(caido)
		_caido_modelo = caido
		_alto = LARGO_MODELO
		return
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
	return to_global(Vector3(0.0, _alto * 0.5, 0.0))


func nivel_altura() -> int:
	return 1


## El tronco cae hacia `direccion` (eje de giro horizontal perpendicular); al terminar, la casilla del río pasa a puente.
func caer() -> void:
	if cayo:
		return
	cayo = true
	_forma.set_deferred("disabled", true)
	var fx: Vfx3D = null
	if mundo != null and mundo.get("_fx") != null:
		fx = mundo.get("_fx") as Vfx3D
		fx.chispazo(punto_activacion(), "fuego")
		# Un fuego PEQUEÑO prende en la base (una lengua, como las enredaderas) y el tronco cae cuando ya ha ardido un momento: se ve por qué cae.
		# No hay versión quemada del tronco-puente (Pablo): el modelo no cambia; solo el fuego sube y se apaga al empezar a caer.
		_llama = fx.llamas(Vector3(global_position.x, global_position.y, global_position.z), 0.6, 0.3, 1)
	var eje: Vector3 = Vector3.UP.cross(direccion).normalized()
	var tw := create_tween()
	var estira: float = ESCALA_CAIDO if _caido_modelo != null else 1.0
	tw.tween_interval(T_ARDE if fx != null else 0.0)
	tw.tween_callback(_apagar_llama.bind(fx))
	tw.tween_method(func(a: float) -> void:
			_pivote.basis = Basis(eje, a).scaled(Vector3.ONE * lerpf(1.0, estira, a / (PI * 0.5))), 0.0, PI * 0.5, T_CAIDA) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_al_caer)


func _apagar_llama(fx: Vfx3D) -> void:
	if fx != null and is_instance_valid(fx) and _llama != null and is_instance_valid(_llama):
		fx.apagar(_llama)
	_llama = null


func _al_caer() -> void:
	if _caido_modelo != null and CAMBIAR_A_CAIDO_OSCURO:
		_pivote.visible = false
		_caido_modelo.visible = true
	Terreno3D.poner_letra(celda_puente, "b")
	if mundo != null:
		mundo.call("_liberar", celda_puente)
	caido.emit()

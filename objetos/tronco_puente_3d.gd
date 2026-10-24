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
## piedras y vainas) y `tronco_puente_caido` (origen en el pie, tumbado hacia +X, 2,6 de largo).
##
## CÓMO LLEGA DE ORILLA A ORILLA (21/10, playtest de Pablo: «no llega al otro lado»). Antes el largo era un 3,4 fijo, se estiraba el modelo ENTERO
## (también el grosor: 1,31× más gordo y alto) y se giraba sobre un pivote desplazado, con lo que la punta quedaba 0,42 u antes de la orilla de
## enfrente y la cara de arriba a ~2,2 de alto, muy por encima de lo que pisa el jugador (1,1). Ahora:
##   · el largo SALE DEL RÍO: se cuentan las casillas de agua (`~`) desde `celda_puente` en la dirección de caída (`n`); el tronco cubre
##     `n × casilla` más un MARGEN_ORILLA apoyado en cada orilla;
##   · el pie NO se queda donde estaba en pie (a 1,15 u del agua, medio tronco se perdería en tierra firme): al caer se DESLIZA hacia el río
##     hasta quedar a MARGEN_ORILLA del borde, como un árbol que se descuelga; así el estirado necesario baja de ×1,5 a ≈×1,27;
##   · se estira SOLO el eje largo (el grosor del modelo no cambia);
##   · el modelo gira sobre sí mismo para que su cara «ancha» (+X del modelo) quede arriba sea cual sea la dirección de caída, y el pivote sube lo
##     justo para que la cara de arriba quede a CARA_SOBRE_ORILLA por encima de la orilla (un escalón que se anda, no un salto);
##   · al terminar, CADA casilla de agua bajo el tronco pasa a «b», se libera y se pisa a la altura de esa cara (`Terreno3D.fijar_y_puente`).
## Sin la lámina (`PiezaBosque3D` devuelve null) vuelve el cilindro con anillos verdes de antes (con el mismo largo y altura).

signal caido

const RADIO: float = 0.28
const MARGEN_ORILLA: float = 0.5         ## u que el tronco apoya en cada orilla (el pie y la punta)
const CARA_SOBRE_ORILLA: float = 0.35    ## u: la cara de arriba del tronco queda tan por encima del suelo de la orilla (se sube sin saltar: tolerancia 0,55)
const CARA_MODELO: float = 0.34          ## u que sube el lomo del tronco sobre su eje (mediana de la malla `tronco_puente_pie`; la prueba lo vuelve a medir)
const MAX_CASILLAS_RIO: int = 6          ## tope al contar el agua que cruza (un río mal editado no estira el tronco sin fin)
const T_CAIDA: float = 1.0
const T_ARDE: float = 1.2                ## s que arde un fuego pequeño en la base antes de que el tronco empiece a caer
## ¿Al terminar de caer se cambia al modelo `tronco_puente_caido`? NO (Pablo, 16/10): ese modelo es OSCURO, o sea una versión «quemada», y el tronco
## no debe quedar chamuscado. Se queda el MISMO modelo de pie, ya tumbado (la caída lo estira a la escala del hueco). El oscuro queda para
## troncos que sí se quemen y así tengan reactividad (otros troncos del bosque), no para este. Con true vuelve el cambio de antes.
const CAMBIAR_A_CAIDO_OSCURO: bool = false
const LARGO_MODELO: float = 2.6          ## largo/alto de los dos modelos tal como salen de la lámina
const COLOR_CORTEZA: Color = Color(0.36, 0.25, 0.16)
const COLOR_ENREDADERA: Color = Color(0.26, 0.55, 0.22)

var mundo: Variant = null
var celda_puente: Vector2i = Vector2i(-1, -1)
var direccion: Vector3 = Vector3.LEFT    ## horizontal y unitaria: hacia dónde cae
var cayo: bool = false
var _pivote: Node3D = null
var _forma: CollisionShape3D = null
var _alto: float = LARGO_MODELO          ## alto del tronco en pie (para la forma de golpeo y el punto de activación)
var _caido_modelo: MeshInstance3D = null ## el modelo del tronco ya caído (null si se usa el cilindro)
var _llama: Node3D = null                ## el fuego pequeño de la base mientras prende
## Lo que se mide del río al preparar (todo en u, a lo largo de `direccion` desde la base):
var celdas_rio: Array[Vector2i] = []     ## las casillas de agua que cubre, de la más cercana a la más lejana
var largo: float = 3.3                   ## largo total del tronco tumbado (de la punta del pie a la punta de arriba)
var desliza: float = 0.0                 ## cuánto se desplaza el pie hacia el río al caer
var escala_largo: float = 1.0            ## estirado del eje largo del modelo (1 = tal como sale de la lámina)
var y_cara: float = 0.0                  ## y del mundo de la cara de arriba del tronco caído: donde se pisa
var _lev: float = 0.0                    ## lo que sube el pivote sobre la base para que la cara quede a CARA_SOBRE_ORILLA


## `base`: dónde apoya el pie (mundo, a la altura del suelo de la orilla). `p_dir`: hacia dónde cae. `p_celda`: la primera casilla del río.
func preparar(p_mundo: Variant, base: Vector3, p_dir: Vector3, p_celda: Vector2i) -> void:
	mundo = p_mundo
	celda_puente = p_celda
	direccion = Vector3(p_dir.x, 0.0, p_dir.z).normalized()
	position = base
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	_medir_rio(base)
	y_cara = base.y + CARA_SOBRE_ORILLA
	_pivote = Node3D.new()
	_pivote.name = "pivote"
	add_child(_pivote)
	_construir_visual()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = _alto
	_forma = CollisionShape3D.new()
	_forma.shape = cap
	_forma.position = Vector3(0.0, _alto * 0.5, 0.0)
	add_child(_forma)


## Cuenta el agua que hay que cruzar y de ahí saca el largo, lo que se desliza el pie y el estirado. Todo a lo largo de `direccion`, con s = 0 en la base
## (el centro de la casilla de la orilla donde está el árbol): el borde cercano del río está en s_cerca, el lejano en s_lejos.
func _medir_rio(base: Vector3) -> void:
	celdas_rio.clear()
	var paso := Vector2i(roundi(direccion.x), roundi(direccion.z))
	var c: Vector2i = celda_puente
	while Terreno3D.en_mapa(c) and Terreno3D.letra_de(c) == "~" and celdas_rio.size() < MAX_CASILLAS_RIO:
		celdas_rio.append(c)
		c += paso
	if celdas_rio.is_empty():
		celdas_rio.append(celda_puente)      # nivel editado a mano sin agua ahí: se comporta como antes (una casilla)
	var cas: float = Terreno3D.casilla
	var s_cerca: float = (Terreno3D.centro_de(celda_puente, base.y) - base).dot(direccion) - cas * 0.5
	var s_lejos: float = s_cerca + float(celdas_rio.size()) * cas
	desliza = maxf(0.0, s_cerca - MARGEN_ORILLA)
	largo = (s_lejos + MARGEN_ORILLA) - desliza


func _construir_visual() -> void:
	var pie: MeshInstance3D = PiezaBosque3D.crear("tronco_puente_pie")
	var caido: MeshInstance3D = PiezaBosque3D.crear("tronco_puente_caido")
	if pie != null and caido != null:
		# El modelo se estira SOLO a lo largo (su eje Y de pie). El origen del modelo es el pie: el pivote gira alrededor de él.
		escala_largo = largo / LARGO_MODELO
		_lev = CARA_SOBRE_ORILLA - CARA_MODELO
		_pivote.position = Vector3(0.0, _lev, 0.0)
		# El lomo ancho del modelo (+X local) tiene que quedar ARRIBA al tumbarse: al caer hacia `d` la cara de atrás (-d) es la que mira al cielo.
		pie.rotation.y = atan2(direccion.z, -direccion.x)
		_pivote.add_child(pie)
		caido.rotation.y = atan2(-direccion.z, direccion.x)       # su +X local mira hacia donde cae
		caido.scale = Vector3(escala_largo, 1.0, 1.0)
		caido.position = direccion * desliza
		caido.visible = false
		add_child(caido)
		_caido_modelo = caido
		_alto = LARGO_MODELO
		return
	escala_largo = 1.0
	_lev = CARA_SOBRE_ORILLA - RADIO
	_pivote.position = Vector3(0.0, _lev, 0.0)
	_alto = largo
	var cil := CylinderMesh.new()
	cil.top_radius = RADIO * 0.9
	cil.bottom_radius = RADIO
	cil.height = largo
	var corteza := StandardMaterial3D.new()
	corteza.albedo_color = COLOR_CORTEZA
	corteza.roughness = 0.95
	cil.material = corteza
	var tronco := MeshInstance3D.new()
	tronco.name = "tronco"
	tronco.mesh = cil
	tronco.position = Vector3(0.0, largo * 0.5, 0.0)          # el pie en el pivote, como el modelo
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
		mi.position = Vector3(0.0, (float(i) + 0.6) * largo / 6.6, 0.0)
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
	tw.tween_interval(T_ARDE if fx != null else 0.0)
	tw.tween_callback(_apagar_llama.bind(fx))
	# Gira (R) y se estira SOLO a lo largo (S en el eje Y local, y R * S para que el estirado vaya con el modelo y no con el mundo); a la vez el
	# pie se desliza hacia el río. Todo en función del ángulo, para que el rebote final asiente el tronco entero y no solo el giro.
	tw.tween_method(func(a: float) -> void:
			var f: float = a / (PI * 0.5)
			_pivote.basis = Basis(eje, a) * Basis.from_scale(Vector3(1.0, lerpf(1.0, escala_largo, f), 1.0))
			_pivote.position = direccion * (desliza * f) + Vector3(0.0, _lev, 0.0), 0.0, PI * 0.5, T_CAIDA) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_al_caer)


## Cae YA: sin fuego ni animación, con el tronco ya tumbado (volver de otro nivel con el tronco caído: lo resuelto se queda resuelto). Emite `caido` como siempre.
func caer_ya() -> void:
	if cayo:
		return
	cayo = true
	_forma.set_deferred("disabled", true)
	var eje: Vector3 = Vector3.UP.cross(direccion).normalized()
	_pivote.basis = Basis(eje, PI * 0.5) * Basis.from_scale(Vector3(1.0, escala_largo, 1.0))
	_pivote.position = direccion * desliza + Vector3(0.0, _lev, 0.0)
	_al_caer()


func _apagar_llama(fx: Vfx3D) -> void:
	if fx != null and is_instance_valid(fx) and _llama != null and is_instance_valid(_llama):
		fx.apagar(_llama)
	_llama = null


func _al_caer() -> void:
	if _caido_modelo != null and CAMBIAR_A_CAIDO_OSCURO:
		_pivote.visible = false
		_caido_modelo.visible = true
	# TODAS las casillas de agua bajo el tronco (no solo la primera): puente «b», pisable a la altura de la cara de arriba. Primero la altura y la
	# letra (la letra avisa a Caminos3D y a los goblins por `casilla_cambio`) y luego se libera el bloqueo (otro aviso).
	for c in celdas_rio:
		Terreno3D.fijar_y_puente(c, y_cara)
		Terreno3D.poner_letra(c, "b")
		if mundo != null:
			mundo.call("_liberar", c)
	caido.emit()

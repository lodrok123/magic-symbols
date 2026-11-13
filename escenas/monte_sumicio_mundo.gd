extends "res://presentacion/prueba_test2.gd"


## El GridMap es el suelo visible y el plano que lee el cargador común.
## Cada planta del GridMap equivale a medio escalón de Sumicio.
func _construir_suelo(_dibujar: bool = true) -> void:
	super._construir_suelo(false)


## Letra de suelo que pintó el GridMap en cada casilla (sin los marcadores encima).
var _letra_pintada: Dictionary = {}


func _leer_nivel_de(raiz: Node) -> void:
	super._leer_nivel_de(raiz)
	_letra_pintada.clear()
	var suelo := raiz.get_node_or_null("Suelo") as GridMap
	if suelo == null:
		return
	var alto: Dictionary = {}
	for u in suelo.get_used_cells():
		var c := Vector2i(u.x, u.z) - _origen
		if not alto.has(c) or int(alto[c]) < u.y:
			alto[c] = u.y
			_letra_pintada[c] = HorneadorNivel.letra_de_item(suelo.mesh_library, suelo.get_cell_item(u))


## Un marcador (inicio, entradas…) no cambia el color del suelo: manda lo pintado en el GridMap.
func _tipo_suelo(c: Vector2i) -> int:
	var l: String = _letra(c)
	if _letra_pintada.has(c) and not HorneadorNivel.LETRAS_SUELO.contains(l):
		match String(_letra_pintada[c]):
			"g":
				return 2
			"R":
				return 3
			_:
				return 0
	return super._tipo_suelo(c)


func _instanciar_nivel() -> void:
	var maqueta := $Maqueta
	var plano := _nivel_raiz as Node3D
	_nivel_raiz = null
	maqueta.add_child(plano)
	plano.position = _desplaza


func _activar_solidez_por_nodos() -> void:
	# La visita anima puertas y registra sus contornos sobre la solidez por casillas.
	pass


func _antes_de_cargar_partida() -> void:
	$Maqueta.montar()
	_vestir_suelo()
	var jugador := get_node("Jugador3D") as Jugador3D
	var inicio := jugador.position
	inicio.y = Terreno3D.y_pies(Terreno3D.celda_de(inicio))
	jugador.position = inicio
	jugador.pj.position = inicio
	jugador.puntos_inicio = inicio


## Costuras como en EoW: la cara de arriba de cada bloque del GridMap lleva el shader común del suelo
## (texturas en coordenadas de mundo + tiras «joint» con ruido entre tipos), así la unión hierba/camino
## no sigue la arista de la casilla. Los lados conservan el material de la loseta.
func _vestir_suelo() -> void:
	if _mat_suelo == null:
		return
	# El tipo «piedra» de Sumicio es el empedrado (las losas claras del bosque no van aquí).
	if ResourceLoader.exists(SUELO + "empedrado_sumicio.png"):
		_mat_suelo.set_shader_parameter("t_piedra", _tex(SUELO + "empedrado_sumicio.png"))
	# Una malla aparte con la cara de arriba de cada columna (la biblioteca del GridMap no se toca).
	var suelo: GridMap = $Maqueta.suelo
	var lib := suelo.mesh_library
	var tope: Dictionary = {}
	for u in suelo.get_used_cells():
		var item := suelo.get_cell_item(u)
		var caja := lib.get_item_mesh(item) as BoxMesh
		if caja == null:
			continue
		# Con la orientación de la casilla: una loseta girada desplaza su altura en otro eje.
		var giro := suelo.get_basis_with_orthogonal_index(suelo.get_cell_item_orientation(u))
		var y := suelo.map_to_local(u).y + (giro * lib.get_item_mesh_transform(item).origin).y + absf((giro * caja.size).y) * 0.5
		var c := Vector2i(u.x, u.z)
		if not tope.has(c) or float(tope[c]) < y:
			tope[c] = y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var m := suelo.cell_size.x * 0.5
	for c in tope:
		var p := suelo.map_to_local(Vector3i(c.x, 0, c.y))
		p.y = float(tope[c]) + 0.02
		var a := p + Vector3(-m, 0, -m)
		var b := p + Vector3(m, 0, -m)
		var d := p + Vector3(m, 0, m)
		var e := p + Vector3(-m, 0, m)
		for v in [a, b, d, a, d, e]:
			st.add_vertex(v)
	var tapas := MeshInstance3D.new()
	tapas.name = "TapasEoW"
	tapas.mesh = st.commit()
	tapas.material_override = _mat_suelo
	tapas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	suelo.add_child(tapas)
	# Las rampas llevan el mismo shader, así las costuras siguen por la pendiente.
	var pendientes := suelo.get_parent().get_node_or_null("Pendientes") as PendientesSuelo3D
	if pendientes:
		pendientes.material_juego = _mat_suelo
		pendientes.construir()     # ya con el nivel en su sitio: las rampas se apuntan en Terreno3D para los pies

extends "res://presentacion/prueba_test2.gd"


## El GridMap es el suelo visible y el plano que lee el cargador común.
## Cada planta del GridMap equivale a medio escalón de Sumicio.
func _construir_suelo(_dibujar: bool = true) -> void:
	super._construir_suelo(false)


## Fuerza del relieve (normal) del suelo en Monte Sumicio: 0 liso · 0,5 la de los demás niveles · 1 el máximo de la tecla B · 2 Sumicio (por encima del máximo de la tecla).
const RUGOSIDAD_SUMICIO := 2.5
## Relieve de más SOLO en la hierba (14/11, Pablo: «¿por qué no afecta en la hierba?»): por defecto la hierba lleva la mitad que el camino
## y la luz en rampa la satura a blanco. 0 = como en los demás niveles.
const RELIEVE_HIERBA_SUMICIO := 0.4    ## con 1 o más, el ruido de la normal se ve granulado sobre la hierba pintada
## Relieve que conserva la franja pintada de la junta hierba→tierra/camino (14/11, Pablo: «esta junta ha vuelto a afectarse»): 0 = lisa,
## con su dibujo limpio; 1 = el relieve del suelo también encima. Las rayas eran de la textura estirada (ver BORDE_EXTIENDE); lisa del todo
## quedaba más clara que la hierba de al lado.
const RELIEVE_JUNTA_SUMICIO := 0.4
## La franja de hojas de la junta se EXTIENDE en coordenadas de mundo en vez de estirarse sobre la frontera (14/11, Pablo: «sospecho que
## estás estirando la textura en vez de extenderla»): 1 = extendida (sin abanicos en curvas y esquinas) · 0 = como en los demás niveles.
const BORDE_EXTIENDE_SUMICIO := 1.0
## Fundido de esa franja hacia la tierra (14/11, Pablo: «debería tener la textura como un fade y entremezclarse con la tierra»): 1 = se
## desvanece con el corte roto por ruido fino (calvas de tierra entre las hojas) · 0 = banda maciza, como en los demás niveles.
const BORDE_FUNDIDO_SUMICIO := 1.0
## Tinte de esa franja: el de serie (0,80 0,90 0,72) es para la hierba del bosque y aquí salía menta; este la acerca al verde de Sumicio.
const BORDE_TINTE_SUMICIO := Color(0.82, 0.87, 0.64)
## 14/11, 3.ª pasada (Pablo: «sigo sin verlo bien. Mira la junta»): con la cámara del juego la franja de hojas se ve como un hilo pálido con
## manchas verdes planas sueltas, y debajo la hierba pasa a la tierra en un degradado borroso. Lo que se usa ahora: SIN franja de hojas
## (BORDE_FUERZA 0, así que los cuatro valores de arriba no hacen nada) y con la frontera de la hierba rota por ruido fino (MEZCLA_HIERBA):
## matas de hierba sobre la tierra y el empedrado y calvas en la hierba, entremezcladas. Para volver a la franja: BORDE_FUERZA 1, MEZCLA 0.
const BORDE_FUERZA_SUMICIO := 0.0
const MEZCLA_HIERBA_SUMICIO := 1.2     ## 0 = degradado liso · 0,8 suave · 1,4 muy deshilachado


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


## 14/11 (Pablo: «las colisiones son por casilla; ponlas TODAS por malla, hay muchos muros invisibles»): Monte Sumicio usa la solidez por
## COLISIÓN REAL, como los bosques. Antes se quedaba en casillas porque la fuente medía a la altura fija del suelo base y aquí el suelo está a
## 2-3 u (ahora mide en el suelo de cada casilla: Terreno3D.FuenteNodos.suelo_de). Los cuerpos los pone la maqueta (montar) y la vegetación.
## Lo que se bloqueó mientras mandaban las casillas (bordes del mapa, muros y muebles de los interiores, cofres) pasa a la fuente nueva
## conservando su forma: con un nodo apuntado (`bloquear(c, nodo)`), choca con ese nodo; sin él, la casilla entera, como antes.
func _activar_solidez_por_nodos() -> void:
	var antes := Terreno3D.fuente
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or Terreno3D.mundo_s != self:
		return
	var n: int = Lanzador3D.activar_fuente_nodos(self)
	var nueva := Terreno3D.fuente
	var fijos: Dictionary = antes.get("_fijos") if antes != null else {}
	var sin_sellar: Dictionary = antes.get("contorno_sin_sellado") if antes != null else {}
	var con_forma := 0
	for c in _bloqueadas.keys():
		var lista: Array = fijos.get(c, [])
		var puestos := 0
		for r in lista:
			var nodo := (r as WeakRef).get_ref() as Node3D
			if nodo != null and nodo.is_inside_tree():
				nueva.bloquear(c, nodo)
				puestos += 1
		if puestos == 0:
			nueva.bloquear_completa(c)
		else:
			con_forma += 1
			if sin_sellar.has(c):
				nueva.contorno_sin_sellado[c] = true
	print("Solidez por colisión: %d casillas tocadas por piezas · %d bloqueos de antes (%d con la forma de su objeto)" % [n, _bloqueadas.size(), con_forma])


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
	# 14/11 (Pablo: «¿puedes subir la normal del suelo?»): más relieve que en el resto de niveles (0,5). La tecla B sigue ciclando 0 · 0,5 · 1.
	_rugosidad = RUGOSIDAD_SUMICIO
	_mat_suelo.set_shader_parameter("rugosidad", _rugosidad)
	_mat_suelo.set_shader_parameter("relieve_hierba", RELIEVE_HIERBA_SUMICIO)
	_mat_suelo.set_shader_parameter("relieve_junta", RELIEVE_JUNTA_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_extiende", BORDE_EXTIENDE_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_fundido", BORDE_FUNDIDO_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_fuerza", BORDE_FUERZA_SUMICIO)
	_mat_suelo.set_shader_parameter("mezcla_hierba", MEZCLA_HIERBA_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_tinte", BORDE_TINTE_SUMICIO)
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

extends "res://presentacion/prueba_test2.gd"


## El GridMap es el suelo visible y el plano que lee el cargador común.
## Cada planta del GridMap equivale a medio escalón de Sumicio.
func _construir_suelo(_dibujar: bool = true) -> void:
	super._construir_suelo(false)


## 26/11: las juntas y los bordes de Sumicio (relieve, relieve de la junta, borde extendido y fundido, mezcla de hierba, tinte) viven en
## `presentacion/acabado_suelo.gd`, que leen TAMBIÉN todos los niveles de la maqueta (los del generador de mapas incluidos). Se afinan allí, con el porqué
## de cada valor; aquí solo quedan los nombres de siempre apuntando a ese script.
const RUGOSIDAD_SUMICIO := AcabadoSuelo.RUGOSIDAD
const RELIEVE_HIERBA_SUMICIO := AcabadoSuelo.RELIEVE_HIERBA
const RELIEVE_JUNTA_SUMICIO := AcabadoSuelo.RELIEVE_JUNTA
const BORDE_EXTIENDE_SUMICIO := AcabadoSuelo.BORDE_EXTIENDE
const BORDE_FUNDIDO_SUMICIO := AcabadoSuelo.BORDE_FUNDIDO
const BORDE_TINTE_SUMICIO := AcabadoSuelo.BORDE_TINTE
const BORDE_FUERZA_SUMICIO := AcabadoSuelo.BORDE_FUERZA
const MEZCLA_HIERBA_SUMICIO := AcabadoSuelo.MEZCLA_HIERBA


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
	_retirar_base_visual_torre()
	_vestir_suelo()
	var jugador := get_node("Jugador3D") as Jugador3D
	var inicio := jugador.position
	inicio.y = Terreno3D.y_pies(Terreno3D.celda_de(inicio))
	jugador.position = inicio
	jugador.pj.position = inicio
	jugador.puntos_inicio = inicio


func _retirar_base_visual_torre() -> void:
	# El mapa ya se leyó. Estas dos columnas de tierra taparían el hueco de la Bajada.
	var centro: Vector2i = $Interiores/TorreVerde.centro + _origen
	var suelo: GridMap = $Maqueta.suelo
	for u in suelo.get_used_cells():
		if u.x == centro.x + 2 and u.z in [centro.y, centro.y + 1]:
			suelo.set_cell_item(u, -1)


## Costuras como en EoW: la cara de arriba de cada bloque del GridMap lleva el shader común del suelo
## (texturas en coordenadas de mundo + tiras «joint» con ruido entre tipos), así la unión hierba/camino
## no sigue la arista de la casilla. Los lados conservan el material de la loseta.
func _vestir_suelo() -> void:
	if _mat_suelo == null:
		return
	# 14/11 (Pablo: «¿puedes subir la normal del suelo?»): más relieve que en el resto de niveles (0,5). La tecla B sigue ciclando 0 · 0,5 · 1.
	# 26/11: los mismos ajustes que lleva ya la maqueta para todo nivel (`_aplicar_juntas_entremezcladas`); se repiten aquí por si esa pasada se apagó.
	_rugosidad = AcabadoSuelo.aplicar(_mat_suelo, "sumicio", _rugosidad)
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

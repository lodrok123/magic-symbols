extends Node3D

var suelo: GridMap:
	get:
		return $Nivel_MonteSumicio/Suelo
var porton: Node3D:
	get:
		return $Nivel_MonteSumicio/Piezas/Porton
var torre: Node3D:
	get:
		return $Nivel_MonteSumicio/Piezas/TorreVerde
var obrador: Node3D:
	get:
		return $Nivel_MonteSumicio/Piezas/Obrador
var inicio: Node3D:
	get:
		return $Nivel_MonteSumicio/Marcadores/InicioFraga
var guardia: Node3D:
	get:
		return $Nivel_MonteSumicio/Piezas/Porton/Guardia
var marimanta: Node3D:
	get:
		return $Nivel_MonteSumicio/Piezas/TorreVerde/Marimanta
var caco: Node3D:
	get:
		return $Nivel_MonteSumicio/Piezas/Obrador/Caco
var cofre: Node3D:
	get:
		return $Nivel_MonteSumicio/Piezas/TorreVerde/CofreUniforme
var escolta: Node3D:
	get:
		return $Nivel_MonteSumicio/Marcadores/Escolta

var _tope_anterior: int
var _montada := false


func montar() -> void:
	_tope_anterior = Jugador3D.tope_niveles_nivel
	Jugador3D.tope_niveles_nivel = 2
	_montada = true
	var plantas: Dictionary[Vector2i, int] = {}
	for u in suelo.get_used_cells():
		var c := Terreno3D.celda_de(suelo.to_global(suelo.map_to_local(u)))
		plantas[c] = maxi(plantas.get(c, u.y), u.y)
	# Altura real de la cara de arriba (las losetas _MEDIA quedan más bajas que su planta).
	var arriba: Dictionary = {}
	var topes := PendientesSuelo3D.topes(suelo)
	for k in topes:
		var col: Vector2i = k
		var y_global := suelo.to_global(Vector3(suelo.map_to_local(Vector3i(col.x, 0, col.y)).x, float(topes[k][0]), suelo.map_to_local(Vector3i(col.x, 0, col.y)).z))
		arriba[Terreno3D.celda_de(y_global)] = y_global.y
	for c in plantas:
		var planta := plantas[c]
		var niveles := maxi(0, floori(planta * 0.5))
		Terreno3D.fijar_altura(c, niveles)
		var base := Terreno3D.alto_suelo + float(niveles) * Terreno3D.ALTO_NIVEL
		var realce: float = float(arriba[c]) - base if arriba.has(c) else (planta - niveles * 2) * suelo.cell_size.y
		if absf(realce) > 0.001:
			Terreno3D.realces_terreno[c] = realce
	for pieza in $Nivel_MonteSumicio/Piezas.find_children("*", "Node3D", true, false):
		if pieza.has_meta("bloquea_casilla"):
			Terreno3D.bloquear_celda_completa(celda(pieza))
	for casa in casas():
		_registrar_palloza(casa)
	Terreno3D.bloquear_contorno(celda(cofre), cofre)
	var entrada := SalidaNivel3D.EntradaNivel3D.new()
	entrada.preparar(celda(inicio), "desde_fraga", "n")
	get_parent().add_child(entrada)


func _exit_tree() -> void:
	if _montada:
		Jugador3D.tope_niveles_nivel = _tope_anterior


func casas() -> Array[Node3D]:
	# El orden asocia cada casa con su interior y mantiene las claves de los cofres.
	return [$Nivel_MonteSumicio/Piezas/Pallozas/Iria, $Nivel_MonteSumicio/Piezas/Pallozas/Brais, $Nivel_MonteSumicio/Piezas/Pallozas/Sabela,
		$Nivel_MonteSumicio/Piezas/Pallozas/TiendaEste]


func abrir_porton() -> void:
	porton.get_node("Bisagra").rotation.y = PI * 0.5
	Terreno3D.liberar_celda(celda(porton))


func bisagra(casa: Node3D) -> Node3D:
	# La Torre Verde lleva su puerta en el propio nodo (el modelo de Meshy es una sola malla); las pallozas, dentro del modelo.
	var propia := casa.get_node_or_null("Puerta") as Node3D
	return propia if propia != null else casa.get_node("Modelo/Puerta")


func mostrar_interiores(posicion: Vector3) -> void:
	# Meshy entrega la torre como una sola malla. Al cruzar el umbral se
	# descubre la sala de audiencia, que conserva sus propios muros.
	var local := torre.to_local(posicion)
	var dentro := Rect2(-3.6, -3.6, 7.2, 8.25).has_point(Vector2(local.x, local.z))
	torre.get_node("Modelo").visible = not dentro
	for muro in torre.get_children():
		if muro.has_meta("bloquea_casilla"):
			muro.visible = dentro


static func celda(nodo: Node3D) -> Vector2i:
	return Terreno3D.celda_de(nodo.global_position)


static func punto(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _registrar_palloza(casa: Node3D) -> void:
	bisagra(casa).position += Vector3(0.03, 0.0, -0.04)
	var c := celda(casa)
	var casillas: Array[Vector2i] = []
	for z in range(-1, 2):
		for x in range(-1, 2):
			var vecina := c + Vector2i(x, z)
			if not Terreno3D.es_vacio(vecina) and not Terreno3D.bloqueada(vecina):
				casillas.append(vecina)
	var malla := BoxMesh.new()
	malla.size = Vector3(0.61, 1.6, 0.29)
	# El contorno deja libre el arco que ocupa la puerta.
	for i in range(2, 15):
		var angulo := TAU * i / 16.0
		var normal := Vector3(sin(angulo), 0.0, cos(angulo))
		var tramo := MeshInstance3D.new()
		tramo.mesh = malla
		tramo.layers = 0
		tramo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		casa.add_child(tramo)
		tramo.position = normal * 1.49 + Vector3.UP * 0.8
		tramo.rotation.y = angulo
		for vecina in casillas:
			var d := punto(vecina) - tramo.global_position
			var alcance := Terreno3D.casilla * 0.5 + 0.60
			if absf(d.x) < alcance and absf(d.z) < alcance:
				Terreno3D.bloquear_contorno(vecina, tramo)
	Terreno3D.bloquear_celda_completa(c)

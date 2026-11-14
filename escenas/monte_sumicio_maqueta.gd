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
var _hojas: Array[Node3D] = []              ## bisagras de la cancela: izquierda y derecha
var _celdas_puerta: Array[Vector2i] = []    ## casillas que cierra SOLO la cancela (se liberan al abrir)
var _choque_puerta: MeshInstance3D          ## caja invisible con la forma de la cancela cerrada (choque fino, como los muros de las pallozas)
var _puerta_abierta := false


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
	_empalizada_circular()
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


## Abre la cancela de la empalizada (el guardia deja pasar a Mid). `animado`: las dos hojas giran hacia dentro; sin animar (partida
## cargada con Mid ya admitida), quedan abiertas de golpe.
func abrir_porton(animado := false) -> void:
	_puerta_abierta = true
	Terreno3D.liberar_celda(celda(porton))
	for c in _celdas_puerta:
		Terreno3D.liberar_celda(c)
	_celdas_puerta.clear()
	if _choque_puerta != null:
		_choque_puerta.queue_free()
		_choque_puerta = null
	if _hojas.is_empty():
		porton.get_node("Bisagra").rotation.y = PI * 0.5      # sin la valla de Meshy: la caja de siempre
		return
	var giros := [-deg_to_rad(PUERTA_GIRO), deg_to_rad(PUERTA_GIRO)]      # izquierda y derecha, las dos hacia dentro (+Z local)
	if not animado:
		for i in range(_hojas.size()):
			_hojas[i].rotation.y = giros[i]
		return
	var t := create_tween().set_parallel()
	for i in range(_hojas.size()):
		# La derecha sale un pelín después: dos hojas empujadas a mano, no un mecanismo.
		t.tween_property(_hojas[i], "rotation:y", giros[i], PUERTA_TIEMPO).set_delay(PUERTA_RETARDO + 0.12 * i) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func porton_abierto() -> bool:
	return _puerta_abierta


func bisagra(casa: Node3D) -> Node3D:
	# La Torre Verde lleva su puerta en el propio nodo (el modelo de Meshy es una sola malla); las pallozas, dentro del modelo.
	var propia := casa.get_node_or_null("Puerta") as Node3D
	return propia if propia != null else casa.get_node("Modelo/Puerta")


func mostrar_interiores(posicion: Vector3) -> void:
	# Meshy entrega la torre como una sola malla. Al cruzar el umbral se
	# descubre la sala de audiencia, que conserva sus propios muros.
	# 14/11: desde que la torre tiene su propia escena (InteriorTorre, se entra por la puerta animada) ya no se descubre la sala por dentro:
	# esconder el modelo al llegar al arco hacía desaparecer la torre delante de la puerta. La torre se ve siempre; sus muros de colisión, nunca.
	var dentro := false
	torre.get_node("Modelo").visible = not dentro
	for muro in torre.get_children():
		if muro.has_meta("bloquea_casilla"):
			muro.visible = dentro


## 14/11 (Pablo): la empalizada es CIRCULAR, como la planta de un castro. En el editor sigue siendo el cuadrado de tramos (fácil de
## mover); al montar, el círculo se inscribe en ese cuadrado: mismo centro, radio = medio lado. Los tramos del cuadrado se esconden y dejan
## de bloquear; bloquean las casillas que pisa el círculo.
## 14/11, 2.ª pasada (Pablo: «no me gusta cómo está integrada la valla; pon una puerta cerrada que se abra cuando el guardia te deje pasar»):
##   · el hueco sale del PORTÓN (Piezas/Porton): en su dirección desde el centro, PUERTA_ANCHO de vano más un poste a cada lado. Los paneles
##     se reparten a partes iguales por el resto del círculo y acaban justo en los postes (antes se saltaban paneles enteros y el hueco
##     quedaba con bordes al azar, con la caja del portón metida 1,4 m por dentro del círculo);
##   · sin escalones: cada panel se clava en el punto MÁS BAJO que pisa (nunca flota) y su punta sigue una línea suavizada a lo largo del
##     círculo (antes cada panel tomaba la altura de su casilla y saltaba al cambiar de casilla);
##   · sin la franja de sombra al pie (en los desniveles se metía en el suelo y dejaba cuñas claras); el travesaño de abajo queda enterrado;
##   · paneles algo solapados y alternos hacia dentro y hacia fuera, para que los travesaños no se corten entre panel y panel;
##   · la cancela: dos hojas de la misma valla modular de Meshy (valla_cancela) entre dos postes más altos (valla_esquina). Cerrada,
##     una caja invisible con su forma cierra el paso; `abrir_porton(true)` las gira hacia dentro.
const VALLA_PANEL := 1.15        # ancho de cada panel en el círculo (media casilla: curva suave con paneles planos)
const VALLA_ALTO := 2.5          # alto de la valla sobre el suelo
const VALLA_SOLAPE := 1.10       # cada panel, un 10 % más ancho que su trozo de círculo (los travesaños se montan, no se cortan)
const VALLA_HUNDIDO := 0.22      # cuánto se clava cada panel bajo el punto más bajo que pisa
const VALLA_SUAVIZADO := 3       # paneles a cada lado con los que se promedia la línea de las puntas
const VALLA_LADEO := 1.2         # grados de cabeceo al azar de cada panel (clavados a mano); 1 de cada 20, el doble
const PUERTA_ANCHO := 2.3        # vano de la cancela (una casilla: el camino)
const PUERTA_ALTO := 2.25        # alto de cada hoja
const PUERTA_GIRO := 86.0        # grados que gira cada hoja al abrirse, hacia dentro
const PUERTA_TIEMPO := 1.1       # segundos que tarda en abrirse
const PUERTA_RETARDO := 0.35     # el guardia habla y, un instante después, empuja
const POSTE_ANCHO := 0.62        # postes de la cancela (valla_esquina, más altos que la valla)
const POSTE_ALTO := 3.05


func _empalizada_circular() -> void:
	var raiz := get_node_or_null("Nivel_MonteSumicio/Piezas/Empalizada") as Node3D
	if raiz == null or raiz.get_child_count() < 8:
		return
	var tramos: Array[Node3D] = []
	var celdas := {}
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for t in raiz.get_children():
		if t is Node3D and t.has_meta("bloquea_casilla"):
			tramos.append(t)
			var p: Vector3 = t.global_position
			minimo = Vector2(minf(minimo.x, p.x), minf(minimo.y, p.z))
			maximo = Vector2(maxf(maximo.x, p.x), maxf(maximo.y, p.z))
	var malla_a := _pieza_valla("tramo_a")
	var malla_b := _pieza_valla("tramo_b")
	if malla_a == null or malla_b == null:
		return
	var centro := (minimo + maximo) * 0.5
	var c3 := Vector3(centro.x, 0.0, centro.y)
	# Un poco más que medio lado: el círculo inscrito justo cortaba la forja del este.
	var lado := minf(maximo.x - minimo.x, maximo.y - minimo.y) * 0.5
	var radio := lado + Terreno3D.casilla * 0.6
	# Celdas del cuadrado que eran valla: las que faltan en su perímetro son huecos (el portón).
	for t in tramos:
		celdas[celda(t)] = t
	for t in tramos:
		t.visible = false
		# Los tramos a cada lado del portón siguen bloqueando (invisibles): si no, entre el cuadrado y el círculo, que es algo mayor,
		# se podría rodear el portón sin pasar por él.
		var c := celda(t)
		var junto_al_porton := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not celdas.has(c + d) and celdas.has(c + d * 2):
				junto_al_porton = true
		if not junto_al_porton:
			t.remove_meta("bloquea_casilla")
	var curva := Node3D.new()
	curva.name = "EmpalizadaCircular"
	raiz.add_child(curva)
	# El hueco, en la dirección del portón. Los paneles van de poste a poste por el resto del círculo.
	var hacia := porton.global_position - c3
	var ang_puerta := atan2(hacia.x, -hacia.z)
	var medio_hueco := (PUERTA_ANCHO + POSTE_ANCHO) * 0.5 / radio        # del centro del vano al centro de cada poste
	var arco := TAU - 2.0 * medio_hueco
	var n := int(ceil(arco * radio / VALLA_PANEL))
	var paso := arco / float(n)
	var cuerda := 2.0 * radio * sin(paso * 0.5)
	var y_defecto := porton.global_position.y
	# Alturas: lo más bajo que pisa cada panel (sus dos extremos y el centro) y el suelo en su centro, para la línea de las puntas.
	var bajo := PackedFloat32Array()
	var medio := PackedFloat32Array()
	for i in range(n):
		var a := ang_puerta + medio_hueco + paso * (float(i) + 0.5)
		var m := INF
		for k: float in [-0.5, 0.0, 0.5]:
			m = minf(m, _suelo_en(_en_circulo(c3, radio, a + paso * k), y_defecto))
		bajo.append(m)
		medio.append(_suelo_en(_en_circulo(c3, radio, a), y_defecto))
	# La base también va suavizada (si no, los travesaños saltan donde cambia el suelo), pero nunca por encima de lo más bajo que pisa.
	var minimos := PackedFloat32Array()
	for i in range(n):
		var m := INF
		for j in range(maxi(0, i - 2), mini(n - 1, i + 2) + 1):
			m = minf(m, bajo[j])
		minimos.append(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1411
	var celdas_valla := {}
	for i in range(n):
		var a := ang_puerta + medio_hueco + paso * (float(i) + 0.5)
		# Punta: el suelo medio de los vecinos (sin cruzar la cancela, que corta el anillo) más el alto de la valla.
		var suma := 0.0
		var suma_base := 0.0
		var cuenta := 0
		for j in range(maxi(0, i - VALLA_SUAVIZADO), mini(n - 1, i + VALLA_SUAVIZADO) + 1):
			suma += medio[j]
			suma_base += minimos[j]
			cuenta += 1
		var base := minf(bajo[i], suma_base / float(cuenta)) - VALLA_HUNDIDO
		var punta := maxf(suma / float(cuenta) + VALLA_ALTO, bajo[i] + VALLA_ALTO * 0.85)
		var p := _en_circulo(c3, radio, a)
		var fuera := (p - c3).normalized()
		p += fuera * (0.03 if i % 2 == 0 else -0.03)       # alternos: los solapes no parpadean
		p.y = base
		var malla: Mesh = malla_a if i % 2 == 0 else malla_b
		var bb := malla.get_aabb()
		var mi := MeshInstance3D.new()
		mi.mesh = malla
		mi.material_override = VallaMadera.material(malla)
		curva.add_child(mi)
		mi.global_position = p
		var ladeo := VALLA_LADEO * (2.0 if rng.randf() < 0.05 else 1.0)
		mi.rotation = Vector3(deg_to_rad(rng.randf_range(-ladeo, ladeo)), -a, deg_to_rad(rng.randf_range(-ladeo * 0.6, ladeo * 0.6)))   # la cara, tangente al círculo
		mi.scale = Vector3(cuerda * VALLA_SOLAPE / bb.size.x, (punta - base) / bb.size.y, VALLA_PANEL / bb.size.x)
		var c := Terreno3D.celda_de(p)
		celdas_valla[c] = true
		Terreno3D.bloquear_celda_completa(c)
	_cancela(curva, c3, radio, ang_puerta, medio_hueco, y_defecto, celdas_valla)
	print("Empalizada circular: centro %s, radio %.1f m, %d paneles, cancela a %.0f°" % [centro, radio, n, rad_to_deg(ang_puerta)])


## Los dos postes y las dos hojas de la cancela, en el hueco del círculo. Las hojas cuelgan de una bisagra cada una (`_hojas`):
## la de la izquierda (vista desde fuera, a la derecha) gira con Y negativa y la otra con Y positiva, las dos hacia dentro del castro.
func _cancela(padre: Node3D, c3: Vector3, radio: float, ang: float, medio_hueco: float, y_defecto: float, celdas_valla: Dictionary) -> void:
	var hoja := _pieza_valla("cancela")
	var poste := _pieza_valla("esquina")
	if hoja == null or poste == null:
		return
	var puerta := Node3D.new()
	puerta.name = "Cancela"
	padre.add_child(puerta)
	var p := _en_circulo(c3, radio, ang)
	p.y = _suelo_en(p, y_defecto)
	puerta.global_position = p
	puerta.rotation.y = -ang          # X local: a lo largo del círculo; +Z local: hacia dentro
	# Postes: en cada borde del vano, clavados como la valla y más altos que ella.
	var bp := poste.get_aabb()
	for lado: float in [-1.0, 1.0]:
		var a := ang + lado * medio_hueco
		var q := _en_circulo(c3, radio, a)
		var suelo := minf(_suelo_en(q, y_defecto), p.y)
		var mi := MeshInstance3D.new()
		mi.name = "Poste"
		mi.mesh = poste
		mi.material_override = VallaMadera.material(poste)
		padre.add_child(mi)
		mi.global_position = Vector3(q.x, suelo - VALLA_HUNDIDO, q.z)
		mi.rotation.y = -a
		mi.scale = Vector3(POSTE_ANCHO / bp.size.x, (POSTE_ALTO + VALLA_HUNDIDO) / bp.size.y, POSTE_ANCHO * 0.8 / bp.size.z)
	# Hojas: el modelo trae los goznes a la izquierda (x mínima) y la cara buena hacia +Z; aquí la cara buena mira hacia fuera (−Z local).
	var bh := hoja.get_aabb()
	var media := PUERTA_ANCHO * 0.5
	var esc := Vector3((media + 0.02) / bh.size.x, PUERTA_ALTO / bh.size.y, VALLA_PANEL / bh.size.x)
	_hojas.clear()
	for lado: float in [-1.0, 1.0]:
		var bisagra := Node3D.new()
		bisagra.name = "BisagraIzquierda" if lado < 0.0 else "BisagraDerecha"
		puerta.add_child(bisagra)
		bisagra.position = Vector3(lado * media, 0.03, 0.0)
		var mi := MeshInstance3D.new()
		mi.name = "Hoja"
		mi.mesh = hoja
		mi.material_override = VallaMadera.material(hoja)
		bisagra.add_child(mi)
		mi.position = Vector3(-lado * media * 0.5, 0.0, 0.0)
		if lado < 0.0:
			mi.scale = Vector3(esc.x, esc.y, -esc.z)          # espejo en Z: goznes en la bisagra, cara buena hacia fuera
		else:
			mi.rotation.y = PI                               # media vuelta: goznes a la derecha, cara buena hacia fuera
			mi.scale = esc
		_hojas.append(bisagra)
	# La caja vieja del portón ya no se ve: la cancela la sustituye (el nodo sigue marcando el sitio y la casilla del guardia).
	porton.get_node("Bisagra").visible = false
	# Choque: una caja invisible con la forma de la cancela cerrada, sobre las casillas del vano que no son ya valla.
	_choque_puerta = MeshInstance3D.new()
	_choque_puerta.name = "ChoqueCancela"
	var caja := BoxMesh.new()
	caja.size = Vector3(PUERTA_ANCHO, 1.6, 0.36)
	_choque_puerta.mesh = caja
	_choque_puerta.layers = 0
	_choque_puerta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puerta.add_child(_choque_puerta)
	_choque_puerta.position = Vector3(0.0, 0.8, 0.0)
	_celdas_puerta.clear()
	for k in range(-4, 5):
		var c := Terreno3D.celda_de(puerta.to_global(Vector3(media * float(k) / 4.0, 0.0, 0.0)))
		if not celdas_valla.has(c) and not _celdas_puerta.has(c):
			_celdas_puerta.append(c)
			Terreno3D.bloquear_contorno(c, _choque_puerta)
	_puerta_abierta = false


static func _en_circulo(c3: Vector3, radio: float, a: float) -> Vector3:
	return Vector3(c3.x + sin(a) * radio, 0.0, c3.z - cos(a) * radio)


## Altura del suelo bajo `p` (la de su casilla); si no tiene sentido (fuera del mapa, vacío), `defecto`.
static func _suelo_en(p: Vector3, defecto: float) -> float:
	var y := Terreno3D.y_pies(Terreno3D.celda_de(p))
	return y if is_finite(y) and absf(y - defecto) < 4.0 else defecto


static func _pieza_valla(nombre: String) -> Mesh:
	var ruta := "res://arte/meshy/piezas/valla_%s.res" % nombre
	return load(ruta) if ResourceLoader.exists(ruta) else null


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

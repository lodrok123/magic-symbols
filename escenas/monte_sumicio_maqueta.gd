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
var _choque_puerta: StaticBody3D           ## el cuerpo de la cancela cerrada (se quita al abrir)
var _puerta_abierta := false
var _anillo := {}                           ## la empalizada: centro, radio, ángulo de la cancela y medio hueco (para la vegetación)
const Vegetacion = preload("res://escenas/monte_sumicio_vegetacion.gd")


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
	_solidos_por_malla()
	for casa in casas():
		bisagra(casa).position += Vector3(0.03, 0.0, -0.04)
	var entrada := SalidaNivel3D.EntradaNivel3D.new()
	entrada.preparar(celda(inicio), "desde_fraga", "n")
	get_parent().add_child(entrada)
	_sembrar_vegetacion.call_deferred()      # con el suelo ya vestido (rampas) y la hierba del nivel creada


## Hierba alta, rocas y matas al pie de la valla, de las casas y del empedrado (escenas/monte_sumicio_vegetacion.gd).
func _sembrar_vegetacion() -> void:
	var evitar: Array[Vector3] = [guardia.global_position, caco.global_position, cofre.global_position, inicio.global_position,
		marimanta.global_position, porton.global_position]
	for paso in escolta.get_children():
		evitar.append((paso as Node3D).global_position)
	Vegetacion.sembrar(self, get_parent(), _anillo, casas(), torre, evitar)


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
	if _choque_puerta != null:
		_choque_puerta.queue_free()
		_choque_puerta = null
		_rehacer_solidez()
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


## ¿Cierra la cancela el paso? Lo que vería el cuerpo de Mid (una esfera de su radio) en el centro del vano, a la altura de la cintura.
func cancela_cierra() -> bool:
	var cancela := find_child("Cancela", true, false) as Node3D
	if cancela == null:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var bola := SphereShape3D.new()
	bola.radius = Terreno3D.FuenteSolidez.RADIO_CUERPO
	q.shape = bola
	q.collision_mask = Terreno3D.CAPA_SOLIDO
	q.transform = Transform3D(Basis(), cancela.global_position + Vector3.UP * 0.6)
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## La cancela ya no tiene cuerpo: en cuanto la física lo note, la fuente de solidez vuelve a medir las casillas (solo si ya manda la colisión
## real; antes de eso, `_activar_solidez_por_nodos` mide todo por primera vez).
func _rehacer_solidez() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var f := Terreno3D.fuente as Terreno3D.FuenteNodos
	if f != null:
		f.reconstruir()


# ---------- Solidez por MALLA (14/11, Pablo: «cuando horneas el nivel las colisiones son por casilla; ponlas TODAS por malla, hay muchos
# muros invisibles») ----------
# Antes cada pieza marcada `bloquea_casilla` cerraba su casilla entera (2,3 u): la empalizada, el portón, los árboles, el obrador y la torre, y
# además unos tramos invisibles del cuadrado viejo junto al portón. Ahora cada una lleva un cuerpo en la capa de lo sólido medido sobre su
# modelo (ColisionPieza: la franja donde toca el cuerpo, con sus huecos), y Monte Sumicio usa la solidez por colisión real
# (monte_sumicio_mundo._activar_solidez_por_nodos). Hechizos, enemigos y rutas siguen viendo casillas (las que la forma cubre por el centro).
const TOPE_EDIFICIO := 1.0     ## los edificios chocan hasta la cintura de Mid: por encima, los aleros de paja y los balcones, que no son obstáculo
## Hueco de la puerta de la torre (x −0,70..0,63, cara en z ≈ 3,62; ver monte_sumicio_visita.HUECO_TORRE): una tabla de choque justo por dentro.
const PUERTA_TORRE_CHOQUE := Vector3(-0.035, 0.0, 3.50)
## El vano de esa puerta en planta (x, z, ancho, fondo), que se recorta de la malla antes de medirla: el marco de piedra sobresale casi 1 u y los
## cascos de los dos lados se unían por delante tapando la entrada (Mid se quedaba a 1,2 de la puerta y no podía cruzarla).
const VANO_TORRE := Rect2(-0.75, 2.6, 1.43, 2.5)


func _solidos_por_malla() -> void:
	var n := 0
	var sueltas: Array[String] = []
	for casa in casas():
		n += _cuerpo_de_modelo(casa, casa.get_node("Modelo"), "contorno", TOPE_EDIFICIO)
	n += _cuerpo_de_modelo(torre, torre.get_node("Modelo"), "contorno", TOPE_EDIFICIO, VANO_TORRE)
	var tabla := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.4, 1.6, 0.2)
	tabla.shape = caja
	tabla.position = PUERTA_TORRE_CHOQUE + Vector3.UP * 0.8
	var cuerpo_torre := torre.get_node_or_null("Solido") as StaticBody3D
	if cuerpo_torre != null:
		cuerpo_torre.add_child(tabla)
	n += _cuerpo_de_modelo(obrador, obrador.get_node("Modelo"), "contorno", TOPE_EDIFICIO)
	# El resto de piezas marcadas: árboles (su tronco) y lo que se añada en el editor (su contorno). Los muros de ayuda de los edificios, los
	# tramos del cuadrado de la empalizada y el portón no: ya tienen su cuerpo (el edificio, el círculo, la cancela).
	for pieza in $Nivel_MonteSumicio/Piezas.find_children("*", "Node3D", true, false):
		if not pieza.has_meta("bloquea_casilla") or pieza == porton:
			continue
		var padre := pieza.get_parent()
		if padre == torre or padre == obrador or padre.name == "Empalizada" or padre.get_parent() == casas()[0].get_parent():
			continue
		var hecho := _cuerpo_de_modelo(pieza, pieza, "tronco" if padre.name == "Arboles" else "contorno", ColisionPieza.BANDA_MAX)
		if hecho == 0:
			Terreno3D.bloquear_celda_completa(celda(pieza))      # sin malla que medir: la casilla, como antes
			sueltas.append(String(pieza.name))
		n += hecho
	print("Monte Sumicio: %d cuerpos medidos sobre su malla%s" % [n, (" · por casilla (sin malla): %s" % ", ".join(sueltas)) if not sueltas.is_empty() else ""])


## Un cuerpo «Solido» (capa de lo sólido) en `pieza` con los cascos medidos sobre las mallas visibles de `malla` (la propia pieza o su «Modelo»).
## Los cascos van en el espacio de `pieza` con la base en su origen. Devuelve 1 si lo puso, 0 si no había nada que medir.
func _cuerpo_de_modelo(pieza: Node3D, malla: Node3D, modo: String, tope: float, vano := Rect2()) -> int:
	var tris := PackedVector3Array()
	if malla == pieza:
		for h in pieza.get_children():
			if h is Node3D and (h as Node3D).visible and not h.has_meta("bloquea_casilla"):
				tris.append_array(ColisionPieza._triangulos(h, Transform3D.IDENTITY))
	else:
		tris = ColisionPieza._triangulos(malla, Transform3D.IDENTITY)
	if vano.has_area():
		# Fuera los triángulos cuyo centro cae en el vano (en planta): así el hueco de la puerta separa los trozos de cada lado.
		var quedan := PackedVector3Array()
		for i in range(0, tris.size() - 2, 3):
			var m := (tris[i] + tris[i + 1] + tris[i + 2]) / 3.0
			if not vano.has_point(Vector2(m.x, m.z)):
				quedan.append_array([tris[i], tris[i + 1], tris[i + 2]])
		tris = quedan
	var lista := ColisionPieza.cascos_triangulos(tris, modo, ColisionPieza.BANDA_MIN, tope)
	if lista.is_empty():
		return 0
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Solido"
	cuerpo.collision_layer = Terreno3D.CAPA_SOLIDO
	cuerpo.collision_mask = 0
	cuerpo.add_to_group("bloquea")
	for nube in lista:
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = nube
		cs.shape = sh
		cuerpo.add_child(cs)
	pieza.add_child(cuerpo)
	return 1


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
const VALLA_GROSOR := 0.3      ## grosor del choque de cada panel (las estacas miden ~0,25 de fondo)


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
		# 14/11: los tramos del cuadrado ya no bloquean nada (antes los de junto al portón seguían cerrando su casilla, invisibles): el círculo
		# está cerrado por sus propios cuerpos y la cancela.
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
	# 14/11: el choque de la valla, un cuerpo con una caja fina por panel (lo que se ve), no las casillas que pisa.
	var solido := StaticBody3D.new()
	solido.name = "SolidoValla"
	solido.collision_layer = Terreno3D.CAPA_SOLIDO
	solido.collision_mask = 0
	curva.add_child(solido)
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
		var alto_suelo_max := maxf(medio[i], bajo[i])
		for k: float in [-0.5, 0.5]:
			alto_suelo_max = maxf(alto_suelo_max, _suelo_en(_en_circulo(c3, radio, a + paso * k), y_defecto))
		_caja_solida(solido, Vector3(p.x, 0.0, p.z), -a, Vector2(cuerda, VALLA_GROSOR), bajo[i] - 0.1, alto_suelo_max + ColisionPieza.BANDA_MAX)
	_cancela(curva, c3, radio, ang_puerta, medio_hueco, y_defecto, solido)
	_anillo = {"centro": c3, "radio": radio, "puerta": ang_puerta, "medio_hueco": medio_hueco}
	print("Empalizada circular: centro %s, radio %.1f m, %d paneles, cancela a %.0f°" % [centro, radio, n, rad_to_deg(ang_puerta)])


## Los dos postes y las dos hojas de la cancela, en el hueco del círculo. Las hojas cuelgan de una bisagra cada una (`_hojas`):
## la de la izquierda (vista desde fuera, a la derecha) gira con Y negativa y la otra con Y positiva, las dos hacia dentro del castro.
func _cancela(padre: Node3D, c3: Vector3, radio: float, ang: float, medio_hueco: float, y_defecto: float, solido: StaticBody3D) -> void:
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
		_caja_solida(solido, Vector3(q.x, 0.0, q.z), -a, Vector2(POSTE_ANCHO, POSTE_ANCHO * 0.8), suelo - 0.1, suelo + ColisionPieza.BANDA_MAX)
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
	# Choque: un cuerpo propio con la forma de la cancela cerrada (se quita al abrir; `abrir_porton`).
	_choque_puerta = StaticBody3D.new()
	_choque_puerta.name = "SolidoCancela"
	_choque_puerta.collision_layer = Terreno3D.CAPA_SOLIDO
	_choque_puerta.collision_mask = 0
	padre.add_child(_choque_puerta)
	_caja_solida(_choque_puerta, Vector3(p.x, 0.0, p.z), -ang, Vector2(PUERTA_ANCHO, VALLA_GROSOR + 0.06), p.y - 0.1, p.y + ColisionPieza.BANDA_MAX)
	_puerta_abierta = false


## Una caja de choque en `cuerpo`: centrada en `en` (x, z), girada `giro` en Y, de `planta` (largo a lo largo, grosor) y de `y0` a `y1`.
static func _caja_solida(cuerpo: StaticBody3D, en: Vector3, giro: float, planta: Vector2, y0: float, y1: float) -> void:
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(planta.x, maxf(y1 - y0, 0.2), planta.y)
	cs.shape = caja
	cuerpo.add_child(cs)
	cs.global_transform = Transform3D(Basis(Vector3.UP, giro), Vector3(en.x, (y0 + y1) * 0.5, en.z))


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

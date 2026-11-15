extends SceneTree
## Prueba del GREMIO DEL GORRO VERDE, la quinta palloza de Monte Sumicio (14/11/2026), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_gremio_sumicio.gd
## 1. La palloza está en el poblado, con su modelo y su bisagra, apoyada a la misma altura que las otras cuatro y sin pisarlas.
## 2. `casas()` devuelve cinco y la quinta es el gremio, emparejada con el interior que tiene `gremio = true`.
## 3. Su sala se pisa: está fuera de lo horneado del nivel y se pinta su suelo al montarla (si no, Mid se queda clavada en la puerta).
## 4. Dentro hay obrador, armero y botín, y NO hay cofre de familia ni animales (no es una casa).
## 5. El del gorro verde está dentro de la sala, no en el muro, y lleva el gorro verde.
## 6. El trueque: la tienda «gremio» ofrece cosas y compra lo que le sobra a Mid.
## 7. Se entra por su puerta como en las demás pallozas (con el uniforme ya recogido).

const Interior = preload("res://escenas/interior_palloza.gd")

var _fallos := 0
var _f := 0
var _paso := 0
var _espera := 0
var _casa: Node3D
var _sala: Node3D


func _initialize() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	# Con la admisión y el uniforme ya hechos, el poblado está abierto y las puertas de las pallozas se cruzan.
	Flags.i().poner("montesumicio.torre.admitida")
	Flags.i().poner("montesumicio.torre.uniforme_recogido")
	change_scene_to_file("res://escenas/PruebaMonteSumicio.tscn")


func _ok(cond: bool, texto: String) -> void:
	print(("OK    " if cond else "FALLO ") + texto)
	if not cond:
		_fallos += 1


func _process(_d: float) -> bool:
	_f += 1
	if _f < 90:
		return false
	_f = 0
	match _paso:
		0:
			_fuera()
		1:
			_sala_por_dentro()
		2:
			_trueque()
		3:
			if not _entrar_por_la_puerta():
				return false
		4:
			print("\n%d fallo(s)" % _fallos)
			quit(1 if _fallos > 0 else 0)
			return true
	_paso += 1
	return false


## 1 y 2 · la palloza en el poblado
func _fuera() -> void:
	var maqueta: Node = current_scene.get_node("Maqueta")
	var casas: Array = maqueta.casas()
	_ok(casas.size() == 5, "el poblado tiene cinco pallozas (%d)" % casas.size())
	if casas.size() < 5:
		_paso = 3
		return
	_casa = casas[4] as Node3D
	_ok(String(_casa.name) == "Gremio", "la quinta es el gremio («%s»)" % _casa.name)
	_ok(_casa.get_node_or_null("Modelo") != null, "tiene su modelo (de ahí sale su choque por malla)")
	_ok(maqueta.bisagra(_casa) != null, "tiene bisagra de puerta, como las demás")
	_ok(_casa.get_node_or_null("FondoVano") != null, "tiene el fondo de vano en penumbra")
	_ok(_casa.get_node_or_null("Solido") != null, "su choque se midió sobre la malla")
	# Apoyada a la misma altura que las otras cuatro.
	var y_otras: float = (casas[0] as Node3D).position.y
	_ok(absf(_casa.position.y - y_otras) < 0.01, "se apoya a la altura de las demás (%.3f vs %.3f)" % [_casa.position.y, y_otras])
	# Sin pisar a ninguna otra pieza del poblado: la separación mínima que guardan las cuatro de la escena es 3,6 casillas.
	var mia: Vector2i = Terreno3D.celda_de(_casa.global_position)
	var cerca: Array[String] = []
	for otra in [casas[0], casas[1], casas[2], casas[3], maqueta.torre, maqueta.obrador, maqueta.porton]:
		var c: Vector2i = Terreno3D.celda_de((otra as Node3D).global_position)
		var d := Vector2(mia - c).length()
		if d < 3.0:
			cerca.append("%s a %.1f casillas" % [(otra as Node3D).name, d])
	_ok(cerca.is_empty(), "no se pisa con ninguna otra pieza %s" % str(cerca))
	# El interior emparejado es el del gremio (la visita asocia casas()[i] con el hijo i de Interiores).
	var habitaciones: Array = current_scene.get_node("Interiores").get_children()
	_ok(habitaciones.size() >= 6, "hay interior para las cinco pallozas y la torre (%d)" % habitaciones.size())
	_sala = habitaciones[4] as Node3D
	_ok(bool(_sala.gremio), "el quinto interior es el del gremio")
	_ok(not bool(_sala.tienda) and not bool(_sala.casa_brais), "y no es tienda ni casa de familia")


## 3, 4 y 5 · la sala por dentro
func _sala_por_dentro() -> void:
	if _sala == null:
		return
	var centro: Vector2i = _sala.centro
	# La sala está más allá de lo horneado: sin pintar su suelo, no se pisaría ninguna casilla.
	var pisables := 0
	var con_suelo := 0
	for z in range(-2, 3):
		for x in range(-2, 3):
			var c: Vector2i = centro + Vector2i(x, z)
			if not Terreno3D.letra_de(c).strip_edges().is_empty():
				con_suelo += 1
			if Terreno3D.pisable(c, 0, true, 9, false):
				pisables += 1
	_ok(con_suelo == 25, "las 25 casillas de la sala tienen suelo (%d)" % con_suelo)
	_ok(pisables >= 8, "se pisa dentro de la sala (%d casillas; el muro y los muebles cierran el resto)" % pisables)
	_ok(Terreno3D.pisable(centro + Interior.SALIDA, 0, true, 9, false), "el umbral de la puerta se pisa")
	# La casilla donde está la figura la bloquea la propia figura, igual que en las otras pallozas: se compara con una de familia.
	var otra: Node3D = current_scene.get_node("Interiores").get_children()[0] as Node3D
	_ok(Terreno3D.pisable(centro + Interior.VECINO, 0, true, 9, false)
		== Terreno3D.pisable((otra.centro as Vector2i) + Interior.VECINO, 0, true, 9, false),
		"la casilla del gorro verde se comporta como la del vecino de una palloza de familia")
	# El mobiliario del gremio, por sus rótulos (son los que se leen dentro).
	var rotulos: Array[String] = []
	for n in _sala.find_children("*", "Label3D", true, false):
		rotulos.append(String((n as Label3D).text))
	for que in ["Obrador", "Armero", "Botín"]:
		_ok(rotulos.has(que), "dentro está el %s" % que.to_lower())
	for que in ["Ástrago", "Travariza", "Mostrador", "Síntesis"]:
		_ok(not rotulos.has(que), "no tiene «%s» (no es casa de familia ni tienda)" % que)
	_ok(_sala.find_children("Valla*", "MeshInstance3D", true, false).is_empty(), "no tiene la valla de los animales")
	# La figura del gorro verde: dentro de la sala y no en el muro.
	var gorro := _sala.get_node_or_null("Gorro verde") as Node3D
	_ok(gorro != null, "el del gorro verde está en la sala")
	if gorro != null:
		var c := Terreno3D.celda_de(gorro.global_position)
		_ok(_sala.contiene(c), "está dentro de la sala (casilla %s)" % c)
		var verde := false
		for m in gorro.find_children("*", "MeshInstance3D", true, false):
			var mat := (m as MeshInstance3D).get_active_material(0) as ShaderMaterial
			if mat != null and mat.get_shader_parameter("tenir_gorro"):
				var tinte: Color = mat.get_shader_parameter("gorro")
				verde = tinte.g > tinte.r and tinte.g > tinte.b
		_ok(verde, "lleva el gorro verde")
	var habitantes := _sala.get_node("Habitantes")
	_ok(habitantes.get_child_count() == 3, "el gremio reúne a cuatro miembros, incluido quien atiende el trueque")


## 6 · el trueque
func _trueque() -> void:
	var oferta: Array = Tiendas.oferta("gremio")
	_ok(not oferta.is_empty(), "el trueque ofrece %d cosas" % oferta.size())
	var tiene_humo := false
	for fila in oferta:
		if String((fila as Dictionary)["objeto"]) == "bomba_humo":
			tiene_humo = true
	_ok(tiene_humo, "entre ellas la bomba de humo, que es su herramienta")
	# Y compra lo que le sobra a Mid (la venta es la misma de cualquier tienda).
	var e := Estado.i()
	e.agregar("resina")
	var oro_antes: int = e.oro
	var vendido: bool = Tiendas.vender("gremio", "resina", 1, e)
	_ok(vendido, "el gremio compra la resina de Mid")
	_ok(e.oro > oro_antes, "y paga por ella (%d → %d de oro)" % [oro_antes, e.oro])


## 7 · entrar por la puerta
func _entrar_por_la_puerta() -> bool:
	var v: Node = current_scene.get_node("Visita")
	if _casa == null:
		_ok(false, "sin palloza del gremio no se puede entrar")
		return true
	if v._interior == null or v._en_transicion:
		var mid: Node3D = v._mid
		var destino: Vector3 = _casa.to_global(v._hueco_puerta(_casa) + Vector3(0, 0, 0.1))
		mid.position = destino
		(mid.get("pj") as Node3D).position = destino
		_espera += 1
		if _espera > 400:
			_ok(false, "la puerta del gremio no lleva a su sala")
			return true
		return false
	_ok(bool(v._interior.gremio), "la puerta del gremio lleva a su sala")
	# Junto al del gorro verde, la pista ofrece el trueque (y no el cofre de las casas de familia).
	var c: Vector2i = v._interior.centro + Interior.VECINO
	var mid: Node3D = v._mid
	mid.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	(mid.get("pj") as Node3D).position = mid.position
	_ok(v._pista_interior() == "[E] Trueque", "la pista junto al gorro verde es el trueque («%s»)" % v._pista_interior())
	var cofre: Vector2i = v._interior.centro + Interior.COFRE
	mid.position = Terreno3D.centro_de(cofre, Terreno3D.y_pies(cofre))
	(mid.get("pj") as Node3D).position = mid.position
	_ok(not v._cofre_al_alcance(), "donde las casas tienen el cofre, el gremio no tiene nada que abrir")
	return true

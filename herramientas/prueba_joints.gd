extends "res://herramientas/escenario_base.gd"
## JOINTS (tiras de transición entre suelos, docs/PLAN_EOW_VISUAL.md §1 punto 3, 22/10). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_joints.gd
## HONESTO: en headless no hay GPU; esto prueba el DATO que alimenta las tiras (`joints_aristas()`: qué aristas entre casillas son frontera de suelos
## distintos y se pintan), la tabla de pares, lo que recibe el shader (uniforms y `mapa_fuera`) y que el interruptor no toca nada más. CÓMO SE VE la tira
## (corte por ruido, migas, matas, estados encima) se mide con `captura_joints.gd` (con ventana).
##
##   1  tabla: los seis pares de suelos están en `JOINTS_PARES`, con ancho y amplitud positivos, y el shader recibe esos valores
##   2  aristas: hay tiras solo entre suelos distintos (la clave del par sale de los dos tipos), solo entre suelo llano (nunca agua, cauce seco ni hueco),
##      y coinciden con un recuento independiente hecho por letras
##   3  `mapa_fuera` marca exactamente el agua, el cauce seco y los huecos (lo que apaga las tiras junto a ellos)
##   4  interruptor: `joints_suelo = false` no deja aristas y el uniform `joints_fuerza` vale 0; true = 1
##   5  nada más cambia: mismas colisiones, mismo `Terreno3D.alturas` y mapa, mismos nodos de dibujo (sin mallas ni llamadas nuevas), mismo tipo de suelo por casilla

const ESCENAS: Dictionary = {"bosque": "res://escenas/PruebaBosque01.tscn", "lab": "res://laboratorios/LabPlaytestEoW.tscn"}


func _escenario() -> void:
	for k in ESCENAS.keys():
		var con: Dictionary = await _montar(String(ESCENAS[k]), true)
		_tabla(k, con["m"])
		_aristas(k, con["m"])
		_mapa_fuera(k, con["m"])
		con["aristas"] = (con["m"] as Node).call("joints_aristas").size()
		con["uniform"] = float(((con["m"] as Node).get("_mat_suelo") as ShaderMaterial).get_shader_parameter("joints_fuerza"))
		(con["m"] as Node).queue_free()
		await avanzar(3)
		var sin: Dictionary = await _montar(String(ESCENAS[k]), false)
		sin["aristas"] = (sin["m"] as Node).call("joints_aristas").size()
		sin["uniform"] = float(((sin["m"] as Node).get("_mat_suelo") as ShaderMaterial).get_shader_parameter("joints_fuerza"))
		_interruptor(k, con, sin)
		_nada_mas(k, con, sin)
		(sin["m"] as Node).queue_free()
		await avanzar(3)


## Monta la escena con el interruptor en `joints` y devuelve la maqueta con una foto de lo que no debe cambiar.
func _montar(ruta: String, joints: bool) -> Dictionary:
	var m: Node = (load(ruta) as PackedScene).instantiate()
	m.set("joints_suelo", joints)
	root.add_child(m)
	await avanzar(30)
	var tipos: Array = []
	var lado: int = int(m.get("_lado"))
	for y in range(lado):
		for x in range(lado):
			tipos.append(int(m.call("_tipo_suelo", Vector2i(x, y))))
	return {"m": m, "colisiones": _contar(m, "col"), "dibujo": _contar(m, "mesh"), "alturas": Terreno3D.alturas.hash(), "mapa": hash(Terreno3D.mapa),
		"lado": Terreno3D.lado_del_mapa(), "tipos": hash(tipos)}


func _contar(n: Node, que: String) -> int:
	var k: int = 0
	for h in n.get_children():
		if que == "col" and (h is CollisionObject3D or h is CollisionShape3D):
			k += 1
		if que == "mesh" and (h is MeshInstance3D or h is MultiMeshInstance3D):
			k += 1
		k += _contar(h, que)
	return k


func _tabla(k: String, m: Node) -> void:
	var tabla: Dictionary = m.get("JOINTS_PARES")
	var tipos: Array = m.get("TIPOS_SUELO")
	var faltan: Array = []
	for a in range(tipos.size()):
		for b in range(a + 1, tipos.size()):
			var clave: String = "%s_%s" % [tipos[a], tipos[b]]
			if not tabla.has(clave):
				faltan.append(clave)
	_ok("1.1 [%s] la tabla tiene los 6 pares de suelos" % k, tabla.size() == 6 and faltan.is_empty(), "faltan %s" % [faltan])
	var mal: Array = []
	for clave in tabla.keys():
		var d: Dictionary = tabla[clave]
		if float(d.get("ancho", 0.0)) <= 0.0 or String(d.get("textura", "")) == "" or String(d.get("sobre", "")) == "":
			mal.append(clave)
		if d.has("amp") and (float(d["amp"]) <= 0.0 or float(d["dens"]) <= 0.0 or float(d["escala"]) <= 0.0):
			mal.append(clave)
	_ok("1.2 [%s] cada par tiene textura, quién va encima, ancho positivo y, en las migas, amplitud, densidad y escala" % k, mal.is_empty(), "mal %s" % [mal])
	var mat: ShaderMaterial = m.get("_mat_suelo") as ShaderMaterial
	_ok("1.3 [%s] el material del suelo existe" % k, mat != null)
	if mat == null:
		return
	var ct: Vector4 = mat.get_shader_parameter("joint_ct")
	var d_ct: Dictionary = tabla["camino_tierra"]
	_ok("1.4 [%s] el shader recibe la fila camino_tierra de la tabla" % k, is_equal_approx(ct.x, float(d_ct["ancho"])) and is_equal_approx(ct.y, float(d_ct["amp"])))
	var mm: Vector3 = mat.get_shader_parameter("joint_matas_ancho")
	_ok("1.5 [%s] y el alcance de las matas de hierba sobre camino y piedra" % k, is_equal_approx(mm.x, float(tabla["hierba_camino"]["ancho"])) and is_equal_approx(mm.z, float(tabla["hierba_piedra"]["ancho"])))


func _aristas(k: String, m: Node) -> void:
	var aristas: Array = m.call("joints_aristas")
	var tabla: Dictionary = m.get("JOINTS_PARES")
	var tipos: Array = m.get("TIPOS_SUELO")
	var lado: int = int(m.get("_lado"))
	_ok("2.1 [%s] hay tiras (el nivel tiene fronteras entre suelos)" % k, aristas.size() > 0, "%d aristas" % aristas.size())
	var iguales: int = 0
	var sin_par: int = 0
	var sobre_agua: int = 0
	var clave_mal: int = 0
	var por_par: Dictionary = {}
	for a in aristas:
		if int(a["a"]) == int(a["b"]):
			iguales += 1
		if not tabla.has(String(a["par"])):
			sin_par += 1
		if String(a["par"]) != "%s_%s" % [tipos[mini(int(a["a"]), int(a["b"]))], tipos[maxi(int(a["a"]), int(a["b"]))]]:
			clave_mal += 1
		for c in [a["c"], a["v"]]:
			var l: String = m.call("_letra", c)
			if l == "~" or l == "b" or l == "c" or l == " ":
				sobre_agua += 1
		por_par[a["par"]] = int(por_par.get(a["par"], 0)) + 1
	_ok("2.2 [%s] ninguna tira une dos casillas del mismo suelo" % k, iguales == 0)
	_ok("2.3 [%s] toda tira tiene su par en la tabla y la clave sale de los dos tipos" % k, sin_par == 0 and clave_mal == 0)
	_ok("2.4 [%s] ninguna tira toca agua, cauce seco ni hueco" % k, sobre_agua == 0, "%d casillas" % sobre_agua)
	# Recuento independiente por letras: pares de casillas vecinas (derecha y abajo) de suelo llano con tipos distintos.
	var esperado: int = 0
	for y in range(lado):
		for x in range(lado):
			for v in [Vector2i(1, 0), Vector2i(0, 1)]:
				var c := Vector2i(x, y)
				var d: Vector2i = c + (v as Vector2i)
				if d.x >= lado or d.y >= lado:
					continue
				var l1: String = m.call("_letra", c)
				var l2: String = m.call("_letra", d)
				if l1 == " " or l1 == "c" or l1 == "~" or l1 == "b" or l2 == " " or l2 == "c" or l2 == "~" or l2 == "b":
					continue
				var t1: int = _tipo_pintado(m, c)
				var t2: int = _tipo_pintado(m, d)
				if t1 != t2:
					esperado += 1
	_ok("2.5 [%s] las aristas coinciden con el recuento independiente por letras" % k, esperado == aristas.size(), "%d esperadas · %d" % [esperado, aristas.size()])
	print("      [%s] aristas por par: %s" % [k, por_par])


## Tipo de suelo como lo pinta el mapa (la arena de la orilla junto al agua cuenta como camino).
func _tipo_pintado(m: Node, c: Vector2i) -> int:
	var t: int = int(m.call("_tipo_suelo", c))
	if t == 0 and bool(m.call("_junto_a_agua", c)):
		t = 1
	return t


func _mapa_fuera(k: String, m: Node) -> void:
	var mat: ShaderMaterial = m.get("_mat_suelo") as ShaderMaterial
	var tex: Texture2D = mat.get_shader_parameter("mapa_fuera") as Texture2D if mat != null else null
	_ok("3.1 [%s] el shader recibe `mapa_fuera`" % k, tex != null)
	if tex == null:
		return
	var img: Image = tex.get_image()
	var lado: int = int(m.get("_lado"))
	var mal: int = 0
	var marcadas: int = 0
	for y in range(lado):
		for x in range(lado):
			var l: String = m.call("_letra", Vector2i(x, y))
			var fuera: bool = l == "~" or l == "b" or l == "c" or l == " "
			var v: float = img.get_pixel(x, y).r
			if fuera:
				marcadas += 1
			if (v > 0.5) != fuera:
				mal += 1
	_ok("3.2 [%s] marca agua, cauce seco y huecos y nada más" % k, mal == 0 and img.get_width() == lado, "%d marcadas · %d mal" % [marcadas, mal])


func _interruptor(k: String, con: Dictionary, sin: Dictionary) -> void:
	_ok("4.1 [%s] con `joints_suelo = true` el uniform vale 1" % k, con["uniform"] == 1.0)
	_ok("4.2 [%s] con `joints_suelo = false` el uniform vale 0" % k, sin["uniform"] == 0.0)
	_ok("4.3 [%s] y no deja aristas (con el interruptor puesto sí hay)" % k, sin["aristas"] == 0 and con["aristas"] > 0, "%d · %d" % [con["aristas"], sin["aristas"]])


func _nada_mas(k: String, con: Dictionary, sin: Dictionary) -> void:
	_ok("5.1 [%s] mismas colisiones con y sin tiras" % k, con["colisiones"] == sin["colisiones"], "%d · %d" % [con["colisiones"], sin["colisiones"]])
	_ok("5.2 [%s] mismo Terreno3D (alturas, mapa y lado)" % k, con["alturas"] == sin["alturas"] and con["mapa"] == sin["mapa"] and con["lado"] == sin["lado"])
	_ok("5.3 [%s] mismos nodos de dibujo: las tiras no añaden mallas ni llamadas de dibujado" % k, con["dibujo"] == sin["dibujo"], "%d · %d" % [con["dibujo"], sin["dibujo"]])
	_ok("5.4 [%s] mismo tipo de suelo por casilla (donde crece y arde la hierba no cambia)" % k, con["tipos"] == sin["tipos"])

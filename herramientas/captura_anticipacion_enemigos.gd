extends "res://herramientas/escenario_base.gd"
## ANTICIPACIÓN DEL GÓLEM Y DEL ELEMENTAL (21/11, dirección; regla C22 de docs/PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md: «cada golpe repite su anticipación»).
## ¿El CUERPO anuncia el golpe, además del aviso en el suelo? ¿El golpe cae cuando acaba el aviso? Graba cada ataque desde que sale su aviso (`AvisoAtaque3D`) hasta 0,4 s después
## de que se acabe, un fotograma cada PASO s, recortado alrededor del enemigo, con lo que le queda al aviso escrito en cada foto. Dos ataques de cada uno. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_anticipacion_enemigos.gd -- [carpeta]   (por defecto res://docs/capturas/anticipacion_enemigos)

const PASO: float = 0.1
var _dir: String = "res://docs/capturas/anticipacion_enemigos"


func _aviso_de(dueno: Node) -> AvisoAtaque3D:
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		if (a as AvisoAtaque3D).dueno == dueno and not (a as AvisoAtaque3D).cancelado:
			return a as AvisoAtaque3D
	return null


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "":
		_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	if args.size() > 1 and args[1] == "guerrero":
		await _guerrero()
		return
	await cargar("res://escenas/PruebaSalaGolem.tscn", true)
	if maqueta == null or jugador == null:
		return
	(jugador as Jugador3D).vida = 100000.0
	maqueta.set("_tam_camara", 7.0)
	(maqueta.get("_camara") as Camera3D).size = 7.0
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var g: Node3D = z.nodo("golem_a") as Node3D
	# --- Gólem: la jugadora a su lado, que venga y pegue ---
	colocar_jugador(Vector2i(11, 6))
	await _grabar(g, "golem", 2)
	# Se aparta el gólem lejos y quieto, y se invoca un elemental.
	g.set("quieto", true)
	g.position = Terreno3D.centro_de(Vector2i(14, 1), Terreno3D.y_pies(Vector2i(14, 1)))
	g.set("casa", g.position)
	var el: Combate3D = Combate3D.invocar_elemental(maqueta as Node3D, jugador as Jugador3D, lanzador, Terreno3D.centro_de(Vector2i(6, 6), Terreno3D.y_pies(Vector2i(6, 6))))
	if el == null:
		print("FALLO no se pudo invocar el elemental")
		return
	colocar_jugador(Vector2i(4, 6))
	await _grabar(el, "elemental", 2)


## C25 de PLAN_COMBATE (22/11): el GUERRERO goblin (sin escudo), en la ArenaCombate, con fotos más seguidas (PASO_GUERRERO) para ver el golpe seco.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_anticipacion_enemigos.gd -- res://docs/capturas/<carpeta> guerrero
const PASO_GUERRERO: float = 0.05
var _paso: float = PASO

func _guerrero() -> void:
	await cargar("res://escenas/PruebaArenaCombate.tscn", true)
	if maqueta == null or jugador == null:
		return
	(jugador as Jugador3D).vida = 100000.0
	maqueta.set("_tam_camara", 5.0)
	(maqueta.get("_camara") as Camera3D).size = 5.0
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	for id in ["escudo_a", "escudo_b", "coraza_arena", "limo_brasa_arena"]:
		var n: Node = z.nodo(id) if z != null else null
		if n is Combate3D:
			(n as Combate3D).retirar()
	var c := Vector2i(11, 10)
	var r: Dictionary = {"clase": "combate", "id": "goblin_warrior_chibi", "casa": Terreno3D.centro_de(c, Terreno3D.y_pies(c)), "nombre_nodo": "GuerreroFoto", "nombre": "Goblin guerrero",
		"debil": "", "resiste": "", "fijo": false, "quieto": false, "premia_tinta": true, "suelta_recogibles": false, "puestos_disparo": [], "puesto_cubierto": Vector3.ZERO, "escudo": false, "coraza": ""}
	var g: Combate3D = Combate3D.recrear(r, maqueta as Node3D, jugador as Jugador3D, lanzador)
	if g == null:
		print("FALLO no se pudo crear el guerrero")
		return
	g.health = 1.0e6
	g.vida_max = 1.0e6
	colocar_jugador(c + Vector2i(-1, 0))
	_paso = PASO_GUERRERO
	await _grabar(g, "guerrero", 2)


func _grabar(enemigo: Node3D, nombre: String, veces: int) -> void:
	for vez in range(veces):
		var av: AvisoAtaque3D = null
		var espera: int = 0
		while av == null and espera < 900:
			await process_frame
			espera += 1
			av = _aviso_de(enemigo)
		if av == null:
			print("FALLO %s: no sacó aviso en %d fotogramas" % [nombre, espera])
			return
		var total: float = av.queda()
		print("%s ataque %d: aviso de %.2f s" % [nombre, vez + 1, total])
		var t0: float = reloj.t
		var k: int = 0
		while reloj.t - t0 <= total + 0.4:
			var queda: float = av.queda() if is_instance_valid(av) else 0.0
			await _foto(enemigo, "%s_%d_%02d" % [nombre, vez + 1, k], "t=%.1f s  aviso %.2f" % [reloj.t - t0, queda])
			k += 1
			var t_sig: float = t0 + float(k) * _paso
			while reloj.t < t_sig:
				await process_frame
		await avanzar_s(1.0)


func _foto(enemigo: Node3D, archivo: String, rotulo: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var c: Vector2 = lanzador.camara.unproject_position(enemigo.global_position + Vector3(0.0, 1.0, 0.0))
	var w: int = 460
	var h: int = 400
	var x0: int = clampi(int(c.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(c.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	rec.save_png(_dir.path_join(archivo + ".png"))
	print("foto %s  %s" % [archivo, rotulo])

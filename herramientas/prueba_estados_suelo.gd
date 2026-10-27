extends SceneTree
## B1 de PLAN_EOW (21/10, Juego): EstadosSuelo3D es el ÚNICO dueño del estado del suelo: hecho, intensidad, caducidad,
## transiciones en tabla y la textura (un píxel por casilla). Sin ventana.
##   godot --headless --path . --script res://herramientas/prueba_estados_suelo.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_estados_suelo

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var e := EstadosSuelo3D.new()
	var visto: Array = []
	e.cambio.connect(func(c: Vector2i, est: String, si: bool) -> void: visto.append([c, est, si]))
	var c := Vector2i(3, 4)

	# 1. Poner y leer: tres argumentos, intensidad 1 y la caducidad de `DURA` (27/10: el mojado se seca a los 20 s; antes no caducaba nada).
	_ok("1 poner con tres argumentos funciona como antes", e.poner(c, "mojada", true) and e.tiene(c, "mojada"))
	_ok("1 intensidad por defecto 1 y la caducidad de DURA", is_equal_approx(e.intensidad(c, "mojada"), 1.0) and is_equal_approx(e.queda(c, "mojada"), float(EstadosSuelo3D.DURA["mojada"])))
	_ok("1 sin el estado, intensidad 0", e.intensidad(c, "quemada") == 0.0)

	# 2. Intensidad: cambiarla no es un cambio de hecho (no avisa), pero sí cambia la textura.
	visto.clear()
	e.poner(c, "quemada", true, 0.25)
	_ok("2 la intensidad se guarda", is_equal_approx(e.intensidad(c, "quemada"), 0.25))
	var antes: int = visto.size()
	_ok("2 subir la intensidad no avisa otra vez", not e.poner(c, "quemada", true, 0.75) and visto.size() == antes, str(visto))
	_ok("2 pero queda la nueva", is_equal_approx(e.intensidad(c, "quemada"), 0.75))

	# 3. Caducidad: el estado se quita solo al pasar el tiempo y avisa UNA vez.
	var d := Vector2i(6, 1)
	e.poner(d, "electrificada", true, 1.0, 2.0)
	_ok("3 queda lo que se pidió", is_equal_approx(e.queda(d, "electrificada"), 2.0))
	visto.clear()
	e.avanzar(1.5)
	_ok("3 a los 1,5 s sigue", e.tiene(d, "electrificada") and visto.is_empty())
	e.avanzar(0.6)
	_ok("3 a los 2,1 s se ha ido", not e.tiene(d, "electrificada"))
	_ok("3 y avisó una sola vez", visto == [[d, "electrificada", false]], str(visto))
	e.avanzar(5.0)
	_ok("3 pasar más tiempo no vuelve a avisar", visto.size() == 1)
	_ok("3 lo que no caduca no se va", e.tiene(c, "mojada"))

	# 4. Transiciones en tabla (las reglas de _impacto_en_suelo de la maqueta).
	var s := Vector2i(10, 10)
	e.aplicar(s, "agua")
	_ok("4 agua sobre seco = mojada", e.tiene(s, "mojada") and not e.tiene(s, "helada"))
	e.aplicar(s, "agua")
	_ok("4 dos aguas hielan", e.tiene(s, "helada") and not e.tiene(s, "mojada"))
	var r: Dictionary = e.aplicar(s, "agua")
	_ok("4 agua sobre helada no hace nada", not bool(r["cambio"]) and e.tiene(s, "helada"))
	e.aplicar(s, "calor")
	_ok("4 calor sobre helada = mojada", e.tiene(s, "mojada") and not e.tiene(s, "helada"))
	r = e.aplicar(s, "calor")
	_ok("4 calor sobre mojada = seca, con vapor", not e.tiene(s, "mojada") and String(r["efecto"]) == "vapor", str(r))
	r = e.aplicar(s, "calor")
	_ok("4 calor sobre seco: nada", not bool(r["cambio"]) and String(r["efecto"]) == "")
	e.aplicar(s, "agua")
	e.aplicar(s, "frio")
	_ok("4 frío sobre mojada = helada", e.tiene(s, "helada") and not e.tiene(s, "mojada"))
	_ok("4 una acción desconocida no hace nada", not bool(e.aplicar(s, "tierra")["cambio"]))

	# 5. Señales: ninguna repetida al aplicar transiciones.
	var t := Vector2i(12, 2)
	visto.clear()
	e.aplicar(t, "agua")
	e.aplicar(t, "agua")
	_ok("5 dos aguas: tres avisos (mojada, -mojada, helada), sin repetidos", visto == [[t, "mojada", true], [t, "mojada", false], [t, "helada", true]], str(visto))

	# 6. Textura: el píxel correcto en la casilla correcta, canales R quemada · G mojada · B helada · A segada.
	e.limpiar()
	e.dimensionar(16)
	e.poner(Vector2i(2, 3), "quemada", true, 0.5)
	e.poner(Vector2i(5, 7), "mojada", true)
	e.poner(Vector2i(9, 1), "helada", true)
	e.poner(Vector2i(0, 15), "segada", true)
	e.poner(Vector2i(20, 20), "mojada", true)        # fuera de la textura: no revienta
	e.avanzar(float(EstadosSuelo3D.SUBE["mojada"]))  # 27/10: lo mojado tarda SUBE s en verse entero (empapa)
	var tex: ImageTexture = e.textura()
	var img: Image = tex.get_image()
	_ok("6 la textura mide lado × lado", img.get_width() == 16 and img.get_height() == 16, "%dx%d" % [img.get_width(), img.get_height()])
	var p: Color = img.get_pixel(2, 3)
	_ok("6 quemada a 0,5 → R ≈ 0,5", absf(p.r - 0.5) < 0.01 and p.g == 0.0 and p.b == 0.0, str(p))
	_ok("6 mojada → G = 1", img.get_pixel(5, 7).g == 1.0 and img.get_pixel(5, 7).r == 0.0)
	_ok("6 helada → B = 1", img.get_pixel(9, 1).b == 1.0)
	_ok("6 segada → A = 1", img.get_pixel(0, 15).a == 1.0)
	_ok("6 una casilla sin nada está a cero", img.get_pixel(8, 8) == Color(0, 0, 0, 0))
	_ok("6 pedirla otra vez sin cambios da el MISMO objeto", e.textura() == tex)
	e.poner(Vector2i(5, 7), "mojada", false)
	# Sin ventana, el servidor de dibujo de mentira no devuelve lo subido con update(): se mira la imagen que se sube.
	_ok("6 al cambiar algo se actualiza (mismo objeto)", e.textura() == tex and e.imagen().get_pixel(5, 7).g == 0.0)
	e.dimensionar(8)
	_ok("6 dimensionar rehace la imagen", e.textura().get_image().get_width() == 8)

	# 7. La fachada: Mundo3D.textura_estados() es la del dueño.
	Terreno3D.estados.limpiar()
	Terreno3D.estados.poner(Vector2i(1, 1), "helada", true)
	var tm: ImageTexture = Mundo3D.textura_estados()
	_ok("7 Mundo3D.textura_estados() lee Terreno3D.estados", tm != null and tm.get_image().get_pixel(1, 1).b == 1.0)
	Terreno3D.estados.limpiar()

	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)

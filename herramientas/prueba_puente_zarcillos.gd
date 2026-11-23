extends SceneTree
## 23/11 (PUENTE DE ZARCILLOS, fase 1, modelos provisionales): `bancal modelo=surco dir=e` (piedra con hueco + nudo dormido) que al mojarse germina y, con la regla `cuando=hueco.germino hace=trama.tender`,
## teje un `puente estilo=zarcillos` (PuenteRaices3D con zarcillos=true: arranque + tejido + anclaje) sobre el agua. Se prueba con el mundo falso de prueba_puente_raices (sin GPU: lo visual NO se mira):
##   1 · parseo de las claves nuevas (`modelo=surco`, `dir` del bancal, `estilo=zarcillos`) y avisos de las malas
##   2 · antes del agua: hueco sin agua visible, hilo oculto, nudo dormido (verde oliva), sin colisiones, casilla libre; puente plegado, anclaje montado con los anillos a escala 0
##   3 · agua en la casilla → flag al instante, pero `germino` NO sale hasta que el nudo se abre (≥ ~0,8 s); el puente NO empieza antes; arranque en la 1.ª casilla y tejido en las demás; anclaje cerrado al final;
##       casillas «b» y libres; `completo` después del último tramo
##   4 · recarga con las flags: todo en estado final EN EL MISMO FOTOGRAMA, sin disparar la regla
##   5 · anclaje: con pared en la casilla de llegada no se monta y avisa
##   godot --headless --path . --script res://herramientas/prueba_puente_zarcillos.gd

class MundoFalso extends Node3D:
	var _lado: int = 10
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _props: Node3D = null
	var _mapa: PackedStringArray = []
	func _init() -> void:
		_mapa = PackedStringArray(MAPA.duplicate())
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

## Bancal con surco en (2,3), mirando a +x (`dir=e`); el agua honda de (3,3) a (6,3); la casilla de llegada es (7,3).
const MAPA: Array = [
	"##########",
	"#........#",
	"#........#",
	"#..~~~~..#",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"##########",
]
const TXT: String = """
; pieza hueco bancal 2 3 flag=prueba.zarc.germino modelo=surco dir=e
; pieza trama puente 3 3 celdas=3,3..6,3 estilo=zarcillos dir=e tendido_si=flag.prueba.zarc.germino
; puzle crece cuando=hueco.germino hace=trama.tender
"""

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_parseo()
	await _secuencia()
	await _sin_anclaje()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _parseo() -> void:
	var r: Dictionary = Puzle3D.parsear(TXT)
	_ok("1 el montaje se lee sin avisos", (r["avisos"] as Array).is_empty() and (r["piezas"] as Array).size() == 2 and (r["reglas"] as Array).size() == 1, str(r["avisos"]))
	var pz: Array = r["piezas"]
	_ok("1 el bancal trae modelo=surco y dir=e; el puente estilo=zarcillos con tendido_si", String(pz[0].p.get("modelo", "")) == "surco" and String(pz[0].p.get("dir", "")) == "e" and String(pz[1].p.get("estilo", "")) == "zarcillos" and pz[1].exprs.has("tendido_si"))
	_ok("1 modelo=tocon sigue valiendo", (Puzle3D.parsear("; pieza b bancal 2 3 flag=a.b.c modelo=tocon")["avisos"] as Array).is_empty())
	_ok("1 bancal dir=x: aviso", not (Puzle3D.parsear("; pieza b bancal 2 3 flag=a.b.c modelo=surco dir=x")["avisos"] as Array).is_empty())
	_ok("1 bancal modelo=roca: aviso", not (Puzle3D.parsear("; pieza b bancal 2 3 flag=a.b.c modelo=roca")["avisos"] as Array).is_empty())
	_ok("1 estilo=piedra: aviso y pieza ignorada", not (Puzle3D.parsear("; pieza p puente 3 3 estilo=piedra")["avisos"] as Array).is_empty() and (Puzle3D.parsear("; pieza p puente 3 3 estilo=piedra")["piezas"] as Array).is_empty())


func _mundo() -> MundoFalso:
	var m := MundoFalso.new()
	m._props = Node3D.new()
	m.add_child(m._props)
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(10):
		for x in range(10):
			if m._mapa[y][x] == "#":
				m._bloqueadas[Vector2i(x, y)] = true
	Terreno3D.cargar_datos(m._mapa, m._bloqueadas)
	return m


func _letras(cs: Array) -> String:
	var s: String = ""
	for c in cs:
		s += Terreno3D.letra_de(c as Vector2i)
	return s


func _secuencia() -> void:
	Flags.nuevo()
	var m: MundoFalso = _mundo()
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "PuenteZarcillosPrueba", TXT)
	await process_frame
	var celdas: Array = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]
	var ban: Vector2i = Vector2i(2, 3)
	var llegada: Vector2i = Vector2i(7, 3)
	var bp: Puzle3D.BancalPuzle = z.nodo("hueco") as Puzle3D.BancalPuzle
	var pq: PuenteRaices3D = z.nodo("trama") as PuenteRaices3D
	_ok("2 montado sin avisos", z.avisos.is_empty(), str(z.avisos))
	_ok("2 el bancal es BancalPuzle con surco y el puente un PuenteRaices3D con zarcillos", bp != null and bp.con_surco and pq != null and pq.zarcillos)
	_ok("2 la piedra, el hueco de agua, el hilo y el nudo existen", bp._piedra != null and bp._agua_hueco != null and bp._hilo != null and bp._nudo != null)
	_ok("2 el hueco NO muestra agua y el hilo está oculto", not bp._agua_hueco.visible and not bp._hilo.visible)
	_ok("2 el nudo está dormido: verde oliva apagado (#7A8450), no abierto", not bp.nudo_abierto and bp.color_nudo().is_equal_approx(Color("7A8450")), str(bp.color_nudo()))
	_ok("2 el nudo está a +dir y a un LADO del eje (el de la cámara: +z con dir=e) y la piedra a −dir", bp._nudo.position.x > 0.5 and absf(bp._nudo.position.z - PuenteRaices3D.NUDO_LATERAL) < 0.01 and bp._piedra.position.x < 0.0, "%s / %s" % [str(bp._nudo.position), str(bp._piedra.position)])
	_ok("2 con surco no sale el brote genérico en la casilla (sin_brote) y el lado del nudo es el de la cámara para las 4 direcciones", preload("res://presentacion/arte_entorno_3d.gd").sin_brote.has(ban) and PuenteRaices3D.lado_nudo(Vector3(1, 0, 0)) == 1.0 and PuenteRaices3D.lado_nudo(Vector3(-1, 0, 0)) == -1.0 and PuenteRaices3D.lado_nudo(Vector3(0, 0, -1)) == 1.0 and PuenteRaices3D.lado_nudo(Vector3(0, 0, 1)) == -1.0)
	_ok("2 ni piedra ni nudo llevan colisión y la casilla no está bloqueada (el agua llega)", bp.find_children("*", "CollisionObject3D", true, false).is_empty() and not Terreno3D.bloqueada(ban))
	_ok("2 el puente está plegado: casillas «~» y condición plegado", not pq.tendido and _letras(celdas) == "~~~~" and z._cumple("trama", "plegado"))
	_ok("2 el anclaje está montado en la casilla de llegada con sus anillos a escala 0 y sin cerrar", pq._ancla != null and not pq._anillos.is_empty() and pq._anillos.all(func(a): return (a as Node3D).scale.length() < 0.001) and not pq.anclaje_cerrado)
	_ok("2 el anclaje NO bloquea la casilla de llegada (sigue siendo suelo libre)", Terreno3D.letra_de(llegada) == "." and not Terreno3D.bloqueada(llegada) and pq._ancla.find_children("*", "CollisionObject3D", true, false).is_empty())
	_ok("2 primer tramo = arranque, los demás = tejido (mallas propias)", (pq._tramos[0]["cuerpo"] as Node).get_child(0).name == "arranque" and (pq._tramos[1]["cuerpo"] as Node).get_child(0).name == "tejido" and (pq._tramos[3]["cuerpo"] as Node).get_child(0).name == "tejido")
	_ok("2 raíces del fondo y de conexión: hay 3 de conexión (sin colisión), todas DORMIDAS (savia 0, oliva #7A8450 en el shader)", bp._raices_conexion.size() == 3 and bp._raices_conexion.all(func(r): return (r as Node).find_children("*", "CollisionObject3D", true, false).is_empty()) and float(bp._mat_fondo.get_shader_parameter("savia")) == 0.0 and bp._mats_raiz.all(func(m): return float((m as ShaderMaterial).get_shader_parameter("savia")) == 0.0 and (m.get_shader_parameter("dormido") as Color).is_equal_approx(Color("7A8450"))) and (bp._mat_fondo.get_shader_parameter("dormido") as Color).is_equal_approx(Color("7A8450")))
	_ok("2 tubos de raíces del fondo existentes (malla propia, sin colisión) y DORMIDOS (savia 0, #7A8450)", bp._raices_fondo != null and bp._raices_fondo.mesh != null and bp._raices_fondo.mesh.get_surface_count() == 1 and (bp._raices_fondo as Node).find_children("*", "CollisionObject3D", true, false).is_empty() and float(bp._mat_raiz_fondo.get_shader_parameter("savia")) == 0.0 and (bp._mat_raiz_fondo.get_shader_parameter("dormido") as Color).is_equal_approx(Color("7A8450")) and bool(bp._mat_raiz_fondo.get_shader_parameter("invertir")))
	var germinos: Array = [0]
	var t_germino: Array = [0]
	bp.germino.connect(func() -> void:
		germinos[0] += 1
		t_germino[0] = Time.get_ticks_msec())
	var orden: Array = []
	var t_losas: Array = []
	pq.losa_lista.connect(func(c: Vector2i) -> void:
		orden.append(c)
		t_losas.append(Time.get_ticks_msec()))
	var completo: Array = [false, 0]
	pq.completo.connect(func() -> void:
		completo[0] = true
		completo[1] = Time.get_ticks_msec())
	# El agua, por la puerta del hechizo (ReaccionesSuelo3D), con el clasificador del mundo falso.
	var clasificador: Callable = ReaccionesSuelo3D.clasificar
	ReaccionesSuelo3D.clasificar = func(c: Vector2i) -> String:
		return "agua" if m._letra(c) == "~" else ("" if m._bloqueadas.has(c) or Terreno3D.bloqueada(c) else "suelo")
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = ReaccionesSuelo3D._aplicar_celda("agua", ban)
	_ok("3 el agua mojó la casilla del bancal", bool(r.get("cambio", false)) and Terreno3D.estados.tiene(ban, EstadosSuelo3D.MOJADA), str(r))
	_ok("3 la flag y `germinado` se ponen AL INSTANTE, pero `germino` aún no ha salido y el puente no se ha lanzado", bp.germinado and Flags.i().tiene("prueba.zarc.germino") and germinos[0] == 0 and not pq.tendido and int(z.puzle("crece")["veces"]) == 0)
	_ok("3 el agua del hueco es visible y sube (empieza baja), el nudo sigue dormido", bp._agua_hueco.visible and bp._agua_hueco.position.y < bp._piedra.position.y + Puzle3D.BancalPuzle.HUECO_Y - 0.001 and not bp.nudo_abierto)
	await create_timer(0.55).timeout
	_ok("3 a los ~0,55 s: agua llena en el hueco, hilo bajando, el nudo sigue sin abrir y el puente sin lanzar", bp._agua_hueco.position.y >= bp._piedra.position.y + Puzle3D.BancalPuzle.HUECO_Y - 0.001 and bp._hilo.visible and not bp.nudo_abierto and germinos[0] == 0 and not pq.tendido,
		"hilo scale.z %.2f" % bp._hilo.scale.z)
	await create_timer(0.7).timeout
	_ok("3 pasado el hilo, el nudo se ha abierto y ha salido `germino` UNA vez, ≥ ~0,6 s de reloj después del agua (0,9 s de animación)", bp.nudo_abierto and germinos[0] == 1 and t_germino[0] - t0 >= 600, "%d ms" % (t_germino[0] - t0))
	_ok("3 al abrirse el nudo la regla lanza el puente (tendido), todavía sin casillas andables", pq.tendido and int(z.puzle("crece")["veces"]) == 1 and _letras(celdas).begins_with("~"))
	await create_timer(0.9).timeout
	_ok("3 la savia ha llegado al final (fondo y raíces de conexión VIVOS, verde del puente) cuando el nudo se abre: orden fondo -> raíces -> nudo -> puente", float(bp._mat_fondo.get_shader_parameter("savia")) >= 0.999 and bp._mats_raiz.all(func(m): return float((m as ShaderMaterial).get_shader_parameter("savia")) >= 0.999 and (m.get_shader_parameter("vivo") as Color).is_equal_approx(Color("7E9E45"))) and bp._savia_v >= 0.999)
	_ok("3 los tubos del fondo también están vivos (savia 1) cuando se abre el nudo", float(bp._mat_raiz_fondo.get_shader_parameter("savia")) >= 0.999)
	_ok("3 el nudo acaba verde lima (#7E9E45)", bp.color_nudo().is_equal_approx(Color("7E9E45")), str(bp.color_nudo()))
	await create_timer(3.2).timeout
	_ok("3 el puente NO empezó antes de que el nudo se abriera: la 1.ª casilla se asentó DESPUÉS de `germino`", not t_losas.is_empty() and int(t_losas[0]) > int(t_germino[0]) + 300, "%d ms después" % (int(t_losas[0]) - int(t_germino[0])) if not t_losas.is_empty() else "ninguna")
	_ok("3 las casillas se asientan en orden, desde la del nudo", orden == celdas, str(orden))
	_ok("3 todas quedan con letra «b» y libres", _letras(celdas) == "bbbb" and celdas.all(func(c): return not Terreno3D.bloqueada(c)), _letras(celdas))
	_ok("3 el anclaje se cierra (anillos a escala 1) y `completo` sale DESPUÉS del último tramo", pq.anclaje_cerrado and pq._anillos.all(func(a): return ((a as Node3D).scale - Vector3.ONE).length() < 0.01) and completo[0] and int(completo[1]) > int(t_losas[3]) + 200,
		"completo %d ms después del último tramo" % (int(completo[1]) - int(t_losas[3])))
	_ok("3 tras `completo` existen los zarcillos de unión del anclaje (4: uno por anillo), crecidos (escala 1), sin colisión y llegando al borde del tejido (x local −1,15)", pq._uniones.size() == 4 and pq._uniones.all(func(u): return ((u as Node3D).scale - Vector3.ONE).length() < 0.01 and (u as Node).find_children("*", "CollisionObject3D", true, false).is_empty() and absf(float(_fin_x(u)) + 1.15) < 0.12), str(pq._uniones.size()))
	_ok("3 sin hojas de esfera en el estilo zarcillos", pq._hojas.is_empty())
	_ok("3 la casilla de llegada sigue libre", Terreno3D.letra_de(llegada) == "." and not Terreno3D.bloqueada(llegada))
	var a0: AABB = (pq._tramos[0]["cuerpo"] as Node).get_child(0).get("mesh").get_aabb()
	var a1: AABB = (pq._tramos[1]["cuerpo"] as Node).get_child(0).get("mesh").get_aabb()
	_ok("3 el arranque y el tejido miden una casilla de largo (cortes limpios): %.2f y %.2f" % [a0.size.x, a1.size.x], absf(a0.size.x - PuenteRaices3D.CASILLA) < 0.12 and absf(a1.size.x - PuenteRaices3D.CASILLA) < 0.12)
	_ok("3 el tejido y el arranque tienen el mismo ancho de bordes (z ±0,8) y la cara de arriba del enrejado a +ALTO/2 (rizos aparte)", a1.position.z <= -0.78 and a1.end.z >= 0.78 and a0.position.z <= -0.78 and a0.end.z >= 0.78, "%s | %s" % [str(a1), str(a0)])
	_ok("3 el arranque sale estrecho: en su borde de entrada los vértices caben en < 0,65 de ancho", _ancho_en_entrada((pq._tramos[0]["cuerpo"] as Node).get_child(0).get("mesh")) < 0.65, "%.2f" % _ancho_en_entrada((pq._tramos[0]["cuerpo"] as Node).get_child(0).get("mesh")))
	_ok("3 la condición del puente dice tendido", z._cumple("trama", "tendido"))
	ReaccionesSuelo3D.clasificar = clasificador
	var guardado: Dictionary = Flags.i().a_dic()
	z.free()
	m.free()
	await process_frame
	_ok("3 al salir el bancal del árbol se quita su `sin_brote`", not preload("res://presentacion/arte_entorno_3d.gd").sin_brote.has(ban))
	# 4 · recargar con las flags guardadas: todo en su estado final en el mismo fotograma.
	Flags.nuevo().desde_dic(guardado)
	m = _mundo()
	z = Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "PuenteZarcillosPrueba", TXT)
	bp = z.nodo("hueco") as Puzle3D.BancalPuzle
	pq = z.nodo("trama") as PuenteRaices3D
	_ok("4 (sin animación) el puente sale tendido, con letras «b» y libres en el mismo fotograma", pq.tendido and _letras(celdas) == "bbbb" and celdas.all(func(c): return not Terreno3D.bloqueada(c)), _letras(celdas))
	_ok("4 (tender_ya) los zarcillos de unión del anclaje están puestos (escala 1)", pq._uniones.size() == 4 and pq._uniones.all(func(u): return ((u as Node3D).scale - Vector3.ONE).length() < 0.01))
	_ok("4 anclaje cerrado y tramos asentados (frente 2, sin alabeo)", pq.anclaje_cerrado and pq._anillos.all(func(a): return ((a as Node3D).scale - Vector3.ONE).length() < 0.01) and pq._tramos.all(func(t): return float((t["mat"] as ShaderMaterial).get_shader_parameter("frente")) >= 1.5 and absf((t["cuerpo"] as Node3D).rotation.x) < 0.0001 and (t["raiz"] as Node3D).visible))
	_ok("4 agua en el hueco, hilo entero y nudo abierto lima, sin esperar", bp.germinado and bp._agua_hueco.visible and bp._hilo.visible and bp._hilo.scale.z >= 0.999 and bp.nudo_abierto and bp.color_nudo().is_equal_approx(Color("7E9E45")))
	_ok("4 raíces del fondo y de conexión ya vivas al recargar (savia 1)", bp._raices_conexion.size() == 3 and float(bp._mat_fondo.get_shader_parameter("savia")) >= 0.999 and bp._mats_raiz.all(func(m): return float((m as ShaderMaterial).get_shader_parameter("savia")) >= 0.999))
	_ok("4 tubos del fondo ya vivos al recargar", bp._raices_fondo != null and float(bp._mat_raiz_fondo.get_shader_parameter("savia")) >= 0.999)
	_ok("4 la regla NO se dispara al recargar", int(z.puzle("crece")["veces"]) == 0)
	await create_timer(0.6).timeout
	_ok("4 medio segundo después nada ha cambiado (sin tweens pendientes)", pq.tendido and _letras(celdas) == "bbbb" and bp._agua_hueco.visible)
	z.free()
	m.free()


## x (en el espacio del anclaje, orientado a +x = dir=e) del último vértice del zarcillo de unión: donde se mete en el tejido (el borde −x de la casilla de llegada).
func _fin_x(u: Node3D) -> float:
	var mi: MeshInstance3D = u.get_child(0) as MeshInstance3D
	var v: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xs: float = 1e9
	for p in v:
		xs = minf(xs, p.x)
	return xs + u.position.x


## Ancho (z) de los vértices de la malla más cercanos al borde de entrada (x < −1,0): el abanico sale estrecho.
func _ancho_en_entrada(malla: Mesh) -> float:
	var v: PackedVector3Array = (malla as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var zmin: float = 1e9
	var zmax: float = -1e9
	for p in v:
		if p.x < -1.0:
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
	return zmax - zmin


## 5 · sin suelo en la casilla de llegada: no se monta el anclaje y se avisa.
func _sin_anclaje() -> void:
	Flags.nuevo()
	var m: MundoFalso = _mundo()
	Terreno3D.poner_letra(Vector2i(7, 3), "#")
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "PuenteZarcillosPrueba2", TXT)
	await process_frame
	var pq: PuenteRaices3D = z.nodo("trama") as PuenteRaices3D
	_ok("5 con pared en la casilla de llegada el puente se monta SIN anclaje y avisa", pq != null and pq._ancla == null and z.avisos.any(func(a): return String(a).contains("sin anclaje")), str(z.avisos))
	z.free()
	m.free()

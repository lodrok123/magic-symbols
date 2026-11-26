extends SceneTree
## 23/11 (fase 1 del PUENTE DE RAÍCES, modelos provisionales): un `bancal modelo=tocon` (tocón seco sobre tierra) que al mojarse germina y, con la regla `cuando=tocon.germino hace=raices.tender`,
## tiende un `puente estilo=raices` (PuenteRaices3D) sobre el agua, tramo a tramo desde el tocón. Lo que se prueba, con el mundo falso de prueba_puzle_condiciones (sin GPU: lo visual NO se mira):
##   1 · parseo de las claves nuevas (`modelo=tocon`, `estilo`, `tendido_si`, `dir`) y avisos de las malas
##   2 · antes del agua: tocón seco, SIN cuerpo de colisión y casilla no bloqueada (el agua llega), puente plegado y casillas «~» (no andables)
##   3 · agua en la casilla del tocón (la misma vía que el hechizo: `ReaccionesSuelo3D`) → germina, cambia a musgoso, el puente se tiende en orden y TODAS las casillas pasan a «b» y se liberan
##   4 · al recargar con las flags guardadas: musgoso directo y puente ya tendido, SIN animación (síncrono) y sin disparar la regla
##   5 · el estilo losas sigue igual: se tiende con `tender`, y también admite `tendido_si`
##   godot --headless --path . --script res://herramientas/prueba_puente_raices.gd

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

## Tocón en (2,3); el agua honda («~») de (3,3) a (6,3): el puente de raíces; (7,3) es la otra orilla. Fila 6: otro río para el puente de losas.
const MAPA: Array = [
	"##########",
	"#........#",
	"#........#",
	"#..~~~~..#",
	"#........#",
	"#........#",
	"#..~~~~..#",
	"#........#",
	"#........#",
	"##########",
]
const TXT: String = """
; pieza tocon bancal 2 3 flag=prueba.raices.germino modelo=tocon
; pieza raices puente 3 3 celdas=3,3..6,3 estilo=raices tendido_si=flag.prueba.raices.germino
; puzle crece cuando=tocon.germino hace=raices.tender
"""

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_parseo()
	await _bancal_y_puente()
	await _losas()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _parseo() -> void:
	var r: Dictionary = Puzle3D.parsear(TXT)
	_ok("1 el montaje de la demo se lee sin avisos", (r["avisos"] as Array).is_empty() and (r["piezas"] as Array).size() == 2 and (r["reglas"] as Array).size() == 1, str(r["avisos"]))
	var pz: Array = r["piezas"]
	_ok("1 el bancal trae modelo=tocon y el puente estilo=raices con su tendido_si", String(pz[0].p.get("modelo", "")) == "tocon" and String(pz[1].p.get("estilo", "")) == "raices" and pz[1].exprs.has("tendido_si"))
	_ok("1 estilo=losas es válido", (Puzle3D.parsear("; pieza p puente 3 3 estilo=losas")["avisos"] as Array).is_empty())
	_ok("1 dir=e vale", (Puzle3D.parsear("; pieza p puente 3 3 estilo=raices dir=e")["avisos"] as Array).is_empty())
	_ok("1 estilo=piedra: aviso y pieza ignorada", not (Puzle3D.parsear("; pieza p puente 3 3 estilo=piedra")["avisos"] as Array).is_empty() and (Puzle3D.parsear("; pieza p puente 3 3 estilo=piedra")["piezas"] as Array).is_empty())
	_ok("1 bancal modelo=roca: aviso", not (Puzle3D.parsear("; pieza b bancal 2 3 flag=a.b.c modelo=roca")["avisos"] as Array).is_empty())
	_ok("1 tendido_si mal escrito (flag.mal): aviso y el puente se descarta", (Puzle3D.parsear("; pieza p puente 3 3 tendido_si=flag.mal")["piezas"] as Array).is_empty())


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


func _bancal_y_puente() -> void:
	Flags.nuevo()
	var m: MundoFalso = _mundo()
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "PuenteRaicesPrueba", TXT)
	await process_frame
	var celdas: Array = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]
	var toc: Vector2i = Vector2i(2, 3)
	var b: Node = z.nodo("tocon")
	var pr: Node = z.nodo("raices")
	_ok("2 montado sin avisos", z.avisos.is_empty(), str(z.avisos))
	_ok("2 el puente es un PuenteRaices3D y el bancal un BancalPuzle", pr is PuenteRaices3D and b is Puzle3D.BancalPuzle)
	var bp: Puzle3D.BancalPuzle = b as Puzle3D.BancalPuzle
	var pq: PuenteRaices3D = pr as PuenteRaices3D
	_ok("2 el tocón seco está puesto (provisional tronco_seco) y el musgoso aún no", bp._seco != null and bp._vivo == null and bp._seco.visible)
	_ok("2 el tocón NO lleva cuerpos de colisión (si no, la casilla bloqueada no recibiría el agua)", bp.find_children("*", "CollisionObject3D", true, false).is_empty())
	_ok("2 la casilla del tocón no está bloqueada", not Terreno3D.bloqueada(toc))
	_ok("2 antes del agua el puente está plegado y sus casillas son agua «~» (no andables)", not pq.tendido and _letras(celdas) == "~~~~" and z._cumple("raices", "plegado"))
	# El agua, por la misma puerta que el hechizo: ReaccionesSuelo3D (clasifica la casilla y la moja).
	# El mundo falso no tiene `_es_agua`/`_es_hierba`: se clasifica como `Lanzador3D._clase_de_casilla` (agua «~»; bloqueada en `_bloqueadas` = nada; el resto, suelo).
	var clasificador: Callable = ReaccionesSuelo3D.clasificar
	ReaccionesSuelo3D.clasificar = func(c: Vector2i) -> String:
		return "agua" if m._letra(c) == "~" else ("" if m._bloqueadas.has(c) or Terreno3D.bloqueada(c) else "suelo")
	var clase: String = ReaccionesSuelo3D.clase_de(toc)
	var r: Dictionary = ReaccionesSuelo3D._aplicar_celda("agua", toc)
	print("      clase de la casilla del tocón: «%s»; resultado del agua: %s" % [clase, str(r)])
	_ok("3 el agua llega a la casilla del tocón (se clasifica como suelo y el hechizo la moja)", clase == "suelo" and bool(r.get("cambio", false)) and Terreno3D.estados.tiene(toc, EstadosSuelo3D.MOJADA), str(r))
	_ok("3 germina: flag puesta, tocón musgoso y seco oculto", bp.germinado and Flags.i().tiene("prueba.raices.germino") and bp._vivo != null and bp._vivo.visible and not bp._seco.visible)
	_ok("3 la regla ha lanzado el puente (tendido = true) pero aún no hay casillas andables (animación en curso)", pq.tendido and _letras(celdas).begins_with("~") and int(z.puzle("crece")["veces"]) == 1)
	var orden: Array = []
	pq.losa_lista.connect(func(c: Vector2i) -> void: orden.append(c))
	var completo: Array = [false]
	pq.completo.connect(func() -> void: completo[0] = true)
	await create_timer(3.0).timeout
	_ok("3 todas las casillas del puente quedan con letra «b» y libres", _letras(celdas) == "bbbb" and celdas.all(func(c): return not Terreno3D.bloqueada(c)), _letras(celdas))
	_ok("3 las casillas se asientan en orden, desde la del tocón", orden == celdas, str(orden))
	_ok("3 emite `completo` y brotan hojas (4 por casilla)", completo[0] and pq._hojas.size() == 16, str(pq._hojas.size()))
	var caja: AABB = pq._caja(pq._tramos[0]["cuerpo"])
	var mallas: Array = (pq._tramos[0]["raiz"] as Node).find_children("*", "MeshInstance3D", true, false)
	_ok("3 cada tramo son 3 ramas de raices_musgo alargadas (no el cilindro de reserva) que cubren la casilla: x %.2f, y %.2f, z %.2f" % [caja.size.x, caja.size.y, caja.size.z],
		not mallas.is_empty() and not (mallas[0] as MeshInstance3D).mesh is CylinderMesh and caja.size.x >= 2.2 and caja.size.x <= 4.5 and caja.size.y < 1.2 and caja.size.z < 2.2, "%d mallas" % mallas.size())
	_ok("3 la condición del puente dice tendido (no plegado)", z._cumple("raices", "tendido") and not z._cumple("raices", "plegado"))
	ReaccionesSuelo3D.clasificar = clasificador
	var guardado: Dictionary = Flags.i().a_dic()
	z.free()
	m.free()
	# 4 · recargar con las flags guardadas.
	Flags.nuevo().desde_dic(guardado)
	m = _mundo()
	_ok("4 el mapa recargado vuelve a tener agua «~» en el río", _letras(celdas) == "~~~~", _letras(celdas))
	z = Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "PuenteRaicesPrueba", TXT)      # SIN esperar ningún fotograma: tiene que salir tendido ya
	pr = z.nodo("raices")
	pq = pr as PuenteRaices3D
	bp = z.nodo("tocon") as Puzle3D.BancalPuzle
	_ok("4 (sin animación) el puente sale tendido y sus casillas ya son «b» en el mismo fotograma del montaje", pq.tendido and _letras(celdas) == "bbbb", _letras(celdas))
	_ok("4 las casillas están libres y hay hojas puestas", celdas.all(func(c): return not Terreno3D.bloqueada(c)) and pq._hojas.size() == 16)
	_ok("4 los tramos salen completos y asentados (frente 2, sin alabeo)", pq._tramos.all(func(t): return float((t["mat"] as ShaderMaterial).get_shader_parameter("frente")) >= 1.5 and absf((t["cuerpo"] as Node3D).rotation.x) < 0.0001 and (t["raiz"] as Node3D).visible))
	_ok("4 el bancal recupera su flag y sale directo el tocón musgoso", bp.germinado and bp._vivo != null and bp._seco == null)
	_ok("4 la regla NO se dispara al recargar (no hay animación que lanzar)", int(z.puzle("crece")["veces"]) == 0)
	await create_timer(0.6).timeout
	_ok("4 medio segundo después nada ha cambiado (sin tweens pendientes)", pq.tendido and _letras(celdas) == "bbbb")
	z.free()
	m.free()


## 5 · el estilo losas de siempre, y `tendido_si` también con él.
func _losas() -> void:
	Flags.nuevo()
	var m: MundoFalso = _mundo()
	var z := Puzle3D.new()
	root.add_child(z)
	var cs: Array = [Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6)]
	z.iniciar(m, "PuenteLosasPrueba", "; pieza lo puente 3 6 celdas=3,6..5,6\n; pieza lo2 puente 3 6 celdas=3,6..5,6 estilo=losas tendido_si=flag.prueba.losas.hecho\n")
	await process_frame
	var pr: Node = z.nodo("lo")
	_ok("5 sin estilo sigue siendo PuenteReactivo3D (losas), plegado", z.avisos.is_empty() and pr is PuenteReactivo3D and not (pr as PuenteReactivo3D).tendido and _letras(cs) == "~~~", str(z.avisos))
	(pr as PuenteReactivo3D).tender()
	await create_timer(2.5).timeout
	_ok("5 las losas se tienden como siempre: casillas «b»", (pr as PuenteReactivo3D).tendido and _letras(cs) == "bbb", _letras(cs))
	_ok("5 `tendido_si` sin cumplirse no tiende el segundo puente", not (z.nodo("lo2") as PuenteReactivo3D).tendido)
	z.free()
	Terreno3D.cargar_datos(m._mapa, m._bloqueadas)
	for c in cs:
		Terreno3D.poner_letra(c, "~")
	Flags.i().poner("prueba.losas.hecho")
	z = Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "PuenteLosasPrueba", "; pieza lo2 puente 3 6 celdas=3,6..5,6 tendido_si=flag.prueba.losas.hecho\n")
	_ok("5 con la flag puesta al montar, las losas salen ya tendidas (sin animación)", (z.nodo("lo2") as PuenteReactivo3D).tendido and _letras(cs) == "bbb", _letras(cs))
	z.free()
	m.free()

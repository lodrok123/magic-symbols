extends SceneTree

## 23/10: PRUEBA DE SOLO LECTURA. Recorre arte/piezas/*.tscn y falla si alguna pieza DIBUJA SU MALLA DOS VECES.
## El horneado (GeneradorPiezas) escribía la instancia del .glb MÁS una copia horneada del mismo subárbol con los mismos nombres.
## Una pieza está duplicada si dos MeshInstance3D visibles tienen la misma malla (mismo nº de triángulos) en la misma caja global
## (posición y tamaño iguales con tolerancia): se dibujan una encima de la otra. Las mallas legítimamente repetidas (dos pilares
## del arco) quedan en cajas distintas, así que no cuentan.
##   godot --headless --path . -s herramientas/prueba_piezas_sin_duplicar.gd
##   Con `-- --informe` imprime también el peso de cada pieza (nodos, mallas, triángulos).

const CARPETA: String = "res://arte/piezas/"
const TOLERANCIA: float = 0.002          ## m: dos cajas que difieren menos que esto son la misma
const MIN_TRIS: int = 4                  ## las mallas sin triángulos no cuentan

var _fallos: int = 0
var _tot_nodos: int = 0
var _tot_mallas: int = 0
var _tot_tris: int = 0
var _dup_tris: int = 0
var _dup_piezas: int = 0


func _initialize() -> void:
	var informe: bool = OS.get_cmdline_user_args().has("--informe")
	var rutas: PackedStringArray = []
	for f in DirAccess.get_files_at(CARPETA):
		if f.ends_with(".tscn"):
			rutas.append(CARPETA + f)
	rutas.sort()
	for ruta in rutas:
		_revisar(ruta, informe)
	print("PIEZAS: %d · duplicadas: %d · triángulos dibujados de más: %d (de %d) · nodos totales %d · mallas %d" % [rutas.size(), _dup_piezas, _dup_tris, _tot_tris, _tot_nodos, _tot_mallas])
	print("PRUEBA piezas_sin_duplicar: %s" % ("OK" if _fallos == 0 else "FALLA (%d)" % _fallos))
	quit(1 if _fallos > 0 else 0)


func _revisar(ruta: String, informe: bool) -> void:
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		print("  FALLO %s: no carga" % ruta)
		_fallos += 1
		return
	var raiz: Node = ps.instantiate()
	var mallas: Array = []
	var nodos: Array = [0]
	_recoger(raiz, Transform3D.IDENTITY, mallas, nodos)
	var tris_pieza: int = 0
	var dup_pieza: int = 0
	var vistas: Array = []        # [tris, AABB global]
	for par in mallas:
		var tris: int = par[0]
		var caja: AABB = par[1]
		tris_pieza += tris
		var repetida: bool = false
		for v in vistas:
			if v[0] == tris and _caja_igual(v[1], caja):
				repetida = true
				break
		if repetida:
			dup_pieza += tris
		else:
			vistas.append([tris, caja])
	_tot_nodos += int(nodos[0])
	_tot_mallas += mallas.size()
	_tot_tris += tris_pieza
	if dup_pieza > 0:
		_dup_piezas += 1
		_dup_tris += dup_pieza
		_fallos += 1
		print("  FALLO %s: dibuja su malla dos veces (%d triángulos de más de %d; %d mallas, %d nodos)" % [ruta.get_file(), dup_pieza, tris_pieza, mallas.size(), int(nodos[0])])
	elif informe:
		print("  ok %s: %d mallas, %d triángulos, %d nodos" % [ruta.get_file(), mallas.size(), tris_pieza, int(nodos[0])])
	raiz.free()


func _recoger(n: Node, acum: Transform3D, fuera: Array, nodos: Array) -> void:
	nodos[0] = int(nodos[0]) + 1
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		var m: Mesh = (n as MeshInstance3D).mesh
		var tris: int = 0
		for s in range(m.get_surface_count()):
			var arr: Array = m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null:
				tris += (idx as PackedInt32Array).size() / 3
			else:
				tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		if tris >= MIN_TRIS:
			fuera.append([tris, t * m.get_aabb()])
	for h in n.get_children():
		_recoger(h, t, fuera, nodos)


func _caja_igual(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) <= TOLERANCIA and a.size.distance_to(b.size) <= TOLERANCIA

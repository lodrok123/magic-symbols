extends SceneTree
## Colisión medida sobre el modelo (ColisionPieza + Pieza3D.formas_colision). Sin ventana:
##   godot --headless --path . -s res://herramientas/prueba_colision_contorno.gd
## Comprueba lo que importa: que los arcos y puertas dejan el paso libre, que ningún casco sobresale del modelo, que las
## 43 piezas nuevas que bloquean traen cuerpo y que las que se pisan no lo traen.

## Las 43 piezas del lote del Bosque (21/10), tal como quedaron en ULTIMAS_INSTALADAS.txt al instalarlas.
const PIEZAS_NUEVAS: Array = ["abedul_amarillo", "arbol_viejo", "arbusto_bayas", "arbusto_flores", "bloque_hierba",
	"bloque_runa_amarilla", "bloque_runa_azul", "bloque_runa_cian", "bloque_runa_naranja", "bloque_runa_roja", "bloque_runa_verde",
	"cartel_runa_amarilla", "cartel_runa_azul", "cartel_runa_cian", "cartel_runa_naranja", "cartel_runa_roja", "cartel_runa_verde",
	"cubo_hielo", "cuenco_piedra", "flores_amarillas", "flores_colores", "helecho_ancho", "hierba_espesa", "hojas_monton", "laja_piedra",
	"nenufar", "nenufar_flor", "planta_agua", "planta_hojas", "planta_violeta", "raices_musgo", "raices_secas", "ramas_suelo", "roca_hueca",
	"sauce", "setas_amarillas", "tocon_alto", "tocon_hueco", "tocon_roca", "tocon_seco", "tronco_enredadera", "tronco_seco", "valla_lianas"]

var fallos: int = 0


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("  ok   ", texto)
	else:
		fallos += 1
		print("  FALLO ", texto)


## ¿Cae el punto (x, z) dentro de la planta de alguno de los cascos?
func _cubre(lista: Array, x: float, z: float) -> bool:
	for nube in lista:
		var p2 := PackedVector2Array()
		for p in (nube as PackedVector3Array):
			p2.append(Vector2(p.x, p.z))
		var h: PackedVector2Array = Geometry2D.convex_hull(p2)
		if Geometry2D.is_point_in_polygon(Vector2(x, z), h):
			return true
	return false


func _init() -> void:
	print("# arcos y puertas: el hueco queda libre")
	for id in ["arco_puerta", "arco_ruina"]:     # (la puerta_goblin es una puerta CERRADA que arde: sólida, no se prueba aquí)
		var l: Array = Pieza3D.cascos_colision(id)
		_ok(l.size() >= 2, "%s: %d cascos (≥ 2: uno por pilar)" % [id, l.size()])
		# el centro de la pieza es el hueco del paso: no debe estar cubierto
		_ok(not _cubre(l, 0.0, 0.0), "%s: el centro del paso (0,0) está libre" % id)
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for n in l:
			for p in (n as PackedVector3Array):
				lo = lo.min(p)
				hi = hi.max(p)
		_ok(lo.y <= 0.001, "%s: el cuerpo llega al suelo (y mín %.3f)" % [id, lo.y])
	print("# árboles: un tronco, no un cilindro fijo de 0,38")
	for id in ["arbol_redondo", "arbol_redondo_2", "pino", "pino_2", "abedul_amarillo", "arbol_viejo", "sauce"]:
		var f: Dictionary = Pieza3D.forma_colision(id)
		_ok(bool(f["cilindro"]) and int(f["cascos"]) == 1, "%s: cilindro de radio %.2f, alto %.2f" % [id, float(f.get("radio", 0.0)), float(f["alto"])])
		_ok(float(f.get("radio", 0.0)) > 0.1 and float(f["alto"]) > 0.5, "%s: medida plausible" % id)
	print("# las 43 nuevas")
	# 23/10: la lista fija (antes se leía de arte/meshy/ULTIMAS_INSTALADAS.txt, que se sobrescribe en cada instalación: con la Cueva traía 5).
	var nuevas: PackedStringArray = PackedStringArray(PIEZAS_NUEVAS)
	_ok(nuevas.size() == 43, "la lista de nuevas tiene %d (43)" % nuevas.size())
	var con_cuerpo: int = 0
	var sin_cuerpo: int = 0
	for id in nuevas:
		var modo: String = ColisionPieza.modo(id)
		var l2: Array = Pieza3D.cascos_colision(id) if modo != "ninguna" else []
		if modo != "ninguna":
			if l2.is_empty():
				# solo vale vacío si es más baja que ALTO_MIN_SOLIDO
				var vis: Node3D = Pieza3D.crear_visual(id)
				var alto: float = Pieza3D._caja(vis, Transform3D.IDENTITY).size.y if vis != null else 0.0
				if vis != null:
					vis.free()
				_ok(alto < ColisionPieza.ALTO_MIN_SOLIDO, "%s: bloquea pero sin cuerpo solo si es baja (%.2f)" % [id, alto])
				sin_cuerpo += 1
			else:
				con_cuerpo += 1
		else:
			sin_cuerpo += 1
	print("  nuevas con cuerpo: %d · se pisan: %d" % [con_cuerpo, sin_cuerpo])
	_ok(con_cuerpo >= 20, "al menos 20 de las nuevas llevan cuerpo")
	print("# ningún casco sobresale del modelo ni de la franja")
	for id in ColisionPieza.MODO.keys():
		var vis2: Node3D = Pieza3D.crear_visual(id)
		if vis2 == null:
			continue
		var caja: AABB = Pieza3D._caja(vis2, Transform3D.IDENTITY).grow(0.011)
		vis2.free()
		for n in Pieza3D.cascos_colision(id):
			for p in (n as PackedVector3Array):
				if not caja.has_point(p) and p.y > 0.0:
					_ok(false, "%s: punto %s fuera del modelo %s" % [id, p, caja])
					break
	# formas_colision: un CollisionShape3D por casco y con la escala aplicada
	var fs: Array = Pieza3D.formas_colision("arco_puerta", 2.0)
	_ok(fs.size() == Pieza3D.cascos_colision("arco_puerta").size() and fs[0] is CollisionShape3D, "formas_colision: un cuerpo por casco")
	var mx: float = 0.0
	for cs in fs:
		for p in ((cs as CollisionShape3D).shape as ConvexPolygonShape3D).points:
			mx = maxf(mx, absf(p.x))
		(cs as CollisionShape3D).free()
	var mx1: float = 0.0
	for n in Pieza3D.cascos_colision("arco_puerta"):
		for p in (n as PackedVector3Array):
			mx1 = maxf(mx1, absf(p.x))
	_ok(absf(mx - 2.0 * mx1) < 0.001, "formas_colision aplica la escala (%.3f = 2 × %.3f)" % [mx, mx1])
	print("FALLOS: %d" % fallos)      # el formato que reconoce tools/resumen_prueba.ps1 (antes «# resultado: N fallos» salía como SIN RESULTADO)
	quit(1 if fallos > 0 else 0)

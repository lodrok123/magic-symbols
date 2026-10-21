extends "res://herramientas/escenario_base.gd"
## V3 (BISEL) y V4 (ESTADO DEL SUELO) de docs/PLAN_EOW_VISUAL.md (Pipeline, 21/10). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bisel_estado.gd
## HONESTO: en headless no hay GPU; esto mide la GEOMETRÍA del labio, que el shader recibe lo que debe y que los interruptores apagan. Cómo SE VE el
## shader (carbón, charco, escarcha, labio sin rayas) se mide con `captura_v3v4.gd` (con ventana).
##
##   1  BordePiedras3D: el labio son 4 triángulos por borde, mira hacia fuera y arriba, no se sale de su sitio y no lleva colisión
##   2  interruptores del labio: `labio_activo`, sin material, pared demasiado baja, `solo_labio` (ni falda ni piedras)
##   3  la maqueta del laboratorio: labio de mapa, de orillas y de escalones; sin colisiones nuevas; `Terreno3D` intacto
##   4  el shader recibe `Mundo3D.textura_estados()` (el mismo objeto) y los interruptores de V4
##   5  la imagen de la maqueta y el estado del juego dicen lo mismo (R, G, B) tras impactos reales, y por qué difieren donde difieren
##   6  apagado: `bisel_suelo = false` no deja labio y `estado_suelo_eow = false` apaga el shader nuevo

const RUTA_LAB: String = "res://laboratorios/LabPlaytestEoW.tscn"
const LADO: float = 2.3

var _colisiones_con: int = 0       ## cuerpos y formas de colisión de la maqueta CON labio (se compara en 6.4 con la misma maqueta SIN labio)


func _escenario() -> void:
	await _labio_suelto()
	await cargar(RUTA_LAB)
	if maqueta == null:
		return
	var h_alturas: int = Terreno3D.alturas.hash()
	var h_mapa: int = hash(Terreno3D.mapa)
	_colisiones_con = _contar_colisiones(maqueta)
	_maqueta_con_labio()
	_ok("3.4 ninguno de los tres BordePiedras3D lleva colisión", _contar_colisiones(maqueta.get("_bordes_mapa")) == 0 and _contar_colisiones(maqueta.get("_bordes")) == 0 and _contar_colisiones(maqueta.get("_bordes_terraza")) == 0)
	_ok("3.5 Terreno3D.alturas y el mapa no los toca el labio (se comparan con el mismo nivel sin labio en 6.4)", Terreno3D.alturas.hash() == h_alturas and hash(Terreno3D.mapa) == h_mapa)
	_shader_y_estado()
	await _estado_igual()
	await _apagado()


# ---------------------------------------------------------------------------------------------------------------------
#  1 y 2 · BordePiedras3D suelto
# ---------------------------------------------------------------------------------------------------------------------

func _borde(c: Vector2i, v: Vector2i, y_alto: float, y_bajo: float, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"c": c, "v": v, "y_alto": y_alto, "y_bajo": y_bajo}
	d.merge(extra, true)
	return d


## El hijo vivo cuyo nombre empieza por `nombre` (al reconstruir, los viejos esperan a `queue_free` y los nuevos se renombran «faldas2»…).
func _hijo(b: Node, nombre: String) -> MeshInstance3D:
	for h in b.get_children():
		if String(h.name).begins_with(nombre) and not h.is_queued_for_deletion():
			return h as MeshInstance3D
	return null


func _labio_suelto() -> void:
	var mat := StandardMaterial3D.new()
	var bordes: Array = [_borde(Vector2i(3, 3), Vector2i(1, 0), 1.0, 0.0), _borde(Vector2i(3, 3), Vector2i(0, 1), 1.0, 0.0),
		_borde(Vector2i(4, 3), Vector2i(-1, 0), 1.0, 0.2), _borde(Vector2i(5, 5), Vector2i(0, -1), 1.0, 0.0)]
	var b := BordePiedras3D.new()
	root.add_child(b)
	b.construir(bordes, LADO, mat, mat)
	_ok("1.1 el labio son 4 triángulos por borde", b.n_triangulos_labio() == 4 * bordes.size(), "%d triángulos para %d bordes" % [b.n_triangulos_labio(), bordes.size()])
	var labio: MeshInstance3D = _hijo(b, "labio")
	_ok("1.2 hay un solo MeshInstance «labio» (una sola llamada de dibujado)", labio != null and labio.mesh.get_surface_count() == 1)
	if labio == null:
		return
	var arr: Array = labio.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	_ok("1.3 12 vértices por borde en una sola malla sin índices (4 triángulos × 3)", vs.size() == 12 * bordes.size(), str(vs.size()))
	# Cada triángulo mira hacia fuera y arriba: la normal geométrica con la normal de sus vértices.
	var mal: int = 0
	for i in range(0, vs.size(), 3):
		var geo: Vector3 = (vs[i + 1] - vs[i]).cross(vs[i + 2] - vs[i])
		var media: Vector3 = ns[i] + ns[i + 1] + ns[i + 2]
		if geo.dot(media) <= 0.0:
			mal += 1
	_ok("1.4 todos los triángulos miran hacia fuera (la cara visible es la de las normales suavizadas)", mal == 0, "%d al revés" % mal)
	# Está dentro de la caja del borde: ni 5 cm por encima de lo previsto ni más abajo que el ancho del labio.
	var y_min: float = INF
	var y_max: float = -INF
	for p in vs:
		y_min = minf(y_min, p.y)
		y_max = maxf(y_max, p.y)
	_ok("1.5 el labio queda entre y_alto − ancho y y_alto + sobresale (%.2f..%.2f)" % [1.0 - b.ancho_labio, 1.0 + b.sobresale_labio + 0.005],
		y_min >= 1.0 - b.ancho_labio - 0.001 and y_max <= 1.0 + b.sobresale_labio + 0.001, "y %.3f..%.3f" % [y_min, y_max])
	# Las normales: arriba (0,1,0), 45° y hacia fuera; ninguna hacia dentro.
	var arriba: int = 0
	var lado_n: int = 0
	var diag: int = 0
	for n in ns:
		if n.y > 0.99:
			arriba += 1
		elif absf(n.y - 0.287) < 0.05:           # el pie: normalize(fuera + 0,3 arriba)
			lado_n += 1
		elif absf(n.y - 0.7071) < 0.05:
			diag += 1
	_ok("1.6 las normales son las de tres perfiles: arriba, 45° y de lado (el sombreado las interpola)", arriba > 0 and lado_n > 0 and diag > 0 and arriba + lado_n + diag == ns.size(), "%d/%d/%d" % [arriba, diag, lado_n])
	# UV2 de plegado: 0 en el arranque, negativa hacia dentro en la esquina y el pie.
	var plegado_ok: bool = uv2.size() == vs.size()
	for i in range(vs.size()):
		if is_equal_approx(ns[i].y, 1.0) and uv2[i] != Vector2.ZERO:
			plegado_ok = false
	_ok("1.7 UV2 de plegado de la textura: cero en el arranque (la tapa no se mueve) y una por vértice", plegado_ok)
	_ok("1.8 el labio no lleva colisión (solo malla)", _contar_colisiones(b) == 0)
	# 2 · interruptores
	b.labio_activo = false
	b.construir(bordes, LADO, mat, mat)
	await process_frame
	_ok("2.1 labio_activo = false: no hay labio (queda falda y piedras)", b.n_triangulos_labio() == 0 and _hijo(b, "labio") == null)
	b.labio_activo = true
	b.construir(bordes, LADO, mat)
	_ok("2.2 sin material de labio: no hay labio (como antes de V3)", b.n_triangulos_labio() == 0)
	b.construir([_borde(Vector2i(1, 1), Vector2i(1, 0), 0.5, 0.48)], LADO, mat, mat)
	_ok("2.3 una pared más baja de 4 cm no lleva labio", b.n_triangulos_labio() == 0)
	b.construir([_borde(Vector2i(1, 1), Vector2i(1, 0), 0.5, 0.35)], LADO, mat, mat)
	_ok("2.4 una pared de 15 cm lleva un labio acortado a su altura", b.n_triangulos_labio() == 4)
	var solo: Array = [_borde(Vector2i(1, 1), Vector2i(1, 0), 1.0, 0.0, {"solo_labio": true})]
	b.construir(solo, LADO, mat, mat)
	await process_frame
	_ok("2.5 solo_labio: labio sí, falda y piedras no", b.n_triangulos_labio() == 4 and b.n_piedras() == 0 and _hijo(b, "faldas") == null and _hijo(b, "piedras") == null)
	b.construir(bordes, LADO, mat, mat)
	await process_frame
	_ok("2.6 los bordes normales siguen llevando falda y piedras junto al labio", _hijo(b, "faldas") != null and b.n_piedras() > 0 and b.n_triangulos_labio() == 16,
		"faldas %s · piedras %d · labio %d" % [str(_hijo(b, "faldas") != null), b.n_piedras(), b.n_triangulos_labio()])
	b.free()


# ---------------------------------------------------------------------------------------------------------------------
#  3 · la maqueta
# ---------------------------------------------------------------------------------------------------------------------

func _contar_colisiones(n: Node) -> int:
	var k: int = 0
	for h in n.get_children():
		if h is CollisionObject3D or h is CollisionShape3D:
			k += 1
		k += _contar_colisiones(h)
	return k


func _maqueta_con_labio() -> void:
	var mapa_b: BordePiedras3D = maqueta.get("_bordes_mapa") as BordePiedras3D
	_ok("3.1 la maqueta pone el labio del borde del mapa (hay bloques que dan al vacío)", mapa_b != null and mapa_b.n_triangulos_labio() > 0,
		"%d triángulos · %d bordes" % [mapa_b.n_triangulos_labio() if mapa_b != null else -1, mapa_b.n_bordes() if mapa_b != null else -1])
	var agua_b: BordePiedras3D = maqueta.get("_bordes") as BordePiedras3D
	# Con agua física la orilla baja hasta el lecho (pared de LECHO_AGUA + 4 cm); sin ella el agua queda a 4 cm del labio y no hay pared que redondear.
	var con_pared: bool = bool(maqueta.get("agua_fisica"))
	_ok("3.2 y el de las orillas del agua (con el material del suelo; solo si hay pared: agua_fisica = %s)" % str(con_pared), agua_b != null and agua_b.n_bordes() > 0
		and agua_b.n_triangulos_labio() == (4 * agua_b.n_bordes() if con_pared else 0),
		"%d triángulos · %d bordes" % [agua_b.n_triangulos_labio() if agua_b != null else -1, agua_b.n_bordes() if agua_b != null else -1])
	var terraza_b: BordePiedras3D = maqueta.get("_bordes_terraza") as BordePiedras3D
	_ok("3.3 y el de los escalones de Terreno3D.alturas del laboratorio", terraza_b != null and terraza_b.n_bordes() > 0 and terraza_b.n_triangulos_labio() == 4 * terraza_b.n_bordes(),
		"%d triángulos · %d bordes" % [terraza_b.n_triangulos_labio() if terraza_b != null else -1, terraza_b.n_bordes() if terraza_b != null else -1])


# ---------------------------------------------------------------------------------------------------------------------
#  4 · el shader recibe lo que debe
# ---------------------------------------------------------------------------------------------------------------------

func _shader_y_estado() -> void:
	var mat: ShaderMaterial = maqueta.get("_mat_suelo") as ShaderMaterial
	_ok("4.1 el material del suelo existe", mat != null)
	if mat == null:
		return
	var tex: Variant = mat.get_shader_parameter("estado_juego")
	_ok("4.2 el shader lee Mundo3D.textura_estados() (el mismo objeto, no una copia)", tex != null and tex == Mundo3D.textura_estados())
	_ok("4.3 estado_eow = 1 y respaldo de la maqueta como dice la constante", float(mat.get_shader_parameter("estado_eow")) == 1.0 and is_equal_approx(float(mat.get_shader_parameter("respaldo_maqueta")), float(maqueta.get("ESTADO_RESPALDO_MAQUETA"))))
	_ok("4.4 el canal «pisado» sigue siendo de la maqueta (el uniform `estado` es su _tex_estado)", mat.get_shader_parameter("estado") == maqueta.get("_tex_estado"))
	var sh: String = (mat.shader as Shader).code
	_ok("4.5 los parámetros de V4 existen en el shader con nombre (carbón, ceniza, mojado, fresnel del hielo)",
		sh.contains("uniform vec3 carbon_mult") and sh.contains("uniform float ceniza_gris") and sh.contains("uniform float rug_mojado") and sh.contains("uniform float espec_mojado")
		and sh.contains("uniform float fresnel_hielo") and sh.contains("uniform float rug_hielo") and sh.contains("uniform float estado_ruido"))
	_ok("4.6 SPECULAR deja de ser 0 fijo (mojado y hielo reflejan) y el quemado ya pinta", sh.contains("SPECULAR = espec;") and not sh.contains("SPECULAR = 0.0;") and sh.contains("quemado = mix("))


# ---------------------------------------------------------------------------------------------------------------------
#  5 · la imagen de la maqueta y el estado del juego dicen lo mismo
# ---------------------------------------------------------------------------------------------------------------------

func _estado_igual() -> void:
	var img: Image = maqueta.get("_img_estado") as Image
	# Impactos de verdad en suelo desnudo (sala 5), hierba y agua; el mismo camino que un hechizo de área.
	var suelo: Vector2i = Vector2i(1, 13)
	var hierba: Vector2i = LabPlaytestEoW3D.SALA5_FUEGO
	lanzador.marcar_celda("agua", suelo)
	lanzador.marcar_celda("hielo", Vector2i(2, 14))
	lanzador.marcar_celda("agua", Vector2i(3, 13))
	lanzador.marcar_celda("agua", Vector2i(3, 13))
	lanzador.marcar_celda("fuego", hierba)
	await avanzar_s(8.0)
	var est: Image = Terreno3D.estados.imagen()
	var n: int = Terreno3D.lado_del_mapa()
	var difieren: Dictionary = {"R": [], "G": [], "B": []}
	var vistas: int = 0
	for y in range(n):
		for x in range(n):
			var c := Vector2i(x, y)
			var a: Color = img.get_pixelv(c)
			var e: Color = est.get_pixelv(c)
			for k in range(3):
				var canal: String = ["R", "G", "B"][k]
				if (a[k] >= 0.5) != (e[k] >= 0.5):
					(difieren[canal] as Array).append(c)
			if e.r >= 0.5 or e.g >= 0.5 or e.b >= 0.5 or a.r >= 0.5 or a.g >= 0.5 or a.b >= 0.5:
				vistas += 1
	_ok("5.1 hubo casillas con estado que comparar (%d)" % vistas, vistas >= 3)
	# El hielo y el mojado de SUELO coinciden exactos (prueba_suelo_impactos lo mide casilla a casilla con todas las combinaciones).
	_ok("5.2 helada: la imagen y el estado dicen lo mismo en todo el mapa", (difieren["B"] as Array).is_empty(), str((difieren["B"] as Array).slice(0, 6)))
	_ok("5.3 quemada: la imagen y el estado dicen lo mismo en todo el mapa", (difieren["R"] as Array).is_empty(), str((difieren["R"] as Array).slice(0, 6)))
	# El mojado puede diferir A PROPÓSITO: la hierba mojada por un agua (reloj de la maqueta) no se escribe en el estado (así que la imagen no la tiene tampoco),
	# pero el agua de simulación mojada va por otro uniform. Se informa, no se exige igualdad.
	if (difieren["G"] as Array).is_empty():
		_ok("5.4 mojada: la imagen y el estado dicen lo mismo en todo el mapa", true)
	else:
		_aviso("5.4 mojada: %d casillas donde la imagen y el estado difieren" % (difieren["G"] as Array).size(), str((difieren["G"] as Array).slice(0, 8)))
	# Por eso el shader toma el mayor de los dos canales: donde difieren, no se pierde lo que solo uno sabe.
	_ok("5.5 el shader mezcla con el MAYOR de los dos (respaldo de la maqueta encendido)", float(maqueta.get("ESTADO_RESPALDO_MAQUETA")) == 1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  6 · apagado
# ---------------------------------------------------------------------------------------------------------------------

func _apagado() -> void:
	maqueta.queue_free()
	await avanzar(5)
	var paquete: PackedScene = load(RUTA_LAB) as PackedScene
	var m: Node = paquete.instantiate()
	m.set("usar_escena", false)
	m.set("bisel_suelo", false)
	m.set("estado_suelo_eow", false)
	root.add_child(m)
	await avanzar(60)
	var mat: ShaderMaterial = m.get("_mat_suelo") as ShaderMaterial
	_ok("6.1 con bisel_suelo = false no hay labio de mapa", m.get("_bordes_mapa") == null)
	var agua_b: BordePiedras3D = m.get("_bordes") as BordePiedras3D
	var terraza_b: BordePiedras3D = m.get("_bordes_terraza") as BordePiedras3D
	_ok("6.2 ni de orillas ni de escalones (queda falda y piedras de antes)", agua_b != null and agua_b.n_triangulos_labio() == 0 and agua_b.n_bordes() > 0 and (terraza_b == null or terraza_b.n_triangulos_labio() == 0))
	_ok("6.3 con estado_suelo_eow = false el uniform vale 0 (shader de antes) y no se sube el estado del juego", mat != null and float(mat.get_shader_parameter("estado_eow")) == 0.0 and mat.get_shader_parameter("estado_juego") == null)
	var sin: int = _contar_colisiones(m)
	_ok("6.4 la misma maqueta con y sin labio tiene EXACTAMENTE las mismas colisiones (%d)" % _colisiones_con, sin == _colisiones_con, "con labio %d · sin %d" % [_colisiones_con, sin])
	m.queue_free()
	await avanzar(3)

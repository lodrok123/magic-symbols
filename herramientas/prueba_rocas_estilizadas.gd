extends SceneTree

## PRUEBA (Pipeline, 4/11): rocas estilizadas del pack LeLu en TRES variantes (musgo = bosque, neutra = cueva, magma = lava). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_rocas_estilizadas.gd
##   1. cada GLB (5 rocas + 5 piedras × 3 variantes) existe, trae UNA malla con UN solo juego de texturas (musgo y neutra: solo albedo; magma: albedo + normal + roughness + emissive), base en y = 0;
##   2. cada id tiene su alto en `Pieza3D.MEDIDA` y su pieza-escena (bloquea lo que pasa de ColisionPieza.ALTO_MIN_SOLIDO: las 5 rocas y piedra_est_*_0; las otras 4 piedras se pisan);
##   3. `RocasEstilizadas.variante_de` elige bien por bioma (bosque → musgo, cueva → neutra, lava → magma) y `id_de` pone el sufijo;
##   4. `VfxTierra` (ROCAS_ESTILIZADAS = true) dibuja terrones, cascotes y bloques con la variante del bioma, a la medida de su tabla.

var _fallos: int = 0
const VARIANTES: Array = ["musgo", "neutra", "magma"]


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	if not bien:
		print("  MAL  %s%s" % [nombre, ("  (" + info + ")") if info != "" else ""])
		_fallos += 1


func _initialize() -> void:
	var ids: Array = []
	for v in VARIANTES:
		for i in 5:
			ids.append(RocasEstilizadas.id_de("roca_est_%d" % i, v))
			ids.append(RocasEstilizadas.id_de("piedra_est_%d" % i, v))
	_ok("30 ids", ids.size() == 30 and ids.has("roca_est_2") and ids.has("roca_est_musgo_2") and ids.has("piedra_est_magma_4"), str(ids.size()))
	print("--- 1. los GLB")
	for id in ids:
		var ps: PackedScene = load("res://arte/meshy/piezas/%s.glb" % id) as PackedScene
		_ok("%s: carga" % id, ps != null)
		if ps == null:
			continue
		var n: Node3D = ps.instantiate() as Node3D
		var mallas: Array = n.find_children("*", "MeshInstance3D", true, false)
		_ok("%s: una malla" % id, mallas.size() == 1)
		var mi: MeshInstance3D = mallas[0] as MeshInstance3D
		var mat: BaseMaterial3D = mi.mesh.surface_get_material(0) as BaseMaterial3D
		var magma: bool = String(id).contains("_magma_")
		_ok("%s: albedo" % id, mat != null and mat.albedo_texture != null)
		_ok("%s: %s" % [id, "juego completo (normal, roughness, emissive)" if magma else "solo albedo (sin normal, roughness ni emissive de otro juego)"],
			mat != null and (mat.normal_texture != null) == magma and (mat.roughness_texture != null) == magma and mat.emission_enabled == magma and (mat.emission_texture != null) == magma)
		if mat != null and mat.albedo_texture != null:
			var ruta: String = mat.albedo_texture.resource_path
			_ok("%s: albedo del juego correcto (%s)" % [id, ruta.get_file()], ruta.contains("magma") == magma and ruta.contains("musgo") == String(id).contains("_musgo_"))
		var ab: AABB = mi.mesh.get_aabb()
		var c: Vector3 = ab.position + ab.size * 0.5
		_ok("%s: base en y = 0 y centrada" % id, absf(ab.position.y) < 0.001 and absf(c.x) < 0.01 and absf(c.z) < 0.01)
		n.free()
	print("--- 2. alta de las piezas")
	var med: Dictionary = (Pieza3D.MEDIDA as Dictionary)
	for id in ids:
		_ok("%s: en MEDIDA" % id, med.has(id))
		var ps2: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		_ok("%s: pieza-escena" % id, ps2 != null)
		if ps2 == null:
			continue
		var raiz: Node3D = ps2.instantiate() as Node3D
		var debe: bool = float(Pieza3D.MEDIDA.get(id, 0.0)) > ColisionPieza.ALTO_MIN_SOLIDO + ColisionPieza.ALTO_TOLERANCIA      # 4/11: lo bajo (≤ 0,45 u) se pisa: piedra_est_*_1 (0,4) ya no bloquea
		_ok("%s: bloquea = %s" % [id, str(debe)], bool(raiz.get_meta("bloquea", false)) == debe)
		_ok("%s: cuerpo de colisión" % id, (raiz.get_node_or_null("cuerpo") != null) == debe)
		raiz.free()
	print("--- 3. elección por bioma")
	_ok("bosque → musgo", RocasEstilizadas.variante_de("bosque", "Bosque_01") == "musgo")
	_ok("Bosque_02 → musgo", RocasEstilizadas.variante_de("bosque", "Bosque_02") == "musgo")
	_ok("estilo cueva → neutra", RocasEstilizadas.variante_de("cueva", "lo_que_sea") == "neutra")
	for n in ["Cueva", "CuevaAgua", "CuevaResonante", "GrutaBatida", "Grutas"]:
		_ok("nivel %s → neutra" % n, RocasEstilizadas.variante_de("bosque", n) == "neutra")
	_ok("estilo magma → magma", RocasEstilizadas.variante_de("magma", "X") == "magma")
	_ok("bioma magma (metadato) → magma", RocasEstilizadas.variante_de("bosque", "X", "magma") == "magma")
	_ok("id_de musgo", RocasEstilizadas.id_de("roca_est_3", "musgo") == "roca_est_musgo_3")
	_ok("id_de neutra", RocasEstilizadas.id_de("piedra_est_2", "neutra") == "piedra_est_2")
	_ok("id_de magma", RocasEstilizadas.id_de("piedra_est_4", "magma") == "piedra_est_magma_4")
	_ok("sin maqueta: musgo", RocasEstilizadas.variante_actual() == "musgo")
	# una maqueta de mentira con `estilo` y `nivel` (como prueba_test2.gd) en el árbol
	var falsa := Node3D.new()
	var gd := GDScript.new()
	gd.source_code = "extends Node3D\nvar estilo: String = \"cueva\"\nvar nivel: String = \"Cueva\"\n"
	gd.reload()
	falsa.set_script(gd)
	root.add_child(falsa)
	_ok("con una maqueta de cueva en el árbol → neutra", RocasEstilizadas.variante_actual() == "neutra")
	falsa.set("estilo", "bosque")
	falsa.set("nivel", "Bosque_02")
	_ok("con una maqueta de bosque → musgo", RocasEstilizadas.variante_actual() == "musgo")
	falsa.set_meta("bioma", "magma")
	_ok("con la marca de magma → magma", RocasEstilizadas.variante_actual() == "magma")
	falsa.remove_meta("bioma")
	print("--- 4. la tierra del hechizo")
	_ok("ROCAS_ESTILIZADAS activo", VfxTierra.ROCAS_ESTILIZADAS)
	VfxTierra.usar_modelos = true
	for v in VARIANTES:
		RocasEstilizadas.forzar = v
		for id in VfxTierra.ROCA_DE:
			var esperado: String = RocasEstilizadas.id_de(String(VfxTierra.ROCA_DE[id]), v)
			var m: MeshInstance3D = VfxTierra.pieza(String(id))
			_ok("%s [%s] → %s: hay modelo" % [id, v, esperado], bool(m.get_meta("modelo", false)))
			var mat: BaseMaterial3D = m.mesh.surface_get_material(0) as BaseMaterial3D
			var tex: String = mat.albedo_texture.resource_path if mat != null and mat.albedo_texture != null else ""
			_ok("%s [%s]: lleva el albedo de su variante (%s)" % [id, v, tex.get_file()], tex.contains(v if v != "neutra" else "rocas_albedo"))
			var caja: AABB = m.mesh.get_aabb()
			var pide: Vector3 = VfxTierra.MEDIDA[id]
			if String(id).begins_with("bloque_"):
				_ok("%s [%s]: caja = %s" % [id, v, str(pide)], absf(caja.size.x - pide.x) < 0.01 and absf(caja.size.y - pide.y) < 0.01 and absf(caja.size.z - pide.z) < 0.01 and absf(caja.position.y) < 0.001, str(caja.size))
			else:
				var lado: float = maxf(pide.x, maxf(pide.y, pide.z))
				_ok("%s [%s]: lado mayor = %.2f" % [id, v, lado], absf(maxf(caja.size.x, maxf(caja.size.y, caja.size.z)) - lado) < 0.005 and absf(caja.position.y + caja.size.y * 0.5) < 0.005)
			m.free()
	RocasEstilizadas.forzar = ""
	_ok("pincho_tierra_0 sigue con lo suyo (no es una roca)", not VfxTierra.ROCA_DE.has("pincho_tierra_0"))
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)

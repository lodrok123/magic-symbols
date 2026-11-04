extends SceneTree

## PRUEBA (Pipeline, 4/11): rocas estilizadas del pack LeLu (`roca_est_0..4`, `piedra_est_0..4`). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_rocas_estilizadas.gd
##   1. cada GLB de `arte/meshy/piezas/` existe, trae UNA malla con material de albedo + normal + roughness (texturas realmente cargadas), origen en el centro de la base;
##   2. cada id tiene su alto en `Pieza3D.MEDIDA` y su pieza-escena `arte/piezas/<id>.tscn` (bloquean las 5 rocas y piedra_est_0/1; las otras 3 se pisan);
##   3. `VfxTierra` (ROCAS_ESTILIZADAS = true) dibuja terrones, cascotes y bloques con ellas, a la medida de su tabla y con la tapa del bloque ancha.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print("  %s   %s%s" % ["OK " if bien else "MAL", nombre, ("  (" + info + ")") if info != "" else ""])
	if not bien:
		_fallos += 1


func _initialize() -> void:
	var ids: Array = []
	for i in 5:
		ids.append("roca_est_%d" % i)
		ids.append("piedra_est_%d" % i)
	print("--- 1. los GLB")
	for id in ids:
		var ruta: String = "res://arte/meshy/piezas/%s.glb" % id
		var ps: PackedScene = load(ruta) as PackedScene
		_ok("%s: carga" % id, ps != null)
		if ps == null:
			continue
		var n: Node3D = ps.instantiate() as Node3D
		var mallas: Array = n.find_children("*", "MeshInstance3D", true, false)
		_ok("%s: una malla" % id, mallas.size() == 1, str(mallas.size()))
		var mi: MeshInstance3D = mallas[0] as MeshInstance3D
		var mat: BaseMaterial3D = mi.mesh.surface_get_material(0) as BaseMaterial3D
		_ok("%s: material con albedo, normal y roughness" % id, mat != null and mat.albedo_texture != null and mat.normal_texture != null and mat.roughness_texture != null)
		_ok("%s: sin emissive (no pega con tierra)" % id, mat != null and not mat.emission_enabled)
		var ab: AABB = mi.mesh.get_aabb()
		var c: Vector3 = ab.position + ab.size * 0.5
		_ok("%s: base en y = 0 y centrada en X/Z" % id, absf(ab.position.y) < 0.001 and absf(c.x) < 0.01 and absf(c.z) < 0.01, str(ab))
		n.free()
	print("--- 2. alta de las piezas")
	var med: Dictionary = (Pieza3D.MEDIDA as Dictionary)
	for id in ids:
		_ok("%s: en MEDIDA" % id, med.has(id))
		var ruta_t: String = "res://arte/piezas/%s.tscn" % id
		var ps2: PackedScene = load(ruta_t) as PackedScene
		_ok("%s: pieza-escena" % id, ps2 != null)
		if ps2 == null:
			continue
		var raiz: Node3D = ps2.instantiate() as Node3D
		var bloquea: bool = bool(raiz.get_meta("bloquea", false))
		var debe: bool = String(id).begins_with("roca_") or id == "piedra_est_0" or id == "piedra_est_1"
		_ok("%s: bloquea = %s" % [id, str(debe)], bloquea == debe)
		_ok("%s: cuerpo de colisión %s" % [id, "sí" if debe else "no"], (raiz.get_node_or_null("cuerpo") != null) == debe)
		raiz.free()
	print("--- 3. la tierra del hechizo")
	_ok("ROCAS_ESTILIZADAS activo", VfxTierra.ROCAS_ESTILIZADAS)
	VfxTierra.usar_modelos = true
	for id in VfxTierra.ROCA_DE:
		_ok("%s → %s: hay modelo" % [id, VfxTierra.ROCA_DE[id]], VfxTierra.hay_modelo(String(id)))
		var m: MeshInstance3D = VfxTierra.pieza(String(id))
		var caja: AABB = m.mesh.get_aabb()
		var pide: Vector3 = VfxTierra.MEDIDA[id]
		if String(id).begins_with("bloque_"):
			_ok("%s: caja = %s" % [id, str(pide)], caja.size.is_equal_approx(pide) or (absf(caja.size.x - pide.x) < 0.01 and absf(caja.size.y - pide.y) < 0.01 and absf(caja.size.z - pide.z) < 0.01), str(caja.size))
			_ok("%s: origen en el centro de la base" % id, absf(caja.position.y) < 0.001)
		else:
			var mayor: float = maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
			_ok("%s: lado mayor = %.2f" % [id, maxf(pide.x, maxf(pide.y, pide.z))], absf(mayor - maxf(pide.x, maxf(pide.y, pide.z))) < 0.005, "%.3f" % mayor)
			_ok("%s: origen en su centro" % id, absf(caja.position.y + caja.size.y * 0.5) < 0.005)
		_ok("%s: lleva la textura de la roca" % id, (m.mesh.surface_get_material(0) as BaseMaterial3D).normal_texture != null)
		m.free()
	_ok("pincho_tierra_0 sigue con lo suyo (no es una roca)", not VfxTierra.ROCA_DE.has("pincho_tierra_0"))
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)

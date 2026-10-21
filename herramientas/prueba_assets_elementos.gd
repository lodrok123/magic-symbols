extends SceneTree

## PRUEBA (22/10, assets de elementos): los modelos de Meshy de TIERRA y HIELO y el atlas de VIENTO están enganchados en los VFX.
##   1. Atlas de viento: 512 × 512, las 16 casillas tienen píxeles con alfa; con `VfxViento.usar_atlas = false` se usa el placeholder (otra textura).
##   2. Cada id de tierra (15) y de hielo (11) carga su GLB; con el interruptor ENCENDIDO `pieza(id)` usa el modelo (meta `modelo` = true) y con él APAGADO la primitiva
##      (meta false), y las dos miden lo que dice `MEDIDA` (tolerancia) con el origen que toca; la esquirla va a lo largo de Z; los 4 trozos de la placa encajan en la entera.
##   3. El material de hielo es translúcido (ShaderMaterial con alfa), no el opaco del GLB.
##   4. Enganche: el proyectil de tierra y el de hielo dibujan el modelo; el de hielo apunta con la punta (+Z) hacia donde va; impacto, racimos que brotan, escarcha y
##      placa rota crean piezas y se liberan solos; el remolino de viento lleva tarjetas de la fila 3 del atlas y las hojas usan el atlas.
##   5. El proyectil de hielo es la esquirla girando por defecto (`VfxHielo.proyectil_esquirla = true`); con false vuelve el cometa; con los modelos apagados, la bola.
##   7. Impacto de tierra legible (terrones + cascotes 0,2–0,32 u + polvo propio, corto y translúcido; GLB con textura de tierra). 8. Rayo de hielo (`VfxHielo.rayo`).
##   6. Placa rota: al fundirse o soltarse el hielo del agua, `Lanzador3D` avisa «hielo_roto» por `Mundo3D.impacto` y `VfxElemento3D` dibuja `VfxHielo.placa_rota`.
##   4b. Hojas de viento de 0,25–0,5 u y tarjetas de remolino de 0,5–1,0 u.
##   godot --headless --path . --fixed-fps 30 -s res://herramientas/prueba_assets_elementos.gd

var _fallos: int = 0
var _mundo: Node3D = null


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("  OK   ", texto)
	else:
		print("  MAL  ", texto)
		_fallos += 1


## Como `_ok` pero con el texto primero (y una info opcional).
func _okc(texto: String, cond: bool, info: String = "") -> void:
	_ok(cond, texto + ((" · " + info) if info != "" else ""))


func _esperar(s: float) -> void:
	await create_timer(maxf(s, 0.02)).timeout
	await process_frame


func _correr() -> void:
	await process_frame
	_mundo = Node3D.new()
	root.add_child(_mundo)
	_atlas()
	_piezas_tierra()
	_piezas_hielo()
	_material()
	await _enganche()
	await _viento()
	_interruptor_hielo()
	await _placa_al_romper_hielo()
	await _tierra_legible()
	await _rayo_hielo()
	_mundo.queue_free()
	await process_frame
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------
func _atlas() -> void:
	print("--- 1. atlas de viento")
	VfxViento.usar_atlas = true
	var t: Texture2D = VfxViento.atlas()
	_ok(ResourceLoader.exists(VfxViento.RUTA_ATLAS) and VfxViento.atlas_real(), "el PNG del atlas existe y es el que se usa")
	_ok(t != null and t.get_width() == 512 and t.get_height() == 512, "el atlas mide 512 × 512 (%d × %d)" % [t.get_width(), t.get_height()])
	var img: Image = t.get_image()
	var vacias: Array = []
	for f in range(4):
		for c in range(4):
			var n: int = 0
			for y in range(f * 128, f * 128 + 128, 4):
				for x in range(c * 128, c * 128 + 128, 4):
					if img.get_pixel(x, y).a > 0.5:
						n += 1
			if n < 20:
				vacias.append(Vector2i(c, f))
	_ok(vacias.is_empty(), "las 16 casillas (4 filas × 4) tienen dibujo con alfa (vacías: %s)" % str(vacias))
	VfxViento.usar_atlas = false
	var ph: Texture2D = VfxViento.atlas()
	_ok(ph != t and not VfxViento.atlas_real(), "con usar_atlas = false se usa el placeholder (otra textura)")
	VfxViento.usar_atlas = true


# ---------------------------------------------------------------------------------------------------------------------
func _caja_pieza(mi: MeshInstance3D) -> AABB:
	var a: AABB = mi.mesh.get_aabb()
	return AABB(a.position * mi.scale, a.size * mi.scale)


func _cerca(a: Vector3, b: Vector3, tol: float) -> bool:
	return absf(a.x - b.x) <= tol and absf(a.y - b.y) <= tol and absf(a.z - b.z) <= tol


## Cuántos vértices (del total) están a menos de `eps` de la altura máxima: una tapa plana tiene muchos.
func _en_tapa(m: Mesh, eps: float) -> float:
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top: float = m.get_aabb().end.y
	var n: int = 0
	for p in v:
		if p.y > top - eps:
			n += 1
	return float(n) / float(maxi(v.size(), 1))


func _piezas_tierra() -> void:
	print("--- 2a. piezas de tierra: GLB cargado, medida, origen; con el interruptor apagado, la primitiva")
	for id in VfxTierra.ids():
		_ok(ResourceLoader.exists("res://arte/meshy/piezas/%s.glb" % id), "%s: el GLB existe" % id)
		VfxTierra.usar_modelos = true
		VfxTierra._modelos.erase(id)
		var mi: MeshInstance3D = VfxTierra.pieza(id)
		var med: Vector3 = VfxTierra.MEDIDA[id]
		var caja: AABB = _caja_pieza(mi)
		_ok(bool(mi.get_meta("modelo")) and VfxTierra.hay_modelo(id), "%s: con el interruptor encendido usa el MODELO" % id)
		var ok_med: bool
		if id.begins_with("bloque_"):
			ok_med = _cerca(caja.size, med, 0.01)
		elif id.begins_with("pincho_"):
			ok_med = absf(caja.size.y - med.y) < 0.01 and caja.size.x <= med.x * 1.7 and caja.size.z <= med.z * 1.7
		else:
			ok_med = absf(maxf(caja.size.x, maxf(caja.size.y, caja.size.z)) - maxf(med.x, maxf(med.y, med.z))) < 0.01
		_ok(ok_med, "%s: mide %.2f × %.2f × %.2f (pide %.2f × %.2f × %.2f)" % [id, caja.size.x, caja.size.y, caja.size.z, med.x, med.y, med.z])
		var cxz: bool = absf(caja.position.x + caja.size.x * 0.5) < 0.01 and absf(caja.position.z + caja.size.z * 0.5) < 0.01
		if id.begins_with("bloque_") or id.begins_with("pincho_"):
			_ok(cxz and absf(caja.position.y) < 0.005, "%s: origen en el centro de la base" % id)
		else:
			_ok(cxz and absf(caja.position.y + caja.size.y * 0.5) < 0.01, "%s: origen en su centro" % id)
		if id.begins_with("bloque_"):
			print("  INFO %s: %.0f %% de los vértices están en la tapa (±2 cm de %.2f u)" % [id, _en_tapa(mi.mesh, 0.02) * 100.0, caja.end.y])
		mi.free()
		VfxTierra.usar_modelos = false
		var prim: MeshInstance3D = VfxTierra.pieza(id)
		_ok(not bool(prim.get_meta("modelo")) and not VfxTierra.hay_modelo(id), "%s: con el interruptor apagado, la primitiva" % id)
		prim.free()
	VfxTierra.usar_modelos = true


func _piezas_hielo() -> void:
	print("--- 2b. piezas de hielo")
	for id in VfxHielo.ids():
		_ok(ResourceLoader.exists("res://arte/meshy/piezas/%s.glb" % id), "%s: el GLB existe" % id)
		VfxHielo.usar_modelos = true
		VfxHielo._modelos.erase(id)
		var mi: MeshInstance3D = VfxHielo.pieza(id)
		var med: Vector3 = VfxHielo.MEDIDA[id]
		var caja: AABB = _caja_pieza(mi)
		_ok(bool(mi.get_meta("modelo")) and VfxHielo.hay_modelo(id), "%s: con el interruptor encendido usa el MODELO" % id)
		var ok_med: bool
		if id.begins_with("placa_hielo_rota"):
			ok_med = absf(caja.size.y - med.y) < 0.01 and caja.size.x <= med.x + 0.01 and caja.size.z <= med.z + 0.01
			if id == "placa_hielo_rota":
				ok_med = ok_med and _cerca(caja.size, med, 0.01)
		elif id == "esquirla_hielo":
			ok_med = absf(caja.size.z - med.z) < 0.01 and caja.size.x < caja.size.z and caja.size.y < caja.size.z
		else:
			ok_med = absf(caja.size.y - med.y) < 0.01 and caja.size.x <= med.x * 1.7 and caja.size.z <= med.z * 1.7
		_ok(ok_med, "%s: mide %.3f × %.3f × %.3f (pide %.2f × %.2f × %.2f)" % [id, caja.size.x, caja.size.y, caja.size.z, med.x, med.y, med.z])
		if id == "esquirla_hielo":
			var c: Vector3 = caja.position + caja.size * 0.5
			_ok(c.length() < 0.01, "esquirla_hielo: origen en su centro y largo a lo largo de Z (punta a +Z)")
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var r_mas: float = 0.0
			var r_menos: float = 0.0
			for p in v:
				if p.z > caja.size.z * 0.3:
					r_mas = maxf(r_mas, Vector2(p.x, p.y).length())
				elif p.z < -caja.size.z * 0.3:
					r_menos = maxf(r_menos, Vector2(p.x, p.y).length())
			print("  INFO esquirla: radio máximo a +Z %.3f u, a -Z %.3f u (la punta es el extremo más fino)" % [r_mas, r_menos])
		elif not id.begins_with("placa_hielo_rota_"):
			_ok(absf(caja.position.x + caja.size.x * 0.5) < 0.01 and absf(caja.position.y) < 0.005, "%s: origen en el centro de la base" % id)
		mi.free()
		VfxHielo.usar_modelos = false
		var prim: MeshInstance3D = VfxHielo.pieza(id)
		var cp: AABB = _caja_pieza(prim)
		_ok(not bool(prim.get_meta("modelo")) and not VfxHielo.hay_modelo(id) and cp.size.y > 0.0, "%s: con el interruptor apagado, la primitiva (%.2f × %.2f × %.2f)" % [id, cp.size.x, cp.size.y, cp.size.z])
		prim.free()
	VfxHielo.usar_modelos = true
	# los cuatro trozos encajan dentro de la placa entera
	var e: AABB = _caja_pieza(VfxHielo.pieza("placa_hielo_rota"))
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in range(VfxHielo.N_TROZOS):
		var t: AABB = _caja_pieza(VfxHielo.pieza("placa_hielo_rota_%d" % i))
		lo = lo.min(t.position)
		hi = hi.max(t.end)
		var dentro: bool = t.position.x >= e.position.x - 0.03 and t.end.x <= e.end.x + 0.03 and t.position.z >= e.position.z - 0.03 and t.end.z <= e.end.z + 0.03
		_ok(dentro, "placa_hielo_rota_%d cae dentro de la entera (desplazada %.2f, %.2f u de su centro)" % [i, VfxHielo.trozo_desplazamiento(i).x, VfxHielo.trozo_desplazamiento(i).y])
	_ok(absf((hi.x - lo.x) - e.size.x) < 0.05 and absf((hi.z - lo.z) - e.size.z) < 0.05, "la unión de los 4 trozos mide lo que la entera (%.2f × %.2f frente a %.2f × %.2f)" % [hi.x - lo.x, hi.z - lo.z, e.size.x, e.size.z])


func _material() -> void:
	print("--- 3. material de hielo")
	VfxHielo.usar_modelos = true
	var mi: MeshInstance3D = VfxHielo.pieza("racimo_hielo_m")
	var mat: Material = mi.material_override
	_ok(mat is ShaderMaterial and (mat as ShaderMaterial).shader.code.contains("ALPHA"), "los modelos de hielo llevan un material con alfa (no el opaco del GLB)")
	var origen: Material = mi.mesh.surface_get_material(0)
	_ok(origen is StandardMaterial3D and (origen as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat != origen, "el material del GLB (opaco) queda sustituido por el de hielo")
	_ok(mat == VfxHielo.pieza("racimo_hielo_m").material_override, "el material se comparte entre instancias de la misma pieza")
	mi.free()


# ---------------------------------------------------------------------------------------------------------------------
func _hijos(nombre: String) -> Array:
	return _mundo.find_children(nombre, "MeshInstance3D", true, false)


func _enganche() -> void:
	print("--- 4. enganche en los VFX")
	VfxTierra.usar_modelos = true
	VfxHielo.usar_modelos = true
	var seg := Node3D.new()
	_mundo.add_child(seg)
	var t: MeshInstance3D = VfxTierra.proyectil(seg, Vector3.RIGHT, 0.3)
	_ok(bool(t.get_meta("modelo")), "el proyectil de tierra dibuja un terrón de Meshy")
	seg.free()
	# bloques de tierra: emergen con el modelo
	var raiz := Node3D.new()
	_mundo.add_child(raiz)
	var bl: Array = VfxTierra.emerger(raiz, Vector3.ZERO, 0.8, 1.0, 3.0, "barrera", 1.5)
	var con_modelo: int = 0
	for b in bl:
		if bool((b as MeshInstance3D).get_meta("modelo")):
			con_modelo += 1
	_ok(bl.size() > 0 and con_modelo == bl.size(), "la barrera de tierra monta %d bloques, todos de Meshy" % bl.size())
	var cas: Array = VfxTierra.impacto(_mundo, Vector3(10, 1, 0), 1.2, 0.0, 4)
	var cm: int = 0
	for c in cas:
		var mi: MeshInstance3D = (c as Node3D).get_child(0) as MeshInstance3D
		if mi != null and bool(mi.get_meta("modelo")):
			cm += 1
	_ok(cas.size() == 4 and cm == 4, "el impacto de tierra suelta %d cascotes de Meshy" % cm)
	raiz.queue_free()
	# hielo: proyectil con la punta hacia donde va
	var sh := Node3D.new()
	_mundo.add_child(sh)
	var dir := Vector3(0.6, 0.0, -0.8).normalized()
	var e: MeshInstance3D = VfxHielo.proyectil(sh, dir, 0.3)
	_ok(bool(e.get_meta("modelo")) and e.name == "esquirla_hielo", "el proyectil de hielo dibuja la esquirla de Meshy")
	var largo_mundo: Vector3 = e.global_transform.basis.z.normalized()
	_ok(largo_mundo.dot(dir) > 0.99, "la esquirla apunta (+Z de la malla) hacia donde va (producto escalar %.3f)" % largo_mundo.dot(dir))
	var c_e: AABB = _caja_pieza(e)
	_ok(absf(c_e.size.z - 0.3 * VfxHielo.ESQUIRLA_LARGO_K) < 0.02, "su largo sigue al radio del proyectil: %.2f u (r_u 0,3 × %.1f)" % [c_e.size.z, VfxHielo.ESQUIRLA_LARGO_K])
	sh.free()
	# hielo: impacto, racimos que brotan, escarcha y placa rota
	var imp: Array = VfxHielo.impacto(_mundo, Vector3(20, 1, 0), 1.0, 0.0)
	_ok(imp.size() == 1 + VfxHielo.IMPACTO_PEQUENOS + VfxHielo.IMPACTO_PINCHOS, "el impacto de hielo brota %d piezas (racimo m, %d p, %d pinchos)" % [imp.size(), VfxHielo.IMPACTO_PEQUENOS, VfxHielo.IMPACTO_PINCHOS])
	var rz := Node3D.new()
	_mundo.add_child(rz)
	var rac: Array = VfxHielo.emerger(rz, Vector3(30, 0, 0), 0.8, 1.4, 3.0, "barrera", 1.5)
	_ok(rac.size() >= 5 and rac.size() <= VfxHielo.MAX_RACIMOS, "la barrera de hielo brota %d racimos grandes" % rac.size())
	var rz2 := Node3D.new()
	_mundo.add_child(rz2)
	var es: Array = VfxHielo.emerger(rz2, Vector3(40, 0, 0), 0.6, 1.0, 3.0, "esfera", 1.0)
	_ok(es.size() == 1 + VfxHielo.PEQUENOS_ESFERA, "la esfera de hielo brota un racimo grande y %d pequeños" % VfxHielo.PEQUENOS_ESFERA)
	var esc: Array = VfxHielo.escarcha_modelos(_mundo, Vector3(50, 0, 0), 1.0, 0.0)
	_ok(esc.size() == VfxHielo.ESCARCHA_RACIMOS + VfxHielo.ESCARCHA_PINCHOS, "congelar algo deja %d racimos y %d pinchos de escarcha" % [VfxHielo.ESCARCHA_RACIMOS, VfxHielo.ESCARCHA_PINCHOS])
	var placa: Node3D = VfxHielo.placa_rota(_mundo, Vector3(60, 0, 0), 1.0)
	_ok(placa != null and placa.get_child_count() == VfxHielo.N_TROZOS, "la placa rota separa %d trozos" % VfxHielo.N_TROZOS)
	# la reacción «congelado» de ReaccionesVfx3D usa los pinchos
	var antes: int = _hijos("pincho_escarcha_*").size()
	VfxReaccion3D.escarcha(_mundo, Vector3(70, 0, 0), 1.0)
	_ok(_hijos("pincho_escarcha_*").size() > antes, "VfxReaccion3D.escarcha (reacción «congelado») saca pinchos de escarcha")
	await _esperar(0.6)
	_ok(_hijos("racimo_hielo_*").size() > 0 and _hijos("terron_*").size() > 0, "durante el efecto las piezas (racimos de hielo, terrones del impacto de tierra) están en el árbol")
	await _esperar(4.2)
	_ok(_hijos("racimo_hielo_*").is_empty() and _hijos("pincho_escarcha_*").is_empty() and _hijos("placa_hielo_rota_*").is_empty() and _hijos("cascote_*").is_empty() and _hijos("terron_*").is_empty(),
		"al acabar no queda ninguna pieza viva de hielo ni de tierra (cascotes y terrones incluidos)")
	_ok(_hijos("bloque_tierra_*").is_empty(), "ni bloques de tierra")


func _viento() -> void:
	print("--- 4b. viento: atlas en hojas y remolinos")
	VfxViento.usar_atlas = true
	var seg := Node3D.new()
	_mundo.add_child(seg)
	VfxViento.proyectil(seg, Vector3.RIGHT, 0.4)
	var hojas: Array = seg.find_children("hoja_*", "MeshInstance3D", true, false)
	var del_atlas: int = 0
	var filas_ok: bool = true
	for h in hojas:
		var m: StandardMaterial3D = (h as MeshInstance3D).material_override as StandardMaterial3D
		if m.albedo_texture == VfxViento.atlas():
			del_atlas += 1
		filas_ok = filas_ok and m.uv1_offset.y < 0.74 and m.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED
	_ok(hojas.size() > 0 and del_atlas == hojas.size(), "las hojas del proyectil de viento (%d) usan el atlas de Meshy" % hojas.size())
	_ok(filas_ok, "las hojas arrastradas eligen casillas de las filas 0–2 y son billboard")
	var lados_ok: bool = hojas.size() > 0
	var lmin: float = INF
	var lmax: float = 0.0
	for h in hojas:
		var lado: float = ((h as MeshInstance3D).mesh as QuadMesh).size.x
		lmin = minf(lmin, lado)
		lmax = maxf(lmax, lado)
		lados_ok = lados_ok and lado >= 0.25 - 1e-4 and lado <= 0.5 + 1e-4
	_ok(lados_ok, "las hojas del proyectil miden %.2f–%.2f u (legible: 0,25–0,5; antes 0,09–0,26)" % [lmin, lmax])
	_ok(VfxViento.HOJA_TAM_MIN >= 0.25 and VfxViento.HOJA_TAM_MAX <= 0.5, "constantes con nombre HOJA_TAM_MIN/MAX = %.2f/%.2f" % [VfxViento.HOJA_TAM_MIN, VfxViento.HOJA_TAM_MAX])
	seg.free()
	var rem: Node3D = VfxViento.remolino(_mundo, Vector3(80, 0, 0), 1.2, 0.0)
	var tarjetas: Array = rem.find_children("remolino_*", "MeshInstance3D", true, false)
	var fila3: bool = tarjetas.size() > 0
	var mascara: bool = VfxViento.remolino_mascara
	for t in tarjetas:
		var mo: Material = (t as MeshInstance3D).material_override
		if mo is ShaderMaterial:
			# con `remolino_mascara`: ShaderMaterial (forma del atlas, color COLOR_CINTA); la casilla va en el uniform `uv_desfase`
			fila3 = fila3 and mascara and absf((mo as ShaderMaterial).get_shader_parameter("uv_desfase").y - 0.75) < 0.001
		else:
			var m3: StandardMaterial3D = mo as StandardMaterial3D
			fila3 = fila3 and not mascara and m3 != null and absf(m3.uv1_offset.y - 0.75) < 0.001 and m3.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED and m3.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
	var rem_ok: bool = tarjetas.size() > 0
	for t in tarjetas:
		var lt: float = ((t as MeshInstance3D).mesh as QuadMesh).size.x
		rem_ok = rem_ok and lt >= 0.5 - 1e-4 and lt <= 1.0 + 1e-4
	_ok(rem_ok, "las tarjetas de remolino miden entre 0,5 y 1,0 u (la jugadora ≈ 1 u)")
	_ok(fila3, "el remolino de impacto lleva %d tarjetas de la fila 3 (remolinos blancos, billboard, mezcla alfa)" % tarjetas.size())
	_ok(mascara, "por defecto VfxViento.remolino_mascara = true (tarjetas con ShaderMaterial)")
	VfxViento.remolino_mascara = false
	var rem_ant: Node3D = VfxViento.remolino(_mundo, Vector3(85, 0, 0), 1.2, 0.0)
	var tarj_ant: Array = rem_ant.find_children("remolino_*", "MeshInstance3D", true, false)
	var antiguo: bool = tarj_ant.size() > 0
	for t in tarj_ant:
		var ma: StandardMaterial3D = (t as MeshInstance3D).material_override as StandardMaterial3D
		antiguo = antiguo and ma != null and absf(ma.uv1_offset.y - 0.75) < 0.001 and ma.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED and ma.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
	VfxViento.remolino_mascara = mascara
	_ok(antiguo, "con remolino_mascara = false las tarjetas vuelven al StandardMaterial3D de antes (%d, uv1_offset, billboard, alfa)" % tarj_ant.size())
	var pie := Node3D.new()
	_mundo.add_child(pie)
	var tor: Node3D = VfxViento.torbellino(pie, Vector3.UP, 0.8, 2.0, 3.0)
	_ok(tor.find_children("remolino_*", "MeshInstance3D", true, false).size() == VfxViento.TORBELLINO_TARJETAS, "el torbellino lleva %d tarjetas de remolino" % VfxViento.TORBELLINO_TARJETAS)
	VfxViento.usar_atlas = false
	var rem2: Node3D = VfxViento.remolino(_mundo, Vector3(90, 0, 0), 1.2, 0.0)
	_ok(rem2.find_children("remolino_*", "MeshInstance3D", true, false).is_empty(), "con usar_atlas = false no hay tarjetas de remolino (vuelve el dibujo de antes)")
	VfxViento.usar_atlas = true
	await _esperar(4.0)
	_ok(not is_instance_valid(rem) and not is_instance_valid(rem2) and not is_instance_valid(tor), "el remolino y el torbellino se liberan solos")
	pie.queue_free()


func _interruptor_hielo() -> void:
	print("--- 5. proyectil de hielo: esquirla por defecto (decisión de Pablo); con VfxHielo.proyectil_esquirla = false vuelve el cometa del kit")
	var hv := VfxElemento3D.new()
	_mundo.add_child(hv)
	VfxHielo.usar_modelos = true
	VfxHielo.proyectil_esquirla = true
	_ok(VfxHielo.proyectil_esquirla and VfxHielo.proyectil_con_esquirla(), "por defecto proyectil_esquirla = true")
	var seg0 := Node3D.new()
	_mundo.add_child(seg0)
	hv._pieza_proyectil("hielo", seg0, Vector3.RIGHT, 0.3, 4.0)
	_ok(not seg0.find_children("esquirla_hielo", "MeshInstance3D", true, false).is_empty(), "por defecto el proyectil de hielo lleva la esquirla")
	var giros: Array = seg0.find_children("EsquirlaGiro", "Node3D", true, false)
	_ok(giros.size() == 1 and giros[0].has_method("_process"), "y la esquirla GIRA sobre su eje (nodo con _process)")
	var cola_e: Array = hv._recoger_cola(seg0, "hielo")
	var mallas_cola: int = 0
	for n in cola_e:
		if n is MeshInstance3D:
			mallas_cola += 1
	_ok(mallas_cola == 0, "la esquirla es el cuerpo, no cola (solo se recogen partículas: %d nodos)" % cola_e.size())
	VfxHielo.proyectil_esquirla = false
	var seg := Node3D.new()
	_mundo.add_child(seg)
	hv._pieza_proyectil("hielo", seg, Vector3.RIGHT, 0.3, 4.0)
	_ok(seg.find_children("esquirla_hielo", "MeshInstance3D", true, false).is_empty() and seg.get_child_count() > 0, "con proyectil_esquirla = false vuelve la bola del kit (cometa), sin esquirla")
	var cola0: Array = hv._recoger_cola(seg, "hielo")
	var mallas_no_esfera: int = 0
	for n in seg.find_children("*", "MeshInstance3D", true, false):
		if not ((n as MeshInstance3D).mesh is SphereMesh):
			mallas_no_esfera += 1
	_ok(mallas_no_esfera == 0 or cola0.size() >= mallas_no_esfera, "y la cola de cometa se recoge como cola (se apaga al pararse): %d nodos" % cola0.size())
	var seg2 := Node3D.new()
	_mundo.add_child(seg2)
	VfxHielo.usar_modelos = false
	VfxHielo.proyectil_esquirla = true
	hv._pieza_proyectil("hielo", seg2, Vector3.RIGHT, 0.3, 4.0)
	_ok(seg2.find_children("esquirla_hielo", "MeshInstance3D", true, false).is_empty() and seg2.get_child_count() > 0, "con los modelos apagados vuelve la bola del kit aunque proyectil_esquirla sea true")
	VfxHielo.usar_modelos = true
	VfxHielo.proyectil_esquirla = true
	hv.free()


## --- 7. Impacto de tierra legible: terrones + cascotes más grandes + polvo corto y translúcido; GLB con su textura y color tierra ---
func _tierra_legible() -> void:
	print("--- 7. impacto de tierra legible")
	VfxTierra.usar_modelos = true
	var k: float = clampf(1.2, VfxTierra.CASCOTE_ESCALA_MIN, VfxTierra.CASCOTE_ESCALA_MAX)
	var cas: Array = VfxTierra.impacto(_mundo, Vector3(110, 1, 0), 1.2, 0.0, 5)
	var ter: Array = VfxTierra.ultimos_terrones.duplicate()
	_okc("el impacto devuelve los cascotes (5) y lanza además entre %d y %d terrones" % [VfxTierra.TERRONES_MIN, VfxTierra.TERRONES_MAX], cas.size() == 5 and ter.size() >= VfxTierra.TERRONES_MIN and ter.size() <= VfxTierra.TERRONES_MAX, "%d terrones" % ter.size())
	var terr_ok: bool = not ter.is_empty()
	for t in ter:
		var mi: MeshInstance3D = (t as Node3D).get_child(0) as MeshInstance3D
		terr_ok = terr_ok and mi.name.begins_with("terron_") and bool(mi.get_meta("modelo"))
	_okc("los terrones son los GLB terron_* de Meshy", terr_ok)
	var lados_ok: bool = true
	var lmin: float = INF
	var lmax: float = 0.0
	for c in cas:
		var mi: MeshInstance3D = (c as Node3D).get_child(0) as MeshInstance3D
		var a: AABB = mi.mesh.get_aabb()
		var lado: float = maxf(a.size.x, maxf(a.size.y, a.size.z)) * mi.scale.x
		lmin = minf(lmin, lado)
		lmax = maxf(lmax, lado)
		lados_ok = lados_ok and lado >= VfxTierra.CASCOTE_LADO_MIN * k - 0.01 and lado <= VfxTierra.CASCOTE_LADO_MAX * k + 0.01
	_okc("los cascotes miden %.2f–%.2f u (legibles: %.2f–%.2f × escala %.2f; antes 0,10–0,20)" % [lmin, lmax, VfxTierra.CASCOTE_LADO_MIN, VfxTierra.CASCOTE_LADO_MAX, k], lados_ok and VfxTierra.CASCOTE_LADO_MIN >= 0.2 and VfxTierra.CASCOTE_LADO_MAX <= 0.35)
	var lt_ok: bool = true
	for t in ter:
		var mi: MeshInstance3D = (t as Node3D).get_child(0) as MeshInstance3D
		var a: AABB = mi.mesh.get_aabb()
		var lado: float = maxf(a.size.x, maxf(a.size.y, a.size.z)) * mi.scale.x
		lt_ok = lt_ok and lado >= 0.25 * VfxTierra.TERRON_IMPACTO_ESCALA * k - 0.01 and lado <= 0.45 * VfxTierra.TERRON_IMPACTO_ESCALA * k + 0.01
	_okc("los terrones miden entre 0,25 y 0,45 u × %.1f × escala" % VfxTierra.TERRON_IMPACTO_ESCALA, lt_ok)
	# polvo: propio, corto y translúcido (no VfxPuzle3D.polvo)
	var polvos: Array = _mundo.find_children("*", "GPUParticles3D", true, false).filter(func(g: Node) -> bool: return (g as GPUParticles3D).amount == VfxTierra.POLVO_N)
	var pol_ok: bool = not polvos.is_empty()
	for g in polvos:
		pol_ok = pol_ok and absf((g as GPUParticles3D).lifetime - VfxTierra.POLVO_VIDA) < 0.001
	_okc("el polvo es el de la tierra: %d partículas, vida %.2f s (antes 16 y 1,1 s)" % [VfxTierra.POLVO_N, VfxTierra.POLVO_VIDA], pol_ok and VfxTierra.POLVO_N < 16 and VfxTierra.POLVO_VIDA < 1.1)
	_okc("y es translúcido y pardo (alfa %.2f, antes 0,70; rojo > azul)" % VfxTierra.POLVO_COLOR.a, VfxTierra.POLVO_COLOR.a <= 0.45 and VfxTierra.POLVO_COLOR.r > VfxTierra.POLVO_COLOR.b + 0.15)
	# GLB: textura de albedo y color tierra (media de la textura marrón, no gris lila)
	var ids_ok: bool = true
	var tierra_ok: bool = true
	var info: String = ""
	for id in ["terron_0", "terron_3", "cascote_0", "cascote_2"]:
		var m: Mesh = VfxTierra.pieza(id).mesh
		var mat: Material = m.surface_get_material(0)
		var tex: Texture2D = (mat as StandardMaterial3D).albedo_texture if mat is StandardMaterial3D else null
		ids_ok = ids_ok and tex != null and (mat as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
		if tex != null:
			var img: Image = tex.get_image()
			if img.is_compressed():
				img.decompress()
			var r: float = 0.0
			var g: float = 0.0
			var b: float = 0.0
			var cnt: int = 0
			for y in range(0, img.get_height(), 16):
				for x in range(0, img.get_width(), 16):
					var col: Color = img.get_pixel(x, y)
					r += col.r
					g += col.g
					b += col.b
					cnt += 1
			tierra_ok = tierra_ok and r > g and g > b and r - b > 0.2 * (r / cnt) * cnt
			info = "media (%.2f, %.2f, %.2f)" % [r / cnt, g / cnt, b / cnt]
	_okc("los GLB de tierra llevan su textura de albedo y sombreado normal (iluminados, no lisos)", ids_ok)
	_okc("y la textura es de tierra (rojo > verde > azul, no gris lila): " + info, tierra_ok)
	await _esperar(0.3)


## --- 8. Rayo de hielo: haz de cristal con la textura de la esquirla ---
func _rayo_hielo() -> void:
	print("--- 8. rayo de hielo (VfxHielo.rayo)")
	VfxHielo.usar_modelos = true
	var padre := Node3D.new()
	_mundo.add_child(padre)
	var desde := Vector3(0, 1, 0)
	var hasta := Vector3(3, 0.2, 4)
	var dir: Vector3 = (hasta - desde).normalized()
	var raiz: Node3D = VfxHielo.rayo(padre, desde, hasta, 1.0, 1.0, 0.0)
	_okc("el rayo devuelve su raíz, en la mano y con +Z hacia el punto (producto escalar %.3f)" % raiz.global_transform.basis.z.dot(dir), raiz != null and raiz.position.is_equal_approx(desde) and raiz.global_transform.basis.z.dot(dir) > 0.99)
	var cil: Array = raiz.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return (n as MeshInstance3D).mesh is CylinderMesh)
	_okc("el haz son 2 cilindros (cristal y núcleo)", cil.size() == 2)
	var largo: float = desde.distance_to(hasta)
	var tex: Texture2D = VfxHielo.textura_esquirla()
	var mat_ok: bool = cil.size() == 2 and tex != null
	var largo_ok: bool = cil.size() == 2
	for c in cil:
		var m: Material = (c as MeshInstance3D).material_override
		mat_ok = mat_ok and m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("tex") == tex and (m as ShaderMaterial).shader.code.contains("ALPHA") and (m as ShaderMaterial).shader.code.contains("TIME")
		largo_ok = largo_ok and absf(((c as MeshInstance3D).mesh as CylinderMesh).height - largo) < 0.01
	_okc("lleva el shader translúcido de hielo con la TEXTURA DE LA ESQUIRLA, que corre (TIME)", mat_ok)
	_okc("y mide lo que la distancia mano–punto (%.2f u)" % largo, largo_ok)
	var esq: Array = raiz.find_children("esquirla_hielo_rayo", "MeshInstance3D", true, false)
	_okc("esquirlas pequeñas a lo largo del haz (%d, entre %d y %d)" % [esq.size(), VfxHielo.RAYO_ESQUIRLAS_MIN, VfxHielo.RAYO_ESQUIRLAS_MAX], esq.size() >= VfxHielo.RAYO_ESQUIRLAS_MIN and esq.size() <= VfxHielo.RAYO_ESQUIRLAS_MAX)
	var chicas: bool = not esq.is_empty()
	for e in esq:
		chicas = chicas and bool((e as MeshInstance3D).get_meta("modelo")) and (e as MeshInstance3D).scale.x <= VfxHielo.RAYO_ESQUIRLA_ESC_MAX + 0.001
	_okc("y son el modelo de la esquirla a escala pequeña", chicas)
	await _esperar(0.7)
	_okc("donde da brotan %d racimos pequeños y %d pinchos de escarcha" % [VfxHielo.RAYO_IMPACTO_PEQUENOS, VfxHielo.RAYO_IMPACTO_PINCHOS],
		padre.find_children("racimo_hielo_p_*", "MeshInstance3D", true, false).size() == VfxHielo.RAYO_IMPACTO_PEQUENOS and padre.find_children("pincho_escarcha_*", "MeshInstance3D", true, false).size() == VfxHielo.RAYO_IMPACTO_PINCHOS)
	var fade_ok: bool = cil.size() == 2
	for c in cil:
		fade_ok = fade_ok and float(((c as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("fade")) > 0.95
	_okc("a los 0,7 s el haz ya está entero (fade ≈ 1)", fade_ok)
	await _esperar(1.8)
	_okc("tras su duración el haz y el impacto se liberan solos", not is_instance_valid(raiz) and padre.find_children("racimo_hielo_p_*", "MeshInstance3D", true, false).is_empty() and padre.find_children("pincho_escarcha_*", "MeshInstance3D", true, false).is_empty())
	VfxHielo.usar_modelos = false
	_okc("con los modelos apagados el rayo tiene textura null y no revienta", VfxHielo.textura_esquirla() == null)
	VfxHielo.usar_modelos = true
	padre.queue_free()

class MundoFalso extends Node3D:
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_canal(c: Vector2i) -> bool:
		return _letra(c) == "-"
	func _liberar(c: Vector2i) -> void:
		_bloqueadas.erase(c)


## El hielo del agua se rompe (fuego, o se acaba su tiempo) → Lanzador3D lo avisa por Mundo3D.impacto → VfxElemento3D dibuja la placa rota en la casilla.
func _placa_al_romper_hielo() -> void:
	print("--- 6. placa rota al romperse el hielo del agua")
	var m := MundoFalso.new()
	m._mapa = ["######", "#....#", "~~~~~~", "~~~~~~", "#....#", "######"]
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if m._mapa[y][x] == "#" or m._mapa[y][x] == "~":
				m._bloqueadas[Vector2i(x, y)] = true
	var w := Mundo3D.new()
	root.add_child(w)
	var vfx: VfxElemento3D = VfxElemento3D.conectar(null, m)
	vfx.casilla = Terreno3D.casilla
	var sim: AguaSim3D = Terreno3D.montar_agua_sim()
	var c := Vector2i(2, 2)
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.alto_agua)
	for _i in range(60):
		sim.paso(1.0 / 60.0)
		Lanzador3D.procesar_cambios_hielo()
	var impactos: Array = []
	w.impacto.connect(func(pt: Vector3, el: String, r: float) -> void: impactos.append([pt, el, r]))
	Lanzador3D.hechizo_sobre_agua("hielo", p)
	_okc("al helar la casilla NO sale placa rota", sim.casilla_helada(c) and vfx.placas() == 0 and m.find_children("PlacaRota", "Node3D", true, false).is_empty())
	Lanzador3D.hechizo_sobre_agua("fuego", p)
	_okc("al fundirse el hielo la casilla deja de estar helada", not sim.casilla_helada(c))
	var rotos: Array = impactos.filter(func(i: Array) -> bool: return i[1] == "hielo_roto")
	_okc("Mundo3D.impacto avisa «hielo_roto» una vez", rotos.size() == 1, "%d avisos" % rotos.size())
	if rotos.size() == 1:
		var q: Vector3 = rotos[0][0]
		var ctr: Vector3 = Terreno3D.centro_de(c)
		_okc("el aviso es en el centro de la casilla (%.2f, %.2f) a la altura del agua (y %.2f)" % [q.x, q.z, q.y], absf(q.x - ctr.x) < 0.01 and absf(q.z - ctr.z) < 0.01 and absf(q.y - Terreno3D.superficie_agua(c)) < 0.01)
		_okc("y lleva el tamaño de casilla (%.2f)" % float(rotos[0][2]), absf(float(rotos[0][2]) - Terreno3D.casilla) < 0.01)
	var placas: Array = m.find_children("PlacaRota", "Node3D", true, false)
	_okc("VfxElemento3D dibuja la placa rota (VfxHielo.placa_rota) con %d trozos" % VfxHielo.N_TROZOS, vfx.placas() == 1 and placas.size() == 1 and placas[0].get_child_count() == VfxHielo.N_TROZOS)
	if placas.size() == 1:
		var pl: Node3D = placas[0]
		_okc("la placa está en la casilla, a la altura del agua, a escala de casilla (×%.3f)" % pl.scale.x, absf(pl.position.x - Terreno3D.centro_de(c).x) < 0.01 and absf(pl.position.y - Terreno3D.superficie_agua(c)) < 0.01 and absf(pl.scale.x - Terreno3D.casilla / 2.2) < 0.01)
	# la otra forma de romperse: se acaba su tiempo
	Lanzador3D.hechizo_sobre_agua("hielo", p)
	for _i in range(int(21.0 * 60.0)):
		sim.paso(1.0 / 60.0)
		Lanzador3D.procesar_cambios_hielo()
	_okc("si el hielo se suelta solo al acabarse su tiempo, también sale su placa (2 en total)", vfx.placas() == 2, "%d" % vfx.placas())
	# con los modelos apagados no se dibuja nada
	var antes: int = vfx.placas()
	VfxHielo.usar_modelos = false
	Terreno3D.mundo_s = m
	w.avisar_impacto(p, "hielo_roto", Terreno3D.casilla)
	VfxHielo.usar_modelos = true
	_okc("con VfxHielo.usar_modelos = false no hay placa", vfx.placas() == antes)
	await _esperar(2.6)
	_okc("las placas se liberan solas", m.find_children("PlacaRota", "Node3D", true, false).is_empty())
	for n in [m, w]:
		n.queue_free()

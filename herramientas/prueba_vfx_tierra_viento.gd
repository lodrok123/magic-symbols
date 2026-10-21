extends SceneTree

## PRUEBA (Pipeline, 21/10): VFX DE MATERIA SÓLIDA de TIERRA y de VIENTO (`VfxTierra`, `VfxViento`, docs/PLAN_EOW_VISUAL.md §4). Mide el árbol y el tiempo:
##   1. las piezas de tierra (`terron_0..5`, `cascote_0..3`, `bloque_tierra_0..2`, `pincho_tierra_0..1`) existen con la MEDIDA de PROMPTS_ELEMENTOS.md, el origen
##      que toca (centro o centro de la base), la tapa del bloque PLANA, las caras bien orientadas (normal hacia fuera y sentido horario) y formas distintas;
##   2. con un modelo de mentira (malla forzada, suelta o de lámina) se usa EL MODELO y se escala; con `usar_modelos = false` vuelven las primitivas;
##   3. el proyectil de tierra en vuelo lleva UN terrón (malla facetada, no partícula) del tamaño de la caja de golpe (2·r_u) y rueda;
##   4. el impacto de tierra deja 3–5 cascotes que caen al suelo (y ≥ suelo − margen), se quedan ~1,5 s y desaparecen; el proyectil, al chocar, los suelta;
##   5. un volumen de tierra (barrera, pulso, esfera) crea bloques que SUBEN desde bajo el suelo y se hunden al acabar; el bloque pisable del Lanzador se viste igual;
##   6. el proyectil de viento lleva cintas que giran, semitransparentes, y hojas (tarjetas del atlas); el impacto abre un remolino que se va; el torbellino se va;
##   7. el atlas de hojas tiene su ruta preparada y, si no existe el PNG, hay placeholder;
##   8. al final no queda ningún nodo de estos efectos vivo.
##   godot --headless --path . --script res://herramientas/prueba_vfx_tierra_viento.gd

class FalsoLanzador:
	extends Node
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)
	signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)
	var fx: Vfx3D = null

var _fallos: int = 0
var _mundo: Node3D = null
var _l: FalsoLanzador = null
var _vfx: VfxElemento3D = null


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("  OK   ", texto)
	else:
		print("  MAL  ", texto)
		_fallos += 1


func _correr() -> void:
	_mundo = Node3D.new()
	root.add_child(_mundo)
	_l = FalsoLanzador.new()
	_mundo.add_child(_l)
	_l.fx = Vfx3D.new()
	_mundo.add_child(_l.fx)
	var estado: VfxEstado3D = VfxEstado3D.conectar(_l, _mundo)
	estado.encendido = false
	_vfx = VfxElemento3D.conectar(_l, _mundo)
	await process_frame
	_piezas()
	_modelos()
	await _vuelo_tierra()
	await _impacto_tierra()
	await _formas_quietas()
	await _viento()
	_atlas()
	await create_timer(1.5, false).timeout
	print("--- 8. no queda nada")
	var restos: int = _restos()
	_ok(restos == 0, "ningún nodo de cascotes, remolinos, bloques o torbellinos sigue vivo (%d)" % restos)
	_ok(_vfx.vivos() == 0, "VfxElemento3D no tiene dibujos vivos (%d)" % _vfx.vivos())
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------
func _piezas() -> void:
	print("--- 1. las piezas de tierra: medida, origen, tapa plana, caras")
	var vistas: Dictionary = {}
	for id in VfxTierra.ids():
		var mi: MeshInstance3D = VfxTierra.pieza(id)
		var med: Vector3 = VfxTierra.MEDIDA[id]
		var caja: AABB = mi.mesh.get_aabb()
		var cerca: bool = (caja.size - med).length() < 0.02 * med.length() + 0.002
		_ok(mi.mesh is ArrayMesh and not bool(mi.get_meta("modelo")) and cerca, "%s: primitiva facetada de %.2f×%.2f×%.2f u (mide %.2f×%.2f×%.2f)" % [id, med.x, med.y, med.z, caja.size.x, caja.size.y, caja.size.z])
		var centro_xz: bool = absf(caja.position.x + caja.size.x * 0.5) < 0.01 and absf(caja.position.z + caja.size.z * 0.5) < 0.01
		if id.begins_with("bloque_") or id.begins_with("pincho_"):
			_ok(centro_xz and absf(caja.position.y) < 0.005, "%s: origen en el centro de la base" % id)
		else:
			_ok(centro_xz and absf(caja.position.y + caja.size.y * 0.5) < 0.01, "%s: origen en su centro" % id)
		_ok(_caras_bien(mi.mesh as ArrayMesh, caja), "%s: normales hacia fuera y caras en sentido horario" % id)
		if id.begins_with("bloque_"):
			_ok(_tapa_plana(mi.mesh as ArrayMesh, med.y) >= 8, "%s: la tapa es PLANA (se pisa)" % id)
		vistas[id] = _firma(mi.mesh as ArrayMesh)
		mi.free()
	var distintas: bool = true
	for pre in ["terron_", "cascote_", "bloque_tierra_", "pincho_tierra_"]:
		var firmas: Dictionary = {}
		for id in vistas:
			if String(id).begins_with(pre):
				firmas[vistas[id]] = true
		var n: int = 0
		for id in vistas:
			if String(id).begins_with(pre):
				n += 1
		distintas = distintas and firmas.size() == n
	_ok(distintas, "cada variante (terron_0..5, cascote_0..3, bloque_tierra_0..2, pincho_tierra_0..1) es una forma distinta")


func _caras_bien(m: ArrayMesh, caja: AABB) -> bool:
	var arr: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var centro: Vector3 = caja.position + caja.size * 0.5
	var bien: int = 0
	var total: int = int(v.size() / 3)
	for t in range(total):
		var a: Vector3 = v[t * 3]
		var b: Vector3 = v[t * 3 + 1]
		var c: Vector3 = v[t * 3 + 2]
		var n: Vector3 = nn[t * 3]
		var fuera: bool = n.dot((a + b + c) / 3.0 - centro) > 0.0
		var horario: bool = (b - a).cross(c - a).dot(n) < 0.0        # Godot: delantera = sentido horario visto de fuera
		if fuera and horario:
			bien += 1
	return total > 0 and bien == total


## Cuántos vértices están en la altura de la tapa (todos los de arriba, a la misma y).
func _tapa_plana(m: ArrayMesh, alto: float) -> int:
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var n: int = 0
	for p in v:
		if absf(p.y - alto) < 0.0005:
			n += 1
	return n


func _firma(m: ArrayMesh) -> String:
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return "%d:%s:%s" % [v.size(), str(snappedf(v[0].x, 0.001)), str(snappedf(v[v.size() / 2].y, 0.001))]


# ---------------------------------------------------------------------------------------------------------------------
func _modelos() -> void:
	print("--- 2. con modelo se usa el modelo (GLB suelto o lámina de mentira); sin él, la primitiva")
	var caja := BoxMesh.new()
	caja.size = Vector3(2.0, 4.0, 2.0)          # un «GLB» de otra escala y de otro origen: se debe escalar a 0,38 de lado mayor y centrar
	VfxTierra._modelos["terron_0"] = caja
	VfxTierra._modelos.erase("terron_3")
	_ok(VfxTierra.hay_modelo("terron_0") and not VfxTierra.hay_modelo("terron_3"), "hay_modelo: terron_0 sí (forzado), terron_3 no")
	var m0: MeshInstance3D = VfxTierra.pieza("terron_0")
	var med: Vector3 = VfxTierra.MEDIDA["terron_0"]
	var lado: float = m0.mesh.get_aabb().size.y * m0.scale.y
	_ok(m0.mesh == caja and bool(m0.get_meta("modelo")), "pieza(terron_0) usa el modelo (la malla forzada)")
	_ok(absf(lado - maxf(med.x, maxf(med.y, med.z))) < 0.001, "el GLB suelto se escala a la medida (%.3f u, pide %.3f)" % [lado, maxf(med.x, maxf(med.y, med.z))])
	m0.free()
	var m3: MeshInstance3D = VfxTierra.pieza("terron_3")
	_ok(m3.mesh != caja and not bool(m3.get_meta("modelo")), "sin modelo, la primitiva")
	m3.free()
	# lámina: un nodo con el id, ya a escala: se usa tal cual (sin escalar)
	var hoja := BoxMesh.new()
	hoja.size = Vector3(0.1, 0.1, 0.1)
	VfxTierra._hoja["cascote_1"] = hoja
	VfxTierra._modelos.erase("cascote_1")
	var c1: MeshInstance3D = VfxTierra.pieza("cascote_1")
	_ok(c1.mesh == hoja and c1.scale.is_equal_approx(Vector3.ONE) and bool(c1.get_meta("modelo")), "de lámina: se usa tal cual (ya viene a escala)")
	c1.free()
	VfxTierra.usar_modelos = false
	var sin: MeshInstance3D = VfxTierra.pieza("terron_0")
	_ok(sin.mesh != caja and not bool(sin.get_meta("modelo")) and not VfxTierra.hay_modelo("terron_0"), "usar_modelos = false fuerza las primitivas")
	sin.free()
	VfxTierra.usar_modelos = true
	# el proyectil de tierra, con el modelo forzado en todos los terrones, lo dibuja
	for i in range(VfxTierra.N_TERRONES):
		VfxTierra._modelos["terron_%d" % i] = caja
	var seg := Node3D.new()
	_mundo.add_child(seg)
	var t: MeshInstance3D = VfxTierra.proyectil(seg, Vector3.RIGHT, 0.3)
	_ok(t.mesh == caja, "el proyectil de tierra usa el modelo cuando lo hay")
	seg.free()
	for i in range(VfxTierra.N_TERRONES):
		VfxTierra._modelos.erase("terron_%d" % i)
	VfxTierra._modelos.erase("terron_0")
	VfxTierra._hoja.erase("cascote_1")
	VfxTierra._modelos.erase("cascote_1")


# ---------------------------------------------------------------------------------------------------------------------
func _proyectil(elemento: String, estado: String, semieje: float, pos: Vector3) -> HechizoVivo:
	var hv := HechizoVivo.new()
	_vfx.encendido = false        # la prueba llama a `_dibujar_proyectil` ella misma: sin esto lo dibujaría también el diferido de `_en_nodo` (dos dibujos)
	hv.set_physics_process(false)
	hv.h = Hechizo.new()
	hv.h.velocidad = 1.7
	hv.h.semieje_x = semieje
	hv.h.semieje_z = semieje
	hv.estado = estado
	hv.elemento = elemento
	hv.activo = true
	hv.proyectil = true
	hv.v = Vector3(1.7 * 2.3, 0.0, 0.0)
	_l.add_child(hv)
	hv.set_physics_process(false)
	hv.global_position = pos
	_vfx.encendido = true
	return hv


func _vuelo_tierra() -> void:
	print("--- 3. tierra en vuelo: un terrón facetado del tamaño del proyectil")
	var hv: HechizoVivo = _proyectil("tierra", "solido", 0.4, Vector3(100, 1, 0))
	_vfx._dibujar_proyectil(weakref(hv))
	var seg: VfxElemento3D.Proyectil = hv.get_node_or_null("VfxElementoProyectil") as VfxElemento3D.Proyectil
	_ok(seg != null, "el proyectil de tierra tiene su dibujo")
	if seg == null:
		return
	seg._process(VfxElemento3D.PROYECTIL_CRECE_S + 0.1)        # ya creció del todo
	var terrones: Array = seg.find_children("terron_*", "MeshInstance3D", true, false)
	_ok(terrones.size() == 1, "lleva UN terrón (malla), no cajas orbitando (%d)" % terrones.size())
	if terrones.size() == 1:
		var mi: MeshInstance3D = terrones[0] as MeshInstance3D
		var r_u: float = hv.h.semiejes_vuelo.x * Terreno3D.casilla
		var caja: AABB = mi.mesh.get_aabb()
		var lado: float = maxf(caja.size.x, maxf(caja.size.y, caja.size.z)) * mi.scale.x
		_ok(mi.mesh is ArrayMesh and not (mi.mesh is SphereMesh), "el terrón es una malla facetada (ArrayMesh)")
		_ok(absf(lado - 2.0 * r_u) < 0.02 * r_u * 2.0 + 0.003, "mide %.3f u = el diámetro de la caja de golpe (2·r_u = %.3f)" % [lado, 2.0 * r_u])
		var rueda: Node3D = seg.get_node_or_null("TerronRueda") as Node3D
		var antes: Basis = rueda.basis
		rueda._process(0.2)
		_ok(not rueda.basis.is_equal_approx(antes), "el terrón rueda")
	var polvo: int = 0
	for n in seg.find_children("*", "GPUParticles3D", true, false):
		polvo += 1
	_ok(polvo >= 1, "deja polvo atrás (%d emisores)" % polvo)
	hv.queue_free()
	await process_frame
	await process_frame


func _cascotes() -> Array:
	var r: Array = []
	for c in _mundo.get_children():
		if c is VfxTierra.Cascote:
			r.append(c)
	return r


func _impacto_tierra() -> void:
	print("--- 4. impacto de tierra: cascotes que caen al suelo, se quedan y desaparecen")
	var suelo: float = 0.5
	var lista: Array = VfxTierra.impacto(_mundo, Vector3(200, 1.7, 0), 1.2, suelo)
	_ok(lista.size() >= VfxTierra.CASCOTES_MIN and lista.size() <= VfxTierra.CASCOTES_MAX, "salen %d cascotes (3–5)" % lista.size())
	var t0: int = Time.get_ticks_msec()
	await create_timer(1.3, false).timeout
	var en_suelo: int = 0
	var bien_y: bool = true
	for c in lista:
		if is_instance_valid(c):
			var y: float = (c as Node3D).position.y
			bien_y = bien_y and y > suelo - 0.05 and y < suelo + 0.5
			if (c as VfxTierra.Cascote).fase == 1:
				en_suelo += 1
	_ok(bien_y, "a 1,3 s todos están a ras del suelo (y entre suelo − 0,05 y suelo + 0,5)")
	_ok(en_suelo == lista.size(), "y están QUIETOS en el suelo, no en el aire (%d de %d)" % [en_suelo, lista.size()])
	await create_timer(0.7, false).timeout          # a ~2,0 s: se han quedado ~1 s en el suelo, siguen ahí
	var siguen: int = 0
	for c in lista:
		if is_instance_valid(c):
			siguen += 1
	_ok(siguen == lista.size(), "a ~2,0 s siguen en el suelo (T_REPOSO = %.1f s)" % VfxTierra.T_REPOSO)
	await create_timer(1.7, false).timeout          # a ~3,7 s: hundidos y liberados
	var vivos: int = 0
	for c in lista:
		if is_instance_valid(c):
			vivos += 1
	_ok(vivos == 0, "a ~3,7 s han desaparecido (quedan %d; tardó %.1f s)" % [vivos, float(Time.get_ticks_msec() - t0) / 1000.0])
	_ok(_cascotes().is_empty(), "y no hay ningún cascote colgando del mundo")
	# sin dato de suelo: cae SUELO_FALTA por debajo del punto (no se queda flotando)
	var l2: Array = VfxTierra.impacto(_mundo, Vector3(210, 3.0, 0), 1.0)
	await create_timer(1.2, false).timeout
	var ok2: bool = not l2.is_empty()
	for c in l2:
		if is_instance_valid(c):
			ok2 = ok2 and absf((c as Node3D).position.y - (3.0 - VfxTierra.SUELO_FALTA)) < 0.4
	_ok(ok2, "sin dato de suelo caen %.1f u bajo el punto (no flotan)" % VfxTierra.SUELO_FALTA)
	await create_timer(3.0, false).timeout
	# el proyectil, al chocar, suelta el impacto y se oculta; si solo se agota, se queda
	var hv: HechizoVivo = _proyectil("tierra", "solido", 0.25, Vector3(220, 1.5, 0))
	_vfx._dibujar_proyectil(weakref(hv))
	var seg: VfxElemento3D.Proyectil = hv.get_node("VfxElementoProyectil") as VfxElemento3D.Proyectil
	seg._process(0.7)
	var n0: int = _cascotes().size()
	hv.motivo_fin = "golpe"
	hv.activo = false
	seg._process(0.01)
	_ok(_cascotes().size() >= VfxTierra.CASCOTES_MIN and n0 == 0 and not seg.visible, "al chocar (golpe) el proyectil suelta %d cascotes y se oculta" % _cascotes().size())
	hv.queue_free()
	await create_timer(3.5, false).timeout
	_ok(_cascotes().is_empty(), "y desaparecen en su tiempo")
	var hv2: HechizoVivo = _proyectil("tierra", "solido", 0.25, Vector3(230, 1.5, 0))
	_vfx._dibujar_proyectil(weakref(hv2))
	var seg2: VfxElemento3D.Proyectil = hv2.get_node("VfxElementoProyectil") as VfxElemento3D.Proyectil
	seg2._process(0.7)
	hv2.motivo_fin = "alcance"
	hv2.activo = false
	seg2._process(0.01)
	_ok(_cascotes().is_empty() and seg2.visible, "si solo se agota el alcance, no hay impacto y el terrón se queda (como antes)")
	hv2.queue_free()
	await process_frame


func _bloques_de(raiz: Node) -> Array:
	return raiz.find_children("bloque_tierra_*", "MeshInstance3D", true, false)


func _formas_quietas() -> void:
	print("--- 5. formas quietas: bloques que emergen del suelo")
	var suelo: float = 0.0
	for forma in ["barrera", "pulso", "esfera"]:
		var props: Dictionary = {"solidez": 1.0} if forma == "barrera" else ({"crece": 0.5} if forma == "pulso" else {})
		var pos := Vector3(300.0 + float(["barrera", "pulso", "esfera"].find(forma)) * 30.0, suelo, 0.0)
		var hv: HechizoVivo = _hechizo_quieto(pos)
		var g: Dictionary = {"x": 0.35, "y": 0.45, "z": 0.35, "celdas": [Vector2i(0, 0)], "niveles": 1, "persiste": 2.0, "suelo": suelo, "t_caida": 0.4,
			"eventos": [{"t": 0.0, "pos": Vector2(pos.x, pos.z), "dir": Vector2(1.0, 0.0)}], "viaja": false, "vida_total": 2.0}
		_l.hechizo_v2.emit("solido", "tierra", g, pos, Vector3.RIGHT, props)
		await process_frame
		var raiz: Node = hv.get_node_or_null("VfxElemento")
		var bloques: Array = _bloques_de(raiz) if raiz != null else []
		var enterrados: int = 0
		for b in bloques:
			if (b as Node3D).position.y < suelo - 0.1:
				enterrados += 1
		_ok(bloques.size() >= (5 if forma != "esfera" else 1), "%s: %d bloques facetados" % [forma, bloques.size()])
		_ok(enterrados == bloques.size() and not bloques.is_empty(), "%s: al nacer TODOS están bajo el suelo (%d de %d)" % [forma, enterrados, bloques.size()])
		var ymax0: float = -INF
		for b in bloques:
			ymax0 = maxf(ymax0, (b as Node3D).position.y)
		await create_timer(1.0, false).timeout
		var subidos: int = 0
		for b in bloques:
			if is_instance_valid(b) and (b as Node3D).position.y > suelo - 0.05 and int((b as Node3D).get_meta("piso")) == 0:
				subidos += 1
		var n_p0: int = 0
		for b in bloques:
			if int((b as Node3D).get_meta("piso")) == 0:
				n_p0 += 1
		_ok(subidos == n_p0, "%s: a 1 s han subido hasta el suelo (%d de %d)" % [forma, subidos, n_p0])
		if forma == "esfera":
			_ok(not raiz.find_children("pincho_tierra_*", "MeshInstance3D", true, false).is_empty(), "esfera: con estacas alrededor")
		await create_timer(2.2, false).timeout       # vida 2 s + margen: se han hundido y liberado
		var quedan: int = 0
		for b in bloques:
			if is_instance_valid(b):
				quedan += 1
		_ok(quedan == 0, "%s: a la hora de acabar se han hundido y liberado (quedan %d)" % [forma, quedan])
		hv.queue_free()
		await process_frame
	# el bloque pisable del Lanzador: gancho `vestir_bloque`
	var bloque := Node3D.new()
	_mundo.add_child(bloque)
	bloque.position = Vector3(400, 0.5, 0)
	var trozos: Array = VfxTierra.vestir_bloque(bloque, Vector3(2.16, 1.035, 2.16), Vector3(400, 0.0, 0))
	var bajo: bool = trozos.size() == 4
	for t in trozos:
		bajo = bajo and (t as Node3D).position.y < -1.035 * 0.5 - 0.1
	_ok(bajo, "vestir_bloque: 4 trozos que empiezan metidos bajo la caja")
	await create_timer(0.8, false).timeout
	var arriba: bool = true
	for t in trozos:
		arriba = arriba and absf((t as Node3D).position.y - (-1.035 * 0.5)) < 0.01
	_ok(arriba, "vestir_bloque: a 0,8 s los 4 trozos están en su sitio (llenan la casilla)")
	bloque.queue_free()
	await create_timer(0.5, false).timeout


func _hechizo_quieto(pos: Vector3) -> HechizoVivo:
	var hv := HechizoVivo.new()
	hv.set_physics_process(false)
	hv.h = Hechizo.new()
	hv.h.velocidad = 0.0
	hv.estado = "solido"
	hv.elemento = "tierra"
	hv.activo = false
	_l.add_child(hv)
	hv.global_position = pos
	return hv


# ---------------------------------------------------------------------------------------------------------------------
func _restos_viento() -> int:
	var n: int = 0
	for c in _mundo.get_children():
		if String(c.name).begins_with("RemolinoViento"):
			n += 1
	return n


func _viento() -> void:
	print("--- 6. viento: cintas que giran, hojas, remolino que se va")
	var hv: HechizoVivo = _proyectil("viento", "gas", 0.4, Vector3(500, 1, 0))
	_vfx._dibujar_proyectil(weakref(hv))
	var seg: VfxElemento3D.Proyectil = hv.get_node("VfxElementoProyectil") as VfxElemento3D.Proyectil
	seg._process(VfxElemento3D.PROYECTIL_CRECE_S + 0.1)
	var cintas: Array = seg.find_children("cinta_*", "MeshInstance3D", true, false)
	var hojas: Array = seg.find_children("hoja_*", "MeshInstance3D", true, false)
	_ok(cintas.size() == VfxViento.CINTAS_VUELO, "el proyectil lleva %d cintas (pide %d)" % [cintas.size(), VfxViento.CINTAS_VUELO])
	_ok(hojas.size() == VfxViento.HOJAS_VUELO, "y %d hojas/briznas arrastradas (tarjetas 2D)" % hojas.size())
	var transl: bool = not cintas.is_empty()
	for c in cintas:
		var mat: StandardMaterial3D = (c as MeshInstance3D).material_override as StandardMaterial3D
		transl = transl and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a <= 0.5 and mat.albedo_color.a > 0.05
	_ok(transl, "las cintas son semitransparentes (alfa ≤ 0,5): no tapan al jugador ni son opacas")
	var tarjetas: bool = not hojas.is_empty()
	for h in hojas:
		tarjetas = tarjetas and (h as MeshInstance3D).mesh is QuadMesh and ((h as MeshInstance3D).material_override as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED
	_ok(tarjetas, "las hojas son tarjetas planas (QuadMesh, billboard)")
	var rueda: Node3D = seg.find_child("VientoRueda", true, false) as Node3D
	var antes: Basis = rueda.basis
	rueda._process(0.2)
	_ok(not rueda.basis.is_equal_approx(antes), "las cintas giran en espiral")
	var largo: float = 0.0
	for c in cintas:
		largo = maxf(largo, (c as MeshInstance3D).mesh.get_aabb().size.y)
	var r_u: float = hv.h.semiejes_vuelo.x * Terreno3D.casilla
	_ok(largo > r_u * 2.0, "la estela es larga (%.2f u frente a un radio de %.2f)" % [largo, r_u])
	# impacto: remolino
	hv.motivo_fin = "golpe"
	hv.activo = false
	seg._process(0.01)
	await process_frame
	_ok(_restos_viento() == 1 and not seg.visible, "al chocar: un remolino de cintas y el cuerpo se oculta")
	var rem: Node = _mundo.find_child("RemolinoViento*", false, false)
	if rem != null:
		_ok(rem.find_children("cinta_*", "MeshInstance3D", true, false).size() == VfxViento.CINTAS_REMOLINO, "el remolino tiene %d cintas" % VfxViento.CINTAS_REMOLINO)
		var ab: Node3D = rem.get_node("RemolinoAbre") as Node3D
		var e0: float = ab.scale.x
		await create_timer(VfxViento.T_REMOLINO * 0.6, false).timeout
		_ok(is_instance_valid(ab) and ab.scale.x > e0 * 1.4, "y se ABRE (escala %.2f → %.2f)" % [e0, ab.scale.x if is_instance_valid(ab) else -1.0])
	await create_timer(VfxViento.T_REMOLINO * 0.4 + 0.5, false).timeout
	_ok(_restos_viento() == 0, "a los %.1f s el remolino se ha ido (queda %d)" % [VfxViento.T_REMOLINO + 0.5, _restos_viento()])
	hv.queue_free()
	await process_frame
	# torbellino (forma quieta)
	var pie := Node3D.new()
	_mundo.add_child(pie)
	pie.position = Vector3(520, 0, 0)
	var eje: Node3D = VfxViento.torbellino(pie, Vector3.UP, 0.6, 1.5, 1.4)
	var cs: Array = eje.find_children("cinta_*", "MeshInstance3D", true, false)
	_ok(cs.size() == VfxViento.CINTAS_TORBELLINO, "el torbellino tiene %d cintas en espiral" % cs.size())
	await create_timer(0.7, false).timeout
	var a: float = ((cs[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a
	_ok(absf(a - VfxViento.CINTA_ALFA) < 0.01, "a media vida está en su alfa de reposo (%.2f; nunca opaco: tope %.2f)" % [a, VfxViento.CINTA_ALFA])
	await create_timer(1.0, false).timeout
	_ok(not is_instance_valid(eje), "y al acabar su vida se va solo")
	pie.queue_free()


func _atlas() -> void:
	print("--- 7. atlas de hojas")
	_ok(VfxViento.RUTA_ATLAS == "res://presentacion/vfx/viento_atlas.png", "la ruta del atlas está preparada (%s)" % VfxViento.RUTA_ATLAS)
	var t: Texture2D = VfxViento.atlas()
	_ok(t != null and t.get_width() >= 256, "hay atlas (%s, %d px)" % ["PNG" if ResourceLoader.exists(VfxViento.RUTA_ATLAS) else "placeholder por código", t.get_width()])
	var img: Image = t.get_image()
	var llenas: int = 0
	for f in range(VfxViento.CASILLAS):
		for c in range(VfxViento.CASILLAS):
			var lado: int = img.get_width() / VfxViento.CASILLAS
			var visto: bool = false
			for py in range(lado):
				for px in range(lado):
					if img.get_pixel(c * lado + px, f * lado + py).a > 0.1:
						visto = true
						break
				if visto:
					break
			if visto:
				llenas += 1
	_ok(llenas == VfxViento.CASILLAS * VfxViento.CASILLAS, "las 16 casillas traen dibujo (%d)" % llenas)


## Nodos de estos efectos que siguen vivos colgando del mundo (cascotes, remolinos).
func _restos() -> int:
	var n: int = 0
	for c in _mundo.find_children("*", "", true, false):
		if c is VfxTierra.Cascote or String(c.name).begins_with("RemolinoViento") or String(c.name).begins_with("bloque_tierra_") \
				or String(c.name).begins_with("pincho_tierra_") or String(c.name).begins_with("VientoEje"):
			if not c.is_queued_for_deletion():
				n += 1
	return n

extends SceneTree

## PRUEBA de los impactos traducidos de Effekseer (25/11/2026): impacto_capas_toy.gd + recetas_effekseer.gd + la comparativa del lab (lab_impactos_effekseer.gd).
##   godot --headless --path . --script res://herramientas/prueba_impactos_effekseer.gd
## Comprueba, para cada receta: que monta TODAS sus capas (cada una con algo que dibujar), que cada capa enseña algo en algún instante (escala, brillo u opacidad > 0), que las
## partículas no bajan de la superficie ni del suelo, que la duración es razonable y que el nodo se libera solo. Y que la comparativa del lab se pone, recorre los cinco pares y se quita
## dejando la cámara, la jugadora y el panel del lab como estaban. No mira si se ve bonito: eso es la captura (captura_impactos_effekseer.gd).

const Recetas = preload("res://presentacion/vfx/toy/recetas_effekseer.gd")
const ImpactoCapasToy = preload("res://presentacion/vfx/toy/impacto_capas_toy.gd")
const LabImpactosEffekseer = preload("res://laboratorios/lab_impactos_effekseer.gd")

var _fallos: int = 0
var _ok: int = 0


func _initialize() -> void:
	_correr()


func _comprobar(cond: bool, que: String) -> void:
	if cond:
		_ok += 1
	else:
		_fallos += 1
		print("FALLO: " + que)


func _correr() -> void:
	await process_frame
	var raiz: Node3D = Node3D.new()
	root.add_child(raiz)
	for r in Recetas.RECETAS:
		await _probar_receta(raiz, r)
	await _probar_lab()
	print("prueba_impactos_effekseer: %d bien, %d fallos" % [_ok, _fallos])
	quit(1 if _fallos > 0 else 0)


func _probar_receta(raiz: Node3D, r: Dictionary) -> void:
	var id: String = String(r["id"])
	var normal: Vector3 = Vector3.BACK if String(r["superficie"]) == "pared" else Vector3.UP
	var i: Node3D = ImpactoCapasToy.crear(r, String(r["elemento"]), normal, 0.4)
	i.set("suelo_y", 0.0)
	i.set_process(false)                                  # el tiempo lo lleva la prueba con avanzar_a
	raiz.add_child(i)
	i.global_position = Vector3(0, 1.1 if normal == Vector3.BACK else 0.0, 0)
	var capas: Array = i.get("_capas")
	_comprobar(capas.size() == (r["capas"] as Array).size(), "%s: monta %d capas de %d" % [id, capas.size(), (r["capas"] as Array).size()])
	var dur: float = float(i.call("duracion"))
	_comprobar(dur > 0.2 and dur < 3.5, "%s: duración %.2f s fuera de 0,2..3,5" % [id, dur])
	# cada capa tiene que enseñar algo en algún instante
	var visto: Array = []
	visto.resize(capas.size())
	visto.fill(false)
	var bajo_suelo: int = 0
	var t: float = 0.0
	while t <= dur:
		i.call("avanzar_a", t)
		for k in capas.size():
			if _capa_visible(capas[k], t):
				visto[k] = true
		for k in capas.size():
			var c: Dictionary = capas[k]
			var pz: String = String((c["def"] as Dictionary).get("pieza", ""))
			if pz in ["chispas", "gotas", "piedras"]:
				for p in c["parts"]:
					var e: Dictionary = i.call("_estado_part", p, t, i.call("_gravedad_local"))
					var pm: Vector3 = i.global_transform * ((i.get("_plano") as Node3D).basis * (e["pos"] as Vector3))
					if pm.y < -0.001:
						bajo_suelo += 1
		t += 1.0 / 60.0
	for k in capas.size():
		var d: Dictionary = (capas[k] as Dictionary)["def"]
		var es_luz_sin: bool = String(d.get("pieza", "")) == "luz" and ((capas[k] as Dictionary)["nodos"] as Array).is_empty()     # la tierra no lleva luz: la capa queda vacía a propósito
		_comprobar(visto[k] or es_luz_sin, "%s: la capa «%s» (%s) no se ve nunca" % [id, String(d.get("nombre", "")), String(d.get("pieza", ""))])
	_comprobar(bajo_suelo == 0, "%s: %d posiciones de partícula por debajo del suelo" % [id, bajo_suelo])
	# y se libera sola
	i.set_process(true)
	var espera: int = int((dur + 0.4) * 60.0) + 10
	for f in espera:
		await process_frame
		if not is_instance_valid(i):
			break
	_comprobar(not is_instance_valid(i), "%s: no se libera solo tras %.2f s" % [id, dur])
	print("receta %s: %d capas, %.2f s" % [id, capas.size(), dur])


func _capa_visible(c: Dictionary, t: float) -> bool:
	var d: Dictionary = c["def"]
	match String(d.get("pieza", "")):
		"sprite":
			for s in c["nodos"]:
				var mi: MeshInstance3D = s
				if mi.scale.x > 0.001 and float((mi.material_override as ShaderMaterial).get_shader_parameter("vida")) > 0.01:
					return true
		"halo":
			for h in c["nodos"]:
				var mh: MeshInstance3D = h
				if mh.scale.x > 0.001 and float((mh.material_override as ShaderMaterial).get_shader_parameter("brillo")) > 0.01:
					return true
		"chispas", "gotas", "piedras":
			var mm: MultiMesh = (c["mm"] as MultiMeshInstance3D).multimesh
			for k in mm.instance_count:
				if mm.get_instance_transform(k).basis.x.length() > 0.0001:
					return true
		"humo":
			return int(c["emitidas"]) > 0
		"grieta":
			var gm: ShaderMaterial = (c["nodos"][0] as MeshInstance3D).material_override as ShaderMaterial
			return float(gm.get_shader_parameter("apertura")) > 0.01 and float(gm.get_shader_parameter("vida")) > 0.01
		"onda":
			for o in c["nodos"]:
				if float(((o as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("vida")) > 0.0:
					return true
		"luz":
			for l in c["nodos"]:
				if (l as OmniLight3D).light_energy > 0.01:
					return true
	return false


func _probar_lab() -> void:
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	for f in 5:
		await process_frame
	var cam_lab: Camera3D = lab.get("_cam")
	var pj: Node3D = lab.get("_pj")
	var c: Node = LabImpactosEffekseer.tecla(lab, KEY_4, false)
	await process_frame
	_comprobar(c != null and lab.get_node_or_null(LabImpactosEffekseer.NOMBRE) != null, "lab: Ctrl+4 no pone la comparativa")
	_comprobar(pj == null or not pj.visible, "lab: la jugadora sigue a la vista con la comparativa")
	_comprobar(not bool(lab.get("_panel_visible")), "lab: el panel del lab tapa el rótulo de la comparativa")
	for k in Recetas.RECETAS.size():
		var par: Array = c.call("lanzar_par")
		await process_frame
		_comprobar(is_instance_valid(par[0]) and is_instance_valid(par[1]), "lab: par %d no lanza los dos impactos" % (k + 1))
		for f in 30:
			await process_frame
		LabImpactosEffekseer.tecla(lab, KEY_5, false)
		await process_frame
	_comprobar(int(c.get("par")) == 0, "lab: Ctrl+5 no da la vuelta a los %d pares" % Recetas.RECETAS.size())
	LabImpactosEffekseer.tecla(lab, KEY_6, false)
	LabImpactosEffekseer.tecla(lab, KEY_7, false)
	_comprobar(is_equal_approx(Engine.time_scale, 0.25), "lab: Ctrl+7 no pone la cámara lenta")
	LabImpactosEffekseer.tecla(lab, KEY_4, false)
	for f in 3:
		await process_frame
	_comprobar(lab.get_node_or_null(LabImpactosEffekseer.NOMBRE) == null, "lab: Ctrl+4 no quita la comparativa")
	_comprobar(is_equal_approx(Engine.time_scale, 1.0), "lab: al salir no vuelve la velocidad normal")
	_comprobar(pj == null or pj.visible, "lab: al salir no vuelve la jugadora")
	_comprobar(bool(lab.get("_panel_visible")), "lab: al salir no vuelve el panel")
	_comprobar(cam_lab == null or cam_lab.current, "lab: al salir no vuelve la cámara del lab")
	lab.queue_free()
	await process_frame

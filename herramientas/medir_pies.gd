extends SceneTree
## Huella (x, z) y alto de cada pieza sin sombra de contacto: de ahí sale el radio de SOMBRA_CONTACTO. Herramienta de medida.
func _caja(n: Node, t: Transform3D, acc: Array) -> void:
	var tt: Transform3D = t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = tt * (n as MeshInstance3D).mesh.get_aabb()
		acc.append(a)
	for h in n.get_children():
		_caja(h, tt, acc)
func _initialize() -> void:
	var ids := ["campamento_cazo","campamento_cofre","campamento_rocas","campamento_tienda","cristal_elemental","cristal_sanctuario","estandarte_goblin","pilar","raiz_mundo","roca_musgosa","rocas_pequenas","tienda_goblin","torre_goblin","tinaja_ruina","tronco_musgoso","tronco_resina","tronco_sin_resina","troncos_apilados","canas","helecho","hierba_alta","hojas_caidas","paja","flores_blancas","seta_quemada"]
	for id in ids:
		var v: Node3D = Pieza3D.crear_visual(id)
		if v == null:
			print("%-20s (sin modelo)" % id)
			continue
		var acc: Array = []
		_caja(v, Transform3D.IDENTITY, acc)
		var tot: AABB = acc[0] if acc.size() > 0 else AABB()
		for a in acc:
			tot = tot.merge(a)
		print("%-20s huella %.2f x %.2f  alto %.2f  (y0 %.2f)" % [id, tot.size.x, tot.size.z, tot.size.y, tot.position.y])
		v.free()
	quit()

extends SceneTree
## Quita de la malla de la Torre Verde (Meshy, una sola malla) la PUERTA PINTADA del arco del sur y guarda el resultado en
## arte/meshy/piezas/torre_verde_sumicio_sin_puerta.res. En su lugar va la puerta animada (monte_sumicio_visita.gd, puerta_torre_sumicio.glb).
##   godot --headless --path . --script res://herramientas/hornear_torre_sin_puerta.gd
## Se quitan los triángulos de MADERA OSCURA dentro del vano: |x − X_VANO| < MEDIO_ANCHO, y < ALTO, z entre Z_MIN y Z_MAX
## (en local de la torre: el modelo va escalado ×10,1 y subido 5,05). El dintel de madera clara del arco (y > 2,4) se queda.

const ORIGEN := "res://arte/meshy/piezas/torre_verde_sumicio.glb"
const DESTINO := "res://arte/meshy/piezas/torre_verde_sumicio_sin_puerta.res"
const X_VANO := -0.05
const MEDIO_ANCHO := 0.68
const ALTO := 2.38
const Z_MIN := 3.4
const Z_MAX := 3.85


func _initialize() -> void:
	var raiz: Node3D = (load(ORIGEN) as PackedScene).instantiate()
	var mi: MeshInstance3D = raiz.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh
	var mat: Material = mesh.surface_get_material(0)
	var img: Image = (mat as BaseMaterial3D).albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	var a: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var t := Transform3D(Basis.IDENTITY * 10.1, Vector3(0, 5.05, 0)) * mi.transform
	var nuevo := PackedInt32Array()
	var quitados := 0
	var losa := 0
	var caja := AABB()
	for k in range(0, idx.size(), 3):
		var c := (t * v[idx[k]] + t * v[idx[k + 1]] + t * v[idx[k + 2]]) / 3.0
		var en_vano := absf(c.x - X_VANO) < MEDIO_ANCHO and c.y < ALTO and c.z > Z_MIN and c.z < Z_MAX
		if en_vano:
			var u := (uv[idx[k]] + uv[idx[k + 1]] + uv[idx[k + 2]]) / 3.0
			var col := img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
			# Madera de la puerta: rojiza y oscura (#5f3711 y vecinos); la piedra gris del arco no entra.
			if col.r > col.b * 1.4 and col.v < 0.62:
				caja = AABB(c, Vector3.ZERO) if quitados == 0 else caja.expand(c)
				quitados += 1
				continue
		# 14/11 (Pablo: «quita la baldosa de abajo»): la losa clara del umbral, delante del arco. Las jambas (más oscuras y mirando a los lados) se quedan.
		if c.y < 0.35 and c.z > 3.85 and c.z < 5.3 and absf(c.x - X_VANO) < 1.3:
			var u2 := (uv[idx[k]] + uv[idx[k + 1]] + uv[idx[k + 2]]) / 3.0
			var col2 := img.get_pixel(clampi(int(u2.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u2.y * img.get_height()), 0, img.get_height() - 1))
			var nrm := ((t * v[idx[k + 1]] - t * v[idx[k]]).cross(t * v[idx[k + 2]] - t * v[idx[k]])).normalized()
			# Por delante de las jambas (z > 4,25) todo lo bajo es losa, también sus cantos; junto al arco, solo lo claro y horizontal.
			if c.z > 4.25 or (col2.v > 0.4 and absf(nrm.x) < 0.5):
				losa += 1
				continue
		nuevo.append(idx[k])
		nuevo.append(idx[k + 1])
		nuevo.append(idx[k + 2])
	a[Mesh.ARRAY_INDEX] = nuevo
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	am.surface_set_material(0, mat)
	var err := ResourceSaver.save(am, DESTINO)
	print("quitados %d (puerta) + %d (losa) de %d triangulos · hueco %s fin %s · guardar=%d" % [quitados, losa, idx.size() / 3, caja, caja.end, err])
	raiz.free()
	quit()

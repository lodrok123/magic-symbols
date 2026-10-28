extends SceneTree
## Medidas del bastón del chamán y de baston_marimanta (para comparar). Headless.
func _initialize() -> void:
	for nom in ["baston_chaman", "baston_marimanta"]:
		var n: Node3D = (load("res://arte/modelos/%s.glb" % nom) as PackedScene).instantiate()
		var verts := PackedVector3Array(); var cols := []; var tris := 0
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D.IDENTITY; var c: Node = mi
			while c != null and c != n:
				if c is Node3D: t = (c as Node3D).transform * t
				c = c.get_parent()
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var a: Array = mesh.surface_get_arrays(s)
				var idx = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
				for p in a[Mesh.ARRAY_VERTEX]: verts.append(t * p)
				var m: Material = mi.get_active_material(s)
				if m is BaseMaterial3D and m.albedo_texture != null:
					cols.append("%s %dx%d" % [m.albedo_texture.resource_path.get_file(), m.albedo_texture.get_width(), m.albedo_texture.get_height()])
					var img: Image = m.albedo_texture.get_image()
					if img.is_compressed(): img.decompress()
					# Colores de cristal: pixeles muy saturados; y media global
					var sat := 0; var tot := 0; var rs := 0.0; var gs := 0.0; var bs := 0.0
					for y in range(0, img.get_height(), 8):
						for x in range(0, img.get_width(), 8):
							var px: Color = img.get_pixel(x, y); tot += 1
							if px.s > 0.45 and px.v > 0.3:
								sat += 1; rs += px.r; gs += px.g; bs += px.b
					print("  textura: pixeles saturados %.1f%%  color medio de ellos (%.2f %.2f %.2f)" % [100.0 * sat / tot, rs / maxf(sat, 1), gs / maxf(sat, 1), bs / maxf(sat, 1)])
		var mn: Vector3 = verts[0]; var mx: Vector3 = verts[0]
		for p in verts: mn = mn.min(p); mx = mx.max(p)
		print("=== ", nom, " ===  mallas ", n.find_children("*", "MeshInstance3D", true, false).size(), "  vert ", verts.size(), "  tris ", tris, "  tex ", cols)
		print("  min ", mn, " max ", mx, " tamaño ", mx - mn)
		# anchura por franjas del eje largo (y): para ver el cristal (zona ancha) y el agarre
		var L := mx.y - mn.y
		for b in 10:
			var y0 := mn.y + L * b / 10.0; var y1 := y0 + L / 10.0
			var a := Vector3(1e9, 1e9, 1e9); var z := Vector3(-1e9, -1e9, -1e9)
			for p in verts:
				if p.y >= y0 and p.y <= y1: a = a.min(p); z = z.max(p)
			print("  y %.2f-%.2f  x[%.3f,%.3f] z[%.3f,%.3f]" % [y0, y1, a.x, z.x, a.z, z.z])
	quit(0)

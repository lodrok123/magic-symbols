extends RefCounted
## Propuestas visuales del lote 3. No se conectan a las fábricas del juego:
## primero comparar forma, tamaño y estado encendido antes de elegir.
const OPCIONES: Dictionary = {
	"setas_amarillas": ["setas_rojas", "lost_largemushrooms_a"],
	"caja": ["lost_box_a", "lost_box_e"],
	"barril": ["lost_barrel", "lost_barrel_a"]
}
const DIR: String = "res://output/sustituciones_assets_2026-11-24/"
static var _texturas_amarillas: Dictionary = {}

static func color_seta(c: Color) -> Color:
	# Solo los sombreros cálidos: el pie, las motas claras y el musgo se conservan.
	var peso: float = smoothstep(0.03,0.14,c.r-maxf(c.g,c.b)) * smoothstep(0.15,0.35,c.s)
	var dorado: Color = Color.from_hsv(0.115,clampf(c.s*0.82,0.0,1.0),c.v*0.98,c.a)
	return c.lerp(dorado,peso)

static func _amarillo(tex: Texture2D) -> Texture2D:
	if _texturas_amarillas.has(tex): return _texturas_amarillas[tex]
	var im: Image = tex.get_image()
	if im.is_compressed(): im.decompress()
	im.clear_mipmaps()
	im.convert(Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width(): im.set_pixel(x,y,color_seta(im.get_pixel(x,y)))
	im.generate_mipmaps()
	var nueva := ImageTexture.create_from_image(im)
	_texturas_amarillas[tex] = nueva
	return nueva

static func _quitar_cuerpos(n: Node) -> void:
	for h in n.get_children():
		if h is CollisionObject3D or h is CollisionShape3D: h.free()
		else: _quitar_cuerpos(h)

## variante 0 = asset actual; 1/2 = propuestas. Solo devuelve la parte visual.
static func crear(id: String, variante: int) -> Node3D:
	if variante == 0: return Pieza3D.crear_visual(id,false)
	var fuente: String = OPCIONES[id][variante-1]
	var n: Node3D
	if fuente.begins_with("lost_"):
		n = (load("res://arte/lostcave/piezas/"+fuente+".tscn") as PackedScene).instantiate()
		_quitar_cuerpos(n)
	else:
		n = (load("res://arte/meshy/piezas/"+fuente+".glb") as PackedScene).instantiate()
	n.rotation.y = deg_to_rad(Pieza3D.giro_de(id))
	n = Pieza3D._normalizar(n,id)
	for mi in n.find_children("*","MeshInstance3D",true,false):
		for s in mi.mesh.get_surface_count():
			var mat: StandardMaterial3D = mi.get_active_material(s) as StandardMaterial3D
			if mat == null: continue
			mat = mat.duplicate()
			if id == "setas_amarillas" and mat.albedo_texture != null:
				mat.albedo_texture = _amarillo(mat.albedo_texture)
			mi.set_surface_override_material(s,mat)
	return n

static func triangulos(n: Node3D) -> int:
	var total: int = 0
	for mi in n.find_children("*","MeshInstance3D",true,false):
		total += mi.mesh.get_faces().size()/3
	return total

## Ensayo sobre un Barril3D real: sustituye exclusivamente el cuerpo visual y
## conserva la colisión, la mecha, el radio de explosión y el código de parpadeo.
static func probar_barril(b: Barril3D, variante: int) -> bool:
	if variante == 0: return true
	var n: Node3D = crear("barril",variante)
	var caja: AABB = Pieza3D._caja(n,Transform3D.IDENTITY)
	n.scale *= b.alto / caja.size.y
	var material: StandardMaterial3D
	for mi in n.find_children("*","MeshInstance3D",true,false):
		for s in mi.mesh.get_surface_count():
			var actual: StandardMaterial3D = mi.get_active_material(s) as StandardMaterial3D
			if material == null: material = actual
			elif material != actual:
				n.free()
				return false       # el parpadeo del barril admite un solo material
	if material == null:
		n.free()
		return false
	material.albedo_color = Color.WHITE       # mismo reposo que Barril3D._poner_visual
	b._cuerpo.free()
	if b._aro != null: b._aro.free()
	b.add_child(n)
	b._cuerpo = n
	b._mat = material
	b._modelo_ok = true
	return true

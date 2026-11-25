extends RefCounted
## Derivados en la escala canónica del juego; nunca añaden cuerpos físicos.
const RAIZ = "res://arte/meshy/blender_interacciones/"
static func cargar(id: String) -> Node3D:
	var ruta: String = RAIZ+id+".glb"
	if id == "barril_articulado": ruta="res://arte/lostcave/blender_interacciones/barril_articulado.glb"
	if not ResourceLoader.exists(ruta): return null
	var n := (load(ruta) as PackedScene).instantiate() as Node3D
	n.set_meta("variante_blender",id)
	return n

static func restos(padre: Node3D, tf: Transform3D, es_tocon: bool, medida: Vector3 = Vector3.ZERO) -> Node3D:
	var raiz := Node3D.new()
	raiz.name="RestosQuemados"
	padre.add_child(raiz)
	raiz.global_transform=tf
	var ceniza := cargar("ceniza_restos")
	if ceniza != null:
		raiz.add_child(ceniza)
		ceniza.name="ceniza"
		var huella: Vector3=Pieza3D._caja(ceniza,Transform3D.IDENTITY).size
		ceniza.scale=Vector3.ONE*maxf(1.0,maxf(medida.x,medida.z)*1.5/maxf(maxf(huella.x,huella.z),0.01))
	if es_tocon:
		var tocon := cargar("tocon_quemado")
		if tocon != null:
			raiz.add_child(tocon)
			tocon.name="tocon_quemado"
			var caja: AABB = Pieza3D._caja(tocon,Transform3D.IDENTITY)
			if medida != Vector3.ZERO:
				tocon.scale *= minf(medida.x/maxf(caja.size.x,0.01),medida.z/maxf(caja.size.z,0.01))
	return raiz

static func fragmentos(padre: Node3D, tf: Transform3D, volar: bool) -> Node3D:
	var n := cargar("roca_fragmentos")
	if n == null: return null
	padre.add_child(n)
	n.name="RestosRoca"
	n.global_transform=tf
	var i := 0
	for p: MeshInstance3D in n.find_children("*","MeshInstance3D",true,false):
		var ini: Vector3=p.position
		var giro:=Vector3(float(i%3)*0.7,float(i)*2.399963,0.4)
		var base:=Transform3D(Basis.from_euler(giro).scaled(p.scale),Vector3.ZERO)
		var fin:=Vector3(sin(i*2.399963)*0.65,-(base*p.mesh.get_aabb()).position.y+0.008,cos(i*2.399963)*0.65)
		var rot_ini: Vector3=p.rotation
		if volar:
			var tw:=p.create_tween()
			tw.tween_method(func(k: float) -> void:
				p.position=ini.lerp(fin,k)+Vector3.UP*0.6*4*k*(1-k)
				p.rotation=rot_ini.lerp(giro,k),0.0,1.0,0.5)
		else:
			p.position=fin; p.rotation=giro
		i+=1
	return n

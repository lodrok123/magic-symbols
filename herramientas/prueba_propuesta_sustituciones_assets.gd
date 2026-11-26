extends SceneTree
const P = preload("res://herramientas/propuesta_sustituciones_assets.gd")
var fallos: int = 0
func comprobar(bien: bool, texto: String) -> void:
	print("OK " if bien else "FALLO ",texto)
	if not bien: fallos += 1

func _initialize() -> void:
	call_deferred("correr")

func correr() -> void:
	Pieza3D._cargar_bibliotecas()
	var fuente: String = "res://arte/meshy/aprobacion3d/s_fantasy_garden_props/setas_amarillas.glb"
	comprobar(FileAccess.get_sha256(fuente)==FileAccess.get_sha256("res://arte/meshy/piezas/setas_amarillas.glb"),"Setas actuales coinciden byte a byte con la fuente")
	comprobar(Pieza3D.id_real("setas_amarillas")=="setas_amarillas","No hay sustitución oculta de las setas")
	var claro := Color(0.9,0.88,0.85,0.5)
	comprobar(P.color_seta(claro).is_equal_approx(claro),"Pies y motas claras conservan el color")
	var rojo: Color = P.color_seta(Color(0.85,0.12,0.08,0.7))
	comprobar(rojo.g>0.4 and absf(rojo.a-0.7)<0.001,"Sombrero cálido pasa a dorado, conservando alfa")
	for id in P.OPCIONES:
		var actual: Node3D = P.crear(id,0)
		var altura: float = Pieza3D._caja(actual,Transform3D.IDENTITY).size.y
		actual.free()
		for v in [1,2]:
			var n: Node3D = P.crear(id,v)
			comprobar(n!=null,"Propuesta disponible: "+id+" "+str(v))
			if n==null: continue
			var caja: AABB = Pieza3D._caja(n,Transform3D.IDENTITY)
			comprobar(absf(caja.size.y-altura)<0.002,"Misma altura del juego: "+id+" "+str(v))
			comprobar(absf(caja.position.y)<0.002,"Base a ras del suelo: "+id+" "+str(v))
			comprobar(n.find_children("*","CollisionObject3D",true,false).is_empty(),"La propuesta no añade cuerpos físicos: "+id+" "+str(v))
			comprobar(P.triangulos(n)>0,"Geometría visible: "+id+" "+str(v))
			n.free()
	for v in [1,2]:
		var b := Barril3D.new()
		root.add_child(b)
		var formas: Array[Node] = b.find_children("*","CollisionShape3D",true,false)
		comprobar(not formas.is_empty(),"Barril real tiene colisión "+str(v))
		if formas.is_empty():
			b.free()
			continue
		var forma: CollisionShape3D = formas[0]
		var size_antes: Vector3 = forma.shape.size
		var radio_antes: float = b.radio
		comprobar(P.probar_barril(b,v),"Barril real admite el material de la propuesta "+str(v))
		comprobar(forma.shape.size==size_antes and b.radio==radio_antes,"Colisión y radio de explosión conservados "+str(v))
		var caja: AABB = Pieza3D._caja(b._cuerpo,Transform3D.IDENTITY)
		comprobar(absf(caja.size.y-b.alto)<0.002,"Altura de pólvora y mecha compatibles "+str(v))
		b._poner_color_mecha(0.65)
		comprobar(b._mat.albedo_color.g<0.9,"El parpadeo rojo actúa en el nuevo material "+str(v))
		b.apagar()
		comprobar(b._mat.albedo_color.is_equal_approx(Color.WHITE),"Apagar restaura el color original "+str(v))
		b.free()
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)

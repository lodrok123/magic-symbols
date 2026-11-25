extends SceneTree
## MEDIDAS de la mano en reposo: maniquí UAL (arte/ual/ual1_standard_mixamo.glb) frente a jugadora_base (25/11, dedos torcidos en los clips UAL). Para cada mano:
## la dirección muñeca → nudillo del corazón (eje «largo») y la dirección nudillo del índice → nudillo del meñique (eje «ancho» de la palma), en el espacio de la
## raíz de cada escena. Tras alinear el eje largo (lo que ya hace ClipsFamilia con «Hand»), el ángulo que queda entre los ejes anchos es el giro de la palma
## sobre su eje que el retarget NO corrige. Sin ventana:
##   godot --headless --path . --script res://herramientas/medidas_manos_ual.gd

const UAL: String = "res://arte/ual/ual1_standard_mixamo.glb"


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar("jugadora_base")
	var sk_d: Skeleton3D = pj._modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ual: Node3D = (load(UAL) as PackedScene).instantiate() as Node3D
	root.add_child(ual)
	var sk_s: Skeleton3D = ual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for lado in ["Left", "Right"]:
		var d: Array = _ejes(sk_d, pj._modelo, lado)
		var s: Array = _ejes(sk_s, ual, lado)
		var alin := Quaternion(d[0], s[0])
		var ancho_d: Vector3 = alin * (d[1] as Vector3)
		var giro: float = rad_to_deg(_angulo_sobre(ancho_d, s[1], s[0]))
		print("%s: largo dest %s · fuente %s (%.1f°) · ancho tras alinear el largo: %.1f° de giro de palma" % [lado, _v(d[0]), _v(s[0]), rad_to_deg((d[0] as Vector3).angle_to(s[0])), giro])
		for dedo in ["Index", "Middle", "Thumb"]:
			var a: int = sk_d.find_bone("mixamorig_%sHand%s1" % [lado, dedo])
			var b: int = sk_s.find_bone("mixamorig_%sHand%s1" % [lado, dedo])
			var a2: int = sk_d.find_bone("mixamorig_%sHand%s2" % [lado, dedo])
			var b2: int = sk_s.find_bone("mixamorig_%sHand%s2" % [lado, dedo])
			var fd: Vector3 = _rot(pj._modelo, sk_d) * (sk_d.get_bone_global_rest(a2).origin - sk_d.get_bone_global_rest(a).origin)
			var fs: Vector3 = _rot(ual, sk_s) * (sk_s.get_bone_global_rest(b2).origin - sk_s.get_bone_global_rest(b).origin)
			print("   %s1→2 respecto al largo de su mano: dest %.1f° · fuente %.1f°" % [dedo, rad_to_deg(fd.angle_to(d[0])), rad_to_deg(fs.angle_to(s[0]))])
	quit()


func _rot(raiz: Node3D, sk: Skeleton3D) -> Basis:
	return (raiz.global_transform.affine_inverse() * sk.global_transform).basis.orthonormalized()


## [eje largo, eje ancho] de la mano `lado` en reposo, normalizados, en el espacio de `raiz`.
func _ejes(sk: Skeleton3D, raiz: Node3D, lado: String) -> Array:
	var b: Basis = _rot(raiz, sk)
	var p := func(n: String) -> Vector3: return b * sk.get_bone_global_rest(sk.find_bone("mixamorig_%s%s" % [lado, n])).origin
	var largo: Vector3 = (p.call("HandMiddle1") - p.call("Hand")).normalized()
	var ancho: Vector3 = (p.call("HandPinky1") - p.call("HandIndex1"))
	ancho = (ancho - largo * ancho.dot(largo)).normalized()
	return [largo, ancho]


## Ángulo con signo de `a` a `b` alrededor de `eje` (los dos ya perpendiculares a él).
func _angulo_sobre(a: Vector3, b: Vector3, eje: Vector3) -> float:
	return atan2(eje.dot(a.cross(b)), a.dot(b))


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]

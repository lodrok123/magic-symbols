extends SceneTree

## PRUEBA (Pipeline, 20/10, entrada 215): el dibujo de un PROYECTIL de VfxElemento3D. Mide, sobre el árbol:
##   1. NACE PEQUEÑO: justo al montarse, la escala del seguidor es ≈ PROYECTIL_ESCALA_INICIAL y a los PROYECTIL_CRECE_S s es 1 (monótona entre medias).
##   2. EL TAMAÑO SIGUE A LA VARIABLE: el radio de la esfera mayor del dibujo crece con `semieje_x` sin toparse (antes se paraba en 0,9 u, semieje ≈ 0,39 m).
##   3. EN REPOSO NO HAY LÍNEAS: en movimiento hay cola/chispas visibles; al dejar de estar `activo` (llegó, chocó, golpeó) no queda ninguna partícula ni cono visible,
##      y el cuerpo (esferas del fuego y el agua, terrones, aros) sigue ahí.
##   godot --headless --path . --script res://herramientas/prueba_vfx_proyectil.gd
class FalsoLanzador:
	extends Node
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)
	signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)
	var fx: Vfx3D = null

const ELEMENTOS: Array = [["plasma", "fuego"], ["liquido", "agua"], ["solido", "tierra"], ["gas", "viento"]]
var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  MAL  ") + texto)
	if not cond:
		_fallos += 1


func _correr() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var l := FalsoLanzador.new()
	mundo.add_child(l)
	l.fx = Vfx3D.new()
	mundo.add_child(l.fx)
	var estado: VfxEstado3D = VfxEstado3D.conectar(l, mundo)
	estado.encendido = false
	var vfx: VfxElemento3D = VfxElemento3D.conectar(l, mundo)
	await process_frame
	print("--- 1. nace pequeño y llega a su tamaño (se maneja el reloj a mano: así no depende de lo lento que vaya el sandbox)")
	var hv: HechizoVivo = _proyectil(mundo, "plasma", "fuego", 0.25, Vector3.ZERO)
	vfx._dibujar_proyectil(weakref(hv))
	var seg: VfxElemento3D.Proyectil = hv.get_node_or_null("VfxElementoProyectil") as VfxElemento3D.Proyectil
	_ok(seg != null, "el proyectil tiene su seguidor")
	if seg == null:
		quit(1)
		return
	var e0: float = seg.scale.x
	# Fuego: nace del tamaño de la bola que ya tenía en la mano (RADIO_CARGA), para que sea la MISMA bola: radio real × escala al nacer = radio de la carga (si no se sale de los límites).
	var r_real: float = 0.3 * clampf(maxf(hv.h.semieje_x, hv.h.semieje_z) * vfx.casilla / 0.3, VfxElemento3D.FACTOR_BOLA_MIN, VfxElemento3D.FACTOR_BOLA_MAX)
	var esperado: float = clampf(FasesFuego3D.radio_carga() / r_real, VfxElemento3D.PROYECTIL_ESCALA_INICIAL, 1.0)
	_ok(absf(e0 - esperado) < 0.001, "fuego: al nacer mide %.2f del tamaño real (esperado %.2f: la bola de la mano era %.2f u, la del proyectil %.2f u)" % [e0, esperado, FasesFuego3D.radio_carga(), r_real])
	_ok(absf(e0 * r_real - FasesFuego3D.radio_carga()) < 0.01 or e0 <= VfxElemento3D.PROYECTIL_ESCALA_INICIAL + 0.001 or e0 >= 0.999, "fuego: sin salto de tamaño al soltar la bola (%.3f u al nacer frente a %.2f u en la mano)" % [e0 * r_real, FasesFuego3D.radio_carga()])
	var antes: float = e0
	var mono: bool = true
	var n_pasos: int = 10
	for i in range(n_pasos):
		seg._process(VfxElemento3D.PROYECTIL_CRECE_S / float(n_pasos))
		mono = mono and seg.scale.x >= antes - 0.0001
		antes = seg.scale.x
		if i == 4:
			_ok(seg.scale.x > e0 and seg.scale.x < 1.0, "a mitad de tiempo mide %.2f (entre %.2f y 1)" % [seg.scale.x, e0])
	_ok(mono, "crece de forma monótona")
	_ok(absf(seg.scale.x - 1.0) < 0.001, "llega a su tamaño real (%.3f)" % seg.scale.x)
	print("--- 2. el tamaño sigue a `semieje_x`")
	var ultimo: float = 0.0
	for s in [0.15, 0.25, 0.40, 0.70, 1.5, 3.0]:
		var h2: HechizoVivo = _proyectil(mundo, "plasma", "fuego", s, Vector3(0.0, 0.0, 20.0))
		vfx._dibujar_proyectil(weakref(h2))
		var r: float = _radio_mayor(h2.get_node("VfxElementoProyectil"))
		var r_u: float = s * 2.3
		print("     semieje %.2f m → radio dibujado %.3f u (esperado ≈ %.3f)" % [s, r, r_u * 1.15])
		_ok(r > ultimo + 0.001 and absf(r - r_u * 1.15) < 0.02 * maxf(r_u, 1.0), "semieje %.2f: crece y coincide con la caja de golpe" % s)
		ultimo = r
		h2.queue_free()
	print("--- 3. en reposo no hay líneas de movimiento")
	for par in ELEMENTOS:
		var h3: HechizoVivo = _proyectil(mundo, par[0], par[1], 0.25, Vector3(10.0, 0.0, 0.0))
		vfx._dibujar_proyectil(weakref(h3))
		var s3: VfxElemento3D.Proyectil = h3.get_node("VfxElementoProyectil") as VfxElemento3D.Proyectil
		s3._process(0.7)                          # ya creció del todo
		var mov: Array = _contar(s3)
		_ok(int(mov[0]) + int(mov[1]) > 0, "%s en movimiento: %d partículas + %d mallas de cola visibles" % [par[1], mov[0], mov[1]])
		h3.activo = false                       # llegó / chocó / golpeó: se queda quieto (permanencia)
		s3._process(0.01)
		s3._process(VfxElemento3D.PROYECTIL_COLA_APAGA_S + 0.05)
		var rep: Array = _contar(s3)
		_ok(s3.parado() and int(rep[0]) == 0 and int(rep[1]) == 0, "%s parado: 0 partículas y 0 conos/cintas visibles (hay %d y %d)" % [par[1], rep[0], rep[1]])
		if String(par[1]) == "fuego":
			_ok(not s3.visible, "fuego parado: la bola se oculta (la explosión la sustituye, 20/10 19:53)")
		else:
			_ok(int(rep[2]) > 0, "%s parado: el cuerpo sigue visible (%d mallas)" % [par[1], rep[2]])
		h3.queue_free()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _proyectil(l: Node, estado: String, elemento: String, semieje: float, pos: Vector3) -> HechizoVivo:
	var hv := HechizoVivo.new()
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
	l.add_child(hv)
	hv.set_physics_process(false)             # sin mundo real, el paso físico del HechizoVivo no tiene nada que consultar
	hv.global_position = pos
	return hv


## Radio de la esfera mayor del dibujo (la envoltura del fuego o la piel del agua), en unidades de mundo (sin la escala del seguidor, que ya es 1).
func _radio_mayor(raiz: Node) -> float:
	var m: float = 0.0
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var me: Mesh = (n as MeshInstance3D).mesh
		if me is SphereMesh:
			m = maxf(m, (me as SphereMesh).radius)
	return m


## [partículas visibles, mallas de cola visibles (no esferas), mallas de cuerpo visibles (esferas / terrones / aros)].
func _contar(raiz: Node) -> Array:
	var p: int = 0
	var c: int = 0
	var cuerpo: int = 0
	for n in raiz.find_children("*", "", true, false):
		if n is GPUParticles3D:
			if (n as GPUParticles3D).is_visible_in_tree() and (n as GPUParticles3D).emitting:
				p += 1
		elif n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
			var me: Mesh = (n as MeshInstance3D).mesh
			if me is CylinderMesh:
				c += 1
			else:
				cuerpo += 1
	return [p, c, cuerpo]

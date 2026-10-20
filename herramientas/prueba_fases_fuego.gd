extends SceneTree

## PRUEBA (Pipeline, 20/10, entrada 217): las fases del fuego (`FasesFuego3D`) y que CADA VARIABLE hace algo. Pablo: «no funcionan los cambios de variables».
## Por eso la prueba central no mira que el efecto exista, sino que cada variable de `FasesFuego3D.DEF` CAMBIA UNA MEDIDA del árbol de nodos al llevarla del mínimo al máximo
## (cantidad de partículas, radio, energía de la luz, tono, volumen…). Una variable sin medida que cambie = un slider muerto = fallo.
## Además: el proyectil de fuego pide el impacto al chocar y el fin al agotarse (una sola vez, también si el HechizoVivo se libera en ese cuadro), los demás elementos no, la carga
## aglutina chispas y suena en bucle, el sonido se corta al disparar, y guardar/cargar devuelve lo mismo.
##   godot --headless --path . --script res://herramientas/prueba_fases_fuego.gd
class FalsoLanzador:
	extends Node
	signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)
	signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)
	var fx: Vfx3D = null
	func tiempos_conjuro(_e: String) -> Array:
		return [0.1, 0.25, 0.1]

var _fallos: int = 0
var _mundo: Node3D = null
var _l: FalsoLanzador = null
var _conjuro: ConjuroVfx3D = null
var _vfx: VfxElemento3D = null


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  MAL  ") + texto)
	if not cond:
		_fallos += 1


func _nuevo_mundo() -> void:
	if _mundo != null:
		_mundo.queue_free()
	_mundo = Node3D.new()
	root.add_child(_mundo)


func _correr() -> void:
	FasesFuego3D.persistir = false            # que no dependa de lo que Pablo tenga guardado
	FasesFuego3D.restaurar()
	_nuevo_mundo()
	_l = FalsoLanzador.new()
	_mundo.add_child(_l)
	_l.fx = Vfx3D.new()
	_mundo.add_child(_l.fx)
	var estado: VfxEstado3D = VfxEstado3D.conectar(_l, _mundo)
	estado.encendido = false
	_conjuro = ConjuroVfx3D.conectar(_l, _mundo)
	_vfx = VfxElemento3D.conectar(_l, _mundo)
	await process_frame
	print("--- 1. cada variable cambia algo medible (mínimo frente a máximo)")
	for d in FasesFuego3D.DEF:
		var k: String = String(d[0])
		var m0: float = await _medir(k, float(d[2]))
		var m1: float = await _medir(k, float(d[3]))
		FasesFuego3D.restaurar()
		_ok(not is_equal_approx(m0, m1), "%s: mín %.3f → máx %.3f" % [k, m0, m1])
	print("--- 2. el proyectil de fuego pide impacto / fin")
	await _proyectiles()
	print("--- 3. la carga: chispas que se aglutinan y sonido en bucle")
	await _carga()
	print("--- 4. guardar y cargar")
	_persistencia()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## --- Medidas ---

func _gp(raiz: Node, quad_chispas: bool) -> GPUParticles3D:
	for n in raiz.find_children("*", "GPUParticles3D", true, false):
		var q: QuadMesh = (n as GPUParticles3D).draw_pass_1 as QuadMesh
		if q != null and (q.size.y > 0.5 and q.size.x < 0.5) == quad_chispas:
			return n as GPUParticles3D
	return null


func _radio_esfera(raiz: Node) -> float:
	var m: float = 0.0
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh is SphereMesh:
			m = maxf(m, (((n as MeshInstance3D).mesh as SphereMesh).radius) * (n as Node3D).scale.x)
	return m


func _luz(raiz: Node) -> float:
	var e: float = 0.0
	for n in raiz.find_children("*", "OmniLight3D", true, false):
		e = maxf(e, (n as OmniLight3D).light_energy)
	return e


func _humo(raiz: Node) -> float:
	var c: int = 0
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.material_override is StandardMaterial3D and (mi.material_override as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED:
			c += 1
	return float(c)


func _lenguas(raiz: Node) -> float:
	var c: int = 0
	for n in raiz.get_children():
		if n.get_class() == "Node3D" and n.get_child_count() == 1 and n.get_child(0) is MeshInstance3D:
			c += 1
	return float(c)


## Avanza todos los tweens vivos `s` segundos de golpe (así se mide el valor FINAL de lo que se anima sin esperar en tiempo real).
func _avanzar_tweens(s: float) -> void:
	for tw in get_processed_tweens():
		if tw.is_valid():
			tw.custom_step(s)


func _hijos_marca() -> float:
	var c: int = 0
	for n in _mundo.get_children():
		if n is Decal or (n is MeshInstance3D):
			c += 1
	return float(c)


## Pone `k` a `valor` y devuelve la medida que le corresponde. Un `match` por variable: si se añade una variable a DEF sin medida, la prueba falla (`MAL: sin medida`).
func _medir(k: String, valor: float) -> float:
	FasesFuego3D.restaurar()
	FasesFuego3D.poner(k, valor)
	_nuevo_mundo()
	var r: Node3D = null
	match k:
		"carga_n_ini", "carga_n_fin", "carga_radio", "carga_tam", "carga_luz", "carga_rampa_s":
			FasesFuego3D.poner("carga_rampa_s", 0.2 if k != "carga_rampa_s" else valor)
			var c := ConjuroVfx3D.new()
			_mundo.add_child(c)
			var f: Node3D = c.forma("fuego", Vector3.ZERO, 0.1)
			var ch: GPUParticles3D = f.get_node("Convergen") as GPUParticles3D
			match k:
				"carga_n_ini":
					return ch.amount_ratio * float(ch.amount)
				"carga_n_fin":
					return float(ch.amount)
				"carga_radio":
					return (ch.process_material as ParticleProcessMaterial).emission_sphere_radius
				"carga_tam":
					return ((ch.draw_pass_1 as QuadMesh).size.x)
				"carga_luz":
					await create_timer(0.5, true, false, true).timeout
					return _luz(f)
				"carga_rampa_s":
					await create_timer(0.3, true, false, true).timeout          # 0,2 s de rampa → ya está al 100 %; 4 s → casi nada
					return ch.amount_ratio
		"carga_bola_r":
			var c4 := ConjuroVfx3D.new()
			_mundo.add_child(c4)
			return _radio_esfera(c4.forma("fuego", Vector3.ZERO, 0.1))
		"carga_bola_ini", "carga_bola_s":
			FasesFuego3D.poner("carga_bola_s", 0.2 if k != "carga_bola_s" else valor)
			var c3 := ConjuroVfx3D.new()
			_mundo.add_child(c3)
			var f3: Node3D = c3.forma("fuego", Vector3.ZERO, 0.1)
			var bola: Node3D = f3.get_meta("bola") as Node3D
			if k == "carga_bola_ini":
				return bola.scale.x                                           # nada más nacer
			await create_timer(0.3, true, false, true).timeout             # con 0,2 s ya llegó a 1; con 3 s casi no ha crecido
			return bola.scale.x
		"carga_destello":
			var c2 := ConjuroVfx3D.new()
			_mundo.add_child(c2)
			c2.destello("fuego", Vector3.ZERO)
			var mi: Node3D = null
			for n in c2.get_children():
				if n is MeshInstance3D:
					mi = n as Node3D
			var mx: float = 0.0
			for i in range(40):
				if mi == null or not is_instance_valid(mi):
					break
				mx = maxf(mx, mi.scale.x)
				_avanzar_tweens(0.01)
				await process_frame
			return mx
		"snd_activo", "snd_db", "snd_tono_ini", "snd_tono_fin":
			FasesFuego3D.poner("carga_rampa_s", 0.2)
			var origen := Node3D.new()
			_mundo.add_child(origen)
			var p: Node = FasesFuego3D.sonido_carga(origen)
			if p == null:
				return -1.0                                              # apagado: otra medida distinta de cualquier sonido real
			var res: float = 0.0
			if k == "snd_db":
				await create_timer(0.4, true, false, true).timeout
				res = float(p.get("volume_db"))
			elif k == "snd_tono_ini":
				res = float(p.get("pitch_scale"))
			elif k == "snd_tono_fin":
				await create_timer(0.4, true, false, true).timeout
				res = float(p.get("pitch_scale"))
			else:
				res = 1.0
			Sfx.parar(p, 0.0)
			return res
		"imp_escala", "imp_con_tamano", "imp_flash":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 3.0, 0.0)
			return _radio_esfera(r)
		"imp_anillo":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			_avanzar_tweens(FasesFuego3D.v("imp_dur") * 0.6)
			var e: float = 0.0
			for n in r.find_children("*", "MeshInstance3D", true, false):
				if (n as MeshInstance3D).mesh is QuadMesh and ((n as MeshInstance3D).mesh as QuadMesh).orientation == PlaneMesh.FACE_Y:
					e = (n as Node3D).scale.x
			return e
		"imp_lenguas":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			return _lenguas(r)
		"imp_brasas":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			var g: GPUParticles3D = _gp(r, false)
			return float(g.amount) if g != null else 0.0
		"imp_chispas":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			var g2: GPUParticles3D = _gp(r, true)
			return float(g2.amount) if g2 != null else 0.0
		"imp_vel":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			var g3: GPUParticles3D = _gp(r, false)
			return (g3.process_material as ParticleProcessMaterial).initial_velocity_max if g3 != null else 0.0
		"imp_humo":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			return _humo(r)
		"imp_luz":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			return _luz(r)
		"imp_dur":
			r = FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			var g4: GPUParticles3D = _gp(r, false)
			return g4.lifetime if g4 != null else 0.0
		"imp_marca":
			var antes: float = _hijos_marca()
			FasesFuego3D.impacto(_mundo, Vector3.ZERO, 1.0, 0.0)
			return _hijos_marca() - antes
		"fin_fogonazo":
			r = FasesFuego3D.desvanecer(_mundo, Vector3.ZERO, 1.0)
			return _radio_esfera(r)
		"fin_brasas":
			r = FasesFuego3D.desvanecer(_mundo, Vector3.ZERO, 1.0)
			var g5: GPUParticles3D = _gp(r, false)
			return float(g5.amount) if g5 != null else 0.0
		"fin_humo":
			r = FasesFuego3D.desvanecer(_mundo, Vector3.ZERO, 1.0)
			return _humo(r)
		"fin_dur":
			r = FasesFuego3D.desvanecer(_mundo, Vector3.ZERO, 1.0)
			var g6: GPUParticles3D = _gp(r, false)
			return g6.lifetime if g6 != null else 0.0
	_ok(false, "%s: sin medida en la prueba (¿variable nueva?)" % k)
	return 0.0


## --- Proyectil → impacto / fin ---

func _hv(velocidad: float, elemento: String, pos: Vector3) -> HechizoVivo:
	var hv := HechizoVivo.new()
	hv.h = Hechizo.new()
	hv.h.velocidad = velocidad
	hv.estado = "plasma"
	hv.elemento = elemento
	hv.activo = true
	hv.proyectil = true
	hv.v = Vector3(3.9, 0.0, 0.0)
	_l.add_child(hv)
	hv.set_physics_process(false)
	hv.global_position = pos
	return hv


func _cuantos(nombre: String) -> int:
	var c: int = 0
	for n in _mundo.get_children():
		if n.name.begins_with(nombre):
			c += 1
	return c


func _proyectiles() -> void:
	FasesFuego3D.restaurar()
	_nuevo_mundo()
	var l2 := FalsoLanzador.new()
	_mundo.add_child(l2)
	l2.fx = Vfx3D.new()
	_mundo.add_child(l2.fx)
	var ve: VfxElemento3D = VfxElemento3D.conectar(l2, _mundo)
	_l = l2
	await process_frame
	for caso in [["golpe", "ImpactoFuego"], ["muro", "ImpactoFuego"], ["suelo", "ImpactoFuego"], ["alcance", "FinFuego"], ["tiempo", "FinFuego"], ["frenado", "FinFuego"]]:
		var hv: HechizoVivo = _hv(1.7, "fuego", Vector3(2.0, 1.0, 0.0))
		await process_frame
		await process_frame
		var seg: VfxElemento3D.Proyectil = hv.get_node_or_null("VfxElementoProyectil") as VfxElemento3D.Proyectil
		if seg == null:
			_ok(false, "%s: el proyectil no tiene seguidor" % caso[0])
			continue
		var imp0: int = _cuantos("ImpactoFuego")
		var fin0: int = _cuantos("FinFuego")
		hv.motivo_fin = String(caso[0])
		hv.activo = false
		seg._process(0.01)
		seg._process(0.01)                                               # la segunda vez NO repite
		var imp1: int = _cuantos("ImpactoFuego") - imp0
		var fin1: int = _cuantos("FinFuego") - fin0
		var quiere_imp: bool = String(caso[1]) == "ImpactoFuego"
		_ok(not seg.visible, "motivo «%s»: la bola del fuego se oculta al pararse (aunque el HechizoVivo siga colgado por permanencia)" % caso[0])
		_ok(imp1 == (1 if quiere_imp else 0) and fin1 == (0 if quiere_imp else 1), "motivo «%s» → %s (una sola vez): impactos %d, fines %d" % [caso[0], caso[1], imp1, fin1])
		hv.queue_free()
		await process_frame
	# El HechizoVivo se libera en el MISMO cuadro en que se para (sin permanencia): el impacto no se pierde y no se duplica.
	var hv2: HechizoVivo = _hv(1.7, "fuego", Vector3(3.0, 1.0, 0.0))
	await process_frame
	await process_frame
	var i0: int = _cuantos("ImpactoFuego")
	hv2.motivo_fin = "golpe"
	hv2.activo = false
	hv2.queue_free()
	await process_frame
	await process_frame
	_ok(_cuantos("ImpactoFuego") - i0 == 1, "se libera en el mismo cuadro: un impacto (%d)" % (_cuantos("ImpactoFuego") - i0))
	# Se va con el proyectil todavía VIVO (fin de nivel): sin explosión.
	var hv3: HechizoVivo = _hv(1.7, "fuego", Vector3(3.0, 1.0, 0.0))
	await process_frame
	await process_frame
	var i1: int = _cuantos("ImpactoFuego")
	var f1: int = _cuantos("FinFuego")
	hv3.queue_free()
	await process_frame
	await process_frame
	_ok(_cuantos("ImpactoFuego") == i1 and _cuantos("FinFuego") == f1, "liberado aún activo: ni impacto ni fin")
	# Otro elemento: no hay fases del fuego.
	var hv4: HechizoVivo = _hv(1.7, "agua", Vector3(4.0, 1.0, 0.0))
	await process_frame
	await process_frame
	var s4: VfxElemento3D.Proyectil = hv4.get_node("VfxElementoProyectil") as VfxElemento3D.Proyectil
	var i2: int = _cuantos("ImpactoFuego") + _cuantos("FinFuego")
	hv4.motivo_fin = "golpe"
	hv4.activo = false
	s4._process(0.01)
	_ok(_cuantos("ImpactoFuego") + _cuantos("FinFuego") == i2, "agua: sin explosión de fuego")
	_ok(s4.visible, "agua: su cuerpo se queda (permanencia) como siempre")
	ve.queue_free()


## --- Carga ---

func _carga() -> void:
	FasesFuego3D.restaurar()
	_nuevo_mundo()
	var l3 := FalsoLanzador.new()
	_mundo.add_child(l3)
	var c: ConjuroVfx3D = ConjuroVfx3D.conectar(l3, _mundo)
	var pos := Vector3(1.0, 1.3, 0.0)
	l3.conjuro_fase.emit("runa", "fuego", pos)
	l3.conjuro_fase.emit("forma", "fuego", pos)
	await process_frame
	var forma: Node = null
	for n in c.get_children():
		if n.get_node_or_null("Convergen") != null:
			forma = n
	_ok(forma != null, "la forma del fuego trae sus chispas que convergen")
	if forma != null:
		var ch: GPUParticles3D = forma.get_node("Convergen") as GPUParticles3D
		# Continuidad (20:13): la bola de la mano lleva el MISMO degradado (rojo→naranja→amarillo) que la del proyectil.
		var con_rampa: int = 0
		for n in forma.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh is SphereMesh and mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).get_shader_parameter("rampa") == FasesFuego3D.rampa_bola():
				con_rampa += 1
		_ok(con_rampa >= 1, "la bola de la mano usa la rampa de la bola del proyectil (%d esferas)" % con_rampa)
		var brillos: int = 0
		var esferas_duras: int = 0
		for n in forma.find_children("*", "MeshInstance3D", true, false):
			var mi2: MeshInstance3D = n as MeshInstance3D
			if mi2.mesh is QuadMesh and mi2.material_override is StandardMaterial3D and (mi2.material_override as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
				brillos += 1
				_ok((mi2.material_override as StandardMaterial3D).billboard_keep_scale, "el resplandor conserva la escala (si no, el billboard mide siempre 1 m y la bola no crece)")
			if mi2.mesh is SphereMesh and mi2.material_override is ShaderMaterial and (mi2.material_override as ShaderMaterial).render_priority == 2:
				esferas_duras += 1
		_ok(brillos == 2 and esferas_duras == 0, "el núcleo es un resplandor blando (%d capas) y no la esfera con borde (%d)" % [brillos, esferas_duras])
		var bola_c: Node3D = forma.get_meta("bola") as Node3D
		_ok(bola_c.scale.x < 0.2, "la bola nace pequeña y no a su tamaño (%.2f)" % bola_c.scale.x)
		_ok(ch.amount == int(FasesFuego3D.v("carga_n_fin")), "tiene %d chispas máximas (carga_n_fin)" % ch.amount)
		_ok(ch.amount_ratio < 0.5, "empieza con pocas (%d%%)" % roundi(ch.amount_ratio * 100.0))
		await create_timer(FasesFuego3D.v("carga_rampa_s") + 0.3, true, false, true).timeout
		_ok(ch.amount_ratio > 0.99, "y acaba con todas (%d%%)" % roundi(ch.amount_ratio * 100.0))
		_ok(absf(bola_c.scale.x - 1.0) < 0.12, "la bola llega a su tamaño (%.2f)" % bola_c.scale.x)
	var sonidos: Array = _bucles()
	_ok(sonidos.size() == 1, "suena UN bucle de carga (%d)" % sonidos.size())
	if sonidos.size() == 1:
		var p: Node = sonidos[0]
		_ok(((p.get("stream") as AudioStreamWAV).loop_mode) == AudioStreamWAV.LOOP_FORWARD, "el bucle está en bucle hacia delante")
		_ok(absf(float(p.get("pitch_scale")) - FasesFuego3D.v("snd_tono_fin")) < 0.05, "el tono ha subido al final (%.2f)" % float(p.get("pitch_scale")))
	l3.conjuro_fase.emit("disparo", "fuego", pos)
	await create_timer(0.4, true, false, true).timeout
	_ok(_bucles().is_empty(), "al disparar el bucle se corta y se libera")
	# Otro elemento: sin bucle ni cambios.
	l3.conjuro_fase.emit("runa", "agua", pos)
	l3.conjuro_fase.emit("forma", "agua", pos)
	await process_frame
	_ok(_bucles().is_empty(), "agua: sin bucle de fuego")
	var forma_agua: Node = null
	for n in c.get_children():
		if n.get_node_or_null("Convergen") != null:
			forma_agua = n
	if forma_agua != null:
		_ok((forma_agua.get_node("Convergen") as GPUParticles3D).amount == 30, "agua: sus 30 chispas de siempre")


func _bucles() -> Array:
	var r: Array = []
	var pila: Array = [root]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).stream is AudioStreamWAV and ((n as AudioStreamPlayer3D).stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD and not n.is_queued_for_deletion():
			r.append(n)
		pila.append_array(n.get_children())
	return r


## --- Guardar / cargar ---

func _persistencia() -> void:
	FasesFuego3D.restaurar()
	FasesFuego3D.poner("imp_brasas", 90.0)
	FasesFuego3D.poner("snd_tono_fin", 2.0)
	_ok(FasesFuego3D.tocadas().size() == 2, "dos variables tocadas (%d)" % FasesFuego3D.tocadas().size())
	var ruta: String = "user://prueba_fases_fuego.json"
	_ok(FasesFuego3D.guardar(ruta), "guarda")
	FasesFuego3D.restaurar()
	_ok(FasesFuego3D.tocadas().is_empty(), "restaurar lo deja todo de fábrica")
	_ok(FasesFuego3D.cargar(ruta) and is_equal_approx(FasesFuego3D.v("imp_brasas"), 90.0) and is_equal_approx(FasesFuego3D.v("snd_tono_fin"), 2.0), "cargar devuelve lo guardado")
	FasesFuego3D.poner("imp_brasas", 99999.0)
	_ok(is_equal_approx(FasesFuego3D.v("imp_brasas"), 150.0), "un valor fuera de rango se recorta al máximo (%.0f)" % FasesFuego3D.v("imp_brasas"))
	FasesFuego3D.restaurar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))

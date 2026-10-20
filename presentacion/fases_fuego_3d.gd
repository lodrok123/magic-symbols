class_name FasesFuego3D
extends RefCounted

## LAS TRES FASES DEL FUEGO QUE FALTABAN (Pipeline, 20/10, entrada 217; pedido de Pablo tras el vídeo «level up a fireball»):
##   CARGA    mientras se carga/apunta: chispas que se aglutinan en la mano (más y más densas) + un bucle de sonido que sube de tono. Lo monta `ConjuroVfx3D`.
##   IMPACTO  cuando el proyectil se para contra algo (golpe, muro, suelo): fogonazo + anillo de onda en el suelo + lenguas + explosión de brasas y chispas + humo + luz + marca.
##   FIN      cuando el proyectil se agota SIN chocar (alcance, tiempo, frenado): fogonazo pequeño, brasas que se dispersan y un hilo de humo. Antes se cortaba de golpe.
## Los dos últimos los pide `VfxElemento3D.Proyectil` al pararse el proyectil (lee `motivo_fin` del HechizoVivo).
##
## POR QUÉ una clase aparte con TODOS los números aquí: Pablo se queja de que «los cambios de variables no funcionan» (entrada 215). Aquí cada número es una variable con su
## nombre, su rango y su texto (`DEF`), se lee SIEMPRE con `v()` en el momento de montar el efecto (nada se copia a constantes), `LabFasesFuego` los mueve con sliders EN VIVO
## y `prueba_fases_fuego.gd` comprueba que cada uno cambia algo MEDIBLE en el árbol de nodos. Los valores tocados se guardan en user://fases_fuego.json (`guardar`), y se cargan
## solos al empezar: lo que apruebas en el lab es lo que sale en el mapa.
## Solo fuego por ahora (decisión de Pablo): `aplica(elemento)`. Los demás elementos siguen como estaban.

## [clave, valor, mín, máx, paso, grupo, texto]. El orden es el del lab.
const DEF: Array = [
	["carga_bola_r", 0.35, 0.15, 0.8, 0.01, "carga", "radio de la bola de la mano (u); el proyectil nace de este tamaño"],
	["carga_bola_ini", 0.03, 0.01, 1.0, 0.01, "carga", "tamaño de la bola al empezar a cargar (fracción del final)"],
	["carga_bola_s", 0.9, 0.05, 3.0, 0.05, "carga", "segundos que tarda la bola en llegar a su tamaño"],
	["carga_n_ini", 10.0, 0.0, 60.0, 1.0, "carga", "chispas al empezar a cargar"],
	["carga_n_fin", 80.0, 10.0, 200.0, 5.0, "carga", "chispas tras `carga_rampa_s` (las que se aglutinan)"],
	["carga_rampa_s", 1.2, 0.2, 4.0, 0.1, "carga", "segundos hasta la densidad máxima"],
	["carga_radio", 0.7, 0.2, 1.5, 0.05, "carga", "radio desde el que vienen las chispas (u)"],
	["carga_tam", 0.09, 0.03, 0.30, 0.01, "carga", "tamaño de cada chispa (u)"],
	["carga_luz", 2.4, 0.0, 6.0, 0.1, "carga", "luz de la mano al final de la carga"],
	["carga_destello", 1.6, 0.0, 4.0, 0.1, "carga", "destello al soltar (× el de siempre)"],
	["snd_activo", 1.0, 0.0, 1.0, 1.0, "sonido", "bucle de carga (1 sí, 0 no)"],
	["snd_db", -14.0, -30.0, 0.0, 1.0, "sonido", "volumen al final de la carga (dB)"],
	["snd_tono_ini", 0.8, 0.4, 1.5, 0.05, "sonido", "tono al empezar"],
	["snd_tono_fin", 1.5, 0.6, 2.5, 0.05, "sonido", "tono al final de la carga"],
	["imp_escala", 1.0, 0.3, 3.0, 0.1, "impacto", "tamaño general del impacto"],
	["imp_con_tamano", 0.5, 0.0, 1.0, 0.1, "impacto", "cuánto crece con el tamaño del hechizo (0 nada, 1 todo)"],
	["imp_flash", 0.4, 0.0, 3.0, 0.1, "impacto", "brillo (glim) central"],
	["imp_anillo", 1.0, 0.0, 3.0, 0.1, "impacto", "onda en el suelo (radio)"],
	["imp_lenguas", 0.0, 0.0, 12.0, 1.0, "impacto", "lenguas de llama"],
	["imp_brasas", 40.0, 0.0, 150.0, 5.0, "impacto", "brasas de la explosión"],
	["imp_chispas", 40.0, 0.0, 100.0, 2.0, "impacto", "chispas alargadas que salen hacia afuera"],
	["imp_vel", 4.0, 1.0, 10.0, 0.5, "impacto", "velocidad de salida de brasas y chispas (u/s)"],
	["imp_humo", 0.0, 0.0, 16.0, 1.0, "impacto", "bocanadas de humo"],
	["imp_luz", 1.2, 0.0, 8.0, 0.2, "impacto", "luz del estallido"],
	["imp_dur", 0.7, 0.3, 3.0, 0.1, "impacto", "duración del estallido (s)"],
	["imp_marca", 1.0, 0.0, 1.0, 1.0, "impacto", "deja chamusco en el suelo (1 sí, 0 no)"],
	["fin_fogonazo", 0.6, 0.0, 2.0, 0.1, "fin", "fogonazo al agotarse"],
	["fin_brasas", 16.0, 0.0, 80.0, 2.0, "fin", "brasas que se dispersan"],
	["fin_humo", 3.0, 0.0, 10.0, 1.0, "fin", "bocanadas de humo"],
	["fin_dur", 0.8, 0.2, 3.0, 0.1, "fin", "duración (s)"],
]
const RUTA: String = "user://fases_fuego.json"
const HUMO_COLOR: Color = Color(0.36, 0.33, 0.31)

## Con false no lee ni escribe el JSON (las pruebas: no deben depender de lo que Pablo tenga guardado).
static var persistir: bool = true
static var _valores: Dictionary = {}
static var _cargado: bool = false
static var _tex_suave: Texture2D = null


static func aplica(elemento: String) -> bool:
	return elemento == "fuego"


## --- Variables ---

static func _asegurar() -> void:
	if not _valores.is_empty() and _cargado:
		return
	if _valores.is_empty():
		for d in DEF:
			_valores[String(d[0])] = float(d[1])
	if not _cargado:
		_cargado = true
		if persistir:
			cargar()


## El valor VIGENTE de una variable. Se lee en el momento de montar el efecto: lo que toques afecta al siguiente.
static func v(clave: String) -> float:
	_asegurar()
	return float(_valores.get(clave, 0.0))


static func poner(clave: String, valor: float) -> void:
	_asegurar()
	for d in DEF:
		if String(d[0]) == clave:
			_valores[clave] = clampf(valor, float(d[2]), float(d[3]))
			return


static func defecto(clave: String) -> float:
	for d in DEF:
		if String(d[0]) == clave:
			return float(d[1])
	return 0.0


static func restaurar(clave: String = "") -> void:
	_asegurar()
	for d in DEF:
		if clave == "" or String(d[0]) == clave:
			_valores[String(d[0])] = float(d[1])


## Qué variables no están en su valor de fábrica: {clave: valor}.
static func tocadas() -> Dictionary:
	_asegurar()
	var r: Dictionary = {}
	for d in DEF:
		var k: String = String(d[0])
		if not is_equal_approx(float(_valores[k]), float(d[1])):
			r[k] = _valores[k]
	return r


static func guardar(ruta: String = RUTA) -> bool:
	_asegurar()
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(tocadas(), "\t"))
	return true


static func cargar(ruta: String = RUTA) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not (d is Dictionary):
		return false
	for k in (d as Dictionary):
		poner(String(k), float((d as Dictionary)[k]))
	return true


## --- Texturas y piezas comunes ---

static func _suave() -> Texture2D:
	if _tex_suave == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex_suave = t
	return _tex_suave


## Bocanadas de humo: quads con billboard que suben, crecen y se desvanecen (alfa: sube rápido y cae despacio). Cada una lleva su tween, atado a su nodo.
## Mismo método que `ConsumoFuego3D` (con CPUParticles3D salía una bola negra fija): determinista y ≤ 16 quads.
static func _humo(padre: Node3D, n: int, centro: Vector3, radio: float, sube: float, vida: float, tam: float, alfa_max: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	for i in range(n):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = _suave()
		m.albedo_color = Color(HUMO_COLOR, 0.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		padre.add_child(mi)
		var a: float = randf() * TAU
		var r: float = radio * sqrt(randf())
		var ini: Vector3 = centro + Vector3(cos(a) * r, randf_range(0.0, 0.2), sin(a) * r)
		mi.position = ini
		var t0: float = randf_range(0.0, vida * 0.35)
		var dur: float = vida * randf_range(0.65, 1.0)
		var tam_i: float = tam * randf_range(0.7, 1.3)
		mi.scale = Vector3.ONE * tam_i * 0.5
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position", ini + Vector3(randf_range(-0.2, 0.2), sube * randf_range(0.7, 1.2), randf_range(-0.2, 0.2)), dur).set_delay(t0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * tam_i * 1.9, dur).set_delay(t0)
		tw.tween_method(func(e: float) -> void: m.albedo_color.a = alfa_max * smoothstep(0.0, 0.18, e) * (1.0 - smoothstep(0.35, 1.0, e)), 0.0, 1.0, dur).set_delay(t0)


static func _luz_que_cae(padre: Node3D, pos: Vector3, energia: float, rango: float, dur: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = energia
	l.omni_range = rango
	l.shadow_enabled = false
	l.position = pos
	padre.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return l


## LA MISMA BOLA EN TODAS LAS FASES (Pablo, 20:13: «que se sienta que es la misma bola de fuego»): contorno rojo, degradado a naranja y núcleo amarillo. El shader del kit pinta por «calor»
## (centro = más caliente, borde = más frío), así que basta darle esta rampa a las esferas de la carga, del proyectil y del brillo del impacto.
const RAMPA_BOLA: Array = [[0.0, Color(0.7, 0.04, 0.02)], [0.38, Color(0.95, 0.12, 0.03)], [0.62, Color(1.0, 0.42, 0.05)], [0.85, Color(1.0, 0.7, 0.1)], [1.0, Color(1.0, 0.9, 0.28)]]
static var _rampa_bola: GradientTexture1D = null


## Radio con el que la bola de la mano (carga) pasa a ser el proyectil: el proyectil nace de ESTE tamaño (ver `escala_inicial_proyectil`), sin salto. Variable `carga_bola_r`.
static func radio_carga() -> float:
	return v("carga_bola_r")


static func rampa_bola() -> GradientTexture1D:
	if _rampa_bola == null:
		var g := Gradient.new()
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		for e in RAMPA_BOLA:
			offs.append(float((e as Array)[0]))
			cols.append((e as Array)[1] as Color)
		g.offsets = offs
		g.colors = cols
		_rampa_bola = GradientTexture1D.new()
		_rampa_bola.gradient = g
		_rampa_bola.width = 128
	return _rampa_bola


## Pinta con el degradado de la bola la ENVOLTURA de `nodo` y cambia su núcleo por un brillo amarillo sin contorno (`_nucleo_brillante`); la cola de cometa y las partículas no se tocan.
static func colorear_bola(nodo: Node) -> void:
	var nucleos: Array = []
	for n in nodo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh is SphereMesh and mi.material_override is ShaderMaterial:
			var mat: ShaderMaterial = mi.material_override as ShaderMaterial
			mat.set_shader_parameter("rampa", rampa_bola())
			if mat.render_priority == 2:          # el núcleo de `VfxKit3D.bola` / `bola_carga` (la envoltura no lleva prioridad)
				nucleos.append(mi)
	for mi in nucleos:
		_nucleo_brillante(mi)


## Núcleo amarillo, más brillante y SIN CONTORNO (Pablo, 20:17: «veo dos semicírculos, quita el contorno al pequeño»): la esfera pequeña del kit tenía borde duro (se leía como un segundo disco dentro de la bola).
## Se sustituye por un resplandor blando (quad que mira a la cámara con degradado radial, aditivo): amarillo en el borde y casi blanco-amarillo en el centro, sin línea donde acaba.
static func _nucleo_brillante(esfera: MeshInstance3D) -> void:
	var padre: Node = esfera.get_parent()
	var radio: float = (esfera.mesh as SphereMesh).radius
	var pos: Vector3 = esfera.position
	padre.remove_child(esfera)
	esfera.queue_free()
	var q := QuadMesh.new()
	for capa in [[6.0, Color(1.0, 0.7, 0.08, 1.0), 0.9], [3.0, Color(1.0, 0.86, 0.2, 1.0), 1.1]]:        # [diámetro / radio del núcleo, color, brillo HDR]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true         # SIN esto el billboard ignora la escala del nodo y el resplandor medía siempre 1 m: la bola «no crecía» (Pablo, 20:43)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = _suave()
		var c: Color = capa[1]
		m.albedo_color = Color(c.r * float(capa[2]), c.g * float(capa[2]), c.b * float(capa[2]), 1.0)
		m.render_priority = 3                 # por encima de la envoltura
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos
		mi.scale = Vector3.ONE * radio * float(capa[0])
		padre.add_child(mi)


## La bola SIN cola, para la mano mientras se carga: las mismas dos esferas (envoltura y núcleo, con los mismos parámetros) que `VfxKit3D.bola` dibuja en el proyectil.
static func bola_carga(radio: float) -> Node3D:
	var raiz := Node3D.new()
	var antes: String = VfxKit3D.elemento
	VfxKit3D.elemento = "fuego"
	var envoltura: ShaderMaterial = VfxKit3D.material({"cerrado": true, "eje": VfxKit3D.EJE_CENTRO, "erosion": 0.3, "suave": 0.3, "brillo": 1.05, "calor_max": 0.95, "peso_ruido": 0.35, "potencia": 2.4, "fresnel_pot": 1.3, "ondula": 0.05, "ondula_freq": 7.0,
		"escala_ruido": Vector2(2.0, 1.4), "velocidad": Vector2(0.3, 1.2)})
	VfxKit3D._malla(raiz, VfxKit3D._esfera(radio * 1.15), envoltura)
	var nucleo: ShaderMaterial = VfxKit3D.material({"cerrado": true, "eje": VfxKit3D.EJE_CENTRO, "erosion": 0.42, "suave": 0.45, "brillo": 1.25, "calor_max": 1.0, "peso_ruido": 0.3, "fresnel_pot": 1.0,
		"escala_ruido": Vector2(1.5, 1.0), "velocidad": Vector2(0.0, 0.8)})
	nucleo.render_priority = 2
	VfxKit3D._malla(raiz, VfxKit3D._esfera(radio * 0.5), nucleo)
	VfxKit3D.elemento = antes
	colorear_bola(raiz)
	return raiz


## Escala con la que nace el proyectil de fuego: el tamaño que ya tenía la bola de la mano (`carga_bola_r`) respecto al del proyectil, para que no haya salto al soltarla.
static func escala_inicial_proyectil(radio_proyectil: float, minima: float) -> float:
	return clampf(radio_carga() / maxf(radio_proyectil, 0.01), minima, 1.0)


static func _fogonazo(padre: Node3D, pos: Vector3, radio: float, crece: float, dur: float) -> void:
	var f: MeshInstance3D = VfxKit3D._malla(padre, VfxKit3D._esfera(radio), VfxKit3D.material({"eje": VfxKit3D.EJE_CENTRO, "erosion": 0.1, "brillo": 1.5, "calor_max": 1.0, "fresnel_pot": 1.0, "rampa": rampa_bola()}, "fuego"))
	f.position = pos
	f.scale = Vector3.ONE * 0.4
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector3.ONE * crece, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "scale", Vector3.ZERO, dur * 0.65).set_ease(Tween.EASE_IN)
	tw.tween_callback(f.queue_free)


## Raíz del efecto: cuelga de `mundo` (no de lo que lo provoca), en coordenadas de mundo. Se libera sola a los `vive` s.
static func _raiz(mundo: Node, nombre: String, pos: Vector3, vive: float) -> Node3D:
	var r := Node3D.new()
	r.name = nombre
	mundo.add_child(r, true)
	r.global_position = pos
	var tw := r.create_tween()
	tw.tween_interval(vive)
	tw.tween_callback(r.queue_free)
	return r


## --- IMPACTO ---

## La explosión del fuego al pararse contra algo, en `pos` (el punto de choque). `esc` = tamaño del hechizo (radio_u / 0,45, el mismo `esc` de los volúmenes).
## `suelo_y` = altura del suelo bajo el choque (la onda y el chamusco van ahí; NAN = la del propio punto). Devuelve la raíz (se borra sola).
static func impacto(mundo: Node, pos: Vector3, esc: float = 1.0, suelo_y: float = NAN) -> Node3D:
	var k: float = lerpf(1.0, esc, v("imp_con_tamano")) * v("imp_escala")
	var dur: float = v("imp_dur")
	var antes: String = VfxKit3D.elemento
	VfxKit3D.elemento = "fuego"                           # el kit lee el perfil del elemento actual al montar materiales
	var raiz: Node3D = _raiz(mundo, "ImpactoFuego", pos, dur + 1.6)
	var y_suelo: float = suelo_y if not is_nan(suelo_y) else pos.y
	var rel_suelo: float = y_suelo - pos.y
	# 1. Fogonazo central: blanco-naranja que se hincha en 0,1 s y se encoge.
	if v("imp_flash") > 0.0:
		_fogonazo(raiz, Vector3.ZERO, 0.30 * k * v("imp_flash"), 2.4, 0.32 * maxf(dur, 0.3))
	# 2. Onda en el suelo: un aro que se abre y se apaga.
	if v("imp_anillo") > 0.0:
		var anillo: MeshInstance3D = VfxKit3D._malla(raiz, VfxKit3D._quad(Vector2(1.0, 1.0), true), VfxKit3D._material_plano(VfxKit3D.aro(), VfxKit3D.perfil()["aro"], 2.4))
		anillo.position = Vector3(0.0, rel_suelo + 0.04, 0.0)
		anillo.scale = Vector3.ONE * 0.4 * k
		var twa := anillo.create_tween().set_parallel(true)
		twa.tween_property(anillo, "scale", Vector3.ONE * 3.8 * k * v("imp_anillo"), dur * 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		twa.tween_method(func(a: float) -> void: (anillo.material_override as ShaderMaterial).set_shader_parameter("alfa", a), 1.0, 0.0, dur * 0.65)
	# 3. Lenguas de llama en estrella (Pablo, 20:04: en vez del impacto con llamas, un glim sutil con chispas y la onda → por defecto 0; el slider las devuelve) (quads que se cruzan), a la altura del suelo.
	var n_l: int = int(v("imp_lenguas"))
	for i in range(n_l):
		var pivote := Node3D.new()
		pivote.rotation.y = float(i) / float(maxi(n_l, 1)) * PI + randf_range(-0.15, 0.15)
		pivote.position = Vector3(0.0, rel_suelo + 0.02, 0.0)
		raiz.add_child(pivote)
		var alto: float = randf_range(1.0, 1.7) * k
		var ancho: float = randf_range(0.8, 1.2) * k
		var mat: ShaderMaterial = VfxKit3D.material({"erosion": 0.4, "brillo": 1.1, "calor_max": 1.0, "ondula": 0.06, "ondula_freq": 8.0, "escala_ruido": Vector2(0.6, 0.45), "velocidad": Vector2(0.0, 1.5), "fase": randf(), "fade": 0.0}, "fuego")
		var mi: MeshInstance3D = VfxKit3D._malla(pivote, VfxKit3D._quad(Vector2(ancho, alto)), mat)
		mi.position.x = randf_range(-0.12, 0.12) * k
		mi.rotation.z = randf_range(-0.45, 0.45)
		pivote.scale = Vector3(1.0, 0.15, 1.0)
		var tw := pivote.create_tween()
		tw.tween_property(pivote, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		VfxKit3D._param(tw, mat, "fade", 0.0, 1.0, 0.1)
		var tw2 := pivote.create_tween()
		tw2.tween_interval(dur * 0.45)
		VfxKit3D._param(tw2, mat, "fade", 1.0, 0.0, dur * 0.55)
	# 4. Brasas y chispas que SALEN DEL PUNTO DE IMPACTO HACIA AFUERA (casi esféricas: 100° de abanico, poca gravedad) (puntos aditivos que salen en abanico y caen) y chispas alargadas.
	var vel: float = v("imp_vel")
	if v("imp_brasas") > 0.0:
		VfxKit3D.particulas(raiz, Vector3(0.0, 0.1, 0.0), int(v("imp_brasas")), 1.1 * (0.6 + 0.4 * dur), 0.12 * k, vel, false, false, 0.2 * k, -1.0, Vector3.UP, 100.0)
	if v("imp_chispas") > 0.0:
		VfxKit3D.particulas(raiz, Vector3(0.0, 0.1, 0.0), int(v("imp_chispas")), 0.9, 0.1 * k, vel * 1.4, true, false, 0.15 * k, -1.5, Vector3.UP, 100.0)
	# 5. Humo que sube tras el estallido.
	if v("imp_humo") > 0.0:
		_humo(raiz, int(v("imp_humo")), Vector3(0.0, 0.15, 0.0), 0.35 * k, 1.0 * k, dur + 0.9, 0.85 * k, 0.32)
	# 6. Luz.
	if v("imp_luz") > 0.0:
		_luz_que_cae(raiz, Vector3(0.0, 0.5, 0.0), v("imp_luz") * k, 4.0 * k, dur)
	# 7. Chamusco en el suelo (se queda ~10 s y se desvanece solo).
	if v("imp_marca") > 0.5:
		VfxKit3D.chamusco(mundo as Node3D, Vector3(pos.x, y_suelo, pos.z), 0.6 * k, 10.0)
	VfxKit3D.elemento = antes
	return raiz


## --- FIN (se agota sin chocar) ---

## El proyectil se acaba en el aire (alcance, tiempo o frenado): un fogonazo pequeño, brasas que se dispersan hacia arriba y un hilo de humo.
static func desvanecer(mundo: Node, pos: Vector3, esc: float = 1.0) -> Node3D:
	var k: float = lerpf(1.0, esc, v("imp_con_tamano")) * v("imp_escala")
	var dur: float = v("fin_dur")
	var antes: String = VfxKit3D.elemento
	VfxKit3D.elemento = "fuego"
	var raiz: Node3D = _raiz(mundo, "FinFuego", pos, dur + 1.4)
	if v("fin_fogonazo") > 0.0:
		_fogonazo(raiz, Vector3.ZERO, 0.28 * k * v("fin_fogonazo"), 1.8, dur * 0.5)
	if v("fin_brasas") > 0.0:
		VfxKit3D.particulas(raiz, Vector3.ZERO, int(v("fin_brasas")), dur + 0.3, 0.09 * k, 1.1, false, false, 0.18 * k, 0.4, Vector3.UP, 150.0)
	if v("fin_humo") > 0.0:
		_humo(raiz, int(v("fin_humo")), Vector3.ZERO, 0.15 * k, 0.7 * k, dur + 0.7, 0.5 * k, 0.22)
	_luz_que_cae(raiz, Vector3.ZERO, 1.2 * k, 2.4 * k, dur * 0.7)
	VfxKit3D.elemento = antes
	return raiz


## --- CARGA ---

## Pone a punto las chispas que convergen a la mano (las crea `ConjuroVfx3D._chispas_convergentes`) para que se vayan AGLUTINANDO: la cantidad sube de `carga_n_ini` a
## `carga_n_fin` en `carga_rampa_s` (se usa `amount_ratio`, que no reinicia la emisión) y la luz de la mano sube con ella.
## La bola de la mano NACE de un punto y crece hasta su tamaño (Pablo, 20:27: «que tenga un origen»): empieza en `carga_bola_ini` y llega a 1 en `carga_bola_s` (suave al final: se asienta).
## Devuelve los segundos que dura, para que quien la haga latir espere a que llegue.
static func crecer_bola(bola: Node3D) -> float:
	var dur: float = maxf(v("carga_bola_s"), 0.05)
	bola.scale = Vector3.ONE * v("carga_bola_ini")
	var tw := bola.create_tween()
	tw.tween_property(bola, "scale", Vector3.ONE, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)       # cuadrática: crece a ritmo visible casi hasta el final (la cúbica llegaba al 96 % a los 0,3 s y no se apreciaba)
	return dur


static func montar_carga(chispas: GPUParticles3D, luz: OmniLight3D) -> void:
	var n_fin: int = int(v("carga_n_fin"))
	var n_ini: int = int(v("carga_n_ini"))
	chispas.amount = maxi(n_fin, 1)
	chispas.amount_ratio = clampf(float(n_ini) / float(maxi(n_fin, 1)), 0.01, 1.0)
	var tw := chispas.create_tween()
	tw.tween_property(chispas, "amount_ratio", 1.0, maxf(v("carga_rampa_s"), 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if luz != null:
		luz.light_energy = 0.0
		var twl := luz.create_tween()
		twl.tween_property(luz, "light_energy", v("carga_luz"), maxf(v("carga_rampa_s"), 0.05))


## El bucle de sonido de la carga: arranca bajo y grave y SUBE de tono y de volumen en `carga_rampa_s`. Devuelve el reproductor (null si está apagado o no hay audio) para
## pararlo con `Sfx.parar` al soltar el hechizo.
static func sonido_carga(desde: Node) -> Node:
	if v("snd_activo") < 0.5:
		return null
	var p: Node = Sfx.bucle(desde, "fuego_carga_bucle", v("snd_tono_ini"))
	if p == null:
		return null
	var db_fin: float = v("snd_db")
	p.set("volume_db", db_fin - 10.0)
	var tw := p.create_tween().set_parallel(true)
	var d: float = maxf(v("carga_rampa_s"), 0.05)
	tw.tween_property(p, "pitch_scale", v("snd_tono_fin"), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "volume_db", db_fin, d)
	p.set_meta("tween_bucle", tw)                       # `Sfx.parar` lo cancela antes de fundir
	return p

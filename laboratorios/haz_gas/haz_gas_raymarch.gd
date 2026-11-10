class_name HazGasRaymarch
extends CompositorEffect

## PORT A GODOT de src/render/volume.js + la cadena de post de src/main.js (lejrimostfa/force-field-vfx-threejs, MIT; aviso en laboratorios/haz_gas/LICENSE_force_field_vfx.txt).
## Es un CompositorEffect en POST_TRANSPARENT (Forward+): corre en el hilo de render DESPUÉS de lo opaco y lo transparente (suelo, muro, chispas) y ANTES del glow y el tonemap,
## igual que la demo compone el volumen sobre su pase de escena y luego hace bloom. Pasadas (compute, como la demo):
##   1. raymarch a media resolución (q.march) → «crudo» (rgb luz, a transmitancia). Corta en la caja del dominio y en la PROFUNDIDAD de la escena.
##   2. filtro temporal (historia recortada al 3x3) → «salida»;  3. copia salida → historia.
##   4. composición a resolución completa sobre el color de la escena: escena · a + rgb, saturación 1,3 y viñeta.
## Se cuelga de la cámara con un Compositor (HazGas lo pone en la cámara activa). Lee las texturas del HazGasSolver (mismo RenderingDevice).

var solver: HazGasSolver = null
var mundo_a_dominio: Transform3D = Transform3D.IDENTITY
var proyeccion: Projection = Projection.ZERO           ## Camera3D.get_camera_projection() de la cámara activa (la pone HazGas cada fotograma)
var camara: Transform3D = Transform3D.IDENTITY
## thickness, relief, edge, smokeAlbedo, flameBody, emitGain, fireOnSmoke, farOnSmoke, lampOnSmoke, saturación, viñeta (params.js + main.js)
var aspecto: PackedFloat32Array = PackedFloat32Array([0.75, 0.7, 0.35, 0.3, 5.0, 6.5, 2.2, 1.6, 720.0, 1.3, 1.0])
var temporal: bool = true
var con_profundidad: bool = true
var medir: bool = true
var depurar: bool = false
## MODO TOON (raymarch_toon.glsl): el dibujo con el lenguaje de FuegoToy. toon_param = [umbral, blandura, contraste, tope, k_T, k_c, amplitud, escala, umbral_humo,
## opacidad_humo, escala_rampa, tiempo, sube, chisporroteo, profundidad_color, -]; toon_tex = RIDs de RenderingDevice de [lenguas, ruido_a, ruido_fino, rampa] (los pone HazGas).
var toon: bool = false
var toon_param: PackedFloat32Array = PackedFloat32Array()
var toon_tex: Array[RID] = []
## MODO AGUA (10/11): con toon, el dibujo es raymarch_toon_agua.glsl (lenguaje del AguaToy) con las mismas ataduras; toon_tex = [T_Noise_W5i, T_Noise_Wo14, T_Noise_Wf4, paleta de AguaPaleta].
var agua: bool = false
var _muestreo_repite: RID

var _rd: RenderingDevice = null
var _sh: Dictionary = {}
var _vista_ubo: RID
var _tam_vol: Vector2i = Vector2i.ZERO
var _crudo: RID
var _salida: RID
var _historia: RID
var _muestreo: RID
var _muestreo_cercano: RID
var _fotograma: int = 0
var _listo: bool = false


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	RenderingServer.call_on_render_thread(_crear)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		for t in [_crudo, _salida, _historia, _vista_ubo, _muestreo, _muestreo_cercano, _muestreo_repite]:
			if t.is_valid():
				_rd.free_rid(t)
		for n in _sh:
			if not String(n).ends_with("_pl"):          # el pipeline se libera con su shader
				_rd.free_rid(_sh[n])


func _crear() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	for n in ["raymarch", "raymarch_toon", "raymarch_toon_agua", "temporal", "compone"]:
		var sp: RDShaderSPIRV = HazGasSolver.spirv(_rd, n)
		if sp.compile_error_compute != "" or sp.bytecode_compute.is_empty():
			push_error("HazGasRaymarch: %s.glsl no compila:\n%s" % [n, sp.compile_error_compute])
			return
		_sh[n] = _rd.shader_create_from_spirv(sp, n)
		_sh[n + "_pl"] = _rd.compute_pipeline_create(_sh[n])
	_vista_ubo = _rd.uniform_buffer_create(16 * 4 + 16 * 9)
	var s: RDSamplerState = RDSamplerState.new()
	s.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_muestreo = _rd.sampler_create(s)
	var sc: RDSamplerState = RDSamplerState.new()
	_muestreo_cercano = _rd.sampler_create(sc)
	var sr: RDSamplerState = RDSamplerState.new()
	sr.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sr.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sr.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sr.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	_muestreo_repite = _rd.sampler_create(sr)
	_listo = true


func _objetivo(tam: Vector2i) -> RID:
	var f: RDTextureFormat = RDTextureFormat.new()
	f.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	f.width = tam.x
	f.height = tam.y
	f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var t: RID = _rd.texture_create(f, RDTextureView.new(), [])
	_rd.texture_clear(t, Color(0, 0, 0, 1), 0, 1, 0, 1)
	return t


func _render_callback(_tipo: int, render_data: RenderData) -> void:
	if not _listo or solver == null or not solver.valido:
		return
	var rsb: RenderSceneBuffersRD = render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var sd: RenderSceneDataRD = render_data.get_render_scene_data() as RenderSceneDataRD
	if rsb == null or sd == null:
		return
	var tam: Vector2i = rsb.get_internal_size()
	if tam.x <= 0 or tam.y <= 0:
		return
	var march: float = float(solver.calidad["march"])
	var tv: Vector2i = Vector2i(ceili(tam.x * march / 8.0) * 8, ceili(tam.y * march / 8.0) * 8)
	if tv != _tam_vol:
		for t in [_crudo, _salida, _historia]:
			if t.is_valid():
				_rd.free_rid(t)
		_crudo = _objetivo(tv)
		_salida = _objetivo(tv)
		_historia = _objetivo(tv)
		_tam_vol = tv
	# Inversa de vista-proyección, llevada al DOMINIO: NDC de OpenGL → vista → mundo → dominio. La proyección y la cámara las pone HazGas desde la Camera3D
	# activa (get_camera_projection, convención OpenGL). La de RenderSceneDataRD ya trae la corrección de profundidad de Vulkan y con la cámara
	# ortográfica del juego daba rayos equivocados; se usa solo si no hay otra.
	var proj: Projection = proyeccion if proyeccion != Projection.ZERO else sd.get_cam_projection()
	var cam: Transform3D = camara if proyeccion != Projection.ZERO else sd.get_cam_transform()
	var inv: Projection = Projection(mundo_a_dominio * cam) * proj.inverse()
	var v: PackedFloat32Array = PackedFloat32Array()
	for c in 4:
		var col: Vector4 = inv[c]
		v.append_array([col.x, col.y, col.z, col.w])
	v.append_array([tv.x, tv.y, tam.x, tam.y])
	var es_toon: bool = toon and toon_tex.size() == 4 and toon_param.size() == 16
	v.append_array([float(solver.calidad["steps"]) * (1.5 if es_toon else 1.0), float(_fotograma % 64) if temporal and not es_toon else 0.0, 1.0 if con_profundidad else 0.0, 1.0 if depurar else 0.0])
	v.append_array(aspecto.slice(0, 4))
	v.append_array(aspecto.slice(4, 8))
	v.append_array([aspecto[8], aspecto[9], aspecto[10], 0.0])
	if toon_param.size() == 16:
		v.append_array(toon_param)
	else:
		var ceros: PackedFloat32Array = PackedFloat32Array()
		ceros.resize(16)
		v.append_array(ceros)
	_rd.buffer_update(_vista_ubo, 0, v.size() * 4, v.to_byte_array())
	_fotograma += 1

	var color: RID = rsb.get_color_layer(0)
	var profundidad: RID = rsb.get_depth_layer(0)
	if medir:
		_rd.capture_timestamp("vol_ini")
	# 1. raymarch
	var u_gas: Array = [_s(0, solver.gas[0], _muestreo), _s(1, solver.luz[0], _muestreo), _s(2, solver.luz_lejos[0], _muestreo), _s(3, solver.clave, _muestreo),
		_s(4, profundidad, _muestreo_cercano), _i(5, _crudo)]
	var pc_r: PackedByteArray = PackedByteArray()          # el bloque «Rejilla» de gas_comun (no se usa aquí, pero el pipeline lo declara)
	pc_r.resize(32)
	if es_toon:
		var u_t: Array = [_s(0, solver.gas[0], _muestreo), _s(1, solver.vel[0], _muestreo), _s(2, profundidad, _muestreo_cercano), _s(3, toon_tex[0], _muestreo_repite),
			_s(4, toon_tex[1], _muestreo_repite), _s(5, toon_tex[2], _muestreo_repite), _s(6, toon_tex[3], _muestreo), _i(7, _crudo)]
		_despacha("raymarch_toon_agua" if agua else "raymarch_toon", [u_t, [_ubo(0, solver.ubo)], [_ubo(0, _vista_ubo)]], Vector3i(ceili(tv.x / 8.0), ceili(tv.y / 8.0), 1), pc_r)
	else:
		_despacha("raymarch", [u_gas, [_ubo(0, solver.ubo)], [_ubo(0, _vista_ubo)]], Vector3i(ceili(tv.x / 8.0), ceili(tv.y / 8.0), 1), pc_r)
	var fuente: RID = _crudo
	if temporal and not es_toon:          # el toon no lleva ruido de marcha (sin desfase IGN): sin filtro temporal, el borde queda nítido
		# 2-3. resolve y copia
		var ut: Array = [_i(0, _crudo), _i(1, _historia), _i(2, _salida)]
		var pc: PackedByteArray = PackedByteArray()
		pc.resize(16)
		pc.encode_s32(0, tv.x)
		pc.encode_s32(4, tv.y)
		pc.encode_s32(8, 0)
		_despacha("temporal", [ut], Vector3i(ceili(tv.x / 8.0), ceili(tv.y / 8.0), 1), pc)
		pc.encode_s32(8, 1)
		_despacha("temporal", [ut], Vector3i(ceili(tv.x / 8.0), ceili(tv.y / 8.0), 1), pc)
		fuente = _salida
	# 4. composición sobre la escena
	_despacha("compone", [[_s(0, fuente, _muestreo), _i(1, color)], [_ubo(0, _vista_ubo)]], Vector3i(ceili(tam.x / 8.0), ceili(tam.y / 8.0), 1), PackedByteArray())
	if medir:
		_rd.capture_timestamp("vol_fin")


func _despacha(nombre: String, sets: Array, grupos: Vector3i, pc: PackedByteArray) -> void:
	var sh: RID = _sh[nombre]
	var cl: int = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _sh[nombre + "_pl"])
	for i in sets.size():
		_rd.compute_list_bind_uniform_set(cl, UniformSetCacheRD.get_cache(sh, i, sets[i]), i)
	if pc.size() > 0:
		_rd.compute_list_set_push_constant(cl, pc, pc.size())
	_rd.compute_list_dispatch(cl, grupos.x, grupos.y, grupos.z)
	_rd.compute_list_end()


func _s(binding: int, t: RID, m: RID) -> RDUniform:
	var u: RDUniform = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(m)
	u.add_id(t)
	return u


func _i(binding: int, t: RID) -> RDUniform:
	var u: RDUniform = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(t)
	return u


func _ubo(binding: int, b: RID) -> RDUniform:
	var u: RDUniform = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u.binding = binding
	u.add_id(b)
	return u

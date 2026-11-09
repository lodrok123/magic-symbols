class_name HazGasSolver
extends RefCounted

## PORT A GODOT de lejrimostfa/force-field-vfx-threejs (MIT, Copyright (c) 2026 lejrimostfa; aviso en laboratorios/haz_gas/LICENSE_force_field_vfx.txt).
## Junta src/gas/fields.js (texturas), grid.js (rejillas y despacho 4x4x4), solver.js (la cadena de pasadas), light.js (campos de luz) y render/sparks.js (estado de chispas).
## Todo vive en el RenderingDevice PRINCIPAL (RenderingServer.get_rendering_device()) para que los materiales y el CompositorEffect lean las mismas texturas
## (Texture3DRD / Texture2DRD). TODAS las llamadas a este objeto han de ir en el hilo de render (RenderingServer.call_on_render_thread): lo hace HazGas.
## Sin ventana (--headless) no hay RenderingDevice: `valido` queda en false y todo es no-op.
##
## La cadena empieza y acaba en el índice 0 de cada pareja (como solver.js): no se cambia ninguna textura de sitio ni se rehace ningún uniform set.
##   gas:       avanza (vel0, gas0 → tmp) · corrige (gas0, tmp → gas1) · fuentes (gas1 → gas0)
##   velocidad: advecta (vel0 → vel1) · fuentes (gas0, vel1 → vel0) · rizo (vel0 → curl) · confina (curl, gas0, vel0 → vel1) · divergencia (vel1, prs0 → prs1)
##              · jacobi ×N (prs1 ↔ prs0) · una más (prs1 → prs0) · proyecta (vel1, prs0 → vel0)
##   luz:       clave (gas0 → keyT) · 6 × (difunde luz0 → luz1 → luz0) · 6 × (lejos far0 → far1 → far0)
##   chispas:   1 pasada sobre la imagen de estado (N x 2)

const WORLD_MIN: Vector3 = Vector3(-12, 0, -6)       ## config.js WORLD: el suelo es y = 0 y z = -6 el acantilado
const WORLD_SIZE: Vector3 = Vector3(24, 12, 12)
const DT: float = 1.0 / 60.0
## config.js QUALITY (res de la rejilla de gas, iteraciones de Jacobi, pasos del raymarch y escala de su resolución)
const CALIDADES: Dictionary = {
	"low": {"res": Vector3i(128, 64, 64), "jacobi": 16, "steps": 48, "march": 0.5},
	"med": {"res": Vector3i(192, 96, 96), "jacobi": 24, "steps": 64, "march": 0.5},
	"high": {"res": Vector3i(256, 128, 128), "jacobi": 32, "steps": 96, "march": 0.75},
	"ultra": {"res": Vector3i(320, 160, 160), "jacobi": 40, "steps": 128, "march": 1.0},
}
const N_CHISPAS: int = 1000
const DIR_SH: String = "res://laboratorios/haz_gas/shaders/"
const FLUJO_BIN: String = "res://laboratorios/haz_gas/flujo_48.bin"

var rd: RenderingDevice = null
var valido: bool = false
var nombre_calidad: String = "low"
var calidad: Dictionary = {}
var res: Vector3i = Vector3i.ZERO
var celdas: int = 0

# Campos (fields.js). vel, prs y curl a media resolución; luz a un cuarto; luz_lejos a un octavo; clave a media.
var vel: Array[RID] = [RID(), RID()]
var gas: Array[RID] = [RID(), RID()]
var gas_tmp: RID
var prs: Array[RID] = [RID(), RID()]
var curl: RID
var luz: Array[RID] = [RID(), RID()]
var luz_lejos: Array[RID] = [RID(), RID()]
var clave: RID
var ruido: RID
var flujo: RID
var chispas: RID                       ## rgba32f N x 2
var residuo: RID                       ## solo para la prueba
var ubo: RID                           ## Parametros (gas_comun.glslinc)
var muestreo_lineal: RID
var muestreo_repite: RID
var muestreo_cercano: RID

var _shaders: Dictionary = {}          ## nombre -> {shader, pipeline, set_ubo}
var _gas_pasos: Array = []
var _vel_pasos: Array = []
var _luz_pasos: Array = []
var _chispas_pasos: Array = []
var _residuo_paso: Dictionary = {}
var _todas: Array[RID] = []
var pasos_dados: int = 0


## jacobi: si es > 0, cambia las iteraciones de Jacobi de la calidad (solo para la prueba de convergencia de la proyección).
func _init(calidad_nombre: String = "low", jacobi: int = 0) -> void:
	nombre_calidad = calidad_nombre if CALIDADES.has(calidad_nombre) else "low"
	calidad = (CALIDADES[nombre_calidad] as Dictionary).duplicate()
	if jacobi > 0:
		calidad["jacobi"] = jacobi
	res = calidad["res"]
	celdas = res.x * res.y * res.z


## Crea texturas, shaders y la cadena. En el hilo de render.
func crear() -> bool:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_warning("HazGasSolver: no hay RenderingDevice (¿--headless?). El gas necesita ventana.")
		return false
	var half: Vector3i = res / 2
	var quarter: Vector3i = res / 4
	var eighth: Vector3i = res / 8
	var f16: int = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	var f32: int = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	for i in 2:
		vel[i] = _tex3d(half, f16)
		gas[i] = _tex3d(res, f16)
		prs[i] = _tex3d(half, f32)
		luz[i] = _tex3d(quarter, f16)
		luz_lejos[i] = _tex3d(eighth, f16)
	gas_tmp = _tex3d(res, f16)
	curl = _tex3d(half, f16)
	clave = _tex3d(half, f16)
	residuo = _tex3d(half, f32)
	ruido = _tex3d(Vector3i(32, 32, 32), RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, _datos_ruido())
	var fl: PackedByteArray = FileAccess.get_file_as_bytes(FLUJO_BIN)
	if fl.size() != 48 * 48 * 48 * 4:
		push_error("HazGasSolver: falta %s (herramientas/hornear_haz_gas.gd)" % FLUJO_BIN)
		return false
	flujo = _tex3d(Vector3i(48, 48, 48), RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, fl)
	chispas = _tex2d(Vector2i(N_CHISPAS, 2), f32, _datos_chispas())
	for t in [vel[0], vel[1], gas[0], gas[1], gas_tmp, prs[0], prs[1], curl, luz[0], luz[1], luz_lejos[0], luz_lejos[1], clave, residuo]:
		rd.texture_clear(t, Color(0, 0, 0, 0), 0, 1, 0, 1)
	rd.texture_clear(clave, Color(1, 0, 0, 1), 0, 1, 0, 1)
	muestreo_lineal = _muestreo(RenderingDevice.SAMPLER_FILTER_LINEAR, RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE)
	muestreo_repite = _muestreo(RenderingDevice.SAMPLER_FILTER_LINEAR, RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT)
	muestreo_cercano = _muestreo(RenderingDevice.SAMPLER_FILTER_NEAREST, RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE)
	ubo = rd.uniform_buffer_create(16 * 16)
	_todas.append(ubo)
	for n in ["gas_avanza", "gas_corrige", "gas_fuentes", "vel_advecta", "vel_fuentes", "rizo", "confina", "divergencia", "jacobi", "proyecta",
			"luz_difunde", "luz_lejos", "luz_clave", "chispas", "residuo"]:
		if not _cargar(n):
			return false
	_montar_cadena(half, quarter, eighth)
	valido = true
	return true


func _montar_cadena(half: Vector3i, quarter: Vector3i, eighth: Vector3i) -> void:
	# gas (resolución completa)
	_gas_pasos = [
		_paso("gas_avanza", [_s(0, vel[0]), _s(1, gas[0]), _s(2, flujo, true), _i(3, gas_tmp)], res),
		_paso("gas_corrige", [_s(0, vel[0]), _s(1, gas[0]), _s(2, gas_tmp), _s(3, flujo, true), _i(4, gas[1])], res),
		_paso("gas_fuentes", [_s(0, gas[1]), _s(1, vel[0]), _s(2, ruido, true), _i(3, gas[0])], res),
	]
	# velocidad y presión (media resolución)
	_vel_pasos = [
		_paso("vel_advecta", [_s(0, vel[0]), _i(1, vel[1])], half),
		_paso("vel_fuentes", [_s(0, vel[1]), _s(1, gas[0]), _s(2, ruido, true), _i(3, vel[0])], half),
		_paso("rizo", [_s(0, vel[0]), _i(1, curl)], half),
		_paso("confina", [_s(0, curl), _s(1, gas[0]), _s(2, vel[0]), _s(3, flujo, true), _i(4, vel[1])], half),
		_paso("divergencia", [_s(0, vel[1]), _s(1, prs[0]), _i(2, prs[1])], half),
	]
	var impar: Dictionary = _paso("jacobi", [_s(0, prs[1]), _i(1, prs[0])], half)
	var par: Dictionary = _paso("jacobi", [_s(0, prs[0]), _i(1, prs[1])], half)
	for i in range(0, int(calidad["jacobi"]), 2):
		_vel_pasos.append(impar)
		_vel_pasos.append(par)
	# El bucle deja la presión nueva en prs1. Una pasada más la lleva a prs0 para proyectar y para el arranque en caliente del paso siguiente.
	_vel_pasos.append(impar)
	_vel_pasos.append(_paso("proyecta", [_s(0, vel[1]), _s(1, prs[0]), _i(2, vel[0])], half))
	# luz (light.js)
	_luz_pasos = [_paso("luz_clave", [_s(0, gas[0]), _i(1, clave)], half)]
	var a: Dictionary = _paso("luz_difunde", [_s(0, gas[0]), _s(1, luz[0]), _i(2, luz[1])], quarter)
	var b: Dictionary = _paso("luz_difunde", [_s(0, gas[0]), _s(1, luz[1]), _i(2, luz[0])], quarter)
	for i in 6:
		_luz_pasos.append(a)
		_luz_pasos.append(b)
	var c: Dictionary = _paso("luz_lejos", [_s(0, luz[0]), _s(1, luz_lejos[0]), _i(2, luz_lejos[1])], eighth)
	var d: Dictionary = _paso("luz_lejos", [_s(0, luz[0]), _s(1, luz_lejos[1]), _i(2, luz_lejos[0])], eighth)
	for i in 6:
		_luz_pasos.append(c)
		_luz_pasos.append(d)
	# chispas: una invocación por chispa, grupos de 64
	var pc: Dictionary = _paso("chispas", [_s(0, vel[0]), _i(1, chispas)], Vector3i(N_CHISPAS, 1, 1))
	pc["grupos"] = Vector3i(ceili(N_CHISPAS / 64.0), 1, 1)
	_chispas_pasos = [pc]
	_residuo_paso = _paso("residuo", [_s(0, vel[0]), _s(1, vel[1]), _i(2, residuo)], half)


## Un paso de simulación (DT = 1/60 s) más luz y chispas, como simulate() de main.js (sin el raymarch, que va en HazGasRaymarch).
func paso(parametros: PackedFloat32Array, medir: bool = true, con_luz: bool = true) -> void:
	if not valido:
		return
	rd.buffer_update(ubo, 0, parametros.size() * 4, parametros.to_byte_array())
	if medir:
		rd.capture_timestamp("gas_ini")
	_correr(_gas_pasos)
	if medir:
		rd.capture_timestamp("gas_fin")
	_correr(_vel_pasos)
	if medir:
		rd.capture_timestamp("vel_fin")
	if con_luz:
		_correr(_luz_pasos)
	if medir:
		rd.capture_timestamp("luz_fin")
	_correr(_chispas_pasos)
	if medir:
		rd.capture_timestamp("chispas_fin")
	pasos_dados += 1


## Solo luz y chispas (para volver a dibujar el mismo estado, p. ej. con la simulación en pausa).
func solo_parametros(parametros: PackedFloat32Array) -> void:
	if valido:
		rd.buffer_update(ubo, 0, parametros.size() * 4, parametros.to_byte_array())


func calcular_residuo() -> void:
	if valido:
		_correr([_residuo_paso])


func _correr(lista: Array) -> void:
	for p in lista:
		var cl: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, p["pipeline"])
		rd.compute_list_bind_uniform_set(cl, p["set0"], 0)
		rd.compute_list_bind_uniform_set(cl, p["set1"], 1)
		var pcb: PackedByteArray = p["pc"]
		rd.compute_list_set_push_constant(cl, pcb, pcb.size())
		var g: Vector3i = p["grupos"]
		rd.compute_list_dispatch(cl, g.x, g.y, g.z)
		rd.compute_list_end()


## Lee una textura entera (para la prueba). Bloquea: solo en pruebas.
func leer(t: RID) -> PackedByteArray:
	if not valido:
		return PackedByteArray()
	return rd.texture_get_data(t, 0)


## Tiempos de GPU del último fotograma medido, en ms: {gas, velocidad, luz, chispas, volumen, total}. Vacío si el driver no da marcas.
func tiempos_gpu() -> Dictionary:
	if not valido:
		return {}
	var marcas: Dictionary = {}
	for i in rd.get_captured_timestamps_count():
		marcas[rd.get_captured_timestamp_name(i)] = rd.get_captured_timestamp_gpu_time(i)
	var r: Dictionary = {}
	var par: Array = [["gas", "gas_ini", "gas_fin"], ["velocidad", "gas_fin", "vel_fin"], ["luz", "vel_fin", "luz_fin"], ["chispas", "luz_fin", "chispas_fin"], ["volumen", "vol_ini", "vol_fin"]]
	var total: float = 0.0
	for p in par:
		if marcas.has(p[1]) and marcas.has(p[2]):
			var ms: float = float(int(marcas[p[2]]) - int(marcas[p[1]])) / 1.0e6
			r[p[0]] = ms
			total += ms
	if not r.is_empty():
		r["total"] = total
	return r


func liberar() -> void:
	if rd == null:
		return
	for t in _todas:
		if t.is_valid():
			rd.free_rid(t)
	_todas.clear()
	for n in _shaders:
		rd.free_rid(_shaders[n]["shader"])          # libera también su pipeline y sus uniform sets
	_shaders.clear()
	valido = false


# ------------------------------------------------------------------------------------------------------------------------------------------------

func _tex3d(tam: Vector3i, formato: int, datos: PackedByteArray = PackedByteArray()) -> RID:
	var f: RDTextureFormat = RDTextureFormat.new()
	f.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	f.format = formato
	f.width = tam.x
	f.height = tam.y
	f.depth = tam.z
	f.usage_bits = (RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT)
	if formato == RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM:
		f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var t: RID = rd.texture_create(f, RDTextureView.new(), [datos] if datos.size() > 0 else [])
	_todas.append(t)
	return t


func _tex2d(tam: Vector2i, formato: int, datos: PackedByteArray) -> RID:
	var f: RDTextureFormat = RDTextureFormat.new()
	f.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	f.format = formato
	f.width = tam.x
	f.height = tam.y
	f.usage_bits = (RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
	var t: RID = rd.texture_create(f, RDTextureView.new(), [datos])
	_todas.append(t)
	return t


func _muestreo(filtro: int, repite: int) -> RID:
	var s: RDSamplerState = RDSamplerState.new()
	s.min_filter = filtro
	s.mag_filter = filtro
	s.repeat_u = repite
	s.repeat_v = repite
	s.repeat_w = repite
	var r: RID = rd.sampler_create(s)
	_todas.append(r)
	return r


## fields.js noiseField(32): ruido de valor que se repite (celdas aleatorias + filtro trilineal). seed 12345, byte = seed >>> 24.
func _datos_ruido(size: int = 32) -> PackedByteArray:
	var d: PackedByteArray = PackedByteArray()
	d.resize(size * size * size * 4)
	var seed: int = 12345
	for i in d.size():
		seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
		d[i] = seed >> 24
	return d


## sparks.js: primeras vidas escalonadas y aparcadas bajo el suelo; entran una a una en vez de reventar todas en el fotograma 0.
func _datos_chispas() -> PackedByteArray:
	var f: PackedFloat32Array = PackedFloat32Array()
	f.resize(N_CHISPAS * 2 * 4)
	for i in N_CHISPAS:
		f[i * 4 + 1] = -10.0
		f[i * 4 + 3] = float(i) / float(N_CHISPAS) * 2.3
	return f.to_byte_array()


## SPIR-V de un compute shader de DIR_SH. Se compila desde el TEXTO (con los #include expandidos aquí): el importador de Godot no vuelve a compilar un .glsl
## cuando solo cambia un .glslinc que incluye (mira el md5 del .glsl), y se quedaban versiones viejas. Si no se puede leer el texto (exportado), el importado.
static func spirv(r: RenderingDevice, nombre: String) -> RDShaderSPIRV:
	var texto: String = FileAccess.get_file_as_string(DIR_SH + nombre + ".glsl")
	if texto != "" and r != null:
		var fuente: RDShaderSource = RDShaderSource.new()
		fuente.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		fuente.source_compute = _expandir(texto.replace("#[compute]", ""))
		var sp: RDShaderSPIRV = r.shader_compile_spirv_from_source(fuente, false)
		if sp.compile_error_compute == "":
			return sp
		push_error("HazGas: %s.glsl no compila desde el texto:\n%s" % [nombre, sp.compile_error_compute])
	var sf: RDShaderFile = load(DIR_SH + nombre + ".glsl") as RDShaderFile
	return sf.get_spirv() if sf != null else RDShaderSPIRV.new()


static func _expandir(texto: String) -> String:
	var r: PackedStringArray = PackedStringArray()
	for linea in texto.split("\n"):
		var l: String = linea.strip_edges()
		if l.begins_with("#include \""):
			var inc: String = l.trim_prefix("#include \"").trim_suffix("\"")
			r.append(_expandir(FileAccess.get_file_as_string(DIR_SH + inc)))
		else:
			r.append(linea)
	return "\n".join(r)


func _cargar(nombre: String) -> bool:
	var sp: RDShaderSPIRV = spirv(rd, nombre)
	if sp.compile_error_compute != "" or sp.bytecode_compute.is_empty():
		push_error("HazGasSolver: %s.glsl no compila:\n%s" % [nombre, sp.compile_error_compute])
		return false
	var sh: RID = rd.shader_create_from_spirv(sp, nombre)
	var pl: RID = rd.compute_pipeline_create(sh)
	var u: RDUniform = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u.binding = 0
	u.add_id(ubo)
	var su: RID = rd.uniform_set_create([u], sh, 1)
	_shaders[nombre] = {"shader": sh, "pipeline": pl, "set_ubo": su}
	return true


func _s(binding: int, t: RID, repite: bool = false) -> RDUniform:
	var u: RDUniform = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(muestreo_repite if repite else muestreo_lineal)
	u.add_id(t)
	return u


func _i(binding: int, t: RID) -> RDUniform:
	var u: RDUniform = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(t)
	return u


func _paso(nombre: String, uniformes: Array, tam: Vector3i) -> Dictionary:
	var sh: Dictionary = _shaders[nombre]
	var pc: PackedByteArray = PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, tam.x)
	pc.encode_s32(4, tam.y)
	pc.encode_s32(8, tam.z)
	pc.encode_float(16, WORLD_SIZE.x / float(tam.x))
	return {"pipeline": sh["pipeline"], "set0": rd.uniform_set_create(uniformes, sh["shader"], 0), "set1": sh["set_ubo"], "pc": pc,
		"grupos": Vector3i(ceili(tam.x / 4.0), ceili(tam.y / 4.0), ceili(tam.z / 4.0))}

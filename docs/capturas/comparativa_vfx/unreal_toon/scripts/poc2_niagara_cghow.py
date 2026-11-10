# Prueba 2 (fuego toon), segunda técnica: NS_MuroFuegoToon según el tutorial de CGHOW (vídeo 2A4AMI-SHIQ) adaptado a
# ref_muro.jpg. Todo son sprites (sin malla): capa «Lenguas» (rampa de tres tonos, lenguas más anchas que altas, solapadas
# a distintas profundidades), capa «Base» (el equivalente toon de la capa aditiva del tutorial: franja baja crema, ondulada
# y brillante), humo gris escaso, chispas pequeñas y una sola luz. Paso fijo de 1/12 s en toda la simulación.
# Del tutorial: nacen en una caja fina sin gravedad (10), vida corta (11), curva de tamaño que crece rápido y se mantiene
# (12), alfa por vida en vez de color a negro (13, adaptado), densidad aleatoria por partícula vía DynamicMaterialParameter
# (15), dos capas (16). La alineación a la velocidad (14) se cambia por eje vertical fijo: las lenguas de la referencia
# son anchas, no estiradas.
import sys, random, unreal as ue
sys.path.append(ue.Paths.project_dir() + "Scripts")
import importlib, poc_niagara as pn
importlib.reload(pn)
from poc_niagara import *

pn.CARPETA = "/Game/POC2/VFX"
MATS = "/Game/POC2/Materiales/"
MI_BASE = MATS + "MI_FuegoToon_Cuerpo.MI_FuegoToon_Cuerpo"
MI_LENGUA = MATS + "MI_FuegoToon_Lengua.MI_FuegoToon_Lengua"
MI_HUMO = MATS + "MI_HumoToon.MI_HumoToon"
MI_CHISPA = MATS + "MI_ChispaToon.MI_ChispaToon"
FPS = 12
DI["rango_v4"] = D + "UniformRange/V2/RandomRangeVector4.RandomRangeVector4"
ue.EditorAssetLibrary.make_directory(pn.CARPETA)


def v4f(x, y, z, w):
    v = ue.Vector4f()   # el constructor de Vector4f no admite argumentos
    v.set_editor_properties({"x": float(x), "y": float(y), "z": float(z), "w": float(w)})
    return v


def rango_v4(a, bb):
    return dinamico("rango_v4", T.VEC4, Minimum=fx.create_script_input_vec4(v4f(*a)), Maximum=fx.create_script_input_vec4(v4f(*bb)))


def envolvente():
    return curva_f([(0, 0), (0.3, 1), (4.3, 1), (4.8, 0)], enlace("Emitter.Age"))


def env_escalones(t_fin=5.0, base=1.0, titileo=0.25, semilla=3):
    rnd = random.Random(semilla)
    def env(t):
        if t < 0.3: return t / 0.3
        if t > 4.3: return max(0.0, 1 - (t - 4.3) / 0.5)
        return 1.0
    pts = [(k / FPS, env(k / FPS) * (base - titileo * rnd.random())) for k in range(int(t_fin * FPS) + 1)]
    claves_c = claves(pts)
    for c in claves_c: c.set_editor_property("interp_mode", ue.RichCurveInterpMode.RCIM_CONSTANT)
    di = fx.create_float_curve_di(claves_c)
    ctx = fx.create_script_context(args(DI["curva_f"], [1, 0]))
    ctx.set_parameter("FloatCurve", fx.create_script_input_di(di))
    ctx.set_parameter("CurveIndex", enlace("Emitter.Age"))
    return fx.create_script_input_dynamic(ctx, T.FLOAT)


def caja_en_altura(e, tam, z0, z1):
    m = e.modulo("ShapeLocation", "forma", CAT.PARTICLE_SPAWN)
    m.set_parameter("Shape Primitive", enum("forma", "Box / Plane"))
    dz = max(0.001, float(z1 - z0))
    m.set_parameter("Box Size", mul_vf(v3(tam[0], tam[1], dz), L) if tam[0] else v3(0.001, 0.001, dz))
    m.set_parameter("Box Midpoint", v3(0.5, 0.5, -z0 / dz))


def tam_no_uniforme(e, minimo, maximo):
    e.ini.set_parameter("Sprite Size Mode", enum("modo_tam", "Random Non-Uniform"))
    e.ini.set_parameter("Sprite Size Min", v2(*minimo))
    e.ini.set_parameter("Sprite Size Max", v2(*maximo))


def lenguas_z(material, pivote=(0.5, 1.0)):
    r = ue.NiagaraSpriteRendererProperties()
    r.set_editor_properties({"material": ue.load_asset(material), "sub_image_size": ue.Vector2D(1, 1),
                             "alignment": ue.NiagaraSpriteAlignment.CUSTOM_ALIGNMENT, "facing_mode": ue.NiagaraSpriteFacingMode.FACE_CAMERA_POSITION,
                             "pivot_in_uv_space": ue.Vector2D(*pivote), "sort_mode": ue.NiagaraSortMode.NONE})
    return r


sis, ctx = pn.nuevo_sistema("NS_MuroFuegoToon")
sis.set_editor_property("fixed_tick_delta", True)
sis.set_editor_property("fixed_tick_delta_time", 1.0 / FPS)
L = enlace("User.Longitud")
env = envolvente()
ALFA = [(0, 1), (0.65, 1), (1, 0.0)]            # (13) adaptado: la máscara se come desde el borde al morir, sin negro
RGB1 = ([(0, 1), (1, 1)], [(0, 1), (1, 1)], [(0, 1), (1, 1)])

# ---------------------------------------------------------------- LENGUAS: capa principal (rampa de tres tonos)
e = Emisor(ctx, "Lenguas", local=True)
e.tasa(mul_f(mul_f(f(28), L), env))
e.vida(0.8, 1.3)
e.color(1, 1, 1, 1)
tam_no_uniforme(e, (110, 80), (200, 140))      # más anchas que altas, varios tamaños (ronda 10: más pequeñas y más)
caja_en_altura(e, (690, 30), 0, 12)            # 30 cm de fondo: solapadas a distintas profundidades
e.velocidad(rango_v(ue.Vector(0, 0, 20), ue.Vector(0, 0, 45)))   # ronda 9: suben poco, como en la referencia
e.e.set_parameter_directly("Particles.SpriteAlignment", v3(0, 0, 1), CAT.PARTICLE_SPAWN)
e.e.set_parameter_directly("Particles.DynamicMaterialParameter", rango_v4((0.8, 0, 0, 0), (1.3, 1, 1, 0)), CAT.PARTICLE_SPAWN)
e.estado_particula()
e.tam_por_vida([(0, 0.5), (0.15, 1.0), (1, 1.05)])   # (12) crece rápido y se mantiene
e.color_por_vida(RGB1, ALFA)
e.resolver()
e.e.add_renderer("SpriteRenderer", lenguas_z(MI_LENGUA))

# ---------------------------------------------------------------- BASE: franja baja crema, ondulada y brillante (capa «núcleo»)
e = Emisor(ctx, "Base", local=True)
e.tasa(mul_f(mul_f(f(6), L), env))
e.vida(0.8, 1.4)
e.color(1, 1, 1, 1)
tam_no_uniforme(e, (100, 50), (150, 70))   # ronda 15: lenguas bajas todo crema, pocas y pequeñas (los sprites muy bajos parecían una alfombra)
caja_en_altura(e, (690, 20), -4, 4)
e.velocidad(rango_v(ue.Vector(0, 0, 8), ue.Vector(0, 0, 22)))
e.e.set_parameter_directly("Particles.SpriteAlignment", v3(0, 0, 1), CAT.PARTICLE_SPAWN)
e.e.set_parameter_directly("Particles.DynamicMaterialParameter", rango_v4((0.9, 0, 0, 0), (1.2, 1, 1, 0)), CAT.PARTICLE_SPAWN)
e.estado_particula()
e.tam_por_vida([(0, 0.6), (0.15, 1.0), (1, 1.0)])
e.color_por_vida(RGB1, ALFA)
e.resolver()
e.e.add_renderer("SpriteRenderer", lenguas_z(MI_BASE))

# ---------------------------------------------------------------- HUMO: poco, gris, pequeño, desde la punta
e = Emisor(ctx, "Humo", local=True)
e.tasa(mul_f(mul_f(f(2.5), L), env))
e.vida(0.9, 1.4)
e.color(1, 1, 1, 1)
e.tam_sprite(9, 15)
caja_en_altura(e, (690, 12), 100, 125)
e.velocidad(rango_v(ue.Vector(-8, -8, 18), ue.Vector(8, 8, 34)))
e.estado_particula()
e.tam_por_vida([(0, 0.7), (1, 1.5)])
e.resolver()
r = ue.NiagaraSpriteRendererProperties()
r.set_editor_properties({"material": ue.load_asset(MI_HUMO), "sub_image_size": ue.Vector2D(1, 1), "sort_mode": ue.NiagaraSortMode.NONE})
e.e.add_renderer("SpriteRenderer", r)

# ---------------------------------------------------------------- CHISPAS: muchas y pequeñas
e = Emisor(ctx, "Chispas", local=True)
e.tasa(mul_f(mul_f(f(40), L), env))
e.vida(0.4, 0.8)
e.color(1, 1, 1, 1)
e.tam_sprite(2.5, 4.5)
caja_en_altura(e, (690, 12), 30, 70)
e.velocidad_cono(rango_f(120, 260), v3(0, 0, 1), 30)
e.estado_particula()
e.gravedad(-260)
e.resolver()
r = ue.NiagaraSpriteRendererProperties()
r.set_editor_properties({"material": ue.load_asset(MI_CHISPA), "sub_image_size": ue.Vector2D(1, 1), "alignment": ue.NiagaraSpriteAlignment.VELOCITY_ALIGNED})
e.e.add_renderer("SpriteRenderer", r)

# ---------------------------------------------------------------- LUZ: una sola, titileo en escalones
e = Emisor(ctx, "Luz", local=True)
e.rafaga(1)
e.vida(1000)
e.color(1.0 * 5, 0.5 * 5, 0.18 * 5, 1.0)
e.tam_sprite(1)
caja_en_altura(e, (0, 0), 25, 26)
e.estado_particula()
e.e.set_parameter_directly("Particles.LightRadius", mul_f(f(520), env_escalones()), CAT.PARTICLE_UPDATE)
r = ue.NiagaraLightRendererProperties()
r.set_editor_properties({"affects_translucency": True, "use_inverse_squared_falloff": False, "alpha_scales_brightness": True})
e.e.set_renderer_binding(r, "RadiusBinding", "Particles.LightRadius", ue.NiagaraRendererSourceDataMode.PARTICLES)
e.e.add_renderer("LightRenderer", r)

guardar(sis, ctx)
print("fixed_tick_delta:", sis.get_editor_property("fixed_tick_delta"), sis.get_editor_property("fixed_tick_delta_time"))
print("NIAGARA CGHOW: fin")

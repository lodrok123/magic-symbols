# Prueba 2 (fuego toon): sistema Niagara NS_MuroFuegoToon en /Game/POC2/VFX.
# Cuerpo = una partícula de malla (Plane del motor, 6,9 x 1,5 m) con MI_FuegoToon_Cuerpo; lenguas = sprites alineados en Z
# (billboard con eje vertical fijo) con MI_FuegoToon_Lengua; humo = bolas de dos tonos que nacen en la punta; chispas; una luz
# con titileo en escalones. Toda la simulación va a paso fijo de 1/12 s (fixed_tick_delta): humo, chispas y lenguas se mueven
# a 12 fotogramas por segundo. User.Longitud como en la prueba 1 (1.0 = 6,9 m).
import sys, random, unreal as ue
sys.path.append(ue.Paths.project_dir() + "Scripts")
import importlib, poc_niagara as pn
importlib.reload(pn)
from poc_niagara import *

pn.CARPETA = "/Game/POC2/VFX"
MATS = "/Game/POC2/Materiales/"
MI_CUERPO = MATS + "MI_FuegoToon_Cuerpo.MI_FuegoToon_Cuerpo"
MI_LENGUA = MATS + "MI_FuegoToon_Lengua.MI_FuegoToon_Lengua"
MI_HUMO = MATS + "MI_HumoToon.MI_HumoToon"
MI_CHISPA = MATS + "MI_ChispaToon.MI_ChispaToon"
MALLA_PLANO = "/Engine/BasicShapes/Plane.Plane"
FPS = 12
VIDA_TOTAL = 4.8
ue.EditorAssetLibrary.make_directory(pn.CARPETA)
DI["add_v"] = D + "Add/Add_Vector.Add_Vector"


def envolvente():
    """nacer 0,3 s / vivir hasta 4,3 s / morir a 4,8 s, sobre la edad del emisor."""
    return curva_f([(0, 0), (0.3, 1), (4.3, 1), (4.8, 0)], enlace("Emitter.Age"))


def env_escalones(t_fin=5.0, base=1.0, titileo=0.25, semilla=3):
    """Curva en escalones (interpolación constante, 12 claves por segundo) con titileo aleatorio y la envolvente nacer/morir."""
    rnd = random.Random(semilla)
    def env(t):
        if t < 0.3: return t / 0.3
        if t > 4.3: return max(0.0, 1 - (t - 4.3) / 0.5)
        return 1.0
    pts = []
    for k in range(int(t_fin * FPS) + 1):
        t = k / FPS
        pts.append((t, env(t) * (base - titileo * rnd.random())))
    claves_c = claves(pts)
    for c in claves_c:
        c.set_editor_property("interp_mode", ue.RichCurveInterpMode.RCIM_CONSTANT)
    di = fx.create_float_curve_di(claves_c)
    ctx = fx.create_script_context(args(DI["curva_f"], [1, 0]))
    ctx.set_parameter("FloatCurve", fx.create_script_input_di(di))
    ctx.set_parameter("CurveIndex", enlace("Emitter.Age"))
    return fx.create_script_input_dynamic(ctx, T.FLOAT)


def caja_en_altura(e, tam, z0, z1):
    """Caja de ShapeLocation con la Z entre z0 y z1: posición = (aleatorio - punto medio) * tamaño, así que con
    tamaño z = (z1 - z0) y punto medio z = -z0 / (z1 - z0) la Z queda en [z0, z1]. (Particles.Position es de tipo
    posición y no se puede sumar un vector por script sin que el compilador de Niagara proteste.)"""
    m = e.modulo("ShapeLocation", "forma", CAT.PARTICLE_SPAWN)
    m.set_parameter("Shape Primitive", enum("forma", "Box / Plane"))
    dz = max(0.001, float(z1 - z0))
    m.set_parameter("Box Size", mul_vf(v3(tam[0], tam[1], dz), L) if tam[0] else v3(0.001, 0.001, dz))
    m.set_parameter("Box Midpoint", v3(0.5, 0.5, -z0 / dz))


sis, ctx = pn.nuevo_sistema("NS_MuroFuegoToon")
sis.set_editor_property("fixed_tick_delta", True)
sis.set_editor_property("fixed_tick_delta_time", 1.0 / FPS)
L = enlace("User.Longitud")
caja = mul_vf(v3(690, 12, 0), L)
env = envolvente()

# ---------------------------------------------------------------- CUERPO: una partícula de malla plana vertical
e = Emisor(ctx, "Cuerpo", local=True)
e.rafaga(1)
e.vida(1000)
e.color(1, 1, 1, 1)
e.ini.set_parameter("Mesh Scale Mode", enum("modo_tam", "Uniform"))
e.ini.set_parameter("Uniform Mesh Scale", f(1.0))
caja_en_altura(e, (0, 0), 75, 76)   # centro de la malla a 75 cm: la base queda en el suelo
e.estado_particula()
e.e.set_parameter_directly("Particles.Scale", mul_vf(v3(1, 1, 1), env), CAT.PARTICLE_UPDATE)
r = fx.create_mesh_renderer_properties()
p = ue.NiagaraMeshRendererMeshProperties()
p.set_editor_property("mesh", ue.load_asset(MALLA_PLANO))
p.set_editor_property("scale", ue.Vector(6.9, 1.5, 1.0))       # 690 x 150 cm (el Plane mide 100 x 100)
p.set_editor_property("rotation", ue.Rotator(90.0, 0.0, 0.0))  # Rotator(roll, pitch, yaw): de pie, la Y de la malla pasa a Z
r.set_editor_property("meshes", [p])
om = ue.NiagaraMeshMaterialOverride()
om.set_editor_property("explicit_mat", ue.load_asset(MI_CUERPO))
r.set_editor_property("bOverrideMaterials", True)
r.set_editor_property("override_materials", [om])
r.set_editor_property("sort_mode", ue.NiagaraSortMode.NONE)
e.e.add_renderer("MeshRenderer", r)

# ---------------------------------------------------------------- LENGUAS: sprites con eje vertical fijo, pivote en la base
e = Emisor(ctx, "Lenguas", local=True)
e.tasa(mul_f(mul_f(f(10), L), env))
e.vida(1.1, 1.7)
e.color(1, 1, 1, 1)
e.tam_sprite(95, 150)
e.forma_caja(caja)
e.velocidad(rango_v(ue.Vector(0, 0, 25), ue.Vector(0, 0, 55)))
e.e.set_parameter_directly("Particles.SpriteAlignment", v3(0, 0, 1), CAT.PARTICLE_SPAWN)
e.estado_particula()
e.tam_por_vida([(0, 0.75), (0.35, 1.0), (1, 1.15)])
e.resolver()
r = ue.NiagaraSpriteRendererProperties()
r.set_editor_properties({"material": ue.load_asset(MI_LENGUA), "sub_image_size": ue.Vector2D(1, 1),
                         "alignment": ue.NiagaraSpriteAlignment.CUSTOM_ALIGNMENT, "facing_mode": ue.NiagaraSpriteFacingMode.FACE_CAMERA_POSITION,
                         "pivot_in_uv_space": ue.Vector2D(0.5, 1.0), "sort_mode": ue.NiagaraSortMode.NONE})
e.e.add_renderer("SpriteRenderer", r)

# ---------------------------------------------------------------- HUMO: bolas que nacen en la punta (z ~ 110), crecen y mueren de golpe
e = Emisor(ctx, "Humo", local=True)
e.tasa(mul_f(mul_f(f(5), L), env))
e.vida(0.9, 1.4)
e.color(1, 1, 1, 1)
e.tam_sprite(16, 28)
caja_en_altura(e, (690, 12), 96, 112)   # nace en la punta de la llama (AlturaLlama ~ 75 % de 150 cm)
e.velocidad(rango_v(ue.Vector(-8, -8, 16), ue.Vector(8, 8, 32)))
e.estado_particula()
e.tam_por_vida([(0, 0.6), (1, 1.7)])
e.resolver()
r = ue.NiagaraSpriteRendererProperties()
r.set_editor_properties({"material": ue.load_asset(MI_HUMO), "sub_image_size": ue.Vector2D(1, 1), "sort_mode": ue.NiagaraSortMode.NONE})
e.e.add_renderer("SpriteRenderer", r)

# ---------------------------------------------------------------- CHISPAS: puntos amarillos alargados por la velocidad
e = Emisor(ctx, "Chispas", local=True)
e.tasa(mul_f(mul_f(f(18), L), env))
e.vida(0.4, 0.9)
e.color(1, 1, 1, 1)
e.tam_sprite(4, 7)
caja_en_altura(e, (690, 12), 30, 60)
e.velocidad_cono(rango_f(110, 240), v3(0, 0, 1), 28)
e.estado_particula()
e.gravedad(-260)
e.resolver()
r = ue.NiagaraSpriteRendererProperties()
r.set_editor_properties({"material": ue.load_asset(MI_CHISPA), "sub_image_size": ue.Vector2D(1, 1), "alignment": ue.NiagaraSpriteAlignment.VELOCITY_ALIGNED})
e.e.add_renderer("SpriteRenderer", r)

# ---------------------------------------------------------------- LUZ: una sola, cálida, en el suelo, radio con titileo en escalones
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
print("NIAGARA toon: fin")

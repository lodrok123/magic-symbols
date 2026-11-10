# Ayudas para construir sistemas Niagara desde Python con la API del plugin CascadeToNiagaraConverter
# (FXConverterUtilitiesLibrary). Es la única vía de autoría de Niagara que Unreal 5.8 expone a Python.
import unreal as ue
from unreal import FXConverterUtilitiesLibrary as fx

CARPETA = "/Game/POC/VFX"
MAT = "/NetworkPredictionExtras/Art/Effects/Proto/Shared/Materials/Starter/"
MAT_FUEGO = "/Game/POC/Materiales/M_POC_Fuego.M_POC_Fuego"  # copias de los materiales de NetworkPredictionExtras con uso Niagara activado
MAT_HUMO = "/Game/POC/Materiales/M_POC_Humo.M_POC_Humo"
MAT_CHISPA = "/Game/POC/Materiales/M_POC_Chispa.M_POC_Chispa"
MAT_CALOR = "/Game/POC/Materiales/M_POC_Calor.M_POC_Calor"
MAT_NUCLEO = "/Game/POC/Materiales/M_POC_Nucleo.M_POC_Nucleo"
MALLA_ESFERA = "/Engine/BasicShapes/Sphere.Sphere"

M = "/Niagara/Modules/"
D = "/Niagara/DynamicInputs/"
E = "/Niagara/Enums/"
MOD = {
    "estado_emisor": M + "Emitter/EmitterState.EmitterState",
    "tasa": M + "Emitter/SpawnRate.SpawnRate",
    "rafaga": M + "Emitter/SpawnBurst_Instantaneous.SpawnBurst_Instantaneous",
    "inicializar": M + "Spawn/Initialization/V2/InitializeParticle.InitializeParticle",
    "forma": M + "Spawn/Location/V2/ShapeLocation.ShapeLocation",
    "velocidad": M + "Spawn/Velocity/AddVelocity.AddVelocity",
    "estado_particula": M + "Update/Lifetime/ParticleState.ParticleState",
    "gravedad": M + "Update/Forces/GravityForce.GravityForce",
    "aceleracion": M + "Update/Forces/AccelerationForce.AccelerationForce",
    "arrastre": M + "Update/Forces/Drag.Drag",
    "ruido": M + "Update/Forces/V2/CurlNoiseForce.CurlNoiseForce",
    "escala_color": M + "Update/Color/ScaleColor.ScaleColor",
    "escala_sprite": M + "Update/Size/ScaleSpriteSize.ScaleSpriteSize",
    "subuv": M + "Update/SubUV/V2/SubUVAnimation.SubUVAnimation",
    "resolver": M + "Solvers/SolveForcesAndVelocity.SolveForcesAndVelocity",
}
DI = {
    "mul_f": D + "Multiply/Multiply_Float.Multiply_Float",
    "mul_v": D + "Multiply/Multiply_Vector.Multiply_Vector",
    "mul_vf": D + "Multiply/Multiply_VectorByFloat.Multiply_VectorByFloat",
    "mul_v2": D + "Multiply/Multiply_Vector2.Multiply_Vector2",
    "rango_f": D + "UniformRange/V2/RandomRangeFloat.RandomRangeFloat",
    "rango_v": D + "UniformRange/V2/RandomRangeVector.RandomRangeVector",
    "rango_v2": D + "UniformRange/V2/RandomRangeVector2D.RandomRangeVector2D",
    "curva_f": D + "ValueFromCurve/FloatFromCurve.FloatFromCurve",
    "curva_v2": D + "ValueFromCurve/Vector2DFromCurve.Vector2DFromCurve",
    "curva_v": D + "ValueFromCurve/VectorFromCurve.VectorFromCurve",
    "color_vf": D + "LinearColor/MakeLinearColorFromVectorAndFloat.MakeLinearColorFromVectorAndFloat",
    "v2_de_f": D + "TypeConversions/Vector2DFromFloat.Vector2DFromFloat",
}
EN = {
    "forma": E + "Location/ENiagara_LocationShapes.ENiagara_LocationShapes",
    "ciclo": E + "ENiagaraEmitterLifeCycleMode.ENiagaraEmitterLifeCycleMode",
    "bucle": E + "ENiagara_EmitterStateOptions.ENiagara_EmitterStateOptions",
    "inactivo": E + "ENiagaraInactiveMode.ENiagaraInactiveMode",
    "modo_tam": E + "ENiagara_SizeScaleMode.ENiagara_SizeScaleMode",
    "escala_sprite": E + "SpriteRenderer/ENiagara_ScaleSpriteSize.ENiagara_ScaleSpriteSize",
    "subuv": E + "ENiagara_SubUVLookupModeV2.ENiagara_SubUVLookupModeV2",
    "fps": E + "SpriteRenderer/ENiagara_FPSPlayrate.ENiagara_FPSPlayrate",
    "espacio": E + "ENiagaraCoordinateSpace.ENiagaraCoordinateSpace",
    "vel_modo": E + "Utility/ENiagara_VelocityMode.ENiagara_VelocityMode",
    "angulo": E + "Angles/ENiagara_AngleInput.ENiagara_AngleInput",
    "rot_sprite": E + "ENiagara_SpriteRotationMode.ENiagara_SpriteRotationMode",
}
T = ue.NiagaraScriptInputType
CAT = ue.ScriptExecutionCategory


def args(ruta, version=None):
    ad = fx.create_asset_data(ruta)
    return ue.CreateScriptContextArgs(ad, version) if version else ue.CreateScriptContextArgs(ad)


def f(v): return fx.create_script_input_float(float(v))
def i(v): return fx.create_script_input_int(int(v))
def b(v): return fx.create_script_input_bool(bool(v))
def v3(x, y, z): return fx.create_script_input_vector(ue.Vector(x, y, z))
def v2(x, y): return fx.create_script_input_vec2(ue.Vector2D(x, y))
def col(r, g, bb, a=1.0): return fx.create_script_input_linear_color(ue.LinearColor(r, g, bb, a))
def enum(clave, nombre): return fx.create_script_input_enum(EN[clave], nombre)
def enlace(nombre, tipo=T.FLOAT): return fx.create_script_input_linked_parameter(nombre, tipo)


def dinamico(clave_di, tipo, **params):
    """Crea un dynamic input (p. ej. Multiply_Float) con sus parámetros y lo devuelve como input."""
    ctx = fx.create_script_context(args(DI[clave_di]))
    for k, v in params.items():
        ctx.set_parameter(k, v)
    return fx.create_script_input_dynamic(ctx, tipo)


def rango_f(a, bb): return dinamico("rango_f", T.FLOAT, Minimum=f(a), Maximum=f(bb))
def rango_v(a, bb): return dinamico("rango_v", T.VEC3, Minimum=fx.create_script_input_vector(a), Maximum=fx.create_script_input_vector(bb))
def rango_v2(a, bb): return dinamico("rango_v2", T.VEC2, Minimum=fx.create_script_input_vec2(a), Maximum=fx.create_script_input_vec2(bb))
def mul_f(a, bb): return dinamico("mul_f", T.FLOAT, A=a, B=bb)
def mul_vf(vec, flt): return dinamico("mul_vf", T.VEC3, Vector=vec, Float=flt)


def claves(puntos):
    out = []
    for t, v in puntos:
        k = ue.RichCurveKeyBP()
        k.set_editor_property("time", float(t))
        k.set_editor_property("value", float(v))
        out.append(k)
    return out


def curva_f(puntos, indice=None):
    """Float por curva sobre la edad normalizada (o sobre `indice`, p. ej. enlace('Emitter.Age'))."""
    di = fx.create_float_curve_di(claves(puntos))
    ctx = fx.create_script_context(args(DI["curva_f"], [1, 0]))
    ctx.set_parameter("FloatCurve", fx.create_script_input_di(di))
    if indice is not None:
        ctx.set_parameter("CurveIndex", indice)
    return fx.create_script_input_dynamic(ctx, T.FLOAT)


def curva_v2(px, py, indice=None):
    di = fx.create_vec2_curve_di(claves(px), claves(py))
    ctx = fx.create_script_context(args(DI["curva_v2"], [1, 0]))
    ctx.set_parameter("Vector2Curve", fx.create_script_input_di(di))
    if indice is not None:
        ctx.set_parameter("CurveIndex", indice)
    return fx.create_script_input_dynamic(ctx, T.VEC2)


def curva_v(px, py, pz, indice=None):
    di = fx.create_vec3_curve_di(claves(px), claves(py), claves(pz))
    ctx = fx.create_script_context(args(DI["curva_v"], [1, 0]))
    ctx.set_parameter("VectorCurve", fx.create_script_input_di(di))
    if indice is not None:
        ctx.set_parameter("CurveIndex", indice)
    return fx.create_script_input_dynamic(ctx, T.VEC3)


def nuevo_sistema(nombre):
    """Crea (o recrea) el asset NiagaraSystem y devuelve (sistema, contexto)."""
    ruta = CARPETA + "/" + nombre
    if ue.EditorAssetLibrary.does_asset_exist(ruta):
        ue.EditorAssetLibrary.delete_asset(ruta)
    at = ue.AssetToolsHelpers.get_asset_tools()
    sistema = at.create_asset(nombre, CARPETA, ue.NiagaraSystem, ue.NiagaraSystemFactoryNew())
    if sistema is None:
        raise RuntimeError("no se pudo crear " + ruta)
    return sistema, fx.create_system_conversion_context(sistema)


def guardar(sistema, ctx):
    ctx.finalize()
    ctx.cleanup()
    ue.EditorAssetLibrary.save_loaded_asset(sistema)
    ue.log("NIAGARA guardado: " + sistema.get_path_name())


class Emisor:
    """Un emisor con los módulos obligatorios ya puestos, en el orden de la pila estándar de Niagara."""

    def __init__(self, sis_ctx, nombre, local=True, bucle="Infinite", duracion=0.0, gpu=False):
        self.e = sis_ctx.add_empty_emitter(nombre)
        self.e.set_local_space(local)
        self.e.set_sim_target(ue.NiagaraSimTarget.GPU_COMPUTE_SIM if gpu else ue.NiagaraSimTarget.CPU_SIM)
        est = self.modulo("EmitterState", "estado_emisor", CAT.EMITTER_UPDATE, [1, 0])
        est.set_parameter("Life Cycle Mode", enum("ciclo", "Self"))
        est.set_parameter("Inactive Response", enum("inactivo", "Complete (Let Particles Finish then Kill Emitter)"))
        est.set_parameter("Loop Behavior", enum("bucle", bucle))
        if bucle != "Infinite":
            est.set_parameter("Loop Duration", f(duracion))
        self.ini = self.modulo("InitializeParticle", "inicializar", CAT.PARTICLE_SPAWN, [1, 0])
        self.estado = None

    def modulo(self, nombre, clave, cat, version=None):
        return self.e.find_or_add_module_script(nombre, args(MOD[clave], version), cat)

    # --- generación
    def tasa(self, valor):
        self.modulo("SpawnRate", "tasa", CAT.EMITTER_UPDATE, [1, 0]).set_parameter("SpawnRate", valor)

    def rafaga(self, cuenta, t=0.0):
        r = self.modulo("SpawnBurst", "rafaga", CAT.EMITTER_UPDATE, [1, 1])
        r.set_parameter("Spawn Count", i(cuenta))
        r.set_parameter("Spawn Time", f(t))

    # --- inicialización
    def vida(self, a, bb=None):
        self.ini.set_parameter("Lifetime", f(a) if bb is None else rango_f(a, bb))

    def color(self, r, g, bb, a=1.0):
        self.ini.set_parameter("Color", col(r, g, bb, a))

    def tam_sprite(self, a, bb=None):
        self.ini.set_parameter("Sprite Size Mode", enum("modo_tam", "Random Uniform" if bb is not None else "Uniform"))
        if bb is None:
            self.ini.set_parameter("Uniform Sprite Size", f(a))
        else:
            self.ini.set_parameter("Uniform Sprite Size Min", f(a))
            self.ini.set_parameter("Uniform Sprite Size Max", f(bb))

    def rot_sprite_aleatoria(self):
        self.ini.set_parameter("Sprite Rotation Mode", enum("rot_sprite", "Random"))

    def tam_malla(self, s):
        self.ini.set_parameter("Mesh Scale Mode", enum("modo_tam", "Uniform"))
        self.ini.set_parameter("Uniform Mesh Scale", f(s))
        self.e.set_parameter_directly("Particles.Scale", v3(s, s, s), CAT.PARTICLE_SPAWN)  # refuerzo: la malla salía a tamaño completo

    def forma_caja(self, tam):
        m = self.modulo("ShapeLocation", "forma", CAT.PARTICLE_SPAWN)
        m.set_parameter("Shape Primitive", enum("forma", "Box / Plane"))
        m.set_parameter("Box Size", tam)

    def forma_esfera(self, radio):
        m = self.modulo("ShapeLocation", "forma", CAT.PARTICLE_SPAWN)
        m.set_parameter("Shape Primitive", enum("forma", "Sphere"))
        m.set_parameter("Sphere Radius", radio)

    def forma_cilindro(self, radio, alto):
        m = self.modulo("ShapeLocation", "forma", CAT.PARTICLE_SPAWN)
        m.set_parameter("Shape Primitive", enum("forma", "Cylinder"))
        m.set_parameter("Cylinder Radius", radio)
        m.set_parameter("Cylinder Height", alto)

    def velocidad(self, vec):
        m = self.modulo("AddVelocity", "velocidad", CAT.PARTICLE_SPAWN)
        m.set_parameter("Velocity Mode", enum("vel_modo", "Linear"))
        m.set_parameter("Velocity", vec)

    def velocidad_cono(self, rapidez, eje, angulo):
        m = self.modulo("AddVelocity", "velocidad", CAT.PARTICLE_SPAWN)
        m.set_parameter("Velocity Mode", enum("vel_modo", "In Cone"))
        m.set_parameter("Velocity Speed", rapidez)
        m.set_parameter("Cone Axis", eje)
        m.set_parameter("Cone Angle", f(angulo))
        m.set_parameter("Cone Angle Mode", enum("angulo", "Degrees"))

    # --- actualización (el orden de llamada es el orden de la pila)
    def estado_particula(self):
        self.estado = self.modulo("ParticleState", "estado_particula", CAT.PARTICLE_UPDATE, [1, 1])

    def gravedad(self, z):
        self.modulo("GravityForce", "gravedad", CAT.PARTICLE_UPDATE).set_parameter("Gravity", v3(0, 0, z))

    def aceleracion(self, x, y, z):
        self.modulo("AccelerationForce", "aceleracion", CAT.PARTICLE_UPDATE).set_parameter("Acceleration", v3(x, y, z))

    def arrastre(self, d):
        self.modulo("Drag", "arrastre", CAT.PARTICLE_UPDATE).set_parameter("Drag", f(d))

    def ruido(self, fuerza, frecuencia):
        m = self.modulo("CurlNoiseForce", "ruido", CAT.PARTICLE_UPDATE)
        m.set_parameter("Noise Strength", f(fuerza))
        m.set_parameter("Noise Frequency", f(frecuencia))

    def color_por_vida(self, rgb, alfa):
        """rgb: (px, py, pz) listas de (t, v); alfa: lista de (t, v). Sobre edad normalizada."""
        m = self.modulo("ScaleColor", "escala_color", CAT.PARTICLE_UPDATE)
        m.set_parameter("Scale RGB", curva_v(*rgb))
        m.set_parameter("Scale Alpha", curva_f(alfa))

    def tam_por_vida(self, puntos):
        m = self.modulo("ScaleSpriteSize", "escala_sprite", CAT.PARTICLE_UPDATE)
        m.set_parameter("Scale Sprite Size Mode", enum("escala_sprite", "Uniform"))
        m.set_parameter("Uniform Scale Factor", curva_f(puntos))

    def subuv(self, fps=None):
        m = self.modulo("SubUVAnimation", "subuv", CAT.PARTICLE_UPDATE)
        if fps is None:
            m.set_parameter("SubUV Animation Mode", enum("subuv", "Linear"))
        else:
            m.set_parameter("SubUV Animation Mode", enum("subuv", "Infinite Loop"))
            m.set_parameter("Playback Mode", enum("fps", "Frames Per Second"))
            m.set_parameter("Frames Per Second", i(fps))
            m.set_parameter("Random Start Frame", b(True))

    def resolver(self):
        self.modulo("SolveForcesAndVelocity", "resolver", CAT.PARTICLE_UPDATE)

    # --- renderers
    def sprite(self, material, subuv=(8, 8), nombre="SpriteRenderer", velocidad_alineada=False):
        r = ue.NiagaraSpriteRendererProperties()
        r.set_editor_property("Material", ue.load_asset(material))
        r.set_editor_property("SubImageSize", ue.Vector2D(subuv[0], subuv[1]))
        r.set_editor_property("bSubImageBlend", True)
        if velocidad_alineada:
            r.set_editor_property("Alignment", ue.NiagaraSpriteAlignment.VELOCITY_ALIGNED)
        self.e.add_renderer(nombre, r)
        return r

    def luz(self, radio, exponente=1.0, afecta_translucidos=True):
        r = ue.NiagaraLightRendererProperties()
        r.set_editor_property("RadiusScale", float(radio))
        r.set_editor_property("bAffectsTranslucency", afecta_translucidos)
        r.set_editor_property("bUseInverseSquaredFalloff", False)
        self.e.add_renderer("LightRenderer", r)
        self.e.set_parameter_directly("Particles.LightExponent", f(exponente), CAT.PARTICLE_UPDATE)
        return r

    def malla(self, malla, material=None):
        r = fx.create_mesh_renderer_properties()
        p = ue.NiagaraMeshRendererMeshProperties()
        p.set_editor_property("Mesh", ue.load_asset(malla))
        r.set_editor_property("Meshes", [p])
        if material:
            r.set_editor_property("bOverrideMaterials", True)
            om = ue.NiagaraMeshMaterialOverride()
            om.set_editor_property("ExplicitMat", ue.load_asset(material))
            r.set_editor_property("OverrideMaterials", [om])
        self.e.add_renderer("MeshRenderer", r)
        return r

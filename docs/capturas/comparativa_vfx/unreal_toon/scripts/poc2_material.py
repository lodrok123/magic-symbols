# Prueba 2 (fuego toon): textura de ruido propia + materiales M_FuegoToon, M_HumoToon, M_ChispaToon creados por script
# con MaterialEditingLibrary, y sus Material Instances con los mandos en castellano. Carpeta /Game/POC2/Materiales.
# Unidades: 1 uu = 1 cm. Tiempo cuantizado en el material: tq = floor(Time * Fps) / Fps.
import unreal as ue, os, zlib, struct, math, random, traceback
MEL = ue.MaterialEditingLibrary
EAL = ue.EditorAssetLibrary
AT = ue.AssetToolsHelpers.get_asset_tools()
CARPETA = "/Game/POC2/Materiales"
TMP = r"E:\tmp\prueba2_unreal"
os.makedirs(TMP, exist_ok=True)
EAL.make_directory(CARPETA)


# ------------------------------------------------------------------ 1. textura de ruido (propia, generada aquí)
def ruido_png(ruta, n=256, semilla=7):
    """Ruido de valor periódico (4 octavas, interpolación suave) en PNG gris de 8 bits, sin PIL."""
    rnd = random.Random(semilla)
    rejillas = []
    for o in range(4):
        m = 4 << o  # 4, 8, 16, 32 celdas
        rejillas.append((m, [[rnd.random() for _ in range(m)] for _ in range(m)]))
    def suave(t): return t * t * (3 - 2 * t)
    def octava(m, g, x, y):
        fx, fy = x * m, y * m
        ix, iy = int(fx) % m, int(fy) % m
        tx, ty = suave(fx - int(fx)), suave(fy - int(fy))
        a, b = g[iy][ix], g[iy][(ix + 1) % m]
        c, d = g[(iy + 1) % m][ix], g[(iy + 1) % m][(ix + 1) % m]
        return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty
    pesos = [0.5, 0.25, 0.15, 0.1]
    filas = []
    for j in range(n):
        fila = bytearray([0])  # filtro 0
        for i in range(n):
            v = sum(p * octava(m, g, i / n, j / n) for p, (m, g) in zip(pesos, rejillas))
            v = (v - 0.2) / 0.6  # estirar el contraste
            fila.append(max(0, min(255, int(v * 255))))
        filas.append(bytes(fila))
    raw = b"".join(filas)
    def chunk(tipo, datos):
        return struct.pack(">I", len(datos)) + tipo + datos + struct.pack(">I", zlib.crc32(tipo + datos) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(ruta, "wb") as fh:
        fh.write(png)
    return ruta


def importar_textura(nombre, png):
    ruta = CARPETA + "/" + nombre
    if EAL.does_asset_exist(ruta):
        EAL.delete_asset(ruta)
    t = ue.AssetImportTask()
    t.set_editor_properties({"filename": png, "destination_path": CARPETA, "destination_name": nombre, "automated": True, "save": False, "replace_existing": True})
    AT.import_asset_tasks([t])
    tex = ue.load_asset(ruta)
    if tex is None:
        raise RuntimeError("no se importó " + ruta)
    tex.set_editor_properties({"srgb": False, "compression_settings": ue.TextureCompressionSettings.TC_GRAYSCALE, "address_x": ue.TextureAddress.TA_WRAP, "address_y": ue.TextureAddress.TA_WRAP})
    EAL.save_loaded_asset(tex)
    print("textura", ruta, tex.blueprint_get_size_x(), "x", tex.blueprint_get_size_y())
    return tex


# ------------------------------------------------------------------ 2. ayudas de grafo
class Grafo:
    def __init__(self, nombre):
        self.ruta = CARPETA + "/" + nombre
        if EAL.does_asset_exist(self.ruta):
            # existe (y lo referencian instancias y el sistema Niagara): se vacía el grafo y se rehace, sin borrar el asset
            self.m = ue.load_asset(self.ruta)
            MEL.delete_all_material_expressions(self.m)
            for e in list(MEL.get_material_expressions(self.m)):   # delete_all no vació el grafo (ronda 4): uno a uno
                MEL.delete_material_expression(self.m, e)
            print("   grafo vaciado; quedan", MEL.get_num_material_expressions(self.m))
        else:
            self.m = AT.create_asset(nombre, CARPETA, ue.Material, ue.MaterialFactoryNew())
        self.m.set_editor_properties({"material_domain": ue.MaterialDomain.MD_SURFACE, "blend_mode": ue.BlendMode.BLEND_MASKED,
                                      "shading_model": ue.MaterialShadingModel.MSM_UNLIT, "two_sided": True, "opacity_mask_clip_value": 0.5})
        for flag in ("used_with_niagara_sprites", "used_with_niagara_mesh_particles", "used_with_mesh_particles", "used_with_particle_sprites", "used_with_static_lighting"):
            try: self.m.set_editor_property(flag, True)
            except Exception as e: print("   flag", flag, str(e)[:60])
        self.n = 0
        self.escalares, self.vectores = [], []

    def nodo(self, cls, **props):
        self.n += 1
        e = MEL.create_material_expression(self.m, cls, -200 * (self.n % 8), 120 * (self.n // 8))
        for k, v in props.items():
            e.set_editor_property(k, v)
        return e

    def esc(self, nombre, valor):
        self.escalares.append((nombre, valor))
        return self.nodo(ue.MaterialExpressionScalarParameter, parameter_name=nombre, default_value=float(valor))

    def vec(self, nombre, r, g, b):
        self.vectores.append((nombre, (r, g, b)))
        return self.nodo(ue.MaterialExpressionVectorParameter, parameter_name=nombre, default_value=ue.LinearColor(r, g, b, 1.0))

    def const(self, v): return self.nodo(ue.MaterialExpressionConstant, r=float(v))
    def const2(self, x, y): return self.nodo(ue.MaterialExpressionConstant2Vector, r=float(x), g=float(y))

    def con(self, a, b, entrada, salida=""):
        ok = MEL.connect_material_expressions(a, salida, b, entrada)
        if not ok: print("   SIN CONEXION", type(a).__name__, salida, "->", type(b).__name__, entrada)
        return ok

    def op(self, cls, a, b=None, sa="", sb="", ea="A", eb="B"):
        e = self.nodo(cls)
        self.con(a, e, ea, sa)
        if b is not None: self.con(b, e, eb, sb)
        return e

    def mul(self, a, b, sa="", sb=""): return self.op(ue.MaterialExpressionMultiply, a, b, sa, sb)
    def add(self, a, b, sa="", sb=""): return self.op(ue.MaterialExpressionAdd, a, b, sa, sb)
    def sub(self, a, b, sa="", sb=""): return self.op(ue.MaterialExpressionSubtract, a, b, sa, sb)
    def div(self, a, b, sa="", sb=""): return self.op(ue.MaterialExpressionDivide, a, b, sa, sb)
    def lerp(self, a, b, alfa, sa="", sb="", salfa=""):
        e = self.op(ue.MaterialExpressionLinearInterpolate, a, b, sa, sb); self.con(alfa, e, "Alpha", salfa); return e
    def append(self, a, b, sa="", sb=""): return self.op(ue.MaterialExpressionAppendVector, a, b, sa, sb)
    def uno_menos(self, a, sa=""): return self.op(ue.MaterialExpressionOneMinus, a, None, sa, ea="")
    def floor(self, a, sa=""): return self.op(ue.MaterialExpressionFloor, a, None, sa, ea="")
    def seno(self, a, sa=""): return self.op(ue.MaterialExpressionSine, a, None, sa, ea="")
    def mask(self, a, r=True, g=False, sa=""):
        e = self.nodo(ue.MaterialExpressionComponentMask, r=r, g=g, b=False, a=False); self.con(a, e, "", sa); return e
    def step(self, borde, valor, sb="", sv=""):
        """1 si valor >= borde, si no 0 (entradas Y = borde, X = valor)."""
        e = self.nodo(ue.MaterialExpressionStep); self.con(borde, e, "Y", sb); self.con(valor, e, "X", sv); return e
    def si(self, a, b, mayor, menor, sa="", sb="", smayor="", smenor=""):
        """If: a > b -> mayor, a == b -> mayor, a < b -> menor."""
        e = self.nodo(ue.MaterialExpressionIf)
        self.con(a, e, "A", sa); self.con(b, e, "B", sb)
        self.con(mayor, e, "A > B", smayor); self.con(mayor, e, "A == B", smayor); self.con(menor, e, "A < B", smenor)
        return e
    def tiempo_cuantizado(self, fps):
        """tq = floor(Time * Fps) / Fps: todo lo que use tq cambia 12 veces por segundo."""
        t = self.nodo(ue.MaterialExpressionTime)
        return self.div(self.floor(self.mul(t, fps)), fps)
    def muestra(self, tex, uv, suv=""):
        e = self.nodo(ue.MaterialExpressionTextureSample, texture=tex); self.con(uv, e, "UVs", suv); return e
    def panner(self, coord, tiempo, velocidad, sc="", st="", sv=""):
        e = self.nodo(ue.MaterialExpressionPanner); self.con(coord, e, "Coordinate", sc); self.con(tiempo, e, "Time", st); self.con(velocidad, e, "Speed", sv); return e

    def salida(self, expr, prop, s=""):
        ok = MEL.connect_material_property(expr, s, prop)
        if not ok: print("   SIN SALIDA", prop)

    def terminar(self):
        MEL.layout_material_expressions(self.m)
        MEL.recompile_material(self.m)
        est = MEL.get_statistics(self.m)
        print("material", self.ruta, "| expresiones", MEL.get_num_material_expressions(self.m), "| instrucciones", est.get_editor_property("num_pixel_shader_instructions"), "| muestras", est.get_editor_property("num_samplers"))
        print("   guardado", EAL.save_loaded_asset(self.m))
        return self.m

    def instancia(self, nombre, **valores):
        ruta = CARPETA + "/" + nombre
        if EAL.does_asset_exist(ruta):
            mi = ue.load_asset(ruta)
            MEL.clear_all_material_instance_parameters(mi)
        else:
            mi = AT.create_asset(nombre, CARPETA, ue.MaterialInstanceConstant, ue.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, self.m)
        for k, v in valores.items():
            if isinstance(v, tuple):
                MEL.set_material_instance_vector_parameter_value(mi, k, ue.LinearColor(v[0], v[1], v[2], 1.0))
            else:
                MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi)
        print("instancia", ruta, "| mandos:", sorted(k for k, _ in self.escalares + self.vectores), "| fijados:", valores)
        return mi


def srgb(hexa):
    """'#FF8A1F' -> LinearColor en lineal (el motor trabaja en lineal; los tonos de §0.1 están en sRGB)."""
    r, g, b = (int(hexa[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b))


# ------------------------------------------------------------------ 3. M_FuegoToon
def fuego(tex):
    g = Grafo("M_FuegoToon")
    # mandos (los diez de §1 y cuatro colores)
    Fps = g.esc("Fps", 12); Umbral = g.esc("Umbral", 1.05); Banda = g.esc("Banda", 0.32); BandaBorde = g.esc("BandaBorde", 0.16); Altura = g.esc("AlturaLlama", 1.0)
    Erosion = g.esc("Erosion", 1.3); Despl = g.esc("Desplazamiento", 6.0); Contorno = g.esc("Contorno", 0.0); Vel = g.esc("Velocidad", 0.8)
    Escala = g.esc("EscalaRuido", 1.5); Brillo = g.esc("Brillo", 0.7); Aspecto = g.esc("Aspecto", 1.0); InvV = g.esc("InvertirV", 1.0)
    ErosEdad = g.esc("ErosionPorEdad", 0.0); Lados = g.esc("Lados", 0.0)
    # tonos de §0.1 (#FFF3B0, #FF8A1F, #C8321E) algo más saturados: el tonemapper ACES del motor los lava hacia crema
    CNucleo = g.vec("ColorNucleo", *srgb("#FFEB80")); CCuerpo = g.vec("ColorCuerpo", *srgb("#FF7A10"))
    CBorde = g.vec("ColorBorde", *srgb("#C8321E")); CContorno = g.vec("ColorContorno", *srgb("#3A0A05"))
    tq = g.tiempo_cuantizado(Fps)
    tc = g.nodo(ue.MaterialExpressionTextureCoordinate)
    U = g.mask(tc, True, False); V = g.mask(tc, False, True)
    # h: 0 en la base, 1 en la punta (InvertirV cambia el sentido de la V del quad); h1 = h / AlturaLlama
    h = g.lerp(V, g.uno_menos(V), InvV)
    h1 = g.div(h, Altura)
    pr = g.nodo(ue.MaterialExpressionParticleRandom)
    # sentido del paneo: hacia la punta
    dirv = g.uno_menos(g.mul(InvV, g.const(2)))
    velv = g.mul(Vel, dirv)
    # ruido A: UV * (Aspecto, 1) * EscalaRuido + desfase aleatorio por partícula
    uv = g.mul(g.append(g.mul(U, Aspecto), V), Escala)
    uvA = g.add(uv, g.append(g.mul(pr, g.const(7.13)), g.const(0)))
    pA = g.panner(uvA, tq, g.append(g.const(0), velv))
    nA = g.muestra(tex, pA)
    # ruido B: más fino, más lento, otro desfase
    uvB = g.add(g.mul(uv, g.const(1.9)), g.append(g.add(g.mul(pr, g.const(3.7)), g.const(0.37)), g.const(0.5)))
    pB = g.panner(uvB, tq, g.append(g.mul(velv, g.const(0.12)), g.mul(velv, g.const(0.55))))
    nB = g.muestra(tex, pB)
    n = g.lerp(nA, nB, g.const(0.25), "R", "R")
    # f = n + (1 - h1) * Erosion - edad * ErosionPorEdad ; fuego donde f > Umbral
    edad = g.nodo(ue.MaterialExpressionParticleRelativeTime)
    # lados: (2U-1)^2 * Lados estrecha la lengua hacia los bordes del quad (gota invertida); 0 en la malla del cuerpo
    lat = g.sub(g.mul(U, g.const(2)), g.const(1))
    lat = g.mul(g.mul(lat, lat), Lados)
    f = g.sub(g.sub(g.add(n, g.mul(g.uno_menos(h1), Erosion)), g.mul(edad, ErosEdad)), lat)
    mascara = g.mul(g.step(Umbral, f), g.step(h1, g.const(1)))  # f >= Umbral y h1 <= 1
    g.salida(mascara, ue.MaterialProperty.MP_OPACITY_MASK)
    # rampa de tres escalones + contorno (segundo umbral)
    # borde rojo fino (BandaBorde) sobre el cuerpo naranja (Banda); el núcleo amarillo claro queda en la base
    c1 = g.si(f, g.add(g.add(Umbral, BandaBorde), Banda), CNucleo, CCuerpo)
    c2 = g.si(f, g.add(Umbral, BandaBorde), c1, CBorde)
    c3 = g.si(f, g.add(Umbral, g.mul(Contorno, g.const(0.08))), c2, CContorno)
    g.salida(g.mul(c3, Brillo), ue.MaterialProperty.MP_EMISSIVE_COLOR)
    # desplazamiento de vértices: vaivén lateral de la punta, cuantizado (usa tq) y distinto por partícula
    fase = g.add(g.add(g.mul(tq, g.const(0.9)), g.mul(pr, g.const(3.0))), g.mul(U, g.const(0.5)))
    vaiven = g.mul(g.mul(g.seno(fase), h), Despl)
    wpo = g.nodo(ue.MaterialExpressionAppend3Vector)
    g.con(vaiven, wpo, "A"); g.con(g.mul(vaiven, g.const(0.5)), wpo, "B"); g.con(g.const(0), wpo, "C")
    g.salida(wpo, ue.MaterialProperty.MP_WORLD_POSITION_OFFSET)
    g.terminar()
    # instancias: cuerpo (malla plana; V del Plane del motor: se comprueba en captura) y lengua (sprite: V=0 arriba)
    # el Plane del motor, de pie con roll 90, tiene V=0 arriba (visto en la ronda 3): InvertirV=1 también en el cuerpo
    g.instancia("MI_FuegoToon_Cuerpo", InvertirV=1.0, Aspecto=4.6, EscalaRuido=1.2, Erosion=1.3, Umbral=1.05, Desplazamiento=4.0)
    g.instancia("MI_FuegoToon_Lengua", InvertirV=1.0, Aspecto=0.8, EscalaRuido=1.1, Erosion=1.2, Umbral=1.05, ErosionPorEdad=0.9, Desplazamiento=8.0, Lados=0.9)
    return g


# ------------------------------------------------------------------ 4. M_HumoToon: bola redonda de dos tonos, borde duro
def humo():
    g = Grafo("M_HumoToon")
    Claro = g.vec("ColorHumoClaro", *srgb("#7E8A98")); Oscuro = g.vec("ColorHumoOscuro", *srgb("#4F5A66")); Brillo = g.esc("Brillo", 1.0)
    Radio = g.esc("Radio", 0.46); Luz = g.esc("TamanoLuz", 0.27)
    tc = g.nodo(ue.MaterialExpressionTextureCoordinate)
    d = g.op(ue.MaterialExpressionDistance, tc, g.const2(0.5, 0.5))
    d2 = g.op(ue.MaterialExpressionDistance, tc, g.const2(0.40, 0.38))
    mascara = g.step(d, Radio)  # Radio >= d
    g.salida(mascara, ue.MaterialProperty.MP_OPACITY_MASK)
    color = g.si(d2, Luz, Oscuro, Claro)  # dentro del círculo desplazado: claro
    g.salida(g.mul(color, Brillo), ue.MaterialProperty.MP_EMISSIVE_COLOR)
    g.terminar()
    g.instancia("MI_HumoToon")
    return g


# ------------------------------------------------------------------ 5. M_ChispaToon: punto amarillo duro
def chispa():
    g = Grafo("M_ChispaToon")
    Color = g.vec("ColorChispa", *srgb("#FFD23F")); Brillo = g.esc("Brillo", 1.2)
    tc = g.nodo(ue.MaterialExpressionTextureCoordinate)
    d = g.op(ue.MaterialExpressionDistance, tc, g.const2(0.5, 0.5))
    g.salida(g.step(d, g.const(0.5)), ue.MaterialProperty.MP_OPACITY_MASK)
    g.salida(g.mul(Color, Brillo), ue.MaterialProperty.MP_EMISSIVE_COLOR)
    g.terminar()
    g.instancia("MI_ChispaToon")
    return g


if __name__ == "__cola__" or __name__ == "__main__":
    if EAL.does_asset_exist(CARPETA + "/T_RuidoToon"):
        tex = ue.load_asset(CARPETA + "/T_RuidoToon")
    else:
        png = ruido_png(os.path.join(TMP, "T_RuidoToon.png"))
        tex = importar_textura("T_RuidoToon", png)
    for paso in (lambda: fuego(tex), humo, chispa):
        try: paso()
        except Exception: print("ERROR", traceback.format_exc())
    print("MATERIALES: fin")

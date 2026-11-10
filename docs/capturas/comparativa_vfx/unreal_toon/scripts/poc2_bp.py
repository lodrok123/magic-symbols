# Prueba 2 (fuego toon): BP_MuroFuegoToon en /Game/POC2/BP, mismo patrón que BP_MuroFuego de la prueba 1 (06_bp.py):
# NiagaraComponent girado 90 grados, variable Longitud, BeginPlay -> SetNiagaraVariableFloat(User.Longitud) -> SetRelativeScale3D.
import unreal as ue, traceback
BEL = ue.BlueprintEditorLibrary
SDS = ue.get_engine_subsystem(ue.SubobjectDataSubsystem)
SBL = ue.SubobjectDataBlueprintFunctionLibrary
BASE = "/Game/POC2/BP"
VFX = "/Game/POC2/VFX/"
ue.EditorAssetLibrary.make_directory(BASE)

def pin_in(n, nombre): return BEL.find_input_pin(n, nombre)
def pin_out(n, nombre): return BEL.find_output_pin(n, nombre)
def conectar(a, b, etiqueta=""):
    ok = a.try_create_connection(b) if (a and b and a.is_valid() and b.is_valid()) else False
    print("   conexion", etiqueta, "->", ok); return ok
def fijar(n, nombre, valor):
    p = pin_in(n, nombre); ok = p.set_pin_value(str(valor)) if p and p.is_valid() else False
    print("   pin", nombre, "=", valor, "->", ok); return ok
def subobjeto(bp, padre, clase):
    h, razon = SDS.add_new_subobject(ue.AddNewSubobjectParams(parent_handle=padre, new_class=clase, blueprint_context=bp))
    if str(razon): print("   add_new_subobject", clase.__name__, "razon:", razon)
    return h, SBL.get_object(SDS.k2_find_subobject_data_from_handle(h))
def raiz(bp):
    hs = SDS.k2_gather_subobject_data_for_blueprint(bp)
    return hs[0], hs[1]
def tipo_float():
    t = ue.EdGraphPinType(); t.import_text('(PinCategory="real",PinSubCategory="double")'); return t

def muro_toon():
    ruta = BASE + "/BP_MuroFuegoToon"
    if ue.EditorAssetLibrary.does_asset_exist(ruta):
        # ya existe (y el personaje lo referencia): no se borra, solo se vuelve a apuntar el componente al sistema
        bp = ue.load_asset(ruta)
        for h in SDS.k2_gather_subobject_data_for_blueprint(bp):
            o = SBL.get_object(SDS.k2_find_subobject_data_from_handle(h))
            if isinstance(o, ue.NiagaraComponent):
                o.set_editor_property("asset", ue.load_asset(VFX + "NS_MuroFuegoToon"))
                print("   componente existente re-apuntado:", o.get_name(), "->", o.get_editor_property("asset"))
        ok = BEL.compile_blueprint(bp)
        print("   compilado:", ok, "| guardado:", ue.EditorAssetLibrary.save_asset(ruta))
        return ok
    bp = BEL.create_blueprint_asset_with_parent(ruta, ue.Actor)
    print("== BP", ruta, bp is not None)
    h_actor, h_raiz = raiz(bp)
    h_nia, nia = subobjeto(bp, h_raiz, ue.NiagaraComponent)
    nia.set_editor_property("asset", ue.load_asset(VFX + "NS_MuroFuegoToon"))
    nia.set_editor_property("relative_rotation", ue.Rotator(0.0, 0.0, 90.0))
    g = BEL.find_event_graph(bp); ge = ue.BlueprintGraphEditor.get_graph_editor(g)
    print("   var Longitud:", ge.add_member_variable("Longitud", tipo_float(), "1.0"))
    begin = BEL.add_event_override(bp, "ReceiveBeginPlay", ue.IntPoint(0, 0))
    setf = ge.add_call_function_node("/Script/Niagara.NiagaraComponent:SetNiagaraVariableFloat")
    fijar(setf, "InVariableName", "User.Longitud")
    comp = nia.get_name().replace("_GEN_VARIABLE", "")
    getv = ge.add_get_member_variable_node("Longitud"); getc = ge.add_get_member_variable_node(comp)
    sets = ge.add_call_function_node("/Script/Engine.SceneComponent:SetRelativeScale3D")
    mkv = ge.add_call_function_node("/Script/Engine.KismetMathLibrary:MakeVector")
    for eje in ("X", "Y", "Z"): fijar(mkv, eje, "1.0")
    getv2 = ge.add_get_member_variable_node("Longitud"); getc2 = ge.add_get_member_variable_node(comp)
    conectar(pin_out(getv2, "Longitud"), pin_in(mkv, "X"), "var->makevector")
    conectar(pin_out(mkv, "ReturnValue"), pin_in(sets, "NewScale3D"), "vector->scale")
    conectar(BEL.find_output_pin_by_index(getc2, 0), BEL.find_self_pin(sets), "comp->target scale")
    conectar(BEL.find_then_pin(begin), BEL.find_execute_pin(setf), "begin->set")
    conectar(BEL.find_then_pin(setf), BEL.find_execute_pin(sets), "set->scale")
    conectar(pin_out(getv, "Longitud"), pin_in(setf, "InValue"), "var->InValue")
    conectar(BEL.find_output_pin_by_index(getc, 0), BEL.find_self_pin(setf), "comp->target")
    for n, (x, y) in ((begin, (0, 0)), (setf, (450, 0)), (getv, (200, 250)), (getc, (200, 150)), (sets, (900, 0)), (mkv, (650, 250)), (getv2, (450, 300)), (getc2, (650, 150))):
        if n: n.set_node_pos(ue.IntPoint(x, y))
    ok = BEL.compile_blueprint(bp)
    errs = ge.list_nodes_with_errors()
    print("   compilado:", ok, "| nodos con error:", [n.get_name() for n in errs])
    cdo = ue.get_default_object(bp.generated_class())
    cdo.set_editor_property("initial_life_span", 4.8)
    print("   guardado:", ue.EditorAssetLibrary.save_asset(ruta))
    return ok and not errs

try: print("RESULTADO BP_MuroFuegoToon:", muro_toon())
except Exception: print("ERR", traceback.format_exc())

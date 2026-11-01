# Prueba 2 (fuego toon): evento LanzarMuroToon y tecla 5 en el personaje, como 07_personaje.py (nodo InputKey clásico).
import unreal as ue, traceback
BEL = ue.BlueprintEditorLibrary
BASE = "/Game/POC2/BP"
PJ = "/Game/ThirdPerson/Blueprints/BP_ThirdPersonCharacter"
bp = ue.load_asset(PJ)
ge = ue.BlueprintGraphEditor.get_graph_editor(BEL.find_event_graph(bp))
def pin_in(n, nombre): return BEL.find_input_pin(n, nombre)
def pin_out(n, nombre): return BEL.find_output_pin(n, nombre)
def conectar(a, b, etiqueta=""):
    ok = a.try_create_connection(b) if (a and b and a.is_valid() and b.is_valid()) else False
    print("   conexion", etiqueta, "->", ok); return ok
def fijar(n, nombre, valor):
    p = pin_in(n, nombre); ok = p.set_pin_value(str(valor)) if p and p.is_valid() else False
    print("   pin", nombre, "=", valor, "->", ok); return ok
def fn(ruta): return ge.add_call_function_node(ruta)

evento, tecla, clase, z = "LanzarMuroToon", "5", "BP_MuroFuegoToon", -90.0
y = 1200 + 4 * 450
viejo = ge.find_event_node(evento)
if viejo:
    print("==", evento, "ya existe; se omite")
else:
    print("==", evento)
    ev = ge.add_custom_event_node(evento)
    key = ge.create_node_from_name("Entrada|KeyboardEvents|" + tecla, ue.Vector2D(0, y + 150), [], None)
    sp = ge.create_node_from_name("Juego|Generaractordesdeclase", ue.Vector2D(900, y), [], None)
    fijar(sp, "Class", "%s/%s.%s_C" % (BASE, clase, clase))
    loc = fn("/Script/Engine.Actor:K2_GetActorLocation")
    rot = fn("/Script/Engine.Actor:K2_GetActorRotation")
    fwd = fn("/Script/Engine.Actor:GetActorForwardVector")
    mul = fn("/Script/Engine.KismetMathLibrary:Multiply_VectorFloat")
    add = fn("/Script/Engine.KismetMathLibrary:Add_VectorVector")
    add2 = fn("/Script/Engine.KismetMathLibrary:Add_VectorVector")
    mk = fn("/Script/Engine.KismetMathLibrary:MakeTransform")
    conectar(pin_out(fwd, "ReturnValue"), pin_in(mul, "A"), "fwd->mul")
    alc = ge.add_get_member_variable_node("Alcance"); conectar(pin_out(alc, "Alcance"), pin_in(mul, "B"), "alcance->mul")
    conectar(pin_out(loc, "ReturnValue"), pin_in(add, "A"), "loc->add")
    conectar(pin_out(mul, "ReturnValue"), pin_in(add, "B"), "mul->add")
    conectar(pin_out(add, "ReturnValue"), pin_in(add2, "A"), "add->add2"); fijar(add2, "B", "0,0,%g" % z)
    conectar(pin_out(add2, "ReturnValue"), pin_in(mk, "Location"), "add2->loc")
    conectar(pin_out(rot, "ReturnValue"), pin_in(mk, "Rotation"), "rot->rot")
    conectar(pin_out(mk, "ReturnValue"), pin_in(sp, "SpawnTransform"), "mk->transform")
    conectar(BEL.find_then_pin(ev), BEL.find_execute_pin(sp), "evento->spawn")
    conectar(pin_out(key, "Pressed"), BEL.find_execute_pin(sp), "tecla->spawn")
    for n, (x, yy) in ((ev, (0, y)), (loc, (150, y + 300)), (fwd, (150, y + 400)), (rot, (150, y + 520)), (mul, (400, y + 400)), (alc, (250, y + 470)), (add, (550, y + 300)), (add2, (650, y + 350)), (mk, (750, y + 250))):
        if n: n.set_node_pos(ue.IntPoint(x, yy))
ok = BEL.compile_blueprint(bp)
errs = ge.list_nodes_with_errors()
print("compilado:", ok, "| nodos con error:", [n.get_name() for n in errs])
print("guardado:", ue.EditorAssetLibrary.save_asset(PJ))

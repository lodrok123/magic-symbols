"""Universal Animation Library (Quaternius, CC0) -> esqueleto con nombres Mixamo.

El GLB de Quaternius usa el maniquí de Unreal (pelvis, spine_01, thigh_l...). ClipsFamilia empareja los huesos
por NOMBRE con los de la jugadora (mixamorig_*), así que aquí solo se renombran los nodos del GLB: ni la malla,
ni el reposo, ni los clips cambian. El retarget de ClipsFamilia ya copia el MOVIMIENTO respecto al reposo, así que
la pose A del maniquí frente a la T del Y Bot no estorba. El hueso `root` (padre de la cadera, quieto en la versión
sin root motion) se queda, pero su giro de Z-arriba se mete en la cadera (`hornear_raiz`): la jugadora no lo tiene y el
retarget copia la traslación de la cadera en los ejes de su padre.

Uso (desde la raíz del repo):
    python -I tools/ual_a_mixamo.py "<carpeta del zip>/Unreal-Godot/UAL1_Standard.glb" arte/ual/ual1_standard_mixamo.glb
Usar UAL1_Standard.glb, NO el _RM (ese trae el desplazamiento metido en la raíz).
"""
import json
import struct
import sys

LADOS = {"l": "Left", "r": "Right"}
DEDOS = {"index": "Index", "middle": "Middle", "ring": "Ring", "pinky": "Pinky", "thumb": "Thumb"}
FIJOS = {
    "pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
    "neck_01": "Neck", "Head": "Head",
}
POR_LADO = {
    "clavicle": "Shoulder", "upperarm": "Arm", "lowerarm": "ForeArm", "hand": "Hand",
    "thigh": "UpLeg", "calf": "Leg", "foot": "Foot", "ball": "ToeBase", "ball_leaf": "Toe_End",
}


def nombre_mixamo(n):
    if n in FIJOS:
        return "mixamorig_" + FIJOS[n]
    base, _, lado = n.rpartition("_")
    if lado not in LADOS:
        return None
    if base in POR_LADO:
        return "mixamorig_" + LADOS[lado] + POR_LADO[base]
    # dedos: index_01_l ... index_04_leaf_l
    partes = base.split("_")
    if partes[0] in DEDOS and len(partes) >= 2 and partes[1].isdigit():
        return "mixamorig_%sHand%s%d" % (LADOS[lado], DEDOS[partes[0]], int(partes[1]))
    return None


def q_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz]


def q_rot(q, v):
    x, y, z, w = q_mul(q_mul(q, [v[0], v[1], v[2], 0.0]), [-q[0], -q[1], -q[2], q[3]])
    return [x, y, z]


def hornear_raiz(j, bin_):
    """El hueso `root` del maniquí está girado -90° en X (Unreal es Z arriba) y la cadera cuelga de él: la traslación de la
    cadera va en ejes Z-arriba. ClipsFamilia copia esa traslación tal cual al Hips de la jugadora (que cuelga del esqueleto,
    Y arriba) y la jugadora salía disparada en los clips que mueven la cadera (muerte, sentarse). Aquí el giro de `root` se
    mete DENTRO de la cadera (reposo y cada clave) y `root` queda neutro: las transformaciones globales no cambian, así que la
    malla y sus inverseBindMatrices siguen valiendo. Solo vale si `root` no está animado (versión sin root motion)."""
    nodos = j["nodes"]
    i_root = next(i for i, n in enumerate(nodos) if n.get("name") == "root")
    i_cad = next(i for i, n in enumerate(nodos) if n.get("name") == "mixamorig_Hips")
    r = nodos[i_root]
    q_r = r.get("rotation", [0.0, 0.0, 0.0, 1.0])
    assert r.get("translation", [0, 0, 0]) == [0, 0, 0] or all(abs(c) < 1e-6 for c in r.get("translation", [0, 0, 0]))
    assert all(abs(c - 1.0) < 1e-6 for c in r.get("scale", [1, 1, 1]))
    c = nodos[i_cad]
    c["translation"] = q_rot(q_r, c.get("translation", [0.0, 0.0, 0.0]))
    c["rotation"] = q_mul(q_r, c.get("rotation", [0.0, 0.0, 0.0, 1.0]))
    r["rotation"] = [0.0, 0.0, 0.0, 1.0]
    acc, vistas = j["accessors"], j["bufferViews"]
    hechos = set()
    for an in j.get("animations", []):
        for ch in an["channels"]:
            t = ch["target"]
            if t.get("node") == i_root and t["path"] in ("rotation", "translation"):
                # Las claves de root han de ser su reposo (quieto): se dejan neutras. Si se mueve, es el GLB con root motion.
                ai = an["samplers"][ch["sampler"]]["output"]
                if ai in hechos:
                    continue
                hechos.add(ai)
                a = acc[ai]
                n = 4 if t["path"] == "rotation" else 3
                v = vistas[a["bufferView"]]
                off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
                paso = v.get("byteStride", 4 * n)
                quieto = q_r if n == 4 else [0.0, 0.0, 0.0]
                neutro = [0.0, 0.0, 0.0, 1.0] if n == 4 else [0.0, 0.0, 0.0]
                for k in range(a["count"]):
                    val = struct.unpack_from("<%df" % n, bin_, off + k * paso)
                    igual = all(abs(x - y) < 1e-4 for x, y in zip(val, quieto)) or (n == 4 and all(abs(x + y) < 1e-4 for x, y in zip(val, quieto)))
                    if not igual:
                        raise SystemExit("el hueso root se mueve en «%s» (%s): usar el GLB sin _RM" % (an.get("name"), val))
                    struct.pack_into("<%df" % n, bin_, off + k * paso, *neutro)
                if "min" in a:
                    a["min"], a["max"] = list(neutro), list(neutro)
                continue
            if t.get("node") != i_cad or t["path"] not in ("rotation", "translation"):
                continue
            ai = an["samplers"][ch["sampler"]]["output"]
            if ai in hechos:
                continue
            hechos.add(ai)
            a = acc[ai]
            assert a["componentType"] == 5126, "se esperaban floats"
            n = 4 if t["path"] == "rotation" else 3
            v = vistas[a["bufferView"]]
            off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
            paso = v.get("byteStride", 4 * n)
            for k in range(a["count"]):
                o = off + k * paso
                val = list(struct.unpack_from("<%df" % n, bin_, o))
                nuevo = q_mul(q_r, val) if n == 4 else q_rot(q_r, val)
                struct.pack_into("<%df" % n, bin_, o, *nuevo)
            if n == 3 and "min" in a:      # los límites del accessor de traslación cambian de ejes
                vals = [struct.unpack_from("<3f", bin_, off + k * paso) for k in range(a["count"])]
                a["min"] = [min(x[e] for x in vals) for e in range(3)]
                a["max"] = [max(x[e] for x in vals) for e in range(3)]
    print("giro de root metido en la cadera (%d pistas)" % len(hechos))


def main(entrada, salida):
    datos = open(entrada, "rb").read()
    magia, version, _ = struct.unpack_from("<III", datos, 0)
    assert magia == 0x46546C67, "no es un GLB"
    ln_json, tipo = struct.unpack_from("<II", datos, 12)
    assert tipo == 0x4E4F534A
    j = json.loads(datos[20:20 + ln_json])
    resto = bytearray(datos[20 + ln_json:])          # cabecera del chunk BIN (8 bytes) + datos; se editan las claves de la cadera

    huesos = set(j["skins"][0]["joints"])
    sin_par = []
    for i in huesos:
        nodo = j["nodes"][i]
        nuevo = nombre_mixamo(nodo.get("name", ""))
        if nuevo is None:
            sin_par.append(nodo.get("name"))
            continue
        nodo["name"] = nuevo
    print("huesos renombrados: %d · sin pareja (se quedan igual): %s" % (len(huesos) - len(sin_par), sin_par))
    nombres = [j["nodes"][i]["name"] for i in huesos]
    assert len(nombres) == len(set(nombres)), "nombres repetidos tras renombrar"

    bin_ = memoryview(resto)[8:]
    hornear_raiz(j, bin_)
    bin_.release()

    nuevo_json = json.dumps(j, separators=(",", ":")).encode("utf-8")
    nuevo_json += b" " * ((4 - len(nuevo_json) % 4) % 4)
    total = 12 + 8 + len(nuevo_json) + len(resto)
    with open(salida, "wb") as f:
        f.write(struct.pack("<III", magia, version, total))
        f.write(struct.pack("<II", len(nuevo_json), 0x4E4F534A))
        f.write(nuevo_json)
        f.write(resto)
    print("escrito %s (%d animaciones)" % (salida, len(j.get("animations", []))))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

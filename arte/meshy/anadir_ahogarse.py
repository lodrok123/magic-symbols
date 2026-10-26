#!/usr/bin/env python3
"""Añade el clip «Drowning» (ahogarse) a un GLB de goblin con esqueleto Mixamo (28 huesos).

Por qué existe: PLAN_EOW A3/PL1. Cuando un goblin cae al agua honda, el Juego lo hunde; hasta ahora no
había animación y se hundía rígido. Mixamo/Meshy no son accesibles desde el sandbox, así que el clip se
GENERA con código sobre el esqueleto que ya tiene el goblin, en vez de bajarlo. Si un día se consigue un
clip real (Mixamo «Drowning»/«Treading Water»), basta con llamarlo igual en el GLB y este script sobra.

Cómo funciona (cuerpo del clip en `pose()`):
  - Base = el primer fotograma de `Idle` del propio GLB (la pose de reposo buena del modelo).
  - Cada hueso recibe un «delta» en EJES DEL MODELO (X = izquierda del personaje, Y = arriba, Z = delante),
    no en ejes locales del hueso: los de Mixamo están torcidos y escribir ángulos locales a ciegas sale mal.
    El delta se acumula por la cadena (inclinar la columna arrastra los brazos), igual que a mano.
  - Cinemática directa para pasar de eso a la rotación local que guarda glTF.

Uso:  python anadir_ahogarse.py entrada.glb [salida.glb]    (sin salida: sobrescribe la entrada)
Es idempotente: si el GLB ya trae `Drowning`, lo sustituye.
"""
import json
import struct
import sys
import numpy as np
from scipy.spatial.transform import Rotation as R

NOMBRE = "Drowning"
DURACION = 3.2          # s. Más largo que el hundimiento del Juego: el último fotograma es una pose que se aguanta.
FPS = 30


def leer_glb(ruta):
    d = open(ruta, "rb").read()
    lj = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + lj])
    lb = struct.unpack("<I", d[20 + lj:24 + lj])[0]
    b = bytearray(d[28 + lj:28 + lj + lb])
    return j, b


def escribir_glb(ruta, j, b):
    while len(b) % 4:
        b.append(0)
    j["buffers"][0]["byteLength"] = len(b)
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(b)
    with open(ruta, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(b), b"BIN\0") + bytes(b))


def leer_acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(bytes(b), dtype="<f4", count=a["count"] * n, offset=off).reshape(a["count"], n)


def añadir_acc(j, b, datos, tipo, minmax=False):
    datos = np.ascontiguousarray(datos, dtype="<f4")
    while len(b) % 4:
        b.append(0)
    off = len(b)
    b.extend(datos.tobytes())
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": datos.nbytes})
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(datos), "type": tipo}
    if minmax:
        a["min"] = [float(datos.min())]
        a["max"] = [float(datos.max())]
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def suave(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def rv(x=0.0, y=0.0, z=0.0):
    """Rotación en ejes del modelo a partir de grados por eje (vector de rotación)."""
    return R.from_rotvec(np.radians([x, y, z]))


def deltas(t):
    """Delta en ejes del modelo de cada hueso (sin prefijo mixamorig:) y desplazamiento de la cadera, en el instante t.

    Tres fases: 0–0.35 s pasa del reposo al pánico; hasta ~2.1 s braceo y pataleo (frecuencia ~2 Hz); después
    se agota (la amplitud baja a 0) y queda con los brazos arriba, la cabeza hacia atrás y la cadera algo más baja.
    """
    entra = suave(t / 0.35)                       # 0 → 1: sale del reposo
    agota = suave((t - 1.9) / 1.0)                # 0 → 1: pierde fuerza
    pan = entra * (1.0 - agota)                   # intensidad del braceo
    w = 2 * np.pi * 2.1 * t
    inclina = 10 + 12 * agota                     # el cuerpo se echa hacia atrás (rotación negativa en X = hacia atrás)
    d = {}
    # Columna: echada atrás y balanceándose de lado a lado.
    d["Spine"] = rv(-inclina * 0.4 * entra, 0, 5 * pan * np.sin(w * 0.5))
    d["Spine1"] = rv(-inclina * 0.4 * entra, 4 * pan * np.sin(w * 0.5 + 1), 4 * pan * np.sin(w * 0.5))
    d["Spine2"] = rv(-inclina * 0.3 * entra, 0, 0)
    # Cabeza: hacia atrás (boca fuera del agua) y sacudiéndose.
    d["Neck"] = rv(-12 * entra, 8 * pan * np.sin(w * 0.7), 0)
    d["Head"] = rv(-(14 + 14 * agota) * entra, 10 * pan * np.sin(w * 0.7 + 0.6), 6 * pan * np.sin(w * 0.5))
    # Brazos: arriba y afuera (rotación en Z: la izquierda del personaje sube con +, la derecha con −), braceando a contrafase.
    base_alto = 105 + 55 * agota                  # de 105º a 160º: acaba casi vertical
    izq = base_alto + 38 * pan * np.sin(w)
    der = base_alto + 38 * pan * np.sin(w + 2.5)
    d["LeftArm"] = rv(-12 * pan * np.cos(w + 1), 0, izq * entra)
    d["RightArm"] = rv(-12 * pan * np.cos(w + 3.5), 0, -der * entra)
    # Antebrazos: manotazos (se doblan hacia delante y vuelven).
    d["LeftForeArm"] = rv(-(12 + 22 * np.sin(w + 0.5)) * pan, 0, 0)
    d["RightForeArm"] = rv(-(12 + 22 * np.sin(w + 3.0)) * pan, 0, 0)
    d["LeftHand"] = rv(0, 0, 20 * pan * np.sin(w * 1.5))
    d["RightHand"] = rv(0, 0, -20 * pan * np.sin(w * 1.5 + 1))
    # Piernas: patalean como pedaleando, a contrafase (rotación en X: + las lleva hacia delante).
    pat_i = 38 * pan * np.sin(w * 0.9)
    pat_d = 38 * pan * np.sin(w * 0.9 + np.pi)
    d["LeftUpLeg"] = rv(pat_i + 12 * entra, 0, 4 * entra)
    d["RightUpLeg"] = rv(pat_d + 12 * entra, 0, -4 * entra)
    d["LeftLeg"] = rv(-(20 + 25 * np.maximum(0, -np.sin(w * 0.9 + 0.4))) * pan, 0, 0)
    d["RightLeg"] = rv(-(20 + 25 * np.maximum(0, np.sin(w * 0.9 + 0.4))) * pan, 0, 0)
    # Cadera: sube y baja al patalear y acaba 12 cm más baja (el hundimiento real lo hace el Juego bajando el nodo).
    dy = 0.035 * pan * np.sin(w * 0.9 * 2) - 0.12 * agota * entra
    dz = -0.05 * entra                            # un poco hacia atrás
    return d, np.array([0.0, dy, dz])


def construir(j, b):
    nodos = j["nodes"]
    por_nombre = {n["name"].replace("mixamorig:", ""): i for i, n in enumerate(nodos) if "name" in n}
    padre = {}
    for i, n in enumerate(nodos):
        for c in n.get("children", []):
            padre[c] = i
    huesos = [h for h in j["skins"][0]["joints"]]
    # Pose base = fotograma 0 de Idle.
    idle = next(a for a in j["animations"] if a["name"] == "Idle")
    q0, p0 = {}, None
    for c in idle["channels"]:
        s = idle["samplers"][c["sampler"]]
        if c["target"]["path"] == "rotation":
            q0[c["target"]["node"]] = leer_acc(j, b, s["output"])[0]
        elif c["target"]["path"] == "translation" and nodos[c["target"]["node"]]["name"].endswith("Hips"):
            p0 = leer_acc(j, b, s["output"])[0]
    for h in huesos:
        q0.setdefault(h, np.array(nodos[h]["rotation"]))
    raiz = por_nombre["Hips"]
    # Orden padre → hijo.
    orden, cola = [], [raiz]
    while cola:
        n = cola.pop(0)
        orden.append(n)
        cola.extend([c for c in nodos[n].get("children", []) if c in huesos])
    n_f = int(round(DURACION * FPS)) + 1
    tiempos = np.arange(n_f) / FPS
    rot = {h: np.zeros((n_f, 4)) for h in huesos}
    pos_cadera = np.zeros((n_f, 3))
    for k, t in enumerate(tiempos):
        d, dp = deltas(t)
        mundo = {}
        for n in orden:
            nom = nodos[n]["name"].replace("mixamorig:", "")
            loc0 = R.from_quat(q0[n])
            dm = d.get(nom, R.identity())
            if n == raiz:
                wp = R.identity()
                mundo[n] = dm * loc0
                loc = mundo[n]
            else:
                wp = mundo[padre[n]]
                mundo[n] = dm * wp * loc0
                loc = wp.inv() * mundo[n]
            rot[n][k] = loc.as_quat()
        pos_cadera[k] = p0 + dp
    # Continuidad de signo del cuaternión (evita el giro largo al interpolar).
    for h in huesos:
        for k in range(1, n_f):
            if np.dot(rot[h][k], rot[h][k - 1]) < 0:
                rot[h][k] = -rot[h][k]
    return tiempos, rot, pos_cadera, raiz, huesos


def main():
    entrada = sys.argv[1]
    salida = sys.argv[2] if len(sys.argv) > 2 else entrada
    j, b = leer_glb(entrada)
    j["animations"] = [a for a in j["animations"] if a["name"] != NOMBRE]
    tiempos, rot, pos, raiz, huesos = construir(j, b)
    a_t = añadir_acc(j, b, tiempos.astype("<f4"), "SCALAR", True)
    samplers, canales = [], []
    for h in huesos:
        a_r = añadir_acc(j, b, rot[h], "VEC4")
        samplers.append({"input": a_t, "interpolation": "LINEAR", "output": a_r})
        canales.append({"sampler": len(samplers) - 1, "target": {"node": h, "path": "rotation"}})
    a_p = añadir_acc(j, b, pos, "VEC3")
    samplers.append({"input": a_t, "interpolation": "LINEAR", "output": a_p})
    canales.append({"sampler": len(samplers) - 1, "target": {"node": raiz, "path": "translation"}})
    j["animations"].append({"name": NOMBRE, "samplers": samplers, "channels": canales})
    escribir_glb(salida, j, b)
    print(f"{salida}: «{NOMBRE}» {len(tiempos)} fotogramas, {DURACION:.2f} s, {len(huesos)} huesos")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Saca los clips de la jugadora de «woodland_all.glb» (Meshy, esqueleto antiguo de la elfa: 28 huesos `mixamorig`) a un GLB ligero: solo esqueleto y animaciones.

Por qué existe: Pablo generó en Meshy siete clips nuevos de la jugadora (abrir un cofre, agacharse, ofrecer la mano, saludar, empujar andando, correr, andar) con el
esqueleto ligero de la elfa. El GLB entero pesa 25 MB (la malla de woodland con sus texturas); aquí solo se quedan los clips, recortados y con nombres claros, para que
`jugador/clips_familia.gd` los lea y los pase (retarget por pose de reposo) a la jugadora actual (woodland_wanderer, chibi_elf) y a `jugadora_base`.

Qué hace con cada clip: lo RECORTA al tramo útil (INICIO..FIN, en segundos del clip original, con fotogramas nuevos interpolados en los bordes y el tiempo empezando en 0),
lo RENOMBRA y, si se pide, quita el avance de la cadera (el Juego mueve al personaje) dejando x/z en lo que valían al empezar el clip original. Las pistas de traslación de los demás huesos no las lee nadie
y se quitan. Después pasa `solo_clips.py` (fuera mallas, materiales y texturas).

Uso:  python clips_jugadora.py entrada.glb salida.glb
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

import solo_clips

# nombre en el GLB de Meshy -> (nombre nuevo, INICIO s, FIN s, quitar el avance de la cadera). FIN < 0 = hasta el final del clip.
INICIO_FIN: dict = {
    # Se inclina y baja las dos manos: de 0 a 0,8 s solo se inclina un poco de pie (se quita); las manos llegan abajo hacia 2,2 s (en el clip recortado, 1,4 s) y se alzan de 3,0 a 3,5 s;
    # de 3,6 a 4,97 s se queda quieta agachada (se quita: el Juego la mantiene el rato que quiera).
    "_01a16a0a_a420_76b6_9b5f_76d31376a982": ("AbrirCofre", 0.8, 3.6, False),
    # Se agacha con las manos juntas y se levanta: del fotograma 0 a 3,5 s (después solo se reajusta de pie).
    "_01a16a11_c386_7572_8afe_336bd05616c7": ("Agacharse", 0.0, 3.5, False),
    # De pie, adelanta la mano derecha con la palma abierta (hablar / ofrecer).
    "_01a16a0c_08c6_73f8_9b63_1aab2dc2e3ee": ("Ofrecer", 0.0, -1.0, False),
    "Personalized_Gesture": ("Saludo", 0.0, -1.0, False),
    # Empuja andando 8 s y avanza 2,65 de cadera: se arranca, anda a ritmo constante de 2,7 a 6,5 s y se para. El tramo 3,67..5,30 es UN ciclo de paso (dos pasos, 1,63 s) cuyo
    # final casa con su principio (se buscó el ciclo con menor distancia de pose entre fotogramas: ~0,07 rad por hueso de media, altura de cadera igual a 3 mm); se usa de bucle y sin avance.
    "Push_and_Walk_Forward": ("Empujar", 3.67, 5.30, True),
    # Correr y andar ya van en el sitio (la cadera vuelve al punto de partida cada ciclo): se dejan como vienen, con su balanceo.
    "Running": ("Correr", 0.0, -1.0, False),
    "Walking": ("Andar", 0.0, -1.0, False),
}
HUESO_CADERA: str = "mixamorig:Hips"


def accesor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
    ini = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(b[ini:ini + a["count"] * n * 4], dtype="<f4").reshape(a["count"], n).copy()


def recortar(t, v, ini, fin, rot):
    """Recorta una pista (t: tiempos, v: valores) a [ini, fin] con bordes interpolados; los tiempos pasan a empezar en 0."""
    def en(x):
        i = int(np.clip(np.searchsorted(t, x), 1, len(t) - 1))
        f = float(np.clip((x - t[i - 1]) / max(t[i] - t[i - 1], 1e-9), 0.0, 1.0))
        a, c = v[i - 1], v[i]
        if rot:
            if float(np.dot(a, c)) < 0.0:
                c = -c
            r = a * (1.0 - f) + c * f
            return r / np.linalg.norm(r)
        return a * (1.0 - f) + c * f
    dentro = [(tt, vv) for tt, vv in zip(t, v) if ini + 1e-6 < tt < fin - 1e-6]
    ts = [ini] + [d[0] for d in dentro] + [fin]
    vs = [en(ini)] + [d[1] for d in dentro] + [en(fin)]
    return np.array(ts, dtype="<f4") - np.float32(ini), np.array(vs, dtype="<f4")


def main(entrada, salida):
    j, b = solo_clips.leer(entrada)
    nodos = j["nodes"]
    nuevo_bin = bytearray(b)

    def añadir(arr, tipo, minmax):
        while len(nuevo_bin) % 4:
            nuevo_bin.append(0)
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(nuevo_bin), "byteLength": arr.nbytes})
        nuevo_bin.extend(arr.tobytes())
        a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": int(arr.shape[0]), "type": tipo}
        if minmax:
            a["min"], a["max"] = [float(arr.min())], [float(arr.max())]
        j["accessors"].append(a)
        return len(j["accessors"]) - 1

    nuevas = []
    for an in j["animations"]:
        if an["name"] not in INICIO_FIN:
            continue
        nombre, ini, fin, sin_avance = INICIO_FIN[an["name"]]
        canales, muestreadores, cache = [], [], {}
        for ch in an["channels"]:
            nodo = nodos[ch["target"]["node"]]["name"]
            ruta = ch["target"]["path"]
            if ruta == "translation" and nodo != HUESO_CADERA:
                continue
            if ruta == "scale":
                continue
            smp = an["samplers"][ch["sampler"]]
            t = accesor(j, b, smp["input"])[:, 0]
            v = accesor(j, b, smp["output"])
            fin_c = float(t[-1]) if fin < 0.0 else fin
            ts, vs = recortar(t, v, ini, fin_c, ruta == "rotation")
            if ruta == "translation" and sin_avance:
                # x/z quedan en lo que valían al EMPEZAR el clip original (de pie, antes de arrancar), no en su media: la media incluye todo lo que avanzó
                vs[:, 0] = v[0][0]
                vs[:, 2] = v[0][2]
            clave = (smp["input"], len(ts))
            if clave not in cache:
                cache[clave] = añadir(ts.reshape(-1, 1), "SCALAR", True)
            muestreadores.append({"input": cache[clave], "output": añadir(vs, "VEC4" if ruta == "rotation" else "VEC3", False), "interpolation": "LINEAR"})
            canales.append({"sampler": len(muestreadores) - 1, "target": ch["target"]})
        nuevas.append({"name": nombre, "channels": canales, "samplers": muestreadores})
        print(f"{an['name']} -> {nombre}: {ini:.2f}..{fin if fin >= 0 else 'fin'} ({len(canales)} pistas)")
    j["animations"] = nuevas
    j["buffers"] = [{"byteLength": len(nuevo_bin)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(nuevo_bin) % 4:
        nuevo_bin.append(0)
    j["buffers"] = [{"byteLength": len(nuevo_bin)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(nuevo_bin)
    temporal = Path(salida).with_suffix(".tmp.glb")
    temporal.write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
                         + struct.pack("<II", len(nuevo_bin), 0x004E4942) + bytes(nuevo_bin))
    solo_clips.main(str(temporal), salida)
    temporal.unlink()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

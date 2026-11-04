#!/usr/bin/env python3
"""Saca los clips de COGER, CARGAR y LANZAR de la jugadora de «Meshy_AI_Willow_Fernstep_..._animated_mixamo_All_animation.glb» (Meshy «Willow Fernstep» pasada a Mixamo: la MISMA
jugadora que arte/modelos/jugadora_base.glb, 65 huesos `mixamorig` + headfront) a un GLB ligero: solo esqueleto y animaciones, con los nombres de ROL de jugador/pj_3d.gd.

Por qué existe: la capa procedural BrazosCarga3D no podía poner las manos sobre la cabeza ni dar una sensación de peso (docs/RECOGER_LANZAR_2026-11-04.md §2). Pablo generó en Meshy estos
clips y aquí se recortan, se renombran y se retocan (en el sitio, sin avance de cadera) igual que arte/meshy/clips_jugadora.py hizo con los de la elfa vieja. Después pasa `solo_clips.py`
(fuera malla, materiales y texturas: el GLB de 20 MB con la malla NO entra en el repo; el resultado pesa ~0,2 MB).

Clips (nombre en el GLB de Meshy -> rol; segundos del clip ORIGINAL, medidos con la cinemática directa de los huesos: arte/meshy/medir_clips_carga.py):
  _01a1a760_...  quieta con las dos manos sobre la cabeza (2,97 s)                       -> CargarIdle    (bucle)
  _01a1a75f_...  anda con las manos arriba; arranca quieta hasta ~1 s y avanza la cadera  -> CargarAndar   (el ciclo de paso 1,2..2,13 s, el de menor distancia de pose entre sus extremos
                 0,75 m: se QUITA el avance (tendencia lineal de x/z de la cadera)          0,04 rad por hueso; en el sitio, para bucle)
  _01a1a757_...  manos sobre la cabeza, las echa atrás y las lanza al frente (suelta a    -> LanzarObjeto (0,85..2,0 s: anticipación, suelta a 1,28 s y remate; después solo baja las manos)
                 1,28 s: el pico de velocidad de las manos es a 1,27 s, 5,3 u/s)
  _01a1a75d_...  manos arriba, se agacha, deja el objeto en el suelo (manos abajo desde    -> DejarObjeto  (0,65..2,967 s; las manos tocan el suelo a 1,85 s)
                 ~1,8 s) y se levanta. OJO: todo el cuerpo está 0,17 más alto que en el resto de clips (cadera 1,02 en vez de 0,85, los pies a 0,30 en vez de 0,13: flota entera, no es
                 solo de puntillas): lo corrige `plantar` de ClipsFamilia (suela al suelo en cada fotograma, como Agacharse)
  el MISMO al revés                                                                       -> Levantar     (se agacha, coge del suelo y lo sube sobre la cabeza: 1,0..2,967 s al revés; las manos llegan abajo a 0,67 s)
  Female_Crouch_Pick_Throw_Forward (4,87 s): se agacha, coge con la derecha, paso al      -> CogerLanzar  (0,25..3,5 s: agachada con la mano a 0,31 hacia 1,0 s, suelta con la derecha a 2,42 s;
                 frente y lanza por arriba                                                   después solo recoloca los pies)
Walking y Running no se importan (la jugadora ya los tiene).

Uso:  python clips_carga.py entrada.glb salida.glb      (p. ej. arte/meshy/jugadora_carga_clips.glb)
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

import clips_jugadora
import solo_clips

# nombre en el GLB de Meshy -> lista de (nombre nuevo, INICIO s, FIN s, quitar el avance de la cadera, invertir el tiempo). FIN < 0 = hasta el final del clip.
CLIPS: dict = {
    "_01a1a760_acb2_73c5_aeec_dab0ca26aae7": [("CargarIdle", 0.0, -1.0, False, False)],
    "_01a1a75f_31f9_71ed_9be6_00a472ca0ce1": [("CargarAndar", 1.20, 2.13, True, False)],
    "_01a1a757_c763_7136_9350_6746fedb1697": [("LanzarObjeto", 0.85, 2.0, False, False)],
    "_01a1a75d_b01c_723e_9d10_08af8b9d6627": [("DejarObjeto", 0.65, -1.0, False, False), ("Levantar", 1.0, -1.0, False, True)],
    "Female_Crouch_Pick_Throw_Forward": [("CogerLanzar", 0.25, 3.5, False, False)],
}
HUESO_CADERA: str = "mixamorig:Hips"


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
        if an["name"] not in CLIPS:
            continue
        for nombre, ini, fin, sin_avance, invertir in CLIPS[an["name"]]:
            canales, muestreadores, cache = [], [], {}
            for ch in an["channels"]:
                nodo = nodos[ch["target"]["node"]]["name"]
                ruta = ch["target"]["path"]
                if ruta == "translation" and nodo != HUESO_CADERA:
                    continue
                if ruta == "scale":
                    continue
                smp = an["samplers"][ch["sampler"]]
                t = clips_jugadora.accesor(j, b, smp["input"])[:, 0]
                v = clips_jugadora.accesor(j, b, smp["output"])
                fin_c = float(t[-1]) if fin < 0.0 else fin
                ts, vs = clips_jugadora.recortar(t, v, ini, fin_c, ruta == "rotation")
                if ruta == "translation" and sin_avance:
                    # quita la TENDENCIA lineal de x/z (lo que avanza la cadera en el tramo) y deja el balanceo; el principio y el final del ciclo quedan al mismo sitio, en el x/z
                    # que tenía la cadera al EMPEZAR el clip original (de pie, centrada), como hizo clips_jugadora.py con Empujar
                    k = ts / max(float(ts[-1]), 1e-9)
                    for eje in (0, 2):
                        vs[:, eje] = vs[:, eje] - (vs[-1, eje] - vs[0, eje]) * k - vs[0, eje] + v[0][eje]
                if invertir:
                    ts = (ts[-1] - ts[::-1]).astype("<f4")
                    vs = vs[::-1].copy()
                clave = (smp["input"], len(ts))
                if clave not in cache:
                    cache[clave] = añadir(ts.reshape(-1, 1), "SCALAR", True)
                muestreadores.append({"input": cache[clave], "output": añadir(vs, "VEC4" if ruta == "rotation" else "VEC3", False), "interpolation": "LINEAR"})
                canales.append({"sampler": len(muestreadores) - 1, "target": ch["target"]})
            nuevas.append({"name": nombre, "channels": canales, "samplers": muestreadores})
            print(f"{an['name']} -> {nombre}: {ini:.2f}..{fin if fin >= 0 else 'fin'}{' (al revés)' if invertir else ''}{' (en el sitio)' if sin_avance else ''} ({len(canales)} pistas)")
    j["animations"] = nuevas
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

#!/usr/bin/env python3
"""Sonido propio del PULSO RESONANTE (26/10, Juego; docs/PLAN_PULSO_RESONANTE.md §9). Lo usan `Pulso3D.SFX_PULSO` y todo lo que responde al pulso (estatuas,
pared hueca, prisma, setas, cofre legendario), cada uno con su tono (`Sfx.play(..., tono)` = pitch_scale: de 0,38 a 1,8), así que el sonido tiene que aguantar
bien tanto grave como agudo.
Solo biblioteca estándar (sin numpy): `python audio/gen_sfx_pulso.py` (o `blender -b -P audio/gen_sfx_pulso.py`). 44,1 kHz, mono, 16 bits, igualado en RMS
(el volumen real lo dice el CATALOGO de nucleo/sfx.gd). Primera versión: SE AFINA ESCUCHANDO.
  pulso_resonante.wav   cristal que vibra: un zumbido grave que hincha y se apaga, y encima una campana de cristal (parciales no armónicos) con un
                        segundo juego detunado que da el brillo de batido («late» como el pulso).
"""
import math, os, struct, wave

SR = 44100
DUR = 1.5


def pulso_resonante():
    n = int(SR * DUR)
    x = [0.0] * n
    f0 = 330.0
    # La campana de cristal: (múltiplo, amplitud, caída por segundo). Parciales no armónicos = vidrio, no campana de iglesia.
    campana = ((1.0, 1.0, 3.2), (2.0, 0.42, 4.5), (2.76, 0.30, 6.0), (4.07, 0.16, 9.0), (5.4, 0.09, 13.0))
    for mult, amp, caida in campana:
        for desafino, peso in ((1.0, 1.0), (1.006, 0.55)):          # el gemelo detunado hace el batido lento (≈2 Hz en el fundamental)
            w = 2 * math.pi * f0 * mult * desafino / SR
            for i in range(n):
                t = i / SR
                ataque = min(1.0, t / 0.003)
                x[i] += math.sin(w * i) * amp * peso * math.exp(-caida * t) * ataque
    # El zumbido grave: dos octavas por debajo, hincha rápido y se apaga más lento (el «late» del cristal).
    w = 2 * math.pi * (f0 / 4) / SR
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.06) * math.exp(-2.4 * t)
        x[i] += math.sin(w * i) * 0.9 * env * (1.0 + 0.25 * math.sin(2 * math.pi * 6.0 * t))
    return x


def guardar(nombre, x, rms_obj=0.12):
    media = sum(x) / len(x)
    x = [v - media for v in x]
    rms = math.sqrt(sum(v * v for v in x) / len(x)) + 1e-9
    x = [v * rms_obj / rms for v in x]
    pico = max(abs(v) for v in x)
    if pico > 0.95:
        x = [v * 0.95 / pico for v in x]
    fade = int(SR * 0.006)
    for i in range(fade):
        x[-1 - i] *= i / fade
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in x))
    print(nombre, round(len(x) / SR, 2), "s")


if __name__ == "__main__":
    guardar("pulso_resonante.wav", pulso_resonante())

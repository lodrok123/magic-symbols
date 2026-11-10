#!/usr/bin/env python3
"""Jingles de la RESPUESTA POSITIVA al jugador (21/10, Juego; PLAN_EOW_VISUAL §4). Los elige la tabla `Logros3D.TABLA` por el nombre del logro.
Solo biblioteca estándar (sin numpy): `python audio/gen_sfx_logros.py`. Campanas sintetizadas (parciales casi armónicos con caída exponencial),
44,1 kHz, mono, 16 bits, igualadas en RMS (el volumen real lo dice el CATALOGO de nucleo/sfx.gd). Primera versión: SE AFINA ESCUCHANDO.
  logro_pista.wav     una sola nota suave y corta («vas bien»: parte del puzle resuelta)
  logro_acierto.wav   arpegio ascendente do-mi-sol («lo has resuelto»)
  logro_brillo.wav    destello agudo con notas muy seguidas (aparece el cofre)
  logro_fanfarria.wav arpegio largo do-mi-sol-do con acorde final (cofre abierto, nivel completado)
"""
import math, os, struct, wave
from random import Random

SR = 44100


def campana(f, dur, vol=1.0, parciales=((1.0, 1.0, 5.0), (2.0, 0.45, 8.0), (3.01, 0.22, 12.0), (4.2, 0.1, 18.0))):
    """Una nota de campana: cada parcial = (múltiplo, amplitud, caída por segundo)."""
    n = int(SR * dur)
    out = [0.0] * n
    for mult, amp, caida in parciales:
        w = 2 * math.pi * f * mult / SR
        for i in range(n):
            t = i / SR
            ataque = min(1.0, t / 0.004)
            out[i] += math.sin(w * i) * amp * math.exp(-caida * t) * ataque * vol
    return out


def mezclar(destino, notas, inicio):
    i0 = int(SR * inicio)
    if len(destino) < i0 + len(notas):
        destino.extend([0.0] * (i0 + len(notas) - len(destino)))
    for i, v in enumerate(notas):
        destino[i0 + i] += v


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


DO5, MI5, SOL5, DO6, MI6 = 523.25, 659.25, 783.99, 1046.5, 1318.5


def logro_pista():
    return campana(MI6, 0.45, 1.0, ((1.0, 1.0, 9.0), (2.0, 0.25, 14.0)))


def logro_acierto():
    x = []
    for k, f in enumerate((DO5, MI5, SOL5)):
        mezclar(x, campana(f, 0.9), 0.09 * k)
    return x


def logro_brillo():
    x = []
    for k, f in enumerate((SOL5, DO6, MI6, 2 * SOL5)):
        mezclar(x, campana(f, 0.5, 0.8, ((1.0, 1.0, 10.0), (2.7, 0.35, 16.0))), 0.055 * k)
    return x


def logro_fanfarria():
    x = []
    for k, f in enumerate((DO5, MI5, SOL5, DO6)):
        mezclar(x, campana(f, 1.2), 0.11 * k)
    for f in (DO5, MI5, SOL5, DO6):
        mezclar(x, campana(f, 1.6, 0.7), 0.5)
    return x


def objetivo_cumplido():
    x = campana(DO5, 0.20, 0.55)
    mezclar(x, campana(MI5, 0.25), 0.075)
    return x


def puzle_resuelto():
    x = []
    for inicio, frecuencia, duracion, volumen in (
        (0.00, DO5, 0.28, 0.75),
        (0.09, MI5, 0.30, 0.85),
        (0.19, DO6, 0.53, 1.00),
    ):
        mezclar(x, campana(frecuencia, duracion, volumen), inicio)
    return x


def mision_completada():
    x = campana(SOL5 / 2, 0.30, 0.8)
    mezclar(x, campana(MI5, 0.35, 0.85), 0.14)
    for frecuencia, volumen in ((DO5 / 2, 0.65), (DO5, 1.0), (SOL5, 0.45)):
        mezclar(x, campana(frecuencia, 0.75, volumen), 0.30)
    return x


def cofre_revelado():
    parciales = ((1.0, 1.0, 9.0), (2.0, 0.30, 16.0), (3.7, 0.18, 25.0))
    x = campana(SOL5, 0.22, 0.7, parciales)
    mezclar(x, campana(MI6, 0.36, 1.0, parciales), 0.06)
    return x


def brasero_linde(resuelto=False):
    # Un roce seco que da paso al mismo pulso de metal en los dos braseros.
    azar = Random(19)
    roce = []
    anterior = 0.0
    for i in range(int(SR * 0.085)):
        t = i / SR
        grano = azar.uniform(-1.0, 1.0)
        envolvente = math.sin(math.pi * t / 0.085) ** 2
        roce.append(0.16 * (grano - anterior) * envolvente)
        anterior = grano
    metal = ((1.0, 1.0, 8.0), (2.76, 0.24, 19.0), (4.08, 0.14, 28.0))
    mezclar(roce, campana(SOL5, 0.34, 0.8, metal), 0.042)
    if resuelto:
        mezclar(roce, campana(DO5, 0.66, 1.0, metal), 0.16)
    return roce


if __name__ == "__main__":
    guardar("logro_pista.wav", logro_pista())
    guardar("logro_acierto.wav", logro_acierto())
    guardar("logro_brillo.wav", logro_brillo())
    guardar("logro_fanfarria.wav", logro_fanfarria())
    guardar("objetivo_cumplido.wav", objetivo_cumplido(), 0.10)
    guardar("puzle_resuelto.wav", puzle_resuelto())
    guardar("mision_completada.wav", mision_completada())
    guardar("cofre_revelado.wav", cofre_revelado(), 0.10)
    guardar("brasero_linde_paso.wav", brasero_linde(), 0.09)
    guardar("brasero_linde_resuelto.wav", brasero_linde(True), 0.12)

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


if __name__ == "__main__":
    guardar("logro_pista.wav", logro_pista())
    guardar("logro_acierto.wav", logro_acierto())
    guardar("logro_brillo.wav", logro_brillo())
    guardar("logro_fanfarria.wav", logro_fanfarria())

"""Recorta y pasa a mono 44,1 kHz los sonidos elegidos del «Magic Spell Full Pack» de Leonardo Calvo (CC BY 4.0) y los escribe en audio/ con prefijo lc_.
A diferencia del lote de Sonniss, estos SÍ van en el repositorio (la licencia deja redistribuir citando al autor: audio/LICENCIAS.md).
Uso: python procesa_magic_spell.py <carpeta con los ogg de 48 kHz del pack> <carpeta audio del juego>

Las pistas del pack duran de 2 a 7 s, con cola larga. El recorte es automático: arranca en el primer punto con señal y corta donde la envolvente cae
`CAIDA_DB` por debajo del pico (después del pico), con un tope de duración por sonido y un fundido de salida. El volumen se iguala al RMS del archivo
que sustituye («como»), con el pico tope a −1 dB; sin «como», pico a −3 dB."""
import os, sys
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
from math import gcd

BASE = "\\\\?\\" + os.path.abspath(sys.argv[1])
DEST = os.path.abspath(sys.argv[2])
SR = 44100
CAIDA_DB = 26.0

# entrada del catálogo: (pistas del pack sin «.ogg», tope en s, fundido de salida en s, archivo de audio/ cuyo RMS se iguala o None)
ELEGIDOS = {
    "fuego":        (["fire_spell_fireball_burst_warm_01", "fire_spell_fireball_burst_warm_02", "fire_spell_fireball_burst_warm_03", "fire_spell_fireball_burst_warm_04"], 1.4, 0.45, "elem_fuego.wav"),
    "magma":        (["fire_spell_fireball_burst_dark_01", "fire_spell_fireball_burst_dark_02", "fire_spell_fireball_burst_dark_03"], 1.6, 0.5, "elem_fuego.wav"),
    "agua":         (["water_spell_cast_fast_ball_power_02", "water_spell_cast_fast_ball_power_03", "water_spell_cast_fast_ball_power_04"], 1.3, 0.4, "elem_agua.wav"),
    "salpicadura":  (["water_spell_cast_thick_splash_01", "water_spell_cast_thick_splash_02", "water_spell_cast_thick_splash_03"], 1.2, 0.4, "salpicadura.wav"),
    "viento":       (["wind_spell_cast_air_sharp_shoot_01", "wind_spell_cast_air_sharp_shoot_02", "wind_spell_cast_air_sharp_shoot_03", "wind_spell_cast_air_sharp_shoot_04"], 1.2, 0.4, "elem_viento.wav"),
    "tierra":       (["earth_spell_cast_throw_rock_fast_whoosh_impact_01", "earth_spell_cast_throw_rock_fast_whoosh_impact_02", "earth_spell_cast_throw_rock_fast_whoosh_impact_03", "earth_spell_cast_throw_rock_fast_whoosh_impact_04"], 1.6, 0.45, "elem_tierra.wav"),
    "rayo":         (["lighting_spell_electric_zap_blast_sparkle_bright_01", "lighting_spell_electric_zap_blast_sparkle_bright_02", "lighting_spell_electric_zap_blast_sparkle_bright_03", "lighting_spell_electric_zap_blast_sparkle_bright_04"], 1.2, 0.3, "oga_relampago_1.wav"),
    "chispazo":     (["lighting_spell_electric_zap_blast_sparkle_dark_01", "lighting_spell_electric_zap_blast_sparkle_dark_02", "lighting_spell_electric_zap_blast_sparkle_dark_03"], 1.0, 0.3, "chispazo.wav"),
    "trueno":       (["lighting_spell_electric_impact_thunder_dark_dry_01", "lighting_spell_electric_impact_thunder_dark_dry_02", "lighting_spell_electric_impact_thunder_dark_dry_03"], 2.5, 0.9, None),
    "hielo":        (["Ice_Spell_cast_and_impact_01", "Ice_Spell_cast_and_impact_02", "Ice_Spell_cast_and_impact_03", "Ice_Spell_cast_and_impact_04"], 1.8, 0.5, "oga_congelar_1.wav"),
    "hielo_flecha": (["Ice_Spell_fast_impact_01", "Ice_Spell_fast_impact_02", "Ice_Spell_fast_impact_03", "Ice_Spell_fast_impact_04"], 1.5, 0.45, "oga_congelar_1.wav"),
    "reaparecer":   (["Holy_spell_revive_cast_01"], 2.5, 0.9, "reaparecer.wav"),
    "veneno_bola":  (["acid_spell_cast_squish_ball_01", "acid_spell_cast_squish_ball_02", "acid_spell_cast_squish_ball_03"], 1.2, 0.4, None),
    "veneno_charco": (["acid_spell_cast_squish_ball_impact_01", "acid_spell_cast_squish_ball_impact_02", "acid_spell_cast_squish_ball_impact_03"], 1.5, 0.5, None),
    "raices_brotan": (["earth_spell_cast_rise_ground_01", "earth_spell_cast_rise_ground_02", "earth_spell_cast_rise_ground_03"], 2.0, 0.6, None),
}


def buscar(nombre):
    for r, d, fs in os.walk(BASE):
        for f in fs:
            if f.lower() == nombre.lower() + ".ogg":
                return os.path.join(r, f)
    return None


def rms_de(nombre):
    ruta = os.path.join(DEST, nombre)
    if not os.path.exists(ruta):
        return None
    v, _ = sf.read(ruta, dtype="float32", always_2d=True)
    return float(np.sqrt((v.mean(axis=1) ** 2).mean()))


informe = []
for entrada, (pistas, tope, fundido, como) in ELEGIDOS.items():
    for i, pista in enumerate(pistas):
        ruta = buscar(pista)
        if ruta is None:
            print("NO ENCONTRADO", entrada, pista)
            continue
        x, sr = sf.read(ruta, dtype="float32", always_2d=True)
        m = x.mean(axis=1)
        g = gcd(SR, sr)
        y = resample_poly(m, SR // g, sr // g).astype(np.float32)
        # arranque: primer punto con señal (deja 3 ms)
        pico = np.abs(y).max()
        idx = np.nonzero(np.abs(y) > pico * 0.03)[0]
        y = y[max(0, idx[0] - int(0.003 * SR)):]
        # final: donde la envolvente (ventanas de 20 ms) cae CAIDA_DB bajo su pico, después del pico; nunca más que el tope
        v = int(0.02 * SR)
        n = len(y) // v
        env = np.sqrt((y[: n * v].reshape(n, v) ** 2).mean(axis=1))
        ip = int(np.argmax(env))
        bajo = np.nonzero(env[ip:] < env[ip] * 10 ** (-CAIDA_DB / 20.0))[0]
        fin = (ip + int(bajo[0])) * v if len(bajo) else len(y)
        fin = min(fin + int(0.05 * SR), int(tope * SR), len(y))
        y = y[:fin].copy()
        ne = int(0.003 * SR)
        ns = min(len(y), int(fundido * SR))
        y[:ne] *= np.linspace(0.0, 1.0, ne)
        y[-ns:] *= np.linspace(1.0, 0.0, ns) ** 1.5
        y *= (10 ** (-3.0 / 20.0)) / (np.abs(y).max() + 1e-9)
        viejo = rms_de(como) if como else None
        if viejo:
            y *= viejo / (float(np.sqrt((y ** 2).mean())) + 1e-9)
            t = 10 ** (-1.0 / 20.0)
            if np.abs(y).max() > t:
                y *= t / np.abs(y).max()
        destino = "lc_%s_%d" % (entrada, i)
        with sf.SoundFile(os.path.join(DEST, destino + ".ogg"), "w", samplerate=SR, channels=1, format="OGG", subtype="VORBIS") as fh:
            for k in range(0, len(y), SR):
                fh.write(y[k:k + SR])
        rms = 20 * np.log10(np.sqrt((y ** 2).mean()) + 1e-9)
        informe.append((destino, entrada, pista + ".ogg", len(y) / SR, rms))
        print("%-22s %.2fs rms %.1f dB  <- %s" % (destino + ".ogg", len(y) / SR, rms, pista))

with open(os.path.join(DEST, "lc_informe.tsv"), "w", encoding="utf-8") as fh:
    for fila in informe:
        fh.write("\t".join(str(c) for c in fila) + "\n")

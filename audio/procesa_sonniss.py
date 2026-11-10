"""Recorta, pasa a mono 44,1 kHz, iguala el pico y escribe en audio/ los sonidos elegidos del lote GDC 2026 de Sonniss (prefijo sn_).
Uso: python procesa_sonniss.py <carpeta sonniss_gdc2026> <carpeta audio del juego>"""
import os, sys, struct
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
from math import gcd

BASE = "\\\\?\\" + os.path.abspath(sys.argv[1])
DEST = os.path.abspath(sys.argv[2])
SR = 44100
PICO_DB = -3.0

# destino (sin extensión): (trozo del nombre de la carpeta, trozo del nombre del archivo, ini_s, fin_s o None, fundido de salida en s)
ELEGIDOS = {
    "sn_golpe_carne_0": ("Cinematic Fight", "4 x Punch, Body", 0.13, 0.54, 0.04),
    "sn_golpe_carne_1": ("Cinematic Fight", "4 x Punch, Body", 1.11, 1.58, 0.04),
    "sn_golpe_carne_2": ("Cinematic Fight", "4 x Punch, Body", 2.15, 2.57, 0.04),
    "sn_golpe_carne_3": ("Cinematic Fight", "4 x Punch, Body", 3.15, 3.65, 0.04),
    "sn_dano_jugadora_0": ("British Female Detective", "Pain Vocal Female Dying", 0.0, 0.68, 0.05),
    "sn_goblin_grito_0": ("Humanoid Creatures", "Screeching Breath Inhale", 0.0, 0.94, 0.08, 1.18),
    "sn_goblin_grito_1": ("Humanoid Creatures", "Orc Male Attack", 0.02, 1.25, 0.25, 1.18),
    "sn_goblin_grito_2": ("Vox Bestiae", "Violent Humanoid Creature Exhale", 0.0, 1.0, 0.15, 1.18),
    "sn_goblin_muere_0": ("Humanoid Creatures", "Flutter Death", 0.0, 2.3, 0.5, 1.45),
    "sn_hielo_quiebra_0": ("Designed Ice", "ice block snapping", 0.50, 2.0, 0.5),
    "sn_hielo_quiebra_1": ("Designed Ice", "fissure, fast, hard", 0.31, 1.8, 0.5),
    "sn_hielo_quiebra_2": ("Designed Ice", "block of ice crushed", 0.10, 1.7, 0.5),
    "sn_derrumbe_0": ("Colossal Impacts", "Woosh Debris", 0.08, 1.88, 0.25),
    "sn_explosion_0": ("Anime Game", "Explosion Small Blast", 0.01, 1.14, 0.15),
    "sn_hundido_burbujas_0": ("Elemental Mutation", "Water Deep Submerge", 0.02, 1.88, 0.25),
    "sn_limo_golpe_0": ("Tower Defense", "Blood Spill Splat", 0.0, 0.31, 0.03),
    "sn_limo_muere_0": ("Halloween", "Gore Designed Transient", 0.0, 1.33, 0.2),
    "sn_voltereta_0": ("Foley T-Shirt", "ClothMovement24", 0.02, 0.62, 0.2),
    "sn_voltereta_1": ("Foley T-Shirt", "ClothMovement24", 1.31, 1.91, 0.2),
    "sn_voltereta_2": ("Foley T-Shirt", "ClothMovement29", 0.0, 0.62, 0.2),
}


def leer_riff(ruta):
    """Lector WAV mínimo (PCM 16/24/32 y float 32) para los archivos cuyo trozo PEAK no acepta libsndfile."""
    with open(ruta, "rb") as fh:
        d = fh.read()
    assert d[:4] == b"RIFF" and d[8:12] == b"WAVE"
    p = 12
    fmt = None
    datos = None
    while p + 8 <= len(d):
        cid = d[p:p + 4]
        tam = struct.unpack("<I", d[p + 4:p + 8])[0]
        cuerpo = d[p + 8:p + 8 + tam]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", cuerpo[:16])
        elif cid == b"data":
            datos = cuerpo
        p += 8 + tam + (tam & 1)
    tag, ch, sr, _, _, bits = fmt
    if tag == 0xFFFE:
        tag = struct.unpack("<H", d[d.find(b"fmt ") + 8 + 24:d.find(b"fmt ") + 8 + 26])[0]
    if tag == 3:
        x = np.frombuffer(datos, dtype="<f4").astype(np.float32)
    elif bits == 16:
        x = np.frombuffer(datos, dtype="<i2").astype(np.float32) / 32768.0
    elif bits == 24:
        b = np.frombuffer(datos[: len(datos) // 3 * 3], dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v & 0x800000, v - 0x1000000, v)
        x = v.astype(np.float32) / 8388608.0
    else:
        x = np.frombuffer(datos, dtype="<i4").astype(np.float32) / 2147483648.0
    x = x[: len(x) // ch * ch].reshape(-1, ch)
    return x, sr


def buscar(carpeta, archivo):
    for r, d, fs in os.walk(BASE):
        if carpeta.lower() not in os.path.basename(r).lower():
            continue
        for f in fs:
            if archivo.lower() in f.lower() and f.lower().endswith(".wav"):
                return os.path.join(r, f)
    return None


informe = []
for destino, datos in ELEGIDOS.items():
    carpeta, archivo, ini, fin, fundido = datos[:5]
    tono = datos[5] if len(datos) > 5 else 1.0
    ruta = buscar(carpeta, archivo)
    if ruta is None:
        print("NO ENCONTRADO", destino, carpeta, archivo)
        continue
    try:
        x, sr = sf.read(ruta, dtype="float32", always_2d=True)
    except Exception:
        x, sr = leer_riff(ruta)
    m = x[:, :2].mean(axis=1) if x.shape[1] >= 2 else x[:, 0]
    a = int(ini * sr)
    b = len(m) if fin is None else min(len(m), int(fin * sr))
    m = m[a:b]
    # «tono» va cocido en el archivo (más agudo y más corto): la voz de orco sube a goblin sin tocar el catálogo
    sr_ef = int(round(sr * tono))
    g = gcd(SR, sr_ef)
    y = resample_poly(m, SR // g, sr_ef // g).astype(np.float32)
    # arranque en el primer punto con señal (deja 3 ms) y fundidos
    pico = np.abs(y).max()
    idx = np.nonzero(np.abs(y) > pico * 0.02)[0]
    if len(idx):
        y = y[max(0, idx[0] - int(0.003 * SR)):]
    ne = int(0.003 * SR)
    ns = min(len(y), int(fundido * SR))
    y[:ne] *= np.linspace(0.0, 1.0, ne)
    y[-ns:] *= np.linspace(1.0, 0.0, ns) ** 1.5
    y *= (10 ** (PICO_DB / 20.0)) / (np.abs(y).max() + 1e-9)
    salida = os.path.join(DEST, destino + ".ogg")
    sf.write(salida, y, SR, format="OGG", subtype="VORBIS")
    rms = 20 * np.log10(np.sqrt((y ** 2).mean()) + 1e-9)
    informe.append((destino, os.path.basename(os.path.dirname(ruta)), os.path.basename(ruta), len(y) / SR, rms))
    print("%-24s %.2fs rms %.1f dB  <- %s" % (destino + ".ogg", len(y) / SR, rms, os.path.basename(ruta)[:70]))

with open(os.path.join(DEST, "sn_informe.tsv"), "w", encoding="utf-8") as fh:
    for fila in informe:
        fh.write("\t".join(str(c) for c in fila) + "\n")

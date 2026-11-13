# CHOQUE DEL VIENTO: ¿ENVUELVE O SE AMONTONA DELANTE? (13/11/2026). Lee herramientas/captura_choque_envuelve.gd (antes/ y despues/ en
# docs/capturas/vfx_en_juego/haz_gas_elementos/choque_envuelve/) y, en la opacidad de los trazos y a menos de 3 radios del centro del obstaculo (en la pantalla):
#   DELANTE = antes de la cara delantera (del lado de la mano, a lo largo del eje del haz en la pantalla); LADOS = de la cara al centro; DETRAS = pasado el centro.
# Da la parte de la opacidad en cada zona y monta HOJA_CHOQUE_ENVUELVE.jpg (antes / despues, recortado alrededor del obstaculo).
#   python herramientas/hoja_choque_envuelve.py [carpeta]
import json
import os
import sys
import cv2
import numpy as np

BASE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "docs", "capturas", "vfx_en_juego", "haz_gas_elementos", "choque_envuelve")
VERSIONES = ["antes", "despues"]


def medir(ver, nombre, m):
    a = cv2.imread(os.path.join(BASE, ver, nombre + "_a.png"), cv2.IMREAD_GRAYSCALE)
    if a is None:
        return None
    a = a.astype(np.float32) / 255.0
    h, w = a.shape
    ys, xs = np.mgrid[0:h, 0:w]
    c = np.array(m["centro"])
    cara = np.array(m["cara"])
    eje = c - np.array(m["mano"])
    eje = eje / max(np.linalg.norm(eje), 1e-6)
    r = max(m["radio"], 1.0)
    cerca = (xs - c[0]) ** 2 + (ys - c[1]) ** 2 < (3.0 * r) ** 2
    s_cara = (xs - cara[0]) * eje[0] + (ys - cara[1]) * eje[1]
    s_c = (xs - c[0]) * eje[0] + (ys - c[1]) * eje[1]
    tot = float(a[cerca].sum())
    if tot <= 0:
        return {"delante": 0.0, "lados": 0.0, "detras": 0.0, "total": 0.0}
    delante = float(a[cerca & (s_cara < 0)].sum()) / tot
    detras = float(a[cerca & (s_c > 0)].sum()) / tot
    return {"delante": delante, "lados": 1.0 - delante - detras, "detras": detras, "total": tot}


def main():
    med = {}
    for ver in VERSIONES:
        ruta = os.path.join(BASE, ver, "medidas.json")
        med[ver] = json.load(open(ruta)) if os.path.exists(ruta) else {}
    nombres = sorted(set(med["antes"]) | set(med["despues"]))
    filas = []
    print("caso | version | delante | lados | detras | opacidad cerca | ms GPU")
    for n in nombres:
        celdas = []
        for ver in VERSIONES:
            m = med[ver].get(n)
            img = cv2.imread(os.path.join(BASE, ver, n + ".jpg"))
            if m is None or img is None:
                celdas.append(np.zeros((300, 450, 3), np.uint8))
                continue
            r = medir(ver, n, m)
            print(f"{n} | {ver} | {r['delante']:.2f} | {r['lados']:.2f} | {r['detras']:.2f} | {r['total']:.0f} | {m.get('gpu_ms', 0):.2f}")
            esc = img.shape[1] / m["tam"][0]
            cx, cy, rr = m["centro"][0] * esc, m["centro"][1] * esc, max(m["radio"] * esc, 20)
            lado = 3.2 * rr
            x0, y0 = int(max(cx - lado * 1.5, 0)), int(max(cy - lado, 0))
            x1, y1 = int(min(cx + lado * 1.5, img.shape[1])), int(min(cy + lado, img.shape[0]))
            celda = cv2.resize(img[y0:y1, x0:x1], (450, 300), interpolation=cv2.INTER_AREA)
            cv2.rectangle(celda, (0, 0), (450, 20), (0, 0, 0), -1)
            cv2.putText(celda, f"{n} {ver.upper()}  delante {r['delante']:.0%}  lados {r['lados']:.0%}  detras {r['detras']:.0%}", (4, 14),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1, cv2.LINE_AA)
            celdas.append(celda)
        filas.append(np.hstack(celdas))
    if filas:
        hoja = np.vstack([np.hstack(filas[i:i + 2]) if i + 1 < len(filas) else np.hstack([filas[i], np.zeros_like(filas[i])]) for i in range(0, len(filas), 2)])
        cv2.imwrite(os.path.join(BASE, "HOJA_CHOQUE_ENVUELVE.jpg"), hoja, [cv2.IMWRITE_JPEG_QUALITY, 88])
        print("hoja", os.path.abspath(os.path.join(BASE, "HOJA_CHOQUE_ENVUELVE.jpg")), hoja.shape)


if __name__ == "__main__":
    main()

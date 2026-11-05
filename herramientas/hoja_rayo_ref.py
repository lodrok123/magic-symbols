"""Hoja resumen de las capturas del rayo en el juego (captura_rayo_ref.gd), comparable con las hojas de fotogramas de la referencia en vídeo.
Uso: python herramientas/hoja_rayo_ref.py <carpeta> <salida.jpg> [ancho_recorte] [columnas]
Recorta el centro de cada captura (la cámara del juego sigue a la jugadora) y las pone en rejilla con su nombre."""
import sys, os, glob
import cv2
import numpy as np

carpeta = sys.argv[1]
salida = sys.argv[2]
ancho = int(sys.argv[3]) if len(sys.argv) > 3 else 640
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 4
alto = ancho * 9 // 16
orden = ["proyectil", "carga", "impacto", "pilar", "area", "haz", "muro", "barrera", "estado_entidad", "estado_agua"]
archivos = sorted(glob.glob(os.path.join(carpeta, "*.png")), key=lambda f: (orden.index(os.path.basename(f).rsplit("_", 1)[0]) if os.path.basename(f).rsplit("_", 1)[0] in orden else 99, f))
celdas = []
for f in archivos:
    im = cv2.imread(f)
    if im is None:
        continue
    h, w = im.shape[:2]
    cx, cy = w // 2 + int((0.30 if 'estado_agua' in f else 0.12) * w), h // 2
    x0 = max(0, min(w - ancho, cx - ancho // 2))
    y0 = max(0, min(h - alto, cy - alto // 2))
    rec = im[y0:y0 + alto, x0:x0 + ancho].copy()
    nombre = os.path.basename(f)[:-4]
    cv2.putText(rec, nombre, (8, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 3, cv2.LINE_AA)
    cv2.putText(rec, nombre, (8, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1, cv2.LINE_AA)
    celdas.append(rec)
while len(celdas) % cols:
    celdas.append(np.zeros((alto, ancho, 3), np.uint8))
filas = [np.hstack(celdas[i:i + cols]) for i in range(0, len(celdas), cols)]
cv2.imwrite(salida, np.vstack(filas), [cv2.IMWRITE_JPEG_QUALITY, 88])
print("escrito", salida, len(archivos), "capturas")

"""Imagen sintética de espermatozoides con largo de flagelo conocido.

El largo real se calcula de la curva y se guarda en verdad_terreno.csv.
Uso: python pruebas/generar_sintetica.py
"""
from pathlib import Path

import numpy as np
import tifffile
from scipy.ndimage import gaussian_filter

ESCALA = 0.125          # µm por píxel
ANCHO, ALTO = 640, 480  # px
GROSOR_PX = 4.0         # grosor aproximado del flagelo (≈0.5 µm)
SEMILLA = 7

# (x0, y0, dirección en grados, amplitud px, longitud de onda px, largo de eje px)
CELULAS = [
    (110, 120, 10, 14, 120, 380),
    (120, 330, -12, 22, 150, 360),
    (560, 250, 185, 10, 100, 330),
]


def curva(x0, y0, ang, amp, lam, largo_eje, n=4000):
    """Onda senoidal que se abre hacia la punta."""
    s = np.linspace(0, largo_eje, n)
    a = amp * (s / largo_eje) ** 0.8
    u, v = s, a * np.sin(2 * np.pi * s / lam)
    t = np.deg2rad(ang)
    x = x0 + u * np.cos(t) - v * np.sin(t)
    y = y0 + u * np.sin(t) + v * np.cos(t)
    return x, y


def main():
    rng = np.random.default_rng(SEMILLA)
    yy, xx = np.mgrid[0:ALTO, 0:ANCHO]
    img = np.zeros((ALTO, ANCHO), float)
    filas = []
    for i, (x0, y0, ang, amp, lam, L) in enumerate(CELULAS, 1):
        x, y = curva(x0, y0, ang, amp, lam, L)
        largo_px = np.sum(np.hypot(np.diff(x), np.diff(y)))
        # flagelo: puntos sobre la curva + desenfoque
        capa = np.zeros_like(img)
        np.add.at(capa, (np.clip(y.round().astype(int), 0, ALTO - 1),
                         np.clip(x.round().astype(int), 0, ANCHO - 1)), 1.0)
        capa = gaussian_filter(capa, GROSOR_PX / 2.355)
        capa /= capa.max()
        img += 0.75 * capa
        # cabeza: elipse al inicio del flagelo
        t = np.deg2rad(ang)
        cx, cy = x0 - 18 * np.cos(t), y0 - 18 * np.sin(t)
        du = (xx - cx) * np.cos(t) + (yy - cy) * np.sin(t)
        dv = -(xx - cx) * np.sin(t) + (yy - cy) * np.cos(t)
        img += np.where((du / 22) ** 2 + (dv / 14) ** 2 <= 1, 1.0, 0.0)
        # 12 puntos sobre la curva, como si lo trazara a mano
        idx = np.linspace(0, len(x) - 1, 12).round().astype(int)
        filas.append((i, largo_px * ESCALA,
                      " ".join(f"{a:.1f}" for a in x[idx]),
                      " ".join(f"{b:.1f}" for b in y[idx])))
    img = gaussian_filter(img, 1.0)
    img = img * 170 + 25 + rng.normal(0, 8, img.shape)
    img = np.clip(img, 0, 255).astype(np.uint8)

    salida = Path(__file__).resolve().parent.parent / "ejemplo"
    salida.mkdir(exist_ok=True)
    tifffile.imwrite(salida / "espermatozoides_sintetico.tif", img, imagej=True,
                     resolution=(1 / ESCALA, 1 / ESCALA), metadata={"unit": "um"})
    with open(salida / "verdad_terreno.csv", "w", encoding="utf-8") as f:
        f.write("celula,largo_real_um,trazo_x,trazo_y\n")
        for c, l, xs, ys in filas:
            f.write(f"{c},{l:.3f},{xs},{ys}\n")
    for c, l, *_ in filas:
        print(f"célula {c}: largo real = {l:.2f} µm")


if __name__ == "__main__":
    main()

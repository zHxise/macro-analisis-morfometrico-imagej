"""Junta todos los *_resultados.csv en una tabla.

Uso: python analisis/combinar_resultados.py CARPETA [--grupos grupos.csv]

grupos.csv es opcional, con columnas imagen,grupo (control, tratamiento...).
Deja en CARPETA tabla_completa.csv y resumen.csv (n, media, DE y mediana
por imagen o por grupo).
"""
import argparse
from pathlib import Path

import pandas as pd

VARIABLES = ["Largo", "Area", "Mean", "IntDen"]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("carpeta", type=Path)
    ap.add_argument("--grupos", type=Path)
    a = ap.parse_args()

    archivos = sorted(a.carpeta.rglob("*_resultados.csv"))
    if not archivos:
        raise SystemExit(f"No hay *_resultados.csv en {a.carpeta}")

    tablas = []
    for f in archivos:
        t = pd.read_csv(f).drop(columns=[" "], errors="ignore")
        t.insert(0, "imagen", f.name.removesuffix("_resultados.csv"))
        tablas.append(t)
    datos = pd.concat(tablas, ignore_index=True)

    clave = "imagen"
    if a.grupos:
        g = pd.read_csv(a.grupos)
        datos = datos.merge(g, on="imagen", how="left")
        clave = "grupo"

    vars_ok = [v for v in VARIABLES if v in datos.columns]
    resumen = datos.groupby(clave)[vars_ok].agg(["count", "mean", "std", "median"]).round(3)

    datos.to_csv(a.carpeta / "tabla_completa.csv", index=False)
    resumen.to_csv(a.carpeta / "resumen.csv")
    print(f"{len(archivos)} archivos, {len(datos)} estructuras.\n")
    print(resumen.to_string())


if __name__ == "__main__":
    main()

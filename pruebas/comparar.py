"""Compara lo que midió la macro contra el largo real de la imagen sintética."""
import sys
from pathlib import Path

import pandas as pd

salida = Path(sys.argv[1])
raiz = Path(__file__).resolve().parent.parent
real = pd.read_csv(raiz / "ejemplo" / "verdad_terreno.csv")
med = pd.read_csv(salida / "espermatozoides_sintetico_resultados.csv")
re = pd.read_csv(salida / "reauditoria" / "espermatozoides_sintetico_resultados.csv")

assert len(med) == len(real), "número de ROIs distinto"
err = (med["Largo"] - real["largo_real_um"]) / real["largo_real_um"] * 100
tabla = pd.DataFrame({"celula": real["celula"], "real_um": real["largo_real_um"],
                      "macro_um": med["Largo"].round(3), "error_%": err.round(2)})
print(tabla.to_string(index=False))
assert err.abs().max() < 2.0, "error de longitud mayor a 2 %"
cols = ["Area", "Mean", "Largo"]
assert (med[cols].values == re[cols].values).all(), "la re-auditoría no reproduce los valores"
print("\nOK: longitudes dentro de ±2 % y re-auditoría idéntica.")

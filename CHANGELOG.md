# Cambios

## 2.1.0

Nuevo:
- Se mide el largo del trazo suavizado (columna `Largo`).
- El ancho se puede poner en µm u otra unidad; se pasa a px con la escala de cada imagen.
- El último ancho se guarda en las preferencias de ImageJ.
- `_parametros.txt` con versión de la macro y de ImageJ, fecha, escala, unidades y ancho.
- `_control.png` con los trazos numerados.
- Tecla `A` para abrir un `RoiSet.zip` y volver a medir.
- Tecla `H` con los atajos.
- Largo y ancho quedan guardados en cada ROI dentro del `RoiSet.zip`.
- Imagen sintética de ejemplo, prueba de exactitud, notebook de validación (Bland-Altman, CCC de Lin, ICC) y script para juntar resultados.

Corregido:
- Con línea recta (tipo 5) `Fit Spline` daba error y la macro se quedaba detenida. Ahora el spline solo se aplica a segmented y freehand line.

## 2.0.0

- Ancho de trazo configurable con `C` (antes estaba fijo en el código).
- El ancho se aplica con `Roi.setStrokeWidth()` justo antes de convertir a área.
- Ya no se duplican las mediciones. En la v1 `F` medía al guardar y `M` volvía a medir todo. Ahora `F` usa `getStatistics()`, que no escribe en la tabla, y `M` mide una sola vez.
- Se quitó `roiManager("Select All")`, que no es un comando válido.
- Ya no se acepta el tipo 8 (angle) como línea.
- Nombres de archivo: la v1 usaba `replace(nombre, ".jpg", "")` y el punto funcionaba como comodín de regex.
- ROIs con nombre, aviso si la imagen no tiene escala, revisión del número de mediciones y tecla `R`.

### Si usaste la versión 1

La v1 ponía el ancho con `run("Properties...", "width=...")`. Eso abre **Image ▸ Properties** (la calibración de la imagen), no el ancho de la línea, así que probablemente ese ancho nunca se aplicó y se usaba el ancho de línea global de ImageJ.

Antes de usar una versión nueva con datos ya analizados, vuelve a medir tu célula de calibración. Si el área cambia, hay que recalibrar el ancho. No mezcles resultados de la v1 con los de otras versiones.

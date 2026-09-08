# Macro de análisis morfométrico para ImageJ

`flagelos.ijm` — macro de ImageJ para la **cuantificación reproducible de estructuras filamentosas**.

Convierte un trazo manual sobre una estructura alargada en una región de interés (ROI) de ancho calibrado, y automatiza su medición y exportación. Desarrollada para el contorneado y la cuantificación de flagelos de espermatozoides, es aplicable a cualquier estructura que se mida trazando su eje y midiendo en una banda de ancho definido: cilios, neuritas y prolongaciones astrocíticas, hifas, fibras de estrés, microvasculatura, fibras musculares.

El objetivo no es ahorrar clics, sino **estandarizar la medición**: mismo ancho de trazo, mismo suavizado y mismo conjunto de parámetros en todas las células, con los trazos exportados junto a los datos para poder reauditarlos.

---

## Instalación

1. Descarga `flagelos.ijm`.
2. En ImageJ o Fiji: **Plugins ▸ Macros ▸ Install…** y selecciona el archivo.

Los atajos quedan activos hasta que cierres ImageJ. Requiere ImageJ 1.52 o superior.

## Uso

| Tecla | Acción |
|-------|--------|
| `C` | Configurar el ancho de trazo (una vez por sesión) |
| `F` | Guardar el trazo actual como ROI medible |
| `D` | Deshacer el último ROI |
| `M` | Medir todos los ROIs y exportar CSV + RoiSet |
| `R` | Reiniciar la sesión |

**Flujo de trabajo**

1. Abre la imagen y pulsa `C` para fijar el ancho de trazo.
2. Selecciona la herramienta **Segmented Line**.
3. Traza el eje de la estructura; doble clic para terminar.
4. Pulsa `F`. El trazo se suaviza por spline, se convierte en área y se guarda con nombre propio en el ROI Manager. La barra de estado muestra el área y la media de esa estructura.
5. Repite para cada estructura válida. Si te equivocas, `D`.
6. Al terminar, pulsa `M` y elige la carpeta de destino.

## Salidas

| Archivo | Contenido |
|---------|-----------|
| `<imagen>_resultados.csv` | Una fila por estructura: área, media, mín., máx., mediana, densidad integrada y etiqueta de origen |
| `<imagen>_RoiSet.zip` | Los trazos, reabribles en el ROI Manager para verificar o rehacer la medición |

Exportar el `RoiSet` junto al CSV es deliberado: permite que un tercero abra los mismos trazos sobre la misma imagen y compruebe de dónde salió cada número.

---

## Calibración del ancho de trazo

El ancho de trazo determina la banda sobre la que se integra la señal, así que **es un parámetro experimental, no una preferencia visual**. Calíbralo así:

1. Mide manualmente una estructura representativa por el método que ya usas.
2. Traza esa misma estructura con la macro.
3. Ajusta el ancho con `C` hasta reproducir el área manual.
4. Usa ese valor para todo el conjunto de imágenes.

Conviene además definir la escala espacial (**Analyze ▸ Set Scale…**) antes de medir; si la imagen no está calibrada, la macro avisa y las áreas se reportan en px².

> ### ⚠️ Nota para quienes usaron la versión 1
>
> La v1 fijaba el ancho con `run("Properties...", "width=...")`, que invoca **Image ▸ Properties** —la calibración de la imagen— y no el ancho de la línea. Es probable que ese ancho **nunca se estuviera aplicando** y que la conversión usara el ancho de línea global de ImageJ.
>
> La v2 lo fija con `Roi.setStrokeWidth()`, justo antes de convertir a área.
>
> **Antes de usar la v2 sobre datos ya analizados, vuelve a medir tu célula de calibración.** Si el área cambia respecto a la v1, el ancho anterior no se estaba aplicando y hay que recalibrar el valor. No mezcles resultados de ambas versiones en un mismo análisis.

---

## Cambios en la versión 2

- **Ancho de trazo parametrizable** (`C`) en lugar de un valor fijo en el código; persiste durante la sesión.
- **Ancho aplicado de forma inequívoca** con `Roi.setStrokeWidth()` — ver la nota de calibración.
- **Corregida la duplicación de mediciones.** En la v1, `F` medía cada ROI al guardarlo y `M` volvía a medirlos todos, de modo que el CSV salía con cada estructura repetida. Ahora `F` da retroalimentación con `getStatistics()`, que no escribe en la tabla, y `M` limpia y mide una sola vez.
- **Corregido `roiManager("Select All")`**, que no es un comando válido del ROI Manager.
- **Corregida la validación del tipo de selección.** La v1 aceptaba el tipo 8, que es *angle* y no una línea; ahora acepta línea recta, segmented line y freehand line.
- **Nombres de archivo correctos.** La v1 usaba `replace(nombre, ".jpg", "")`, donde el punto es un comodín de expresión regular; ahora la extensión se recorta por posición.
- **ROIs con nombre propio**, para que cada fila del CSV se pueda rastrear hasta su trazo.
- Aviso cuando la imagen carece de escala espacial.
- Verificación de que el número de mediciones coincide con el número de ROIs.
- Comprobación de que hay una imagen abierta; cancelar el diálogo de carpeta ya no deja la exportación a medias.
- Nueva tecla `R` para reiniciar la sesión.

## Limitaciones

- El trazado es manual: la macro estandariza la medición, no la detección.
- El ancho de trazo es único para toda la sesión; estructuras de grosor muy dispar requieren analizarse por lotes separados.
- No implementa criterios de inclusión o exclusión de células: esa decisión sigue siendo del operador.

## Licencia

MIT — ver [LICENSE](LICENSE).

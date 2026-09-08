// ============================================================
//  flagelos.ijm  —  v2.0
//  Cuantificación de estructuras filamentosas en ImageJ
//
//  Convierte un trazo manual sobre una estructura filamentosa
//  (flagelo, cilio, neurita, hifa, fibra) en una región de
//  interés de ancho calibrado, y automatiza su medición y
//  exportación reproducible.
//
//  INSTALACIÓN
//    Plugins > Macros > Install...  y elige este archivo.
//
//  USO
//    C  configurar ancho de trazo (una vez por sesión)
//    F  guardar el trazo actual como ROI medible
//    D  deshacer el último ROI
//    M  medir todo y exportar CSV + RoiSet
//    R  reiniciar la sesión (vacía ROI Manager y Resultados)
//
//  Autor: Braulio Arturo Rodríguez Angulo
//  Licencia: MIT
// ============================================================

// --- Estado global: persiste mientras el set esté instalado ---
var anchoTrazo    = 3.4;    // ancho del trazo, en píxeles
var yaConfigurado = false;

var MEDICIONES = "area mean min max median integrated display limit redirect=None decimal=3";


// ------------------------------------------------------------
//  C — Configuración
// ------------------------------------------------------------
macro "Configurar ancho [c]" {
    configurar();
}

function configurar() {
    Dialog.create("Configuración — flagelos.ijm");
    Dialog.addNumber("Ancho de trazo (px):", anchoTrazo, 2, 6, "");
    Dialog.addMessage("Calíbralo midiendo manualmente una estructura\n" +
                      "representativa y ajustando hasta reproducir su área.");
    Dialog.show();
    valor = Dialog.getNumber();
    if (valor <= 0 || isNaN(valor)) {
        showMessage("Valor inválido", "El ancho debe ser un número mayor que cero.");
        return;                       // conserva el ancho anterior en lugar de invalidarlo
    }
    anchoTrazo    = valor;
    yaConfigurado = true;
    revisarCalibracion();
    showStatus("Ancho de trazo = " + anchoTrazo + " px");
}

// Avisa si la imagen no tiene escala espacial: las áreas saldrían en px².
function revisarCalibracion() {
    if (nImages == 0) return;
    getPixelSize(unidad, anchoPx, altoPx);
    if (unidad == "pixel" || unidad == "pixels" || unidad == "") {
        showMessage("Imagen sin calibrar",
            "Esta imagen no tiene escala espacial definida.\n \n" +
            "Las áreas se reportarán en px², no en unidades físicas.\n" +
            "Si necesitas unidades reales, define la escala en\n" +
            "Analyze > Set Scale... antes de medir.");
    }
}

// Nombre del archivo sin extensión, a partir del título de la imagen activa.
function baseDelTitulo() {
    t = getTitle();
    p = lastIndexOf(t, ".");
    if (p > 0) t = substring(t, 0, p);
    t = replace(t, "[^A-Za-z0-9_.-]", "_");
    return t;
}

function hayImagen() {
    if (nImages == 0) {
        showMessage("Sin imagen", "Abre primero la imagen que vas a analizar.");
        return false;
    }
    return true;
}


// ------------------------------------------------------------
//  F — Guardar el trazo como ROI de área
// ------------------------------------------------------------
macro "Guardar trazo [f]" {
    if (!hayImagen()) exit;

    tipo = selectionType();
    if (tipo == -1) {
        showMessage("Sin selección", "Traza primero la estructura con la herramienta Segmented Line.");
        exit;
    }
    // 5 = línea recta, 6 = segmented line, 7 = freehand line.
    // (8 es "angle", NO una línea medible: estaba aceptado por error en v1.)
    if (tipo != 5 && tipo != 6 && tipo != 7) {
        showMessage("Tipo de selección incorrecto",
            "Necesitas una selección de línea.\n \n" +
            "Elige la herramienta Segmented Line y traza el eje de la estructura\n" +
            "(doble clic para terminar el trazo).");
        exit;
    }

    // Pide el ancho la primera vez, en lugar de asumir un valor fijo.
    if (!yaConfigurado) configurar();
    if (!yaConfigurado) exit;

    // El ancho se fija con Roi.setStrokeWidth, que actúa de forma inequívoca
    // sobre la selección activa, y se aplica JUSTO ANTES de convertir a área.
    // v1 usaba run("Properties...", "width=..."), que invoca Image > Properties
    // (calibración de la imagen), no el ancho de la línea: es probable que ese
    // ancho nunca se estuviera aplicando. Ver nota de calibración en el README.
    run("Fit Spline");
    Roi.setStrokeWidth(anchoTrazo);
    run("Line to Area");

    n = roiManager("count");
    roiManager("Add");
    roiManager("Select", n);
    roiManager("Rename", baseDelTitulo() + "_" + IJ.pad(n + 1, 3));

    // Retroalimentación inmediata SIN escribir en la tabla de Resultados:
    // getStatistics no agrega filas, así que la exportación final no se duplica.
    getStatistics(area, media);
    showStatus("ROI " + (n + 1) + " guardado  |  area=" + d2s(area, 3) +
               "  media=" + d2s(media, 3) + "  |  F=guardar  D=deshacer  M=exportar");

    run("Select None");
    setTool("polyline");
}


// ------------------------------------------------------------
//  D — Deshacer el último ROI
// ------------------------------------------------------------
macro "Deshacer ultimo [d]" {
    n = roiManager("count");
    if (n == 0) {
        showMessage("ROI Manager vacío", "No hay ROIs que borrar.");
        exit;
    }
    roiManager("Select", n - 1);
    roiManager("Delete");
    run("Select None");
    showStatus("ROI " + n + " eliminado. Quedan " + (n - 1) + ".");
}


// ------------------------------------------------------------
//  M — Medir todo y exportar
// ------------------------------------------------------------
macro "Medir y exportar [m]" {
    if (!hayImagen()) exit;

    n = roiManager("count");
    if (n == 0) {
        showMessage("ROI Manager vacío", "Guarda al menos un trazo con la tecla F antes de exportar.");
        exit;
    }

    run("Set Measurements...", MEDICIONES);

    // Tabla limpia: se mide una sola vez cada ROI, en orden.
    run("Clear Results");
    for (i = 0; i < n; i++) {
        roiManager("Select", i);
        roiManager("Measure");
    }
    run("Select None");

    if (nResults != n) {
        showMessage("Advertencia",
            "Se esperaban " + n + " mediciones y se obtuvieron " + nResults + ".\n" +
            "Revisa la tabla de Resultados antes de usar el archivo.");
    }

    dir = getDirectory("Elige dónde guardar los resultados");
    if (dir == "") exit;                 // el usuario canceló

    base = baseDelTitulo();
    rutaCSV = dir + base + "_resultados.csv";
    rutaROI = dir + base + "_RoiSet.zip";

    saveAs("Results", rutaCSV);
    roiManager("Deselect");
    roiManager("Save", rutaROI);

    showMessage("Exportación completa",
        n + " estructuras medidas.\n \n" +
        "  " + base + "_resultados.csv\n" +
        "  " + base + "_RoiSet.zip\n \n" +
        "Ancho de trazo usado: " + anchoTrazo + " px\n" +
        "Carpeta: " + dir);
}


// ------------------------------------------------------------
//  R — Reiniciar la sesión
// ------------------------------------------------------------
macro "Reiniciar sesion [r]" {
    n = roiManager("count");
    if (n > 0) {
        if (!getBoolean("Se borrarán " + n + " ROIs y la tabla de Resultados.\n¿Continuar?"))
            exit;
    }
    roiManager("Reset");
    run("Clear Results");
    if (nImages > 0) run("Select None");
    showStatus("Sesión reiniciada. Ancho de trazo = " + anchoTrazo + " px");
}

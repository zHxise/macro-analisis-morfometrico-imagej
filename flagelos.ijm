// ============================================================
//  flagelos.ijm  v2.1.0
//  Mide flagelos (o cualquier estructura alargada) a partir de
//  un trazo manual: largo del eje + intensidad en una banda de
//  ancho fijo.
//
//  Instalar: Plugins > Macros > Install...
//
//  Teclas:
//    C  ancho de trazo (px o µm)
//    F  guardar trazo
//    D  deshacer último ROI
//    M  medir y exportar (CSV, RoiSet, parámetros, imagen de control)
//    A  abrir un RoiSet para volver a medir
//    R  reiniciar (vacía ROI Manager y Resultados)
//    H  ayuda
//
//  Autor: Braulio Arturo Rodríguez Angulo
//  Repositorio: github.com/zHxise/macro-analisis-morfometrico-imagej
//  Licencia: MIT
// ============================================================

var VERSION = "2.1.0";

// Variables globales (duran mientras la macro esté instalada).
// El ancho también se guarda en Prefs para la próxima sesión.
var anchoValor    = parseFloat(call("ij.Prefs.get", "flagelos.ancho", "3.4"));
var anchoUnidad   = call("ij.Prefs.get", "flagelos.unidad", "px");   // "px" o "fisica"
var yaConfigurado = false;
var silencioso    = false;  // true = sin mensaje final (para las pruebas)

var MEDICIONES = "area mean min max median integrated display limit redirect=None decimal=3";


// ------------------------------------------------------------
//  C: configuración
// ------------------------------------------------------------
macro "Configurar ancho [c]" {
    configurar();
}

function configurar() {
    unidadImg = "unidades físicas";
    if (nImages > 0 && imagenCalibrada()) {
        getPixelSize(u, pw, ph);
        unidadImg = u;
    }
    opciones = newArray("px", "unidades físicas (" + unidadImg + ")");
    elegida = opciones[0];
    if (anchoUnidad == "fisica") elegida = opciones[1];

    Dialog.create("Configuración, flagelos.ijm v" + VERSION);
    Dialog.addNumber("Ancho de trazo:", anchoValor, 3, 7, "");
    Dialog.addChoice("Unidad del ancho:", opciones, elegida);
    Dialog.addMessage("Calíbralo midiendo manualmente una estructura\n" +
                      "representativa y ajustando hasta reproducir su área.\n \n" +
                      "Usar unidades físicas permite comparar imágenes\n" +
                      "tomadas con distinto objetivo o microscopio.");
    Dialog.show();
    valor  = Dialog.getNumber();
    unidad = Dialog.getChoice();

    if (valor <= 0 || isNaN(valor)) {
        showMessage("Valor inválido", "El ancho debe ser un número mayor que cero.");
        return;                       // se queda el ancho anterior
    }
    anchoValor  = valor;
    anchoUnidad = "px";
    if (unidad != opciones[0]) anchoUnidad = "fisica";
    yaConfigurado = true;
    call("ij.Prefs.set", "flagelos.ancho", "" + anchoValor);
    call("ij.Prefs.set", "flagelos.unidad", anchoUnidad);

    revisarCalibracion();
    showStatus("Ancho de trazo = " + textoAncho());
}

function imagenCalibrada() {
    getPixelSize(unidad, anchoPx, altoPx);
    return !(unidad == "pixel" || unidad == "pixels" || unidad == "");
}

// Aviso si la imagen no tiene escala (todo saldría en px).
function revisarCalibracion() {
    if (nImages == 0) return;
    if (!imagenCalibrada()) {
        extra = "";
        if (anchoUnidad == "fisica")
            extra = "\n \nAdemás elegiste el ancho en unidades físicas:\n" +
                    "sin escala no se puede convertir y no podrás guardar trazos.";
        showMessage("Imagen sin calibrar",
            "Esta imagen no tiene escala espacial definida.\n \n" +
            "Las áreas y longitudes se reportarán en píxeles.\n" +
            "Si necesitas unidades reales, define la escala en\n" +
            "Analyze > Set Scale... antes de medir." + extra);
    }
}

// Ancho en px para la imagen activa. -1 si no hay escala para convertir.
function anchoEnPx() {
    if (anchoUnidad == "px") return anchoValor;
    if (!imagenCalibrada()) return -1;
    getPixelSize(u, pw, ph);
    return anchoValor / pw;
}

function textoAncho() {
    if (anchoUnidad == "px") return "" + anchoValor + " px";
    t = "" + anchoValor + " (unidades físicas)";
    if (nImages > 0 && imagenCalibrada()) {
        getPixelSize(u, pw, ph);
        t = "" + anchoValor + " " + u + " (= " + d2s(anchoValor / pw, 3) + " px)";
    }
    return t;
}

// Título de la imagen sin extensión.
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
//  F: guardar el trazo como ROI de área
// ------------------------------------------------------------
macro "Guardar trazo [f]" {
    guardarTrazo();
}

function guardarTrazo() {
    if (!hayImagen()) exit;

    tipo = selectionType();
    if (tipo == -1) {
        showMessage("Sin selección", "Traza primero la estructura con la herramienta Segmented Line.");
        exit;
    }
    // 5 recta, 6 segmented, 7 freehand. El 8 es angle y no sirve.
    if (tipo != 5 && tipo != 6 && tipo != 7) {
        showMessage("Tipo de selección incorrecto",
            "Necesitas una selección de línea.\n \n" +
            "Elige la herramienta Segmented Line y traza el eje de la estructura\n" +
            "(doble clic para terminar el trazo).");
        exit;
    }

    // La primera vez pide el ancho.
    if (!yaConfigurado) configurar();
    if (!yaConfigurado) exit;

    anchoPx = anchoEnPx();
    if (anchoPx <= 0) {
        showMessage("Ancho no convertible",
            "El ancho está en unidades físicas, pero esta imagen no tiene escala.\n" +
            "Define la escala (Analyze > Set Scale...) o cambia el ancho a px con C.");
        exit;
    }

    // Fit Spline falla con línea recta, solo para segmented y freehand.
    if (tipo == 6 || tipo == 7) run("Fit Spline");

    // Largo del eje antes de convertir a área (en unidades de la escala).
    largo = getValue("Length");

    // Ancho con Roi.setStrokeWidth justo antes de Line to Area.
    Roi.setStrokeWidth(anchoPx);
    run("Line to Area");

    // Largo y ancho se guardan como propiedades del ROI (quedan en el RoiSet.zip).
    Roi.setProperty("largo", d2s(largo, 4));
    Roi.setProperty("ancho_px", d2s(anchoPx, 4));
    Roi.setProperty("version", VERSION);

    n = roiManager("count");
    roiManager("Add");
    roiManager("Select", n);
    roiManager("Rename", baseDelTitulo() + "_" + IJ.pad(n + 1, 3));

    // getStatistics no escribe en Resultados, así no se duplican filas al exportar.
    getStatistics(area, media);
    showStatus("ROI " + (n + 1) + " guardado  |  largo=" + d2s(largo, 2) +
               "  area=" + d2s(area, 3) + "  media=" + d2s(media, 2) +
               "  |  F=guardar  D=deshacer  M=exportar");

    run("Select None");
    setTool("polyline");
}


// ------------------------------------------------------------
//  D: deshacer el último ROI
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
//  M: medir todo y exportar
// ------------------------------------------------------------
macro "Medir y exportar [m]" {
    if (!hayImagen()) exit;
    if (roiManager("count") == 0) {
        showMessage("ROI Manager vacío", "Guarda al menos un trazo con la tecla F antes de exportar.");
        exit;
    }
    dir = getDirectory("Elige dónde guardar los resultados");
    if (dir == "") exit;                 // cancelado
    exportar(dir);
}

function exportar(dir) {
    n = roiManager("count");
    idImagen = getImageID();
    run("Set Measurements...", MEDICIONES);

    // Cada ROI se mide una vez, en orden.
    run("Clear Results");
    for (i = 0; i < n; i++) {
        roiManager("Select", i);
        roiManager("Measure");
    }

    if (nResults != n) {
        showMessage("Advertencia",
            "Se esperaban " + n + " mediciones y se obtuvieron " + nResults + ".\n" +
            "Revisa la tabla de Resultados antes de usar el archivo.");
    }

    // Largo y ancho se agregan después, ya con todas las filas medidas.
    sumaLargo = 0;
    nLargo = 0;
    for (i = 0; i < n && i < nResults; i++) {
        roiManager("Select", i);
        largo   = Roi.getProperty("largo");      // "" en ROIs de v2.0
        anchoPx = Roi.getProperty("ancho_px");
        setResult("Largo", i, parseFloat(largo));
        setResult("Ancho_px", i, parseFloat(anchoPx));
        if (largo != "") {
            sumaLargo += parseFloat(largo);
            nLargo++;
        }
    }
    updateResults();
    run("Select None");

    base = baseDelTitulo();
    saveAs("Results", dir + base + "_resultados.csv");
    roiManager("Deselect");
    roiManager("Save", dir + base + "_RoiSet.zip");
    guardarParametros(dir + base + "_parametros.txt", n);
    guardarControl(dir + base + "_control.png", idImagen);

    resumen = "";
    if (nLargo > 0) resumen = "Longitud media: " + d2s(sumaLargo / nLargo, 2) + "\n";
    if (nLargo < n) resumen = resumen + (n - nLargo) + " ROI(s) sin longitud (trazos de v2.0)\n";

    if (silencioso) return;
    showMessage("Exportación completa",
        n + " estructuras medidas.\n" + resumen + " \n" +
        "  " + base + "_resultados.csv\n" +
        "  " + base + "_RoiSet.zip\n" +
        "  " + base + "_parametros.txt\n" +
        "  " + base + "_control.png\n \n" +
        "Ancho de trazo: " + textoAncho() + "\n" +
        "Carpeta: " + dir);
}

// Parámetros de la medición, para poder repetirla.
function guardarParametros(ruta, n) {
    getPixelSize(u, pw, ph);
    getDateAndTime(an, mes, dsem, dia, h, mi, s, ms);
    fecha = "" + an + "-" + IJ.pad(mes + 1, 2) + "-" + IJ.pad(dia, 2) + " " +
            IJ.pad(h, 2) + ":" + IJ.pad(mi, 2);
    f = File.open(ruta);
    print(f, "flagelos.ijm v" + VERSION);
    print(f, "fecha=" + fecha);
    print(f, "imagej=" + getVersion());
    print(f, "imagen=" + getTitle());
    print(f, "carpeta_imagen=" + getInfo("image.directory"));
    print(f, "dimensiones_px=" + getWidth() + "x" + getHeight());
    print(f, "escala=" + pw + " " + u + "/px");
    print(f, "unidad_largo=" + u);
    print(f, "unidad_area=" + u + "^2");
    print(f, "ancho_trazo=" + textoAncho());
    print(f, "suavizado=Fit Spline (segmented y freehand line)");
    print(f, "mediciones=" + MEDICIONES);
    print(f, "n_rois=" + n);
    File.close(f);
}

// Imagen con los trazos numerados.
function guardarControl(ruta, idImagen) {
    selectImage(idImagen);
    roiManager("Show All with labels");
    run("Flatten");
    saveAs("PNG", ruta);
    close();
    selectImage(idImagen);
    roiManager("Show None");
}


// ------------------------------------------------------------
//  A: abrir un RoiSet para volver a medir
// ------------------------------------------------------------
macro "Abrir RoiSet [a]" {
    if (!hayImagen()) exit;
    if (roiManager("count") > 0) {
        if (!getBoolean("El ROI Manager tiene ROIs. ¿Reemplazarlos por el RoiSet?"))
            exit;
        roiManager("Reset");
    }
    ruta = File.openDialog("Elige el archivo _RoiSet.zip");
    if (ruta == "") exit;
    roiManager("Open", ruta);
    roiManager("Show All with labels");
    showStatus(roiManager("count") + " ROIs cargados. Pulsa M para volver a medir.");
}


// ------------------------------------------------------------
//  R: reiniciar la sesión
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
    showStatus("Sesión reiniciada. Ancho de trazo = " + textoAncho());
}


// ------------------------------------------------------------
//  H: ayuda
// ------------------------------------------------------------
macro "Ayuda [h]" {
    showMessage("flagelos.ijm v" + VERSION,
        "C  configurar ancho de trazo\n" +
        "F  guardar el trazo actual\n" +
        "D  deshacer el último ROI\n" +
        "M  medir y exportar\n" +
        "A  abrir un RoiSet para auditar\n" +
        "R  reiniciar la sesión\n \n" +
        "Ancho actual: " + textoAncho());
}

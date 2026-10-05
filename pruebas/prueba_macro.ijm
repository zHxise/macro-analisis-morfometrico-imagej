// Prueba de flagelos.ijm con la imagen sintética.
// Se corre desde correr_pruebas.sh (ahí se pega la macro y se definen RAIZ y SALIDA).

open(RAIZ + "ejemplo/espermatozoides_sintetico.tif");
lineas = split(File.openAsString(RAIZ + "ejemplo/verdad_terreno.csv"), "\n");

anchoValor = 0.5;           // µm
anchoUnidad = "fisica";
yaConfigurado = true;
silencioso = true;

for (i = 1; i < lineas.length; i++) {
    c = split(lineas[i], ",");
    xs = split(c[2], " ");
    ys = split(c[3], " ");
    for (k = 0; k < xs.length; k++) { xs[k] = parseFloat(xs[k]); ys[k] = parseFloat(ys[k]); }
    makeSelection("polyline", xs, ys);
    guardarTrazo();
}
// Línea recta, para checar que no truene en Fit Spline.
makeLine(300, 440, 420, 440);
guardarTrazo();
if (roiManager("count") != 4) exit("ERROR: se esperaban 4 ROIs");
macro_d();                  // deshacer la recta
if (roiManager("count") != 3) exit("ERROR: deshacer falló");

exportar(SALIDA);

// Reabrir el RoiSet y volver a medir tiene que dar lo mismo.
roiManager("Reset");
roiManager("Open", SALIDA + "espermatozoides_sintetico_RoiSet.zip");
dir2 = SALIDA + "reauditoria" + File.separator;
File.makeDirectory(dir2);
exportar(dir2);
File.saveString("OK", SALIDA + "terminado.txt");

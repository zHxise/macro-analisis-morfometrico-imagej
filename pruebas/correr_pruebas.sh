#!/usr/bin/env bash
# Corre la prueba en ImageJ con pantalla virtual (xvfb).
# Con -batch no se acumula la tabla de Resultados, por eso va con -macro.
# Uso: IJ_JAR=/ruta/a/ij.jar bash pruebas/correr_pruebas.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)/"
SALIDA="${RAIZ}pruebas/salida/"
rm -rf "$SALIDA"; mkdir -p "$SALIDA"
python "${RAIZ}pruebas/generar_sintetica.py"
# Los bloques macro "Nombre [x]" se vuelven function macro_x() para poder llamarlos
{
  echo "var RAIZ = \"$RAIZ\"; var SALIDA = \"$SALIDA\";"
  sed -E 's/^macro "[^"]*\[([a-z])\]" \{/function macro_\1() {/' "${RAIZ}flagelos.ijm"
  cat "${RAIZ}pruebas/prueba_macro.ijm"
  echo 'eval("script", "System.exit(0);");'
} > "${SALIDA}_prueba_completa.ijm"
timeout 120 xvfb-run -a java -jar "${IJ_JAR:?define IJ_JAR}" -macro "${SALIDA}_prueba_completa.ijm" > /dev/null 2>&1 || true
[ -f "${SALIDA}terminado.txt" ] || { echo "La macro no terminó"; exit 1; }
python "${RAIZ}pruebas/comparar.py" "$SALIDA"

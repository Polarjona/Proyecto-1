#!/usr/bin/env bash
# Batería de tests headless del proyecto.
#
# Uso:
#   tools/run_tests.sh          # suite verde (la que debe pasar siempre)
#   tools/run_tests.sh --all    # añade los tests largos/inestables
#
# GODOT puede apuntar a otro binario: GODOT=/ruta/godot tools/run_tests.sh
# Requiere haber abierto el proyecto una vez (importacion y cache de clases).
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"

TESTS=(
  persistence_test
  check_scenes
  smoke_test
  flow_test
  levels_test
  progression_test
  settings_test
  features_test
  iteration3_test
  iteration4_test
  iteration5_test
)

if [[ "${1:-}" == "--all" ]]; then
  TESTS+=(bots_test slow_test levels_bots_test)
fi

fail=0
for test_name in "${TESTS[@]}"; do
  printf '\n== %s ==\n' "$test_name"
  if ! "$GODOT" --headless --path . -s "res://tools/${test_name}.gd"; then
    printf 'FALLO: %s\n' "$test_name"
    fail=1
  fi
done

if [[ $fail -eq 0 ]]; then
  printf '\nTODOS LOS TESTS OK (%d)\n' "${#TESTS[@]}"
else
  printf '\nHAY TESTS EN ROJO\n'
fi
exit $fail

#!/usr/bin/env bash
# Batería de tests headless del proyecto.
#
# Uso:
#   tools/run_tests.sh            # suite obligatoria (tiene que pasar siempre)
#   tools/run_tests.sh --long     # solo los tests largos de bots
#   tools/run_tests.sh --all      # suite + largos
#
# Variables de entorno:
#   GODOT=/ruta/godot    binario de Godot a usar (por defecto `godot`)
#   TEST_TIMEOUT=180     segundos máximos por test de la suite
#   LONG_TIMEOUT=900     segundos máximos por test largo
#
# Cada test corre con `timeout`, así que un cuelgue se marca en rojo en vez de
# colgar la CI. El resumen se imprime, se guarda en `tools/test-logs/summary.md`
# y, dentro de GitHub Actions, se copia al resumen del job.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${TEST_TIMEOUT:-180}"
LONG_TIMEOUT="${LONG_TIMEOUT:-900}"
LOG_DIR="tools/test-logs"
SUMMARY="$LOG_DIR/summary.md"

SUITE=(
  persistence_test
  check_scenes
  smoke_test
  flow_test
  levels_test
  lod_test
  progression_test
  settings_test
  features_test
  iteration3_test
  iteration4_test
  iteration5_test
)
LONG_SUITE=(
  levels_bots_test
  bots_test
  slow_test
)

case "${1:-}" in
  --long) TESTS=("${LONG_SUITE[@]}") ;;
  --all) TESTS=("${SUITE[@]}" "${LONG_SUITE[@]}") ;;
  "") TESTS=("${SUITE[@]}") ;;
  *)
    printf 'Uso: %s [--long|--all]\n' "$0"
    exit 2
    ;;
esac

# `timeout` de coreutils no existe en todas partes (Git Bash de Windows trae el
# `timeout.exe` de Windows, que no vale): sin él la batería sigue, solo pierde
# el corte por tiempo.
if timeout --version > /dev/null 2>&1; then
  HAS_TIMEOUT=1
else
  HAS_TIMEOUT=0
  printf 'AVISO: no hay `timeout` de coreutils; los tests no se cortan por tiempo.\n'
fi

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

rows=()
passed=0
fail=0

for test_name in "${TESTS[@]}"; do
  script="tools/${test_name}.gd"
  printf '\n== %s ==\n' "$test_name"
  if [[ ! -f "$script" ]]; then
    printf 'AVISO: no existe %s, se omite\n' "$script"
    rows+=("| \`$test_name\` | omitido (no existe) |")
    fail=1
    continue
  fi

  limit="$TEST_TIMEOUT"
  case " ${LONG_SUITE[*]} " in
    *" $test_name "*) limit="$LONG_TIMEOUT" ;;
  esac

  log="$LOG_DIR/${test_name}.log"
  if [[ $HAS_TIMEOUT -eq 1 ]]; then
    timeout "$limit" "$GODOT" --headless --path . -s "res://${script}" > "$log" 2>&1
  else
    "$GODOT" --headless --path . -s "res://${script}" > "$log" 2>&1
  fi
  status=$?

  if [[ $status -eq 0 ]]; then
    grep -a -E "^(RESULT|SMOKE|TODO LOS|TODOS LOS)" "$log" | tail -n 1
    rows+=("| \`$test_name\` | OK |")
    passed=$((passed + 1))
  elif [[ $status -eq 124 ]]; then
    printf 'TIMEOUT: %s no terminó en %s s\n' "$test_name" "$limit"
    rows+=("| \`$test_name\` | timeout (${limit} s) |")
    fail=1
  else
    printf 'FALLO: %s (código %d)\n' "$test_name" "$status"
    rows+=("| \`$test_name\` | fallo (código $status) |")
    grep -a -E "^(FAIL|ERROR|SCRIPT ERROR)" "$log" | head -n 10
    tail -n 15 "$log"
    fail=1
  fi
done

total=${#TESTS[@]}
{
  printf '## Batería headless\n\n'
  printf '%d/%d en verde\n\n' "$passed" "$total"
  printf '| Test | Resultado |\n| --- | --- |\n'
  printf '%s\n' "${rows[@]}"
} > "$SUMMARY"

printf '\n'
cat "$SUMMARY"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "$SUMMARY" >> "$GITHUB_STEP_SUMMARY"
fi

if [[ $fail -eq 0 ]]; then
  printf '\nTODOS LOS TESTS OK (%d)\n' "$total"
else
  printf '\nHAY TESTS EN ROJO\n'
fi
exit $fail

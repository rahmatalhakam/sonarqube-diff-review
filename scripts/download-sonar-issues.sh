#!/usr/bin/env bash
# scripts/download-sonar-issues.sh

set -euo pipefail

SONAR_URL="${SONAR_URL:-}"
SONAR_TOKEN="${SONAR_TOKEN:-}"
OUTPUT_FILE="sonarqube-issues.json"
AUTH_MODE="basic"
CURL_CONFIG=""
TEMP_PATH=""

usage() {
  echo "Usage: $0 [--url SONAR_URL] [--token SONAR_TOKEN] [--output sonarqube-issues.json] [--auth-mode basic|bearer]"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$CURL_CONFIG" && -f "$CURL_CONFIG" ]]; then
    rm -f "$CURL_CONFIG"
  fi

  if [[ -n "$TEMP_PATH" && -f "$TEMP_PATH" ]]; then
    rm -f "$TEMP_PATH"
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      [[ $# -ge 2 ]] || die "Missing value for --url."
      SONAR_URL="$2"
      shift 2
      ;;
    --token)
      [[ $# -ge 2 ]] || die "Missing value for --token."
      SONAR_TOKEN="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || die "Missing value for --output."
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --auth-mode)
      [[ $# -ge 2 ]] || die "Missing value for --auth-mode."
      AUTH_MODE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown argument: $1"
      ;;
  esac
done

echo "Checking Git project root..."

if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  die "Current directory is not inside a Git repository."
fi

cd "$PROJECT_ROOT"

[[ -n "$SONAR_URL" ]] || die "Missing SonarQube URL. Provide --url or set SONAR_URL."
[[ -n "$SONAR_TOKEN" ]] || die "Missing SonarQube token. Provide --token or set SONAR_TOKEN."
command -v curl >/dev/null 2>&1 || die "curl is required to download SonarQube issues."

case "$AUTH_MODE" in
  basic|bearer)
    ;;
  *)
    die "Invalid auth mode. Use basic or bearer."
    ;;
esac

case "$OUTPUT_FILE" in
  ""|*/*|*\\*|*..*)
    die "Output filename must be a simple file name inside the Git project root."
    ;;
esac

OUTPUT_PATH="$PROJECT_ROOT/$OUTPUT_FILE"
TEMP_PATH="$OUTPUT_PATH.tmp"
CURL_CONFIG="$(mktemp)"
chmod 600 "$CURL_CONFIG"

if [[ "$AUTH_MODE" == "bearer" ]]; then
  printf 'header = "Authorization: Bearer %s"\n' "$SONAR_TOKEN" > "$CURL_CONFIG"
else
  printf 'user = "%s:"\n' "$SONAR_TOKEN" > "$CURL_CONFIG"
fi

echo "Downloading SonarQube issues..."
echo "Output file: $OUTPUT_PATH"

curl --fail --silent --show-error --location --config "$CURL_CONFIG" --output "$TEMP_PATH" "$SONAR_URL"

[[ -f "$TEMP_PATH" ]] || die "Download failed. No output file was created."
[[ -s "$TEMP_PATH" ]] || die "Download failed. Output file is empty."

if command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
else
  die "Python is required to validate JSON."
fi

if ! "$PYTHON_BIN" - "$TEMP_PATH" <<'PY'
import json
import sys

path = sys.argv[1]

try:
    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
except Exception as exc:
    print(f"Error: downloaded file is not valid JSON: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(payload, dict) or "issues" not in payload:
    print("Error: downloaded JSON is not a SonarQube issues response because it has no 'issues' property.", file=sys.stderr)
    sys.exit(1)
PY
then
  exit 1
fi

mv -f "$TEMP_PATH" "$OUTPUT_PATH"
TEMP_PATH=""

echo "SonarQube issue report downloaded successfully."
echo "Saved to: $OUTPUT_PATH"

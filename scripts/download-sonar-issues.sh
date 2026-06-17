#!/usr/bin/env bash
# scripts/download-sonar-issues.sh

set -euo pipefail

SONAR_URL=""
OUTPUT_FILE="sonarqube-issues.json"
AUTH_MODE="bearer"
SESSION_ID=""
TEMP_PATH=""

usage() {
  echo "Usage: $0 --url SONAR_URL [--output sonarqube-issues.json] [--auth-mode bearer|basic] [--session-id SESSION_ID]"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_PATH" && -f "$TEMP_PATH" ]]; then
    rm -f "$TEMP_PATH"
  fi
}

trap cleanup EXIT

find_powershell() {
  local candidate

  for candidate in pwsh powershell.exe powershell; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

get_persistent_sonar_token() {
  local powershell_bin

  if ! powershell_bin="$(find_powershell)"; then
    return 1
  fi

  "$powershell_bin" -NoProfile -NonInteractive -Command '$token = [System.Environment]::GetEnvironmentVariable("SONAR_TOKEN", [System.EnvironmentVariableTarget]::User); if ([string]::IsNullOrWhiteSpace($token)) { $token = [System.Environment]::GetEnvironmentVariable("SONAR_TOKEN", [System.EnvironmentVariableTarget]::Machine) }; if (-not [string]::IsNullOrWhiteSpace($token)) { [Console]::Out.Write($token) }'
}

new_session_id() {
  printf '%s-%s\n' "$(date -u '+%Y%m%dT%H%M%SZ')" "$$"
}

assert_simple_name() {
  local value="$1"
  local label="$2"

  case "$value" in
    ""|*/*|*\\*|*..*)
      die "$label must be a simple name without path separators."
      ;;
  esac
}

assert_sonar_url() {
  local url="$1"
  local lower_url
  local authority

  case "$url" in
    http://*|https://*)
      ;;
    *)
      die "SonarQube URL must be an absolute HTTP or HTTPS URL."
      ;;
  esac

  authority="${url#*://}"
  authority="${authority%%[/?#]*}"
  case "$authority" in
    *@*)
      die "SonarQube URL must not contain embedded credentials."
      ;;
  esac

  lower_url="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"
  case "$lower_url" in
    *\?token=*|*&token=*|*\?access_token=*|*&access_token=*|*\?authorization=*|*&authorization=*|*\?auth=*|*&auth=*|*\?password=*|*&password=*|*\?passwd=*|*&passwd=*|*\?secret=*|*&secret=*)
      die "SonarQube URL appears to contain a secret. Remove secrets from the URL before running this helper."
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      [[ $# -ge 2 ]] || die "Missing value for --url."
      SONAR_URL="$2"
      shift 2
      ;;
    --token)
      die "Token input via --token is not supported. Set persistent SONAR_TOKEN with [System.Environment]::SetEnvironmentVariable before running this helper."
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
    --session-id)
      [[ $# -ge 2 ]] || die "Missing value for --session-id."
      SESSION_ID="$2"
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

[[ -n "$SONAR_URL" ]] || die "Missing SonarQube URL. Provide --url with the SonarQube issues API URL. SONAR_URL is intentionally ignored."
assert_sonar_url "$SONAR_URL"

if ! SONAR_TOKEN="$(get_persistent_sonar_token)"; then
  die "Persistent SONAR_TOKEN requires PowerShell or pwsh so the helper can read [System.Environment] values."
fi

[[ -n "$SONAR_TOKEN" ]] || die "Missing persistent SONAR_TOKEN. Set SONAR_TOKEN in the User or Machine environment with [System.Environment]::SetEnvironmentVariable before running this helper. Do not use process SONAR_TOKEN, command arguments, prompts, or chat."
command -v curl >/dev/null 2>&1 || die "curl is required to download SonarQube issues."

case "$AUTH_MODE" in
  basic|bearer)
    ;;
  *)
    die "Invalid auth mode. Use basic or bearer."
    ;;
esac

assert_simple_name "$OUTPUT_FILE" "Output filename"

if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="$(new_session_id)"
fi

assert_simple_name "$SESSION_ID" "Session id"

ARTIFACT_ROOT="$PROJECT_ROOT/.sonarqube-diff-review"
SESSION_DIR="$ARTIFACT_ROOT/$SESSION_ID"
mkdir -p "$SESSION_DIR"

OUTPUT_PATH="$SESSION_DIR/$OUTPUT_FILE"
TEMP_PATH="$SESSION_DIR/$OUTPUT_FILE.tmp"

if [[ "$AUTH_MODE" == "bearer" ]]; then
  CURL_CONFIG_DATA="$(printf 'header = "Authorization: Bearer %s"\n' "$SONAR_TOKEN")"
else
  CURL_CONFIG_DATA="$(printf 'user = "%s:"\n' "$SONAR_TOKEN")"
fi

echo "Downloading SonarQube issues..."
echo "Artifact session: $SESSION_ID"
echo "Output file: $OUTPUT_PATH"

if ! printf '%s' "$CURL_CONFIG_DATA" | curl --fail --silent --show-error --location --config - --output "$TEMP_PATH" "$SONAR_URL"; then
  unset CURL_CONFIG_DATA SONAR_TOKEN
  die "Download failed. curl exited with a non-zero status."
fi

unset CURL_CONFIG_DATA SONAR_TOKEN

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

#!/bin/bash

set -euo pipefail

AIBOX_SCRIPT_VERSION="1.0.0"
DEFAULT_TOOL="opencode"

TOOL_NAMES="opencode|kilocode|pi"

WORKDIR_FLAG=""
IMAGE_FLAG=""
ENV_FLAGS=()
HELP_FLAG=false

load_config() {
  local config_file=""

  if [[ -f "$HOME/.aiboxrc" ]]; then
    source "$HOME/.aiboxrc"
  fi

  if [[ -f ".aiboxrc" ]]; then
    source ".aiboxrc"
  fi
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -w|--workdir)
        WORKDIR_FLAG="$2"
        shift 2
        ;;
      -i|--image)
        IMAGE_FLAG="$2"
        shift 2
        ;;
      -e|--env)
        ENV_FLAGS+=("$2")
        shift 2
        ;;
      -h|--help)
        HELP_FLAG=true
        shift
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        exit 1
        ;;
      *)
        TOOL_NAME="$1"
        shift
        ;;
    esac
  done

  if $HELP_FLAG; then
    show_usage
    exit 0
  fi

  if [[ -z "${TOOL_NAME:-}" ]]; then
    load_config
    TOOL_NAME="${AIBOX_DEFAULT_TOOL:-}"
  fi

  if [[ -z "$TOOL_NAME" ]]; then
    echo "Error: No tool specified. Use -h for help."
    exit 1
  fi
}

show_usage() {
  cat << EOF
Usage: aibox [OPTIONS] <tool>

Arguments:
  tool          AI coding tool to run: $TOOL_NAMES

Options:
  -w, --workdir PATH    Project directory to mount (default: current directory)
  -i, --image IMAGE     Custom Docker image to use
  -e, --env KEY=VALUE   Pass environment variable into container (repeatable)
  -h, --help            Show this help message

Environment Variables:
  AIBOX_DEFAULT_TOOL    Default tool to run if none specified (default: $DEFAULT_TOOL)
  AIBOX_IMAGE          Default Docker image to use

Examples:
  aibox opencode
  aibox kilocode
  aibox pi
  aibox -w ~/my-project opencode
  aibox -e OPENAI_API_KEY=\$OPENAI_API_KEY opencode

EOF
}

validate_tool() {
  if [[ -z "$TOOL_NAME" ]]; then
    echo "Error: No tool specified. Use -h for help."
    exit 1
  fi

  if [[ ! "${TOOL_NAME:-}" =~ ^($TOOL_NAMES)$ ]]; then
    echo "Error: Invalid tool '${TOOL_NAME:-}'. Supported tools: $TOOL_NAMES"
    exit 1
  fi
}

get_docker_image() {
  if [[ -n "$IMAGE_FLAG" ]]; then
    echo "$IMAGE_FLAG"
    return
  fi

  local TOOL_NAME="${1:-}"
  local base_image=""

  if [[ -z "$TOOL_NAME" ]]; then
    echo "Error: No tool name provided" >&2
    exit 1
  fi

  case "$TOOL_NAME" in
    opencode)
      base_image="ghcr.io/anomalyco/opencode:latest"
      ;;
    kilocode)
      base_image="ghcr.io/kilo-org/kilo:latest"
      ;;
    pi)
      base_image="pi-dev:latest"
      ;;
    *)
      echo "Error: No image configured for tool '$TOOL_NAME'" >&2
      exit 1
      ;;
  esac

  if [[ -z "$base_image" ]]; then
    echo "Error: No image configured for tool '$TOOL_NAME'" >&2
    exit 1
  fi

  echo "$base_image"
}

check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH" >&2
    exit 1
  fi

  if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running" >&2
    exit 1
  fi
}

execute_opencode() {
  local workdir="$1"
  local image="$2"
  shift 2

  echo "Running opencode in Docker container..."

  container run -it --rm \
    -v "$workdir:/workspace" \
    -w /workspace \
    "$image" \
    "$@"

  # docker run -it --rm \
  #   -v "$workdir:/workspace" \
  #   -w /workspace \
  #   "${ENV_FLAGS[@]}" \
  #   "$image" \
  #   "$@"
}

execute_kilocode() {
  local workdir="$1"
  local image="$2"
  shift 2

  echo "Running kilocode in Docker container..."

  container run -it --rm \
    -v "$workdir:/workspace" \
    -w /workspace \
    "$image" \
    "$@"
}

execute_pi() {
  local workdir="$1"
  local image="$2"
  shift 2

  echo "Running pi in Docker container..."

  container run -it --rm \
    -v "$workdir:/workspace" \
    -v "$HOME/.pi/agent/models.json:/home/piuser/.pi/agent/models.json" \
    -w /workspace \
    "$image" \
    "$@"
}

main() {
  local tool_name
  local workdir
  local image

  parse_arguments "$@"

  validate_tool

  if [[ -n "$WORKDIR_FLAG" ]]; then
    workdir="$WORKDIR_FLAG"
  else
    workdir="$(pwd)"
  fi

if [[ ! -d "$workdir" ]]; then
    echo "Error: Workdir does not exist: $workdir" >&2
    exit 1
  fi

  # check_docker

  image=$(get_docker_image "$TOOL_NAME")
  case "$TOOL_NAME" in
    opencode)
      execute_opencode "$workdir" "$image"
      ;;
    kilocode)
      execute_kilocode "$workdir" "$image"
      ;;
    pi)
      execute_pi "$workdir" "$image"
      ;;
    *)
      echo "Error: Unknown tool '$TOOL_NAME'" >&2
      exit 1
      ;;
  esac
}

main "$@"
#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then #If being sourced
  set -euE
fi

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)/wrap"
cd "${AMANDA_CWD}"

source "${VSI_COMMON_DIR}/linux/docker_functions.bsh"

function caseify()
{
  local just_arg=$1
  shift 1
  case ${just_arg} in
    build)
      (justify client build)
      (justify server build server)
      ;;
    push)
      (justify client push)
      (justify server push)
      ;;
    client) # Run docker compose command for the client. E.g. "client run"
      Docker-compose "${@}"
      extra_args+=$#
      ;;
    server) # Run docker compose command for the server
      if [ "$#" = "0" ]; then
        Docker-compose -f "${AMANDA_CWD}/server.yml" run server
      else
        Docker-compose -f "${AMANDA_CWD}/server.yml" "${@}"
        extra_args+=$#
      fi
      ;;

    backup) # Start a backup on the server
      (justify server up -d backup)
      (justify server logs)
      ;;
    abort) # Abort a backup on the server
      for docker_id in $(docker-compose ps -q backup); do
        docker exec ${docker_id} amcleanup -k ${AMANDA_CONFIG_NAME}
      done
      ;;
    *)
      defaultify "${just_arg}" ${@+"${@}"}
      ;;
  esac
}

if ! command -v justify &> /dev/null; then caseify ${@+"${@}"};fi


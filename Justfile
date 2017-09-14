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
      (justify server push server)
      ;;
    client) # Run docker compose command for the client. E.g. "client run"
      if [ "$#" = "0" ]; then
        (justify client run amandad)
      else
        COMPOSE_API_VERSION=1.21 Docker-compose -f "${AMANDA_CWD}/docker-compose1.yml" "${@}"
        extra_args+=$#
      fi
      ;;
    server) # Run docker compose command for the server
      if [ "$#" = "0" ]; then
        (justify server run server)
      else
        Docker-compose -f "${AMANDA_CWD}/server.yml" "${@}"
        extra_args+=$#
      fi
      ;;

    upload) # upload amanda configuration
      cd "${AMANDA_CWD}/${AMANDA_CONFIG_NAME}"
      tar zc * | docker run -i --rm -v "amanda_amanda-config":/cp -w /cp alpine tar zx
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


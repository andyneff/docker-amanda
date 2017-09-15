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
    # recipe_amanda) # Build Amanda recipe
    # recipe_gosu) # Build Gosu recipe
    # recipe_tini) # Build tini recipe
    recipe_*)
      Docker-compose -f recipes.yml build ${just_arg#*_}
      ;;
    recipes)
      Docker-compose -f recipes.yml build "${@}"
      extra_args+=$#
      ;;
    build) # Build everything
      (justify recipes)
      (justify client build)
      (justify server build server)
      ;;
    push) # Push to dockerhub
      (justify client push)
      (justify server push server)
      ;;
    client) # Run docker compose command for the client. E.g. "client run"
      if [ "$#" = "0" ]; then
        (justify client up -d amandad)
      else
        if command -v docker1.21 >&/dev/null && [ "$(docker1.21 info 2>/dev/null | sed -n '/^Server Version/{s/Server Version: //p;q}')" == "1.9.1" ]; then
          export COMPOSE_API_VERSION=1.21
          export COMPOSE_FILE="${AMANDA_CWD}/docker-compose1.yml"
        fi
        Docker-compose "${@}"
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
      (justify server run server tail -n +1 -f /etc/amanda/vsidata/log /etc/amanda/vsidata/amdump)
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


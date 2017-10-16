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
        (justify client logs -f)
      else
        if command -v docker1.23 >&/dev/null && [ "$(docker1.23 info 2>/dev/null | sed -n '/^Server Version/{s/Server Version: //p;q}')" == "1.11.2" ]; then
          export COMPOSE_API_VERSION=1.23
          #export COMPOSE_FILE="${AMANDA_CWD}/docker-compose1.yml"
        fi
        Docker-compose "${@}"
        extra_args+=$#
      fi
      ;;
    server) # Run docker compose command for the server
      if [ "$#" = "0" ]; then
        (justify server up -d server)
      else
        Docker-compose -f "${AMANDA_CWD}/server.yml" "${@}"
        extra_args+=$#
      fi
      ;;

    backup) # Start a backup on the server
      (justify server up -d backup)
      # (justify server logs -f backup)
      (justify server run server tail -n +1 -f /etc/amanda/vsidata/log /etc/amanda/vsidata/amdump /etc/amanda/vsidata/xinetd)
      ;;

    abort) # Abort a backup in progress
      (justify server exec backup amcleanup -k ${AMANDA_CONFIG_NAME})
    #   for docker_id in $(docker-compose ps -q backup); do
    #     docker exec ${docker_id} amcleanup -k ${AMANDA_CONFIG_NAME}
    #   done
      ;;

    cleanup) # Cleanup an interrupted backup
      (justify server run server amcleanup ${AMANDA_CONFIG_NAME})
      ;;

    check) # Test amanda configuration and check which tape is inserted and if
           # it is valid, also tests clients
      (justify server run server amcheck ${AMANDA_CONFIG_NAME})
      ;;

    list-tapes) # List tapes in the tape drive(s) for the current configuration
      (justify server run server amtape ${AMANDA_CONFIG_NAME} show)
      ;;

    current-tape) #Display current slot/tape
      (justify server run server amtape ${AMANDA_CONFIG_NAME} current)
      ;;

    rewind) # Rewind tape. This should not be part of normal operation
      (justify server run server mt -f /dev/nst0 rewind)
      ;;

    eject) # Eject current tape
      (justify server run server mt-st -f /dev/nst0 eject)
      ;;


    dump-backup) #Use in conjunction with | tar tv, or | tar xv
      (justify server run server amrecover /dev/nst0 -)
      ;;

    print-config) # Print configuration
      (justify server run server amadmin ${AMANDA_CONFIG_NAME} config)
      ;;

# #  recover:
# #    image: vsiri/amanda:client
# #    command: ["amrecover", "${AMANDA_CONFIG_NAME}", "-s", "jacquard"]

    upload) # Upload amanda configuration to connected docker server
      cd "${AMANDA_CWD}/${AMANDA_CONFIG_NAME}"
      tar zc * | docker run -i --rm -v "amanda_amanda-config":/cp -w /cp alpine tar zx
      ;;


    gpg_list) # List gpg keys
      (justify server run server gpg2 --fingerprint --with-colons)
      ;;

    gpg_recv) # Download gpg key by keyid
      (justify server run server gpg2 --keyserver hkps.pool.sks-keyservers.net --recv-key "${1}")
      extra_args+=1
      ;;

    gpg_trust) #Ultimately trust key. Must use entire fingerprint
      echo "${1}:6" | (justify server run server gpg2 --import-ownertrust)
      extra_args+=1
      ;;
    *)
      defaultify "${just_arg}" ${@+"${@}"}
      ;;
  esac
}

if ! command -v justify &> /dev/null; then caseify ${@+"${@}"};fi


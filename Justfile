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
      Docker-compose -f "${AMANDA_CWD}/recipes.yml" build "${@}"
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
    dropbox)
      Docker-compose -f "${AMANDA_CWD}/dropbox.yml" up -d --build --force-recreate
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
      (justify server run -d backup)
      # (justify server logs -f backup)
      (justify server run server tail -n +1 -f /etc/amanda/persist/vsidata/log /etc/amanda/persist/vsidata/amdump)
      ;;

    pull-server-ssh) # Pull the server ssh public key
      (justify server run server cat /etc/keys/id_rsa.pub) > server.pub
      ;;
    pull-client-ssh) # Pull the server ssh public key
      (justify client run amandad cat /etc/keys/id_rsa.pub) > client.pub
      ;;


    push-client-ssh) # Push the server ssh key to the client
      (justify client run amandad bash -c "cat - >> /etc/keys/authorized_keys") < server.pub
      ;;
    push-server-ssh) # Push the server ssh key to the client
      (justify server run server bash -c "cat - >> /etc/keys/authorized_keys") < client.pub
      ;;

    abort) # Abort a backup in progress
      (justify server exec backup amcleanup -k ${AMANDA_CONFIG_NAME})
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


    gpg-suggest-password) # Suggest a good random password
      head -c 48 /dev/urandom | openssl base64
      ;;
    gpg-keys) # Generate new gpg encrypted keys for backup
      (justify server run server bash -c \
       'x=1; while [ "$x" != "$y" ]; do
          read -rsp "Password: " x; echo
          read -rsp "Confirm: " y; echo
        done
        echo -n "$x" > /etc/keys/.am_passphrase
        head -c 3120 /dev/urandom | openssl base64 | head -n 66 | tail -n 65 | \
          gpg2 --batch --cipher-algo aes256 --symmetric -a --passphrase-file /etc/keys/.am_passphrase > \
          /etc/amanda/persist/vsidata/am_key.gpg')
      ;;
    *)
      defaultify "${just_arg}" ${@+"${@}"}
      ;;
  esac
}

if ! command -v justify &> /dev/null; then caseify ${@+"${@}"};fi


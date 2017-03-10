if [ -f "${VSI_COMMON_DIR}/linux/just_functions.bsh" ]; then
  source "${VSI_COMMON_DIR}/linux/just_functions.bsh"
fi

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)

: ${DRYRUN=}

function Docker()
{
  $DRYRUN docker "${@}"
}

function caseify()
{
  local just_arg=$1
  shift 1

  case ${just_arg} in
    build) #for dev
      Docker build -t andyneff/amanda:client -f client.Dockerfile .
      Docker build -t andyneff/amanda:server -f server.Dockerfile .
      ;;
    push) #for dev
      Docker push andyneff/amanda:client
      Docker push andyneff/amanda:server
      ;;
    client)
      docker network create amanda-test &> /dev/null || :
      #Docker run -d --restart=always -p 10080:10080 --name amanda_client andyneff/amanda:client
      Docker run -it --rm -p 10080:10080 --name amanda-client \
                 -e SERVER_NAME=amanda-server.amanda-test \
                 --hostname amanda-client --network amanda-test \
                 andyneff/amanda:client ${@+"${@}"}
      ;;
    server)
      docker network create amanda-test &> /dev/null || :
      mkdir -p "${CURDIR}/data/daily/log"
      mkdir -p "${CURDIR}/data/daily/vdisk/slots"
      for ((i=1; i<=15; i++)); do mkdir -p "${CURDIR}/data/daily/vdisk/slots/slot$i"; done
      Docker run -it --rm -v "${CURDIR}/etc":/etc/amanda \
                 -v "${CURDIR}/data":/var/lib/amanda \
                 --network amanda-test \
                 --name amanda-server \
                 --hostname amanda-server \
                 andyneff/amanda:server "${@}"
      ;;
    label_vdisk) #step 7
      for ((i=1; i<=15; i++)); do
          "$0" server amlabel daily daily-$i slot $i
      done
      ;;
  esac
}

if ! command -v justify &> /dev/null; then function justify(){ caseify ${@+"${@}"};};fi

justify ${@+"${@}"}

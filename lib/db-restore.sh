#!/usr/bin/env bash

require_app_root_dir

LOCAL_MONGO_URL="mongodb://localhost:27017/meteor"
DUMP_ROOT_DIR="./.dump"

function print_restore_status {
  local drop_flag=$1
  local drop_enabled=$([[ ${drop_flag} == "" ]] && echo "NO" || echo "YES")
  local _db_restore_status_msg

  read -r -d '' _db_restore_status_msg << EOF
${COLOR_ERROR}${TEXT_BOLD}
######################################
# WARNING!!!                         #
# You may lost data at remote server #
######################################
${COLOR_DEFAULT}
Server: ${SERVER_DESCRIPTION}
URL: ${TEXT_UNDERLINE}${ROOT_URL}${COLOR_DEFAULT}
Drop enabled: ${TEXT_BOLD}${COLOR_ERROR}${drop_enabled}${COLOR_DEFAULT}

Are you sure? (Enter 'yes' to continue):
EOF

  printf "${_db_restore_status_msg} "
}

function db-restore_help {
  cat << EOF
This script enables restoring of database from local project directory to remote server

boo db-restore server_name [--no-drop|-D] [-v|--verbose]

Options:
--no-drop|-D  - prevent all collections drop before dump restore
-v|--verbose  - verbose mode (print all logs)
EOF
}

function db-restore {
  local server_name=$1
  source_deploy_conf ${server_name}

  local app_local_db_path="$(pwd)/${BOO_LOCAL_DB_PATH}"
  local drop_flag='--drop'
  local output_stream=/dev/null

  # parse script arguments
  while [[ $(($#-1)) -gt 0 ]]; do
    local key="$2"

    case ${key} in
      --no-drop|-D)
      drop_flag=''
      ;;
      -v|--verbose)
      output_stream=/dev/stdout
      ;;
      *)
      echo_error "Unknown option: ${key}"
      exit 1
      ;;
    esac

    shift # past argument or value
  done

  # first get confirmation... just in case :)
  print_restore_status ${drop_flag}

  read CONFIRM

  if [[ ${CONFIRM} =~ ^yes$ ]]; then
    echo "Starting local database server... "
    mongod --dbpath "${app_local_db_path}" > ${output_stream} &

    local mongod_pid=$!
    sleep 20

    echo "Making local database dump..."
    mongodump --uri "${LOCAL_MONGO_URL}" --out "${DUMP_ROOT_DIR}" &> ${output_stream}

    kill ${mongod_pid}

    echo "Restoring database from dump..."

    mongorestore "${drop_flag}" \
      --uri "${MONGO_URL}" \
      --noIndexRestore "${DUMP_ROOT_DIR}/$(get_db_name_by_mongo_url ${LOCAL_MONGO_URL})"

    echo_success "Done! Local database restored to ${SERVER_DESCRIPTION}."
  fi
}

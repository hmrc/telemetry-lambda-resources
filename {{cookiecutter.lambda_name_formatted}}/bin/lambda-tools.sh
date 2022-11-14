#!/usr/bin/env bash

# A helper tool to assist us maintaining lambda functions
# Intention here is to keep this files and all its functions reusable for all Telemetry repositories

set -o errexit
set -o nounset

#####################################################################
## Beginning of the configurations ##################################

BASE_LOCATION="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAMBDA_ZIP_NAME="lambda.zip"
LAMBDA_HASH_NAME="${LAMBDA_ZIP_NAME}.base64sha256"
PATH_BUILD="${BASE_LOCATION}/build"
PROJECT_FULL_NAME="{{ cookiecutter.lambda_name_formatted }}"

S3_TELEMETRY_LAMBDA_ROOT="{{ cookiecutter.lambda_artifacts_bucket }}"
S3_LAMBDA_SUB_FOLDER="build-${PROJECT_FULL_NAME}"
S3_ADDRESS="s3://${S3_TELEMETRY_LAMBDA_ROOT}/${S3_LAMBDA_SUB_FOLDER}"

## End of the configurations ########################################
#####################################################################

debug_env(){
  echo BASE_LOCATION="${BASE_LOCATION}"
  echo PROJECT_FULL_NAME="${PROJECT_FULL_NAME}"
  echo PATH_BUILD="${PATH_BUILD}"
  echo S3_TELEMETRY_LAMBDA_ROOT="${S3_TELEMETRY_LAMBDA_ROOT}"
  echo S3_ADDRESS="${S3_ADDRESS}"
}

open_shell() {
    print_begins

    poetry export --without-hashes --format requirements.txt --with dev --output "requirements-tests.txt"
    docker run -it \
               --rm \
               --volume "${BASE_LOCATION}":/data \
               --workdir /data \
               --env REQUIREMENTS_FILE="requirements-tests.txt" \
               --env VENV_NAME="venv" \
               python:$(cat "${BASE_LOCATION}/.python-version")-slim-buster /data/bin/entrypoint.sh /bin/bash

    print_completed
}

# Prepare dependencies and run unit tests in a Docker environment
unittest() {
  print_begins

  poetry export --without-hashes --format requirements.txt --with dev --output "requirements-tests.txt"
  docker run --rm \
             --tty \
             --volume "${BASE_LOCATION}":/data \
             --workdir /data \
             --env REQUIREMENTS_FILE="requirements-tests.txt" \
             --env VENV_NAME="venv" \
             python:$(cat "${BASE_LOCATION}/.python-version")-slim-buster /data/bin/entrypoint.sh /data/bin/run-tests.sh

  print_completed
}

# Prepare dependencies and build the Lambda function code using Docker
package() {
  print_begins

  poetry export --without-hashes --format requirements.txt --output "requirements.txt"
  docker run --rm \
             --tty \
             --volume "${BASE_LOCATION}":/data \
             --workdir /data \
             --env LAMBDA_ZIP_NAME="${LAMBDA_ZIP_NAME}" \
             --env LAMBDA_HASH_NAME="${LAMBDA_HASH_NAME}" \
             --env REQUIREMENTS_FILE="requirements.txt" \
             --env VENV_NAME="venv_package" \
             python:$(cat "${BASE_LOCATION}/.python-version")-slim-buster /data/bin/entrypoint.sh /data/bin/package-lambda.sh

  print_completed
}

# Creates a release tag in the repository
cut_release() {
  print_begins

  poetry run cut-release

  print_completed
}

# Bump the function's version when appropriate
prepare_release() {
  print_begins

  poetry run prepare-release
  export_version

  print_completed
}

# Upload artifacts to S3 - default behaviour, Lambda should always deploy to S3
publish_to_s3() {
  print_begins

  export_version
  export S3_OBJECT_KEY="${PROJECT_FULL_NAME}.${VERSION}.zip"
  export S3_OBJECT_HASH_KEY="${S3_OBJECT_KEY}.base64sha256"

  aws s3 cp "${PATH_BUILD}/${LAMBDA_ZIP_NAME}" "${S3_ADDRESS}/${S3_OBJECT_KEY}" \
    --acl=bucket-owner-full-control
  aws s3 cp "${PATH_BUILD}/${LAMBDA_HASH_NAME}" "${S3_ADDRESS}/${S3_OBJECT_HASH_KEY}" \
    --acl=bucket-owner-full-control \
    --content-type text/plain

  print_completed
}

# Upload artifacts to Artifactory - optional behaviour for any Lambdas that are shared outside of Telemetry
publish_to_artifactory() {
  print_begins

  export_version
  export PACKAGE_NAME="${PROJECT_FULL_NAME}.${VERSION}.zip"

  PACKAGE_MD5=$(md5sum "${PATH_BUILD}/${LAMBDA_ZIP_NAME}" | awk '{print $1}')
  PACKAGE_SHA1=$(sha1sum "${PATH_BUILD}/${LAMBDA_ZIP_NAME}" | awk '{print $1}')
  PACKAGE_SHA256=$(sha256sum "${PATH_BUILD}/${LAMBDA_ZIP_NAME}" | awk '{print $1}')

  export PACKAGE_MD5=${PACKAGE_MD5}
  export PACKAGE_SHA1=${PACKAGE_SHA1}
  export PACKAGE_SHA256=${PACKAGE_SHA256}

  curl --request PUT \
       --fail \
       --silent \
       --header "Authorization: Bearer ${ARTIFACTORY_TOKEN}" \
       --header "X-Checksum: ${PACKAGE_MD5}" \
       --header "X-Checksum-Sha1: ${PACKAGE_SHA1}" \
       --header "X-Checksum-Sha256: ${PACKAGE_SHA256}" \
       --upload-file "${PATH_BUILD}/${LAMBDA_ZIP_NAME}" \
       "https://artefacts.tax.service.gov.uk/artifactory/telemetry-lambda-packages/${PROJECT_FULL_NAME}/${PACKAGE_NAME}"

  print_completed
}

#####################################################################
## Beginning of the helper methods ##################################

export_version() {

  if [ ! -f ".version" ]; then
    echo ".version file not found! Have you run prepare_release command?"
    exit 1
  fi

  VERSION=$(cat .version)
  export VERSION=${VERSION}
}

help() {
  echo "$0 Provides set of commands to assist you with day-to-day tasks when working in this project"
  echo
  echo "Available commands:"
  echo -e " - package\t\t\t Prepare dependencies and build the Lambda function code using Docker"
  echo -e " - prepare_release\t\t Bump the function's version when appropriate"
  echo -e " - publish_to_s3\t Upload artifacts to ${S3_ADDRESS}"
  echo -e " - publish_to_artifactory\t Upload artifacts to B&D's artifactory repository"
  echo -e " - cut_release\t\t Creates a release tag in the repository"
  echo
}

print_begins() {
  echo -e "\n-------------------------------------------------"
  echo -e ">>> ${FUNCNAME[1]} Begins\n"
}

print_completed() {
  echo -e "\n### ${FUNCNAME[1]} Completed!"
  echo -e "-------------------------------------------------"
}

print_configs() {
  echo -e "BASE_LOCATION:\t\t\t${BASE_LOCATION}"
  echo -e "PATH_BUILD:\t\t\t${PATH_BUILD}"
  echo -e "PROJECT_FULL_NAME:\t\t${PROJECT_FULL_NAME}"
  echo
  echo -e "S3_TELEMETRY_LAMBDA_ROOT:\t${S3_TELEMETRY_LAMBDA_ROOT}"
  echo -e "S3_LAMBDA_SUB_FOLDER:\t\t${S3_LAMBDA_SUB_FOLDER}"
  echo -e "S3_ADDRESS:\t\t\t${S3_ADDRESS}"
}

## End of the helper methods ########################################
#####################################################################

#####################################################################
## Beginning of the Entry point #####################################
main() {
  # Validate command arguments
  [ "$#" -ne 1 ] && help && exit 1
  function="$1"
  functions="help debug_env open_shell unittest package publish_to_s3 publish_to_artifactory prepare_release print_configs cut_release"
  [[ $functions =~ (^|[[:space:]])"$function"($|[[:space:]]) ]] || (echo -e "\n\"$function\" is not a valid command. Try \"$0 help\" for more details" && exit 2)

  # Ensure build folder is available
  mkdir -p "${PATH_BUILD}"

  $function
}

main "$@"
## End of the Entry point ###########################################
#####################################################################

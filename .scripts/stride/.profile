#!/bin/bash

STRIDE_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

alias bashstride="vim ${STRIDE_SCRIPT_DIR}/.profile"

venv-create() {
  if [[ "${1}" == "" ]]; then
    # Must specify a name for the new venv
    echo "Name unspecified. First argument to this command must be a name for the venv we are creating"
  else
	source ~/venvs/python38/bin/activate
	python3 -m venv ~/venvs/${1}
	deactivate
  fi
}

onboard-bastion() {
  if [[ "${1}" == "" ]]; then
    echo "Unknown Username. First argument to this command must be a username of the form '{first_initial}{lastname}'. EX: bsandoval"
  elif [[ "${2}" == "" ]]; then
    echo "Unknown SSH Key. Second argument to this command must be an ssh public key in string form"
  elif [[ 0 != `aws sts get-caller-identity >/dev/null; echo $?` ]]; then
    echo "error occured, you are probably not logged in. try 'aws sso login'"
  else

    if [[ `aws s3api list-objects --bucket stride-prod-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${1}.pub"` != "" ]]; then
      echo "pub key ${1}.pub already exists in prod"
    elif [[ `aws s3api list-objects --bucket stride-dev-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${1}.pub"` != "" ]]; then
      echo "pub key ${1}.pub already exists in dev"
    else
      echo "${2}" > "${1}.pub"
      aws s3api put-object --bucket stride-prod-bastion --key "public-keys/${1}.pub" --body "${1}.pub"
      aws s3api put-object --bucket stride-dev-bastion --key "public-keys/${1}.pub" --body "${1}.pub"
      rm "${1}.pub"
      echo "validating prod"
      aws s3api list-objects --bucket stride-prod-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${1}.pub"
      echo "validating dev"
      aws s3api list-objects --bucket stride-dev-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${1}.pub"
    fi
  fi
}

# DEPENDS ON: STRIDE_VPN_USERNAME, STRIDE_BASTION_USERNAME
ssh-bastion() {
  _environment="${1}"
  if [[ "${1}" != "dev" ]] && [[ "${1}" != "prod" ]]; then
    # Must specify a environment to connect to
    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
  else
    _key=${2}
    _keys=`ls -1 ~/.ssh | perl -ne 'print "$1\n" if /'${_environment}'-stride-(.+)-[0-9]+.pem/'`
    if [[ ! " ${_keys} " =~ " ${2} " ]]; then
      printf "${_environment} ${_key} ssh key not found. \n\nFound the following: \n${_keys[*]}\n"
    else
      # enable the proper vpn
      if [[ $(_vpn_required "${_environment}") == "connecting" ]]; then
        echo "complete VPN login and try again"
      else
        # delete all keys from your ssh keychain (ssh agent only cares about your first 5 keys)
        ssh-add -D
        # add the correct key to your keychain
        ssh-add -K ~/.ssh/${_environment}-stride-python-*.pem
        # ssh to env-based bastion
        if [[ "${_environment}" == "prod" ]]; then
          ssh -A  "${STRIDE_BASTION_USERNAME}@bastion.prod.stridehealth.com"
        elif [[ "${_environment}" == "dev" ]]; then
          ssh -A  "${STRIDE_BASTION_USERNAME}@bastion.stridehealth.io"
        fi
      fi
    fi
  fi
  # unset all variables
  unset _environment
}

# DEPENDS ON: STRIDE_VPN_USERNAME, STRIDE_DEV_REDIS_HOST, and STRIDE_PROD_REDIS_HOST
bust-health-cache() {
  # Verify input parameters
  _planYear="${1}"
  _environment="${2}"
  shift && shift
  if [[ ! "${_planYear}" =~ [0-9]{4} ]]; then
    echo "Unknown Year. First argument to this command must be the plan year in YYYY format"
    echo "Ex: ${FUNCNAME[0]} 2021 prod AL"
  elif [[ "${_environment}" != "dev" ]] && [[ "${_environment}" != "prod" ]]; then
    echo "Unknown Environment. Second argument to this command must be 'dev' or 'prod'"
    echo "Ex: ${FUNCNAME[0]} 2021 prod AL"
  else
    _allStateCodes=('AL' 'AK' 'AZ' 'AR' 'CA' 'CO' 'CT' 'DE' 'FL' 'GA' 'HI' 'ID' 'IL' 'IN' 'IA' 'KS' 'KY' 'LA' 'ME' 'MD' 'MA' 'MI' 'MN' 'MS' 'MO' 'MT' 'NE' 'NV' 'NH' 'NJ' 'NM' 'NY' 'NC' 'ND' 'OH' 'OK' 'OR' 'PA' 'RI' 'SC' 'SD' 'TN' 'TX' 'UT' 'VT' 'VA' 'WA' 'WV' 'WI' 'WY')
    # enable the proper vpn
    if [[ $(_vpn_required "${_environment}") == "connecting" ]]; then
      echo "complete VPN login and try again"
    else
      echo "running in ${_environment} environment"
      if [[ "${_environment}" == "dev" ]]; then
        _strideRedisHost=${STRIDE_DEV_REDIS_HOST}
      elif [[ "${_environment}" == "prod" ]]; then
        _strideRedisHost=${STRIDE_PROD_REDIS_HOST}
      fi
      if [[ "${_strideRedisHost}" != "" ]]; then
        if [[ "${1}" != "all_locations" ]]; then # we can do a list of specific states
          for _postalCode in "$@"; do
            if [[ " ${_allStateCodes[@]} " =~ " ${_postalCode} " ]]; then # make sure it's a real postal code
              echo "busting ${_postalCode}"
              # a note on time: pipes are handled concurrently, so time is timing the entire pipe. Time stops and prints after the pipe completes but before followup commands are run
              redis-cli -h ${_strideRedisHost} --scan --pattern "healthPlanEligible:planYear=${_planYear}:state=${_postalCode}*" | xargs redis-cli -h ${_strideRedisHost} unlink && echo "${_postalCode} complete" &
            fi
          done
        else # or we can just do all the states
          for _postalCode in "${_allStateCodes[@]}"; do # go through every US postal code
            echo "busting ${_postalCode}"
            redis-cli -h ${_strideRedisHost} --scan --pattern "healthPlanEligible:planYear=${_planYear}:state=${_postalCode}*" | xargs redis-cli -h ${_strideRedisHost} unlink && echo "${_postalCode} complete" &
          done
        fi
        wait
        echo "all caches completed"
      fi
    fi
  fi
  # unset all variables
  unset _planYear _postalCode _environment _strideRedisHost _fileName
}

_vpn_required() {
  if [[ "${1}" != "dev" ]] && [[ "${1}" != "prod" ]]; then
    # Must specify a environment to connect to
    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
  else
    _conn="${STRIDE_VPN_USERNAME}@${1}-vpn.stridehealth.io"
    _active_connections=$(${STRIDE_SCRIPT_DIR}/scripts/_connected_vpns.sh)
    # If required vpn not active, close all active vpns and connect the one we need
    if [[ ! " ${_active_connections[@]} " =~ " ${_conn} " ]]; then
      if [[ "${#_active_connections[@]}" != "0" ]] && [[ "${_active_connections[0]}" != "" ]]; then
        # Seems like you can only have one active connection at a time
        ${STRIDE_SCRIPT_DIR}/scripts/_vpn_disconnect_all.sh
      fi
      echo "connecting"
      ${STRIDE_SCRIPT_DIR}/scripts/_vpn_connect.sh "${_conn}"
    fi
    # unset all variables
    unset _conn _active_connections
  fi
}

#!/bin/bash

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
  local _username="${1}"
  local _sshkey="${2}"
  if [[ "${_username}" == "" ]]; then
    echo "Unknown Username. First argument to this command must be a username of the form '{first_initial}{lastname}'. EX: bsandoval"
  elif [[ "${_sshkey}" == "" ]]; then
    echo "Unknown SSH Key. Second argument to this command must be an ssh public key in string form"
  elif [[ 0 != `aws sts get-caller-identity >/dev/null; echo $?` ]]; then
    echo "error occured, you are probably not logged in. try 'aws sso login'"
  else

    if [[ `aws s3api list-objects --bucket stride-prod-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"` != "" ]]; then
      echo "pub key ${_username}.pub already exists in prod"
    elif [[ `aws s3api list-objects --bucket stride-dev-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"` != "" ]]; then
      echo "pub key ${_username}.pub already exists in dev"
    else
      echo "${_sshkey}" > "${_username}.pub"
      aws s3api put-object --bucket stride-prod-bastion --key "public-keys/${_username}.pub" --body "${_username}.pub"
      aws s3api put-object --bucket stride-dev-bastion --key "public-keys/${_username}.pub" --body "${_username}.pub"
      rm "${_username}.pub"
      echo "validating prod"
      aws s3api list-objects --bucket stride-prod-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"
      echo "validating dev"
      aws s3api list-objects --bucket stride-dev-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"
    fi
  fi
}

ssh-bastion() {
  local _funcs_req=( "vpn_required" )
  local _funcs_miss=()
  for _func in "${_funcs_req[@]}"; do
    declare -F "${_func}" > /dev/null || _funcs_miss+=("${_func}")
  done; unset _func
  local _vars_req=( "STRIDE_BASTION_USERNAME" )
  local _vars_miss=()
  for _var in "${_vars_req[@]}"; do
    [[ ! -z ${!_var+x} ]] || _vars_miss+=("${_var}")
  done; unset _var
  if [[ "${#_funcs_miss[@]}" != "0" ]] || [[ "${#_vars_miss[@]}" != "0" ]]; then
    echo "missing ${#_funcs_miss[@]} external function(s): ${_funcs_miss[@]}"
    echo "missing ${#_vars_miss[@]} external variables(s): ${_vars_miss[@]}"
  else
    local _environment="${1}"
    local _key=${2}
    local _keys=( `ls -1 ~/.ssh | perl -ne 'print "$1\n" if /'${_environment}'-stride-(.+)-[0-9]+.pem/'` )
    if [[ "${_environment}" != "dev" ]] && [[ "${_environment}" != "prod" ]]; then
      # Must specify a environment to connect to
      echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
    elif [[ ! " ${_keys[*]} " =~ " ${_key} " ]]; then
      printf "${_environment} ${_key} ssh key not found. \n\nFound the following: \n${_keys[*]}\n"
    elif [[ $(vpn_required "${_environment}") == "connecting" ]]; then
      echo "complete VPN login and try again"
    else
      # delete all keys from your ssh keychain (ssh agent only cares about your first 5 keys)
      ssh-add -D
      # add the correct key to your keychain
      ssh-add -K ~/.ssh/${_environment}-stride-${_key}-*.pem
      # ssh to env-based bastion
      if [[ "${_environment}" == "prod" ]]; then
        ssh -A  "${STRIDE_BASTION_USERNAME}@bastion.prod.stridehealth.com"
      elif [[ "${_environment}" == "dev" ]]; then
        ssh -A  "${STRIDE_BASTION_USERNAME}@bastion.stridehealth.io"
      fi
    fi
  fi
}

bust-health-cache() {
  # Verify input parameters
  local _environment="${1}"
  local _planYear="${2}"
  local _redisHostVar=$(echo "STRIDE_${_environment}_REDIS_HOST" | tr '[a-z]' '[A-Z]')
  shift && shift
  if [[ "${_environment}" != "dev" ]] && [[ "${_environment}" != "prod" ]]; then
    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
    echo "Ex: ${FUNCNAME[0]} prod 2021 AL"
  elif [[ -z ${!_redisHostVar+x} ]]; then
    echo "Missing external variable ${_redisHostVar}"
  elif [[ ! "${_planYear}" =~ [0-9]{4} ]]; then
    echo "Unknown Year. Second argument to this command must be the plan year in YYYY format"
    echo "Ex: ${FUNCNAME[0]} prod 2021 AL"
  else
    # enable the proper vpn
    if [[ $(vpn_required "${_environment}") == "connecting" ]]; then
      echo "complete VPN login and try again"
    else
      echo "running in ${_environment} environment"
      local _strideRedisHost="${!_redisHostVar}"
      if [[ "${_strideRedisHost}" != "" ]]; then
        local _stateCodes=()
        if [[ "${1}" != "all_locations" ]]; then # we can do a list of specific states
          _stateCodes=( $@ )
        else
          _stateCodes=$ALL_STATE_CODES
        fi
        for _postalCode in "${_stateCodes[@]}"; do # go through every US postal code
          echo "busting ${_postalCode}"
          redis-cli -h ${_strideRedisHost} --scan --pattern "healthPlanEligible:planYear=${_planYear}:state=${_postalCode}*" | xargs redis-cli -h ${_strideRedisHost} unlink && echo "${_postalCode} complete" &
        done; unset _postalCode
      fi
      wait
      echo "all caches completed"
    fi
  fi
}

#!/bin/bash

# Purpose: Add new user's ssh public key to the bastion server's s3 bucket
#   This command requires you be logged into AWS SSO. Elegant error handling if not logged in
#   Discreetly requests ssh pub key so key is only in memory and purged once out of context of this function
#   Uses regex to validate that we've received a valid ssh public key. If invalid, shows beginning and end of key
#   Validates provided username doesn't already exist on the box. Prevents deletion of similarly named employee's keys
onboard-bastion() {
  # Ensure functional dependencies exist
  local _funcs_req=( "_get_user_input_discreet" ); local _funcs_miss=()
  for _func in "${_funcs_req[@]}"; do declare -F "${_func}" > /dev/null || _funcs_miss+=("${_func}"); done; unset _func
  [ "${#_funcs_miss[@]}" != "0" ] && echo "missing ${#_funcs_miss[@]} external function(s): ${_funcs_miss[@]}" && return 1

  local _username="${1}"
  # Verify logged in. Already gives a readable error if logged out so don't need a warning
  if [[ 0 == `aws sts get-caller-identity >/dev/null; echo $?` ]]; then
    if [[ "${_username}" == "" ]]; then
      echo "Unknown Username. First argument to this command must be a username of the form '{first_initial}{lastname}'. EX: bsandoval"
    else
      # putting stuff in the conditional of while to make it a do-while
      while
        # discreetly get the ssh public key. Feels unnecessary, but means that the key is gone for good when this command ends
        _get_user_input_discreet "SSH Public Key" && _capturedSshKey=${_user_input} || return 1
        local _sshPubKey=$(echo $_capturedSshKey | perl -ne 'print "$1$2" if /^(ssh-rsa AAAAB3NzaC1yc2|ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNT|ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzOD|ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1Mj|ssh-ed25519 AAAAC3NzaC1lZDI1NTE5|ssh-dss AAAAB3NzaC1kc3)([0-9A-Za-z+\/]+[=]{0,3})(?: .*)?$/')
        if [[ "${_sshPubKey}" == "" ]]; then
          (( ${#_capturedSshKey} > 15 )) && _capturedSshKey="${_capturedSshKey:0:8}...${_capturedSshKey:$(( ${#_capturedSshKey} - 8 ))}"
          echo "Invalid SSH Pub Key. Recieved: ${_capturedSshKey}"; unset _capturedSshKey
          true # Continue while loop
        else
          false # Break out of while loop
        fi
      do
        :
      done
      if [[ `aws s3api list-objects --bucket stride-prod-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"` != "" ]]; then
        # don't overwrite existing ssh keys
        echo "pub key ${_username}.pub already exists in prod"
      elif [[ `aws s3api list-objects --bucket stride-dev-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"` != "" ]]; then
        # don't overwrite existing ssh keys
        echo "pub key ${_username}.pub already exists in dev"
      else
        local _tmpFile="$(date +%s).tmp"
        echo "${_sshPubKey}" > "${_tmpFile}"
        aws s3api put-object --bucket stride-prod-bastion --key "public-keys/${_username}.pub" --body "${_tmpFile}"
        aws s3api put-object --bucket stride-dev-bastion --key "public-keys/${_username}.pub" --body "${_tmpFile}"
        echo "validating prod"
        aws s3api list-objects --bucket stride-prod-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"
        echo "validating dev"
        aws s3api list-objects --bucket stride-dev-bastion --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub"
        # remove the public key from local machine
        rm "${_tmpFile}"
      fi
    fi
  fi
}


# Purpose: Helper function for sshing into proper bastion with requested ssh keys
#   Ensures you are on the right vpn for the bastion that's been requested
#   If requested key not found locally, lists available keys for environment
ssh-bastion() {
  local _funcs_req=( "vpn_required" )
  local _funcs_miss=()
  local _vars_req=( "STRIDE_BASTION_USERNAME" )
  local _vars_miss=()
  for _func in "${_funcs_req[@]}"; do
    declare -F "${_func}" > /dev/null || _funcs_miss+=("${_func}")
  done; unset _func
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
      # add user's personal ssh key
      ssh-add -K ~/.ssh/id_rsa
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


# Purpose: Bust health cache in a given environment
#   Can specify one or more states in which to bust
#   Can optionally specify 'all_states' to bust all caches
#   If busting more than one state, runs them in parallel
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
} 2>/dev/null


# Purpose: Pull down the most recent Vericred plan data
#   Vericred sometimes uploads previous year's data late into next year so we can't make assumptions on the year.
#   Runs all states in parallel
vericred-pull-plan-data() {
  local _planYear=${1}
  if [[ "" == "$(echo ${_planYear} | perl -ne 'print if /^[0-9]{4}$/')" ]]; then
    echo "Unknown or invalid year. First argument to this command must be the plan year to fetch, in YYYY format. Recieved: '${_planYear}'"
  else
    local _path=`eval "~/vericred/plans"`
    mkdir -p _path
    echo "pulling ${_planYear} plans for all states"
    for _stateCode in "${ALL_STATE_CODES[@]}"; do # go through every US state code
      local _fileKey="production/plans/stride_health/csv/individual/${_stateCode}/${_planYear}/plans.csv"
      local _outFile="${_path}/`echo ${_stateCode} | tr '[A-Z]' '[a-z]'`_plans.csv"
      aws s3api get-object --profile vericred --bucket vericred-emr-workers --key ${_fileKey} ${_outFile} &
    done; unset _stateCode
    wait
  fi
} 2>/dev/null


# Purpose: Pull down the most recent Vericred provider data
#   Avoid downloading it if we already have most recent zip
#   Avoid unzipping it if most recent data already unzipped
vericred-pull-provider-data() {
  # Find upload date of most recent data uploaded
  local _vericredFileKey=$(aws s3api list-objects-v2 --profile vericred --bucket vericred-emr-workers --prefix 'production/plans/stride_health/network/' --query 'sort_by(Contents, &LastModified)[-1].Key' --no-paginate --output text)
  local _vericredFileDate=$(echo "${_vericredFileKey}" | perl -pe 's|.*(\d{4}-\d{2}-\d{2}).zip|$1|g')
  echo "Latest file uploaded on ${_vericredFileDate}"
  local _path=`eval _homedir="~" && echo "${_homedir}/vericred"` && unset _homedir
  mkdir -p "${_path}"
  # Uses dated lock file to avoid reunzipping same data
  if [[ ! -f "${_path}/tmp/${_vericredFileDate}.lock" ]]; then
    # Checks local zip to avoid redownloading same data
    if [[ ! -f "${_path}/network_data_${_vericredFileDate}.zip" ]]; then
      echo "Current Vericred zip doesn't exist locally, pulling down from source."
      rm -f "${_path}/network_data_*.zip"
      aws s3api get-object --profile vericred --bucket vericred-emr-workers --key $_vericredFileKey ${_path}/network_data_${_vericredFileDate}.zip
    fi
    echo "Unzipping local Vericred data"
    rm -rf "${_path}/tmp"
    unzip "${_path}/network_data_${_vericredFileDate}.zip" -d "${_path}"
    touch "${_path}/tmp/${_vericredFileDate}.lock"
  else
    echo "Already have most up-to-date Vericred data"
  fi
}

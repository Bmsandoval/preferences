#!/bin/bash


STRIDE_ENVIRONMENTS=('prod' 'dev')
ALL_STATE_CODES=('AL' 'AK' 'AZ' 'AR' 'CA' 'CO' 'CT' 'DE' 'FL' 'GA' 'HI' 'ID' 'IL' 'IN' 'IA' 'KS' 'KY' 'LA' 'ME' 'MD' 'MA' 'MI' 'MN' 'MS' 'MO' 'MT' 'NE' 'NV' 'NH' 'NJ' 'NM' 'NY' 'NC' 'ND' 'OH' 'OK' 'OR' 'PA' 'RI' 'SC' 'SD' 'TN' 'TX' 'UT' 'VT' 'VA' 'WA' 'WV' 'WI' 'WY')


alias st="stride"
stride () {
# Purpose: Package a number of scripts that I've used
# Options:
#   help - Displays this menu
#   bastion - Encompasses onboarding, offboarding, & ssh helpers
#   vericred-pull - Pull recent plans | providers
#   health-cache-bust - Bust one or more states in parallel. Try 'all_locations'
#   inspector-validate - Validate patch manager is patching as expected

  local baseOp="${1}"; shift
  case "${baseOp}" in
  'help'|'') cat <<EOF
    Usage: $ ${FUNCNAME[0]} [option]
    Options:
      help - Displays this menu
      bastion - [Tab] Encompasses onboarding, offboarding, & ssh helpers
      vericred-pull - Pull recent plans | providers
      health-cache-bust - [Tab] Bust one or more states in parallel. Try 'all_locations'
      inspector-validate - Validate patch manager is patching as expected
EOF
  ;;
  'bastion')
    local secondaryOp="${1}"; shift
    case "${secondaryOp}" in
    'onboard') stride-bastion-onboard $@ ;;
    'offboard') stride-bastion-offboard $@ ;;
    'ssh') stride-bastion-ssh $@ ;;
    'help'|'') cat <<EOF
      Options:
        help - Displays this menu
        onboard - Accepts username as parameter, prompts for ssh key. Elegantly fails on duplicate username
        offboard - Accepts username as parameter
        ssh - [Tab] Accepts an environment (dev|prod) and a key type (eg node) as parameters
EOF
    esac
  ;;
  'vericred-pull')
    local secondaryOp="${1}"; shift
    case "${secondaryOp}" in
    'plans') stride-vericred-pull-plans $@ ;;
    'providers') stride-vericred-pull-providers $@ ;;
    'help'|'') cat <<EOF
      Options:
        help - Displays this menu
        onboard - Accepts username as parameter, prompts for ssh key. Elegantly fails on duplicate username
        offboard - Accepts username as parameter
        ssh - [Tab] Accepts an environment (dev|prod) and a key type (eg node) as parameters
EOF
    esac
  ;;
  'health-cache-bust') stride-health-cache-bust $@ ;;
  'inspector-validate') stride-inspector-check-patch $@ ;;
  esac
}


#     ___ ___  __  __ ___ _    ___ _____ ___ ___  _  _ ___
#    / __/ _ \|  \/  | _ \ |  | __|_   _|_ _/ _ \| \| / __|
#   | (_| (_) | |\/| |  _/ |__| _|  | |  | | (_) | .` \__ \
#    \___\___/|_|  |_|_| |____|___| |_| |___\___/|_|\_|___/
#############################################################

__complete_stride () {
  case "${COMP_CWORD}" in
  "1") COMPREPLY=($(compgen -W "help bastion vericred-pull health-cache-bust inspector-validate" "${COMP_WORDS[COMP_CWORD]}")) ;;
  "2")
    case "${COMP_WORDS[COMP_CWORD-1]}" in
    "bastion") COMPREPLY=($(compgen -W "onboard offboard ssh" "${COMP_WORDS[COMP_CWORD]}")) ;;
    "vericred-pull") COMPREPLY=($(compgen -W "plans providers" "${COMP_WORDS[COMP_CWORD]}")) ;;
    "health-cache-bust") COMPREPLY=($(compgen -W "dev prod" "${COMP_WORDS[COMP_CWORD]}")) ;;
    "inspector-validate") COMPREPLY=($(compgen -W "us-west-1 us-west-2" "${COMP_WORDS[COMP_CWORD]}")) ;;
    esac
  ;;
  "3")
    if [[ "bastion" == "${COMP_WORDS[COMP_CWORD-2]}" ]] \
    && [[ "ssh" == "${COMP_WORDS[COMP_CWORD-1]}" ]]; then
      COMPREPLY=($(compgen -W "dev prod" "${COMP_WORDS[COMP_CWORD]}"))
    elif [[ "health-cache-bust" == "${COMP_WORDS[COMP_CWORD-2]}" ]]; then
      COMPREPLY=($(compgen -W "$(date -v -1y +%Y) $(date +%Y) $(date -v +1y +%Y)" "${COMP_WORDS[COMP_CWORD]}"))
    elif [[ "vericred-pull" == "${COMP_WORDS[COMP_CWORD-2]}" ]]; then
      COMPREPLY=($(compgen -W "$(date -v -1y +%Y) $(date +%Y) $(date -v +1y +%Y)" "${COMP_WORDS[COMP_CWORD]}"))
    fi
  ;;
  "4")
    if [[ "bastion" == "${COMP_WORDS[COMP_CWORD-3]}" ]] \
    && [[ "ssh" == "${COMP_WORDS[COMP_CWORD-2]}" ]]; then
      local _env="${COMP_WORDS[COMP_CWORD-1]}"
      read -ra _keys <<< "$(find ~/.ssh -type f \
      | perl -ne 'print "$1 " if /'"${_env}"'-stride-(.+)-[0-9]+.pem/')"
      COMPREPLY=($(compgen -W "${_keys[*]}" "${COMP_WORDS[COMP_CWORD]}"))
    elif [[ "health-cache-bust" == "${COMP_WORDS[COMP_CWORD-3]}" ]]; then
      COMPREPLY=($(compgen -W "${ALL_STATE_CODES[*]} all_locations" "${COMP_WORDS[COMP_CWORD]}"))
    fi
  ;;
  esac
}
complete -F __complete_stride -o default -o bashdefault stride
complete -F __complete_stride -o default -o bashdefault st


#    ___ _  _ ___ ___ ___ ___ _____ ___  ___
#   |_ _| \| / __| _ \ __/ __|_   _/ _ \| _ \
#    | || .` \__ \  _/ _| (__  | || (_) |   /
#   |___|_|\_|___/_| |___\___| |_| \___/|_|_\
#############################################################

stride-inspector-check-patch() {
# Purpose: List high-severity instances from inspector
# Returns: AMI and hostname
#
# Calls `aws inspector list-assessment-runs` and filters for most recent runs
# Gets findings for each run using `aws inspector describe-assessment-runs`
# Gets the CVE for each finding using `aws inspector describe-findings`
# Queries RedHat api with each UNIQUE CVE to get current details

  local _redhat_product="Red Hat Enterprise Linux 6"
  local _severities=('Critical' 'Important')
  local _severity_filter
  _severity_filter="$( printf " or .threat_severity == '%s'" "${_severities[@]}" | sed 's/^ or //')"

  local _region _backing_file
  local _allowed_regions="us-west-1 us-west-2"
  _region="${1}"
  if [[ 0 != $(aws sts get-caller-identity >/dev/null; echo $?) ]]; then
    echo "Not logged in. Try 'aws sts get-caller-identity' to see if logged in, log in with 'aws sso login'"
  elif [[ ! "${_allowed_regions}" =~ ${_region} ]]; then
    echo "Unknown Region. First argument to this command must be a region: 'us-west-2' for prod, or 'us-west-1' for dev"
  else
    read -ra _assessments <<< "$(aws inspector list-assessment-runs \
      --region "${_region}" \
      --filter "completionTimeRange={beginDate=$(date -v -7d +%Y-%m-%d),endDate=$(date -v +1d +%Y-%m-%d)}" \
    | perl -ne 'print "$1 " if /^\s+"(arn:aws:inspector:[^:]+:[^:]+:target.+)"/')"

    read -ra _list_findings <<< "$(aws inspector list-findings \
      --region "${_region}" \
      --assessment-run-arns ${_assessments[*]} \
    | perl -ne 'print "$1 " if /^\s+"(arn:aws:inspector:[^:]+:[^:]+:target.+)"/')"

    read -ra _finding_cves <<< "$(aws inspector describe-findings \
      --region "${_region}" \
      --output text \
      --query 'findings[*].id' \
      --finding-arns ${_list_findings[*]} \
    | perl -e '
      foreach $items (<>) {
        foreach $item (split(/\s+/, $items)) {
          unless ($seen{$item}) {
              # if we get here, we have not seen it before
              $seen{$item} = 1;
              print "$item " if $item =~ /[A-Z]+-[0-9]{4}-[0-9]+/;}}}')"
    _backing_file=$(mktemp -u)
    for _cve in "${_finding_cves[@]}"; do
      curl --location --request GET "https://access.redhat.com/hydra/rest/securitydata/cve/${_cve}.json" \
      | perl -pnle '/./' \
      | while read -r _input; do
          local _output
          if [[ "${_input}" =~ '{"message":"Not Found"}' ]]; then
            _output="Red Hat has no data for CVE: ${_cve}"
          else
            local _severity _fix_state
            _severity="$(echo "${_input}" | jq -r '.threat_severity')"
            if [[ ! "${_severities[*]}" =~ ${_severity} ]]; then
              continue
            fi
            _fix_state="$(echo "${_input}"\
              | jq -r '.
              | .package_state[]
              | select(.product_name | startswith("Red Hat Enterprise Linux 6"))
              | .fix_state?')"
            if [[ "${_fix_state}" == "" ]]; then
              _fix_state="released - $(echo "${_input}"\
              | jq -r '.
              | .affected_release[]
              | select(.product_name | startswith("Red Hat Enterprise Linux 6"))
              | .release_date')"
            fi
            _output="CVE: ${_cve}\nOS: ${_redhat_product}\nSeverity: ${_severity}\nFix State: ${_fix_state}"
          fi
          while ! touch "${_backing_file}"; do
            sleep .2
          done
          echo -e "${_output}\n"
          sleep .2
          rm -rf "${_backing_file}"
        done \
        &
    done
    wait
  fi; unset _assessments
} 2>/dev/null


#    _  _ ___   _   _  _____ _  _    ___   _   ___ _  _ ___
#   | || | __| /_\ | ||_   _| || |  / __| /_\ / __| || | __|
#   | __ | _| / _ \| |__| | | __ | | (__ / _ \ (__| __ | _|
#   |_||_|___/_/ \_\____|_| |_||_|  \___/_/ \_\___|_||_|___|
#############################################################

stride-health-cache-bust() {
# Purpose: Bust health cache in a given environment
#   Can specify one or more states in which to bust
#   Can optionally specify 'all_states' to bust all caches
#   If busting more than one state, runs them in parallel

  # Verify input parameters
  local _environment _planYear _redisHostVar _statusPid _pids _strideRedisHost _stateCodes
  _environment="${1}"
  _planYear="${2}"
  _redisHostVar=$(echo "STRIDE_${_environment}_REDIS_HOST" | tr '[:lower:]' '[:upper:]')
  shift && shift
  if [[ "${_environment}" != "dev" ]] && [[ "${_environment}" != "prod" ]]; then
    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
    echo "Ex: ${FUNCNAME[0]} prod 2021 AL"
  elif [[ -z ${!_redisHostVar+x} ]]; then
    echo "Missing environment variable ${_redisHostVar}"
  elif [[ ! "${_planYear}" =~ [0-9]{4} ]]; then
    echo "Unknown Year. Second argument to this command must be the plan year in YYYY format"
    echo "Ex: ${FUNCNAME[0]} prod 2021 AL"
  else
    # enable the proper vpn
    if [[ $(vpn_required "${_environment}") == "connecting" ]]; then
      echo "complete VPN login and try again"
    else
      echo "running in ${_environment} environment"
      _strideRedisHost="${!_redisHostVar}"
      _pids=()
      if [[ "${_strideRedisHost}" != "" ]]; then
        _stateCodes=()
        if [[ "${1}" != "all_locations" ]]; then # we can do a list of specific states
          read -ra _stateCodes <<<"${@}"
        else
          read -ra _stateCodes <<<"${ALL_STATE_CODES}"
        fi
        for _postalCode in "${_stateCodes[@]}"; do # go through every US postal code
          echo "busting ${_postalCode}"
          redis-cli -h "${_strideRedisHost}" --scan --pattern "healthPlanEligible:planYear=${_planYear}:state=${_postalCode}*" \
          | xargs redis-cli -h "${_strideRedisHost}" unlink && echo "${_postalCode} complete" &
          _pids+=($!)
        done; unset _postalCode
      fi
      while true; do echo '.' && sleep 1; done &
      _statusPid=$!
      trap "kill ${_statusPid}" SIGINT;
      wait "${_pids[@]}"
      kill $_statusPid
      trap - SIGINT;
    fi
  fi
} 2>/dev/null


#    ___   _   ___ _____ ___ ___  _  _
#   | _ ) /_\ / __|_   _|_ _/ _ \| \| |
#   | _ \/ _ \\__ \ | |  | | (_) | .` |
#   |___/_/ \_\___/ |_| |___\___/|_|\_|
########################################

function stride-bastion-offboard {
# Purpose: Remove old user's ssh public key from the bastion server's s3 bucket
#   This command requires you be logged into AWS SSO. Elegant error handling if not logged in
#   Validates provided username exists on the box before attempting removal

  local _username _tempFile
  _username="${1}"
  # Verify logged in. Already gives a readable error if logged out so don't need a warning
  if [[ 0 == $(aws sts get-caller-identity >/dev/null; echo $?) ]]; then
    if [[ "${_username}" == "" ]]; then
      echo "Unknown Username. First argument to this command must be a username of the form '{first_initial}{lastname}'. EX: bsandoval"
      aws s3api list-objects --bucket "stride-prod-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}'
    else
      _tempFile=$(mktemp)
      for env in "${STRIDE_ENVIRONMENTS[@]}"; do
        aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' \
        | grep "/${_username}.pub" >> "${_tempFile}" &
      done; wait
      if [[ "$(cat "${_tempFile}" wc -l | tr -d '[:space:]')" != "${#STRIDE_ENVIRONMENTS[@]}" ]]; then
        echo "user does not exist in bastion"
      else
        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
          aws s3api delete-object --bucket "stride-${env}-bastion" --key "public-keys/${_username}.pub" &
        done; wait
        echo "validating keys removed"
        _tempFile=$(mktemp)
        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
          aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' \
          | grep "/${_username}.pub" >> "${_tempFile}" &
        done; wait
        if [[ "$( < "${_tempFile}" wc -l | tr -d '[:space:]')" != "0" ]]; then
          echo "something went wrong, user keys not found"
        fi
      fi
    fi
  fi
} 2> /dev/null


stride-bastion-onboard() {
# Purpose: Add new user's ssh public key to the bastion server's s3 bucket
#   This command requires you be logged into AWS SSO. Elegant error handling if not logged in
#   Discreetly requests ssh pub key so key is only in memory and purged once out of context of this function
#   Uses regex to validate that we've received a valid ssh public key. If invalid, shows beginning and end of key
#   Validates provided username doesn't already exist on the box. Prevents deletion of similarly named employee's keys

  # Ensure functional dependencies exist
  local _funcsReq _funcsMiss _username _sshPubKey _capturedSshKey
  _funcsReq=( "__get_user_input_discreet" ); _funcsMiss=()
  for _func in "${_funcsReq[@]}"; do declare -F "${_func}" > /dev/null || _funcsMiss+=("${_func}"); done; unset _func
  [ "${#_funcsMiss[@]}" != "0" ] && echo "missing ${#_funcsMiss[@]} external function(s): ${_funcsMiss[*]}" && return 1

  _username="${1}"
  # Verify logged in. Already gives a readable error if logged out so don't need a warning
  if [[ 0 == $(aws sts get-caller-identity >/dev/null; echo $?) ]]; then
    if [[ "${_username}" == "" ]]; then
      echo "Unknown Username. First argument to this command must be a username of the form '{first_initial}{lastname}'. EX: bsandoval"
    else
      # putting stuff in the conditional of while to make it a do-while
      while
        # discreetly get the ssh public key. Feels unnecessary, but means that the key is gone for good when this command ends

        _capturedSshKey=$(_get_user_input_discreet "SSH Public Key: ")
        _sshPubKey=$(echo "${_capturedSshKey}" \
        | perl -ne \
            'print "$1$2" if /^('\
              'ssh-rsa AAAAB3NzaC1yc2'\
              '|ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNT'\
              '|ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzOD'\
              '|ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1Mj'\
              '|ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'\
              '|ssh-dss AAAAB3NzaC1kc3'\
            ')([0-9A-Za-z+\/]+[=]{0,3})(?: .*)?$/')
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
      _tempFile=$(mktemp)
      echo "validating keys don't already exist"
      for env in "${STRIDE_ENVIRONMENTS[@]}"; do
        aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub" >> "${_tempFile}" &
      done; wait
      if [[ "$(< "${_tempFile}" wc -l)" != "0" ]]; then
        echo "pub key ${_username}.pub already exists"
      else
        local _tempFile
        _tempFile=$(mktemp | tee >(read -r _n; echo "${_sshPubKey}" > "${_n}"))
        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
          aws s3api put-object --bucket "stride-${env}-bastion" --key "public-keys/${_username}.pub" --body "${_tempFile}" &
        done; wait
        echo "validating keys added"
        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
          aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub" >> "${_tempFile}" &
        done; wait
        _tempFile=$(mktemp)
        if [[ "$( < "${_tempFile}" wc -l \
        | tr -d '[:space:]')" != "${#STRIDE_ENVIRONMENTS[@]}" ]]
        then
          echo "something went wrong, user keys not found"
        fi
        # remove the public key from local machine
      fi
    fi
  fi
} 2> /dev/null


__get_user_input_discreet() {
# Purpose: Used to get user input while hiding the input from both scroll history and shell history
#   Will loop until a non-empty input is received, or until an interrupt is sent
# Returns: User's input, echoed from function. positive exit code if received SIGINT
# Warning: Discreet output is indiscreetly echoed from this function. Capture it or it will be in scroll history
  local _user_input
  trap "stty echo && echo '' && echo 'received interrupt' && (exit 1); return" SIGINT;
  stty -echo
  while [ -z "${_user_input}" ]; do
    # Send to /dev/tty to force output to user allowing this commands output to be captured
    printf '%s' "${1}" > /dev/tty; read -r _user_input; printf '\n' > /dev/tty;
  done
  stty echo
  trap - SIGINT;
  echo "${_user_input}"
}


stride-bastion-ssh() {
# Purpose: Helper function for sshing into proper bastion with requested ssh keys
#   Ensures you are on the right vpn for the bastion that's been requested
#   If requested key not found locally, lists available keys for environment

  local _funcs_req _func _vars_req _var _env _keys _key _tempFile
  _funcs_req=( "vpn_required" ) _vars_req=( "STRIDE_BASTION_USERNAME" ) _tempFile=$(mktemp)
  for _func in "${_funcs_req[@]}"; do declare -F "${_func}" > /dev/null || echo "${_func}" >> "${_tempFile}" & done;
  for _var in "${_vars_req[@]}"; do [[ -n ${!_var+x} ]] || echo "${_var}" >> "${_tempFile}" & done;
  wait
  if [[ "$( < "${_tempFile}" wc -l | tr -d '[:space:]')" != "0" ]]; then
    echo -e "Missing dependencies: " && perl -ne 'print "$1 " if /^([^\n]+)/' "${_tempFile}"
  else
    _env="${1}"
    _key=${2}
    read -ra _keys <<< "$(find ~/.ssh -type f \
    | perl -ne 'print "$1 " if /'"${_env}"'-stride-(.+)-[0-9]+.pem/')"
    if [[ "${_env}" != "dev" ]] && [[ "${_env}" != "prod" ]]; then
      echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
    elif [[ ! "${_keys[*]}" =~ (^|[[:space:]])"${_key}"($|[[:space:]]) ]]; then
      echo -e "${_env} ${_key} ssh key not found. \n\nFound the following: \n${_keys[*]}\n"
    elif [[ $(vpn_required "${_env}") == "connecting" ]]; then
      echo "Complete VPN login and try again"
    else
      # delete all keys from your ssh keychain (ssh agent only cares about your first 5 keys)
      ssh-add -D
      # add user's personal ssh key
      ssh-add -K "$HOME/.ssh/id_rsa"
      # add the correct key to your keychain
      ssh-add -K "$HOME/.ssh/${_env}-stride-${_key}-*.pem"
      # ssh to env-based bastion
      local _envFlag
      [[ "${_env}" == "prod" ]] && _envFlag=".prod"
      ssh -A "${STRIDE_BASTION_USERNAME}@bastion${_envFlag}.stridehealth.io"
    fi
  fi
} 2>/dev/null


#   __   _____ ___ ___ ___ ___ ___ ___
#   \ \ / / __| _ \_ _/ __| _ \ __|   \
#    \ V /| _||   /| | (__|   / _|| |) |
#     \_/ |___|_|_\___\___|_|_\___|___/
##########################################

stride-vericred-pull-plans() {
# Purpose: Pull down the most recent Vericred plan data
#   Vericred sometimes uploads previous year's data late into next year so we can't make assumptions on the year.
#   Runs all states in parallel

  local _planYear _path
  _planYear=${1}
  if [[ "" == "$(echo "${_planYear}" | perl -ne 'print if /^[0-9]{4}$/')" ]]; then
    echo "Unknown or invalid year. First argument to this command must be the plan year to fetch, in YYYY format. Recieved: '${_planYear}'"
  else
    _path="${HOME}/vericred/plans"
    mkdir -p _path
    echo "pulling ${_planYear} plans for all states"
    for _stateCode in "${ALL_STATE_CODES[@]}"; do # go through every US state code
      aws s3api get-object --profile vericred --bucket vericred-emr-workers \
        --key "production/plans/stride_health/csv/individual/${_stateCode}/${_planYear}/plans.csv" \
        "${_path}/$(echo "${_stateCode}" | tr '[:upper:]' '[:lower:]')_plans.csv" \
        &
    done; unset _stateCode
    wait
  fi
} 2>/dev/null


stride-vericred-pull-providers() {
# Purpose: Pull down the most recent Vericred provider data
#   Avoid downloading it if we already have most recent zip
#   Avoid unzipping it if most recent data already unzipped

  # Find upload date of most recent data uploaded
  local _vericredFileKey _vericredFileDate _path _homedir
  _vericredFileKey=$(aws s3api list-objects-v2 --profile vericred --bucket vericred-emr-workers --prefix 'production/plans/stride_health/network/' --query 'sort_by(Contents, &LastModified)[-1].Key' --no-paginate --output text)
  _vericredFileDate=$(echo "${_vericredFileKey}" \
  | perl -pe 's|.*(\d{4}-\d{2}-\d{2}).zip|$1|g')
  echo "Latest file uploaded on ${_vericredFileDate}"
  _path="${HOME}/vericred"
  mkdir -p "${_path}"
  # Uses dated lock file to avoid re-unzipping same data
  if [[ ! -f "${_path}/tmp/${_vericredFileDate}.lock" ]]; then
    # Checks local zip to avoid re-downloading same data
    if [[ ! -f "${_path}/network_data_${_vericredFileDate}.zip" ]]; then
      echo "Current Vericred zip doesn't exist locally, pulling down from source."
      rm -f "${_path}/network_data_*.zip"
      aws s3api get-object --profile vericred --bucket vericred-emr-workers --key "${_vericredFileKey}" "${_path}/network_data_${_vericredFileDate}.zip"
    fi
    echo "Unzipping local Vericred data"
    rm -rf "${_path}/tmp"
    unzip "${_path}/network_data_${_vericredFileDate}.zip" -d "${_path}"
    touch "${_path}/tmp/${_vericredFileDate}.lock"
  else
    echo "Already have most up-to-date Vericred data"
  fi
}


#   __   _____ _  _
#   \ \ / / _ \ \| |
#    \ V /|  _/ .` |
#     \_/ |_| |_|\_|
##########################################

function vpn_required {
# Purpose: Add new user's ssh public key to the bastion server's s3 bucket
#   This command requires you be logged into AWS SSO. Elegant error handling if not logged in
#   Discreetly requests ssh pub key so key is only in memory and purged once out of context of this function
#   Uses regex to validate that we've received a valid ssh public key. If invalid, shows beginning and end of key
#   Validates provided username doesn't already exist on the box. Prevents deletion of similarly named employee's keys
  local _environment="${1}"
  if [[ "${1}" != "dev" ]] && [[ "${1}" != "prod" ]]; then
    # Must specify a environment to connect to
    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
  else
    local _conn="${STRIDE_VPN_USERNAME}@${_environment}-vpn.stridehealth.io"
    local _active_connections=$(_connected_vpns)
    # If required vpn not active, close all active vpns and connect the one we need
    if [[ ! " ${_active_connections[@]} " =~ " ${_conn} " ]]; then
      if [[ "${#_active_connections[@]}" != "0" ]] && [[ "${_active_connections[0]}" != "" ]]; then
        # Seems like you can only have one active connection at a time
        _vpn_disconnect_all
      fi
      echo "connecting"
      _vpn_connect "${_conn}"
    fi
  fi
}


function _vpn_connect {
# Purpose: Attempt to connect to a Viscosity-maintained VPN
  osascript <<EOF
tell application "Viscosity" to connect "${1}"
EOF
}


function _connected_vpns {
# Purpose: View all currently connected VPNs as maintained by Viscosity
  osascript <<EOF
tell application "Viscosity"
  set output to ""
  set i to 0
  repeat with _conn in connections
    set i to i + 1
    set _vpn to name of _conn
    set _state to state of _conn
    if _state = "Connected" then
      set output to output & _vpn
      if i < count of connections
        set output to output & "\n"
      end if
    end if
  end repeat
  output
end tell
EOF
}


function _vpn_disconnect_all {
# Purpose: Disconnect from all VPNs maintained by Viscosity
  osascript <<EOF
tell application "Viscosity" to disconnectall
EOF
}
##!/bin/bash
#
#
## Get directory of this file for relative file access
#__STRIDE_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
#
#
## Source the env for this script. Mitigating issues by ensuring an env file exists
#if [ ! -f "$__STRIDE_SCRIPT_DIR/.env" ]; then
#  [ -f "$__STRIDE_SCRIPT_DIR/.env.ex" ] && cp "$__STRIDE_SCRIPT_DIR/.env.ex" "$__STRIDE_SCRIPT_DIR/.env" || touch "$__STRIDE_SCRIPT_DIR/.env"
#fi
#set -a; source "${__STRIDE_SCRIPT_DIR}/.env"; set +a
#
#
### Load the VISCOSITY profile
#source "$__STRIDE_SCRIPT_DIR/viscosity.profile"
#
#
#testy () {
#  cat <<'EOF'
#    sample
#      tabbed boi
#    a third
#EOF
#}
#
#
##    ___   _   ___ _____ ___ ___  _  _
##   | _ ) /_\ / __|_   _|_ _/ _ \| \| |
##   | _ \/ _ \\__ \ | |  | | (_) | .` |
##   |___/_/ \_\___/ |_| |___\___/|_|\_|
#########################################
#
#stride-bastion-onboard() {
## Purpose: Add new user's ssh public key to the bastion server's s3 bucket
##   This command requires you be logged into AWS SSO. Elegant error handling if not logged in
##   Discreetly requests ssh pub key so key is only in memory and purged once out of context of this function
##   Uses regex to validate that we've received a valid ssh public key. If invalid, shows beginning and end of key
##   Validates provided username doesn't already exist on the box. Prevents deletion of similarly named employee's keys
#
#  # Ensure functional dependencies exist
#  local _funcsReq _funcsMiss _username _sshPubKey _capturedSshKey
#  _funcsReq=( "__get_user_input_discreet" ); _funcsMiss=()
#  for _func in "${_funcsReq[@]}"; do declare -F "${_func}" > /dev/null || _funcsMiss+=("${_func}"); done; unset _func
#  [ "${#_funcsMiss[@]}" != "0" ] && echo "missing ${#_funcsMiss[@]} external function(s): ${_funcsMiss[*]}" && return 1
#
#  _username="${1}"
#  # Verify logged in. Already gives a readable error if logged out so don't need a warning
#  if [[ 0 == $(aws sts get-caller-identity >/dev/null; echo $?) ]]; then
#    if [[ "${_username}" == "" ]]; then
#      echo "Unknown Username. First argument to this command must be a username of the form '{first_initial}{lastname}'. EX: bsandoval"
#    else
#      # putting stuff in the conditional of while to make it a do-while
#      while
#        # discreetly get the ssh public key. Feels unnecessary, but means that the key is gone for good when this command ends
#
#        _capturedSshKey=$(_get_user_input_discreet "SSH Public Key: ")
#        _sshPubKey=$(echo "${_capturedSshKey}" \
#        | perl -ne \
#            'print "$1$2" if /^('\
#              'ssh-rsa AAAAB3NzaC1yc2'\
#              '|ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNT'\
#              '|ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzOD'\
#              '|ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1Mj'\
#              '|ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'\
#              '|ssh-dss AAAAB3NzaC1kc3'\
#            ')([0-9A-Za-z+\/]+[=]{0,3})(?: .*)?$/')
#        if [[ "${_sshPubKey}" == "" ]]; then
#          (( ${#_capturedSshKey} > 15 )) && _capturedSshKey="${_capturedSshKey:0:8}...${_capturedSshKey:$(( ${#_capturedSshKey} - 8 ))}"
#          echo "Invalid SSH Pub Key. Recieved: ${_capturedSshKey}"; unset _capturedSshKey
#          true # Continue while loop
#        else
#          false # Break out of while loop
#        fi
#      do
#        :
#      done
#      _tempFile=$(mktemp)
#      echo "validating keys don't already exist"
#      for env in "${STRIDE_ENVIRONMENTS[@]}"; do
#        aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub" >> "${_tempFile}" &
#      done; wait
#      if [[ "$(< "${_tempFile}" wc -l)" != "0" ]]; then
#        echo "pub key ${_username}.pub already exists"
#      else
#        local _tempFile
#        _tempFile=$(mktemp | tee >(read -r _n; echo "${_sshPubKey}" > "${_n}"))
#        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
#          aws s3api put-object --bucket "stride-${env}-bastion" --key "public-keys/${_username}.pub" --body "${_tempFile}" &
#        done; wait
#        echo "validating keys added"
#        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
#          aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' | grep "/${_username}.pub" >> "${_tempFile}" &
#        done; wait
#        _tempFile=$(mktemp)
#        if [[ "$( < "${_tempFile}" wc -l \
#        | tr -d '[:space:]')" != "${#STRIDE_ENVIRONMENTS[@]}" ]]
#        then
#          echo "something went wrong, user keys not found"
#        fi
#        # remove the public key from local machine
#      fi
#    fi
#  fi
#} 2> /dev/null
#
#
#function stride-bastion-offboard {
## Purpose: Remove old user's ssh public key from the bastion server's s3 bucket
##   This command requires you be logged into AWS SSO. Elegant error handling if not logged in
##   Validates provided username exists on the box before attempting removal
#
#  local _username _tempFile
#  _username="${1}"
#  # Verify logged in. Already gives a readable error if logged out so don't need a warning
#  if [[ 0 == $(aws sts get-caller-identity >/dev/null; echo $?) ]]; then
#    if [[ "${_username}" == "" ]]; then
#      echo "Unknown Username. First argument to this command must be a username of the form '{first_initial}{lastname}'. EX: bsandoval"
#      aws s3api list-objects --bucket "stride-prod-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}'
#    else
#      _tempFile=$(mktemp)
#      for env in "${STRIDE_ENVIRONMENTS[@]}"; do
#        aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' \
#        | grep "/${_username}.pub" >> "${_tempFile}" &
#      done; wait
#      if [[ "$(cat "${_tempFile}" wc -l | tr -d '[:space:]')" != "${#STRIDE_ENVIRONMENTS[@]}" ]]; then
#        echo "user does not exist in bastion"
#      else
#        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
#          aws s3api delete-object --bucket "stride-${env}-bastion" --key "public-keys/${_username}.pub" &
#        done; wait
#        echo "validating keys removed"
#        _tempFile=$(mktemp)
#        for env in "${STRIDE_ENVIRONMENTS[@]}"; do
#          aws s3api list-objects --bucket "stride-${env}-bastion" --prefix public-keys/ --output text --query 'Contents[*].{key:Key}' \
#          | grep "/${_username}.pub" >> "${_tempFile}" &
#        done; wait
#        if [[ "$( < "${_tempFile}" wc -l | tr -d '[:space:]')" != "0" ]]; then
#          echo "something went wrong, user keys not found"
#        fi
#      fi
#    fi
#  fi
#} 2> /dev/null
#
#
#stride-inspector-check-patch() { # region, severity, product
## Purpose: List high-severity instances from inspector
## Returns: AMI and hostname
##
## Calls `aws inspector list-assessment-runs` and filters for most recent runs
## Gets findings for each run using `aws inspector describe-assessment-runs`
## Gets the CVE for each finding using `aws inspector describe-findings`
## Queries RedHat api with each UNIQUE CVE to get current details
#
#  local _redhat_product="Red Hat Enterprise Linux 6"
#  local _severities=('Critical' 'Important')
#  local _severity_filter
#  _severity_filter="$( printf " or .threat_severity == '%s'" "${_severities[@]}" | sed 's/^ or //')"
#
#  local _region _backing_file
#  local _allowed_regions="us-west-1 us-west-2"
#  _region="${1}"
#  if [[ 0 != $(aws sts get-caller-identity >/dev/null; echo $?) ]]; then
#    echo "Not logged in. Try 'aws sts get-caller-identity' to see if logged in, log in with 'aws sso login'"
#  elif [[ ! "${_allowed_regions}" =~ ${_region} ]]; then
#    echo "Unknown Region. First argument to this command must be a region: 'us-west-2' for prod, or 'us-west-1' for dev"
#  else
#    read -ra _assessments <<< "$(aws inspector list-assessment-runs \
#      --region "${_region}" \
#      --filter "completionTimeRange={beginDate=$(date -v -7d),endDate=$(date +%Y-%m-%d)}" \
#    | perl -ne 'print "$1 " if /^\s+"(arn:aws:inspector:[^:]+:[^:]+:target.+)"/')"
#
#    read -ra _list_findings <<< "$(aws inspector list-findings \
#      --region "${_region}" \
#      --assessment-run-arns ${_assessments[*]} \
#    | perl -ne 'print "$1 " if /^\s+"(arn:aws:inspector:[^:]+:[^:]+:target.+)"/')"
#
#    read -ra _finding_cves <<< "$(aws inspector describe-findings \
#      --region "${_region}" \
#      --output text \
#      --query 'findings[*].id' \
#      --finding-arns ${_list_findings[*]} \
#    | perl -e '
#      foreach $items (<>) {
#        foreach $item (split(/\s+/, $items)) {
#          unless ($seen{$item}) {
#              # if we get here, we have not seen it before
#              $seen{$item} = 1;
#              print "$item " if $item =~ /[A-Z]+-[0-9]{4}-[0-9]+/;}}}')"
#    _backing_file=$(mktemp -u)
#    for _cve in "${_finding_cves[@]}"; do
#      curl --location --request GET "https://access.redhat.com/hydra/rest/securitydata/cve/${_cve}.json" \
#      | perl -pnle '/./' \
#      | while read -r _input; do
#          local _output
#          if [[ "${_input}" =~ '{"message":"Not Found"}' ]]; then
#            _output="Red Hat has no data for CVE: ${_cve}"
#          else
#            local _severity _fix_state
#            _severity="$(echo "${_input}" | jq -r '.threat_severity')"
#            if [[ ! "${_severities[*]}" =~ ${_severity} ]]; then
#              continue
#            fi
#            _fix_state="$(echo "${_input}"\
#              | jq -r '.
#              | .package_state[]
#              | select(.product_name | startswith("Red Hat Enterprise Linux 6"))
#              | .fix_state?')"
#            if [[ "${_fix_state}" == "" ]]; then
#              _fix_state="released - $(echo "${_input}"\
#              | jq -r '.
#              | .affected_release[]
#              | select(.product_name | startswith("Red Hat Enterprise Linux 6"))
#              | .release_date')"
#            fi
#            _output="CVE: ${_cve}\nOS: ${_redhat_product}\nSeverity: ${_severity}\nFix State: ${_fix_state}"
#          fi
#          while ! touch "${_backing_file}"; do
#            sleep .2
#          done
#          echo -e "${_output}\n"
#          sleep .2
#          rm -rf "${_backing_file}"
#        done \
#        &
#    done
#    wait
#  fi; unset _assessments
#} 2>/dev/null
#
#stride-bastion-ssh() {
## Purpose: Helper function for sshing into proper bastion with requested ssh keys
##   Ensures you are on the right vpn for the bastion that's been requested
##   If requested key not found locally, lists available keys for environment
#
#  local _funcs_req _func _vars_req _var _env _keys _key _tempFile
#  _funcs_req=( "vpn_required" ) _vars_req=( "STRIDE_BASTION_USERNAME" ) _tempFile=$(mktemp)
#  for _func in "${_funcs_req[@]}"; do declare -F "${_func}" > /dev/null || echo "${_func}" >> "${_tempFile}" & done;
#  for _var in "${_vars_req[@]}"; do [[ -n ${!_var+x} ]] || echo "${_var}" >> "${_tempFile}" & done;
#  wait
#  if [[ "$( < "${_tempFile}" wc -l | tr -d '[:space:]')" != "0" ]]; then
#    echo -e "Missing dependencies: " && perl -ne 'print "$1 " if /^([^\n]+)/' "${_tempFile}"
#  else
#    _env="${1}"
#    _key=${2}
#    read -ra _keys <<< "$(find ~/.ssh -type f \
#    | perl -ne 'print "$1 " if /'"${_env}"'-stride-(.+)-[0-9]+.pem/')"
#    if [[ "${_env}" != "dev" ]] && [[ "${_env}" != "prod" ]]; then
#      echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
#    elif [[ ! "${_keys[*]}" =~ (^|[[:space:]])"${_key}"($|[[:space:]]) ]]; then
#      echo -e "${_env} ${_key} ssh key not found. \n\nFound the following: \n${_keys[*]}\n"
#    elif [[ $(vpn_required "${_env}") == "connecting" ]]; then
#      echo "Complete VPN login and try again"
#    else
#      # delete all keys from your ssh keychain (ssh agent only cares about your first 5 keys)
#      ssh-add -D
#      # add user's personal ssh key
#      ssh-add -K "$HOME/.ssh/id_rsa"
#      # add the correct key to your keychain
#      ssh-add -K "$HOME/.ssh/${_env}-stride-${_key}-*.pem"
#      # ssh to env-based bastion
#      local _envFlag
#      [[ "${_env}" == "prod" ]] && _envFlag=".prod"
#      ssh -A "${STRIDE_BASTION_USERNAME}@bastion${_envFlag}.stridehealth.io"
#    fi
#  fi
#} 2>/dev/null
#
#
##    _  _ ___   _   _  _____ _  _    ___   _   ___ _  _ ___
##   | || | __| /_\ | ||_   _| || |  / __| /_\ / __| || | __|
##   | __ | _| / _ \| |__| | | __ | | (__ / _ \ (__| __ | _|
##   |_||_|___/_/ \_\____|_| |_||_|  \___/_/ \_\___|_||_|___|
##############################################################
#
#stride-health-cache-bust() {
## Purpose: Bust health cache in a given environment
##   Can specify one or more states in which to bust
##   Can optionally specify 'all_states' to bust all caches
##   If busting more than one state, runs them in parallel
#
#  # Verify input parameters
#  local _environment _planYear _redisHostVar _statusPid _pids _strideRedisHost _stateCodes
#  _environment="${1}"
#  _planYear="${2}"
#  _redisHostVar=$(echo "STRIDE_${_environment}_REDIS_HOST" | tr '[:lower:]' '[:upper:]')
#  shift && shift
#  if [[ "${_environment}" != "dev" ]] && [[ "${_environment}" != "prod" ]]; then
#    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
#    echo "Ex: ${FUNCNAME[0]} prod 2021 AL"
#  elif [[ -z ${!_redisHostVar+x} ]]; then
#    echo "Missing external variable ${_redisHostVar}"
#  elif [[ ! "${_planYear}" =~ [0-9]{4} ]]; then
#    echo "Unknown Year. Second argument to this command must be the plan year in YYYY format"
#    echo "Ex: ${FUNCNAME[0]} prod 2021 AL"
#  else
#    # enable the proper vpn
#    if [[ $(vpn_required "${_environment}") == "connecting" ]]; then
#      echo "complete VPN login and try again"
#    else
#      echo "running in ${_environment} environment"
#      _strideRedisHost="${!_redisHostVar}"
#      _pids=()
#      if [[ "${_strideRedisHost}" != "" ]]; then
#        _stateCodes=()
#        if [[ "${1}" != "all_locations" ]]; then # we can do a list of specific states
#          read -ra _stateCodes <<<"${@}"
#        else
#          read -ra _stateCodes <<<"${ALL_STATE_CODES}"
#        fi
#        for _postalCode in "${_stateCodes[@]}"; do # go through every US postal code
#          echo "busting ${_postalCode}"
#          redis-cli -h "${_strideRedisHost}" --scan --pattern "healthPlanEligible:planYear=${_planYear}:state=${_postalCode}*" \
#          | xargs redis-cli -h "${_strideRedisHost}" unlink && echo "${_postalCode} complete" &
#          _pids+=($!)
#        done; unset _postalCode
#      fi
#      while true; do echo '.' && sleep 1; done &
#      _statusPid=$!
#      trap "kill ${_statusPid}" SIGINT;
#      wait "${_pids[@]}"
#      kill $_statusPid
#      trap - SIGINT;
#    fi
#  fi
#} 2>/dev/null
#
#
##   __   _____ ___ ___ ___ ___ ___ ___
##   \ \ / / __| _ \_ _/ __| _ \ __|   \
##    \ V /| _||   /| | (__|   / _|| |) |
##     \_/ |___|_|_\___\___|_|_\___|___/
###########################################
#
#stride-vericred-pull-plans() {
## Purpose: Pull down the most recent Vericred plan data
##   Vericred sometimes uploads previous year's data late into next year so we can't make assumptions on the year.
##   Runs all states in parallel
#
#  local _planYear _path
#  _planYear=${1}
#  if [[ "" == "$(echo "${_planYear}" | perl -ne 'print if /^[0-9]{4}$/')" ]]; then
#    echo "Unknown or invalid year. First argument to this command must be the plan year to fetch, in YYYY format. Recieved: '${_planYear}'"
#  else
#    _path="${HOME}/vericred/plans"
#    mkdir -p _path
#    echo "pulling ${_planYear} plans for all states"
#    for _stateCode in "${ALL_STATE_CODES[@]}"; do # go through every US state code
#      aws s3api get-object --profile vericred --bucket vericred-emr-workers \
#        --key "production/plans/stride_health/csv/individual/${_stateCode}/${_planYear}/plans.csv" \
#        "${_path}/$(echo "${_stateCode}" | tr '[:upper:]' '[:lower:]')_plans.csv" \
#        &
#    done; unset _stateCode
#    wait
#  fi
#} 2>/dev/null
#
#
#stride-vericred-pull-providers() {
## Purpose: Pull down the most recent Vericred provider data
##   Avoid downloading it if we already have most recent zip
##   Avoid unzipping it if most recent data already unzipped
#
#  # Find upload date of most recent data uploaded
#  local _vericredFileKey _vericredFileDate _path _homedir
#  _vericredFileKey=$(aws s3api list-objects-v2 --profile vericred --bucket vericred-emr-workers --prefix 'production/plans/stride_health/network/' --query 'sort_by(Contents, &LastModified)[-1].Key' --no-paginate --output text)
#  _vericredFileDate=$(echo "${_vericredFileKey}" \
#  | perl -pe 's|.*(\d{4}-\d{2}-\d{2}).zip|$1|g')
#  echo "Latest file uploaded on ${_vericredFileDate}"
#  _path="${HOME}/vericred"
#  mkdir -p "${_path}"
#  # Uses dated lock file to avoid re-unzipping same data
#  if [[ ! -f "${_path}/tmp/${_vericredFileDate}.lock" ]]; then
#    # Checks local zip to avoid re-downloading same data
#    if [[ ! -f "${_path}/network_data_${_vericredFileDate}.zip" ]]; then
#      echo "Current Vericred zip doesn't exist locally, pulling down from source."
#      rm -f "${_path}/network_data_*.zip"
#      aws s3api get-object --profile vericred --bucket vericred-emr-workers --key "${_vericredFileKey}" "${_path}/network_data_${_vericredFileDate}.zip"
#    fi
#    echo "Unzipping local Vericred data"
#    rm -rf "${_path}/tmp"
#    unzip "${_path}/network_data_${_vericredFileDate}.zip" -d "${_path}"
#    touch "${_path}/tmp/${_vericredFileDate}.lock"
#  else
#    echo "Already have most up-to-date Vericred data"
#  fi
#}

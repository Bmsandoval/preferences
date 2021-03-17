alias pa="paws"
paws () {
    # if no command given force help page
    local OPTION
    if [[ "$1" != "" ]]; then
        OPTION=$1
    else
        OPTION="help"
    fi
    # handle input options
    case "${OPTION}" in
        'help')
echo "Usage: $ ${FUNCNAME} [option]

Options:
- help: show this menu
- find-ec2: 'search for ec2 within region by Name tag'
"
        ;;
        "find-ec2")
            if [[ "$2" != "dev" ]] && [[ "$2" != "prod" ]]; then
                echo "Unknown Workspace. First argument to this command must be either 'dev' or 'prod'"
            else
                _lower=$(echo $3 | tr '[A-Z]' '[a-z]')
                _upper=$(echo $3 | tr '[a-z]' '[A-Z]')
                if [[ "$2" == "dev" ]]; then
                    _region="us-west-1"
                else
                    _region="us-west-2"
                fi
                aws ec2 describe-instances --region="${_region}" --filters "Name=tag:Name, Values=[${_lower},${_upper}]" --query "Reservations[*].Instances[*].[InstanceId,Tags[? Key == 'Name'].Value[] | [0]]" --output text
                unset _lower _upper _region
            fi
        ;;
        *)
            echo -e "ERROR: invalid option. Try..\n$ ${FUNCNAME} help"
        ;;
    esac
}

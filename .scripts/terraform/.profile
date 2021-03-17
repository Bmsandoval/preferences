alias tf="terrafly"
terrafly () {
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
- plan: 'terraform plan {env}.varfile'
    * optional '-c' parameter for concise output
- apply: 'terraform apply {env}.varfile'
"
        ;;
        "init")
            terraform init
        ;;
        "plan")
            if [[ "$2" == "" ]]; then
                echo "Unknown Workspace. Second argument to this command must be something like 'dev' or 'prod'"
            else
                terraform workspace select "${2}"
                #result=terraform workspace select "${2}" | grep "doesn't exist."
                if [[ "$3" == "-c" ]]; then
                    terraform plan -var-file="${2}.tfvars" -no-color | grep -E "(^.*[#~+-] .*|^[[:punct:]]|Plan)"
                else
                    terraform plan -var-file="${2}.tfvars"
                fi
            fi
        ;;
        "apply")
            if [[ "$2" == "" ]]; then
                echo "Unknown Workspace. Second argument to this command must be something like 'dev' or 'prod'"
            else
                terraform workspace select "${2}"
                if [[ "$3" == "-y" ]]; then
                    terraform apply -var-file="${2}.tfvars" -assume-yes
                else
                    terraform apply -var-file="${2}.tfvars"
                fi
            fi
        ;;
        *)
            echo -e "ERROR: invalid option. Try..\n$ ${FUNCNAME} help"
        ;;
    esac
}

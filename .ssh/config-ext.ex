#!/bin/bash
# quickly ssh into servers. Depends on called hosts existing in ssh config
alias ssh-log1="ssh -t qa-log 'sudo lxc exec team-dev-logistics-1 -- bash; exec $SHELL'"
alias ssh-log2="ssh -t qa-log 'sudo lxc exec team-dev-logistics-2 -- bash; exec $SHELL'"
alias ssh-cron7="ssh -t log-cron-7 'echo \"Logged into logistics php7 cron server. Access cron with.. (sudo crontab -u logistics -e)\"; exec $SHELL'"

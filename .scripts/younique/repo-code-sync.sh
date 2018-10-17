#!/bin/bash

### Variable Declarations ###
local_dir=/home/sandman/projects/work/code
remote_dir=/var/www/code
remote_ssh=dev
# List of directories to exclude
exclusions=(CodeDeploy CodeBuild .idea .github .gitignore .git */node_modules *.env cake/app/tmp api/tmp */Vendor)
### END Declarations ###

# Compile exclusions
excludes=()
for excl in "${exclusions[@]}"; do
	excludes+=(--exclude=\'$excl\')
done

# Deploy to remote dev
#echo "rsync -a ${excludes[@]} $local_dir/ $remote_ssh:$remote_dir/"
#rsync -a ${excludes[@]} $local_dir/ $remote_ssh:$remote_dir/
rsync -r --exclude='CodeDeploy' --exclude='CodeBuild' --exclude='.idea' --exclude='.github' --exclude='.gitignore' --exclude='.git' --exclude '*/node_modules' --exclude='*.env' --exclude='cake/app/tmp' --exclude='api/tmp' --exclude='*/Vendor' $local_dir/ $remote_ssh:$remote_dir 
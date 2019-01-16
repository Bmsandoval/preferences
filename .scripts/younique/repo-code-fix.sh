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

# Clean up afterwards
ssh dev <<EOF
cd ${remote_dir}
sudo find ${remote_dir} -type d -exec chmod 0750 {} +
sudo find ${remote_dir} -type f -exec chmod 0640 {} +
sudo chown -R ${whoami}:www-data ${remote_dir} 
sudo npm install
sudo chmod -R 777 api/tmp
sudo npm install -g grunt-cli
if [[ ! -f /usr/bin/node ]]; then ln -s /usr/bin/nodejs /usr/bin/node; fi;
cd admin && sudo npm install && sudo npm run install-dnd && sudo npm run install-jgrowl && sudo composer install && cd ../
cd cake/app && sudo npm install && sudo composer install && cd ../../
cd api && sudo npm install && sudo composer install && cd ../
cd api/aws3 && sudo composer install && cd ../../
chmod +x api/Console/cake
sudo api/Console/cake phinx migrate
EOF

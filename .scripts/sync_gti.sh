#!/bin/bash

### Variable Declarations ###
local_dir=~/projects/work/gti
remote_dir=/var/www/gti
remote_ssh=dev
# List of directories to exclude
exclusions=(CodeDeploy CodeBuild .idea .github .gitignore .git */node_modules *.env cake/app/tmp api/tmp */Vendor */vendor)
# Tack on list I found in GTI
exclusions+=(.svn .DS_Store .pid .svn .cvsignore log tmp tmp/* public/images/items public/core/configuration.php public/wiki/ .zip .idea daemons/pids daemons/pids/** )
### END Declarations ###

# Compile exclusions
excludes=()
for excl in "${exclusions[@]}"; do
	excludes+=(--exclude=\"$excl\")
done

# Deploy GTI to remote dev
rsync -r ${excludes[@]} $local_dir/ $remote_ssh:/var/www/gti/ #--delete

# Clean up afterwards
#ssh dev << EOL
#sudo service php7.0-fpm restart
#chmod +x ${remote_dir}/gtil/artisan
#chmod +x ${remote_dir}/gtil/composer.phar
#cd ${remote_dir}/gtil && ./composer.phar install
#cd ${remote_dir} 
#find . -type d -exec chmod 0755 {} +
#find . -type f -exec chmod 0644 {} +
#sudo chown -R ${whoami}:www-data ${remote_dir} 
#EOL

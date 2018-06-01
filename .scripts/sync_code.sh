#!/bin/bash


dir=/home/sandman/Work/code

#rsync -nvr $dir/* dev:/var/www/code

rsync -a --exclude='CodeDeploy' --exclude='CodeBuild' --exclude='.idea' --exclude='.github' --exclude='.gitignore' --exclude='.git' --exclude '*/node_modules' --exclude='*.env' --exclude='cake/app/tmp' --exclude='api/tmp' --exclude='*/Vendor' $dir/ dev:/var/www/code/ 


ssh dev 'sudo chmod -R 775 /var/www/code; clean-up-my-mess'
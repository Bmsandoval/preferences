apt-install

# required for autojump to work
## but should already be in bashrc
#echo ". /usr/share/autojump/autojump.bash" >> ~/.bashrc

###### https://dmitryfrank.com/articles/shell_shortcuts
## start setting up bookmarks
sudo cat <<EOT >> /usr/bin/cdscuts_list_echo
#!/bin/bash
cat $1 | sed 's/#.*//g' | sed '/^\s*$/d'
EOT
sudo chmod a+x /usr/bin/cdscuts_list_echo
#
sudo cat <<EOT >> /usr/bin/cdscuts_glob_echo
#!/bin/bash
system_wide_filelist=''
user_filelist=''
if [ -r /etc/cdg_paths ]; then
   system_wide_filelist=$(cdscuts_list_echo /etc/cdg_paths)
fi
if [ -r ~/.cdg_paths ]; then
   user_filelist=$(cdscuts_list_echo ~/.cdg_paths)
fi
echo -e "$system_wide_filelist\n$user_filelist" | sed '/^\s*$/d'
EOT
sudo chmod a+x /usr/bin/cdscuts_glob_echo
#
###### SHOULD BE SAVED IN GITHUB PREFS
#sudo cat << EOT >> ~/.bashrc
## Setup cdg function
## ------------------
#unalias cdg 2> /dev/null
#cdg() {
#   local dest_dir=$(cdscuts_glob_echo | fzf )
#   if [[ $dest_dir != '' ]]; then
#      cd "$dest_dir"
#   fi
#}
#export -f cdg > /dev/null
#EOT
## done setting up bookmarks

# install sexy_bash_prompt
git clone --depth 1 --config core.autocrlf=false https://github.com/twolfson/sexy-bash-prompt
cd sexy-bash-prompt
make install
source ~/.bashrc

## install fzf
#cd applications
#git clone git@github.com:junegunn/fzf.git
#cd fzf
#./install
#cd ~


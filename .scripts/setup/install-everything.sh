###### SETUP ######
package-installed () {
	result=$(compgen -A function -abck | grep ^$1$)
	if [ "${result}" == "$1" ]; then
		# package installed
		return 0
	else
		# package not installed
		return 1
	fi
}

###### INSTALL_FROM_SOURCES ######
#apt-install all necessary programs
#apt-install

###### PULL DOWN GIT REPO ######
#sudo apt install git  # Run alone
#
#git init
#git remote add origin git@github.com:Bmsandoval/preferences.git
#ssh-keyscan www.github.com >> ~/.ssh/known_hosts
#
#git fetch  # Run alone
#
#git reset origin/master
#git branch --set-upstream-to=origin/master
#mv .bashrc .bashrc.old
#mv .profile .profile.old
#git pull
#git merge master

###### JUST FOLLOW THEIR GUIDE  ######
# insync (google drive)
# with i3 I found it easier to configure with the headless

###### AUTOJUMP ######
# only need the apt-install, rest should be in git preferences

###### INSTALL APPLICATIONS ######
if [ ! -d ~/applications ]; then
	mkdir -p ~/applications
fi

###### SEXY_BASH_PROMPT ######
#cd applications
#git clone --depth 1 --config core.autocrlf=false https://github.com/twolfson/sexy-bash-prompt
#cd sexy-bash-prompt
#make install
#source ~/.bashrc
#cd ~

###### FZF ######
package-installed fzf
if [ "$?" == "1" ]; then
	cd ~/applications
	git clone git@github.com:junegunn/fzf.git
	cd -
	cd fzf
	./install
	cd -
fi

###### ALBERT ######
#wget -nv -O Release.key  https://build.opensuse.org/projects/home:manuelschneid3r/public_key
#sudo apt-key add - < Release.key
#sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/manuelschneid3r/xUbuntu_16.04/ /' > /etc/apt/sources.list.d/home:manuelschneid3r.list"
#sudo apt-get update
#sudo apt-get install albert


###### KITTY TERMINAL????? ######
# update address via http://www.linuxfromscratch.org/blfs/view/svn/general/harfbuzz.html
package-installed kitty
if [ "$?" == "1" ]; then
	curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
	sudo ln -s ~/.local/kitty.app/bin/kitty /usr/local/bin/
fi

# install Cat substitute, Bat
package-installed bat
if [ "$?" == "1" ]; then
	wget https://github.com/sharkdp/bat/releases/download/v0.9.0/bat-musl_0.9.0_amd64.deb
	sudo dpkg -i bat-musl_0.9.0_amd64.deb
	rm bat-musl_0.9.0_amd64.deb
fi

# set global gitignore
git config --global core.excludesfile '~/.gitignore_global'

# install diodon
echo "checking diodon"
package-installed diodon
if [ "$?" == "1" ]; then
	sudo add-apt-repository ppa:diodon-team/stable
	sudo apt install diodon
fi

package-installed i3blocks
if [ "$?" == "1" ]; then # can't check for gaps, look for blocks instead
	# install i3-gaps
	#https://github.com/Airblader/i3
	#https://github.com/maestrogerardo/i3-gaps-deb
	git clone git@github.com:maestrogerardo/i3-gaps-deb.git ~/applications/i3-gaps-deb
	cd ~/applications/i3-gaps-deb
	# uncomment all deb-src lines from /etc/apt/sources.list
	sudo sed -i '/deb-src/s/^# //g' /etc/apt/sources.list.save
	sudo apt update
	./i3-gaps-deb

	# install i3blocks-gaps
	#https://github.com/Airblader/i3blocks-gaps
	git clone https://github.com/Airblader/i3blocks-gaps ~/applications/i3blocks
	cd ~/applications/i3blocks
	make clean debug
	sudo make install
fi

echo "recommend running 'bash-src-scripts'"

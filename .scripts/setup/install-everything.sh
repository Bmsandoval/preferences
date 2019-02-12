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


###### VIM #########
# install vim
#sudo apt install vim
# install bundler
#git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
# install plugins
#vim +PluginInstall +qall



###### JUST FOLLOW THEIR GUIDE  ######
# insync (google drive)
# with i3 I found it easier to configure with the headless
#sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C
# or sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ACCAF35C

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
	cd fzf
	./install
	cd -
fi

###### ALBERT ######
wget -nv https://download.opensuse.org/repositories/home:manuelschneid3r/xUbuntu_18.04/Release.key -O Release.key
sudo apt-key add - < Release.key
sudo apt-get update


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

# google golang
echo "checking go"
package-installed "go" 
if [ ! -d ~/projects/home/go ]; then
	mkdir -p ~/projects/home/go
fi
if [ "$?" == "1" ]; then
	cd ~/Downloads
	wget -c https://storage.googleapis.com/golang/go1.7.3.linux-amd64.tar.gz
	sudo tar -C /usr/local -xvzf go1.7.3.linux-amd64.tar.gz
fi

# Sublime
#echo "checking sublime"
#package-installed sublime
#if [ "$?" == "1" ]; then
#   curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
#	sudo add-apt-repository "deb https://download.sublimetext.com/ apt/stable/"
#	sudo apt update
#	sudo apt install sublime-text
#fi

# i3blocks
package-installed i3blocks
if [ "$?" == "1" ]; then # can't check for gaps, look for blocks instead
	# install i3-gaps
	#https://github.com/Airblader/i3
	sudo add-apt-repository ppa:aguignard/ppa
	sudo apt-get update
	sudo apt-get install libxcb-xrm-dev libxcb1-dev libxcb-keysyms1-dev libpango1.0-dev \
		libxcb-util0-dev libxcb-icccm4-dev libyajl-dev \
		libstartup-notification0-dev libxcb-randr0-dev \
		libev-dev libxcb-cursor-dev libxcb-xinerama0-dev \
		libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev \
		autoconf libxcb-xrm0 libxcb-xrm-dev automake libxcb-shape0-dev
	git clone https://www.github.com/Airblader/i3 $HOME/applications/i3-gaps
	cd $HOME/applications/i3-gaps
	autoreconf --force --install
	rm -rf build/
	mkdir -p build && cd build/
	../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers
	make
	sudo make install

	# install i3blocks-gaps
	#https://github.com/Airblader/i3blocks-gaps
	git clone https://github.com/Airblader/i3blocks-gaps ~/applications/i3blocks
	cd $HOME/applications/i3blocks
	make clean debug
	sudo make install
fi

echo "recommend running 'bash-src-scripts'"

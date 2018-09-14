###### SETUP ######

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

###### AUTOJUMP ######
# only need the apt-install, rest should be in git preferences

###### INSTALL APPLICATIONS ######
#mkdir applications

###### SEXY_BASH_PROMPT ######
#cd applications
#git clone --depth 1 --config core.autocrlf=false https://github.com/twolfson/sexy-bash-prompt
#cd sexy-bash-prompt
#make install
#source ~/.bashrc
#cd ~

###### FZF ######
#cd applications
#git clone git@github.com:junegunn/fzf.git
#cd fzf
#./install
#cd ~

###### ALBERT ######
#wget -nv -O Release.key  https://build.opensuse.org/projects/home:manuelschneid3r/public_key
#sudo apt-key add - < Release.key
#sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/manuelschneid3r/xUbuntu_16.04/ /' > /etc/apt/sources.list.d/home:manuelschneid3r.list"
#sudo apt-get update
#sudo apt-get install albert


###### KITTY TERMINAL????? ######
# update address via http://www.linuxfromscratch.org/blfs/view/svn/general/harfbuzz.html
wget https://www.freedesktop.org/software/harfbuzz/release/harfbuzz-1.8.8.tar.bz2
./configure --prefix=/usr --with-gobject &&
sudo apt install libgl1-mesa-dev libpng16-dev apt-file
# ? sudo apt-file update ?
apt-file search fontconfig.pc
make
sudo make install

sudo apt install gcc g++ libfreetype6-dev libglib2.0-dev libcairo2-dev libunistring0 libunistring-dev libxkbcommon-x11-0 libxkbcommon-x11-dev wayland-protocols
git clone https://github.com/kovidgoyal/kitty.git
cd kitty
python3 setup.py build

# preferences

## Programs
Chrome
Slack
Postman
Albert (Linux)/Alfred (Mac)
iTerm (Mac)
Jetbrains Suite
Adobe XD
Zepplin?

## MAC SETUP
# generate a new ssh key
$ ssh-keygen -t rsa -b 4096 -C "bmsandoval@gmail.com"
#now add that ssh key to github

# Install gsed
$ brew install gnu-sed

# Setup Home Dir
$ git init
$ git remote add origin git@github.com:bmsandoval/preferences.git
$ git pull origin master

# Setup Vim
$ git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/plugin/Vundle.vim
$ vim +PluginInstall +qall

# Setup Jetbrains
#-For Goland, Pycharm, and possibly Phpstorm
#-install, hit 'File', and import settings from ~/applications

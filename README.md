# preferences

## Recommended Programs
* Chrome
* Slack
* Postman
* iTerm (Mac)
* Jetbrains Toolbox
* Adobe XD
* Zepplin?
* gitkraken

## MAC SETUP
# generate a new ssh key
* $`ssh-keygen -t rsa -b 4096 -C "bmsandoval@gmail.com"`
* now add that ssh key to github

# Install Homebrew
* $`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

# Install gsed
* $`brew install gnu-sed`

# Setup Home Dir
* $`git init`
* $`git remote add origin git@github.com:bmsandoval/preferences.git`
* $`git pull origin master`

# Setup Vim
* $`git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/plugin/Vundle.vim`
* $`vim +PluginInstall +qall`
* If the above fail, sometimes it needs to be in the 'bundle' directory
  * $`mv .vim/plugin/* .vim/bundle/`

# Setup Jetbrains
* For Goland, Pycharm, and possibly Phpstorm - install, hit 'File', and import settings from ~/applications

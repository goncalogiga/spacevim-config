#!/bin/bash

set -e

MIN_NEOVIM_VERSION="0.8.0"
MIN_NODEJS_VERSION="16.19.0"

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

info () {
    printf "${BBlue}[spacevim-setup]${Color_Off} ${Green}$1${Color_Off}\n"
}

warning () {
    printf "${BBlue}[spacevim-setup WARNING]${Color_Off} ${BYellow}$1${Color_Off}\n"
}

error () {
    printf "${BRed}[spacevim-setup ERROR]${Color_Off} $1. Aborting...\n"
    exit 1
}

question () {
    printf "${BBlue}[spacevim-setup]${Color_Off} $1\n"
}

yesno () {
    printf "${BBlue}[spacevim-setup]${Color_Off} $1 [Y/n] ?\n"
    read answer

    if [[ "$answer" != "Y" ]] && [[ "$answer" != "y" ]]
    then
        printf "${BRed}[spacevim-setup]${Color_Off} Aborting...\n"
        exit 0
    fi
}

# === usefull function === #

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

check_neovim_version () {
    local NEOVIM_VERSION=$($1 --version | grep 'NVIM')
    NEOVIM_VERSION=${NEOVIM_VERSION:6}
    echo $NEOVIM_VERSION
}

install_neovim_appimage () {
    info "Fetching latest neovim appimage"
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x nvim.appimage
    info "Moving appimage to /usr/bin (sudo might be required)"
    sudo mv nvim.appimage /usr/bin
    info "Appimage installed. You might consider adding an alias to your .bashrc: alias nvim='nvim.appimage'"
}

install_spacevim () {
    question "Please insert the neovim binary's path (use which nvim or check your bashrc if you use aliases. If you don't have neovim installed press enter."
    read NEOVIM_EXEC_PATH

    if [[ ${NEOVIM_EXEC_PATH} ]]
    then
        if [ ! -f "$NEOVIM_EXEC_PATH" ]
        then
            error "Path not found: '${NEOVIM_EXEC_PATH}'"
        else
            NEOVIM_VERSION=$(check_neovim_version $NEOVIM_EXEC_PATH)
            
            if [ $(version "$MIN_NEOVIM_VERSION") -ge $(version "$NEOVIM_VERSION") ]
            then
                info "Neovim is not up to date ($NEOVIM_VERSION < $MIN_NEOVIM_VERSION)"
                yesno "Install newest neovim appimage"
                install_neovim_appimage
            else
                info "Neovim is up to date !"
            fi
        fi
    else
        yesno "Install newest neovim appimage"
        install_neovim_appimage
    fi

    echo $NEOVIM_EXEC_PATH

    # === SpaceVim set up === #

    info "Fetching spacevim installer"
    curl -sLf https://spacevim.org/install.sh | bash
}

update_config () {
    info "Updating configuration files..."
    mv -f /tmp/spacevim-config/init.toml ~/.SpaceVim.d/
    mkdir -p ~/.SpaceVim.d/autoload
    mv -f /tmp/spacevim-config/myspacevim.vim ~/.SpaceVim.d/autoload/
    info "done."

    info "Please paste your prefered fuzzy searcher (fd, fdfind, ...)"
    read fzfengine

    sed -i s/fdfind/${fzfengine}/g ~/.SpaceVim.d/autoload/myspacevim.vim
    info "Successfully updated the fuzzy searcher."
}

upload_gitrepo () {
    info "Uploading configuration files..."
    git clone https://github.com/goncalogiga/spacevim-config
    mkdir -p /tmp/spacevim-config/
    mkdir -p /tmp/spacevim-config/autoload/
    mv -f spacevim-config/config/init.toml /tmp/spacevim-config/
    mv -f spacevim-config/config/myspacevim.vim /tmp/spacevim-config/
    info "Files successfully extracted. Removing spacevim-config git.."
    sudo rm -r spacevim-config
    info "done."
}

test_node_version () {
    info "Health check on nodejs (neccesary for some plugins)"
    node --version
    local NODEJS_VERSION=$(node --version)
    NODEJS_VERSION=${NODEJS_VERSION:1}

    if [ $(version "$MIN_NODEJS_VERSION") -ge $(version "$NODEJS_VERSION") ]
    then
        warning "Nodejs is out of date in order for some vim plugins to work proprely !"
        warning "To update nodejs use nvm, install it if it is not installed already:"
        warning "https://github.com/nvm-sh/nvm#install--update-script"
        warning "To install using nvm, run the following in a terminal:"
        warning "> npm install 16.19.1"
        warning "Also install neovim just to be sure:"
        warning "> npm install -g neovim"
        warning "Some plugins also need yarn:"
        warning "> npm install --global yarn"
    else
        info "Nodejs is up to date !"
    fi
}

test_pip_vim() {
    info "Make sure neovim and pynvim are installed:"
    pip3 list | grep "vim"
    info "Make sure a linter is installed :"
    pip3 list | grep "lint"
}

# === main ===

if ls ~/.SpaceVim &> /dev/null
then
    info "SpaceVim was found. Do you wish to reinstall it ? [Y/n] If not this script will only reload the config files."
    read answer

    if [[ "$answer" == "Y" ]] | [[ "$answer" == "y" ]]
    then
        curl -sLf https://spacevim.org/install.sh | bash -s -- --uninstall
        install_spacevim
        upload_gitrepo
        update_config
        test_node_version
        test_pip_vim
        info "All done!"
    else
        upload_gitrepo
        info "Checking if your local configuration matches the repository configuration..."
        DOES_INIT_DIFFER=false
        DOES_AUTOLOAD_DIFFER=false
        
        if ! cmp -s ~/.SpaceVim.d/init.toml /tmp/spacevim-config/init.toml
        then
            DOES_INIT_DIFFER=true
        fi
        if ! cmp -s ~/.SpaceVim.d/autoload/myspacevim.vim /tmp/spacevim-config/myspacevim.vim
        then
            DOES_AUTOLOAD_DIFFER=true
        fi

        info "Does init.toml differ: $DOES_INIT_DIFFER"
        info "Does autoload content differ (might always be true if fuzzy finder is not fdfind): $DOES_AUTOLOAD_DIFFER"

        if $DOES_INIT_DIFFER | $DOES_AUTOLOAD_DIFFER
        then
            update_config
            info "Config files are now up-to-date !"
            exit 0
        fi
        info "Config files are up-to-date."
    fi
else
    install_spacevim
    upload_gitrepo
    update_config
    test_node_version
    test_pip_vim
    info "All done!"
fi

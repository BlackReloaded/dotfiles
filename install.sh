#!/bin/bash

export DOTFILE_REPO="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export LOCALBASHEXTRA="${HOME}/.localbashextra"
export LOCALGITEXTRA="${HOME}/.gitconfig.d"


function ensureLocalBashRCExtra {
    if [[ -d "${LOCALBASHEXTRA}" ]]; then
        return 0;
    fi
    mkdir -p ${LOCALBASHEXTRA}
}

function ensureLocalGitExtra {
    if [[ -d "${LOCALGITEXTRA}" ]]; then
        return 0;
    fi
    mkdir -p ${LOCALGITEXTRA}
}

function linkFileOrFolder {
    echo -n "Trying to link '${1}': "
    if [[ -L "${2}" ]]; then
        if [[ -e "${2}" ]]; then
            echo "already linked"
            return 0;
        else
            unlink ${2}
        fi
    elif [[ -f "${2}" || -d "${2}" ]]; then
        mv "${2}" "${2}_bak"
        echo -n "renamed "
    fi
    ln -s "${1}" "${2}"
    echo "linked"
}

function setupYubikey {
    if [[ -z "${WSL_DISTRO_NAME}" ]]; then
        echo "WSL not found: ignoring setup yubikey"
        return 0;
    fi
    echo -n "Installing yubikey wsl bridge: "
    ensureLocalBashRCExtra
    cat << \EOF > ${LOCALBASHEXTRA}/yubikey.sh
export SSH_AUTH_SOCK=${HOME}/.ssh_agent.sock
ss -a | grep -q ${SSH_AUTH_SOCK}
if [ $? -ne 0 ]; then
    rm -f ${SSH_AUTH_SOCK}
    (setsid nohup socat UNIX-LISTEN:${SSH_AUTH_SOCK},fork EXEC:${HOME}/.bin/wsl2-ssh-pageant.exe >/dev/null 2>&1 &)
fi

export GPG_AGENT_SOCK=${HOME}/.gnupg/S.gpg-agent
ss -a | grep -q ${GPG_AGENT_SOCK}
if [ $? -ne 0 ]; then
        rm -rf ${GPG_AGENT_SOCK}
        (setsid nohup socat UNIX-LISTEN:${GPG_AGENT_SOCK},fork EXEC:"${HOME}/.bin/wsl2-ssh-pageant.exe --gpg S.gpg-agent" >/dev/null 2>&1 &)
fi
EOF
    curl https://github.com/blackreloaded.gpg | gpg --import
    keyid=$( gpg --with-colons --fingerprint m.kohlbau@myopenfactory.com | grep pub | cut -d: -f5 )
    echo -e "5\ny\n" |  gpg --command-fd 0 --expert --edit-key ${keyid} trust;
    ensureLocalGitExtra
cat << EOF > ${LOCALGITEXTRA}/yubikey
[user]
        signingkey = ${keyid}
[commit]
        gpgsign = true
EOF
    echo "created"
    source ${LOCALBASHEXTRA}/yubikey.sh
}

function setupBinary {
    echo "setup binary folder"
    linkFileOrFolder "${DOTFILE_REPO}/binary" "${HOME}/.bin"
    ensureLocalBashRCExtra
    echo 'export PATH="${HOME}/.bin/:${PATH}"' > ${LOCALBASHEXTRA}/binPath.sh
}

function setupHomeDot {
    echo "setup homedot files"
    for file in `ls ${DOTFILE_REPO}/home`
    do
        linkFileOrFolder "${DOTFILE_REPO}/home/${file}" "${HOME}/.${file}"
    done
}

function setupHomebrew {
    echo -n "setup homebrew: "
    if [[ ! -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
       output=$( curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash 2>&1 )
       if [[ $? -ne 0 ]]; then
            echo "failed"
            echo "${output}"
            return 1;
       fi
       ensureLocalBashRCExtra
       echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"' > ${LOCALBASHEXTRA}/brew.sh
    fi
    source ${LOCALBASHEXTRA}/brew.sh
    output=$( brew install $( cat ${DOTFILE_REPO}/brew/packages.conf | tr '\n' ' ' ) 2>&1 )
    if [[ $? -ne 0 ]]; then
        echo "failed"
        echo "${output}"
        return 1;
    fi
    echo "ok"
}

function setupPrivate {
    echo -n "init private submodule: "
    PWD=$( pwd )
    cd ${DOTFILE_REPO}
    GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=${DOTFILE_REPO}/github_knownhost" git submodule init
    GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=${DOTFILE_REPO}/github_knownhost" git submodule update
    if [[ $? -ne 0 ]]; then
        echo "failed"
        return 1;
    fi
    echo "ok"
    linkFileOrFolder "${DOTFILE_REPO}/private/ssh" "${HOME}/.ssh"
    cd $PWD
}

function setupApt {
    output=$( sudo apt update )
    rv=$?
    echo -n "install apt packages: "
    if [[ ${rv} -ne 0 ]]; then
        echo "failed"
        echo "${output}"
        return 1;
    fi
    output=$( sudo apt -y install $( cat ${DOTFILE_REPO}/apt_packages.conf | tr '\n' ' ' ) 2>&1 )
    if [[ $? -ne 0 ]]; then
        echo "failed"
        echo "${output}"
        return 1;
    fi
    echo "ok"
}


cat << EOF > ${HOME}/.bashrc_variables
export DOTFILE_REPO="${DOTFILE_REPO}"
export LOCALBASHEXTRA="${LOCALBASHEXTRA}"
EOF

case $1 in
    yubikey)
        setupYubikey
        ;;
    binary)
        setupBinary
        ;;
    home)
        setupHomeDot
        ;;
    apt)
        setupApt
        ;;
    brew)
        setupHomebrew
        ;;
    private)
        setupPrivate
        ;;
    *)
        setupApt
        setupHomebrew
        setupBinary
        setupHomeDot
        setupYubikey
        setupPrivate
        ;;
esac

cd ${DOTFILE_REPO} && git remote set-url origin git@github.com:BlackReloaded/dotfiles.git

source ${HOME}/.bashrc

#!/bin/bash
set -u

# enable  command completion
set -o history -o histexpand

python="python3"

abort() {
  printf "%s\n" "$1"
  exit 1
}

getc() {
  local save_state
  save_state=$(/bin/stty -g)
  /bin/stty raw -echo
  IFS= read -r -n 1 -d '' "$@"
  /bin/stty "$save_state"
}

exit_on_error() {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

wait_for_user() {
  local c
  echo
  echo "Press RETURN to continue or any other key to abort"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "$c" == $'\r' || "$c" == $'\n' ]]; then
    exit 1
  fi
}

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

# string formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

# Things can fail later if `pwd` doesn't exist.
# Also sudo prints a warning message for no good reason
cd "/usr" || exit 1

linux_install_pre() {
    sudo apt-get update 
    sudo apt-get install --no-install-recommends --no-install-suggests -y apt-utils curl git cmake build-essential
    exit_on_error $?
}

linux_install_python() {
    which $python
    if [[ $? != 0 ]] ; then
        ohai "Installing python"
        sudo apt-get install --no-install-recommends --no-install-suggests -y $python
    else
        ohai "Updating python"
        sudo apt-get install --only-upgrade $python
    fi
    exit_on_error $? 
    ohai "Installing python tools"
    sudo apt-get install --no-install-recommends --no-install-suggests -y $python-pip $python-dev 
    exit_on_error $? 
}

linux_update_pip() {
    PYTHONPATH=$(which $python)
    ohai "You are using python@ $PYTHONPATH$"
    ohai "Installing python tools"
    $python -m pip install --upgrade pip
}

linux_install_cron() {
  ohai "Installing cron"
  sudo apt-get install -y cron
}

linux_install_ufw() {
  ohai "Installing ufw"
  sudo apt-get install -y ufw
}

linux_install_pm2() {
  ohai "Installing pm2"
  sudo apt-get install -y jq npm
  sudo npm install -g -y pm2
  exit_on_error $?
}

linux_install_docker() {
  ohai "Installing docker"
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d -y /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

linux_install_bittensor() {
    ohai "Cloning bittensor@master into ~/.bittensor/bittensor"
    mkdir -p ~/.bittensor/bittensor
    git clone https://github.com/opentensor/bittensor.git ~/.bittensor/bittensor/ 2> /dev/null || (cd ~/.bittensor/bittensor/ ; git fetch origin master ; git checkout master ; git pull --ff-only ; git reset --hard ; git clean -xdf)
    ohai "Installing bittensor"
    $python -m pip install -e ~/.bittensor/bittensor/
    exit_on_error $? 
}

linux_increase_ulimit(){
    ohai "Increasing ulimit to 1,000,000"
    prlimit --pid=$PPID --nofile=1000000
}

# Do install.
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then

    which -s apt
    if [[ $? == 0 ]] ; then
        abort "This linux based install requires apt. To run with other distros (centos, arch, etc), you will need to manually install the requirements"
    fi
    echo """
    
██████╗░██╗████████╗████████╗███████╗███╗░░██╗░██████╗░█████╗░██████╗░
██╔══██╗██║╚══██╔══╝╚══██╔══╝██╔════╝████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║░░░░░░██║░░░█████╗░░██╔██╗██║╚█████╗░██║░░██║██████╔╝
██╔══██╗██║░░░██║░░░░░░██║░░░██╔══╝░░██║╚████║░╚═══██╗██║░░██║██╔══██╗
██████╦╝██║░░░██║░░░░░░██║░░░███████╗██║░╚███║██████╔╝╚█████╔╝██║░░██║
╚═════╝░╚═╝░░░╚═╝░░░░░░╚═╝░░░╚══════╝╚═╝░░╚══╝╚═════╝░░╚════╝░╚═╝░░╚═╝
                                                    
                                                    - Mining a new element.
    """
    ohai "This script will install:"
    echo "git"
    echo "curl"
    echo "cmake"
    echo "build-essential"
    echo "python3"
    echo "python3-pip"
    echo "cron"
    echo "ufw"
    echo "pm2"
    echo "docker (choice)"
    echo "bittensor (choice)"

    wait_for_user
    linux_install_pre
    linux_install_python
    linux_update_pip
    linux_install_cron
    linux_install_ufw
    linux_install_pm2

    echo "Would you like to install Docker?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) linux_install_docker; break;;
            No ) echo "Skipping Docker installation"; break;;
            * ) echo "Please enter 1 or 2";;
        esac
    done

    echo "Would you like to install latest Bittensor?"
    select yn in "Yes" "No"; do
        case $yn in
            [Yy]* ) linux_install_bittensor; break;;
            [Nn]* ) echo "Skipping Bittensor installation"; break;;
            * ) echo "Please enter 1 or 2";;
        esac
    done

    ohai "Would you like to increase the ulimit? This will allow your miner to run for a longer time"
    wait_for_user
    linux_increase_ulimit
    echo ""
    echo ""
    echo "######################################################################"
    echo "##                                                                  ##"
    echo "##                      ESSENTIAL SETUP                             ##"
    echo "##                                                                  ##"
    echo "######################################################################"
    echo ""
    echo ""
    
else
  abort "Setup is only for Linux"
fi

# Use the shell's audible bell.
if [[ -t 1 ]]; then
printf "\a"
fi

echo "Essential setup successful."
echo ""
echo ""

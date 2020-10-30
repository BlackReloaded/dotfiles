set -e
sudo apt install git
TARGET="${HOME}/src/blackreloaded/"
mkdir -p ${TARGET}
cd ${TARGET}
git clone https://github.com/blackreloaded/dotfiles
cd dotfiles
./install.sh
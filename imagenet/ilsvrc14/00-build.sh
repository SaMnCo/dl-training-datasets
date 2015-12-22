#!/bin/bash
# This script will download images from ImageNet. 

# Usage: ./build-dataset.sh <path/to/target/folder> 
# Global variables
OUTPUT_FOLDER="$1"

function ensure_cmd_or_install_package_apt() {
    local CMD=$1
    shift
    local PKG=$*
    hash $CMD 2>/dev/null || { 
    	log warn $CMD not available. Attempting to install $PKG
    	(sudo apt-get update -yqq && sudo apt-get install -yqq ${PKG}) || die "Could not find $PKG"
    }
}

function is_sudoer() {
    CAN_RUN_SUDO=$(sudo -n uptime 2>&1|grep "load"|wc -l)
    if [ ${CAN_RUN_SUDO} -gt 0 ]
    then
        echo 1
    else
        echo 0
    fi
}

# Check if we are sudoer or not
if [ $(is_sudoer) -eq 0 ]; then
    die "You must be root or sudo to run this script"
fi

ensure_cmd_or_install_package_apt wget wget 
ensure_cmd_or_install_package_apt gzip gzip
ensure_cmd_or_install_package_apt mogrify imagemagick

# OK let's download this!
[ ! -d "${OUTPUT_FOLDER}" ] && mkdir -p "${OUTPUT_FOLDER}"
cd "${OUTPUT_FOLDER}"

wget -cq http://www.deepdetect.com/dd/datasets/imagenet/ilsvrc12_urls.txt.gz
gzip -d ilsvrc12_urls.txt.gz && mv ilsvrc12_urls.txt.gz /tmp/

git clone https://github.com/beniz/imagenet_downloader.git

python imagenet_downloader/download_imagenet_dataset.py \
	ilsvrc12_urls.txt \
	"${OUTPUT_FOLDER}" \
	--jobs 10 \
	--retry 3 \
	--sleep 0

# This will take looooooooaaaaads of time... 
# Let's use another script to adapt the images

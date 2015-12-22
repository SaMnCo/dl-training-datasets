#!/bin/bash
# This script will download images from Amazon S3 along with information about them to make them usable in the context of neurotalk. 
# The source items are the Im2Text files (http://tlberg.cs.unc.edu/vicente/sbucaptions/), created via the build-dataset.sh script
# and stored in S3. 

# Usage: ./download-dataset.sh <path/to/target/folder>
# Global variables
TARGET_PATH="$1"

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

# Eventually installing dependencies
ensure_cmd_or_install_package_apt wget wget

echo "Creating Target folder"
[ -d "${TARGET_PATH}" ] && echo "Target path already started, moving forward" || mkdir -p "${TARGET_PATH}"

cd "${TARGET_PATH}"

# Download the JSON file
wget -qc https://s3-us-west-2.amazonaws.com/samnco-static-files/datasets/im2text.json.tar.gz & 

FILES=""
for thread in {a..l}
do
  wget -qc https://s3-us-west-2.amazonaws.com/samnco-static-files/datasets/im2text.a${thread} &
  FILES="${FILES} im2text.a${thread}"
done

echo "Now waiting for all threads to end"
wait
echo "Done waiting for threads"

echo "Combining all datasets now"
cat ${FILES} > im2text.tar.gz

# Uncompress files
tar xfz m2text.json.tar.gz
tar xfz im2text.tar.gz

mv im2test.a* /tmp/
cd -
echo "All done. Enjoy!"


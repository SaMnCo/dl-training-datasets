#!/bin/bash
# This script will download images from Amazon S3 along with information about them to make them usable in the context of neurotalk. 
# The source items are the Im2Text files (http://tlberg.cs.unc.edu/vicente/sbucaptions/), created via the build-dataset.sh script
# and stored in S3. 

# Usage: ./download-dataset.sh <path/to/target/folder>
# Global variables
TARGET_PATH="$1"

cat > /tmp/md5sum.txt << EOF
19d1fc999cee5b22536a6b4efa06ebab  im2text.aa
48d4b6268fbd455d3875668fd2a098b2  im2text.ab
920c548b3c6a1dd2d64b9d78e5621c15  im2text.ac
11e87d92b7bf649031daf60972f2e328  im2text.ad
cac05d8564fb8e48471e8b81e5a9f36b  im2text.ae
dd50c189ac57aef173e3ce1125cde0b7  im2text.af
c748cccabf17a1c0687d621a6c354b9c  im2text.ag
2811ef56b06ad53b1bb95a5abbca115c  im2text.ah
5473ad53d78a9ec35da0a4a8fbe30bb8  im2text.ai
088c93d5934a1432ec351b46359d44a4  im2text.aj
4da0fb1519d19150589286c640cc8784  im2text.ak
93c44223d53d1694f65ac8f7da144f72  im2text.al
e22e89d7729989dc635cac60a7fd29fc  im2text.json.tar.gz
EOF

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
DONE=-1

until [ ${DONE} = 0 ]
do 
  FILES=""
  for thread in {a..l}
  do
    wget -qc https://s3-us-west-2.amazonaws.com/samnco-static-files/datasets/im2text.a${thread} &
    FILES="${FILES} im2text.a${thread}"
  done

  wget -qc https://s3-us-west-2.amazonaws.com/samnco-static-files/datasets/im2text.json.tar.gz & 

  echo "Now waiting for all threads to end"
  wait
  echo "Done waiting for threads. Now checking md5sum"

  DONE=$(md5sum -c /tmp/md5sum.txt | grep 'FAILED' | wc -l)
done

echo "Combining all datasets now"
cat ${FILES} > im2text.tar.gz
rm ${FILES}

# Uncompress files
tar xfz im2text.json.tar.gz
tar xfz im2text.tar.gz

mv im2test.a* /tmp/
cd -
echo "All done. Enjoy!"


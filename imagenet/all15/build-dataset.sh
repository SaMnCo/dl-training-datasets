#!/bin/bash
# This script will download images from ImageNet. 

# Usage: ./build-dataset.sh <path/to/target/folder> 
# Global variables
TARGET_PATH="$1"
THREADS=50

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

function download_image() {
  local SYNSET="$1"
  shift
  local ID="$1"
  shift
  local URL="$1"
  local EXT="$(echo $URL | sed 's/.*\.//g')"
  local IMAGE_PATH="dataset/${SYNSET}/${ID}.${EXT}"
  local JSON_PATH="${TARGET_PATH}/jsonset/imagenet.${SYNSET}.json"
  local JSON_ARRAY="[]"

  # Let's download the image
  if [ ! -f "${IMAGE_PATH}" ]
  then
    # echo "Processing image ${ID} at ${URL}"
    wget -qc --connect-timeout 3 --read-timeout 5 --timeout 30 "${URL}" -O "${TARGET_PATH}/${IMAGE_PATH}" \
      && {
        # Converting potential gif files to jpg
        if [ "${EXT}" != "jpg" ]
        then
          echo "Converting ${EXT} file to jpg"
          mogrify -format jpg "${TARGET_PATH}/${IMAGE_PATH}"
          rm "${TARGET_PATH}/${IMAGE_PATH}"
          local EXT="jpg"
          local IMAGE_PATH="dataset/${ID}.${EXT}"
        fi
        # Now filtering files that are too small 
        local SIZE=$(ls -l "${TARGET_PATH}/${IMAGE_PATH}" | awk '{ print $5 }')
        [ "x${SIZE}" = "x" ] && local SIZE=0
        if [ ${SIZE} -gt 2000 ] # 2051 bytes is the size of the Flickr error message
        then
          # echo "Adding caption for line ${ID} to ${OUTPUT}"
          local DEFINITION="$(grep ^${SYNSET} "${TARGET_PATH}/dict/data.noun" | cut -f2- -d'|' | tr -d ';\"')"
          for word in $(grep "^${SYNSET}" "${TARGET_PATH}/dict/data.noun" \
              | cut -f2- -d"n" \
              | cut -f1 -d"@" \
              | sed s/\ 0\ /\ /g \
              | tr -d [0-9])
          do 
              JSON_ARRAY=$(echo "${JSON_ARRAY}" | jq ". + [\"${word}\"]")
          done
          cat "${JSON_PATH}" | jq ". + [ {\"captions\": ${JSON_ARRAY}, \"definition\": \"${DEFINITION}\", \"id\": \"${ID}\", \"file_path\": \"${IMAGE_PATH}\", \"url\": \"${URL}\", \"image_id\": \"${ID}\"  }]" > /tmp/tmp.file.${ID} && \
          mv /tmp/tmp.file.${ID} "${JSON_PATH}"
        else 
          echo "Image ${ID} is too small. Betting it is an error image from Flickr"
          rm -f "${TARGET_PATH}/${IMAGE_PATH}"
        fi
      } \
      || { 
        echo "Failed to download image ${ID} at ${URL}"
        rm "${TARGET_PATH}/${IMAGE_PATH}"
      }
  else 
    echo "Image ${ID} already there. Passing by"
  fi
}

function download_thread() {
  local THREAD=$1
  echo "Thread ${THREAD} started. To infinity and beyond!"

  local START=$(expr ${THREAD} \* ${ITEMS_PER_THREAD} + 1)
  local END=$(expr $(expr ${THREAD} + 1 ) \* ${ITEMS_PER_THREAD})

  for synset in $(seq ${START} 1 ${END})
  do 
    echo "Started downloading Synset ${SYNSET}"
    local SYNSET="$(sed -n ${synset}p ${TARGET_PATH}/imagenet_synset_listing | tr -d 'n')"
    [ -d "${TARGET_PATH}/dataset/${SYNSET}" ] || mkdir -p "${TARGET_PATH}/dataset/${SYNSET}"
    # Creating JSON file if needed
    local OUTPUT="jsonset/imagenet.${SYNSET}.json"
    echo "Creating output json file ${TARGET_PATH}/${OUTPUT}"
    [ -f "${TARGET_PATH}/${OUTPUT}" ] \
      && echo "Output file already created, moving forward" \
      || echo "[]" \
      > "${TARGET_PATH}/${OUTPUT}"

    # Cleaning up windows files \r
    dos2unix "${TARGET_PATH}/image_urls/n${SYNSET}"

    for i in $(seq 1 1 $(cat "${TARGET_PATH}/image_urls/n${SYNSET}" | wc -l))
      do
        download_image "${SYNSET}" "${SYNSET}_$(printf '%06d' ${i})" "$(sed -n ${i}p ${TARGET_PATH}/image_urls/n${SYNSET})"
    done


  done

  echo "Thread ${THREAD} done :)"
}

# Check if we are sudoer or not
if [ $(is_sudoer) -eq 0 ]; then
    die "You must be root or sudo to run this script"
fi

ensure_cmd_or_install_package_apt wget wget 
ensure_cmd_or_install_package_apt curl curl
ensure_cmd_or_install_package_apt mogrify imagemagick
ensure_cmd_or_install_package_apt dos2unix dos2unix

# OK let's download this!
[ -d "${TARGET_PATH}" ] || mkdir -p "${TARGET_PATH}"
cd "${TARGET_PATH}"

if [ ! -d "${TARGET_PATH}/dict" ]
then 
  curl -fSsL http://wordnetcode.princeton.edu/3.0/WNdb-3.0.tar.gz \
    > wn.tar.gz
  tar xfz wn.tar.gz && mv wn.tar.gz /tmp/
fi

[ -f "${TARGET_PATH}/imagenet_synset_listing" ] || \
  curl -fSsL http://www.image-net.org/api/text/imagenet.synset.obtain_synset_list \
    > "${TARGET_PATH}/imagenet_synset_listing"

[ -f "${TARGET_PATH}/wordnet.is_a.txt" ] || \
  curl -fSsL -O http://www.image-net.org/archive/wordnet.is_a.txt

# Cleaning up empty lines in synset
sed -i '/^$/d' "${TARGET_PATH}/imagenet_synset_listing"

# Now downloading all synsets available
[ -d "${TARGET_PATH}/image_urls" ] || mkdir -p "${TARGET_PATH}/image_urls" 

while read synset; do
    [ -f "${TARGET_PATH}/image_urls/${synset}" ] || \
        curl -fSsL http://www.image-net.org/api/text/imagenet.synset.geturls?wnid=${synset} \
            > "${TARGET_PATH}/image_urls/${synset}"
done < "${TARGET_PATH}/imagenet_synset_listing"

# Now download all images via threads 
# cd image_urls
NB_ITEMS=$(cat "${TARGET_PATH}/imagenet_synset_listing" | wc -l)
ITEMS_PER_THREAD=$(expr ${NB_ITEMS} \/ ${THREADS})

[ -d "${TARGET_PATH}/dataset" ] || mkdir -p "${TARGET_PATH}/dataset"
[ -d "${TARGET_PATH}/jsonset" ] || mkdir -p "${TARGET_PATH}/jsonset"

for thread in $(seq 0 1 $(expr ${THREADS} - 1))
do
  download_thread ${thread} &
done



# This will take looooooooaaaaads of time... 
# Let's use another script to adapt the images

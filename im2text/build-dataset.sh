#!/bin/bash
# This script will download images from Flickr along with information about them to make them usable in the context of neurotalk. 
# The source items are the Im2Text files (http://tlberg.cs.unc.edu/vicente/sbucaptions/)

# Usage: ./build-dataset.sh <path/to/target/folder> <start_image_number> <nb_images_to_download>
# Global variables
TARGET_PATH="$1"
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"
START_IMAGE=$(expr $2 + 1)
NB_IMAGES=$3
END_IMAGE=$(expr $2 + ${NB_IMAGES})

# Semi hard coded values
DATASET="im2text"
THREADS=10

# Create an md5sum check for removed images (This is an md5 for Flickr "404 image")
# This can be enabled but is REALLY slow. 
# BAD_MD5="880a7a58e05d3e83797f27573bb6d35c"

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
  local ID=$1
  shift
  local OUTPUT="$1"

  local CAPTION="$(sed -n ${ID}p ${TARGET_PATH}/dataset/SBU_captioned_photo_dataset_captions.txt | tr -d '\";\\')"
  local IMAGE="$(sed -n ${ID}p ${TARGET_PATH}/dataset/SBU_captioned_photo_dataset_urls.txt)"
  local FLICKR_ID="$(echo ${IMAGE} | cut -f5 -d'/' | cut -f1 -d'_')"
  local IMAGE_ID="$(printf '%012d' ${ID})"
  local IMAGE_PATH="${TARGET_PATH}/${DATASET}/${DATASET}_${IMAGE_ID}.jpg"
  # Let's download the image
  if [ ! -f "${IMAGE_PATH}" ]
  then
    echo "Processing image ${IMAGE}"
    wget -qc "${IMAGE}" -O "${IMAGE_PATH}"
    local SIZE=$(ls -l "${IMAGE_PATH}" | awk '{ print $5 }')
    # CHECK_MD5=$(md5sum "${IMAGE_PATH}" | cut -f1 -d' ')
    # if [ "${CHECK_MD5}" = "${BAD_MD5}" ]
    # The test of size is really a bad ack, but it's fast. 
    if [ ${SIZE} -lt 5000 ]
    then
      echo "${IMAGE} at line ${ID} does not exist. Removing from our list"
      rm "${IMAGE_PATH}"
    else
      echo "Adding caption for line ${ID} to ${OUTPUT}"
      cat "${OUTPUT}" | jq ". + [ {\"captions\": [ \"${CAPTION}\" ], \"id\": \"${IMAGE_ID}\", \"file_path\": \"${IMAGE_PATH}\", \"url\": \"${IMAGE}\", \"image_id\": \"${FLICKR_ID}\"  }]" > /tmp/tmp.file.${ID} && \
      mv /tmp/tmp.file.${ID} "${OUTPUT}"
    fi
  else 
    echo "Image ${IMAGE} already there. Passing by"
  fi
}

function download_thread() {
  local THREAD=$1
  echo "Thread ${THREAD} started. To infinity and beyond!"

  local OUTPUT="im2text.${THREAD}.json"
  echo "Creating output json file ${TARGET_PATH}/${OUTPUT}"
  [ -f "${TARGET_PATH}/${OUTPUT}" ] && echo "Output file already created, moving forward" || echo "[]" > "${TARGET_PATH}/${OUTPUT}"

  local START=$(expr ${START_IMAGE} + ${THREAD} \* ${IMAGES_PER_THREAD} + 1)
  local END=$(expr ${START_IMAGE} + $(expr ${THREAD} + 1 ) \* ${IMAGES_PER_THREAD})

  for image in $(seq ${START} 1 ${END})
  do 
    download_image ${image} "${TARGET_PATH}/${OUTPUT}"
  done

  echo "Thread ${THREAD} done :)"
}

# Check if we are sudoer or not
if [ $(is_sudoer) -eq 0 ]; then
    die "You must be root or sudo to run this script"
fi

# Eventually installing dependencies
ensure_cmd_or_install_package_apt jq jq
ensure_cmd_or_install_package_apt wget wget

echo "Creating Target folder"
[ -d "${TARGET_PATH}" ] && echo "Target path already started, moving forward" || mkdir -p "${TARGET_PATH}"

cd "${TARGET_PATH}"
# Download the initial file if needed
echo "Downloading source dataset if needed"
[ -f SBUCaptionedPhotoDataset.tar.gz ] && echo "Already there, moving forward" || wget -cq http://tlberg.cs.unc.edu/vicente/sbucaptions/SBUCaptionedPhotoDataset.tar.gz
echo "Uncompressing..."
[ -d "dataset" ] && echo "Already uncompressed, moving forward" || tar xfz SBUCaptionedPhotoDataset.tar.gz 
echo "Creating Dataset folder"
[ -d "${DATASET}" ] && echo "Dataset already started, moving forward" || mkdir -p "${DATASET}"

IMAGES_PER_THREAD=$(expr ${NB_IMAGES} \/ ${THREADS})
echo "Each thread is going to process ${IMAGES_PER_THREAD} images"

for thread in $(seq 0 1 $(expr ${THREADS} - 1))
do
  download_thread ${thread} &
done

echo "Now waiting for all threads to end"
wait
echo "Done waiting for threads"

echo "Combining all datasets now"
[ -f "${TARGET_PATH}/${DATASET}.json" ] || echo "[]" > "${TARGET_PATH}/${DATASET}.json"
jq -s add "${TARGET_PATH}/${DATASET}.json" "${TARGET_PATH}"/im2text.*.json > /tmp/final.json && \
  jq '. | unique | sort_by(.id) ' /tmp/final.json > "${TARGET_PATH}/${DATASET}.json"

echo "Removing Temporary JSON files"
find  "${TARGET_PATH}" -name "im2text.*.json" -exec mv {} /tmp/ \;

echo "preparing the H5 and JSON files for training"
python "${MYDIR}"/01-build-h5-and-json.py  \
  --input_json "${TARGET_PATH}/im2text.json" \
  --num_val 20000 \
  --num_test 20000 \
  --images_root "${TARGET_PATH}" \
  --word_count_threshold 5 \
  --output_json "${TARGET_PATH}/im2texttalk.json" \
  --output_h5 "${TARGET_PATH}/im2texttalk.h5"
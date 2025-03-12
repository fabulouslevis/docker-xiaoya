#!/bin/bash
yml=$1

declare -A images=( 
    ["ghcr.io\/monlor\/xiaoya-alist:latest"]="ghcr.io\/monlor\/xiaoya-alist:\${ALIST_IMAGE_TAG:-latest}" 
    ["ghcr.io\/monlor\/xiaoya-metadata:latest"]="ghcr.io\/monlor\/xiaoya-metadata:\${METADATA_IMAGE_TAG:-latest}"  
    ["ghcr.io\/monlor\/xiaoya-embyserver:latest"]="ghcr.io\/monlor\/xiaoya-embyserver:\${EMBY_IMAGE_TAG:-latest}" 
)

for image in "${!images[@]}"; do
     sed -i "s/$image/${images[$image]}/g" $yml
done
#!/bin/bash
set -euo pipefail
PLATFORM="${1}"
GROUP() {
    echo "::group::${*}"
    set -x
}
ENDGROUP() {
    set +x
    echo "::endgroup::"
}
pv() {
    if command -v pv &> /dev/null; then
        command pv -f "${@}"
    else
        dd if="${1}" bs=1M status=progress
    fi
}

cd work

GROUP "Install dependencies..."
sudo apt-get update && sudo apt-get install -y pv xz-utils guestfish
ENDGROUP

GROUP "Download CoreOS image..."
bash ./steps/1-download-image.sh | tee download.log
ENDGROUP

GROUP "Extract downloaded CoreOS image..."
bash ./steps/2-extract-image.sh
ENDGROUP


GROUP "Convert CoreOS image (to ${*})..."
INFILExz="$(tail -1 ./download.log)"
INFILE="${INFILExz%.xz}"
OUTFILE="${INFILE//qemu/${PLATFORM}}"
VERSION="$(tail -1 ./download.log | sed -e "s/qemu/${PLATFORM}/" | cut -d- -f3)"
sudo chmod -R a+r /boot
export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
bash "./steps/3-convert-image.sh" "${INFILE}" "${OUTFILE}" "${PLATFORM}"
ENDGROUP

GROUP "Compress converted CoreOS image..."
pv "${OUTFILE}" |  gzip  > "${OUTFILE}.gz"
ENDGROUP

GROUP "Record metadata..."
set +u # Just in case we're not running in GHA, don't exit on unset var
{
echo "outfile=${OUTFILE#./}.gz"
echo "version=${VERSION}"
echo "tag=${VERSION}.$(date -I)"
} | tee -a "$GITHUB_OUTPUT"
set -u
ENDGROUP
#!/bin/bash
#
# Copyright (C) 2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

DEVICE=rosy
VENDOR=xiaomi

DEVICE_BRINGUP_YEAR=2018

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

LINEAGE_ROOT="$MY_DIR"/../../..

HELPER="$LINEAGE_ROOT"/vendor/lineage/build/tools/extract_utils.sh
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

while [ "$1" != "" ]; do
    case $1 in
        -n | --no-cleanup )     CLEAN_VENDOR=false
                                ;;
        -s | --section )        shift
                                SECTION=$1
                                CLEAN_VENDOR=false
                                ;;
        * )                     SRC=$1
                                ;;
    esac
    shift
done

if [ -z "$SRC" ]; then
    SRC=adb
fi

# Initialize the helper
setup_vendor "$DEVICE" "$VENDOR" "$LINEAGE_ROOT" true "$CLEAN_VENDOR"

extract "$MY_DIR"/proprietary-files.txt "$SRC" "$SECTION"

DEVICE_BLOB_ROOT="$LINEAGE_ROOT"/vendor/"${VENDOR}"/"${DEVICE}"/proprietary

# Camera data
for CAMERA_LIB in libmmcamera2_stats_algorithm.so libmmcamera2_q3a_core.so libmmcamera2_cpp_module.so libmmcamera_dbg.so libmmcamera2_pproc_modules.so libmm-qcamera.so libmmcamera_tintless_bg_pca_algo.so libmmcamera_pdaf.so libmmcamera2_stats_modules.so libmmcamera_tintless_algo.so libmmcamera2_iface_modules.so libmmcamera2_dcrf.so libmmcamera_imglib.so libmmcamera2_imglib_modules.so libmmcamera_pdafcamif.so libmmcamera2_mct.so libmmcamera2_sensor_modules.so
    sed -i "s|/data/misc/camera|/data/vendor/qcam|g" "${DEVICE_BLOB_ROOT}"/vendor/lib/${CAMERA_LIB}
done

for CAMERA_LIB in camera.msm8953.so
    sed -i "s|/data/misc/camera|/data/vendor/qcam|g" "${DEVICE_BLOB_ROOT}"/vendor/lib/hw/${CAMERA_LIB}
done

# Camera socket
sed -i "s|/data/vendor/camera/cam_socket|/data/vendor/qcam/cam_socket|g" "$DEVICE_BLOB_ROOT"/vendor/bin/mm-qcamera-daemon

# Always set 0 (Off) as CDS mode in iface_util_set_cds_mode

BLOB_IFACE_MODULES="$DEVICE_BLOB_ROOT"/vendor/lib/libmmcamera2_iface_modules.so

sed -i -e 's|\xfd\xb1\x20\x68|\xfd\xb1\x00\x20|g' "$BLOB_IFACE_MODULES"
PATTERN_FOUND=$(hexdump -ve '1/1 "%.2x"' "$BLOB_IFACE_MODULES" | grep -E -o "fdb10020" | wc -l)
if [ $PATTERN_FOUND != "1" ]; then
	echo "Critical blob modification weren't applied on ${2}!"
	exit;
fi

"$MY_DIR"/setup-makefiles.sh

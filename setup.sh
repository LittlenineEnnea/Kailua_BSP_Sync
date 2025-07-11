#!/usr/bin/env bash
# Base URL for the git repository containing the tech packs
base_url="https://git.codelinaro.org/clo"
# Directory where downloaded XML files will be stored
download_dir="clo"
# Re-gerenate the download directory
rm -rf "$download_dir"
mkdir -p "$download_dir"
# Declaration of versions using associative arrays
declare -A versions=(
    [audio]="AU_TECHPACK_AUDIO.LA.8.0.R1.00.00.00.000.096"
    [camera]="AU_TECHPACK_CAMERA.LA.3.0.R1.00.00.00.000.083"
    [cv]="AU_TECHPACK_CV.LA.1.0.R1.00.00.00.000.040"
    [display]="AU_TECHPACK_DISPLAY.LA.3.0.R1.00.00.00.000.112"
    [graphics]="AU_TECHPACK_GRAPHICS.LA.1.0.R1.00.00.00.000.071"
    [kernelplatform]="AU_LINUX_KERNEL.PLATFORM.2.0.R1.00.00.00.004.152"
    [sensor]="AU_TECHPACK_SENSORS.LA.3.0.R1.00.00.00.000.042"
    [qssi_system]="AU_LINUX_ANDROID_LA.QSSI.15.0.R1.11.00.00.1136.120.00"
    [system]="AU_LINUX_ANDROID_LA.QSSI.13.0.R1.13.00.00.913.122.00"
    [vendor]="AU_LINUX_ANDROID_LA.VENDOR.13.2.4.R1.11.00.00.1084.028"
    [le]="LE.UM.6.3.3.r1-20400-genericarmv8-64.0"
    [video]="AU_TECHPACK_VIDEO.LA.3.0.R1.00.00.00.000.070"
    [xr]="AU_TECHPACK_XR.LA.1.0.R1.00.00.00.000.043"
    [def_system]="default_LA.QSSI.13.0.r1-12200-qssi.0"
)
# Loop through each tech pack and process accordingly
for key in "${!versions[@]}"; do
    filename="${versions[$key]}.xml"
    file_path="$download_dir/${key}.xml"

    # Determine the correct URL based on the key
    case $key in
        audio | camera | cv | display | graphics | sensor | video | xr)
            url="$base_url/la/techpack/$key/manifest/-/raw/release/$filename"
            ;;
        kernelplatform)
            url="$base_url/la/$key/manifest/-/raw/release/$filename"
            ;;
        qssi_system)
            url="$base_url/la/la/system/manifest/-/raw/release/$filename"
            ;;
        system | vendor)
            url="$base_url/la/la/$key/manifest/-/raw/release/$filename"
            ;;
        le)
            url="$base_url/le/le/manifest/-/raw/release/$filename"
            ;;
        def_system)
            url="$base_url/la/la/system/manifest/-/raw/release/$filename"
            ;;
    esac
    # Download the file if it does not already exist
    if [ ! -f "$file_path" ]; then
        echo "Downloading $file_path from $url"
        wget -q -O "$file_path" "$url" || {
            echo "Failed to download $filename from $url" >&2
            continue
        }
    fi
    # Remove unnecessary elements from the downloaded XML files
    xmlstarlet ed -L -d "//remote | //default | //refs" "$file_path"
    # Apply XML modifications only for kernelplatform
    if [ "$key" == "kernelplatform" ]; then
        xmlstarlet ed -L \
            -d "/manifest/project[contains(@name, 'prebuilts')]/@revision" \
            -r "/manifest/project[contains(@name, 'prebuilts')]/@upstream" -v "revision" \
            "$file_path"

        xmlstarlet ed -L \
            -i "/manifest/project[contains(@name, 'prebuilts')]" -t attr -n "clone-depth" -v "1" \
            "$file_path"
    fi
    # Apply XML modifications only for system
    if [ "$key" == "def_system" ]; then
        project_names=$(xmlstarlet sel -t -m "//project[@clone-depth='1']" -v "@name" -n "$file_path")

        for name in $project_names; do
            xmlstarlet ed -L \
                -d "/manifest/project[@name='$name']/@revision" \
                -r "/manifest/project[@name='$name']/@upstream" -v "revision" \
                "$download_dir/system.xml"

            xmlstarlet ed -L \
                -s "/manifest/project[@name='$name']" -t attr -n "clone-depth" -v "1" \
                "$download_dir/system.xml"
        done
        rm -rf "$file_path"
    fi
done
echo "Setting up manifest completed successfully."
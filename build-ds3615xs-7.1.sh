#!/bin/bash

# prepare build tools
sudo apt-get update && sudo apt-get install --yes --no-install-recommends ca-certificates build-essential git libssl-dev curl cpio bspatch vim gettext bc bison flex dosfstools kmod jq

dsmodel="DS3615xs"
osid="ds3615xs"
os_version="42661"
workpath="DS3615xs-7.1"
pat_address="https://global.download.synology.com/download/DSM/release/7.1/"${os_version}"/DSM_"${dsmodel}"_"${os_version}".pat"
root=`pwd`
mkdir $workpath
mkdir output
cd $workpath

# download redpill
git clone --depth=1 https://github.com/RedPill-TTG/redpill-lkm.git
git clone -b develop --depth=1 https://github.com/jumkey/redpill-load.git

# download syno toolkit
curl --location "https://sourceforge.net/projects/dsgpl/files/toolkit/DSM7.0/ds.bromolow-7.0.dev.txz/download" --output ds.bromolow-7.0.dev.txz

mkdir bromolow
tar -C./bromolow/ -xf ds.bromolow-7.0.dev.txz usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build

# build redpill-lkm
cd redpill-lkm
sed -i 's/   -std=gnu89/   -std=gnu89 -fno-pie/' ../bromolow/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build/Makefile
make LINUX_SRC=../bromolow/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build dev-v7
read -a KVERS <<< "$(sudo modinfo --field=vermagic redpill.ko)" && cp -fv redpill.ko ../redpill-load/ext/rp-lkm/redpill-linux-v${KVERS[0]}.ko || exit 1
cd ..

# download old pat for syno_extract_system_patch # thanks for jumkey's idea.
mkdir synoesp
curl --location https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat --output oldpat.tar.gz
tar -C./synoesp/ -xf oldpat.tar.gz rd.gz
cd synoesp

output=$(xz -dc < rd.gz 2>/dev/null | cpio -idm 2>&1)
mkdir extract && cd extract
cp ../usr/lib/libcurl.so.4 ../usr/lib/libmbedcrypto.so.5 ../usr/lib/libmbedtls.so.13 ../usr/lib/libmbedx509.so.1 ../usr/lib/libmsgpackc.so.2 ../usr/lib/libsodium.so ../usr/lib/libsynocodesign-ng-virtual-junior-wins.so.7 ../usr/syno/bin/scemd ./
ln -s scemd syno_extract_system_patch

curl --location  ${pat_address} --output ${os_version}.pat

mkdir output-pat

sudo LD_LIBRARY_PATH=. ./syno_extract_system_patch ${os_version}.pat output-pat || echo "extract latest pat"

cd output-pat && sudo tar -zcvf ${os_version}.pat ./ && sudo chmod 777 ${os_version}.pat
read -a os_sha256 <<< $(sha256sum ${os_version}.pat)
echo $os_sha256
cp ${os_version}.pat ${root}/${workpath}/redpill-load/cache/${osid}_${os_version}.pat
cd ../../../


# build redpill-load
cd redpill-load
cp -f ${root}/user_config.DS3615xs.json ./user_config.json
cp -rf ${root}/config/* ./config
# 7.1.0 must add this ext
./ext-manager.sh add https://raw.githubusercontent.com/jumkey/redpill-load/develop/redpill-misc/rpext-index.json  
./ext-manager.sh add https://raw.githubusercontent.com/pocopico/rp-ext/master/mpt2sas/rpext-index.json
./ext-manager.sh add https://raw.githubusercontent.com/jumkey/redpill-load/develop/redpill-acpid/rpext-index.json
ls -l cache
echo "kaishi start "
sudo ./build-loader.sh ${dsmodel} '7.1.0-'${os_version}
echo "kaishi end "
mv images/redpill-${dsmodel}*.img ${root}/output/
cd ${root}

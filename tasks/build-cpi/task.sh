#!/bin/bash
set -e

echo "=============================================================================================="
echo "Building BOSH Azure CPI release on ${CPI_SOURCE_BRANCH} branch ..."
echo "=============================================================================================="

export TERM=xterm
cd bosh-cpi-src/
echo "Check ${CPI_SOURCE_BRANCH} branch"
git checkout ${CPI_SOURCE_BRANCH}
git log -3
cpi_release_name="bosh-azure-cpi"
timestamp=`date +%s`
echo "Creating release"
bosh create-release --name ${cpi_release_name} \
 --version ${CPI_SOURCE_BRANCH}-${timestamp} \
 --tarball ../builds/${cpi_release_name}-${CPI_SOURCE_BRANCH}.tgz
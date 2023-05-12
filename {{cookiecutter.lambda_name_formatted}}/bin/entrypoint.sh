#!/bin/bash

set -xeu

# Debug Python environment
python --version
pip --version

# Initialise directories
BASEDIR=/data
cd ${BASEDIR}

# Force Debian to use HTTPS
cp /etc/apt/sources.list /etc/apt/sources.list.bak
sed --in-place 's|http://|https://|g' /etc/apt/sources.list

# Update the package listing, so we know what package exist:
apt-get update

# Install security updates:
apt-get -y upgrade

# Install test requirements
python -m venv "${VENV_NAME}"
source ./"${VENV_NAME}"/bin/activate
pip install --upgrade pip
pip install --requirement "${REQUIREMENTS_FILE}" \
            --platform manylinux2014_x86_64 \
            --target=./${VENV_NAME}/lib/python{{ cookiecutter.python_version }}/site-packages \
            --implementation cp \
            --only-binary=:all:

# Make the binary location specified in --target above, available to PATH
export PATH="$PATH:./${VENV_NAME}/lib/python{{ cookiecutter.python_version }}/site-packages/bin"

exec "$@"

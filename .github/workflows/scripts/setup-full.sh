#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2020 Birger Schacht, 2024 Institute for Common Good Technology
# SPDX-License-Identifier: AGPL-3.0-or-later

set -x
set -e

# Set up and start elasticsearch
curl -s -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.6.1-amd64.deb
sudo dpkg -i --force-confnew elasticsearch-7.6.1-amd64.deb
sudo sed -i.old 's/-Xms1g/-Xms128m/' /etc/elasticsearch/jvm.options
sudo sed -i.old 's/-Xmx1g/-Xmx128m/' /etc/elasticsearch/jvm.options
echo -e '-XX:+DisableExplicitGC\n-Djdk.io.permissionsUseCanonicalPath=true\n-Dlog4j.skipJansi=true\n-server\n' | sudo tee -a /etc/elasticsearch/jvm.options
sudo chown -R elasticsearch:elasticsearch /etc/default/elasticsearch
sudo systemctl start elasticsearch

sudo apt update
if [ $python_version == '3.8' ]; then
	# for pymssql there are no wheels for 3.8 https://github.com/certtools/intelmq/issues/2539
	DEBIAN_FRONTEND="noninteractive" sudo -E apt install -y build-essential freetds-dev libssl-dev libkrb5-dev
fi

# Install the dependencies of all the bots
pip install wheel
for file in intelmq/bots/*/*/REQUIREMENTS.txt; do
	echo $file;
	pip install -r $file;
done

# Test specific dependencies not used for production
for file in intelmq/tests/bots/*/*/REQUIREMENTS.txt; do
	echo $file;
	pip install -r $file;
done

# Setup sudo and install intelmq
sudo sed -i '/^Defaults\tsecure_path.*$/ d' /etc/sudoers
sudo pip install .
sudo intelmqsetup --skip-ownership

# Initialize the postgres database
intelmq_psql_initdb
sed -i 's/events/tests/g' /tmp/initdb.sql
psql -w -v ON_ERROR_STOP=on -d postgresql://intelmq@localhost/intelmq -f /tmp/initdb.sql

# Import the OpenPGP test key
gpg --import intelmq/tests/assets/key-public.pgp

#!/bin/bash
wget http://provisioning.aws.cs-labs.net/testdrive/cloud/fcs_0.23.0_Linux_x86_64_signed.tar.gz
tar -xvzf fcs**.tar.gz
mv fcs_0.23.0_Linux_x86_64 fcs
sudo cp fcs /usr/local/bin/fcs
sudo chmod +x /usr/local/bin/fcs

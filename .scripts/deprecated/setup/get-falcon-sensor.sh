#!/bin/bash
 
sudo mkdir -p /media/`whoami`/dc03
sudo mount -t cifs -o user=bsandoval@youniqueproducts.com //dc03/public /media/`whoami`/dc03
cp /media/`whoami`/dc03/CrowdStrike/Ubuntu/falcon-sensor_4.16.0-6101_amd64.deb ~/Downloads/falcon-sensor_4.16.0-6101_amd64.deb
sudo umount -l /media/`whoami`/dc03
sudo apt update && sudo apt install ~/Downloads/falcon-sensor_4.16.0-6101_amd64.deb
sudo rm ~/Downloads/falcon-sensor_4.16.0-6101_amd64.deb

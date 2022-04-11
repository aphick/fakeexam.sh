#!/bin/bash


URSESSION="$(cat list_of_vms.txt | shuf -n 3 -)"

echo "This script runs through a list of random Vulnhub vms from TJNulls oscp prep blog."
echo "it requires that aria2c be installed and anywhere from 2-20GB free on disk."
echo "it also expects Virtualbox be installed, and a host-only network be configured with the name 'vboxnet0'"
echo "some vms may also need virtualbox-ext-pack to be installed"

if ! command -v aria2c &> /dev/null
then
    echo "aria2c could not be found"
    exit
fi

if ! command -v virtualbox &> /dev/null
then
    echo "Virtualbox could not be found"
    exit
fi

rm .no-peeking

while IFS= read -r line
do 
	curl -s $line | grep -oE '''https.*torrent"''' | sed 's/.$//'  >> .no-peeking
done < <(printf '%s\n' "$URSESSION")

mkdir .seriously-nopeeking
aria2c -i .no-peeking -j 4 --console-log-level=error --dir .seriously-nopeeking --download-result=hide --summary-interval=0 --seed-time=0



for file in .seriously-nopeeking/*
do
	ext="${file##*.}"
	if [ "$ext" != "ova" ] && [ "$ext" != "torrent" ]
	then
		echo "extracting vms"
		7za -y e $file -o.seriously-nopeeking/ &>/dev/null
	fi
done
echo "done extracting"

virtualbox &
a=3
for file in .seriously-nopeeking/*
do
	ext="${file##*.}"
	if [ "$ext" == "ova" ] || [ "$ext" == "ovf" ]
	then
		echo "importing VM $a"
		vboxmanage import --vsys 0 --vmname $a $file &>/dev/null
		vboxmanage modifyvm $a --nic1 hostonly --hostonlyadapter1 vboxnet0
		echo "starting VM $a"
		vboxmanage startvm $a --type headless
		((a+=1))
	fi
done


rm -rf .seriously-nopeeking

echo "Your VMs are up"
echo "subnet: $(ip -4 addr | grep "vboxnet0" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')/24"

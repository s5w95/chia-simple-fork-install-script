#!/bin/bash

#set mode to harvester or node
MODE=harvester
#set node ip only needed on harvester mode
NODE_IP=192.168.9.107
NODE_USER=dev

BASEDIR=$(dirname "$0")
. $BASEDIR/forks.config


if [ $MODE = harvester ]; then
	#download certs from node
	rm ~/blockchain-certs -rf
	scp -r $NODE_USER@$NODE_IP:~/blockchain-certs ~/blockchain-certs
fi

for index in "${!forks[@]}"
do
	fork=${forks[$index]}
	profileAvailable=false

	#check if we need to init the wallet and keys, if there is no log folder it was never started
	if [ -d ~/.${forksProfile[$index]} ]; then
		if [ -d ~/.${forksProfile[$index]}/mainnet/log ]; then
			profileAvailable=true
		fi
	fi

	#check running instances and shutdown	
	if [ -d ~/blockchains/$fork ]; then
		if [ -f ~/blockchains/$fork/activate ]; then
			cd ~/blockchains/$fork/
			. ./activate
			#maybe this is not necessary at all
			$fork stop all
		fi
		
		#we completly remove the fork and reinstall it
		rm ~/blockchains/$fork -rf
	fi
	
	#keep the working dir safe, otherwise git will throw an error if we're still in a deleted folder from steps before
	cd ~/
	
	#reinstall fork
	mkdir ~/blockchains/$fork
	git clone ${forksGit[index]} ~/blockchains/$fork
	
	cd ~/blockchains/$fork/
	chmod 777 install.sh
	#maybe you need to enter sudo passwd here for update
	sh install.sh
	
	#jump into the env
	. ./activate
	
	if [ $MODE = harvester ]; then
		#start init with node certs no keys needed here
		$fork init -c ~/blockchain-certs/$fork/
		
		if [ $profileAvailable = false ] ; then
			for plotDir in "${plotDirs[@]}"
			do
				$fork plots add -d $plotDir
			done
		fi
		
		$fork start harvester
		
		#todo insert node ipp on harvester config.yaml
	else
		#start init
		$fork init
		
		if [ $profileAvailable = false ] ; then
			#add private key manually after you added a new fork, I dont want to set it for security reasons but feel free todo and pipe it
			$fork keys add
			#pipe example for autofill:
			#echo "some key words right here" | $fork keys add
		fi
		
		#start node without timelord
		$fork start harvester farmer node wallet
		
		if [ $profileAvailable = false ] ; then
			#waiting for wallet startup for wallet init, maybe needs adjustment?
			sleep 1m
			echo "S" | $fork wallet show
		fi
		
		if [ -d ~/blockchain-certs ]; then
			rm ~/blockchain-certs/$fork -rf
			mkdir ~/blockchain-certs/$fork
			cp ~/.${forksProfile[$index]}/mainnet/config/ssl/ca/* ~/blockchain-certs/$fork/
		fi
	fi
   
done

#!/bin/bash

BASEDIR=$(dirname "$0")
. $BASEDIR/forks.config

for index in "${!forks[@]}"
do
echo 
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
	
	#send some telegram message
	telegram-send "*$fork* node updated and is now starting" --format markdown
done

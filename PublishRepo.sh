#!/bin/bash
	
# This script is used to create local repository and publish to web.
# When pulished or snapshot or repo is exist, it will be deleted firstly. 
# It supports a directory or a single deb file.

# Input variables 
SNAPSHOT_NAME=$1
DEB_FOLDER=$2

# Constant variables
RELEASE_NAME=xenial
REPO_NAME=in-sec
LOG_SIGN=">>>"

# Check the validition of parameters
if [[ -z "$SNAPSHOT_NAME" || -z "$DEB_FOLDER" ]]; then
	echo -e "\033[31m  Error: too few arguments\033[0m"
	echo -e "\033[31m  Usage: $0 <snapshot> <directory>|<package file.deb>\033[0m"

	exit 1
fi

# Check the exist of <directory>|<package file.deb>
if [[ ! -e "$DEB_FOLDER" ]]; then
	echo -e "\033[31m  Error: '$2' is not exist\033[0m"

	exit 2
fi

# Get Exist publishes
pubs=`aptly publish list | grep publishes`

# Check the program 'aptly' is currently installed
inst=`echo "$pubs" | grep "not installed"`

if [ -n "$inst" ]; then
	echo -e "\033[31mThe program 'aptly' is currently not installed. You can install it by typing:\033[0m"
	echo -e "\033[31mapt installed aptly\033[0m"

	exit 3
fi

# Get the publish of mine
pubs=`aptly publish list | grep $RELEASE_NAME`

# Check my publish is exist
if [ -n "$pubs" ]; then
	name=`echo "$pubs" | awk -F ' ' '{print $2}' | awk -F ']' '{print $1}'`
	name=${name:2:20}

	snap=`echo "$pubs" | awk -F ' ' '{print $6}' | awk -F ']' '{print $1}'`
	snap=${snap:1:20}

	repo=`echo "$pubs" | awk -F ' ' '{print $11}' | awk -F ']' '{print $1}'`
	repo=${repo:1:20}
	
	echo -e "\033[32m$LOG_SIGN 0. Exist '$name' publishes {main: [$snap]: from local repo [$repo]}\033[0m" 

	# Drop exists publish
	echo -e "\033[32m$LOG_SIGN   a. Drop the exist publish '$name' ...\033[0m"
	aptly publish drop $name >/dev/null 2>&1

	# Drop my snapshot if it is exist
	if [ $snap = $SNAPSHOT_NAME ]; then
		echo -e "\033[32m$LOG_SIGN   b. Drop the exist snapshot '$snap' ...\033[0m"
		aptly snapshot drop $snap >/dev/null 2>&1
	fi

	# Drop my repo if it is exist and the parameter is <directory>
	if [[ -d "$DEB_FOLDER" && $repo = $REPO_NAME ]]; then
		echo -e "\033[32m$LOG_SIGN   c. Drop the exist repo '$repo' ...\033[0m"
		aptly repo drop -force $repo >/dev/null 2>&1

		echo -e "\033[32m$LOG_SIGN   d. Cleanup the APT database ...\033[0m"
		aptly db cleanup >/dev/null 2>&1
	fi

	# Print a blank line
	echo -e "\033[32m\033[0m"
fi

# Get the snapshots of mine
list=`aptly snapshot list | grep $SNAPSHOT_NAME`

# Check my snapshot is exist
if [ -n "$list" ]; then
	snap=`echo "$list" | awk -F ' ' '{print $2}' | awk -F ']' '{print $1}'`
	snap=${snap:1:20}

	repo=`echo "$list" | awk -F ' ' '{print $7}' | awk -F ']' '{print $1}'`
	repo=${repo:1:20}
	
	echo -e "\033[32m0. Exist snapshot [$snap] from local repo [$repo]\033[0m" 

	# Drop my snapshot
	echo -e "\033[32m$LOG_SIGN   a. Drop the exist snapshot '$snap' ...\033[0m"
	aptly snapshot drop $snap >/dev/null 2>&1

	# Drop my repo if it is exist and the parameter is <directory>
	if [[ -d "$DEB_FOLDER" && $repo = $REPO_NAME ]]; then
		echo -e "\033[32m$LOG_SIGN   b. Drop the exist repo '$repo' ...\033[0m"
		aptly repo drop -force $repo >/dev/null 2>&1

		echo -e "\033[32m$LOG_SIGN   c. Cleanup the APT database ...\033[0m"
		aptly db cleanup >/dev/null 2>&1
	fi

	# Print a blank line
	echo -e "\033[32m\033[0m"
fi

# Get the repo of mine
list=`aptly repo list | grep $REPO_NAME`

# Check my repository is exist
if [[ -n "$list" && -d "$DEB_FOLDER" ]]; then
	repo=`echo "$list" | awk -F ' ' '{print $2}' | awk -F ']' '{print $1}'`
	repo=${repo:1:20}

	pack=`echo "$list" | awk -F ' ' '{print $4}' | awk -F ')' '{print $1}'`
	
	echo -e "\033[32m$LOG_SIGN 0. Exist repository [$repo] includes $pack packages\033[0m" 

	# Drop my repository
	echo -e "\033[32m$LOG_SIGN   a. Drop the exist repo '$repo' ...\033[0m"
	aptly repo drop -force $repo >/dev/null 2>&1

	echo -e "\033[32m$LOG_SIGN   b. Cleanup the APT database ...\033[0m"
	aptly db cleanup >/dev/null 2>&1

	# Print a blank line
	echo -e "\033[32m\033[0m"
fi

if [ -d "$DEB_FOLDER" ]; then	
	# Create my repository
	echo -e "\033[32m$LOG_SIGN 1. Create repo of '$REPO_NAME' ...\033[0m"
	aptly repo create $REPO_NAME

	# Add local files to the repository
	echo -e "\033[32m\033[0m"
	echo -e "\033[32m$LOG_SIGN   a. Add local files to the repo of '$RPEO_NAME' ...\033[0m"
	aptly repo add $REPO_NAME $DEB_FOLDER
else
	# Add file to the repository
	echo -e "\033[32m$LOG_SIGN 1. Add local file to the repo of '$REPO_NAME' ...\033[0m"

	# Get the name of file.deb
	name=`echo $DEB_FOLDER | awk -F '/' '{print $NF}'`

	# Get the name of package
	pack=`echo $name | awk -F '_' '{print $1}'`

	# When the name of package is invalid
	if [ $name = $pack ]; then
		# Get the name of package from its control infomation
		pack=`dpkg --info $DEB_FOLDER | grep "Package:" | awk -F ' ' '{print $2}'`	
	fi

	# Search repository for package
	pOld=`aptly repo search $REPO_NAME $pack 2>&1 | grep "no results"`

	# Check the exist package
	if [ -n "$pOld" ]; then
		# Add the new package
		echo -e "\033[32m$LOG_SIGN   a. Add package '$pack' to the local repository ...\033[0m"
		aptly repo add $REPO_NAME $DEB_FOLDER | grep $pack
	else
		# Remove the exist package
		echo -e "\033[32m$LOG_SIGN   a. Remove package '$pack' from the local repository ...\033[0m"
		aptly repo remove $REPO_NAME $pack | grep $pack

		# Add the new package
		echo -e "\033[32m$LOG_SIGN   b. Add package '$pack' to the local repository ...\033[0m"
		aptly repo add $REPO_NAME $DEB_FOLDER | grep $pack
	fi
fi

# Print a blank line
echo -e "\033[32m\033[0m"

# Create my snapshot
echo -e "\033[32m$LOG_SIGN 2. Create snapshot of '$SNAPSHOT_NAME' ...\033[0m"
aptly snapshot create $SNAPSHOT_NAME from repo $REPO_NAME

# Print a blank line
echo -e "\033[32m\033[0m"

# Publish my snapshot
echo -e "\033[32m$LOG_SIGN 3. Publish the snapshot of '$SNAPSHOT_NAME' by '$RELEASE_NAME' ...\033[0m"
aptly publish snapshot -distribution="$RELEASE_NAME" --skip-signing $SNAPSHOT_NAME

# Check the port 8080 is not used
port=`lsof -i:8080 | grep LISTEN`

if [ -z "$port" ]; then
	# Print a blank line
	echo -e "\033[32m\033[0m"

	echo -e "\033[32m$LOG_SIGN 4. Access the publish from the following address ...\033[0m"
	echo -e "\033[32m    http://localhost:8080\033[0m"
	aptly serve >/dev/null 2>&1 &
fi

# Skip error: can't open database: resource temporarily unavailable
sleep 2

echo -e "\033[32m==============================================================================\033[0m"
echo -e "\033[32mYour packages have been published successfully.\033[0m"
echo -e "\033[32m`aptly snapshot show $SNAPSHOT_NAME`\033[0m"

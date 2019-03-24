#!/bin/bash
# This script is used to backup pictures from digital still cam storage to photo repository 
# Photo repository is organized using two level folder : 
# * folder of the year on 4 digit (YYYY) 
# * subfolder name according to date (YYYY_MM_DD) followed by underscore 
# 
# Copy require a start date YYYY-MM-DD, by default date is set to the last date found in folder repository tree
# each photo is analysed using exiftool and stored into a temporary folder, and then copied into repository (exif date is used)
# each photo is renamed according to its exif date pyyyymmdd_hhmmss.jpg
# only photos took after the date of last directory in repository are managed
#
# same process is done on video files

# current script directory
script_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# check arg
if [[ $# -lt 2 ]]
then 
	echo "photo repository path and source path must be provided"
	echo "usage : $0 [-i repository/path] || repository/path path/to/photos/source"
	echo "-i option install gnome-nautilus autoloader update to propose photocopying to repository config files at usb insertion"
	exit 1
fi

if [[ "$1" == "-i" ]]
then
	echo "installation step ... $0 $1 $2 "
	# image repository (ie : /home/shared/Images/Private) 
	imgRepository=$2

	if [ ! -e $imgRepository ]
	then
		echo "Image repository folder $imgRepository not found, try to create it "
		mkdir -p $imgRepository
	fi


	#install config files 
	if [ ! -e ~/.local/share/applications ]
	then 
		mkdir -p ~/.local/share/applications
	fi 

	replacement="s|{{repository\}}|$2|g"
	replacement2="s|{{execpath\}}|$script_folder|g"
	sed $replacement $script_folder/photoLoader.desktop | sed $replacement2 >~/.local/share/applications/photoLoader.desktop

	res=$(grep "x-content/image"  ~/.local/share/applications/mimeapps.list)
	if [ $? -ne 0 ]
	then
		#case not present : create it
		echo "create mime type"
		echo "x-content/image=photoLoader.desktop">>~/.local/share/applications/mimeapps.list
	fi

	res=$(grep "x-content/image"  ~/.local/share/applications/mimeapps.list | grep "photoLoader")
	if [ $? -ne 0 ]
	then
		#case not declared : addit to list
		#res=$(grep "x-content/image"  ~/.local/share/applications/mimeapps.list)
		res="$res;photoLoader.desktop"
		echo "declare mime type" $res
		grep -v "x-content/image" ~/.local/share/applications/mimeapps.list> ~/.local/share/applications/tmp.txt
		echo $res>>~/.local/share/applications/tmp.txt
		cat ~/.local/share/applications/tmp.txt>~/.local/share/applications/mimeapps.list
		rm -f ~/.local/share/applications/tmp.txt
	fi

	echo "Installation done. Press any key"
	read a

# else if test [[ $1=="shift" ]]
# shiftValue = prompt/input shift value
# exiftool "-AllDates+=$shiftValue" $folder
#

else
	echo "copying photos..."
	# image repository 
	imgRepository=$1 #/home/shared/Images/Prive

	# file marker for date
	startDateMarker=/tmp/startDateMarker

	# temporary files used to receive photos and video from source before being managed and dispatched by exiftool
	tempPDest=$imgRepository/tempPDest
	tempVDest=$imgRepository/tempVDest


	# trap script end and Ctrl+C
	trap "{ rm -f $startDateMarker; rmdir --ignore-fail-on-non-empty $tempPDest/; rmdir --ignore-fail-on-non-empty $tempVDest/; exit 255; }" EXIT INT

	# get starting date : the last uploaded dir
	res=$(ls $imgRepository/????/* -drv)
	if [ "$?" -ne "0" ];
	then
		startDate="1900-01-01"
	else
		lastDir=$(ls $imgRepository/????/* -drv | head -n1)
		startDate=$(basename $lastDir)
		startDate=${startDate:0:4}-${startDate:4:2}-${startDate:6:2}
		read -p "Start photo loading at date $startDate, input another date or not and press [ENTER] " -e input
		if [[ "$input" != "" ]]
		then
			startDate=$input
		fi
	fi

	# produce empty file as start date marker
	touch --date $startDate $startDateMarker
	chmod 777 $startDateMarker


	# Make temp dir if necessary and clear them
	source=$2
	mkdir -p $tempPDest/
	mkdir -p $tempVDest/
	#rm -rf $tempPDest/*
	#rm -rf $tempVDest/*

	#find and copy newer photo files to temp directory
	echo "Copy photos files newer than $startDate from $source to $tempPDest"
	find $source -maxdepth 5 -type f -iregex "^.*\.\(jpg\|jpeg\|gif\|png\|tif\)$" -newer $startDateMarker -exec cp --preserve {} $tempPDest/ \;

	echo "Move photos from $tempPDest to repository $imgRepository"
	exiftool -d $imgRepository/%Y/%Y%m%d_/p%Y%m%d_%H%M%S%%-c.%%le "-filename<DateTimeOriginal" $tempPDest/ 
	exiftool -d $imgRepository/%Y/%Y%m%d_/p%Y%m%d_%H%M%S%%-c.%%le "-filename<CreateDate" $tempPDest/ 
	exiftool -d $imgRepository/%Y/%Y%m%d_/p%Y%m%d_%H%M%S%%-c.%%le "-filename<FileModifyDate" $tempPDest/ 


	#find and copy newer videos files to temp directory
	echo "Copy videos files newer than $startDate from $source to $tempVDest"
	find $source -maxdepth 6 -type f -iregex "^.*\.\(mov\|mpg\|mpeg\|mts\|avi\|divx\|flv\|m4a\|mp4\|ogg\|wmv\)$" -newer $startDateMarker -exec cp --preserve {} $tempVDest/ \;

	echo "Move videos from $tempVDest to repository $imgRepository"
	extensions="-ext mov -ext mpg -ext mpeg -ext mts -ext avi -ext divx -ext flv -ext m4a -ext mp4 -ext ogg -ext wmv "
	exiftool $extensions -d $imgRepository/%Y/%Y%m%d_/m%Y%m%d_%H%M%S%%-c.%%le "-filename<DateTimeOriginal" $tempVDest/ 
	exiftool $extensions -d $imgRepository/%Y/%Y%m%d_/m%Y%m%d_%H%M%S%%-c.%%le "-filename<CreateDate" $tempVDest/ 
	exiftool $extensions -d $imgRepository/%Y/%Y%m%d_/m%Y%m%d_%H%M%S%%-c.%%le "-filename<FileModifyDate" $tempVDest/ 

	#remove temporary directory if empty
	rmdir --ignore-fail-on-non-empty $tempPDest/
	if [ "$?" -ne "0" ]; then 
		echo "Some pictures are left into $tempPDest : you must do it by hands"
		nautilus $tempPDest/
	fi
	rmdir --ignore-fail-on-non-empty $tempVDest/
	if [ "$?" -ne "0" ]; then 
		echo "Some videos are left into $tempVDest : you must do it by hands"
		nautilus $tempVDest/
	fi

	echo "Photos uploaded. Press any key"
	read a
fi


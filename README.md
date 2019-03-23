# photoloader

## Goal
This script is used to backup pictures from digital still cam, or other device to a local folder photo repository 

## Local photo repository

Photo repository folder is organized using two level folder : 
* a first folder named according to the year of the photo/video, on 4 digit (YYYY) 
* a subfolder named according to "exif date" of the photo/video, YYYY_MM_DD followed by an underscore 

## Main process

* Copy require a start date YYYY-MM-DD, by default date is set to the last date found in folder repository tree
* each photo/video is analysed using exiftool and stored into a temporary folder, and then move into the repository (exif date is used)
* each photo is renamed according to its exif date pyyyymmdd_hhmmss.jpg
* each video is renamed according to its exif date myyyymmdd_hhmmss.jpg
* only photos took after the date of last directory in repository are managed



#!/bin/bash

for (( i=1; i<=$1; i++))
do
        convert -background black -fill white  -font Helvetica \
                -size 160x144  -pointsize 50  -gravity center \
                label:$i $i.bmp
done

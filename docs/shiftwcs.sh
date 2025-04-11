 #! /bin/sh

# 2018-Oct-01 - Andrew Stephens, beta version
# 2018-Oct-03 - astephens, use formatted output to preserve floats

function usage () {
  echo " "
  echo "NAME"
  echo "       shiftwcs.sh - shift an instrument WCS"
  echo " "
  echo "SYNOPSIS"
  echo "       shiftwcs.sh [-p] wcsfile xshift yshift"
  echo " "
  echo "DESCRIPTION"
  echo "       Make a backup of the supplied WCS file by appending it's last modification date,"
  echo "       then shift the WCS file in X and Y.  By default the supplied X and Y shifts are"
  echo "       assumed to be in arcseconds.  One may give offsets in pixels with the -p option."
  echo "       Note that shifts in arcseconds are in the TELESCOPE reference frame, and shifts"
  echo "       in pixels are in the DETECTOR reference frame.  For this reason it may be more"
  echo "       intuitive to apply shifts in pixels, although shifts due to hotspot changes may"
  echo "       be easier to apply in arcseconds."
  echo " "
  echo "OPTIONS"
  echo "       -p : Apply shifts in pixels instead of arcseconds"
  echo " "
  echo "VERSION"
  echo "       2018-Oct-03"
  echo " "
  exit
}

if [ ${#} = 0 ] ; then usage ; fi

arcsec=true

while [ $# -gt 0 ] ; do
  case "$1" in
    -p)  arcsec=false;;
    -*)  usage;;
     *)  break;; # terminate when the loop runs out of options
  esac
  shift
done

wcsfile=$1
xshift=$2
yshift=$3

if test -z "$wcsfile" || test -z "$xshift" || test -z "$yshift"; then usage ; fi

backup=$wcsfile.`stat --printf=%y $wcsfile | awk '{print $1"_"substr($2,0,8)}'`
echo "Moving $wcsfile to $backup" 
mv -i $wcsfile $backup

# WCS files contain 4 columns: X and Y image coordinates (pix) and X and Y instrument offsets (mm)
scale=1.61144 # arcseconds per millimeter
if [ "$arcsec" = true ] ; then # apply scaled shifts to the instrument offsets in columns 3 & 4:
    echo "Shifting by dx=$xshift and dy=$yshift arcseconds"
    awk -v dx=$xshift -v dy=$yshift -v s=$scale '{printf "%9.2f %9.2f %9.4f %9.4f\n", $1, $2, $3+dx/s, $4+dy/s}' $backup > $wcsfile
else # apply shifts to the image coordinates in columns 1 & 2:
    echo "Shifting by dx=$xshift and dy=$yshift pixels"
    awk -v dx=$xshift -v dy=$yshift '{printf "%9.2f %9.2f %9.4f %9.4f\n", $1+dx, $2+dy, $3, $4}' $backup > $wcsfile
fi
             
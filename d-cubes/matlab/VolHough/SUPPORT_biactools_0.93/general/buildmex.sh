#!/bin/sh
#
# Build BIAC MATLAB mex files
#
# NOTE: Assumes UNIX
#

# Initialize variables to default values
LIBXML2DIR=/usr
MATLABVER=6.5

#########################
# Function: disp_usage()
#########################
disp_usage () {
  echo 'Usage: buildmex [OPTIONS]'
  echo 'Build BIAC MATLAB MEX libraries'
  echo ''
  echo 'Options:'
  echo "  --matlabver version (default = $MATLABVER)"
  echo "  --libxml2dir DIR  (default = $LIBXML2DIR) [DIR/libxml2/include]"
  echo ''
}

#########################
# Main
#########################
# Grab input and set defaults.

# Check number of inputs
if [ $# -lt 0 -o $# -gt 5 ]; then
  disp_usage
  exit 1
fi

# Extract configuration options from command line
status="OK"
while [ "$status" = "OK" -a $# -gt 0 ]; do
  case "$1" in
    --libxml2dir)
       # libxml2 directory
       if [ $# -eq 1 ]; then
         echo 'buildmex: Missing directory after -libxml2dir'
         status=""
       else
         shift
         LIBXML2DIR=$1
       fi
       ;;
    --matlabver)
       # MATLAB version
       if [ $# -eq 1 ]; then
         echo 'buildmex: Missing MATLAB version after --matlabver'
         status=""
       else
         shift
         MATLABVER=$1
       fi
       ;;
    "--help" | "-h")
       # Usage
       disp_usage
       exit 1
       ;;
     *)
       echo "buildmex: Unknown option $1"
       status=""
    esac
  shift
done
# Check for errors
if [ "$status" != "OK" ]; then
  echo 'Try `buildmex --help` for more information'
  exit 1
fi

# Get major and minor MATLAB versions
MATLABMAJOR=`perl -e "\"$MATLABVER\" =~ /^(\d+)/; print \\\$1;"`;
MATLABMINOR=`perl -e "\"$MATLABVER\" =~ /^\d+(\.(\d+))?/; print \\\$2;"`
if [ -z "$MATLABMAJOR" -o -z "$MATLABMINOR" ]; then
  echo "Invalid MATLAB version string ($MATLABVER)"
  echo "Must specify major and minor version (x.x)"
  exit 1
fi

# Build functions with no additional includes
for i in minmax.c scaled2rgb.c trilinear.c; do
  echo "Building $i"
  echo "  mex $i"
  mex $i
done

#echo "Building cellfun2"
#if [ $MATLABMAJOR -gt 6 -o \( $MATLABMAJOR -eq 6 -a $MATLABMINOR -ge 5 \) ]; then
#  echo "  mex -output cellfun2LT cellfun2.c"
#  mex -output cellfun2LT cellfun2.c
#else
#  # Need to built with no logical type support before MATLAB 6.5
#  echo "  mex -DNO_LOGICAL_TYPE -output cellfun2NLT cellfun2.c"
#  mex -DNO_LOGICAL_TYPE -output cellfun2NLT cellfun2.c 
#fi

# Build functions with library dependencies
echo "Building readxml"
echo "  mex -I$LIBXML2DIR/include/libxml2 -L$LIBXML2DIR/lib -lxml2 -lz readxml.c"
mex -I$LIBXML2DIR/include/libxml2 -L$LIBXML2DIR/lib -lxml2 -lz readxml.c

echo "Buildng writexml"
echo "  mex -I$LIBXML2DIR/include/libxml2 -L$LIBXML2DIR/lib -lxml2 -lz writexml.c"
mex -I$LIBXML2DIR/include/libxml2 -L$LIBXML2DIR/lib -lxml2 -lz writexml.c

echo "Done building mex files"

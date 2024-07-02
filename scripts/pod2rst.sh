#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: ./pod2rst.sh <script.pl>"
    exit 1
fi

if [ ! -f $1 ]; then
    echo "Perl script '$1' does not exist"
    exit 1
fi

scriptpath=$(dirname $1)
scriptname=$(basename $1 | sed -e 's/.pl$//g')
docpath="docs/source/pipelines$(echo $scriptpath | sed -e 's/src//g' )/"

if [ ! -d $docpath ]; then
    echo "Documentation directory '$docpath' for script $scriptname does not exist"
    exit 1
fi

# capture usage and indent it all so it is properly rendered as formatted text in reST
usage=$(perl $1 --help | sed -e 's/\(^.*\)/\t\1/g')

# generate HTML from POD and convert to reST
rstpod=$(pod2html --infile $1 --noindex | pandoc --read html --write rst | sed -E "s/^\.\.\ \_.*://g")

underline=$(python -c "print('=' * len('$scriptname'))")

if [[ -z $rstpod ]] &&  [[ -z $usage ]]; then
    echo "$1 has no pod text and no usage not creating documentation file"
    exit
fi

cat << EOD > "$docpath/$scriptname.rst"
$scriptname
$underline
EOD

if [[ ! -z $usage ]]; then
    cat << EOD >> "$docpath/$scriptname.rst"
Usage
-----

::

$usage
EOD
fi

if [[ ! -z $rstpod ]]; then
cat << EOD >> "$docpath/$scriptname.rst"

Functions
---------
$rstpod
EOD
fi
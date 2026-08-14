#!/usr/bin/env python

"""
merge_shortbred.py
==================
Please type "./merge_shortbred.py -h" for usage help

Authors:
  Eric A. Franzosa (franzosa@hsph.harvard.edu)

Copyright (c) 2016 Harvard T. H. Chan School of Public Health

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

from __future__ import print_function # PYTHON 2.7+ REQUIRED 
import os
import sys
import argparse
import csv
import re

#-------------------------------------------------------------------------------
# description
#-------------------------------------------------------------------------------

description = """
DESCRIPTION:

  This is a python program for integrating ShortBRED output with 
  a sequence similarity network. It is a component of the 
  Chemically-Guided Functional Profiling workflow described in:

  <citation>

BASIC OPERATION:

  ./merge_shortbred.py sample1.txt sample2.txt ... sampleN.txt --clusters-file cgfp-clusters.txt

ARGUMENTS:
"""

#-------------------------------------------------------------------------------
# constants
#-------------------------------------------------------------------------------

c_na = "#N/A"
c_epsilon = 1e-20
c_default_genome_size = 5e6
c_delim = "|"

#-------------------------------------------------------------------------------
# arguments
#-------------------------------------------------------------------------------

def get_args( ):
    """ master argument parser """
    parser = argparse.ArgumentParser( 
        description=description, 
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument( 
        "shortbred_outputs",
        type=str,
        metavar="<path(s) to shortbred outputs>",
        nargs="+",
        help="One or more output files from ShortBRED quantify",
    )
    parser.add_argument( 
        "-c", "--clusters-file",
        required=True,
        metavar="<path>",
        type=str,
        help="Clusters file created from parse_ssn.py",
    )
    parser.add_argument( 
        "-p", "--protein-abundance-file",
        type=str,
        metavar="<path>",
        default="protein-abundance.txt",
        help="Path to output file 1: abundance of individual proteins",
    )
    parser.add_argument( 
        "-C", "--cluster-abundance-file",
        type=str,
        metavar="<path>",
        default="cluster-abundance.txt",
        help="Path to output file 2: abundance of SSN clusters",
    )
    parser.add_argument( 
        "-n", "--sum-normalize",
        action="store_true",
        help="Sum-normalize the output files (force columns sums = 1.0)",
    )
    parser.add_argument( 
        "-g", "--genome-size-normalize",
        type=str,
        default=None,
        metavar="<path>",
        help="Perform genome-size normalization (requires mapping from sample ID to average genome size)",
    )
    args = parser.parse_args()
    return args

#-------------------------------------------------------------------------------
# utilities and file i/o
#-------------------------------------------------------------------------------

def try_open( path, *args ):
    """ open and fail gracefully """
    fh = None
    try:
        fh = open( path, *args )
    except:
        sys.exit( "Unable to open: %s, please check the path" % ( path ) )
    return fh

def read_lines( fh, headers=True, dialect="excel" ):
    for row in csv.reader( fh, dialect=dialect ):
        if headers:
            headers=False
        else:
            yield row

def read_dict( fh, kdex=0, vdex=1, multivalue=False,
               headers=False, func=None, dialect="excel" ):
    d = {}
    for row in read_lines( fh, headers=headers, dialect=dialect ):
        key = row[kdex]
        val = row[vdex]
        val = val if func is None else func( val )
        if not multivalue:
            d[key] = val
        else:
            d.setdefault( key, [] ).append( val )
    return d

def strat_sort( k ):
    key = k.split( c_delim )
    if key[0] == c_na:
        key[0] = 0
    elif "S" not in key[0]:
        key[0] = int( key[0] )
    else:
        key[0] = int( key[0][1:] ) + 1e9 # hack to put singletons at the end
    #key[0] = 0 if key[0] == c_na else int( key[0] )
    return key

def write_nested_dict( dd, path, missing=0 ):
    colheads = sorted( dd )
    rowheads = set( )
    for c, cdict in dd.items( ):
        rowheads.update( cdict )
    print(rowheads)
    rowheads = sorted( rowheads, key=lambda x: strat_sort( x ) )
    with try_open( path, "w" ) as fh:
        print( "\t".join( ["Feature \ Sample"] + colheads ), file=fh )
        for r in rowheads:
            outline = []
            for c in colheads:
                outline.append( dd[c].get( r, missing ) )
            outline = [r] + ["%.6g" % k for k in outline]
            print( "\t".join( outline ), file=fh )

def clean_acc( acc ):
    if re.search( "^(>)?[a-z]{2}\|", acc ):
        acc = acc.split( c_delim )[1]
    return acc

#-------------------------------------------------------------------------------
# main
#-------------------------------------------------------------------------------

def main( ):
    args = get_args()
    # load cluster mapping
    cmap = read_dict( try_open( args.clusters_file ), kdex=1, vdex=0, dialect="excel-tab" )
    # load shortbred outputs
    dd = {}
    for p in args.shortbred_outputs:
        name = os.path.split( p )[1].split( "." )[0]
        sdict = read_dict( try_open( p ), headers=True,
                           func=float, dialect="excel-tab" )
        # rebuild dict with clean acc
        sdict = {clean_acc( k ): v for k, v in sdict.items( )}
        # update keys with cluster numbers
        sdict = {c_delim.join( [cmap.get( k, c_na ), k] ): v for k, v in sdict.items( )}
        dd[name] = sdict
    # genome-size-normalize?
    if args.genome_size_normalize is not None:
        sizes = read_dict( try_open( args.genome_size_normalize ),
                           func=float, dialect="excel-tab" )
        for name, sdict in dd.items( ):
            if name in sizes:
                ags = sizes[name]
            else:
                ags = c_default_genome_size
                print( "Missing genome size information for sample:",
                       name, file=sys.stderr )
            # approximation for CPG normalization from RPKM (v) units
            dd[name] = {k: v * ags * 1e-9 for k, v in sdict.items( )}
    # sum-normalize?
    if args.sum_normalize:
        for name, sdict in dd.items( ):
            total = sum( sdict.values( ) )
            if total > 0.0:
                dd[name] = {k: v / total for k, v in sdict.items( )}
            else:
                dd[name] = {k: 0 for k, v in sdict.items( )}
    # write out the proteins file
    write_nested_dict( dd, args.protein_abundance_file )
    # collapse proteins to clusters
    for name, sdict in dd.items( ):
        cdict = {}
        for k, v in sdict.items( ):
            cluster, protein = k.split( c_delim )
            cdict[cluster] = cdict.get( cluster, 0 ) + v
        dd[name] = cdict
    # write out the clusters file
    write_nested_dict( dd, args.cluster_abundance_file )
            
if __name__ == "__main__":
    main( )

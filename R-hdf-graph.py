#!/usr/bin/env python

import h5py
import collections
import math
import argparse
import re

parser=argparse.ArgumentParser(description='create hdf5 file for creating quartile plots of blast out put in R')
parser.add_argument('-f','--hdf5',dest='hdf',help='path to the hdf5 file', type=str, required=True)
parser.add_argument('-b','--blast',dest='blast',help='path to the 1.out blast file output', type=file, required=True)
parser.add_argument('-c','--chunksize',dest='chunksize',help='size of hdf5 chunks to process', default=10000, type=int)
parser.add_argument('-i','--incfrac',dest='incfrac',help='center fraction of all sequences to keep',default=0.99, type=float)
parser.add_argument('-a','--fasta',dest='fasta',help='path of the fasta file',type=file, required=True)
args=parser.parse_args()

hdfFile = h5py.File(args.hdf, "w")
blastIn=args.blast
chunksize=args.chunksize
incfrac=args.incfrac

dataSetHash=collections.defaultdict(dict)
evalueHisto=[]
size=0
maxy=0

#read the blast output and populate data structure
#there is a bug in h5py that prevents us form adding data to the hdf as we go
print("read blast")
for line in blastIn:
  #print(line.rstrip())
  lineary=line.rstrip().split('\t')
  evalue=int(-(math.log(int(lineary[5])*int(lineary[6]))/math.log(10))+float(lineary[4])*math.log(2)/math.log(10))
  try:
    dataSetHash['align'][evalue]
  except:
    dataSetHash['align'][evalue]=[]
    dataSetHash['perid'][evalue]=[]
    evalueHisto.extend([0]*(evalue-len(evalueHisto)+1))
  dataSetHash['align'][evalue].append(int(lineary[3]))
  dataSetHash['perid'][evalue].append(float(lineary[2]))
  evalueHisto[evalue]+=1
  size += 1
  if int(lineary[3])>maxy:
    maxy=int(lineary[3])

#print(evalueHisto)
print("length of histogram is %s" % len(evalueHisto))
#how many sequences are we trimming off each end
print("find sequence to remove")
chopnumber=int((size-int(size*incfrac))/2)
print("removing %s of %s sequences from each end" % (chopnumber, size))

#find sequences to remove from head
print("find values to remove from head")
tmpcount=0
evalRemove=[]
for key in sorted(dataSetHash['align'].keys()):
  tmpcount+=len(dataSetHash['align'][key])
  if tmpcount < chopnumber:
    print("head remove %s" % key)
    evalRemove.append(key)

#find sequences to remove from tail
print("find values to remove from tail")
tmpcount=0
for key in sorted(dataSetHash['align'].keys(), reverse=True):
  tmpcount+=len(dataSetHash['align'][key])
  if tmpcount < chopnumber:
    print("tail remove %s" % key)
    evalRemove.append(key)

#remove values from data structure
for key in evalRemove:
  print("remove %s" % key)
  del dataSetHash['align'][key]
  del dataSetHash['perid'][key]



#ensure datasets exist for all numbers from start to end (will cause R to crash)
print("ensure existance from head to tail")
start=sorted(dataSetHash['align'].keys())[0]
end=sorted(dataSetHash['align'].keys())[len(dataSetHash['align'].keys())-1]
print("checking from %s to %s" % (start,end))
for key in range(start, end):
  try:
    dataSetHash['align'][key]
  except:
    print("evalue %s was missing" % key)
    dataSetHash['align'][key]=[]
    dataSetHash['perid'][key]=[]

#write out the data structure to the hdf5 file
print("write out start, stop, and max alignment length")
hdfFile.create_dataset('/stats/start',(1,1),maxshape=(1,1),chunks=(1,1),dtype=int,data=start)
hdfFile.create_dataset('/stats/stop',(1,1),maxshape=(1,1),chunks=(1,1),dtype=int,data=end)
hdfFile.create_dataset('/stats/maxy',(1,1),maxshape=(1,1),chunks=(1,1),dtype=int,data=maxy)
print("write quartile hdf data from head to tail")
for key in dataSetHash['align']:
  hdfFile.create_dataset('/align/'+str(key),(len(dataSetHash['align'][key]),1),maxshape=(None,1),chunks=(chunksize/2,1),dtype=int,data=dataSetHash['align'][key])
  hdfFile.create_dataset('/perid/'+str(key),(len(dataSetHash['perid'][key]),1),maxshape=(None,1),chunks=(chunksize/2,1),dtype=float,data=dataSetHash['perid'][key])

#fix the data for the evalue histogram
print("size of histo is %s - %s" % (chopnumber, (len(evalueHisto)-chopnumber)))
evalueHisto=evalueHisto[start:end]

print("write out evalue histogram data to hdf file")
print(evalueHisto)
hdfFile.create_dataset('/edgehisto',(len(evalueHisto),1),maxshape=(None,None),chunks=(chunksize/2,1),dtype=int,data=evalueHisto)

#process data necessary for length histogram
print("reading sequences.fa for length histogram")
lengthAry=[]
fastaLen=0
fastaNum=0
for line in args.fasta:
  if(re.match('\A>',line)):
    fastaNum+=1
    if(fastaLen !=0):
      try:
        lengthAry[fastaLen]
      except:
        if len(lengthAry) < fastaLen+1:
          lengthAry.extend([0]*(fastaLen-len(lengthAry)+1))
        #print("length is %s" % fastaLen)
        #print("array size is %s" % len(lengthAry))
        lengthAry[fastaLen]=1
      else:
        lengthAry[fastaLen]+=1
    fastaLen=0
  else:
    fastaLen+=len(line.rstrip())

try:
  lengthAry[fastaLen]
except:
  lengthAry[fastaLen]=1
else:
  lengthAry[fastaLen]+=1

lenstart=0
lenstop=0
counter=0
chopnumber=int((1-incfrac)*fastaNum)
#print("chopnumber is %s" % chopnumber)
for i in lengthAry:
  if counter>chopnumber:
    print("start at %s" % lenstart)
    break
  else:
    counter+=i
    lenstart+=1

counter=0
lenstop=len(lengthAry)
for i in reversed(lengthAry):
  if counter>chopnumber:
    print("stop at %s" % lenstop)
    break
  else:
    counter+=i
    lenstop-=1

print("start is %s, stop is %s" % (lenstart,lenstop))
lengthAry=lengthAry[lenstart:lenstop]

lenmax=0
for i in lengthAry:
  if lenmax<i:
    lenmax=i

print("Write length histogram data to hdfFile")

hdfFile.create_dataset('/lenhisto',(len(lengthAry),1),maxshape=(None,None),chunks=(chunksize/2,1),dtype=int,data=lengthAry)
hdfFile.create_dataset('/stats/lenstart',(1,1),maxshape=(1,1),chunks=(1,1),dtype=int,data=lenstart)
hdfFile.create_dataset('/stats/lenstop',(1,1),maxshape=(1,1),chunks=(1,1),dtype=int,data=lenstop)
hdfFile.create_dataset('/stats/lenmax',(1,1),maxshape=(1,1),chunks=(1,1),dtype=int,data=lenmax)

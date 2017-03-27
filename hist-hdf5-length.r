library("rhdf5")

args <- commandArgs(trailingOnly = TRUE)
hdffile=args[1]
newdata=h5read(hdffile,"/lenhisto")
start<-h5read(hdffile,"/stats/lenstart")
stop<-h5read(hdffile,"/stats/lenstop")
maxy<-h5read(hdffile,"/stats/lenmax")

start=start[1][1]
stop=stop[1][1]
maxy=maxy[1][1]
#data=read.delim(args[1], header=FALSE, sep="\t", check.names = FALSE)
#data2=t(data [, -1])
#colnames(data2)=data[ ,1]
colnames(newdata)=seq(start,stop-1)
png(args[2], width=1800, height=900);
par(mar=c(4,4,4,4))
barplot(newdata, main = "Number of Sequences at Each Length", ylab = "Number of Sequences", xlab = "Length", col = "red", border = "blue")
dev.off()
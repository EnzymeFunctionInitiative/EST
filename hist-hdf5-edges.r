library("rhdf5")

args <- commandArgs(trailingOnly = TRUE)
hdffile=args[1]
newdata=h5read(hdffile,"/edgehisto")
start<-h5read(hdffile,"/stats/start")
stop<-h5read(hdffile,"/stats/stop")

start=start[1][1]
stop=stop[1][1]

colnames(newdata)=seq(start,stop-1)
png(args[2], width=1800, height=900);
par(mar=c(4,4,4,4))
barplot(newdata, main = "Number of edges at score", ylab = "Number of Edges", xlab = "Score", col = "red", border = "blue")
dev.off()
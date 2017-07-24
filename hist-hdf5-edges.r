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

jobnum = ""
if (length(args) > 2) {
    jobnum = paste(" for Job ID ", args[3])
}

barplot(newdata, main = paste("Number of edges at score", jobnum), ylab = "Number of Edges", xlab = "Score", col = "red", border = "blue")
dev.off()

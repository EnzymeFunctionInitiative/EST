library("rhdf5")

args <- commandArgs(trailingOnly = TRUE)
hdffile=args[1]
pngfile=args[2]
start<-h5read(hdffile,"/stats/start")
stop<-h5read(hdffile,"/stats/stop")
maxy<-h5read(hdffile,"/stats/maxy")

start=start[1][1]
stop=stop[1][1]
maxy=maxy[1][1]



print(paste(start,",",stop,",",maxy))
png(pngfile, width=2000, height=900)

newdata=t(rep(NA,stop))

boxplot(newdata,  main = "Alignment Length vs Alignment Score", ylab = "Alignment Length", xlab = "Alignment Score",ylim=range(0,maxy))
for (i in 1:(stop-start+1)){
  key=i+start-1
  print(paste0("/align/",key))
#so this is an array,has to be rotated
  newdata=t(h5read(hdffile,paste0("/align/",key)))
  #str(newdata)
  boxplot(newdata,col = "red", border = "blue",  add = TRUE , xaxt = "n", at=key, range = 0)
  rm(newdata)
  gc()
}
dev.off()

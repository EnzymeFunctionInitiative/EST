args <- commandArgs(trailingOnly = TRUE)
datafiles=list.files(path = args[1], pattern = "align")
first=args[3]
last=args[4]
maxalign=as.integer(args[5])
print(paste("range",first,last))
data=t(rep(NA,length(datafiles)))
colnames(data)<-first:last
png(args[2], width=2000, height=900);
print(maxalign)
boxplot(data,  main = "Alignment Length vs Alignment Score", ylab = "Alignment Length", xlab = "Alignment Score",ylim=range(0,maxalign))
for (i in 1:length(datafiles)){
  fullpath=paste(args[1],"/",datafiles[i],sep='')
  print(fullpath)
  data=read.table(fullpath, header=TRUE, sep="\t", check.names = FALSE)
  str(data)
  boxplot(data,col = "red", border = "blue",  add = TRUE , xaxt = "n", at=i, range = 0)
  rm(data)
  gc()
}
dev.off()
#data=read.delim(args[1], header=TRUE, sep="\t", check.names = FALSE)
#png(args[2], width=1800, height=900);
#par(mar=c(4,4,4,4))
#boxplot(data, main = "Alignment Length vs Alignment Score", ylab = "Alignment Length", xlab = "Alignment Score", col = "red", border = "blue", range = 0)
#dev.off()

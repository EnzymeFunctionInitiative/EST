args <- commandArgs(trailingOnly = TRUE)
png(args[2], width=2000, height=900);
#par(mar=c(4,4,4,4))
datafiles=list.files(path = args[1], pattern = "perid")
first=args[3]
last=args[4]
print(paste("range",first,last))
data=t(rep(NA,length(datafiles)))
colnames(data)<-first:last
boxplot(data,  main = "Percent Identity vs Alignment Score", ylab = "Percent Identity", xlab = "Alignment Score",ylim=range(0,100))
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
args <- commandArgs(trailingOnly = TRUE)
data=read.delim(args[1], header=FALSE, sep="\t", check.names = FALSE)
data2=t(data [, -1])
colnames(data2)=data[ ,1]
png(args[2], width=1800, height=900);
par(mar=c(4,4,4,4))
barplot(data2, main = "Number of Sequences at Each Length", ylab = "Number of Sequences", xlab = "Length", col = "red", border = "blue")
dev.off()
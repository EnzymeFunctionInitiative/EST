data=read.delim("length.tab", header=TRUE, sep="\t", check.names = FALSE)
png("r_length_histogram.png", width=1800, height=900);
par(mar=c(4,4,4,4))
hist(data, main = "Percent Identity vs Alignment Score", ylab = "Percent Identity", xlab = "Alignment Score", col = "red", border = "blue", range = 0)
dev.off()
library("rhdf5")

args <- commandArgs(trailingOnly = TRUE)
type = args[1]
arg_offset = 0
data_file = ""

data_file = args[2]
png_file = args[3]
data_dir = ""
start = 0
stop = 0

if (type == "hdf5") {
    plot_data = h5read(data_file,"/lenhisto")
    start <- h5read(data_file,"/stats/lenstart")
    stop <- h5read(data_file,"/stats/lenstop")
    maxy <- h5read(data_file,"/stats/lenmax")

    start = start[1][1]
    stop = stop[1][1]

    cols = seq(start,stop-1)

    arg_offset = 3
} else {

    raw_data = read.delim(data_file, header=FALSE, sep="\t", check.names = FALSE)
    cols = raw_data[, 1]
    plot_data = t(raw_data[, -1])

    arg_offset = 3
}

jobnum = ""
extra_text = ""
if (length(args) > arg_offset) {
    jobnum = paste("for Job ID", args[arg_offset+1])
}
if (length(args) > arg_offset+1) {
    extra_text = args[arg_offset+2];
}
im_width = 1800
if (length(args) > arg_offset+2) {
    im_width = strtoi(args[arg_offset+3])
}
im_height = 900
if (length(args) > arg_offset+3) {
    im_height = strtoi(args[arg_offset+4])
}

colnames(plot_data) = cols

png(png_file, width=im_width, height=im_height, type="cairo");
par(mar=c(4,4,4,4))

barplot(plot_data, main = paste("Number of Sequences at Each Length", jobnum, extra_text), ylab = "Number of Sequences", xlab = "Length", col = "red", border = "blue")
dev.off()

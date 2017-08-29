library("rhdf5")

args <- commandArgs(trailingOnly = TRUE)
hdffile=args[1]
pngfile=args[2]
start<-h5read(hdffile,"/stats/start")
stop<-h5read(hdffile,"/stats/stop")

start=start[1][1]
stop=stop[1][1]


jobnum = ""
if (length(args) > 2) {
    jobnum = paste(" for Job ID ", args[3])
}
im_width = 2000
if (length(args) > 3) {
    im_width = strtoi(args[4])
}
im_height = 900
if (length(args) > 4) {
    im_height = strtoi(args[5])
}


print(paste(start,",",stop))
png(pngfile, width=im_width, height=im_height)

newdata=t(rep(NA,stop))

bar_step_size <- 1
whisk_color <- "gray40"
if (im_width < 1000) {
    bar_step_size = 5
    whisk_color <- "gray60"
}

num_boxes <- stop - start + 1
step_size <- ceiling(10 / (im_width / num_boxes))
box_range <- seq(start, num_boxes + step_size, step_size)
bars_to_use <- seq(start, num_boxes, bar_step_size)

boxplot(newdata,
        main = paste("Percent Identity vs Alignment Score", jobnum),
        whiskcol = whisk_color,
        staplecol = whisk_color,
        ylab = "Percent Identity",
        xlab = "Alignment Score",
        ylim = range(0,100),
        xaxt = "n",
        frame = F)

for (i in bars_to_use) {
    key=i #i+start-1
    print(paste0("/perid/",key))
    newdata=t(h5read(hdffile,paste0("/perid/",key)))
    boxplot(newdata,
            col = "red", 
            border = "blue", 
            whiskcol = whisk_color, 
            staplecol = whisk_color,
            add = TRUE , 
            xaxt = "n", 
            yaxt = "n", 
            at=key, 
            range = 0, 
            frame=F)
    rm(newdata)
    gc()
}
axis(side = 1, box_range)

dev.off()


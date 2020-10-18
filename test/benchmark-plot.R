benchmark.no_ft <- read.delim("benchmark-no_ft.tsv.bz2",
                              colClasses = c("factor","factor","factor","integer","numeric","numeric","numeric"))
benchmark.ft <- read.delim("benchmark-ft.tsv.bz2",
                            colClasses = c("factor","factor","factor","integer","numeric","numeric","numeric"))

levels(benchmark.ft) <-c("barrier", "agree")
benchmark = rbind(transform(subset(benchmark.no_ft,
                                   stat==1),
                            stat=factor("barrier (ft disabled)")),
                  benchmark.ft)

benchmark$num_images <- factor(benchmark$num_images,
                               levels=as.character(sort(as.integer(levels(benchmark$num_images)))))

pdf("form_team.pdf")
boxplot(time.form_team*1000 ~ num_images + stat,
        lex.order = T,
        data=benchmark,
        outline = FALSE,
        col=c("blue","red", "limegreen"),
        boxwex=0.75,
        xaxt = 'n',
        at=c(1:3,5:7,9:11,13:15,17:19,21:23),
        xlab = "Number of images",
        ylab="Time (milliseconds)")
title("FORM TEAM (MPI_COMM_SPLIT + MPI_BARRIER/MPI_COMM_AGREE)")
axis(side=1, at=c(2,6,10,14,18,22), labels = c("2","4","8","16","32","64"))
axis(side=1, tck=1, at=c(4,8,12,16,20), col.ticks="dark gray", labels=FALSE)
axis(side=2, tck=1, col.ticks="light gray", labels=FALSE)
legend("topleft", inset=0.01, bty="n", fill=c("blue","red","limegreen"),title = "Synchronization", title.adj = 0, legend=c("MPI_BARRIER (ft disabled)", "MPI_BARRIER", "MPI_COMM_AGREE"))

dev.off()



pdf("change_end_team.pdf")
boxplot((time.change_team+time.end_team)/2*1000 ~ num_images + stat,
        lex.order = T,
        data=benchmark,
        outline = FALSE,
        col=c("blue","red", "limegreen"),
        boxwex=0.75,
        xaxt = 'n',
        at=c(1:3,5:7,9:11,13:15,17:19,21:23),
        xlab = "Number of images",
        ylab="Time (milliseconds)")
title("CHANGE TEAM / END TEAM")
axis(side=1, at=c(2,6,10,14,18,22), labels = c("2","4","8","16","32","64"))
axis(side=1, tck=1, at=c(4,8,12,16,20), col.ticks="dark gray", labels=FALSE)
axis(side=2, tck=1, col.ticks="light gray", labels=FALSE)
legend("topleft", inset=0.01, bty="n", fill=c("blue","red","limegreen"),title = "Synchronization", title.adj = 0, legend=c("MPI_BARRIER (ft disabled)", "MPI_BARRIER", "MPI_COMM_AGREE"))

dev.off()

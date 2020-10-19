sole_survivor <- read.delim("sole_survivor.tsv.bz2",
                            colClasses = c("factor","integer","numeric","numeric","numeric"))
sole_survivor$num_images <- factor(sole_survivor$num_images,
                                   levels=as.character(sort(as.integer(levels(sole_survivor$num_images)))))

# active_images == 0: total time for a given repetition
svg("sole_survivor.svg")
barplot(t(aggregate(cbind(1000*time.end_team, 1000*time.form_team, 1000*time.change_team) ~ num_images, data = subset(sole_survivor, active_images > 0), FUN = "mean")[,-1]),
    names = c("2","4","8","16","32","64"),
    xlab = "Number of images",
    ylab="Average time (milliseconds)",
    main = '"Sole Survivor" Benchmark',
    legend.text = c("END TEAM", "FORM TEAM", "CHANGE TEAM"),
    col = c("dark blue", "orange", "yellow"),
    args.legend = list(x = "topleft", bty = "n", inset=c(0,0.05))
)
axis(side=2, tck=1, col.ticks="dark gray", labels=FALSE)

dev.off()

library(readr)
library(reshape2)
library(tidyverse)
library(ggridges)
library(ggplot2)
library(ggforce)
library(ggstatsplot)
library(hrbrthemes)

benchmark_instance_plot <- function(data, b) {
  bmark <- dplyr::select(filter(data, benchmark == b), instance, sample)
  grouped <- dplyr::group_by(bmark, instance)

  options(repr.plot.width=30, repr.plot.height=80)

  grouped %>%
    ggplot(aes(x=sample,
               y=fct_reorder(instance, sample, .fun = mean),
               fill=instance, height=after_stat(density))) +
    geom_density_ridges(alpha = 0.6, stat="density_ridges",
                        rel_min_height=0.001, scale=3) +
    scale_y_discrete(expand = c(0.01, 0)) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 20)) +
    theme_ipsum() +
    theme(legend.position = "none",
          panel.spacing = unit(0.1, "lines"),
          strip.text.x = element_text(size = 8)) +
    labs(x = "Latency (microseconds)",
         y = "Instance Type",
         title=paste(b, "Latency by Instance Type")) +
    coord_cartesian(xlim = quantile(grouped$sample, c(0, 0.999)))
}

data <- read_csv('benchmarks.csv', show_col_types=FALSE)

benchmark_instance_plot(data, "Request__GetRandom")
benchmark_instance_plot(data, "Request__Attestation")

library(data.table)
library(ggplot2)
library(viridis)

# 1. LOAD DATA
dt <- fread("results/Alouatta_Clean_Final.csv")

# 2. THE FINAL HELPER FUNCTION
# We add 'rotate' and 'italic_axis' as specific options
create_dist_plot <- function(data, category_var, title_text, x_label, rotate = FALSE, italic_axis = FALSE) {
  
  counts <- data[, .N, by = category_var]
  setnames(counts, c("Category", "n"))
  
  # Set fontface
  f_face <- if(italic_axis) "italic" else "bold"
  
  # For vertical plots (A & B), we want descending order
  # For horizontal plots (C), we want ascending so the biggest is at the top
  if(rotate) {
    counts$Category <- reorder(counts$Category, counts$n)
  } else {
    counts$Category <- reorder(counts$Category, -counts$n)
  }
  
  p <- ggplot(counts, aes(x = Category, y = n, fill = n)) +
    geom_col(width = 0.8) +
    scale_fill_viridis_c(option = "viridis", direction = -1) +
    labs(
      title = title_text,
      subtitle = "Alouatta Foraging Dataset - Sample Distribution",
      x = x_label,
      y = "Number of Observations (n)"
    ) +
    theme_minimal(base_size = 15) +
    theme(
      panel.grid.major.x = element_blank(),
      legend.position = "none",
      plot.title = element_text(face = "bold", size = 20)
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15)))
  
  # APPLY ROTATION LOGIC
  if(rotate) {
    # Horizontal Bars
    p <- p + 
      coord_flip() + 
      geom_text(aes(label = n), hjust = -0.2, size = 5, fontface = "bold") +
      theme(axis.text.y = element_text(face = f_face))
  } else {
    # Vertical Bars
    p <- p + 
      geom_text(aes(label = n), vjust = -0.5, size = 4.5, fontface = "bold") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"))
  }
  
  return(p)
}

# 3. GENERATE AND SAVE
# Plot A: Vertical, Bold Labels
p_group <- create_dist_plot(dt, "grupo", "Data Distribution by Group", "Sampling Group")
ggsave("results/Plot_Distribution_Group.png", p_group, width = 16, height = 9, dpi = 300)

# Plot B: Vertical, Bold Labels
p_pop <- create_dist_plot(dt, "Population", "Data Distribution by Population", "Population Site")
ggsave("results/Plot_Distribution_Population.png", p_pop, width = 16, height = 9, dpi = 300)

# Plot C: Horizontal, Italicized Labels
p_species <- create_dist_plot(dt, "Species", "Data Distribution by Species", "Primate Species", 
                              rotate = TRUE, italic_axis = TRUE)
ggsave("results/Plot_Distribution_Species.png", p_species, width = 16, height = 9, dpi = 300)

message("--- SUCCESS ---")
message("Plots are now saved.")
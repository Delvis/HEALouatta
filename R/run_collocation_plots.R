library(data.table)
library(ggplot2)
library(viridis)
library(ggtext)
library(igraph)
library(ggraph)
library(openxlsx)

# --- 1. SETUP & LOAD DATA ---
current_suffix <- if(exists("file_suffix")) file_suffix else "General"
current_title_raw <- if(exists("plot_label")) plot_label else "All Populations"

input_ranked <- paste0("results/Ranked_Pairs_", current_suffix, ".xlsx")
ranked_output <- as.data.table(read.xlsx(input_ranked))

# --- 2. CLEANING NAMES ---
clean_names_simple <- function(x) {
  x <- gsub("_", " ", x)
  x <- gsub("\\s+", " ", x)
  return(trimws(x))
}

ranked_output[, food_item := clean_names_simple(food_item)]
ranked_output[, food_item_next := clean_names_simple(food_item_next)]

# NEW TITLE LOGIC:
# This looks for species names anywhere in the title and italicizes ONLY them.
current_title_display <- clean_names_simple(current_title_raw)

# 1. Italicize full species names if found
current_title_display <- gsub("Alouatta caraya", "<i>Alouatta caraya</i>", current_title_display)
current_title_display <- gsub("Alouatta guariba", "<i>Alouatta guariba</i>", current_title_display)

# 2. Italicize the Genus only if it's followed by "sp." (for the ALL scope)
current_title_display <- gsub("Alouatta sp", "<i>Alouatta</i> sp", current_title_display)

# --- 3. TOP 32 BAR CHART ---
plot_data <- head(ranked_output, 32)
plot_data$pair <- paste(plot_data$food_item, "→", plot_data$food_item_next)
plot_data$pair <- reorder(plot_data$pair, plot_data$coll_strength)

p1 <- ggplot(plot_data, aes(x = coll_strength, y = pair, fill = k_obs)) +
  geom_col(width = 0.8) +
  scale_fill_viridis_c(option = "viridis", direction = -1) +
  labs(
    title = paste("Top Transitions:", current_title_display),
    subtitle = "Ranked by Collocation Strength (Exact Binomial)",
    x = "Strength Score = −log<sub>10</sub>(<i>p</i>-value)",
    y = "Foraging Transition",
    fill = "Observed (n)"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_markdown(face = "bold", size = 18),
    plot.subtitle = element_text(color = "grey30"),
    axis.title.x = element_markdown(),
    axis.text.y = element_text(size = 10, face = "bold"), # Clean, bold labels
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(paste0("results/BarChart_", current_suffix, ".png"), plot = p1, 
       width = 16, height = 9, dpi = 360, bg = "white")

# --- 4. TOP 64 NETWORK GRAPH ---
net_data <- head(ranked_output, 64)
graph <- graph_from_data_frame(net_data[, .(food_item, food_item_next, coll_strength)])

p2 <- ggraph(graph, layout = 'kk') + 
  geom_edge_fan(aes(width = coll_strength, alpha = coll_strength), 
                arrow = arrow(length = unit(3, 'mm'), type = "closed"),
                end_cap = circle(3, 'mm'), 
                color = "#95a5a6") + 
  geom_node_point(size = 5, color = "#2c3e50") + 
  # Standard geom_node_text: Rock solid, no rendering errors
  geom_node_text(aes(label = name), 
                 repel = TRUE, 
                 size = 4, 
                 fontface = "bold",
                 color = "black") + 
  scale_edge_width(range = c(0.5, 3), name = "Strength Score") + 
  scale_edge_alpha(range = c(0.2, 0.8), name = "Strength Score") +
  labs(title = paste("Foraging Network:", current_title_display)) +
  theme_void() +
  theme(
    plot.title = element_markdown(face = "bold", size = 20, hjust = 0.5),
    legend.position = "right",
    legend.title = element_text(face = "bold"),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(paste0("results/NetworkPlot_", current_suffix, ".png"), plot = p2, 
       width = 16, height = 12, dpi = 360, bg = "white")

message("--- PLOTTING SUCCESS ---")
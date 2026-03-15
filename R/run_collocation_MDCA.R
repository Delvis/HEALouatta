library(data.table)
library(openxlsx)

# 1. SETUP - Dynamic Input/Output
# If called from Master, use the suffix. If run alone, use default.
current_suffix <- if(exists("file_suffix")) file_suffix else "General"

input_file <- paste0("outputs/Prepared_for_Collocation_", current_suffix, ".txt")
file_ranked <- paste0("results/Ranked_Pairs_", current_suffix, ".xlsx")
file_matrix <- paste0("results/Strength_Matrix_", current_suffix, ".xlsx")

if(!file.exists(input_file)) {
  stop(paste("Input file not found:", input_file, ". Did you run main_bouts.R first?"))
}

df <- fread(input_file)
total_n <- nrow(df)

# 2. CALCULATE VARIABLES
global_b <- df[, .(global_B_count = .N), by = .(food_item_next)]
global_b[, p_global := global_B_count / total_n]

total_a <- df[, .(n_trials = .N), by = .(food_item)]

mdca_results <- df[, .(k_obs = .N), by = .(food_item, food_item_next)]

# 3. MERGE & COMPUTE
mdca_results <- merge(mdca_results, total_a, by = "food_item")
mdca_results <- merge(mdca_results, global_b, by = "food_item_next")

# Exact Binomial Test
mdca_results[, p_val := pbinom(k_obs - 1, n_trials, p_global, lower.tail = FALSE)]
mdca_results[, coll_strength := round(-log10(p_val), 5)]

# Clean up Infinites
finite_vals <- mdca_results[is.finite(coll_strength)]$coll_strength
max_s <- if(length(finite_vals) > 0) max(finite_vals) else 10
mdca_results[is.infinite(coll_strength), coll_strength := max_s + 1]

# 4. EXPORT 1: RANKED LIST
ranked_list <- mdca_results[food_item != food_item_next]
setorder(ranked_list, -coll_strength)
write.xlsx(ranked_list, file_ranked)

# 5. EXPORT 2: MATRIX
strength_matrix <- dcast(mdca_results, food_item ~ food_item_next, 
                         value.var = "coll_strength", fill = 0)
write.xlsx(strength_matrix, file_matrix)

message(paste("--- MDCA SUCCESS ---"))
message(paste("Files saved for suffix:", current_suffix))
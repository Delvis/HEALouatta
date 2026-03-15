library(arules)
library(data.table)

# --- 1. DATA LOADING ---
if (!exists("clean_data")) {
  # Path is relative to the 'app' folder
  data_path <- "data/clean_data.rds"
  
  if (file.exists(data_path)) {
    clean_data <- readRDS(data_path)
  } else {
    # Fallback for local development if you haven't run the pipeline yet
    parent_path <- "../data_checkpoints/clean_data.rds" # You might need to add a saveRDS in Step 7 too
    if(file.exists(parent_path)) {
      clean_data <- readRDS(parent_path)
    } else {
      stop("Data file not found! Please run clean_data.R first.")
    }
  }
}
# Ensure it is a data.table for the fast [Species == ...] syntax in server.R
setDT(clean_data)

# --- 2. GLOBAL CLEANING ---
# Do the heavy lifting once here so the server doesn't have to repeat it
clean_data <- clean_data[food_item != "" & !is.na(food_item)]
clean_data <- clean_data[!grepl("Unknown|unknown", food_item)]

# Convert factors if needed for the dropdown menus
clean_data[, Species := as.character(Species)]
clean_data[, Population := as.character(Population)]

# --- 3. (Optional) GLOBAL ITEM LABELS ---
# Useful for initializing selectizeInputs
all_items <- sort(unique(clean_data$food_item))
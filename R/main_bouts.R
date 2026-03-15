library(data.table)

# 1. Load the cleaned buckets
# If running via Master script, 'working_dt' exists in memory
# Otherwise, we load the default checkpoint
if (exists("working_dt")) {
  message("Main Bouts: Using subset provided by Master script.")
  # Use a copy to avoid modifying the master object directly
  dt_bouts <- copy(working_dt)
} else {
  message("Main Bouts: Running independently. Loading full checkpoint.")
  load("data_checkpoints/alouatta_buckets.RData")
  dt_bouts <- copy(clean_data)
}

# 2. DEFINING THE BOUTS
# Sort strictly by actor and time to ensure sequential logic
setorder(dt_bouts, actor, datetime)

# Calculate the time gap between scans for the same individual
dt_bouts[, time_gap := as.numeric(difftime(datetime, shift(datetime), units="mins")), by=actor]
dt_bouts[is.na(time_gap), time_gap := 0]

# LOGIC: New bout starts if:
# - Actor changes OR
# - Food item changes OR
# - More than 60 minutes passed since last scan

dt_bouts[, is_new_bout := actor != shift(actor, fill="") | 
           food_item != shift(food_item, fill="") |
           time_gap > 60]

dt_bouts[, bout_id := cumsum(is_new_bout)]

# 3. SUMMARIZE INTO BOUT TABLE
table_bouts <- dt_bouts[, .(
  date = first(date_only),
  time_start = first(time_string),
  datetime_start = first(datetime),
  food_item = first(food_item),
  n_scans = .N,
  duration_mins = .N * 15 # Assuming 15-min scan intervals
), by = .(actor, bout_id)]

# 4. CREATE TRANSITION PAIRS (ITEM A -> ITEM B)
# We use shift(type="lead") to see what was eaten next by the same actor on the same day.
setorder(table_bouts, actor, datetime_start)
table_bouts[, food_item_next := shift(food_item, type="lead"), by=.(actor, date)]

# Filter out the last bout of each day (which has no "next" item)
final_pairs <- table_bouts[!is.na(food_item_next)]

# 5. SANITIZE FOR THE GRIES/MAËL SCRIPT
# The collexeme script is very picky: no spaces, no dots, no commas.
clean_for_gries <- function(x) {
  x <- gsub("[^[:alnum:]]", "_", x) # Replace all non-alphanumeric with _
  x <- gsub("__+", "_", x)          # Collapse double underscores
  x <- gsub("_$", "", x)            # Remove trailing underscores
  return(x)
}

final_pairs[, food_item := clean_for_gries(food_item)]
final_pairs[, food_item_next := clean_for_gries(food_item_next)]

# 6. EXPORT
if (!dir.exists("outputs")) dir.create("outputs")

# Use file_suffix if it exists (from Master), else use default
prep_filename <- if(exists("file_suffix")) {
  paste0("outputs/Prepared_for_Collocation_", file_suffix, ".txt")
} else {
  "outputs/Alouatta_Prepared_for_Collocation.txt"
}

write.table(final_pairs[, .(food_item, food_item_next)], 
            file = prep_filename, 
            sep = "\t", quote = FALSE, row.names = FALSE)

message(paste("Bout analysis complete. Exported to:", prep_filename))
# ==========================================
# MASTER RUNNER: Alouatta Foraging Analysis
# ==========================================
library(data.table)

# --- SETTINGS ---
# Options: "ALL", "Alouatta caraya", "Alouatta guariba", 
# or specific Population code (e.g., "NSG")
RUN_SCOPE <- "JCBM"

# --- STEP 1: CLEAN DATA ---
# This script must leave an object called 'clean_data' in the environment
source("R/clean_data.R") 

# --- STEP 2: SUBSETTING ---
# We use the object directly from memory instead of reloading from disk
if (RUN_SCOPE == "ALL") {
  working_dt <- clean_data
  plot_label <- "<i>Alouatta</i> sp."
  file_suffix <- "General"
} else if (RUN_SCOPE %in% unique(clean_data$Species)) {
  working_dt <- clean_data[Species == RUN_SCOPE]
  plot_label <- RUN_SCOPE # Keeps the space for the plot title
  file_suffix <- gsub(" ", "_", RUN_SCOPE) # Underscore for filename safety
} else {
  # Logic for Population codes (NSG, HMP, etc.)
  working_dt <- clean_data[Population == RUN_SCOPE]
  sp_name <- working_dt[1, Species]
  plot_label <- paste(sp_name, "-", RUN_SCOPE)
  file_suffix <- paste0(gsub(" ", "_", sp_name), "_", RUN_SCOPE)
}

# --- STEP 3: PREPARE FOR SUB-SCRIPTS ---
# This is the most important part: 
# The next scripts (main_bouts, MDCA, plots) need to look at 'working_dt'
# We save this specific subset as a temporary "checkpoint"
if (!dir.exists("outputs")) dir.create("outputs")
fwrite(working_dt, "outputs/current_subset.csv")

# --- STEP 4: RUN PIPELINE ---
source("R/main_bouts.R")             # Processes bouts for this subset
source("R/run_collocation_MDCA.R")    # Runs the MDCA statistics
source("R/run_collocation_plots.R")   # Generates the visuals

message(paste("--- FULL PIPELINE FINISHED FOR:", RUN_SCOPE, "---"))
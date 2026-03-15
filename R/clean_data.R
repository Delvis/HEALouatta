library(data.table)
library(readxl)

# 1. LOAD DATA - Force to Text to prevent early corruption
raw_data <- readxl::read_excel("./alouatta_data.xlsx", col_types = "text")
setDT(raw_data)
setnames(raw_data, tolower(names(raw_data)))

# 2. THE REPAIR FUNCTIONS
fix_excel_date_v2 <- function(x) {
  if (is.na(x)) return(as.Date(NA))
  # Case A: 8-digit date (20120314)
  if (nchar(x) == 8 && (startsWith(x, "1") | startsWith(x, "2"))) {
    return(as.Date(x, format = "%Y%m%d"))
  } 
  # Case B: 6-digit date (201207) - Assuming 1st of month
  if (nchar(x) == 6 && (startsWith(x, "1") | startsWith(x, "2"))) {
    return(as.Date(paste0(x, "01"), format = "%Y%m%d"))
  }
  # Case C: Excel Serial Number (e.g. 39396)
  x_num <- as.numeric(x)
  if (!is.na(x_num) && x_num < 100000) {
    return(as.Date(x_num, origin = "1899-12-30"))
  }
  return(as.Date(NA))
}

fix_excel_time <- function(h) {
  if (is.na(h)) return("0000")
  
  # 1. Handle Excel Fractions (0.729...)
  h_num <- as.numeric(h)
  if (!is.na(h_num) && h_num < 1) {
    seconds <- round(h_num * 86400)
    return(format(as.POSIXct(seconds, origin="1970-01-01", tz="UTC"), "%H%M"))
  }
  
  # 2. Clean decimals/spaces
  h_clean <- gsub("\\..*", "", trimws(as.character(h)))
  
  # --- THE TYPO GATE ---
  # If someone typed 9000, 8000, 7000... convert to 0900, 0800, etc.
  if (h_clean %in% c("7000", "8000", "9000")) {
    return(paste0("0", substr(h_clean, 1, 1), "00"))
  }
  
  # 3. Standard Padding
  if (nchar(h_clean) == 1) return(paste0("000", h_clean))
  if (nchar(h_clean) == 2) return(paste0("00", h_clean))
  if (nchar(h_clean) == 3) return(paste0("0", h_clean))
  
  return(substr(h_clean, 1, 4)) 
}

# 3. APPLY REPAIRS & STANDARDIZATION
raw_data[, date_clean := as.Date(sapply(data, fix_excel_date_v2), origin="1970-01-01")]
raw_data[, time_string := sapply(hora, fix_excel_time)]
raw_data[, behaviour_date := as.POSIXct(paste(as.character(date_clean), time_string), 
                                        format="%Y-%m-%d %H%M")]
raw_data[, `:=`(especie = trimws(as.character(especie)), 
                item = tolower(item), 
                tipo = toupper(tipo))]

# --- 4. BUCKETING
is_code <- grepl("^A?\\d+$", raw_data$especie) | raw_data$especie == "IND"
check_species <- raw_data[is_code]
working_set   <- raw_data[!is_code]

is_bad_date <- is.na(working_set$behaviour_date) | 
  year(working_set$date_clean) > 2026 | 
  year(working_set$date_clean) < 1980

check_dates <- working_set[is_bad_date]
clean_data  <- working_set[!is_bad_date]

# 5. DICTIONARY & ITEM CREATION
part_map <- c(
  "FOB" = "leaf bud", "FOV" = "young leaf", "FOM" = "mature leaf", "FOI" = "leaf indet",
  "FLB" = "flower bud", "FLA" = "open flower", "FLI" = "flower indet",
  "FRV" = "unripe fruit", "FRM" = "ripe fruit", "FRI" = "fruit indet",
  "C"   = "bark", "R"   = "branch", "S" = "seed"
)
clean_data[, plant_part := part_map[tipo]]
clean_data[is.na(plant_part), plant_part := item]
clean_data[, food_item := paste(especie, "-", plant_part)]

setnames(clean_data, 
         old = c("individuo", "especie", "date_clean", "behaviour_date"), 
         new = c("actor", "species_name", "date_only", "datetime"), 
         skip_absent = TRUE)

# 6. POPULATION AND SPECIES MAPPING
pop_species_map <- data.table(
  grupo = c("ASJ", "CBM", "NSGI", "NSGII", "NSGIII", "GBG", "HMP", 
            "IAL_CEN", "IAL_MAN", "IAL_IND", "JCBM", "VMSME", "VMSMSP", "VMSPSP"),
  Population = c("ASJ", "CBM", "NSG", "NSG", "NSG", "GBG", "HMP", 
                 "IAL", "IAL", "IAL", "JCBM", "VMS", "VMS", "VMS"),
  Species = c("Alouatta caraya", "Alouatta caraya", "Alouatta guariba", "Alouatta guariba", "Alouatta guariba", 
              "Alouatta guariba", "Alouatta caraya", "Alouatta caraya", "Alouatta caraya", "Alouatta caraya", 
              "Alouatta caraya", "Alouatta guariba", "Alouatta guariba", "Alouatta guariba")
)

clean_data <- merge(clean_data, pop_species_map, by = "grupo", all.x = TRUE)

if(any(is.na(clean_data$Species))) {
  warning("Some records have 'grupo' values not found in the mapping table!")
}

# 6b. FILTER LOW-SAMPLE GROUPS (n < 100)
group_counts <- clean_data[, .N, by = grupo]
clean_data <- clean_data[grupo %in% group_counts[N >= 100, grupo]]

# 7. SORT & CHECKPOINT
setorder(clean_data, actor, datetime)

if (!dir.exists("data_checkpoints")) dir.create("data_checkpoints")
save(clean_data, check_species, check_dates, file = "data_checkpoints/alouatta_buckets.RData")

message("--- DATA CLEANING COMPLETE ---")
message(paste("Remaining Rows:", nrow(clean_data)))
message("The object 'clean_data' is ready in memory for run_analysis.R")

# 8. SELF-CONTAINED APP EXPORT
# Create the app/data folder if it doesn't exist
if (!dir.exists("app/data")) dir.create("app/data", recursive = TRUE)

# Save as RDS for the self-contained Shiny App
saveRDS(clean_data, file = "app/data/clean_data.rds")

message("--- APP DATA SYNCED ---")
message("File saved to: app/data/clean_data.rds")
#### INITIAL SETTINGS ####
library(httr)
library(rvest)
library(dplyr)
library(purrr)
library(writexl)
library(rstudioapi)
library(future)
library(furrr)
library(openxlsx)
library(httr)
library(jsonlite)
library(future.apply)
library(googlesheets4)
library(tidyr)
library(readxl)
library(curl)
options(gargle_quiet = TRUE)
gs4_auth(cache = ".secrets", email = "davidruffini98@gmail.com")



url <- "http://www.ristretti.it/areestudio/disagio/ricerca/2010/morti.carcere.xls"
destfile <- tempfile(fileext = ".xls")

GET(url, write_disk(destfile, overwrite = TRUE))



# Leggi il file
dati <- read_excel(destfile, skip = 3)
dati$Età = as.numeric(gsub("\\D", "", dati$Età))

# vecchi dati
sheet_id <- "1Srarxv6VAfhXdNmPnAEGapgm8lsypB-LVgHOle64iYg"  
foglio <- read_sheet(sheet_id)

# aggiornamento
# Uniforma formato date, se serve
dati <- dati %>%
  mutate(Data = as.Date(Data))
foglio = foglio %>%
  mutate(Data = as.Date(Data))

# Filtro solo le nuove righe
dati_da_aggiungere <- anti_join(dati, foglio, by = "Data")

# Aggiungi i dati
sheet_append(sheet_id, dati_da_aggiungere)

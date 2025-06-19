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
gs4_auth(cache = ".secrets", email = Sys.getenv("GOOGLE_EMAIL"))


#### NUOVI DATI ####
url = "http://www.ristretti.it/areestudio/disagio/ricerca/2010/morti.carcere.xls"
destfile = tempfile(fileext = ".xls")
GET(url, write_disk(destfile, overwrite = TRUE))

# leggo il file
dati = read_excel(destfile, skip = 3)
dati$Età = as.numeric(gsub("\\D", "", dati$Età))

#### VECCHI DATI ####
sheet_id = "1Srarxv6VAfhXdNmPnAEGapgm8lsypB-LVgHOle64iYg"  
foglio = read_sheet(sheet_id)

#### AGGIORNAMENTO ####
# uniformo le date
dati = dati %>%
  mutate(Data = as.Date(Data))
foglio = foglio %>%
  mutate(Data = as.Date(Data))

# filtro solamente le nuove righe
dati_da_aggiungere = anti_join(dati, foglio, by = "Data")

# se ci sono nuove righe, le aggiungo; altrimenti, restituisce un messaggio 
if (nrow(dati_da_aggiungere) > 0) {
  sheet_append(sheet_id, dati_da_aggiungere)
} else {
  message("Nessun dato da aggiungere.")
}




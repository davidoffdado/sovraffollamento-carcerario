#### INITIAL SETTINGS ####
library(httr)
library(rvest)
library(dplyr)
library(purrr)
library(writexl)
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
# In CI (GitHub Actions) l'autenticazione avviene con un service account,
# la cui chiave viene scritta su file dal workflow; in locale resta valida
# l'autenticazione interattiva con cache su .secrets.
sa_key_path = Sys.getenv("GOOGLE_SA_KEY_PATH")
if (sa_key_path != "") {
  gs4_auth(path = sa_key_path)
} else if (!gs4_has_token()) {
  gs4_auth(cache = ".secrets", email = Sys.getenv("GOOGLE_EMAIL"))
}


#### NUOVI DATI ####
url = "http://www.ristretti.it/areestudio/disagio/ricerca/morti.carcere.xls"
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

# filtro solamente le nuove righe: confronto per persona e data, non solo per data
# (prima due morti nello stesso giorno venivano contate una volta sola)
dati_da_aggiungere = anti_join(dati, foglio, by = c("Cognome", "Nome", "Data"))

# se ci sono nuove righe, le aggiungo; altrimenti, restituisce un messaggio 
if (nrow(dati_da_aggiungere) > 0) {
  sheet_append(sheet_id, dati_da_aggiungere)
} else {
  message("Nessun dato da aggiungere.")
}

#### TOTALI PER ANNO E CAUSA (per la pagina pubblica) ####
# il foglio delle morti contiene nomi e cognomi e resta privato: nella scheda "Morti" del foglio
# pubblico degli istituti scrivo solo i conteggi, calcolati sul file completo di Ristretti Orizzonti
totali_morti = dati %>%
  filter(!is.na(Data), !is.na(Causa)) %>%
  mutate(
    anno = as.integer(format(Data, "%Y")),
    causa = trimws(Causa, whitespace = "[\\h\\v]"), # toglie anche gli spazi non separabili
    causa = paste0(toupper(substr(causa, 1, 1)), tolower(substr(causa, 2, nchar(causa))))
  ) %>%
  count(anno, causa, name = "morti") %>%
  arrange(anno, causa)

sheet_write(totali_morti, ss = "1wH9i9hc_B7Q91KklHFc8FHFdGrZ82SsDB1gHhNPaumg", sheet = "Morti")




#### MORTI PER ISTITUTO (per le schede della pagina pubblica) ####
# I nomi degli istituti di Ristretti Orizzonti sono scritti liberamente: l'abbinamento ai codici del
# Ministero sta in data/abbinamento-morti-istituti.csv (costruito il 2026-11-04 con un abbinamento
# automatico prudente e alcune correzioni a mano). Restano fuori i nomi ambigui (es. "Roma Rebibbia",
# "Firenze", citta' con piu' istituti), gli OPG chiusi, CIE/CPR, questure e domiciliari.
# I nomi nuovi non presenti nel file vengono elencati qui sotto: per contarli basta aggiungerli al CSV.
abbinamento = read.csv("data/abbinamento-morti-istituti.csv", colClasses = "character")
morti_istituti = dati %>%
  filter(!is.na(Data), !is.na(Causa), !is.na(Istituto)) %>%
  mutate(
    anno = as.integer(format(Data, "%Y")),
    causa = trimws(Causa, whitespace = "[\\h\\v]"),
    causa = paste0(toupper(substr(causa, 1, 1)), tolower(substr(causa, 2, nchar(causa)))),
    ristretti = Istituto
  ) %>%
  left_join(abbinamento, by = "ristretti")
non_abbinati = morti_istituti %>% filter(is.na(ID_istituto)) %>% count(ristretti, sort = TRUE)
message("Morti attribuite a un istituto: ", sum(!is.na(morti_istituti$ID_istituto)), " su ", nrow(morti_istituti),
        ". Nomi non abbinati piu' frequenti: ", paste(head(non_abbinati$ristretti, 10), collapse = "; "))
morti_istituti = morti_istituti %>%
  filter(!is.na(ID_istituto)) %>%
  count(ID_istituto, anno, causa, name = "morti") %>%
  arrange(ID_istituto, anno, causa)

sheet_write(morti_istituti, ss = "1wH9i9hc_B7Q91KklHFc8FHFdGrZ82SsDB1gHhNPaumg", sheet = "MortiIstituti")

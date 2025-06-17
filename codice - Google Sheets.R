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
options(gargle_quiet = TRUE)
# gs4_auth(cache = ".secrets", email = "davidruffini98@gmail.com")



#### INIZIO AGGIORNAMENTO DATI ####

#### CARICAMENTO DATI ESISTENTI ####
sheet_istituti = "1wH9i9hc_B7Q91KklHFc8FHFdGrZ82SsDB1gHhNPaumg"
df_precedente = read_sheet(ss=sheet_istituti, sheet = "Dati")

#### WEB SCRAPING ####
# inizio parallelizzazione
plan(multisession, workers = 4)

#### FUNZIONE WEB SCRAPING (SOLO DATI AGGIORNABILI) ####
estrai_dati_aggiornati <- function(id, max_retry = 5) {
  url <- paste0("https://www.giustizia.it/giustizia/page/it/dettaglio_scheda_istituto_penitenziario?s=MII", id)
  
  attempt <- 1
  while (attempt <= max_retry) {
    Sys.sleep(1)
    
    result <- tryCatch({
      pagina <- read_html(url)
      tabelle <- pagina %>% html_nodes("table.custom-table.custom-text-center")
      
      estrai_tabella <- function(tabella) {
        intestazioni <- tabella %>% html_nodes("th") %>% html_text(trim = TRUE)
        valori <- tabella %>% html_nodes("td") %>% html_text(trim = TRUE)
        df <- as.data.frame(matrix(valori, nrow = 1, byrow = TRUE), stringsAsFactors = FALSE)
        colnames(df) <- intestazioni
        return(df)
      }
      
      dati_list <- lapply(tabelle[1:5], estrai_tabella)
      dati_uniti <- bind_cols(dati_list)
      dati_uniti$id <- id
      return(dati_uniti)
      
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(result)) return(result)
    
    attempt <- attempt + 1
    Sys.sleep(3 * attempt)
  }
  
  return(NULL)
}

#### ESTRAZIONE DATI AGGIORNATI ####
ids <- df_precedente$istituto.id  # colonna 'id' è in df_precedente$istituto.id
dati_aggiornati <- future_map_dfr(ids, estrai_dati_aggiornati, .progress = TRUE)
# fine parallelizzazione
plan(sequential)

#### AGGIUNTA METADATI ####
dati_aggiornati <- dati_aggiornati %>%
  mutate(data_aggiornamento = Sys.Date())

#### JOIN DEI NUOVI DATI CON QUELLI VECCHI ####
df_finale <- df_precedente %>%
  select(istituto.nome_istituto, istituto.id, lat, lon) %>%  # colonne da non modificare
  left_join(dati_aggiornati, by = c("istituto.id" = "id"))



#### RICALCOLO TASSO DI SOVRAFFOLLAMENTO ####
df_finale <- df_finale %>%
  mutate(across(c("posti regolamentari", "posti non disponibili", "totale detenuti"), as.numeric)) %>%
  mutate(tasso_sovraffollamento = (`totale detenuti` / (`posti regolamentari` - `posti non disponibili`))*100,
         tasso_sovraffollamento = replace_na(tasso_sovraffollamento, 0))

#### SOSTITUISCO IL VECCHIO FOGLIO ####
sheet_write(df_finale, ss = sheet_istituti, sheet = "Dati")


#### FINE AGGIORNAMENTO DATI ####

#### INIZIO AGGIORNAMENTO TASSO DI SOVRAFFOLLAMENTO NAZIONALE ####
#### TASSO DI SOVRAFFOLLAMENTO NAZIONALE ####
totale_detenuti <- sum(df_finale$`totale detenuti`, na.rm = TRUE)
posti_regolamentari <- sum(df_finale$`posti regolamentari`, na.rm = TRUE)
posti_non_disponibili <- sum(df_finale$`posti non disponibili`, na.rm = TRUE)

tasso_nazionale <- (totale_detenuti / (posti_regolamentari - posti_non_disponibili))*100

tasso_oggi <- data.frame(
  data = Sys.Date(),
  tasso_sovraffollamento_nazionale = tasso_nazionale
)

sheet_storico <- "1REAvN1QFv3IzkbHbI7AICLAhDICeh9Vvd4f_Xk-6vOs"
sheet_append(tasso_oggi, ss = sheet_storico, sheet = "Storico")
#### FINE AGGIORNAMENTO TASSO DI SOVRAFFOLLAMENTO NAZIONALE ####



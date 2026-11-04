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


#### INIZIO AGGIORNAMENTO DATI ####

#### CARICAMENTO DATI ESISTENTI ####
sheet_istituti = "1wH9i9hc_B7Q91KklHFc8FHFdGrZ82SsDB1gHhNPaumg"
df_precedente = read_sheet(ss=sheet_istituti, sheet = "Dati")

#### WEB SCRAPING ####
# inizio parallelizzazione
plan(multisession, workers = 4)

#### FUNZIONE WEB SCRAPING ####
estrai_dati_aggiornati = function(id, max_retry = 5) {
  url = paste0("https://www.giustizia.it/giustizia/page/it/dettaglio_scheda_istituto_penitenziario?s=MII", id)
  
  attempt = 1
  while (attempt <= max_retry) {
    Sys.sleep(1)
    
    result = tryCatch({
      pagina = read_html(url)
      tabelle = pagina %>% html_nodes("table.custom-table.custom-text-center")
      
      estrai_tabella = function(tabella) {
        intestazioni = tabella %>% html_nodes("th") %>% html_text(trim = TRUE)
        valori = tabella %>% html_nodes("td") %>% html_text(trim = TRUE)
        df = as.data.frame(matrix(valori, nrow = 1, byrow = TRUE), stringsAsFactors = FALSE)
        colnames(df) = intestazioni
        return(df)
      }
      
      dati_list = lapply(tabelle[1:5], estrai_tabella)
      dati_uniti = bind_cols(dati_list)
      dati_uniti$id = id
      return(dati_uniti)
      
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(result)) return(result)
    
    attempt = attempt + 1
    Sys.sleep(3 * attempt)
  }
  
  return(NULL)
}

#### ESTRAZIONE DATI AGGIORNATI ####
ids = df_precedente$ID_istituto # prendo gli id già presenti
dati_aggiornati = future_map_dfr(ids, estrai_dati_aggiornati, .progress = TRUE)
# fine parallelizzazione
plan(sequential)

#### CONTROLLO: QUANTI ISTITUTI SONO STATI LETTI? ####
# se il sito del Ministero non risponde per buona parte degli istituti mi fermo prima di scrivere
# qualsiasi cosa: il workflow fallisce (GitHub manda una mail) e i dati di ieri restano al loro posto
letti = if (nrow(dati_aggiornati) > 0) unique(dati_aggiornati$id) else c()
falliti = setdiff(ids, letti)
message("Istituti letti: ", length(letti), " su ", length(ids))
if (length(letti) < 0.9 * length(ids)) {
  stop("Letti solo ", length(letti), " istituti su ", length(ids), ": aggiornamento annullato")
}

#### AGGIUNTA METADATI ####
dati_aggiornati = dati_aggiornati %>%
  mutate(data_aggiornamento = Sys.Date())

#### JOIN DEI NUOVI DATI CON QUELLI VECCHI ####
df_finale = df_precedente %>%
  select(Nome_istituto, ID_istituto, Regione, Latitudine, Longitudine) %>%  # colonne da non modificare
   left_join(dati_aggiornati, by = c("ID_istituto" = "id"))

#### RICALCOLO TASSO DI SOVRAFFOLLAMENTO ####
df_finale = df_finale %>%
  mutate(across(c("posti regolamentari", "posti non disponibili", "totale detenuti"), as.numeric)) %>%
  mutate(tasso_sovraffollamento = (`totale detenuti` / (`posti regolamentari` - `posti non disponibili`))*100,
         tasso_sovraffollamento = replace_na(tasso_sovraffollamento, 0))

#### RINOMINIAMO LE COLONNE ####
df_finale = df_finale %>%
  rename(
    Posti_regolamentari = `posti regolamentari`,
    Posti_non_disponibili = `posti non disponibili`,
    Totale_detenuti = `totale detenuti`,
    PolPen_effettivi = `polizia penitenziaria - effettivi`,
    PolPen_previsti = `polizia penitenziaria - previsti`,
    Amm_effettivi = `amministrativi - effettivi`,
    Amm_previsti = `amministrativi - previsti`,
    Educatori_effettivi = `educatori - effettivi`,
    Educatori_previsti = `educatori - previsti`,
    Numero_complessivo = `numero complessivo`,
    Numero_non_disponibili = `numero non disponibili`,
    Doccia = doccia,
    Bidet = bidet,
    Accessibile_disabili = `portatori di handicap`,
    Servizi_igienici_con_porta = `servizi igienici con porta`,
    Accensione_luce_autonoma = `accensione luce autonoma`,
    Prese_elettriche = `prese elettriche`,
    Sale_colloqui = `sale colloqui`,
    Colloqui_conformi = `conformi alle norme`,
    Aree_verdi = `aree verdi`,
    Ludoteca = ludoteca,
    Campi_sportivi = `campi sportivi`,
    Teatro = teatri,
    Laboratori = laboratori,
    Palestre = palestre,
    Officine = officine,
    Biblioteca = biblioteche,
    Aule = aule,
    Locali_di_culto = `locali di culto`,
    Mensa_detenuti = `mense detenuti`,
    Data_aggiornamento = data_aggiornamento,
    Tasso_sovraffollamento = tasso_sovraffollamento
  )

#### ISTITUTI NON LETTI OGGI: TENGO I DATI DI IERI ####
# prima restavano vuoti e il tasso diventava 0% (cerchio verde sulla mappa)
if (length(falliti) > 0) {
  message("Istituti non letti oggi, uso i dati precedenti: ", paste(falliti, collapse = ", "))
  prec = df_precedente %>% filter(ID_istituto %in% falliti)
  riga = match(prec$ID_istituto, df_finale$ID_istituto)
  fisse = c("ID_istituto", "Nome_istituto", "Regione", "Latitudine", "Longitudine")
  for (col in setdiff(intersect(names(df_finale), names(prec)), fisse)) {
    valori = prec[[col]]
    if (col == "Data_aggiornamento") {
      df_finale[[col]][riga] = as.Date(valori)
    } else if (is.numeric(df_finale[[col]])) {
      df_finale[[col]][riga] = as.numeric(valori)
    } else {
      df_finale[[col]][riga] = as.character(valori)
    }
  }
  df_finale = df_finale %>%
    mutate(Tasso_sovraffollamento = replace_na((Totale_detenuti / (Posti_regolamentari - Posti_non_disponibili)) * 100, 0))
}

#### RIORDINO LE COLONNE ####
df_finale = df_finale %>%
  select(ID_istituto, Nome_istituto, Tasso_sovraffollamento, Totale_detenuti, Posti_regolamentari, Posti_non_disponibili, PolPen_effettivi, PolPen_previsti, Data_aggiornamento, everything())

#### TASSO DI SOVRAFFOLLAMENTO NAZIONALE ####
totale_detenuti = sum(df_finale$Totale_detenuti, na.rm = TRUE)
posti_regolamentari = sum(df_finale$Posti_regolamentari, na.rm = TRUE)
posti_non_disponibili = sum(df_finale$Posti_non_disponibili, na.rm = TRUE)

tasso_nazionale = (totale_detenuti / (posti_regolamentari - posti_non_disponibili))*100

#### CONTROLLO DI PLAUSIBILITA' ####
# valori fuori da questi intervalli indicano quasi certamente un errore di lettura: mi fermo senza scrivere
message("Detenuti totali: ", totale_detenuti, " - tasso nazionale: ", round(tasso_nazionale, 2), "%")
if (!is.finite(tasso_nazionale) || tasso_nazionale < 80 || tasso_nazionale > 200) {
  stop("Tasso nazionale non plausibile (", round(tasso_nazionale, 2), "%): aggiornamento annullato")
}
if (totale_detenuti < 40000 || totale_detenuti > 90000) {
  stop("Numero di detenuti non plausibile (", totale_detenuti, "): aggiornamento annullato")
}

#### SOSTITUISCO IL VECCHIO FOGLIO ####
sheet_write(df_finale, ss = sheet_istituti, sheet = "Dati")

#### TASSO DI SOVRAFFOLLAMENTO A LIVELLO REGIONALE ####
# calcolato come per l'Italia: detenuti della regione / posti disponibili della regione.
# (fino al 2026-11 era la media semplice dei tassi degli istituti, in cui un carcere da 30 detenuti
# pesava quanto uno da 2.000; il nome della colonna resta lo stesso per non rompere la pagina)
tasso_per_regione = df_finale %>%
  group_by(Regione) %>%
  summarise(Tasso_sovraffollamento_medio = sum(Totale_detenuti, na.rm = TRUE) /
              (sum(Posti_regolamentari, na.rm = TRUE) - sum(Posti_non_disponibili, na.rm = TRUE)) * 100) %>%
  arrange(desc(Tasso_sovraffollamento_medio))

#### SOSTIUISCO IL VECCHIO FOGLIO ####
sheet_write(tasso_per_regione, ss = sheet_istituti, sheet = "DatiRegioni")

#### STORICO PER ISTITUTO ####
# ogni giorno la fotografia di tutti gli istituti si aggiunge a data/storico-istituti.csv
# (il workflow poi fa il commit del file). Le date dal 2025-06-15 al 2026-09-18 sono state
# ricostruite dalle versioni pubblicate della tabella Datawrapper, quindi non sono giornaliere.
file_storico = "data/storico-istituti.csv"
oggi_txt = format(Sys.Date(), "%Y-%m-%d")
fotografia = df_finale %>%
  transmute(
    data = oggi_txt,
    ID_istituto, Nome_istituto, Regione,
    Totale_detenuti, Posti_regolamentari, Posti_non_disponibili,
    Tasso_sovraffollamento = round(Tasso_sovraffollamento, 4),
    PolPen_effettivi = as.numeric(PolPen_effettivi),
    PolPen_previsti = as.numeric(PolPen_previsti),
    fonte = ifelse(ID_istituto %in% falliti, "scraper (non letto, dato precedente)", "scraper")
  ) %>%
  mutate(across(everything(), as.character))
storico = if (file.exists(file_storico)) read.csv(file_storico, colClasses = "character") else NULL
if (!is.null(storico)) storico = storico %>% filter(data != oggi_txt) # se il workflow gira due volte nello stesso giorno
storico = bind_rows(storico, fotografia) %>% type.convert(as.is = TRUE)
dir.create("data", showWarnings = FALSE)
write.csv(storico, file_storico, row.names = FALSE, na = "")

#### FINE AGGIORNAMENTO DATI ####

#### INIZIO AGGIORNAMENTO TASSO DI SOVRAFFOLLAMENTO NAZIONALE ####
tasso_oggi = data.frame(
  data = Sys.Date(),
  tasso_sovraffollamento_nazionale = tasso_nazionale
)

sheet_storico = "1REAvN1QFv3IzkbHbI7AICLAhDICeh9Vvd4f_Xk-6vOs"
sheet_append(tasso_oggi, ss = sheet_storico, sheet = "Storico")
#### FINE AGGIORNAMENTO TASSO DI SOVRAFFOLLAMENTO NAZIONALE ####



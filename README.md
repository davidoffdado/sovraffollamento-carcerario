# sovraffollamento-carcerario
Script in R per lo scraping e l'aggiornamento automatico dei dati relativi ai penitenziari italiani.
---

## Il progetto

Questo progetto esegue un **web scraping automatico** dei dati pubblicati dal Ministero della Giustizia e da Ristretti Orizzonti sugli istituti penitenziari italiani. I dati vengono aggiornati quotidianamente con informazioni su:

* Capacità e presenza dei detenuti;
* Presenze del personale (Polizia Penitenziaria, educatori, amministrativi);
* Strutture e servizi interni (docce, aule, mense, ecc.);
* Morti in carcere.
  
Ho raccolto i dati per ogni singolo istituto, calcolato il tasso di sovraffollamento - singolo e nazionale, aggiunto le coordinate geografiche e la regione.

## **Il progetto è visualizzabile online qui**:
[www.davidruffini.com/stato-delle-carceri.html](https://www.davidruffini.com/stato-delle-carceri.html)

---

## Tecnologie utilizzate

* `R` + `tidyverse` per la manipolazione dati;
* `rvest` per lo scraping;
* `furrr` e `future` per la parallelizzazione, al fine di velocizzare lo scraping;
* `googlesheets4` per la connessione a Google Sheets;
* `openxlsx` per l'esportazione.

---

## Sicurezza

La chiave di autenticazione per l’accesso ai Google Sheets è **nascosta** e **non inclusa nel repository**.

---

## Output

I dati vengono salvati su Google Sheets:

1. `Dati` - dataset aggiornato con tasso di sovraffollamento (fotografia del giorno)
2. `DatiRegioni` - tasso di sovraffollamento per regione, calcolato come detenuti della regione diviso posti disponibili della regione (fino a novembre 2026 era la media semplice dei tassi degli istituti)
3. `Morti` - morti in carcere per anno e causa, senza dati personali (nel foglio pubblico degli istituti)
4. `Storico` - storico giornaliero del tasso nazionale
5. `Dati_MortiCarcere` - elenco aggiornato delle morti in carcere (foglio privato)

### Storico per istituto

Ogni giorno la fotografia di tutti gli istituti si aggiunge a
[`data/storico-istituti.csv`](data/storico-istituti.csv) (una riga per istituto per giorno: data,
detenuti, posti, posti non disponibili, tasso, agenti effettivi e previsti), di cui il workflow fa il commit.

Le date dal 15 giugno 2025 al 18 settembre 2026 non sono giornaliere: sono state ricostruite dalle
versioni pubblicate della tabella Datawrapper del progetto (colonna `fonte`). L'8 e il 25 agosto 2025
sono incomplete (169 e 167 istituti su 190). Dal 4 novembre 2026 i dati sono giornalieri.

### Controlli

Prima di scrivere, lo script controlla che siano stati letti almeno il 90% degli istituti e che il
tasso nazionale (80-200%) e il numero di detenuti (40.000-90.000) siano plausibili; altrimenti si
ferma, il workflow fallisce e i dati del giorno prima restano invariati. Gli istituti che non
rispondono mantengono i dati del giorno precedente, con la loro data di aggiornamento.

---

## Come funziona

1. Autenticazione all’account Google per accesso ai fogli
2. Lettura ID istituti già presenti
3. Scraping parallelo delle fonti dati
4. Calcolo dei tassi di sovraffollamento
5. Scrittura dei nuovi dati nei fogli Google
6. Retry intelligente in caso di timeout o errori
7. Estrazione dati separati per le morti in carcere

---

## Pianificazione

Lo script viene eseguito automaticamente ogni giorno tramite GitHub Actions
(workflow `.github/workflows/aggiorna-dati.yml`), quindi non dipende più da un
PC acceso. Può anche essere lanciato manualmente dalla tab "Actions" del
repository ("Run workflow").

### Setup del service account (una tantum)

Per l'autenticazione a Google Sheets in CI serve un service account Google,
perché l'auth interattiva usata in locale non funziona in un ambiente headless:

1. Su [Google Cloud Console](https://console.cloud.google.com/), crea (o riusa)
   un progetto, abilita la **Google Sheets API**, poi crea un service account
   e genera una chiave in formato JSON.
2. Condividi entrambi i Google Sheet (quello degli istituti e quello dello
   storico) con l'email del service account (tipo
   `nome@progetto.iam.gserviceaccount.com`), come editor.
3. Nel repository GitHub: Settings → Secrets and variables → Actions → New
   repository secret, nome `GOOGLE_SERVICE_ACCOUNT_JSON`, incolla il
   contenuto del file JSON della chiave.

In locale lo script continua a funzionare come prima, con `gs4_auth(cache =
".secrets", email = ...)`.

---

## Autore

David Ruffini, <br>
Collaboro come data journalist con il blog Info Data del Sole 24 Ore. <br>
Email: [davidruffini98@gmail.com](mailto:davidruffini98@gmail.com) <br>
Sito personale: [www.davidruffini.com](https://www.davidruffini.com) <br>
X: [https://x.com/davidruffini_] <br>
Instagram: [https://www.instagram.com/david_ruffini/] <br>
Linkedin: [https://www.linkedin.com/in/david-ruffini-56a5a1161/](https://www.linkedin.com/in/david-ruffini-56a5a1161/) <br> <br>
Le segnalazioni sono sempre benvenute. 

---


# sovraffollamento-carcerario
Script in R per lo scraping e l'aggiornamento automatico dei dati relativi ai penitenziari italiani.
---

## Il progetto

Questo progetto esegue un **web scraping automatico** dei dati pubblicati dal Ministero della Giustizia e da Ristretti Orizzonti sugli istituti penitenziari italiani. I dati vengono aggiornati quotidianamente e salvati in tre **fogli di Google Sheets**, con informazioni su:

* Capacità e presenza dei detenuti;
* Presenze del personale (Polizia Penitenziaria, educatori, amministrativi);
* Strutture e servizi interni (docce, aule, mense, ecc.);
* Morti in carcere.
  
Ho raccolto i dati per ogni singolo istituto, calcolato il tasso di sovraffollamento - singolo e nazionale-, aggiunto le coordinate geografiche e la regione.

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

La chiave di autenticazione per l’accesso ai Google Sheets è **nascosta** e **non inclusa nel repository**, in quanto salvata in locale con `gs4_auth(cache = ".secrets")` e **non tracciata da Git**.

---

## Output

I dati vengono salvati su tre fogli principali:

1. `Dati` – dataset aggiornato con tasso di sovraffollamento
2. `Storico` – storico giornaliero del tasso nazionale
3. `Dati_MortiCarcere` – elenco aggiornato delle morti in carcere

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

Lo script è pensato per essere eseguito giornalmente.

---

## Autore

David Ruffini, <br>
Collaboro come data journalist con il blog Info Data del Sole 24 Ore. <br>
Email: [davidruffini98@gmail.com](mailto:davidruffini98@gmail.com) <br>
Sito personale: [www.davidruffini.com](https://www.davidruffini.com) <br>
X: https://x.com/davidruffini_ <br>
Instagram: https://www.instagram.com/david_ruffini/ <br>
Linkedin: [https://www.linkedin.com/in/david-ruffini-56a5a1161/](https://www.linkedin.com/in/david-ruffini-56a5a1161/) <br> <br>
Le segnalazioni sono sempre benvenute. 

---


# Rozszerzona Dokumentacja Techniczna Systemu Bazy Danych

## 1. Środowisko i Technologie
*   **System Zarządzania Bazą Danych (RDBMS):** PostgreSQL (zalecana wersja 14+)
*   **Interfejsy i Narzędzia (GUI):** pgAdmin 4 / DBeaver / DataGrip / psql CLI
*   **Kod bazy danych:** Czysty SQL poszerzony o zagnieżdżony język proceduralny PL/pgSQL wykorzystywany do tworzenia funkcji i wyzwalaczy (triggerów).
*   **Skrypty pomocnicze:** Język Python (plik `db_manager.py`) używany do zautomatyzowania budowy struktury i seeding'u bazy danych.

## 2. Architektura Schematu (Schema `public`)
Projekt wykorzystuje standardowy, pojedynczy schemat relacyjny do przechowywania wszystkich encji. Tabele zostały podzielone na słownikowe (statyczne) oraz operacyjne (transakcyjne).

### 2.1 Tabele słownikowe
Te tabele są rzadko modyfikowane i służą do standaryzacji wpisów w głównej bazie. Usunięcie z nich rekordu używanego przez system jest zablokowane kluczem obcym z opcją `ON DELETE RESTRICT`.
*   `role_uzytkownikow`: Przechowuje kody ról (np. klient, pracownik, admin).
*   `dyscypliny`: Słownik sportów (np. tenis ziemny, squash, badminton).
*   `nawierzchnie`: Słownik rodzajów podłoży (np. mączka, trawa sztuczna, parkiet).

### 2.2 Tabele transakcyjne i główne relacje (1:N, 1:1)
*   **`uzytkownicy`**: Centralna tabela logowania i kontaktu z przypisanym kluczem obcym (1:N) do `role_uzytkownikow`.
*   **`korty`**: Obiekty fizyczne udostępniane do rezerwacji. Posiadają powiązania 1:N z `dyscypliny` oraz `nawierzchnie`. Dodatkowo przechowują flagę `czy_aktywny` oraz stawkę bazową `cena_za_godzine`.
*   **`rezerwacje`**: Kluczowa tabela w systemie. Łączy użytkownika z określonym kortem w danym przedziale czasowym (od-do). 
*   **`platnosci`**: Tabela rozliczeń w relacji 1:1 (`UNIQUE`) względem rezerwacji. Usunięcie rezerwacji kaskadowo usuwa powiązaną płatność (`ON DELETE CASCADE`).
*   **`opinie`**: Tabela sprzężeń zwrotnych, również w relacji 1:1 do zrealizowanej rezerwacji (`ON DELETE CASCADE`). 

## 3. Integralność i Więzy (Constraints)
Zastosowano mechanizmy twardej walidacji danych uniemożliwiające wprowadzenie "śmieciowych" wartości:
*   **CHECK constraints:** 
    *   Wymuszenie poprawności chronologicznej: `CONSTRAINT chk_daty CHECK (data_zakonczenia > data_rozpoczecia)`
    *   Wartości finansowe uodpornione na błędy: `CONSTRAINT chk_cena CHECK (cena_za_godzine > 0)` oraz `CONSTRAINT chk_kwota CHECK (kwota >= 0)`
    *   Oceny zdefiniowane w przedziale: `CONSTRAINT chk_ocena CHECK (ocena BETWEEN 1 AND 5)`
    *   Predefiniowane stany (`ENUM` like check): 
        * Rezerwacje: *oczekujaca, potwierdzona, anulowana, zakonczona*.
        * Płatności: *oczekujaca, zrealizowana, odrzucona, zwrocona*.

## 4. Logika Serwera (PL/pgSQL Triggers)
Logika biznesowa przeniesiona z warstwy aplikacji wprost do jądra bazy danych:

1.  **`trg_rezerwacje_terminy` (Ochrona przed Overbookingiem)**
    *   *Zdarzenie:* BEFORE INSERT OR UPDATE na tabeli `rezerwacje`
    *   *Opis:* Zapytanie wyszukuje wszystkie rezerwacje dla tego samego kortu, których ramy czasowe zachodzą na nowo wprowadzaną rezerwację. W przypadku znalezienia chociaż jednego rekordu (i jeśli nie jest to aktualizowany właśnie rekord) rzuca wyjątek przerywający transakcję.

2.  **`trg_platnosci_rezerwacje` (Automatyzacja statusów)**
    *   *Zdarzenie:* AFTER UPDATE na tabeli `platnosci`
    *   *Opis:* Jeżeli status płatności zmieni się na `zrealizowana`, automatycznie wysyła sygnał UPDATE do tabeli nadrzędnej `rezerwacje`, zamieniając jej status z oczekującej na `potwierdzona`.

3.  **`trg_oblicz_cene` (Silnik cennika)**
    *   *Zdarzenie:* BEFORE INSERT OR UPDATE na tabeli `rezerwacje`
    *   *Opis:* Wylicza pole `cena_calkowita`. Ekstrahuje w locie długość trwania rezerwacji w sekundach, dzieli na godziny (3600.0) i mnoży przez bazową `cena_za_godzine` przypisanego kortu.

4.  **`trg_zabezpiecz_historie` (Ochrona danych dowodowych)**
    *   *Zdarzenie:* BEFORE UPDATE na tabeli `rezerwacje`
    *   *Opis:* Baza chroni "przeszłość". Jeśli `data_rozpoczecia` mija w stosunku do `CURRENT_TIMESTAMP`, trigger pozwala zmienić jedynie ostateczny status rezerwacji (np. na `zakonczona`), ale w pełni blokuje (`RAISE EXCEPTION`) jakąkolwiek próbę zmiany godzin, kortu, czy klienta.

## 5. Zaimplementowane Widoki (Views)
W celu ułatwienia pracy analitykom stworzono 4 zoptymalizowane widoki złączeniowe w pliku `02_views.sql`:
*   **`v_szczegoly_rezerwacji`**: Rozszerza tabelę rezerwacji o złączone dane klientów (imię, nazwisko, email), szczegóły kortów oraz nawierzchni, a także dokleja statuty z płatności i ocen z opinii (LEFT JOIN).
*   **`v_oblozenie_kortow`**: Zestawienie pokazujące sumaryczną liczbę wygenerowanych rezerwacji i godzin zarezerwowanych dla poszczególnych kortów oraz ich średnią ocenę.
*   **`v_przychody_miesieczne`**: Grupowanie analityczne po miesiącach i latach pokazujące przychody z podziałem na statusy płatności (zrealizowane vs oczekujące).
*   **`v_statystyki_klientow`**: Tabela rankingowa klientów pokazująca zsumowaną wydaną przez nich kwotę pieniędzy oraz stosunek rezerwacji zakończonych do anulowanych.

## 6. Zastosowane Indeksy (Performance)
Zastosowano standardowe struktury B-Tree do ułatwienia skanowania dużej ilości danych.
*   Klucze główne (`PRIMARY KEY`) domyślnie posiadają wbudowane indeksy w Postgres.
*   Utworzono dodatkowe indeksy na kluczach obcych (`idx_rezerwacje_uzytkownik`, `idx_rezerwacje_kort`) – rozwiązuje to problem tzw. 'Full Table Scan' przy usuwaniu kaskadowym użytkowników czy kortów.
*   Utworzono indeks kompozytowy `idx_rezerwacje_daty` na parze `(data_rozpoczecia, data_zakonczenia)`, z uwagi na to, że warunek weryfikujący nakładanie się czasów z triggera nr 1 byłby wąskim gardłem bazy danych bez szybkiego dostępu do drzewa dat.

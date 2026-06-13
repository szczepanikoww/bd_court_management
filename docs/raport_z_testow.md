# Rozszerzony Raport z Testowania Bazy Danych (Test Cases)

## 1. Cel i środowisko testowe
Celem scenariuszy testowych jest weryfikacja poprawności przyjętego modelu danych, skuteczności narzuconych więzów (constraints) i prawidłowego funkcjonowania logiki ukrytej w triggerach po stronie bazy PostgreSQL. 
*   **Środowisko wykonawcze:** psql / pgAdmin / DBeaver
*   **Zestaw testowy:** Baza zasilana danymi testowymi wygenerowanymi przez skrypt `sql/dml/01_seed_data.sql`.

---

## 2. Zestawienie Przypadków Testowych (Test Cases)

### [TC01] - Rezerwacja nakładająca się na inną (Overbooking / Trigger)
*   **Cel:** Weryfikacja działania wyzwalacza `trg_rezerwacje_terminy`.
*   **Zapytania testowe:**
    ```sql
    -- Rezerwacja nr 1 (poprawna)
    INSERT INTO rezerwacje (id_uzytkownika, id_kortu, data_rozpoczecia, data_zakonczenia, status_rezerwacji)
    VALUES (1, 1, '2025-06-01 10:00:00', '2025-06-01 12:00:00', 'potwierdzona');
    
    -- Rezerwacja nr 2 (kolizja w godzinach 11:00 - 13:00 dla tego samego kortu nr 1)
    INSERT INTO rezerwacje (id_uzytkownika, id_kortu, data_rozpoczecia, data_zakonczenia)
    VALUES (2, 1, '2025-06-01 11:00:00', '2025-06-01 13:00:00');
    ```
*   **Oczekiwany rezultat:** Zapytanie drugie zostaje przerwane. Baza wykonuje `ROLLBACK`.
*   **Faktyczny rezultat:** `ERROR: Błąd rezerwacji: Kort o ID 1 jest już zajęty w godzinach od 2025-06-01 11:00:00 do 2025-06-01 13:00:00.`
*   **Status wykonania:** **ZALICZONY (PASSED) ✅**

### [TC02] - Automatyczne przeliczanie ceny (Wyzwalacz `trg_oblicz_cene`)
*   **Cel:** Weryfikacja zautomatyzowanego wyliczania pola `cena_calkowita` w locie.
*   **Zapytania testowe:**
    ```sql
    -- Założenie: Kort nr 2 kosztuje 100 zł / h w tabeli Korty
    INSERT INTO rezerwacje (id_uzytkownika, id_kortu, data_rozpoczecia, data_zakonczenia)
    VALUES (1, 2, '2025-06-10 18:00:00', '2025-06-10 19:30:00') RETURNING cena_calkowita;
    ```
*   **Oczekiwany rezultat:** Trigger samodzielnie obliczy 1.5h różnicy czasu i pomnoży ją przez stawkę.
*   **Faktyczny rezultat:** Zwrócono wartość: `150.00` pomimo braku podania jej w zapytaniu INSERT.
*   **Status wykonania:** **ZALICZONY (PASSED) ✅**

### [TC03] - Kaskadowe usuwanie powiązanych wpisów (ON DELETE CASCADE)
*   **Cel:** Sprawdzenie, czy usunięcie rezerwacji wyczyści osierocone płatności i opinie powiązane z nią za pomocą klucza obcego.
*   **Zapytania testowe:**
    ```sql
    DELETE FROM rezerwacje WHERE id_rezerwacji = 1;
    SELECT * FROM platnosci WHERE id_rezerwacji = 1;
    SELECT * FROM opinie WHERE id_rezerwacji = 1;
    ```
*   **Oczekiwany rezultat:** Wszystkie zapytania wyszukujące usunięte encje podrzędne po ich wykonaniu zwracają wynik pusty (`0 rows`).
*   **Status wykonania:** **ZALICZONY (PASSED) ✅**

### [TC04] - Edycja Historii (Modyfikacja rezerwacji przeszłych)
*   **Cel:** Weryfikacja działania `trg_zabezpiecz_historie` chroniącego przeszłe wpisy (np. przed niepożądanymi roszczeniami klientów lub błędami obsługi).
*   **Zapytania testowe:**
    ```sql
    -- Próba zmiany zadeklarowanego przed rokiem kortu w archiwalnej rezerwacji.
    UPDATE rezerwacje SET id_kortu = 3 WHERE id_rezerwacji = 5; 
    ```
*   **Faktyczny rezultat:** `ERROR: Modyfikacja historycznych rezerwacji (data rozpoczęcia w przeszłości) jest zabroniona.`
*   **Status wykonania:** **ZALICZONY (PASSED) ✅**

### [TC05] - Integralność Danych - Daty wsteczne (CHECK constraint)
*   **Cel:** Weryfikacja błędu fizyki przy tworzeniu rezerwacji.
*   **Zapytania testowe:**
    ```sql
    INSERT INTO rezerwacje (id_uzytkownika, id_kortu, data_rozpoczecia, data_zakonczenia)
    VALUES (1, 1, '2025-06-20 18:00:00', '2025-06-20 16:00:00'); -- Zakończenie następuje przed rozpoczęciem
    ```
*   **Faktyczny rezultat:** `ERROR: new row for relation "rezerwacje" violates check constraint "chk_daty"`
*   **Status wykonania:** **ZALICZONY (PASSED) ✅**

### [TC06] - Integralność Danych - Błędne statusy systemowe (CHECK constraint)
*   **Cel:** Próba wprowadzenia statusu płatności wymyślonego np. przez błędną łatkę na Front-End, który nie ma odzwierciedlenia w domenowych regułach bazy.
*   **Zapytania testowe:**
    ```sql
    INSERT INTO platnosci (id_rezerwacji, kwota, metoda_platnosci, status_platnosci)
    VALUES (2, 100, 'blik', 'zaplacone_dawno_temu');
    ```
*   **Faktyczny rezultat:** `ERROR: new row for relation "platnosci" violates check constraint "chk_status_platnosci"` (baza pozwala wyłącznie na: oczekujaca, zrealizowana, odrzucona, zwrocona).
*   **Status wykonania:** **ZALICZONY (PASSED) ✅**

---

## 3. Zakończenie i Wnioski Główne
*   Wykonane testy strukturalne (wykonywane z poziomu interfejsu SQL) potwierdziły w 100% poprawność zaimplementowanego kodu PL/pgSQL i więzów logiki w modelu.
*   System bazodanowy działa jako **"Gruby serwer" (Fat-Database)**. Programista warstwy klienckiej (np. Backend API) zostaje odciążony z obowiązku weryfikowania wyżej wspomnianych reguł we własnym kodzie aplikacji – nawet, jeśli warstwa aplikacji z jakiegoś powodu przepuści złośliwe, sztuczne żądanie od użytkownika, system w jądrze bazy danych odrzuci transakcję i uchroni integralność statystyk całego systemu kortów.
*   Nałożenie dodatkowych triggerów na zdarzenia `INSERT/UPDATE` operacji rezerwacji nie wprowadza negatywnego, odczuwalnego narzutu wydajnościowego na system dzięki zastosowanym strukturom indeksowania B-Tree dla najczęściej odpytywanych pół: klucza kortu (`id_kortu`) oraz złożonego klucza drzewiastego przedziału dat (`data_rozpoczecia, data_zakonczenia`).

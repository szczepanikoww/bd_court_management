# Analiza Wymagań - System Rezerwacji Kortów Sportowych

## 1. Cel i zakres projektu
Celem projektu jest stworzenie struktury relacyjnej bazy danych obsługującej system rezerwacji kortów sportowych. System ma za zadanie zautomatyzować i ustrukturyzować proces zarządzania obiektami, rezerwacjami, użytkownikami, płatnościami oraz systemem opinii. 

## 2. Aktorzy (Grupy użytkowników)
Zgodnie ze strukturą tabeli `role_uzytkownikow`, w systemie przewiduje się następujących aktorów:
*   **Klient:** Użytkownik końcowy, który przegląda ofertę, dokonuje rezerwacji kortów, opłaca je oraz wystawia opinie po zakończonej grze.
*   **Pracownik (Obsługa):** Użytkownik zarządzający codziennymi operacjami, takimi jak weryfikacja płatności gotówkowych, nadzorowanie grafiku rezerwacji i pomoc klientom.
*   **Administrator:** Użytkownik posiadający pełne uprawnienia do zarządzania słownikami (nawierzchnie), dodawania lub dezaktywowania kortów oraz wglądu we wszystkie statystyki i raporty.

## 3. Wymagania funkcjonalne

### 3.1. Zarządzanie użytkownikami
*   System musi umożliwiać rejestrację użytkowników przechowując ich imię, nazwisko, e-mail (który musi być unikalny) oraz telefon.
*   Każdy użytkownik musi mieć bezwzględnie przypisaną rolę determinującą jego uprawnienia.

### 3.2. Zarządzanie infrastrukturą sportową
*   System musi przechowywać pełne informacje o kortach, w tym: nazwa, rodzaj nawierzchni, informacja o zadaszeniu oraz przypisana cena za godzinę.
*   Korty mogą być tymczasowo lub trwale wyłączone z użytku (flaga `czy_aktywny`), co powinno natychmiast blokować możliwość ich dalszej rezerwacji.
*   Słownik rodzajów nawierzchni musi być w pełni rozszerzalny.

### 3.3. Obsługa rezerwacji
*   Użytkownik musi mieć możliwość zarezerwowania kortu określając czas rozpoczęcia i zakończenia.
*   System musi samodzielnie i automatycznie wyliczać całkowitą cenę rezerwacji na podstawie różnicy czasu jej trwania oraz godzinowej stawki wybranego kortu.
*   Rezerwacje muszą poprawnie przyjmować i przechodzić przez statusy: `oczekujaca`, `potwierdzona`, `anulowana`, `zakonczona`.
*   System musi bezwzględnie i automatycznie blokować na poziomie samej bazy próby dokonania podwójnej rezerwacji (nakładanie się terminów na tym samym korcie).

### 3.4. Obsługa płatności
*   Każda rezerwacja musi być powiązana z dokładnie jedną określoną transakcją płatniczą.
*   Obsługiwane metody płatności to ściśle zdefiniowana lista: `karta`, `przelew`, `gotowka`, `blik`.
*   Dozwolone statusy płatności to: `oczekujaca`, `zrealizowana`, `odrzucona`, `zwrocona`.
*   Zmiana statusu płatności musi automatycznie aktualizować status powiązanej rezerwacji (np. opłacenie przez BLIK = zrealizowana płatność -> automatycznie potwierdzona rezerwacja).

### 3.5. System opinii
*   Klienci mają możliwość wystawienia oceny zadowolenia (w sztywnej skali 1-5) oraz opcjonalnego komentarza tekstowego.
*   Opinia może zostać wystawiona wyłącznie raz dla danej, sfinalizowanej rezerwacji (relacja 1:1).

### 3.6. Raportowanie i statystyki
*   Baza ma dostarczać gotowe widoki (views) lub procedury ułatwiające analitykom biznesowym pobranie danych (wskaźniki obłożenia, przychody, popularność nawierzchni i klientów).

## 4. Wymagania niefunkcjonalne
*   **Technologia:** Baza danych oparta o otwarty system RDBMS **PostgreSQL** w celu wsparcia zaawansowanych wyzwalaczy.
*   **Integralność danych:** System musi wykorzystywać klucze obce (z kaskadowym usuwaniem `ON DELETE CASCADE` dla rezerwacji lub blokowaniem usuwania `ON DELETE RESTRICT` dla słowników), aby nie dopuścić do niespójności danych.
*   **Wydajność:** Wymagane jest optymalizowanie głównych zapytań poprzez tworzenie indeksów na krytycznych kolumnach (daty, klucze obce użytkowników i kortów).
*   **Automatyzacja logiki (Gruby Serwer Bazy Danych):** Należy odciążyć warstwę aplikacji poprzez implementację kluczowych mechanizmów walidacyjnych i wyliczeniowych w wyzwalaczach (`triggers`) na poziomie samej bazy danych.

## 5. Reguły biznesowe (Business Rules)
System wymusza na poziomie silnika bazy danych następujące żelazne zasady (poprzez CHECK Constraints i Triggery):
1.  Data zakończenia rezerwacji zawsze musi być fizycznie późniejsza niż data jej rozpoczęcia.
2.  Całkowity koszt rezerwacji oraz kwota płatności nigdy nie mogą spaść poniżej 0.00.
3.  Surowo zabronione jest przypisywanie rezerwacji do kortu, którego status `czy_aktywny` to FALSE.
4.  W przypadku detekcji kolizji czasu dwóch rezerwacji dla tego samego kortu, żądanie SQL zostaje bezwarunkowo przerwane z rzuceniem wyjątku (Exception).
5.  Rezerwacje historyczne (takie, których data rozpoczęcia wpadła do przeszłości względem obecnego czasu serwera) wchodzą w tryb ochrony – zabrania się modyfikacji w nich pola użytkownika, wybranego kortu, przedziału czasowego oraz kosztów.

Oto szczegółowe omówienie każdego z plików `.sql` w Twoim projekcie, z podziałem na ich logiczne zastosowanie:

### DDL (Struktura i Definicje)

*   **[01_tables.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/ddl/01_tables.sql) (Struktura tabel)**
    Jest to absolutny fundament Twojej bazy danych. Plik ten odpowiada za usunięcie starych tabel (jeśli istnieją) i utworzenie ich od nowa. 
    *   Definiuje słowniki: `role_uzytkownikow` oraz `nawierzchnie`.
    *   Tworzy główne tabele encji: `uzytkownicy` (zależni od ról) oraz `korty` (zależne od nawierzchni).
    *   Tworzy tabele operacyjne: `rezerwacje`, `platnosci` oraz `opinie`. 
    *   **Szczegóły techniczne:** Skrypt ten dba o integralność danych, definiując klucze obce (zapobiegając np. usunięciu użytkownika, który ma rezerwacje) oraz tzw. "Check constraints" (np. wymuszając, by `cena_calkowita` była $\ge 0$, oceny mieściły się w skali 1-5, a data zakończenia rezerwacji była zawsze po dacie jej rozpoczęcia). Na końcu zakłada indeksy na kolumny najczęściej używane w zapytaniach (np. daty i identyfikatory w rezerwacjach), co znacznie przyspiesza działanie bazy.

*   **[02_views.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/ddl/02_views.sql) (Perspektywy / Widoki)**
    Tworzy wirtualne tabele, które same nie przechowują danych, ale są "zapisanymi na stałe" bardzo złożonymi zapytaniami. Służą one ukryciu skomplikowanych złączeń (`JOIN`) wielu tabel.
    *   `v_szczegoly_rezerwacji`: Łączy w jednym miejscu absolutnie wszystko, co wiemy o danej rezerwacji – imię i e-mail klienta, parametry kortu, status opłaty i ewentualną pozostawioną opinię.
    *   `v_oblozenie_kortow`: Grupuje dane po kortach. Oblicza ile godzin dany kort "przepracował" i wyciąga średnią ocenę pozostawioną przez graczy.
    *   `v_przychody_miesieczne`: Agreguje finanse, wyciągając z dat miesiąc i rok. Wylicza ile realnie zarobiono (status "zrealizowana"), a ile zadeklarowano (status "oczekująca").
    *   `v_statystyki_klientow`: Podsumowuje aktywność każdego użytkownika – ile wydał łącznie pieniędzy i jaki ma stosunek rezerwacji zakończonych do anulowanych.

*   **[03_functions.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/ddl/03_functions.sql) (Logika biznesowa bazy)**
    Zamiast przetwarzać wszystko w aplikacji (np. w kodzie backendu), część najważniejszej logiki umieszczono wewnątrz samej bazy, co gwarantuje szybkość i mniejsze ryzyko błędów.
    *   `fn_sprawdz_dostepnosc_kortu`: Zwraca prawdę lub fałsz. Zlicza, czy w podanym przez klienta terminie istnieje już jakaś inna rezerwacja posiadająca status "potwierdzona" lub "oczekująca".
    *   `fn_oblicz_cene_rezerwacji`: Na podstawie czasu w godzinach i ceny bazowej danego kortu, wylicza dokładny koszt rezerwacji z zaokrągleniem do 2 miejsc po przecinku.
    *   `proc_zloz_rezerwacje`: Główna "akcja" w systemie. Klient wywołuje tę procedurę, a ona: (1) sprawdza dostępność, (2) wylicza cenę, (3) zapisuje rezerwację do bazy, (4) automatycznie generuje powiązany wpis w tabeli płatności z informacją, że system oczekuje na wpłatę.

*   **[04_triggers.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/ddl/04_triggers.sql) (Wyzwalacze i Automatyzacja)**
    Triggery to skrypty, które "odpalają się" całkowicie automatycznie w tle, reagując na próby wpisania czegoś do bazy.
    *   `trg_rezerwacje_terminy`: Reaguje tuż przed dopisaniem rezerwacji. Pełni rolę tarczy obronnej przed podwójnym zajęciem tego samego terminu ("overbookingiem"). Jeśli wykryje nałożenie się na inną rezerwację, brutalnie odrzuca taką operację, zwracając błąd.
    *   `trg_platnosci_rezerwacje`: Automatyzuje procesy biurowe. Gdy zewnętrzny system księgowy (np. Blik) zgłosi, że wpłata została zmieniona na "zrealizowana", wyzwalacz automatycznie namierzy odpowiednią rezerwację i zmieni jej status na "potwierdzona". W przypadku statusu "odrzucona", rezerwacja stanie się "anulowana".

*   **[05_security.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/ddl/05_security.sql) (Zabezpieczenia i Uprawnienia)**
    Zarządza polityką dostępu do danych w modelu RBAC (Role-Based Access Control) i RLS (Row-Level Security).
    *   Kasuje stare i tworzy nowe role: `rola_klient`, `rola_pracownik` i `rola_admin`.
    *   Kategoryzuje co komu wolno. Klient może odczytywać oferty kortów i dodawać rezerwacje. Pracownik może je do tego edytować i usuwać. Administrator może robić wszystko.
    *   **Row Level Security:** To niezwykle silne zabezpieczenie włączone na rezerwacjach i płatnościach. Chroni przed sytuacją, w której haker posiadający rolę klienta próbuje podglądać rezerwacje innych osób. Baza wymusza regułę: "Pokażę ci ten rekord rezerwacji tylko wtedy, kiedy wpisane w nim Twoje ID uzytkownika pokrywa się z Twoim aktualnym zalogowanym mailem". 

### DML (Zasilanie danymi)

*   **[01_seed_data.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/dml/01_seed_data.sql) (Skrypt inicjujący)**
    Kiedy wdrażasz projekt (lub resetujesz środowisko deweloperskie), baza jest pusta. Ten plik brutalnie czyści wszystkie ewentualne pozostałości z tabel, resetuje liczniki kluczy głównych, a następnie "wstrzykuje" pulę danych testowych. Zawiera predefiniowanych pracowników (np. administrator Maria Dąbrowska), zbiór różnych kortów, halę squash, kilka symulowanych zrealizowanych rezerwacji wraz z uiszczonymi wpłatami oraz pozostawionymi ocenami (od 1 do 5). Dzięki temu plikowi możesz od razu testować, jak system zachowa się w akcji.

### Queries (Analiza i Operacje)

*   **[reports.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/queries/reports.sql) (Raportowanie)**
    Przykłady gotowych, skomplikowanych zapytań `SELECT`, które zarząd kompleksu sportowego chciałby widzieć w panelu administratora. Zapytania te intensywnie korzystają z widoków zbudowanych w `02_views.sql`. Wyliczają np. procentowy współczynnik wykorzystania danego kortu, przychody generowane dla konkretnych obiektów, generują ładnie sformatowane agregacje opinii i komentarzy dla poszczególnych obiektów, czy też budują ranking najlepszych klientów na podstawie pozostawionych pieniędzy przy użyciu funkcji rankingowej `DENSE_RANK()`.

*   **[transactions.sql](file:///D:/STUDIA%20DYSK/6%20sem/projekt_bazy/sql/queries/transactions.sql) (Demonstracja izolacji transakcji)**
    Plik ten jest techniczną demonstracją pokazującą świadomość tego, jak działa współbieżność bazodanowa. 
    *   Otwiera kilka sesji transakcji (`BEGIN;`) na różnych poziomach izolacji (np. `READ COMMITTED`, `SERIALIZABLE`, `READ UNCOMMITTED`). 
    *   W jednej z transakcji upewnia się, że cena kortu nie zmieni się nagle, blokując cały jego rekord instrukcją `SELECT ... FOR UPDATE`.
    *   Demonstruje próbę zarezerwowania kortu krok po kroku za pomocą wywołań procedury, zapewniając przy tym bezpieczeństwo i rygor zachowania spójności dla systemu kasowego.

-- Skrypt SQL: Mechanizmy transakcyjne i poziomy izolacji
-- Baza danych: PostgreSQL
--
-- Ten plik ilustruje dwa główne podejścia do zapobiegania anomalii "podwójnej rezerwacji" 
-- (dwóch klientów rezerwujących ten sam kort w tym samym czasie).

-- ============================================================================
-- SCENARIUSZ 1: BLOKOWANIE PESYMISTYCZNE (SELECT ... FOR UPDATE)
-- Działa na poziomie izolacji READ COMMITTED (domyślnym). Blokuje wiersz kortu,
-- zmuszając inne transakcje do poczekania, aż bieżąca transakcja zakończy się (COMMIT/ROLLBACK).
-- ============================================================================

-- Transakcja A (Klient Jan Kowalski rezerwuje Kort A)
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- 1. Zablokowanie rekordu kortu na czas sprawdzania i zapisu.
-- Każda inna transakcja próbująca wykonać SELECT ... FOR UPDATE dla tego samego id_kortu zostanie zawieszona.
SELECT id_kortu, nazwa, cena_za_godzine 
FROM korty 
WHERE id_kortu = 1 
FOR UPDATE;

-- 2. Sprawdzenie dostępności terminu (wywołanie naszej funkcji)
-- Skoro wiersz jest zablokowany, mamy gwarancję, że nikt w tym momencie nie wstawia rezerwacji równolegle.
SELECT fn_sprawdz_dostepnosc_kortu(1, '2026-06-20 12:00:00', '2026-06-20 14:00:00');

-- 3. Jeśli wynik to TRUE, wykonujemy rezerwację
CALL proc_zloz_rezerwacje(
    1, 1, 
    '2026-06-20 12:00:00'::timestamp, 
    '2026-06-20 14:00:00'::timestamp, 
    NULL, NULL
);

-- Zapisanie transakcji (zwolnienie blokady FOR UPDATE)
COMMIT;


-- ============================================================================
-- SCENARIUSZ 2: IZOLACJA SZEREGOWALNA (SERIALIZABLE)
-- Najwyższy poziom izolacji. Nie blokuje wierszy zawczasu, ale jeśli PostgreSQL
-- wykryje, że doszło do anomalii zapisu (write skew) z powodu współbieżnego
-- wykonania, druga transakcja zostanie natychmiast wycofana z błędem 40001 (serialization_failure).
-- Aplikacja musi wtedy ponowić transakcję.
-- ============================================================================

-- Transakcja B (Klient Anna Nowak próbuje rezerwować ten sam termin równolegle)
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- 1. Sprawdzenie wolnego terminu
SELECT fn_sprawdz_dostepnosc_kortu(1, '2026-06-20 12:00:00', '2026-06-20 14:00:00');

-- 2. Załóżmy, że Transakcja A jeszcze się nie zatwierdziła, więc funkcja zwraca TRUE.
-- Próbujemy wstawić rezerwację:
CALL proc_zloz_rezerwacje(
    2, 1, 
    '2026-06-20 12:00:00'::timestamp, 
    '2026-06-20 14:00:00'::timestamp, 
    NULL, NULL
);

-- 3. W momencie próby wykonania COMMIT (jeśli Transakcja A zatwierdziła się pierwsza):
-- PostgreSQL rzuci błąd: "ERROR: could not serialize access due to read/write dependencies among transactions"
COMMIT;


-- ============================================================================
-- SCENARIUSZ 3: DEMONSTRACJA BRUDNEGO ODCZYTU (DIRTY READ)
-- W PostgreSQL poziom READ UNCOMMITTED działa jak READ COMMITTED. 
-- PostgreSQL NIE DOPUSZCZA do brudnych odczytów w żadnym trybie.
-- ============================================================================
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Nie zobaczymy tu niezatwierdzonych rezerwacji innych użytkowników.
SELECT * FROM rezerwacje;

COMMIT;

-- Skrypt DDL: Bezpieczeństwo Danych (Role, Uprawnienia i Row-Level Security)
-- Baza danych: PostgreSQL

-- Usunięcie starych ról jeśli istnieją
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rola_klient') THEN
        DROP ROLE rola_klient;
    END IF;
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rola_pracownik') THEN
        DROP ROLE rola_pracownik;
    END IF;
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rola_admin') THEN
        DROP ROLE rola_admin;
    END IF;
END $$;

-- ============================================================================
-- 1. TWORZENIE RÓL BAZODANOWYCH
-- ============================================================================
CREATE ROLE rola_klient NOLOGIN;
CREATE ROLE rola_pracownik NOLOGIN;
CREATE ROLE rola_admin NOLOGIN;

-- Nadanie dostępu do schematu publicznego
GRANT USAGE ON SCHEMA public TO rola_klient;
GRANT USAGE ON SCHEMA public TO rola_pracownik;
GRANT ALL PRIVILEGES ON SCHEMA public TO rola_admin;

-- ============================================================================
-- 2. NADAWANIE UPRAWNIEŃ DO TABEL
-- ============================================================================

-- Rola: KLIENT
-- Klient może tylko przeglądać korty, słowniki i opinie
GRANT SELECT ON korty, dyscypliny, nawierzchnie, opinie TO rola_klient;
-- Klient może rezerwować i opłacać swoje rezerwacje
GRANT SELECT, INSERT, UPDATE ON rezerwacje, platnosci TO rola_klient;
-- Klient może dodawać opinie do swoich rezerwacji
GRANT INSERT ON opinie TO rola_klient;
-- Dostęp do sekwencji (wymagany przy dodawaniu rezerwacji/płatności/opinii)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rola_klient;

-- Rola: PRACOWNIK
-- Pracownik zarządza rezerwacjami, klientami i płatnościami na miejscu
GRANT SELECT, INSERT, UPDATE, DELETE ON uzytkownicy, korty, rezerwacje, platnosci, opinie, dyscypliny, nawierzchnie TO rola_pracownik;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rola_pracownik;

-- Rola: ADMIN
-- Administrator posiada pełne uprawnienia do modyfikacji struktury i danych
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rola_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rola_admin;

-- ============================================================================
-- 3. ROW-LEVEL SECURITY (RLS) - BEZPIECZEŃSTWO NA POZIOMIE WIERSZY
-- ============================================================================
-- Domyślnie tabele są dostępne dla każdego, kto ma uprawnienia tabeli.
-- Włączenie RLS powoduje uruchomienie polityk sprawdzających dostęp do każdego wiersza.

ALTER TABLE rezerwacje ENABLE ROW LEVEL SECURITY;
ALTER TABLE platnosci ENABLE ROW LEVEL SECURITY;

-- Usunięcie starych polityk bezpieczeństwa
DROP POLICY IF EXISTS policy_rezerwacje_klient ON rezerwacje;
DROP POLICY IF EXISTS policy_platnosci_klient ON platnosci;

-- Polityka dla tabeli REZERWACJE
-- Klient widzi tylko swoje rezerwacje i może wstawiać tylko rezerwacje dla swojego ID.
-- Wykorzystuje parametr sesyjny 'app.biezacy_email_uzytkownika'.
CREATE POLICY policy_rezerwacje_klient ON rezerwacje
    FOR ALL
    TO rola_klient
    USING (
        id_uzytkownika = (
            SELECT id_uzytkownika FROM uzytkownicy 
            WHERE email = current_setting('app.biezacy_email_uzytkownika', true)
        )
    )
    WITH CHECK (
        id_uzytkownika = (
            SELECT id_uzytkownika FROM uzytkownicy 
            WHERE email = current_setting('app.biezacy_email_uzytkownika', true)
        )
    );

-- Polityka dla tabeli PLATNOSCI
-- Klient widzi tylko płatności powiązane ze swoimi rezerwacjami.
CREATE POLICY policy_platnosci_klient ON platnosci
    FOR ALL
    TO rola_klient
    USING (
        id_rezerwacji IN (
            SELECT id_rezerwacji FROM rezerwacje 
            WHERE id_uzytkownika = (
                SELECT id_uzytkownika FROM uzytkownicy 
                WHERE email = current_setting('app.biezacy_email_uzytkownika', true)
            )
        )
    );

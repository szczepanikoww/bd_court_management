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

CREATE ROLE rola_klient NOLOGIN;
CREATE ROLE rola_pracownik NOLOGIN;
CREATE ROLE rola_admin NOLOGIN;

GRANT USAGE ON SCHEMA public TO rola_klient;
GRANT USAGE ON SCHEMA public TO rola_pracownik;
GRANT ALL PRIVILEGES ON SCHEMA public TO rola_admin;

GRANT SELECT ON korty, dyscypliny, nawierzchnie, opinie TO rola_klient;
GRANT SELECT, INSERT, UPDATE ON rezerwacje, platnosci TO rola_klient;
GRANT INSERT ON opinie TO rola_klient;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rola_klient;

GRANT SELECT, INSERT, UPDATE, DELETE ON uzytkownicy, korty, rezerwacje, platnosci, opinie, dyscypliny, nawierzchnie TO rola_pracownik;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rola_pracownik;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rola_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rola_admin;

ALTER TABLE rezerwacje ENABLE ROW LEVEL SECURITY;
ALTER TABLE platnosci ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS policy_rezerwacje_klient ON rezerwacje;
DROP POLICY IF EXISTS policy_platnosci_klient ON platnosci;

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

CREATE OR REPLACE FUNCTION trg_fn_sprawdz_nakladanie_terminow()
RETURNS TRIGGER AS $$
DECLARE
    v_kolizje INT;
    v_czy_aktywny BOOLEAN;
BEGIN
    SELECT czy_aktywny INTO v_czy_aktywny FROM korty WHERE id_kortu = NEW.id_kortu;
    IF v_czy_aktywny IS NOT TRUE THEN
        RAISE EXCEPTION 'Nie można zarezerwować nieaktywnego kortu (ID: %).', NEW.id_kortu;
    END IF;

    IF NEW.status_rezerwacji IN ('oczekujaca', 'potwierdzona', 'zakonczona') THEN
        SELECT COUNT(*)
        INTO v_kolizje
        FROM rezerwacje
        WHERE id_kortu = NEW.id_kortu
          AND status_rezerwacji IN ('oczekujaca', 'potwierdzona', 'zakonczona')
          AND data_rozpoczecia < NEW.data_zakonczenia
          AND data_zakonczenia > NEW.data_rozpoczecia
          AND id_rezerwacji <> COALESCE(NEW.id_rezerwacji, -1);

        IF v_kolizje > 0 THEN
            RAISE EXCEPTION 'Błąd rezerwacji: Kort o ID % jest już zajęty w godzinach od % do %.',
                NEW.id_kortu, NEW.data_rozpoczecia, NEW.data_zakonczenia;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_rezerwacje_terminy ON rezerwacje;
CREATE TRIGGER trg_rezerwacje_terminy
BEFORE INSERT OR UPDATE ON rezerwacje
FOR EACH ROW
EXECUTE FUNCTION trg_fn_sprawdz_nakladanie_terminow();

CREATE OR REPLACE FUNCTION trg_fn_aktualizuj_status_rezerwacji_po_platnosci()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_platnosci = 'zrealizowana' AND (OLD.status_platnosci IS NULL OR OLD.status_platnosci != 'zrealizowana') THEN
        UPDATE rezerwacje
        SET status_rezerwacji = 'potwierdzona'
        WHERE id_rezerwacji = NEW.id_rezerwacji;

    ELSIF NEW.status_platnosci = 'odrzucona' AND (OLD.status_platnosci IS NULL OR OLD.status_platnosci != 'odrzucona') THEN
        UPDATE rezerwacje
        SET status_rezerwacji = 'anulowana'
        WHERE id_rezerwacji = NEW.id_rezerwacji;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_platnosci_rezerwacje ON platnosci;
CREATE TRIGGER trg_platnosci_rezerwacje
AFTER UPDATE ON platnosci
FOR EACH ROW
EXECUTE FUNCTION trg_fn_aktualizuj_status_rezerwacji_po_platnosci();

-- ==============================================================================
-- TRIGGER: Automatyczne obliczanie ceny całkowitej (cena_calkowita)
-- ==============================================================================
CREATE OR REPLACE FUNCTION trg_fn_oblicz_cene_calkowita()
RETURNS TRIGGER AS $$
DECLARE
    v_cena_za_godzine DECIMAL(10, 2);
    v_czas_w_godzinach NUMERIC;
BEGIN
    SELECT cena_za_godzine INTO v_cena_za_godzine FROM korty WHERE id_kortu = NEW.id_kortu;
    
    v_czas_w_godzinach := EXTRACT(EPOCH FROM (NEW.data_zakonczenia - NEW.data_rozpoczecia)) / 3600.0;
    NEW.cena_calkowita := ROUND((v_czas_w_godzinach * v_cena_za_godzine)::numeric, 2);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oblicz_cene ON rezerwacje;
CREATE TRIGGER trg_oblicz_cene
BEFORE INSERT OR UPDATE ON rezerwacje
FOR EACH ROW
EXECUTE FUNCTION trg_fn_oblicz_cene_calkowita();

-- ==============================================================================
-- TRIGGER: Zabezpieczenie danych historycznych
-- ==============================================================================
CREATE OR REPLACE FUNCTION trg_fn_zabezpiecz_historie()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.data_rozpoczecia < CURRENT_TIMESTAMP THEN
        IF NEW.id_uzytkownika != OLD.id_uzytkownika OR
           NEW.id_kortu != OLD.id_kortu OR
           NEW.data_rozpoczecia != OLD.data_rozpoczecia OR
           NEW.data_zakonczenia != OLD.data_zakonczenia OR
           NEW.cena_calkowita != OLD.cena_calkowita 
        THEN
            RAISE EXCEPTION 'Modyfikacja historycznych rezerwacji (data rozpoczęcia w przeszłości) jest zabroniona.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_zabezpiecz_historie ON rezerwacje;
CREATE TRIGGER trg_zabezpiecz_historie
BEFORE UPDATE ON rezerwacje
FOR EACH ROW
EXECUTE FUNCTION trg_fn_zabezpiecz_historie();

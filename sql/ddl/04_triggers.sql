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

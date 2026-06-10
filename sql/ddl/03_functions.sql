-- Skrypt DDL: Funkcje i procedury składowane (PL/pgSQL)
-- Baza danych: PostgreSQL

-- 1. Funkcja sprawdzająca dostępność kortu w zadanym terminie
CREATE OR REPLACE FUNCTION fn_sprawdz_dostepnosc_kortu(
    p_id_kortu INT,
    p_data_rozp TIMESTAMP,
    p_data_zak TIMESTAMP
)
RETURNS BOOLEAN AS $$
DECLARE
    v_kolizje INT;
    v_czy_aktywny BOOLEAN;
BEGIN
    -- Sprawdzenie czy kort istnieje i jest aktywny
    SELECT czy_aktywny INTO v_czy_aktywny FROM korty WHERE id_kortu = p_id_kortu;
    IF v_czy_aktywny IS NOT TRUE THEN
        RETURN FALSE;
    END IF;

    -- Zliczenie rezerwacji nakładających się czasowo
    -- Dwie rezerwacje (A i B) nakładają się, gdy: A.start < B.end ORAZ A.end > B.start
    SELECT COUNT(*)
    INTO v_kolizje
    FROM rezerwacje
    WHERE id_kortu = p_id_kortu
      AND status_rezerwacji IN ('oczekujaca', 'potwierdzona', 'zakonczona')
      AND data_rozpoczecia < p_data_zak
      AND data_zakonczenia > p_data_rozp;

    IF v_kolizje > 0 THEN
        RETURN FALSE; -- Brak dostępności (kolizja)
    ELSE
        RETURN TRUE;  -- Wolny termin
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. Funkcja obliczająca cenę rezerwacji na podstawie czasu trwania i stawki godzinowej kortu
CREATE OR REPLACE FUNCTION fn_oblicz_cene_rezerwacji(
    p_id_kortu INT,
    p_data_rozp TIMESTAMP,
    p_data_zak TIMESTAMP
)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_cena_h DECIMAL(10, 2);
    v_godziny DOUBLE PRECISION;
BEGIN
    -- Pobranie ceny za godzinę dla danego kortu
    SELECT cena_za_godzine INTO v_cena_h FROM korty WHERE id_kortu = p_id_kortu;
    
    IF v_cena_h IS NULL THEN
        RAISE EXCEPTION 'Kort o ID % nie istnieje.', p_id_kortu;
    END IF;

    -- Obliczenie liczby godzin (różnica w sekundach / 3600)
    v_godziny := EXTRACT(EPOCH FROM (p_data_zak - p_data_rozp)) / 3600.0;
    
    IF v_godziny <= 0 THEN
        RAISE EXCEPTION 'Data zakończenia musi być późniejsza niż data rozpoczęcia.';
    END IF;

    RETURN ROUND((v_cena_h * v_godziny)::numeric, 2);
END;
$$ LANGUAGE plpgsql;

-- 3. Procedura składania nowej rezerwacji wraz z kalkulacją ceny i walidacją
CREATE OR REPLACE PROCEDURE proc_zloz_rezerwacje(
    p_id_uzytkownika INT,
    p_id_kortu INT,
    p_data_rozp TIMESTAMP,
    p_data_zak TIMESTAMP,
    INOUT p_id_rezerwacji INT DEFAULT NULL,
    OUT p_cena_calkowita DECIMAL(10, 2)
)
AS $$
DECLARE
    v_dostepny BOOLEAN;
BEGIN
    -- 1. Sprawdzenie czy termin jest wolny
    v_dostepny := fn_sprawdz_dostepnosc_kortu(p_id_kortu, p_data_rozp, p_data_zak);
    
    IF NOT v_dostepny THEN
        RAISE EXCEPTION 'Kort jest niedostępny (zajęty lub nieaktywny) w podanym przedziale czasowym.';
    END IF;

    -- 2. Obliczenie ceny rezerwacji
    p_cena_calkowita := fn_oblicz_cene_rezerwacji(p_id_kortu, p_data_rozp, p_data_zak);

    -- 3. Wstawienie rekordu rezerwacji
    INSERT INTO rezerwacje (id_uzytkownika, id_kortu, data_rozpoczecia, data_zakonczenia, status_rezerwacji, cena_calkowita)
    VALUES (p_id_uzytkownika, p_id_kortu, p_data_rozp, p_data_zak, 'oczekujaca', p_cena_calkowita)
    RETURNING id_rezerwacji INTO p_id_rezerwacji;

    -- 4. Automatyczne wygenerowanie rekordu płatności o statusie 'oczekujaca'
    INSERT INTO platnosci (id_rezerwacji, kwota, metoda_platnosci, status_platnosci)
    VALUES (p_id_rezerwacji, p_cena_calkowita, 'blik', 'oczekujaca');
    
    RAISE NOTICE 'Rezerwacja o ID % została pomyślnie utworzona. Cena: % PLN.', p_id_rezerwacji, p_cena_calkowita;
END;
$$ LANGUAGE plpgsql;

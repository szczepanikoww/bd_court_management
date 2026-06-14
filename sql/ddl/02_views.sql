DROP VIEW IF EXISTS v_statystyki_klientow CASCADE;
DROP VIEW IF EXISTS v_przychody_miesieczne CASCADE;
DROP VIEW IF EXISTS v_oblozenie_kortow CASCADE;
DROP VIEW IF EXISTS v_szczegoly_rezerwacji CASCADE;

CREATE VIEW v_szczegoly_rezerwacji AS
SELECT 
    r.id_rezerwacji,
    u.id_uzytkownika,
    u.imie || ' ' || u.nazwisko AS klient,
    u.email AS klient_email,
    k.id_kortu,
    k.nazwa AS nazwa_kortu,
    n.nazwa_nawierzchni AS typ_nawierzchni,
    r.data_rozpoczecia,
    r.data_zakonczenia,
    r.data_zakonczenia - r.data_rozpoczecia AS czas_trwania,
    r.status_rezerwacji,
    r.cena_calkowita,
    p.id_platnosci,
    p.metoda_platnosci,
    p.status_platnosci,
    o.ocena AS ocena_klienta,
    o.komentarz AS opinia_klienta
FROM rezerwacje r
JOIN uzytkownicy u ON r.id_uzytkownika = u.id_uzytkownika
JOIN korty k ON r.id_kortu = k.id_kortu
JOIN nawierzchnie n ON k.id_nawierzchni = n.id_nawierzchni
LEFT JOIN platnosci p ON r.id_rezerwacji = p.id_rezerwacji
LEFT JOIN opinie o ON r.id_rezerwacji = o.id_rezerwacji;

CREATE VIEW v_oblozenie_kortow AS
SELECT 
    k.id_kortu,
    k.nazwa,
    k.cena_za_godzine,
    COUNT(r.id_rezerwacji) AS liczba_rezerwacji,
    COALESCE(SUM(EXTRACT(EPOCH FROM (r.data_zakonczenia - r.data_rozpoczecia))/3600.0), 0) AS suma_godzin,
    ROUND(AVG(o.ocena), 2) AS srednia_ocena
FROM korty k
LEFT JOIN rezerwacje r ON k.id_kortu = r.id_kortu AND r.status_rezerwacji IN ('potwierdzona', 'zakonczona')
LEFT JOIN opinie o ON r.id_rezerwacji = o.id_rezerwacji
GROUP BY k.id_kortu, k.nazwa, k.cena_za_godzine;

CREATE VIEW v_przychody_miesieczne AS
SELECT 
    EXTRACT(YEAR FROM COALESCE(p.data_platnosci, r.data_rozpoczecia))::INTEGER AS rok,
    EXTRACT(MONTH FROM COALESCE(p.data_platnosci, r.data_rozpoczecia))::INTEGER AS miesiac,
    COUNT(r.id_rezerwacji) AS liczba_rezerwacji,
    SUM(CASE WHEN p.status_platnosci = 'zrealizowana' THEN p.kwota ELSE 0 END) AS przychod_zrealizowany,
    SUM(CASE WHEN p.status_platnosci = 'oczekujaca' THEN r.cena_calkowita ELSE 0 END) AS przychod_oczekujacy,
    SUM(r.cena_calkowita) AS wartosc_calkowita_rezerwacji
FROM rezerwacje r
LEFT JOIN platnosci p ON r.id_rezerwacji = p.id_rezerwacji
WHERE r.status_rezerwacji != 'anulowana'
GROUP BY 
    EXTRACT(YEAR FROM COALESCE(p.data_platnosci, r.data_rozpoczecia)), 
    EXTRACT(MONTH FROM COALESCE(p.data_platnosci, r.data_rozpoczecia));

CREATE VIEW v_statystyki_klientow AS
SELECT 
    u.id_uzytkownika,
    u.imie || ' ' || u.nazwisko AS klient,
    u.email,
    ru.nazwa_roli AS rola_uzytkownika,
    COUNT(r.id_rezerwacji) AS suma_rezerwacji,
    SUM(CASE WHEN r.status_rezerwacji = 'zakonczona' THEN 1 ELSE 0 END) AS rezerwacje_zakonczone,
    SUM(CASE WHEN r.status_rezerwacji = 'anulowana' THEN 1 ELSE 0 END) AS rezerwacje_anulowane,
    COALESCE(SUM(p.kwota) FILTER (WHERE p.status_platnosci = 'zrealizowana'), 0) AS suma_wydana
FROM uzytkownicy u
JOIN role_uzytkownikow ru ON u.id_roli = ru.id_roli
LEFT JOIN rezerwacje r ON u.id_uzytkownika = r.id_uzytkownika
LEFT JOIN platnosci p ON r.id_rezerwacji = p.id_rezerwacji
GROUP BY u.id_uzytkownika, u.imie, u.nazwisko, u.email, ru.nazwa_roli;

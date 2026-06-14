SELECT 
    id_kortu,
    nazwa,
    liczba_rezerwacji,
    suma_godzin AS zarezerwowane_godziny,
    420.0 AS pojemnosc_godzinowa_miesiaca,
    ROUND(((suma_godzin / 420.0) * 100)::numeric, 2) AS wskaznik_oblozenia_procent
FROM v_oblozenie_kortow
ORDER BY wskaznik_oblozenia_procent DESC;

SELECT 
    rok,
    miesiac,
    liczba_rezerwacji,
    przychod_zrealizowany AS wplaty_zrealizowane_pln,
    przychod_oczekujacy AS wplaty_oczekujace_pln,
    wartosc_calkowita_rezerwacji AS suma_prognozowana_pln
FROM v_przychody_miesieczne
ORDER BY rok DESC, miesiac DESC;

SELECT 
    n.nazwa_nawierzchni AS typ_nawierzchni,
    COUNT(r.id_rezerwacji) AS liczba_rezerwacji,
    SUM(p.kwota) AS total_przychod_pln,
    ROUND(AVG(k.cena_za_godzine), 2) AS avg_cena_h_pln
FROM korty k
JOIN nawierzchnie n ON k.id_nawierzchni = n.id_nawierzchni
JOIN rezerwacje r ON k.id_kortu = r.id_kortu
JOIN platnosci p ON r.id_rezerwacji = p.id_rezerwacji
WHERE p.status_platnosci = 'zrealizowana'
GROUP BY n.nazwa_nawierzchni
ORDER BY total_przychod_pln DESC;

SELECT 
    id_uzytkownika,
    klient,
    email,
    suma_rezerwacji,
    rezerwacje_zakonczone,
    suma_wydana AS wydano_lacznie_pln,
    DENSE_RANK() OVER (ORDER BY suma_wydana DESC) AS pozycja_w_rankingu
FROM v_statystyki_klientow
WHERE suma_rezerwacji > 0
ORDER BY wydano_lacznie_pln DESC;

SELECT 
    k.nazwa AS nazwa_kortu,
    n.nazwa_nawierzchni AS typ_nawierzchni,
    COUNT(o.id_opinii) AS liczba_opinii,
    ROUND(AVG(o.ocena), 2) AS srednia_ocena,
    STRING_AGG(o.komentarz, ' | ' ORDER BY o.data_dodania DESC) AS zebrane_opinie
FROM korty k
JOIN nawierzchnie n ON k.id_nawierzchni = n.id_nawierzchni
LEFT JOIN rezerwacje r ON k.id_kortu = r.id_kortu
LEFT JOIN opinie o ON r.id_rezerwacji = o.id_rezerwacji
GROUP BY k.id_kortu, k.nazwa, n.nazwa_nawierzchni
ORDER BY srednia_ocena DESC NULLS LAST;

SELECT 
    id_rezerwacji,
    klient,
    nazwa_kortu,
    data_rozpoczecia,
    data_zakonczenia,
    status_rezerwacji
FROM v_szczegoly_rezerwacji
WHERE id_kortu = 1 
  AND status_rezerwacji IN ('oczekujaca', 'potwierdzona', 'zakonczona')
ORDER BY data_rozpoczecia;

-- Skrypt DML: Zasilanie bazy danymi testowymi (Zgodność z 3NF)
-- Baza danych: PostgreSQL

-- Czyszczenie istniejących danych
TRUNCATE TABLE opinie, platnosci, rezerwacje, korty, uzytkownicy, role_uzytkownikow, dyscypliny, nawierzchnie RESTART IDENTITY CASCADE;

-- ============================================================================
-- 1. Zasilanie Słowników
-- ============================================================================

INSERT INTO role_uzytkownikow (kod_roli, nazwa_roli, opis) VALUES
('klient', 'Klient', 'Standardowy użytkownik mogący dokonywać rezerwacji kortów'),
('pracownik', 'Pracownik Obsługi', 'Użytkownik obsługujący rezerwacje i płatności na miejscu'),
('administrator', 'Administrator Systemu', 'Użytkownik z pełnymi uprawnieniami konfiguracyjnymi');

INSERT INTO dyscypliny (nazwa_sportu, opis_sportu) VALUES
('tenis', 'Tenis ziemny - gra pojedyncza lub podwójna'),
('squash', 'Squash - dynamiczna gra halowa'),
('badminton', 'Badminton - gra rekreacyjna i sportowa'),
('koszykowka', 'Koszykówka - gra zespołowa na twardym boisku'),
('siatkowka', 'Siatkówka halowa lub plażowa');

INSERT INTO nawierzchnie (nazwa_nawierzchni, czy_wymaga_obuwia_halowego) VALUES
('maczka', FALSE),
('trawa', FALSE),
('parkiet', TRUE),
('twarda', TRUE);

-- ============================================================================
-- 2. Zasilanie Tabel Głównych
-- ============================================================================

-- Tabela Uzytkownicy (wykorzystanie podzapytań dla bezpieczeństwa kluczy obcych)
INSERT INTO uzytkownicy (imie, nazwisko, email, telefon, id_roli, data_rejestracji) VALUES
('Jan', 'Kowalski', 'jan.kowalski@email.com', '601202303', (SELECT id_roli FROM role_uzytkownikow WHERE kod_roli = 'klient'), '2026-01-15 10:30:00'),
('Anna', 'Nowak', 'anna.nowak@email.com', '502303404', (SELECT id_roli FROM role_uzytkownikow WHERE kod_roli = 'klient'), '2026-02-10 14:20:00'),
('Piotr', 'Wisniewski', 'piotr.wisniewski@email.com', '703404505', (SELECT id_roli FROM role_uzytkownikow WHERE kod_roli = 'klient'), '2026-03-05 09:15:00'),
('Katarzyna', 'Wojcik', 'katarzyna.wojcik@email.com', '804505606', (SELECT id_roli FROM role_uzytkownikow WHERE kod_roli = 'klient'), '2026-04-22 17:45:00'),
('Tomasz', 'Lewandowski', 'tomasz.lewandowski@korty.pl', '500100200', (SELECT id_roli FROM role_uzytkownikow WHERE kod_roli = 'pracownik'), '2026-01-01 08:00:00'),
('Maria', 'Dabrowska', 'maria.dabrowska@korty.pl', '600200300', (SELECT id_roli FROM role_uzytkownikow WHERE kod_roli = 'administrator'), '2026-01-01 08:00:00');

-- Tabela Korty
INSERT INTO korty (nazwa, id_dyscypliny, id_nawierzchni, czy_zadaszony, cena_za_godzine, czy_aktywny) VALUES
('Kort A (Centralny)', (SELECT id_dyscypliny FROM dyscypliny WHERE nazwa_sportu = 'tenis'), (SELECT id_nawierzchni FROM nawierzchnie WHERE nazwa_nawierzchni = 'maczka'), FALSE, 60.00, TRUE),
('Kort B (Boczny)', (SELECT id_dyscypliny FROM dyscypliny WHERE nazwa_sportu = 'tenis'), (SELECT id_nawierzchni FROM nawierzchnie WHERE nazwa_nawierzchni = 'trawa'), FALSE, 50.00, TRUE),
('Hala Squash 1', (SELECT id_dyscypliny FROM dyscypliny WHERE nazwa_sportu = 'squash'), (SELECT id_nawierzchni FROM nawierzchnie WHERE nazwa_nawierzchni = 'parkiet'), TRUE, 45.00, TRUE),
('Hala Squash 2', (SELECT id_dyscypliny FROM dyscypliny WHERE nazwa_sportu = 'squash'), (SELECT id_nawierzchni FROM nawierzchnie WHERE nazwa_nawierzchni = 'parkiet'), TRUE, 45.00, TRUE),
('Kort Badminton 1', (SELECT id_dyscypliny FROM dyscypliny WHERE nazwa_sportu = 'badminton'), (SELECT id_nawierzchni FROM nawierzchnie WHERE nazwa_nawierzchni = 'parkiet'), TRUE, 35.00, TRUE),
('Kort Badminton 2', (SELECT id_dyscypliny FROM dyscypliny WHERE nazwa_sportu = 'badminton'), (SELECT id_nawierzchni FROM nawierzchnie WHERE nazwa_nawierzchni = 'parkiet'), TRUE, 35.00, TRUE),
('Kort Koszykowki', (SELECT id_dyscypliny FROM dyscypliny WHERE nazwa_sportu = 'koszykowka'), (SELECT id_nawierzchni FROM nawierzchnie WHERE nazwa_nawierzchni = 'twarda'), TRUE, 80.00, FALSE);

-- Tabela Rezerwacje
INSERT INTO rezerwacje (id_uzytkownika, id_kortu, data_rozpoczecia, data_zakonczenia, status_rezerwacji, cena_calkowita, data_utworzenia) VALUES
(1, 1, '2026-06-08 10:00:00', '2026-06-08 12:00:00', 'zakonczona', 120.00, '2026-06-07 18:00:00'),
(2, 3, '2026-06-08 15:00:00', '2026-06-08 16:30:00', 'zakonczona', 67.50, '2026-06-08 09:00:00'),
(3, 5, '2026-06-09 18:00:00', '2026-06-09 19:00:00', 'zakonczona', 35.00, '2026-06-08 12:00:00'),
(1, 1, '2026-06-11 09:00:00', '2026-06-11 11:00:00', 'potwierdzona', 120.00, '2026-06-09 10:00:00'),
(4, 4, '2026-06-12 17:00:00', '2026-06-12 18:00:00', 'oczekujaca', 45.00, '2026-06-10 15:00:00'),
(2, 2, '2026-06-12 12:00:00', '2026-06-12 14:00:00', 'anulowana', 100.00, '2026-06-10 11:00:00'),
(3, 6, '2026-06-13 10:00:00', '2026-06-13 12:00:00', 'potwierdzona', 70.00, '2026-06-10 12:00:00');

-- Tabela Platnosci
INSERT INTO platnosci (id_rezerwacji, kwota, metoda_platnosci, status_platnosci, data_platnosci) VALUES
(1, 120.00, 'blik', 'zrealizowana', '2026-06-07 18:05:00'),
(2, 67.50, 'karta', 'zrealizowana', '2026-06-08 16:35:00'),
(3, 35.00, 'przelew', 'zrealizowana', '2026-06-08 14:22:00'),
(4, 120.00, 'blik', 'zrealizowana', '2026-06-09 10:02:00'),
(5, 45.00, 'blik', 'oczekujaca', NULL),
(6, 100.00, 'karta', 'odrzucona', '2026-06-10 11:05:00'),
(7, 70.00, 'przelew', 'zrealizowana', '2026-06-10 13:00:00');

-- Tabela Opinie
INSERT INTO opinie (id_rezerwacji, ocena, komentarz, data_dodania) VALUES
(1, 5, 'Kort rewelacyjny, nawierzchnia doskonale przygotowana!', '2026-06-08 12:30:00'),
(2, 4, 'Wszystko super, ale klimatyzacja w hali mogłaby działać mocniej.', '2026-06-08 17:00:00'),
(3, 5, 'Bardzo miła obsługa, szybka rezerwacja.', '2026-06-09 19:30:00');

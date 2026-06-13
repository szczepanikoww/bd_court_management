DROP TABLE IF EXISTS opinie CASCADE;
DROP TABLE IF EXISTS platnosci CASCADE;
DROP TABLE IF EXISTS rezerwacje CASCADE;
DROP TABLE IF EXISTS korty CASCADE;
DROP TABLE IF EXISTS uzytkownicy CASCADE;
DROP TABLE IF EXISTS role_uzytkownikow CASCADE;
DROP TABLE IF EXISTS dyscypliny CASCADE;
DROP TABLE IF EXISTS nawierzchnie CASCADE;

CREATE TABLE role_uzytkownikow (
    id_roli SERIAL PRIMARY KEY,
    kod_roli VARCHAR(20) NOT NULL UNIQUE,
    nazwa_roli VARCHAR(50) NOT NULL,
    opis TEXT
);

CREATE TABLE dyscypliny (
    id_dyscypliny SERIAL PRIMARY KEY,
    nazwa_sportu VARCHAR(50) NOT NULL UNIQUE,
    opis_sportu TEXT
);

CREATE TABLE nawierzchnie (
    id_nawierzchni SERIAL PRIMARY KEY,
    nazwa_nawierzchni VARCHAR(50) NOT NULL UNIQUE,
    czy_wymaga_obuwia_halowego BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE uzytkownicy (
    id_uzytkownika SERIAL PRIMARY KEY,
    imie VARCHAR(50) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    telefon VARCHAR(20),
    id_roli INTEGER NOT NULL,
    data_rejestracji TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_uzytkownicy_rola FOREIGN KEY (id_roli) 
        REFERENCES role_uzytkownikow(id_roli) ON DELETE RESTRICT
);

CREATE TABLE korty (
    id_kortu SERIAL PRIMARY KEY,
    nazwa VARCHAR(100) NOT NULL,
    id_dyscypliny INTEGER NOT NULL,
    id_nawierzchni INTEGER NOT NULL,
    czy_zadaszony BOOLEAN NOT NULL DEFAULT FALSE,
    cena_za_godzine DECIMAL(10, 2) NOT NULL,
    czy_aktywny BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT chk_cena CHECK (cena_za_godzine > 0),
    CONSTRAINT fk_korty_dyscyplina FOREIGN KEY (id_dyscypliny) 
        REFERENCES dyscypliny(id_dyscypliny) ON DELETE RESTRICT,
    CONSTRAINT fk_korty_nawierzchnia FOREIGN KEY (id_nawierzchni) 
        REFERENCES nawierzchnie(id_nawierzchni) ON DELETE RESTRICT
);

CREATE TABLE rezerwacje (
    id_rezerwacji SERIAL PRIMARY KEY,
    id_uzytkownika INTEGER NOT NULL,
    id_kortu INTEGER NOT NULL,
    data_rozpoczecia TIMESTAMP NOT NULL,
    data_zakonczenia TIMESTAMP NOT NULL,
    status_rezerwacji VARCHAR(20) NOT NULL DEFAULT 'oczekujaca',
    cena_calkowita DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    data_utworzenia TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_rezerwacje_uzytkownik FOREIGN KEY (id_uzytkownika) 
        REFERENCES uzytkownicy(id_uzytkownika) ON DELETE CASCADE,
    CONSTRAINT fk_rezerwacje_kort FOREIGN KEY (id_kortu) 
        REFERENCES korty(id_kortu) ON DELETE CASCADE,
    
    CONSTRAINT chk_daty CHECK (data_zakonczenia > data_rozpoczecia),
    CONSTRAINT chk_status_rezerwacji CHECK (status_rezerwacji IN ('oczekujaca', 'potwierdzona', 'anulowana', 'zakonczona')),
    CONSTRAINT chk_cena_calkowita CHECK (cena_calkowita >= 0)
);

CREATE TABLE platnosci (
    id_platnosci SERIAL PRIMARY KEY,
    id_rezerwacji INTEGER NOT NULL UNIQUE,
    kwota DECIMAL(10, 2) NOT NULL,
    metoda_platnosci VARCHAR(20) NOT NULL,
    status_platnosci VARCHAR(20) NOT NULL DEFAULT 'oczekujaca',
    data_platnosci TIMESTAMP,
    
    CONSTRAINT fk_platnosci_rezerwacja FOREIGN KEY (id_rezerwacji) 
        REFERENCES rezerwacje(id_rezerwacji) ON DELETE CASCADE,
    
    CONSTRAINT chk_kwota CHECK (kwota >= 0),
    CONSTRAINT chk_metoda CHECK (metoda_platnosci IN ('karta', 'przelew', 'gotowka', 'blik')),
    CONSTRAINT chk_status_platnosci CHECK (status_platnosci IN ('oczekujaca', 'zrealizowana', 'odrzucona', 'zwrocona'))
);

CREATE TABLE opinie (
    id_opinii SERIAL PRIMARY KEY,
    id_rezerwacji INTEGER NOT NULL UNIQUE,
    ocena INTEGER NOT NULL,
    komentarz TEXT,
    data_dodania TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_opinie_rezerwacja FOREIGN KEY (id_rezerwacji) 
        REFERENCES rezerwacje(id_rezerwacji) ON DELETE CASCADE,
        
    CONSTRAINT chk_ocena CHECK (ocena BETWEEN 1 AND 5)
);

CREATE INDEX idx_rezerwacje_daty ON rezerwacje (data_rozpoczecia, data_zakonczenia);
CREATE INDEX idx_rezerwacje_kort ON rezerwacje (id_kortu);
CREATE INDEX idx_rezerwacje_uzytkownik ON rezerwacje (id_uzytkownika);
CREATE INDEX idx_platnosci_rezerwacja ON platnosci (id_rezerwacji);

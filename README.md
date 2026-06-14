# System Rezerwacji Kortów Sportowych

Projekt bazy danych dla systemu rezerwacji kortów sportowych, obejmujący zarządzanie terminami, użytkownikami, płatnościami oraz generowanie statystyk wykorzystania obiektów.

## 📋 Opis projektu

System umożliwia:
- Rejestrację i zarządzanie kontami użytkowników (klienci, pracownicy, administratorzy).
- Ewidencjonowanie kortów sportowych (typy nawierzchni, obiekty kryte/otwarte).
- Rezerwowanie kortów w określonych przedziałach czasowych z automatycznym sprawdzaniem kolizji terminów (ochrona przed overbookingiem).
- Automatyczne wyliczanie całkowitych kosztów rezerwacji na podstawie cennika kortu i czasu wynajmu.
- Rejestrowanie płatności powiązanych z rezerwacjami z systemem reaktywnej aktualizacji statusu rezerwacji.
- Zbieranie opinii użytkowników po zrealizowanych rezerwacjach.
- Systemową ochronę danych historycznych i dowodowych przed modyfikacjami po odbyciu się rezerwacji.
- Generowanie zaawansowanych raportów i statystyk (wykorzystanie obiektów, przychody).

---

## 📂 Struktura Projektu

Poniższa struktura została zaprojektowana w celu czytelnego podziału skryptów SQL oraz dokumentacji:

```text
projekt_bazy/
├── docs/                          # Pełna dokumentacja projektowa
│   ├── analiza_wymagan.md         # Wymagania biznesowe i opis aktorów
│   ├── db_design.md               # Model konceptualny/logiczny, słownik danych, ERD
│   ├── dokumentacja_techniczna.md # Relacje, constraints, triggery i indeksy
│   └── raport_z_testow.md         # Przypadki testowe i weryfikacja integralności
├── sql/                           # Skrypty SQL
│   ├── ddl/                   # Skrypty DDL (Definicja struktur)
│   │   ├── 01_tables.sql      # Tworzenie tabel i więzów integralności
│   │   ├── 02_views.sql       # Definicje widoków (statystyki i raporty)
│   │   ├── 03_functions.sql   # Funkcje i procedury składowane (PL/pgSQL)
│   │   └── 04_triggers.sql    # Wyzwalacze (np. kontrola nakładania terminów)
│   ├── dml/                   # Skrypty DML (Dane)
│   │   └── 01_seed_data.sql   # Dane testowe (seed) do zasilenia bazy
│   └── queries/               # Zapytania testowe i raportowe
│       └── reports.sql        # Przykładowe zapytania analityczne i raporty
├── tests/                     # Skrypty testowe
│   └── test_database.py       # Testy jednostkowe bazy danych (pytest)
├── requirements.txt           # Zależności Pythona
└── README.md                  # Główne informacje o projekcie
```

---

## 🛠️ Wymagania i Uruchomienie

### Baza danych
Projekt domyślnie wykorzystuje bazę danych **PostgreSQL** z uwagi na zaawansowaną obsługę wyzwalaczy (triggers) i procedur składowanych (PL/pgSQL).

### Uruchomienie ręczne (przez CLI PostgreSQL - psql)
Możesz zaimportować strukturę i dane bezpośrednio w terminalu:

```bash
# 1. Tworzenie bazy danych
createdb -U postgres rezerwacje_kortow

# 2. Uruchomienie skryptów DDL (struktura)
psql -U postgres -d rezerwacje_kortow -f sql/ddl/01_tables.sql
psql -U postgres -d rezerwacje_kortow -f sql/ddl/02_views.sql
psql -U postgres -d rezerwacje_kortow -f sql/ddl/03_functions.sql
psql -U postgres -d rezerwacje_kortow -f sql/ddl/04_triggers.sql

# 3. Zasilenie bazy danymi testowymi
psql -U postgres -d rezerwacje_kortow -f sql/dml/01_seed_data.sql
```

---

## 📊 Główne Statystyki i Raporty (Zaimplementowane w `sql/queries/reports.sql`)
1. **Wskaźnik obłożenia (wykorzystania) kortów** - stosunek zarezerwowanych godzin do godzin otwarcia obiektu w danym miesiącu.
2. **Miesięczne zestawienie przychodów** - podział na zrealizowane płatności oraz płatności oczekujące.
3. **Najbardziej aktywni klienci** - ranking użytkowników na podstawie liczby rezerwacji i wydanych kwot.
4. **Popularność nawierzchni** - statystyka określająca, które rodzaje kortów są najchętniej rezerwowane.

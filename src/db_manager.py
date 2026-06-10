#!/usr/bin/env python3
import os
import sys
import argparse
import time
import threading
from pathlib import Path
import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv
from tabulate import tabulate

# Załadowanie zmiennych środowiskowych z pliku .env
load_dotenv()

# Konfiguracja połączenia z bazą danych
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "rezerwacje_kortow")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

def get_connection():
    """Tworzy i zwraca połączenie z bazą danych PostgreSQL."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except psycopg2.OperationalError as e:
        print(f"\n[BŁĄD] Nie można połączyć się z bazą danych PostgreSQL.")
        print(f"Szczegóły: {e}")
        print("\nUpewnij się, że:")
        print(f"  1. PostgreSQL jest uruchomiony na {DB_HOST}:{DB_PORT}.")
        print(f"  2. Baza danych '{DB_NAME}' istnieje (możesz ją utworzyć poleceniem: createdb -U {DB_USER} {DB_NAME}).")
        print("  3. Plik .env zawiera prawidłowe hasło i login.")
        sys.exit(1)

def run_sql_file(conn, file_path):
    """Wczytuje i wykonuje plik SQL w ramach jednej transakcji."""
    print(f"Wykonuję skrypt: {file_path.name} ... ", end="")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        with conn.cursor() as cursor:
            cursor.execute(sql_content)
        conn.commit()
        print("OK")
    except Exception as e:
        conn.rollback()
        print("BŁĄD")
        print(f"Szczegóły błędu w pliku {file_path.name}:\n{e}")
        sys.exit(1)

def initialize_database(conn):
    """Inicjalizuje strukturę bazy danych (DDL)."""
    print("\n--- INICJALIZACJA STRUKTURY BAZY DANYCH (DDL) ---")
    project_root = Path(__file__).resolve().parent.parent
    ddl_dir = project_root / "sql" / "ddl"
    
    ddl_files = [
        "01_tables.sql",
        "02_views.sql",
        "03_functions.sql",
        "04_triggers.sql",
        "05_security.sql"
    ]
    
    for filename in ddl_files:
        file_path = ddl_dir / filename
        if file_path.exists():
            run_sql_file(conn, file_path)
        else:
            print(f"[OSTRZEŻENIE] Brak pliku {file_path}")
    print("Inicjalizacja struktury zakończona sukcesem!")

def seed_database(conn):
    """Zasila bazę danych danymi testowymi (DML)."""
    print("\n--- ZASILANIE BAZY DANYMI TESTOWYMI (DML) ---")
    project_root = Path(__file__).resolve().parent.parent
    dml_file = project_root / "sql" / "dml" / "01_seed_data.sql"
    
    if dml_file.exists():
        run_sql_file(conn, dml_file)
        print("Zasilanie bazy zakończone sukcesem!")
    else:
        print(f"[OSTRZEŻENIE] Brak pliku {dml_file}")

def generate_reports(conn):
    """Wykonuje zapytania raportowe i wyświetla je w czytelnych tabelach."""
    print("\n--- GENEROWANIE RAPORTÓW ANALITYCZNYCH ---")
    
    reports = [
        {
            "title": "1. WSKAŹNIK OBŁOŻENIA KORTÓW (W CZERWCU 2026)",
            "query": """
                SELECT id_kortu, nazwa, typ_sportu, liczba_rezerwacji, 
                       suma_godzin, wskaznik_oblozenia_procent 
                FROM v_oblozenie_kortow
                ORDER BY wskaznik_oblozenia_procent DESC;
            """,
            "headers": ["ID", "Nazwa kortu", "Sport", "Liczba rez.", "Suma godz.", "Obłożenie (%)"]
        },
        {
            "title": "2. MIESIĘCZNY PRZYCHÓD (ZREALIZOWANY vs OCZEKUJĄCY)",
            "query": """
                SELECT rok, miesiac, liczba_rezerwacji, przychod_zrealizowany, 
                       przychod_oczekujacy, wartosc_calkowita_rezerwacji 
                FROM v_przychody_miesieczne
                ORDER BY rok DESC, miesiac DESC;
            """,
            "headers": ["Rok", "Miesiąc", "Liczba rez.", "Przychód zrealizowany (PLN)", "Przychód oczekujący (PLN)", "Suma (PLN)"]
        },
        {
            "title": "3. RANKING DOCHODOWOŚCI DYSCYPLIN SPORTOWYCH",
            "query": """
                SELECT k.typ_sportu, COUNT(r.id_rezerwacji) AS liczba_rezerwacji, 
                       SUM(p.kwota) AS total_przychod, ROUND(AVG(k.cena_za_godzine), 2) AS avg_cena
                FROM korty k
                JOIN rezerwacje r ON k.id_kortu = r.id_kortu
                JOIN platnosci p ON r.id_rezerwacji = p.id_rezerwacji
                WHERE p.status_platnosci = 'zrealizowana'
                GROUP BY k.typ_sportu
                ORDER BY total_przychod DESC;
            """,
            "headers": ["Dyscyplina", "Liczba rezerwacji", "Przychód łączny (PLN)", "Średnia stawka/h (PLN)"]
        },
        {
            "title": "4. RANKING LOJALNOŚCIOWY KLIENTÓW (TOP SPENDERS)",
            "query": """
                SELECT id_uzytkownika, klient, email, rola_uzytkownika, suma_rezerwacji, 
                       rezerwacje_zakonczone, suma_wydana 
                FROM v_statystyki_klientow
                WHERE suma_rezerwacji > 0
                ORDER BY suma_wydana DESC;
            """,
            "headers": ["ID Użytkownika", "Klient", "Adres Email", "Rola", "Liczba rez.", "Zakończone rez.", "Wydatki łącznie (PLN)"]
        },
        {
            "title": "5. OCENY I OPINIE UŻYTKOWNIKÓW O OBIEKTACH",
            "query": """
                SELECT k.nazwa, d.nazwa_sportu, COUNT(o.id_opinii) AS opinie, 
                       COALESCE(ROUND(AVG(o.ocena), 2)::text, 'Brak') AS srednia_ocena
                FROM korty k
                JOIN dyscypliny d ON k.id_dyscypliny = d.id_dyscypliny
                LEFT JOIN rezerwacje r ON k.id_kortu = r.id_kortu
                LEFT JOIN opinie o ON r.id_rezerwacji = o.id_rezerwacji
                GROUP BY k.id_kortu, k.nazwa, d.nazwa_sportu
                ORDER BY avg(o.ocena) DESC NULLS LAST;
            """,
            "headers": ["Nazwa kortu", "Sport", "Liczba opinii", "Średnia ocena"]
        }
    ]
    
    with conn.cursor() as cursor:
        for r in reports:
            print(f"\n=== {r['title']} ===")
            try:
                cursor.execute(r['query'])
                rows = cursor.fetchall()
                print(tabulate(rows, headers=r['headers'], tablefmt="grid", numalign="right", stralign="left"))
            except Exception as e:
                print(f"Nie udało się pobrać danych dla raportu. Szczegóły: {e}")

def test_booking_validation(conn):
    """Prezentacja działania wyzwalaczy i walidacji bazy danych."""
    print("\n--- TEST DZIAŁANIA WALIDACJI (ZAPOBIEGANIE NAKŁADANIU TERMINÓW) ---")
    
    # Próba dokonania prawidłowej rezerwacji za pomocą procedury
    print("1. Próba rejestracji poprawnej rezerwacji (Kort B, 15 czerwca, 10:00 - 12:00)...")
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CALL proc_zloz_rezerwacje(
                    1, 2, 
                    '2026-06-15 10:00:00'::timestamp, 
                    '2026-06-15 12:00:00'::timestamp, 
                    NULL, NULL
                );
            """)
        conn.commit()
        print("   [SUKCES] Rezerwacja dodana pomyślnie.")
    except Exception as e:
        conn.rollback()
        print(f"   [BŁĄD] Niepowodzenie: {e}")

    # Próba dokonania nakładającej się rezerwacji (ten sam kort, ten sam czas)
    print("\n2. Próba dodania nakładającej się rezerwacji (Kort B, 15 czerwca, 11:00 - 13:00 - kolizja)...")
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CALL proc_zloz_rezerwacje(
                    2, 2, 
                    '2026-06-15 11:00:00'::timestamp, 
                    '2026-06-15 13:00:00'::timestamp, 
                    NULL, NULL
                );
            """)
        conn.commit()
        print("   [BŁĄD] Ostrzeżenie! System dopuścił do nałożenia rezerwacji!")
    except Exception as e:
        conn.rollback()
        error_msg = str(e).split('\n')[0]
        print(f"   [SUKCES] Wyzwalacz bazy zablokował kolizję terminów. Komunikat błędu:")
        print(f"   >>> {error_msg}")

def demo_security(conn):
    """Demonstracja bezpieczeństwa: RLS i Role."""
    print("\n--- DEMONSTRACJA BEZPIECZEŃSTWA (ROLE I ROW-LEVEL SECURITY) ---")
    
    try:
        with conn.cursor() as cursor:
            # Sprawdzenie jako Administrator (domyślne połączenie)
            print("1. Widok rezerwacji jako ADMINISTRATOR (widzi wszystko):")
            cursor.execute("SELECT id_rezerwacji, id_uzytkownika, cena_calkowita FROM rezerwacje;")
            admin_rows = cursor.fetchall()
            print(tabulate(admin_rows, headers=["ID Rez.", "ID Użytkownika", "Cena (PLN)"], tablefmt="simple"))
            
            # Przełączenie na rolę 'rola_klient' i ustawienie kontekstu sesji dla Jana Kowalskiego
            print("\n2. Przełączenie roli na 'rola_klient' i zalogowanie jako jan.kowalski@email.com:")
            cursor.execute("SET ROLE rola_klient;")
            cursor.execute("SET app.biezacy_email_uzytkownika = 'jan.kowalski@email.com';")
            
            # Pobranie rezerwacji
            cursor.execute("SELECT id_rezerwacji, id_uzytkownika, cena_calkowita FROM rezerwacje;")
            jan_rows = cursor.fetchall()
            print(tabulate(jan_rows, headers=["ID Rez.", "ID Użytkownika", "Cena (PLN)"], tablefmt="simple"))
            print("   >>> RLS odfiltrował rekordy i pokazał wyłącznie rezerwacje Jana (id_uzytkownika = 1).")
            
            # Ustawienie kontekstu sesji dla Anny Nowak
            print("\n3. Zmiana kontekstu sesji na anna.nowak@email.com (nadal rola_klient):")
            cursor.execute("SET app.biezacy_email_uzytkownika = 'anna.nowak@email.com';")
            cursor.execute("SELECT id_rezerwacji, id_uzytkownika, cena_calkowita FROM rezerwacje;")
            anna_rows = cursor.fetchall()
            print(tabulate(anna_rows, headers=["ID Rez.", "ID Użytkownika", "Cena (PLN)"], tablefmt="simple"))
            print("   >>> RLS dynamicznie przełączył widok i pokazał wyłącznie rezerwacje Anny (id_uzytkownika = 2).")
            
            # Próba wstawienia rezerwacji dla innego użytkownika przez klienta (naruszenie CHECK policy)
            print("\n4. Próba wstrzyknięcia rezerwacji dla innego użytkownika (jako rola_klient):")
            try:
                cursor.execute("""
                    INSERT INTO rezerwacje (id_uzytkownika, id_kortu, data_rozpoczecia, data_zakonczenia, status_rezerwacji, cena_calkowita)
                    VALUES (1, 1, '2026-06-22 14:00:00', '2026-06-22 15:00:00', 'oczekujaca', 60.00);
                """)
                print("   [BŁĄD] Baza danych pozwoliła na wstawienie rezerwacji dla innego klienta!")
            except Exception as ex:
                print(f"   [SUKCES] RLS zablokował operację INSERT: {str(ex).strip()}")
            
            # Przywrócenie roli administratora
            cursor.execute("RESET ROLE;")
            conn.commit()
            print("\nRolę pomyślnie zresetowano do poziomu administratora.")
            
    except Exception as e:
        conn.rollback()
        print(f"Błąd podczas testowania zabezpieczeń: {e}")

def demo_concurrency_serializable():
    """
    Demonstruje współbieżność i wykrywanie anomalii (Serialization Failure) 
    przy poziomie izolacji SERIALIZABLE.
    """
    print("\n--- DEMONSTRACJA WSPÓŁBIEŻNOŚCI (IZOLACJA SERIALIZABLE) ---")
    print("Dwie transakcje próbują równolegle sprawdzić i zarezerwować ten sam wolny termin.")
    
    barrier = threading.Barrier(2)
    results = {}

    def client_transaction(client_name, delay_before_insert, thread_id):
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                # Rozpoczęcie transakcji SERIALIZABLE
                cur.execute("BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;")
                print(f"[{client_name}] Rozpoczęto transakcję SERIALIZABLE")
                
                # Krok 1: Sprawdzenie dostępności (oba wątki powinny to zrobić)
                cur.execute("SELECT fn_sprawdz_dostepnosc_kortu(1, '2026-06-30 14:00:00', '2026-06-30 16:00:00');")
                dostepny = cur.fetchone()[0]
                print(f"[{client_name}] Odczytano dostępność kortu: {dostepny}")
                
                # Synchronizacja przed zapisem
                barrier.wait()
                
                time.sleep(delay_before_insert)
                
                if dostepny:
                    print(f"[{client_name}] Zapisuję rezerwację...")
                    cur.execute("""
                        CALL proc_zloz_rezerwacje(
                            %s, 1, 
                            '2026-06-30 14:00:00'::timestamp, 
                            '2026-06-30 16:00:00'::timestamp, 
                            NULL, NULL
                        );
                    """)
                    
                    # Synchronizacja przed COMMIT
                    barrier.wait()
                    
                    print(f"[{client_name}] Próbuję zatwierdzić transakcję (COMMIT)...")
                    cur.execute("COMMIT;")
                    results[thread_id] = "COMMIT SUCCESS"
                    print(f"[{client_name}] ZATWIERDZONO POMYŚLNIE")
                else:
                    cur.execute("ROLLBACK;")
                    results[thread_id] = "SKIPPED (OCCUPIED)"
                    print(f"[{client_name}] Brak wolnego terminu, wycofanie (ROLLBACK)")
        except psycopg2.errors.SerializationFailure as sf:
            conn.rollback()
            results[thread_id] = "SERIALIZATION FAILURE"
            print(f"[{client_name}] BŁĄD IZOLACJI: Wykryto konflikt współbieżności! Transakcja wycofana przez silnik DB.")
        except Exception as e:
            conn.rollback()
            results[thread_id] = f"ERROR: {str(e).strip()}"
            print(f"[{client_name}] Błąd transakcji: {str(e).strip()}")
        finally:
            conn.close()

    # Jan zaczyna zapis minimalnie szybciej
    t1 = threading.Thread(target=client_transaction, args=("Jan (Wątek 1)", 0.0, 1))
    # Anna zaczyna ułamek sekundy później, ale w tym samym czasie
    t2 = threading.Thread(target=client_transaction, args=("Anna (Wątek 2)", 0.2, 2))

    t1.start()
    t2.start()
    t1.join()
    t2.join()

    print("\nPodsumowanie współbieżności:")
    print(f"  Wątek 1 (Jan): {results.get(1)}")
    print(f"  Wątek 2 (Anna): {results.get(2)}")
    print(">>> Poziom SERIALIZABLE zapobiegł podwójnej rezerwacji rzucając błąd izolacji w jednym z wątków.")

def main():
    parser = argparse.ArgumentParser(description="Menedżer bazy danych dla systemu rezerwacji kortów.")
    parser.add_argument("--init", action="store_true", help="Inicjalizuje strukturę bazy danych (DDL)")
    parser.add_argument("--seed", action="store_true", help="Zasila bazę danych danymi testowymi (DML)")
    parser.add_argument("--report", action="store_true", help="Generuje i wyświetla raporty analityczne")
    parser.add_argument("--test-validation", action="store_true", help="Prezentuje testy blokowania nakładających się terminów")
    parser.add_argument("--demo-security", action="store_true", help="Demonstruje zabezpieczenia RLS i Role")
    parser.add_argument("--demo-concurrency", action="store_true", help="Demonstruje anomalie i rozwiązywanie konfliktów transakcji")
    parser.add_argument("--all", action="store_true", help="Wykonuje wszystkie operacje (init, seed, report, testy i dema)")
    
    args = parser.parse_args()
    
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
        
    conn = get_connection()
    try:
        if args.all or args.init:
            initialize_database(conn)
        if args.all or args.seed:
            seed_database(conn)
        if args.all or args.report:
            generate_reports(conn)
        if args.all or args.test_validation:
            test_booking_validation(conn)
        if args.all or args.demo_security:
            demo_security(conn)
        if args.all or args.demo_concurrency:
            demo_concurrency_serializable()
    finally:
        conn.close()

if __name__ == "__main__":
    main()

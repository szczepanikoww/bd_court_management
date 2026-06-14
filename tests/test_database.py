import os
import pytest
import psycopg2
from psycopg2 import errors as pg_errors
from pathlib import Path
from dotenv import load_dotenv
load_dotenv()
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME_TEST = os.getenv("DB_NAME_TEST", "rezerwacje_kortow_test")
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_DDL_DIR = PROJECT_ROOT / "sql" / "ddl"
SQL_DML_DIR = PROJECT_ROOT / "sql" / "dml"
@pytest.fixture(scope="session")
def db_connection():
    admin_conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        database="postgres", user=DB_USER, password=DB_PASSWORD
    )
    admin_conn.autocommit = True
    with admin_conn.cursor() as cur:
        cur.execute(f"DROP DATABASE IF EXISTS {DB_NAME_TEST};")
        cur.execute(f"CREATE DATABASE {DB_NAME_TEST};")
    admin_conn.close()
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        database=DB_NAME_TEST, user=DB_USER, password=DB_PASSWORD
    )
    ddl_files = [
        "01_tables.sql",
        "02_views.sql",
        "03_functions.sql",
        "04_triggers.sql",
    ]
    for filename in ddl_files:
        path = SQL_DDL_DIR / filename
        with open(path, "r", encoding="utf-8") as f:
            conn.cursor().execute(f.read())
        conn.commit()
    yield conn
    conn.close()
    admin_conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        database="postgres", user=DB_USER, password=DB_PASSWORD
    )
    admin_conn.autocommit = True
    with admin_conn.cursor() as cur:
        cur.execute(f)
        cur.execute(f"DROP DATABASE IF EXISTS {DB_NAME_TEST};")
    admin_conn.close()
@pytest.fixture(autouse=True)
def clean_tables(db_connection):
    conn = db_connection
    with conn.cursor() as cur:
        cur.execute("SAVEPOINT test_savepoint;")
        cur.execute()
        cur.execute()
        cur.execute()
        cur.execute()
        cur.execute()
        cur.execute()
    conn.commit()
    yield conn
    conn.rollback()
class TestTableConstraints:
    def test_rola_unikalny_kod(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.UniqueViolation):
                cur.execute()
        conn.rollback()
    def test_uzytkownik_unikalny_email(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.UniqueViolation):
                cur.execute()
        conn.rollback()
    def test_uzytkownik_wymagane_imie(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.NotNullViolation):
                cur.execute()
        conn.rollback()
    def test_uzytkownik_fk_rola_nieistniejaca(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.ForeignKeyViolation):
                cur.execute()
        conn.rollback()
    def test_kort_cena_musi_byc_dodatnia(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute()
        conn.rollback()
    def test_kort_cena_ujemna(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute()
        conn.rollback()
    def test_rezerwacja_data_konca_przed_poczatkiem(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute()
        conn.rollback()
    def test_rezerwacja_nieprawidlowy_status(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute()
        conn.rollback()
    def test_rezerwacja_ujemna_cena(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute()
        conn.rollback()
    def test_platnosc_nieprawidlowa_metoda(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute(, (rez_id,))
        conn.rollback()
    def test_platnosc_nieprawidlowy_status(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute(, (rez_id,))
        conn.rollback()
    def test_opinia_ocena_poza_zakresem_za_niska(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute(, (rez_id,))
        conn.rollback()
    def test_opinia_ocena_poza_zakresem_za_wysoka(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            with pytest.raises(pg_errors.CheckViolation):
                cur.execute(, (rez_id,))
        conn.rollback()
    def test_opinia_prawidlowa_ocena(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            cur.execute(, (rez_id,))
            cur.execute("SELECT ocena FROM opinie WHERE id_rezerwacji = %s;", (rez_id,))
            assert cur.fetchone()[0] == 5
        conn.rollback()
    def test_opinia_unikalna_na_rezerwacje(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            cur.execute(, (rez_id,))
            with pytest.raises(pg_errors.UniqueViolation):
                cur.execute(, (rez_id,))
        conn.rollback()
    def test_cascade_delete_uzytkownik_kasuje_rezerwacje(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute("DELETE FROM uzytkownicy WHERE id_uzytkownika = 1;")
            cur.execute("SELECT COUNT(*) FROM rezerwacje WHERE id_uzytkownika = 1;")
            assert cur.fetchone()[0] == 0
        conn.rollback()
    def test_restrict_delete_rola_z_uzytkownikami(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(pg_errors.RestrictViolation):
                cur.execute()
        conn.rollback()
class TestFnSprawdzDostepnosc:
    def test_kort_wolny(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            assert cur.fetchone()[0] is True
    def test_kort_zajety_pelne_nakladanie(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            assert cur.fetchone()[0] is False
    def test_kort_zajety_czesciowe_nakladanie(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            assert cur.fetchone()[0] is False
    def test_kort_wolny_tuz_po_rezerwacji(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            assert cur.fetchone()[0] is True
    def test_kort_nieaktywny(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            assert cur.fetchone()[0] is False
    def test_rezerwacja_anulowana_nie_blokuje(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            assert cur.fetchone()[0] is True
    def test_inny_kort_nie_koliduje(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            assert cur.fetchone()[0] is True
class TestFnObliczCene:
    def test_cena_za_2_godziny(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            result = cur.fetchone()[0]
            assert float(result) == 120.00
    def test_cena_za_pol_godziny(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            result = cur.fetchone()[0]
            assert float(result) == 22.50
    def test_cena_za_1_5_godziny(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            result = cur.fetchone()[0]
            assert float(result) == 67.50
    def test_cena_nieistniejacy_kort(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(psycopg2.errors.RaiseException):
                cur.execute()
        conn.rollback()
    def test_cena_data_konca_przed_poczatkiem(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(psycopg2.errors.RaiseException):
                cur.execute()
        conn.rollback()
class TestProcZlozRezerwacje:
    def test_poprawna_rezerwacja(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute("SELECT COUNT(*) FROM rezerwacje WHERE id_uzytkownika = 1 AND id_kortu = 1;")
            assert cur.fetchone()[0] == 1
            cur.execute()
            row = cur.fetchone()
            assert float(row[0]) == 120.00  # 60 PLN/h × 2h
            assert row[1] == 'blik'
            assert row[2] == 'oczekujaca'
        conn.rollback()
    def test_rezerwacja_na_zajetym_korcie(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            with pytest.raises(psycopg2.errors.RaiseException):
                cur.execute()
        conn.rollback()
    def test_rezerwacja_na_nieaktywnym_korcie(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(psycopg2.errors.RaiseException):
                cur.execute()
        conn.rollback()
    def test_rezerwacja_poprawna_cena_wyliczona(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            assert float(cur.fetchone()[0]) == 67.50  # 45 PLN/h × 1.5h
        conn.rollback()
    def test_rezerwacja_status_domyslny(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute("SELECT status_rezerwacji FROM rezerwacje WHERE id_uzytkownika = 1;")
            assert cur.fetchone()[0] == 'oczekujaca'
        conn.rollback()
class TestTriggers:
    def test_trigger_blokuje_kolizje_insert(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            with pytest.raises(psycopg2.errors.RaiseException):
                cur.execute()
        conn.rollback()
    def test_trigger_blokuje_na_nieaktywnym_korcie(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            with pytest.raises(psycopg2.errors.RaiseException):
                cur.execute()
        conn.rollback()
    def test_trigger_pozwala_anulowana_nie_koliduje(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            cur.execute("SELECT COUNT(*) FROM rezerwacje WHERE id_kortu = 1;")
            assert cur.fetchone()[0] == 2
        conn.rollback()
    def test_trigger_pozwala_rezerwacje_stykowe(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            cur.execute("SELECT COUNT(*) FROM rezerwacje WHERE id_kortu = 1;")
            assert cur.fetchone()[0] == 2
        conn.rollback()
    def test_trigger_platnosc_zrealizowana_potwierdza_rezerwacje(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            cur.execute(, (rez_id,))
            cur.execute(, (rez_id,))
            cur.execute("SELECT status_rezerwacji FROM rezerwacje WHERE id_rezerwacji = %s;", (rez_id,))
            assert cur.fetchone()[0] == 'potwierdzona'
        conn.rollback()
    def test_trigger_platnosc_odrzucona_anuluje_rezerwacje(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            cur.execute(, (rez_id,))
            cur.execute(, (rez_id,))
            cur.execute("SELECT status_rezerwacji FROM rezerwacje WHERE id_rezerwacji = %s;", (rez_id,))
            assert cur.fetchone()[0] == 'anulowana'
        conn.rollback()
    def test_trigger_platnosc_oczekujaca_nie_zmienia_statusu(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            rez_id = cur.fetchone()[0]
            cur.execute(, (rez_id,))
            cur.execute(, (rez_id,))
            cur.execute("SELECT status_rezerwacji FROM rezerwacje WHERE id_rezerwacji = %s;", (rez_id,))
            assert cur.fetchone()[0] == 'oczekujaca'
        conn.rollback()
class TestViews:
    def _insert_full_reservation(self, cur, user_id, court_id, start, end, status, price):
        cur.execute(, (user_id, court_id, start, end, status, price))
        return cur.fetchone()[0]
    def test_v_szczegoly_rezerwacji(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            rez_id = self._insert_full_reservation(
                cur, 1, 1, '2026-07-01 10:00', '2026-07-01 12:00', 'potwierdzona', 120.00
            )
            cur.execute(, (rez_id,))
            cur.execute(, (rez_id,))
            row = cur.fetchone()
            assert row[0] == 'Jan Kowalski'
            assert row[1] == 'Kort A'
            assert row[2] == 'maczka'
            assert row[3] == 'potwierdzona'
            assert row[4] == 'blik'
        conn.rollback()
    def test_v_oblozenie_kortow(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            self._insert_full_reservation(
                cur, 1, 1, '2026-07-01 10:00', '2026-07-01 12:00', 'zakonczona', 120.00
            )
            self._insert_full_reservation(
                cur, 2, 1, '2026-07-02 10:00', '2026-07-02 13:00', 'potwierdzona', 180.00
            )
            cur.execute()
            row = cur.fetchone()
            assert row[0] == 2          # 2 rezerwacje
            assert float(row[1]) == 5.0  # 2h + 3h
    def test_v_statystyki_klientow(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            rez_id = self._insert_full_reservation(
                cur, 1, 1, '2026-07-01 10:00', '2026-07-01 12:00', 'zakonczona', 120.00
            )
            cur.execute(, (rez_id,))
            cur.execute()
            row = cur.fetchone()
            assert row[0] == 'Jan Kowalski'
            assert row[1] == 1        # 1 rezerwacja
            assert row[2] == 1        # 1 zakończona
            assert float(row[3]) == 120.00
    def test_v_przychody_miesieczne(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            rez_id = self._insert_full_reservation(
                cur, 1, 1, '2026-07-01 10:00', '2026-07-01 12:00', 'potwierdzona', 120.00
            )
            cur.execute(, (rez_id,))
            cur.execute()
            row = cur.fetchone()
            assert row is not None
            assert float(row[2]) == 120.00
        conn.rollback()
class TestEndToEnd:
    def test_pelny_cykl_rezerwacji(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            rez = cur.fetchone()
            rez_id, status, cena = rez[0], rez[1], float(rez[2])
            assert status == 'oczekujaca'
            assert cena == 120.00
            cur.execute(, (rez_id,))
            cur.execute("SELECT status_rezerwacji FROM rezerwacje WHERE id_rezerwacji = %s;", (rez_id,))
            assert cur.fetchone()[0] == 'potwierdzona'
            cur.execute(, (rez_id,))
            cur.execute(, (rez_id,))
            cur.execute(, (rez_id,))
            row = cur.fetchone()
            assert row[0] == 'Jan Kowalski'
            assert row[1] == 'Kort A'
            assert row[2] == 'zakonczona'
            assert row[3] == 'zrealizowana'
            assert row[4] == 5
            assert row[5] == 'Doskonały kort!'
        conn.rollback()
    def test_rezerwacja_odrzucona_platnosc(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute("SELECT id_rezerwacji FROM rezerwacje WHERE id_uzytkownika = 1;")
            rez_id = cur.fetchone()[0]
            cur.execute(, (rez_id,))
            cur.execute("SELECT status_rezerwacji FROM rezerwacje WHERE id_rezerwacji = %s;", (rez_id,))
            assert cur.fetchone()[0] == 'anulowana'
            cur.execute()
            assert cur.fetchone()[0] is True
        conn.rollback()
    def test_wielu_klientow_rozne_korty(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            cur.execute("SELECT COUNT(*) FROM rezerwacje;")
            assert cur.fetchone()[0] == 2
        conn.rollback()
    def test_sekwencyjne_rezerwacje_tego_samego_kortu(self, clean_tables):
        conn = clean_tables
        with conn.cursor() as cur:
            cur.execute()
            cur.execute()
            cur.execute()
            cur.execute("SELECT COUNT(*) FROM rezerwacje WHERE id_kortu = 1;")
            assert cur.fetchone()[0] == 3
        conn.rollback()

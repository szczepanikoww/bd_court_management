BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT id_kortu, nazwa, cena_za_godzine
FROM korty
WHERE id_kortu = 1
FOR UPDATE;

SELECT fn_sprawdz_dostepnosc_kortu(1, '2026-06-20 12:00:00', '2026-06-20 14:00:00');

CALL proc_zloz_rezerwacje(
    1, 1,
    '2026-06-20 12:00:00'::timestamp,
    '2026-06-20 14:00:00'::timestamp,
    NULL, NULL
);

COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT fn_sprawdz_dostepnosc_kortu(1, '2026-06-20 12:00:00', '2026-06-20 14:00:00');

CALL proc_zloz_rezerwacje(
    2, 1,
    '2026-06-20 12:00:00'::timestamp,
    '2026-06-20 14:00:00'::timestamp,
    NULL, NULL
);

COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT * FROM rezerwacje;

COMMIT;

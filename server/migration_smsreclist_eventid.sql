-- ============================================================================
--  smsreclist — add EventID idempotency + store DeviceName
--  For: sms_received.php (Detail array format)
--  Date: 2026-08-27
-- ============================================================================
--
--  Run these one at a time and read each result before moving on. Back up first:
--
--      mysqldump -u USER -p DBNAME smsreclist > smsreclist_backup.sql
--
-- ----------------------------------------------------------------------------
--  1. Inspect what's there now  — DO NOT SKIP
-- ----------------------------------------------------------------------------

SHOW CREATE TABLE smsreclist;
SELECT COUNT(*) AS existing_rows FROM smsreclist;

--  Three things to check in that output before continuing:
--
--  a) Are there other NOT NULL columns without a default that the endpoint's
--     INSERT doesn't name? It writes only clientmobid, eventid, smsdate, mobile,
--     smstext, devicename. INSERT IGNORE DOWNGRADES "Field 'x' doesn't have a
--     default value" from an error to a warning, so a missing column would be
--     filled with an implicit default and the row saved anyway — unattributable
--     rather than rejected. If you find one (a clientid column is the likely
--     candidate), add it to the INSERT in sms_received.php.
--
--  b) Is smstext utf8mb4? On 3-byte utf8 any SMS containing an emoji is
--     SILENTLY TRUNCATED at the bad character under INSERT IGNORE rather than
--     erroring. Convert it if not.
--
--  c) Is smsdate a DATETIME? If it's VARCHAR the normalisation in the endpoint
--     still works, but you lose range queries and index efficiency.

SHOW COLUMNS FROM smsreclist LIKE 'smsdate';


-- ----------------------------------------------------------------------------
--  2. Add the columns
-- ----------------------------------------------------------------------------
--
--  eventid is deliberately NULL-able with no default. MySQL treats NULLs as
--  distinct inside a UNIQUE index, so every pre-existing row keeps its NULL and
--  none of them collide with each other. If this column were NOT NULL DEFAULT ''
--  then every existing row would share the key (clientmobid, '') and step 3
--  would fail outright with "Duplicate entry".
--
--  New rows always arrive with a non-empty eventid — the endpoint generates a
--  content hash when the client omits one — so the index protects everything
--  written from here on.
--
--  COLLATE ascii_bin is load-bearing, not tidiness. The app's eventid embeds the
--  message text, so under the table's likely default (a case-insensitive,
--  PAD SPACE collation) the unique index would treat '..._Hello' and '..._HELLO'
--  as the same key, and '..._msg' and '..._msg ' likewise — silently suppressing
--  genuinely different messages as false duplicates. ascii_bin compares byte for
--  byte. It also keeps the index narrow: 4-byte utf8mb4 would make eventid alone
--  256 bytes and can trip "Specified key was too long" on an older
--  ROW_FORMAT=COMPACT table.
--
--  No AFTER clause on purpose — appending lets MySQL 8.0.29+ do this INSTANT,
--  whereas AFTER forces a full table rebuild.

ALTER TABLE smsreclist
    ADD COLUMN eventid    VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin
                          NULL DEFAULT NULL,
    ADD COLUMN devicename VARCHAR(100) NOT NULL DEFAULT '';


-- ----------------------------------------------------------------------------
--  3. Add the unique index
-- ----------------------------------------------------------------------------
--
--  Scoped to clientmobid as well as eventid so two devices can never suppress
--  each other's rows. The endpoint now rejects a blank ClientMobID for the same
--  reason — ('', eventid) would be a key shared by every handset.
--
--  If this errors with "Duplicate entry", some rows already share a non-NULL
--  eventid. Find them with the diagnostic below and resolve before retrying.

ALTER TABLE smsreclist
    ADD UNIQUE KEY uq_smsreclist_event (clientmobid, eventid);

-- Diagnostic for a failed step 3:
-- SELECT clientmobid, eventid, COUNT(*) AS n
--   FROM smsreclist
--  WHERE eventid IS NOT NULL
--  GROUP BY clientmobid, eventid
-- HAVING n > 1;


-- ----------------------------------------------------------------------------
--  4. Supporting index for reads (optional but recommended)
-- ----------------------------------------------------------------------------
--
--  Reporting on this table almost always filters by device and orders by date.
--  Skip if step 1 showed something equivalent already exists.

ALTER TABLE smsreclist
    ADD KEY ix_smsreclist_mob_date (clientmobid, smsdate);


-- ----------------------------------------------------------------------------
--  5. Verify
-- ----------------------------------------------------------------------------

SHOW CREATE TABLE smsreclist;

-- After the app has reported a few messages, confirm idempotency is live.
-- Re-POST the same batch and this count must not change:
SELECT COUNT(*) AS total, COUNT(eventid) AS with_eventid FROM smsreclist;

-- And confirm the device name is landing:
SELECT clientmobid, devicename, mobile, smsdate, LEFT(smstext, 40) AS preview
  FROM smsreclist
 WHERE eventid IS NOT NULL
 ORDER BY smsdate DESC
 LIMIT 10;


-- ============================================================================
--  Rollback
-- ============================================================================
--
-- ALTER TABLE smsreclist DROP KEY uq_smsreclist_event;
-- ALTER TABLE smsreclist DROP KEY ix_smsreclist_mob_date;
-- ALTER TABLE smsreclist DROP COLUMN eventid;
-- ALTER TABLE smsreclist DROP COLUMN devicename;
--
--  Note: the endpoint's INSERT names both new columns, so roll the PHP back at
--  the same time or every insert fails with "Unknown column".
-- ============================================================================

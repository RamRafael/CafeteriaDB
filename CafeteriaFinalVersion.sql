/*
 * Gentrification Analysis Database
 * Project: Latti Coffee House & Deli — Tijuana, BC
 *
 * We built this database to store and analyze rental listing data
 * scraped from Vivanuncios.com.mx across 4 Mexican cities, combined
 * with economic indicators pulled from the Banxico SIE API.
 *
 * All data flows in from Python — no manual inserts anywhere.
 * Every table gets populated through stored procedures only,
 * which keeps the data access layer clean and auditable.
 *
 * Cities covered: Tijuana, CDMX, Monterrey, Guadalajara
 * Data sources: Vivanuncios (scraping) + Banxico SIE API
 */

DROP DATABASE IF EXISTS cafeteria;
CREATE DATABASE cafeteria;
USE cafeteria;


/* ENTITIES */

/*
 * City — we only work with 4 cities, so this table is small.
 * The is_border flag helps us distinguish Tijuana from the rest,
 * since its border location makes it behave differently in rent trends.
 */
CREATE TABLE City (
    city_id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'Mexico',
    is_border TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (city_id)
);

/*
 * Neighborhood — populated automatically during scraping.
 * When sp_insert_rental runs, it checks if the neighborhood exists
 * and inserts it if not. This way we never duplicate neighborhoods
 * and we keep a clean catalog per city.
 */
CREATE TABLE Neighborhood (
    neighborhood_id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    city_id INT NOT NULL,
    PRIMARY KEY (neighborhood_id),
    CONSTRAINT fk_neighborhood_city
        FOREIGN KEY (city_id) REFERENCES City(city_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

/*
 * ScrapedSession — we open one session per city every time
 * the scraper runs. This lets us track exactly how many pages
 * we scraped, how many listings we found, and whether it succeeded.
 * Useful for debugging when a city returns 0 results.
 */
CREATE TABLE ScrapedSession (
    session_id INT NOT NULL AUTO_INCREMENT,
    city_id INT NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pages_scraped INT NOT NULL DEFAULT 0,
    total_listings INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'running',
    PRIMARY KEY (session_id),
    CONSTRAINT fk_session_city
        FOREIGN KEY (city_id) REFERENCES City(city_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

/*
 * ScrapedData — this is where we store the raw text we pulled
 * from each listing before cleaning it. Think of it as a log
 * of everything the scraper saw, so we can always go back
 * and re-parse if we change our extraction logic.
 */
CREATE TABLE ScrapedData (
    data_id INT NOT NULL AUTO_INCREMENT,
    session_id INT,
    source_url VARCHAR(255) NOT NULL,
    title TEXT NOT NULL,
    captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (data_id),
    CONSTRAINT fk_scraped_session
        FOREIGN KEY (session_id) REFERENCES ScrapedSession(session_id)
        ON UPDATE CASCADE ON DELETE SET NULL
);

/*
 * RentalListing — the cleaned, structured version of each listing.
 * After parsing price, currency, and neighborhood from the raw text,
 * we store it here. This is the main table the dashboard reads from
 * through the views we created below.
 */
CREATE TABLE RentalListing (
    listing_id INT NOT NULL AUTO_INCREMENT,
    neighborhood_id INT,
    session_id INT,
    price DECIMAL(12,2) NOT NULL,
    currency VARCHAR(5) NOT NULL,
    area_m2 DECIMAL(8,1),
    scraped_date DATE NOT NULL,
    PRIMARY KEY (listing_id),
    CONSTRAINT fk_listing_neighborhood
        FOREIGN KEY (neighborhood_id) REFERENCES Neighborhood(neighborhood_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_listing_session
        FOREIGN KEY (session_id) REFERENCES ScrapedSession(session_id)
        ON UPDATE CASCADE ON DELETE SET NULL
);

/*
 * BanxicoSerie — a small catalog of the 4 economic series
 * we pull from the Banxico SIE API. We store them here so we can
 * reference them by key without hardcoding names everywhere in Python.
 */
CREATE TABLE BanxicoSerie (
    serie_id INT NOT NULL AUTO_INCREMENT,
    serie_key VARCHAR(20) NOT NULL UNIQUE,
    serie_name VARCHAR(100) NOT NULL,
    unit VARCHAR(50),
    frequency VARCHAR(20),
    PRIMARY KEY (serie_id)
);

/*
 * BanxicoData — the historical values we download from Banxico.
 * Each row is one date-value pair for one series. We end up with
 * about 13,882 records across our 4 series (exchange rate alone
 * has daily data going back to 2000, so it dominates).
 *
 * We use serie_id = 0 as a fallback when the serie catalog lookup
 * fails, just to avoid breaking the insert.
 */
CREATE TABLE BanxicoData (
    data_id INT NOT NULL AUTO_INCREMENT,
    serie_id INT NOT NULL DEFAULT 0,
    serie_key VARCHAR(20) NOT NULL,
    serie_name VARCHAR(100) NOT NULL,
    record_date DATE NOT NULL,
    value DECIMAL(20,6) NOT NULL,
    extracted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (data_id),
    CONSTRAINT fk_banxico_serie
        FOREIGN KEY (serie_id) REFERENCES BanxicoSerie(serie_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

/*
 * CurrencySnapshot — a derived table where we store specific
 * USD/MXN snapshots we want to highlight in the dashboard,
 * like key dates or year-end rates. It references BanxicoData
 * so we never duplicate the raw value — just point to it.
 */
CREATE TABLE CurrencySnapshot (
    snapshot_id INT NOT NULL AUTO_INCREMENT,
    banxico_data_id INT NOT NULL,
    record_date DATE NOT NULL,
    usd_mxn_rate DECIMAL(10,4) NOT NULL,
    PRIMARY KEY (snapshot_id),
    CONSTRAINT fk_currency_banxico
        FOREIGN KEY (banxico_data_id) REFERENCES BanxicoData(data_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

/*
 * InflationIndex — same idea as CurrencySnapshot but for INPC.
 * We store annual averages here derived from the monthly Banxico data.
 * The dashboard uses these to show inflation-adjusted rent comparisons.
 */
CREATE TABLE InflationIndex (
    index_id INT NOT NULL AUTO_INCREMENT,
    banxico_data_id INT NOT NULL,
    year INT NOT NULL,
    avg_inpc DECIMAL(10,4) NOT NULL,
    PRIMARY KEY (index_id),
    CONSTRAINT fk_inflation_banxico
        FOREIGN KEY (banxico_data_id) REFERENCES BanxicoData(data_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

/*
 * ETLLog — every time BanxicoAPIs.py or scraper_tijuana.py runs,
 * we open a log entry at the start and close it at the end with
 * a success or error status. This makes it easy to see when the
 * last sync happened and how many records were loaded.
 */
CREATE TABLE ETLLog (
    log_id INT NOT NULL AUTO_INCREMENT,
    process_name VARCHAR(100) NOT NULL,
    source VARCHAR(50) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME,
    records_loaded INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'running',
    error_message TEXT,
    PRIMARY KEY (log_id)
);

/*
 * Audit — this table gets populated automatically by our triggers.
 * We never write to it directly from Python. Every INSERT, UPDATE,
 * or DELETE on BanxicoData, RentalListing, ScrapedSession and ETLLog
 * leaves a trace here, including the database user and timestamp.
 */
CREATE TABLE Audit (
    audit_id INT NOT NULL AUTO_INCREMENT,
    affected_table VARCHAR(60) NOT NULL,
    operation VARCHAR(20) NOT NULL,
    record_id INT NOT NULL,
    old_data TEXT,
    new_data TEXT,
    db_user VARCHAR(100) NOT NULL,
    date_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (audit_id)
);


/* VIEWS */

/*
 * vw_banxico_annual_trend — we use this to power the economic
 * indicator charts in the dashboard. Instead of averaging in Python,
 * we let MySQL group by year here and return clean annual averages.
 */
CREATE VIEW vw_banxico_annual_trend AS
SELECT
    serie_name AS indicator,
    YEAR(record_date) AS year,
    ROUND(AVG(value), 4) AS annual_avg
FROM BanxicoData
GROUP BY serie_name, YEAR(record_date)
ORDER BY year DESC;

/*
 * vw_rental_by_city — quick summary of rental prices per city
 * and currency. We use this to compare how each market behaves
 * and spot outliers in average, min and max prices.
 */
CREATE VIEW vw_rental_by_city AS
SELECT
    c.name AS city,
    rl.currency,
    COUNT(rl.listing_id) AS total_listings,
    ROUND(AVG(rl.price), 2) AS avg_price,
    ROUND(MIN(rl.price), 2) AS min_price,
    ROUND(MAX(rl.price), 2) AS max_price
FROM RentalListing rl
JOIN ScrapedSession ss ON rl.session_id = ss.session_id
JOIN City c ON ss.city_id = c.city_id
GROUP BY c.name, rl.currency
ORDER BY avg_price DESC;

/*
 * vw_top_neighborhoods — we use this in the dashboard to show
 * which neighborhoods concentrate the highest rents. The treemap
 * and bar charts on the Calculator page both read from here.
 */
CREATE VIEW vw_top_neighborhoods AS
SELECT
    c.name AS city,
    n.name AS neighborhood,
    rl.currency,
    COUNT(rl.listing_id) AS listings,
    ROUND(AVG(rl.price), 2) AS avg_price
FROM RentalListing rl
JOIN Neighborhood n ON rl.neighborhood_id = n.neighborhood_id
JOIN City c ON n.city_id = c.city_id
GROUP BY c.name, n.name, rl.currency
ORDER BY avg_price DESC;

/*
 * vw_exchange_rate_annual — filters BanxicoData down to just
 * the USD/MXN series and groups by year. The Exchange Rate page
 * uses this to draw the historical trend line.
 */
CREATE VIEW vw_exchange_rate_annual AS
SELECT
    YEAR(record_date) AS year,
    ROUND(AVG(value), 4) AS avg_usd_mxn
FROM BanxicoData
WHERE serie_key = 'SF43718'
GROUP BY YEAR(record_date)
ORDER BY year DESC;

/*
 * vw_etl_summary — a quick health check view. We can run this
 * after any sync to see how many times each process ran, how many
 * records it loaded in total, and whether it had any failures.
 */
CREATE VIEW vw_etl_summary AS
SELECT
    process_name,
    source,
    COUNT(log_id) AS total_runs,
    SUM(records_loaded) AS total_records,
    MAX(finished_at) AS last_run,
    SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS successful_runs,
    SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) AS failed_runs
FROM ETLLog
GROUP BY process_name, source;

/*
 * vw_rental_full_detail — joins RentalListing with Neighborhood
 * and City so we get a complete readable row per listing.
 * sp_get_rentals() uses this view to return data to Python.
 */
CREATE VIEW vw_rental_full_detail AS
SELECT
    rl.listing_id,
    c.name AS city,
    n.name AS neighborhood,
    rl.price,
    rl.currency,
    rl.area_m2,
    rl.scraped_date
FROM RentalListing rl
LEFT JOIN Neighborhood n ON rl.neighborhood_id = n.neighborhood_id
LEFT JOIN City c ON n.city_id = c.city_id
ORDER BY rl.scraped_date DESC;


/* STORED PROCEDURES */

/*
 * sp_insert_banxico — called by BanxicoAPIs.py for every row
 * it downloads from the API. We look up the serie_id first
 * and fall back to 0 if it's not found, so we never block
 * a Banxico insert just because the catalog is out of sync.
 */
DELIMITER $$
CREATE PROCEDURE sp_insert_banxico(
    IN p_key VARCHAR(20),
    IN p_name VARCHAR(100),
    IN p_date DATE,
    IN p_value DECIMAL(20,6)
)
BEGIN
    DECLARE v_serie_id INT DEFAULT 0;
    SELECT serie_id INTO v_serie_id FROM BanxicoSerie WHERE serie_key = p_key LIMIT 1;
    IF v_serie_id IS NULL THEN
        SET v_serie_id = 0;
    END IF;
    INSERT INTO BanxicoData (serie_id, serie_key, serie_name, record_date, value)
    VALUES (v_serie_id, p_key, p_name, p_date, p_value);
END$$
DELIMITER ;

/*
 * sp_insert_scraped_data — stores the raw text from each listing
 * before we clean it. We call this once per listing in the scraper,
 * right before calling sp_insert_rental with the parsed values.
 */
DELIMITER $$
CREATE PROCEDURE sp_insert_scraped_data(
    IN p_url VARCHAR(255),
    IN p_title TEXT
)
BEGIN
    INSERT INTO ScrapedData (source_url, title)
    VALUES (p_url, p_title);
END$$
DELIMITER ;

/*
 * sp_insert_rental — does the heavy lifting for each listing.
 * It looks up the city, checks if the neighborhood already exists
 * and inserts it if not, then finally inserts the rental record.
 * This way neighborhoods stay normalized without extra Python logic.
 */
DELIMITER $$
CREATE PROCEDURE sp_insert_rental(
    IN p_neighborhood VARCHAR(150),
    IN p_city_name VARCHAR(100),
    IN p_price DECIMAL(12,2),
    IN p_currency VARCHAR(5),
    IN p_area_m2 DECIMAL(8,1),
    IN p_session_id INT,
    IN p_scraped_date DATE
)
BEGIN
    DECLARE v_city_id INT DEFAULT NULL;
    DECLARE v_nbhd_id INT DEFAULT NULL;
    SELECT city_id INTO v_city_id FROM City WHERE name = p_city_name LIMIT 1;
    IF v_city_id IS NOT NULL THEN
        SELECT neighborhood_id INTO v_nbhd_id
        FROM Neighborhood
        WHERE name = p_neighborhood AND city_id = v_city_id LIMIT 1;
        IF v_nbhd_id IS NULL THEN
            INSERT INTO Neighborhood (name, city_id) VALUES (p_neighborhood, v_city_id);
            SET v_nbhd_id = LAST_INSERT_ID();
        END IF;
    END IF;
    INSERT INTO RentalListing (neighborhood_id, session_id, price, currency, area_m2, scraped_date)
    VALUES (v_nbhd_id, p_session_id, p_price, p_currency, p_area_m2, p_scraped_date);
END$$
DELIMITER ;

/*
 * sp_start_session — we call this at the beginning of each city's
 * scraping loop. It opens a session record and returns the new ID
 * via SELECT so Python can read it from stored_results() and pass
 * it to every sp_insert_rental call for that city.
 */
DELIMITER $$
CREATE PROCEDURE sp_start_session(
    IN p_city_name VARCHAR(100)
)
BEGIN
    DECLARE v_city_id INT DEFAULT NULL;
    SELECT city_id INTO v_city_id FROM City WHERE name = p_city_name LIMIT 1;
    INSERT INTO ScrapedSession (city_id, status) VALUES (v_city_id, 'running');
    SELECT LAST_INSERT_ID() AS session_id;
END$$
DELIMITER ;

/*
 * sp_close_session — called at the end of each city's scraping loop.
 * Updates the session with the final page count, listing count,
 * and status so we have a full record of what happened.
 */
DELIMITER $$
CREATE PROCEDURE sp_close_session(
    IN p_session_id INT,
    IN p_pages INT,
    IN p_total INT,
    IN p_status VARCHAR(20)
)
BEGIN
    UPDATE ScrapedSession
    SET pages_scraped = p_pages,
        total_listings = p_total,
        status = p_status
    WHERE session_id = p_session_id;
END$$
DELIMITER ;

/*
 * sp_log_etl_start — opens an ETL log entry when a process starts.
 * Returns the new log_id via SELECT so Python can store it
 * and pass it to sp_log_etl_finish when the process ends.
 */
DELIMITER $$
CREATE PROCEDURE sp_log_etl_start(
    IN p_process VARCHAR(100),
    IN p_source VARCHAR(50)
)
BEGIN
    INSERT INTO ETLLog (process_name, source, status)
    VALUES (p_process, p_source, 'running');
    SELECT LAST_INSERT_ID() AS log_id;
END$$
DELIMITER ;

/*
 * sp_log_etl_finish — closes the ETL log entry with final stats.
 * We pass the record count, status and any error message.
 * The trigger on ETLLog then writes the status change to Audit.
 */
DELIMITER $$
CREATE PROCEDURE sp_log_etl_finish(
    IN p_log_id INT,
    IN p_records INT,
    IN p_status VARCHAR(20),
    IN p_error TEXT
)
BEGIN
    UPDATE ETLLog
    SET finished_at = NOW(),
        records_loaded = p_records,
        status = p_status,
        error_message = p_error
    WHERE log_id = p_log_id;
END$$
DELIMITER ;

/*
 * sp_clear_banxico — wipes all Banxico data before a fresh download.
 * We use DELETE instead of TRUNCATE because CurrencySnapshot and
 * InflationIndex have foreign keys pointing to BanxicoData,
 * and TRUNCATE would fail with an FK constraint error.
 */
DELIMITER $$
CREATE PROCEDURE sp_clear_banxico()
BEGIN
    DELETE FROM InflationIndex;
    DELETE FROM CurrencySnapshot;
    DELETE FROM BanxicoData;
END$$
DELIMITER ;

/*
 * sp_clear_scraped — wipes all scraping data before a fresh run.
 * We delete in the right order to respect foreign key constraints:
 * listings first, then raw data, then sessions.
 */
DELIMITER $$
CREATE PROCEDURE sp_clear_scraped()
BEGIN
    DELETE FROM RentalListing;
    DELETE FROM ScrapedData;
    DELETE FROM ScrapedSession;
END$$
DELIMITER ;

/*
 * sp_get_banxico — returns all Banxico records ordered by date.
 * We use this to verify what's in the database after a sync,
 * and it's also available for any future reporting needs.
 */
DELIMITER $$
CREATE PROCEDURE sp_get_banxico()
BEGIN
    SELECT * FROM BanxicoData ORDER BY record_date ASC;
END$$
DELIMITER ;

/*
 * sp_get_scraped_data — returns raw scraped records for inspection.
 * Useful to debug what the scraper pulled before it got cleaned.
 */
DELIMITER $$
CREATE PROCEDURE sp_get_scraped_data()
BEGIN
    SELECT source_url, title, captured_at
    FROM ScrapedData
    ORDER BY captured_at DESC;
END$$
DELIMITER ;

/*
 * sp_get_rentals — returns all listings through the full detail view.
 * This is the procedure Python would call to read rental data
 * back from the database if needed for reporting.
 */
DELIMITER $$
CREATE PROCEDURE sp_get_rentals()
BEGIN
    SELECT * FROM vw_rental_full_detail;
END$$
DELIMITER ;

/*
 * sp_insert_serie — adds a new Banxico series to the catalog.
 * We use INSERT IGNORE so running it multiple times won't cause errors —
 * if the serie_key already exists, it just skips the insert.
 */
DELIMITER $$
CREATE PROCEDURE sp_insert_serie(
    IN p_key VARCHAR(20),
    IN p_name VARCHAR(100),
    IN p_unit VARCHAR(50),
    IN p_frequency VARCHAR(20)
)
BEGIN
    INSERT IGNORE INTO BanxicoSerie (serie_key, serie_name, unit, frequency)
    VALUES (p_key, p_name, p_unit, p_frequency);
END$$
DELIMITER ;


/* TRIGGERS */

/*
 * trg_banxico_insert — fires after every new row in BanxicoData.
 * We log the serie key, date and value so we always know
 * exactly what got inserted and when.
 */
DELIMITER $$
CREATE TRIGGER trg_banxico_insert
AFTER INSERT ON BanxicoData FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user)
    VALUES ('BanxicoData', 'INSERT', NEW.data_id, NULL,
            CONCAT(NEW.serie_key, ' | ', NEW.record_date, ' | ', NEW.value), USER());
END$$
DELIMITER ;

/*
 * trg_banxico_delete — fires when a Banxico row gets deleted,
 * which only happens when sp_clear_banxico runs before a fresh sync.
 * We capture the old values so we can trace what was wiped.
 */
DELIMITER $$
CREATE TRIGGER trg_banxico_delete
AFTER DELETE ON BanxicoData FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user)
    VALUES ('BanxicoData', 'DELETE', OLD.data_id,
            CONCAT(OLD.serie_key, ' | ', OLD.record_date, ' | ', OLD.value), NULL, USER());
END$$
DELIMITER ;

/*
 * trg_rental_insert — logs every new rental listing that comes in
 * from the scraper. We store the price and currency so the Audit
 * table gives us a quick summary of what was loaded each run.
 */
DELIMITER $$
CREATE TRIGGER trg_rental_insert
AFTER INSERT ON RentalListing FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user)
    VALUES ('RentalListing', 'INSERT', NEW.listing_id, NULL,
            CONCAT(NEW.price, ' ', NEW.currency, ' | m2: ', IFNULL(NEW.area_m2, 'N/A')), USER());
END$$
DELIMITER ;

/*
 * trg_rental_delete — fires when listings get cleared before a new scrape.
 * We log the price and currency of what was removed so we can
 * compare runs and spot major data changes.
 */
DELIMITER $$
CREATE TRIGGER trg_rental_delete
AFTER DELETE ON RentalListing FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user)
    VALUES ('RentalListing', 'DELETE', OLD.listing_id,
            CONCAT(OLD.price, ' ', OLD.currency), NULL, USER());
END$$
DELIMITER ;

/*
 * trg_session_update — captures status changes on ScrapedSession.
 * When sp_close_session updates a session from 'running' to 'success'
 * or 'error', this trigger records both the old and new status.
 */
DELIMITER $$
CREATE TRIGGER trg_session_update
AFTER UPDATE ON ScrapedSession FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user)
    VALUES ('ScrapedSession', 'UPDATE', NEW.session_id, OLD.status, NEW.status, USER());
END$$
DELIMITER ;

/*
 * trg_etl_update — same idea as trg_session_update but for ETLLog.
 * Every time sp_log_etl_finish closes a log entry, we record
 * the status transition in Audit automatically.
 */
DELIMITER $$
CREATE TRIGGER trg_etl_update
AFTER UPDATE ON ETLLog FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user)
    VALUES ('ETLLog', 'UPDATE', NEW.log_id, OLD.status, NEW.status, USER());
END$$
DELIMITER ;


-- INITIAL DATA 
/*
 * We seed the 4 cities and 4 Banxico series right after creating
 * the schema. Everything else gets populated by the Python ETL scripts.
 * Tijuana is flagged as a border city (is_border = 1) because that
 * distinction matters for our gentrification analysis.
 */
INSERT INTO City (name, state, country, is_border) VALUES
('Tijuana', 'Baja California', 'Mexico', 1),
('CDMX', 'Ciudad de Mexico', 'Mexico', 0),
('Monterrey', 'Nuevo Leon', 'Mexico', 0),
('Guadalajara', 'Jalisco', 'Mexico', 0);

INSERT INTO BanxicoSerie (serie_key, serie_name, unit, frequency) VALUES
('SF43718', 'Exchange Rate USD/MXN', 'MXN per USD', 'daily'),
('SP1', 'INPC Inflation Index', 'Index 2018=100', 'monthly'),
('SF43784', 'Border Zone Minimum Wage', 'MXN per day', 'annual'),
('SF3338', 'TIIE Interest Rate', 'Percentage', 'daily');


/* VERIFY */

/*
 * Run these after the initial setup to confirm everything was created.
 * After running BanxicoAPIs.py and scraper_tijuana.py, the counts
 * on BanxicoData and RentalListing should show actual records.
 */
SHOW TABLES;
SHOW PROCEDURE STATUS WHERE Db = 'cafeteria';
SHOW TRIGGERS FROM cafeteria;
SELECT * FROM City;
SELECT * FROM BanxicoSerie;

SELECT COUNT(*) AS total_banxico_records FROM BanxicoData;
SELECT serie_name, COUNT(*) AS records,
       MIN(record_date) AS from_date,
       MAX(record_date) AS to_date
FROM BanxicoData
GROUP BY serie_name;

SELECT session_id, c.name AS city, started_at, pages_scraped, total_listings, status
FROM ScrapedSession ss
JOIN City c ON ss.city_id = c.city_id
ORDER BY session_id DESC;

SELECT COUNT(*) AS total_scraped_records FROM ScrapedData;
SELECT COUNT(*) AS total_listings FROM RentalListing;

SELECT c.name AS city, rl.currency,
       COUNT(*) AS listings,
       ROUND(AVG(rl.price), 2) AS avg_price,
       ROUND(MIN(rl.price), 2) AS min_price,
       ROUND(MAX(rl.price), 2) AS max_price
FROM RentalListing rl
LEFT JOIN ScrapedSession ss ON rl.session_id = ss.session_id
LEFT JOIN City c ON ss.city_id = c.city_id
GROUP BY c.name, rl.currency
ORDER BY avg_price DESC;

SELECT COUNT(*) AS total_audit_records FROM Audit;
SELECT affected_table, operation, COUNT(*) AS count
FROM Audit
GROUP BY affected_table, operation
ORDER BY affected_table;

SELECT * FROM vw_banxico_annual_trend LIMIT 10;
SELECT * FROM vw_rental_by_city;
SELECT * FROM vw_top_neighborhoods LIMIT 10;
SELECT * FROM vw_exchange_rate_annual LIMIT 5;
SELECT * FROM vw_etl_summary;
SELECT * FROM vw_rental_full_detail LIMIT 10;
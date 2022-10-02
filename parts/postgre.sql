--
-- postgre.sql -- draft PostgreSQL schemata of Menugene
--
-- Since the current Oracle DB is not documented anywhere, the best chance
-- you can take is looking at SCHEMA menugene_am, which is close enough on
-- the conceptual level at least to what can be seen in Oracle today.
--
-- Design Recommendations {{{
-- ==========================
--
-- 1. Choose and follow a naming convention.
-- -----------------------------------------
--
-- The point is to make identifiers recognisable out of context,
-- so you and your friends will have easier time talking about them.
-- You may wish to disambiguate entity tables, relation tables,
-- views, types, functions and such.
-- Also, it is easier to JOIN ... USING rather than JOIN ... ON,
-- so consider calling foo "foo" everywhere in your schema.
--
-- In the meantime it is a good idea to choose your identifiers
-- not to clash with SQL keywords and to leave them case insensitive
-- because otherwise you'll need to quote them all the time.
--
-- 2. Forget NUMERIC.  Use INTEGER and unsigned.
-- ---------------------------------------------
--
-- NUMERIC is a string that Postgres can calculate with. up to
-- infinite precision.  Most of the time you don't need that,
-- so why not use a natural INTEGER?  Or unsigned or unreal
-- (see the public schema) for columns you know they won't
-- (therefore shouldn't) contain negative numbers.  Well-known
-- candidates are identifier and quantity columns.
--
-- 3. Forget VARCHAR(x).  Use VARCHAR and TEXT.
-- --------------------------------------------
--
-- There is no perfomance penalty imposed by VARCHAR. Neither by TEXT.
-- All that the (x) restriction brings to you is, well, the restriction
-- of max length of the column, which can bite you in the ass very well.
-- Actually, CHAR(n) is worse than VARCHAR because the former will
-- *always* take up overhead + n byte storage due to space padding.
--
-- 4. Use DOMAIN:s to create enumerated types.
-- -------------------------------------------
--
-- The situation is that you have a small set of predefined meanings
-- and you want to ensure some column can only have one of these.
-- How these meanings encoded is unimportant.
--
-- The textbook approach is to create a table of code-description pairs
-- and have columns REFERENCES to .code.  This works, but the price is
-- a new table.  Lots of enums, lots of tables, great annoyance keeping
-- them out of way and out of mind.  Observe the .description column:
-- it's unnecessary for the DBM and for the application because they
-- can't understand it anyway.  It's documentation---for humans.
--
-- PostgreSQL provides an easy way to create new types either restricting
-- or extending old ones.  Then you can COMMENT on them to explain the
-- meaning of the codes.  Example:
--
-- CREATE DOMAIN personality AS "char" CHECK (VALUE BETWEEN 0 AND 3);
-- COMMENT ON DOMAIN personality
-- 	IS '0: nasty, 1: stupid, 2: idiot, 3: crazy';
--
-- (You may substitute "char" with SMALLINT or INTEGER.)
-- Executing these commands you will be able to use personality as a
-- first class database object type, and you will have saved one table.
--
-- 5. Use column and table constraints generously.
-- -----------------------------------------------
--
-- Of course, this is what they taught you in database theory classes
-- (or what you tell in those classes if you happen to be the teacher).
-- The usual reasoning is to ensure consistency by making it impossible
-- to enter bogus rows.  Another reason is documentation.  Whenever
-- a human sees REFERENCES it will immedeately become obvious that
-- this table has something to do with another one, without requiring
-- him to read your (hopefully extensive) COMMENT:s.
--
-- When you define a column it might be inspiring to ask yourself;
-- -- Is there any reason to have two rows in this table sharing
--    the same value for this column?  If not, then let it be UNIQUE.
-- -- Would it be meaningful to have .column IS NULL?
-- -- Can the value of this column be negative under any circumstances?
--    Can we restrict the possible values?  Then CHECK().
--
-- It is also wise to require the UNIQUE:ness of relations between
-- entities (UNIQUE (entity1, entity2)), because that's what the
-- application expects most of the time.  Never mind the performance cost.
--
-- 6. Learn and use PostgreSQL extensions.
-- ---------------------------------------
--
-- Some would argue against this due to ill concerns about portability,
-- and advise that you stick with the most widespread features.
--
-- There are numerous problems with such views:
-- -- The "common estate" is indeed small.  Not even the most basic
--    SQL operations (SELECT, INSERT) are the same across different
--    database managers, not to mention the available data types.
--    Granted, "SELECT * FROM tbl" works the same way everywhere,
--    but RIGHT OUTER JOIN might not.  And we haven't talked about
--    transaction isolation, locking, performance etc. which are not
--    just syntactic differences, but behavioral ones.  Insisting on
--    the common wealth sacrifices so much that your task may become
--    impossible to carry out.  Extensions are made for you, use them.
-- -- The term "portable" is often misunderstood as the condition
--    "I can take *my product* and snap to another standard-conformant
--    component without much hassle".  In the SQL realm, portability
--    tends to refer to your ideas and intelligence rather than to
--    your product, which means you don't have to learn a new language
--    from the scratch every time you sit down in front of another DBM
--    because the basic concepts are the same everywhere; you may reuse
--    your previous ideas and experience, but you should not expect it
--    to work the same way as the other one does.
-- -- Database managers are large and complex beasts, and they happen
--    to integrate tighter and tighter with the application every year.
--    Developing in the constant fear of replacing the DBM is like
--    expecting to rewrite your entire product in another programming
--    language.  It might happen, yes, but you gotta have strong reason
--    to actually *design* for that.
--
-- While one may disagree with (2) and (3) rebuttal of (1) seems hard.
-- Anyway, my favourite pets are DOMAIN:s, table inheritance, partial
-- indices, indices over expressions, arrays, compound types and EXECUTE.
--
-- 7. Practice your language skills.  Document.
-- --------------------------------------------
--
-- Ask your favorite career manager and I bet he'll give long lectures
-- about the importance of verbal intelligence.  Also think about the
-- many insults you'll be awarded by me for not doing item 2.
-- }}}
--

------------------------- public ---------------------- {{{

-- Public harmless stuff that might be of interest for any SCHEMA.
-- Consider adding SCHEMA public to your search_path so you can
-- refer to the goodies here without extra handwork.
--
-- [Maintainer: adam]
CREATE SCHEMA public;
SET search_path TO public;

--- Types ---
-------------

-- Use this type (domain) whenever you would use an "unsigned"
-- in a C program, such as declaring object identifier.
CREATE DOMAIN unsigned AS INTEGER CHECK (VALUE >= 0);

-- Unsigned float.  One usage area is to express quantities,
-- which cannot be negative.
--
-- To my surprise no programming language known to me offers
-- such data type.  (Java is a prime sinner because it does
-- neither have unsigned integers.)
CREATE DOMAIN unreal AS REAL CHECK (VALUE >= 0);

------------------------- public ---------------------- }}}

------------------------- main ------------------------ {{{

-- [Maintainer: Herczi]
CREATE SCHEMA main;
SET search_path TO main;

--- Functions {{{
-----------------

CREATE FUNCTION start_session(userid integer) RETURNS integer AS
$$
DECLARE
	uid ALIAS FOR $1;
	sessionStart timestamp DEFAULT now();
BEGIN
	BEGIN
		INSERT INTO main.session
			(user_id, sess_start)
			VALUES (uid, sessionStart);
	EXCEPTION WHEN foreign_key_violation
	THEN
		RETURN -2;
	END;

	RETURN currval('main.session_session_id_seq'::text);
END
$$ LANGUAGE PLPGSQL;

CREATE FUNCTION end_session(sessionid integer) RETURNS boolean AS
$$
DECLARE
	sid ALIAS FOR $1;
	ts timestamp default now();
BEGIN
	UPDATE main.session SET sess_end=ts WHERE session_id=sid;
	RETURN FOUND;
END
$$ LANGUAGE PLPGSQL;

CREATE FUNCTION is_active(sessionid integer) RETURNS boolean AS
$$
DECLARE
	dummy RECORD;
BEGIN
	SELECT INTO dummy * FROM main.session
		WHERE session_id=$1 AND sess_end IS NULL
		LIMIT 1;
	RETURN FOUND;
END
$$ LANGUAGE PLPGSQL;

CREATE FUNCTION raise_event(sessionid integer, eventcode integer)
	RETURNS boolean AS
$$
DECLARE
	act BOOLEAN;
	ts TIMESTAMP DEFAULT now();
BEGIN
	act := main.is_active(sessionid::integer);
	IF act = FALSE
	THEN
		RETURN FALSE;
	END IF;

	BEGIN
		INSERT INTO main.event
			(session_id, event_code, timestamp)
			VALUES (sessionid, eventcode, ts);
	EXCEPTION WHEN integrity_constraint_violation
	THEN
		RETURN FALSE;
	END;

	RETURN TRUE;
END
$$ LANGUAGE PLPGSQL;
--- Functions }}}

--- Tables {{{
--------------

CREATE TABLE "user" (
	user_id		SERIAL			PRIMARY KEY,
	usertype_code	INTEGER			NOT NULL
);

CREATE TABLE "session" (
	session_id	SERIAL				PRIMARY KEY,
	user_id		INTEGER				NOT NULL
			REFERENCES "user"(user_id),
	sess_start	TIMESTAMP WITHOUT TIME ZONE	NOT NULL,
	sess_end	TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE codeset (
	codeset_id	INTEGER			PRIMARY KEY,
	codeset_name	VARCHAR(100)		NOT NULL
);

CREATE TABLE code (
	codeset_id	INTEGER			NOT NULL
			REFERENCES codeset(codeset_id),
	code_no		INTEGER			NOT NULL,
	"desc"		VARCHAR(50)		NOT NULL,
	long_desc	VARCHAR(150),
	PRIMARY KEY (codeset_id, code_no)
);

CREATE TABLE lang (
	langid		SERIAL			PRIMARY KEY,
	langname	VARCHAR(250)		NOT NULL UNIQUE,
	langcode	VARCHAR(5)		NOT NULL UNIQUE
);

CREATE TABLE sn (
	snid		SERIAL			PRIMARY KEY,
	snname		VARCHAR(250)
);

CREATE TABLE c_sn_lang (
	snid		INTEGER			NOT NULL,
	langid		INTEGER			NOT NULL,
	name		VARCHAR
);

CREATE TABLE measure (
	measureid	SERIAL			PRIMARY KEY,
	snid		INTEGER			NOT NULL UNIQUE
			REFERENCES sn(snid),
	name		VARCHAR(250)		UNIQUE
);

CREATE TABLE event (
	event_id	SERIAL				PRIMARY KEY,
	session_id	INTEGER				NOT NULL
			REFERENCES "session"(session_id),
	event_code	INTEGER				NOT NULL,
	"timestamp"	TIMESTAMP WITHOUT TIME ZONE	NOT NULL
);
--- Tables }}}

------------------------- main ------------------------ }}}

------------------------- anam ------------------------ {{{

-- [Author: Rajcsanyi, Viktor]
CREATE SCHEMA anam;
SET search_path TO anam;

--- Tables ---
--------------

CREATE TABLE korkategoriak (
	kor_id		SERIAL				NOT NULL,
	kategoria	BIGINT,
	tol		BIGINT,
	ig		BIGINT
);

CREATE TABLE munka_tipus (
	munka_tipusid	SERIAL				NOT NULL,
	leiras		TEXT,
	szorzo		DOUBLE PRECISION
);

CREATE TABLE munka (
	munkaid		SERIAL				NOT NULL,
	nev		TEXT,
	munka_tipusid	BIGINT
);

CREATE TABLE munka_tmp (
	id		SERIAL				NOT NULL,
	munka_id	BIGINT,
	idotartam	DOUBLE PRECISION,
	partner_id	BIGINT
);

CREATE TABLE sport_tipus (
	sport_tipusid	SERIAL				NOT NULL,
	leiras		TEXT
);

CREATE TABLE sport (
	sportid		SERIAL				NOT NULL,
	nev		TEXT,
	sport_tipusid	BIGINT
);

CREATE TABLE sport_tmp (
	id serial	NOT NULL,
	sport_id	BIGINT,
	partner_id	BIGINT
);

CREATE TABLE sportolok (
	sportolok_id	SERIAL				NOT NULL,
	kategoria	BIGINT,
	e_min		BIGINT,
	e_max		BIGINT,
	feherje		DOUBLE PRECISION,
	zsir		DOUBLE PRECISION,
	mufa		DOUBLE PRECISION,
	pufa		DOUBLE PRECISION,
	sfa		DOUBLE PRECISION,
	tr_zsirsav	DOUBLE PRECISION,
	szenhidrat	DOUBLE PRECISION,
	rost		DOUBLE PRECISION,
	koleszterin	DOUBLE PRECISION,
	vit_a		DOUBLE PRECISION,
	vit_b1_min	DOUBLE PRECISION,
	vit_b1_max	DOUBLE PRECISION,
	vit_b2		DOUBLE PRECISION,
	vit_b6_min	DOUBLE PRECISION,
	vit_b6_max	DOUBLE PRECISION,
	vit_b12		DOUBLE PRECISION,
	vit_c		DOUBLE PRECISION,
	vit_d		DOUBLE PRECISION,
	vit_e		DOUBLE PRECISION,
	vit_k		DOUBLE PRECISION,
	niacin		DOUBLE PRECISION,
	folat		DOUBLE PRECISION,
	pantotensav	DOUBLE PRECISION,
	ca		DOUBLE PRECISION,
	p		DOUBLE PRECISION,
	na		DOUBLE PRECISION,
	k		DOUBLE PRECISION,
	cl		DOUBLE PRECISION,
	mg		DOUBLE PRECISION,
	fe		DOUBLE PRECISION,
	cu		DOUBLE PRECISION,
	zn		DOUBLE PRECISION,
	i		DOUBLE PRECISION,
	mn		DOUBLE PRECISION,
	fl		DOUBLE PRECISION,
	cr		DOUBLE PRECISION,
	se		DOUBLE PRECISION,
	mo		DOUBLE PRECISION,
);

CREATE TABLE szabadido_tipus (
	szabadido_tipusid	SERIAL				NOT NULL,
	szorzo			DOUBLE PRECISION,
	leiras			TEXT,
);

CREATE TABLE szabadido (
	szabadidoid		SERIAL				NOT NULL,
	nev			TEXT
	szabadido_tipusid	BIGINT,
);


CREATE TABLE szabadido_tmp (
	id		SERIAL					NOT NULL,
	szabadido_id	BIGINT,
	idotartam	DOUBLE PRECISION,
	partner_id	BIGINT
);

CREATE TABLE tapanyag (
	id		SERIAL					NOT NULL,
	nem		CHARACTER,
	korkategoria	BIGINT,
	e_alap		BIGINT,
	e_szorzo	DOUBLE PRECISION,
	feherje		DOUBLE PRECISION,
	zsir		DOUBLE PRECISION,
	mufa		DOUBLE PRECISION,
	pufa		DOUBLE PRECISION,
	sfa		DOUBLE PRECISION,
	tr_zsirsav	DOUBLE PRECISION,
	szenhidrat	DOUBLE PRECISION,
	rost		DOUBLE PRECISION,
	koleszterin	DOUBLE PRECISION,
	vit_a		DOUBLE PRECISION,
	vit_b1		DOUBLE PRECISION,
	vit_b2		DOUBLE PRECISION,
	vit_b6		DOUBLE PRECISION,
	vit_b12		DOUBLE PRECISION,
	vit_c		DOUBLE PRECISION,
	vit_d		DOUBLE PRECISION,
	vit_e		DOUBLE PRECISION,
	vit_k		DOUBLE PRECISION,
	niacin		DOUBLE PRECISION,
	folat		DOUBLE PRECISION,
	pantotensav	DOUBLE PRECISION,
	ca		DOUBLE PRECISION,
	p		DOUBLE PRECISION,
	na		DOUBLE PRECISION,
	k		DOUBLE PRECISION,
	cl		DOUBLE PRECISION,
	mg		DOUBLE PRECISION,
	fe		DOUBLE PRECISION,
	cu		DOUBLE PRECISION,
	zn		DOUBLE PRECISION,
	i		DOUBLE PRECISION,
	mn		DOUBLE PRECISION,
	fl		DOUBLE PRECISION,
	cr		DOUBLE PRECISION,
	se		DOUBLE PRECISION,
	mo		DOUBLE PRECISION,
	vit_k_min	DOUBLE PRECISION,
	vit_k_max	DOUBLE PRECISION
);

------------------------- anam ------------------------ }}}

------------------------- usda ------------------------ {{{

-- Csak az eredeti USDA tablak tarolasara, esetleg meg egy-ket view.
-- [Maintainer: VI]
CREATE SCHEMA usda;
SET search_path TO usda;

--- Functions {{{
-----------------

-- Beszur egy uj alapanyagot az usda.food_des es abbrev_menugene tablakba.
-- Karbantartja: V.I., 2006. jul.
CREATE FUNCTION uj_alapanyag(menugene_elelmiszerid INTEGER) RETURNS VARCHAR AS
$$
DECLARE
	uj_id_int INT;
	uj_id VARCHAR(6);
BEGIN
	SELECT INTO uj_id_int MAX("NDB_No") FROM usda.food_des;
	IF uj_id < 1 OR uj_id > 999999
	THEN
		RAISE EXCEPTION 'Sikertelen id generalas (usda.food_des)';
		RETURN NULL;
	END IF;

	uj_id := CAST(uj_id_int + 1 AS VARCHAR);
	-- RAISE NOTICE 'Az uj ID: %', uj_id;
	INSERT INTO usda.food_des
		("NDB_No", "Long_Desc")
		VALUES (uj_id, 'No long description available');
	INSERT INTO usda.abbrev_menugene (ndb_no) VALUES (uj_id);
	-- RAISE NOTICE 'menugene_elelmiszerid: %', menugene_elelmiszerid;
	UPDATE recept.alapanyag SET usda_ndb_no=uj_id
		WHERE sorszam = menugene_elelmiszerid;
	RETURN uj_id;
END
$$ LANGUAGE PLPGSQL;
--- Functions }}}

--- Tables {{{
--------------

CREATE TABLE food_des (
	"NDB_No"	VARCHAR(6)		PRIMARY KEY,
	"FdGrp_Cd"	VARCHAR(4),
	"Long_Desc"	VARCHAR(200),
	"Shrt_Desc"	VARCHAR(60),
	"ComName"	VARCHAR(100),
	"ManufacName"	VARCHAR(50),
	"Survey"	VARCHAR(1),
	"Ref_Desc"	VARCHAR(60),
	"Refuse"	SMALLINT,
	"SciName"	VARCHAR(60),
	"N_Factor"	DOUBLE PRECISION,
	"Pro_Factor"	DOUBLE PRECISION,
	"Fat_Factor"	DOUBLE PRECISION,
	"CHO_Factor"	DOUBLE PRECISION
);

CREATE TABLE abbrev (
	"NDB_No"	VARCHAR(5)		PRIMARY KEY
			REFERENCES food_des("NDB_No"),
	"Water"		DOUBLE PRECISION,
	"Energ_Kcal"	INTEGER,
	"Protein"	DOUBLE PRECISION,
	"Lipid_Tot"	DOUBLE PRECISION,
	"Ash"		DOUBLE PRECISION,
	"Carbohydrt"	DOUBLE PRECISION,
	"Fiber_TD"	DOUBLE PRECISION,
	"Sugar_Tot"	REAL,
	"Calcium"	INTEGER,
	"Iron"		DOUBLE PRECISION,
	"Magnesium"	INTEGER,
	"Phosphorus"	INTEGER,
	"Potassium"	INTEGER,
	"Sodium"	INTEGER,
	"Zinc"		DOUBLE PRECISION,
	"Copper"	DOUBLE PRECISION,
	"Manganese"	DOUBLE PRECISION,
	"Selenium"	DOUBLE PRECISION,
	"Vit_C"		DOUBLE PRECISION,
	"Thiamin"	DOUBLE PRECISION,
	"Riboflavin"	DOUBLE PRECISION,
	"Niacin"	DOUBLE PRECISION,
	"Panto_acid"	DOUBLE PRECISION,
	"Vit_B6"	DOUBLE PRECISION,
	"Folate_Tot"	INTEGER,
	"Folic_acid"	INTEGER,
	"Food_Folate"	INTEGER,
	"Folate_DFE"	INTEGER,
	"Vit_B12"	DOUBLE PRECISION,
	"Vit_A_IU"	INTEGER,
	"Vit_A_RAE"	INTEGER,
	"Retinol"	INTEGER,
	"Vit_E"		REAL,
	"Vit_K"		REAL,
	"Alpha_Carot"	DOUBLE PRECISION,
	"Beta_Carot"	DOUBLE PRECISION,
	"Beta_Crypt"	DOUBLE PRECISION,
	"Lycopene"	DOUBLE PRECISION,
	"Lut+Zea"	DOUBLE PRECISION,
	"FA_SAT"	DOUBLE PRECISION,
	"FA_Mono"	DOUBLE PRECISION,
	"FA_Poly"	DOUBLE PRECISION,
	"Cholesterl"	INTEGER,
	"GmWt_1"	DOUBLE PRECISION,
	"GmWt_Desc1"	VARCHAR(120),
	"GmWt_2"	DOUBLE PRECISION,
	"GmWt_Desc2"	VARCHAR(120),
	"Refuse_Pct"	INTEGER,
	"Shrt_Desc"	VARCHAR(60)
);

-- Azok az alapanyagok, melyeknek mi adjuk meg kezzel az osszetetelet,
-- mert nincsenek az usda.abbrev tablaban.
CREATE TABLE abbrev_menugene (
	"NDB_No"	VARCHAR(6)		PRIMARY KEY
			REFERENCES food_des("NDB_No"),
			-- Az usda.abbrev-ban nem levo alapanyag ID-je.
	"Water"		DOUBLE PRECISION,
	"Energ_Kcal"	INTEGER,
	"Protein"	DOUBLE PRECISION,
	"Lipid_Tot"	DOUBLE PRECISION,
	"Ash"		DOUBLE PRECISION,
	"Carbohydrt"	DOUBLE PRECISION,
	"Fiber_TD"	DOUBLE PRECISION,
	"Sugar_Tot"	REAL,
	"Calcium"	INTEGER,
	"Iron"		DOUBLE PRECISION,
	"Magnesium"	INTEGER,
	"Phosphorus"	INTEGER,
	"Potassium"	INTEGER,
	"Sodium"	INTEGER,
	"Zinc"		DOUBLE PRECISION,
	"Copper"	DOUBLE PRECISION,
	"Manganese"	DOUBLE PRECISION,
	"Selenium"	DOUBLE PRECISION,
	"Vit_C"		DOUBLE PRECISION,
	"Thiamin"	DOUBLE PRECISION,
	"Riboflavin"	DOUBLE PRECISION,
	"Niacin"	DOUBLE PRECISION,
	"Panto_acid"	DOUBLE PRECISION,
	"Vit_B6"	DOUBLE PRECISION,
	"Folate_Tot"	INTEGER,
	"Folic_acid"	INTEGER,
	"Food_Folate"	INTEGER,
	"Folate_DFE"	INTEGER,
	"Vit_B12"	DOUBLE PRECISION,
	"Vit_A_IU"	INTEGER,
	"Vit_A_RAE"	INTEGER,
	"Retinol"	INTEGER,
	"Vit_E"		REAL,
	"Vit_K"		REAL,
	"Alpha_Carot"	DOUBLE PRECISION,
	"Beta_Carot"	DOUBLE PRECISION,
	"Beta_Crypt"	DOUBLE PRECISION,
	"Lycopene"	DOUBLE PRECISION,
	"Lut+Zea"	DOUBLE PRECISION,
	"FA_SAT"	DOUBLE PRECISION,
	"FA_Mono"	DOUBLE PRECISION,
	"FA_Poly"	DOUBLE PRECISION,
	"Cholesterl"	INTEGER,
	"GmWt_1"	DOUBLE PRECISION,
	"GmWt_Desc1"	VARCHAR(120),
	"GmWt_2"	DOUBLE PRECISION,
	"GmWt_Desc2"	VARCHAR(120),
	"Refuse_Pct"	INTEGER,
	"Shrt_Desc"	VARCHAR(60)
);
--- Tables }}}

--- Views {{{
-------------

CREATE VIEW vi_usda_anyag AS
SELECT a."NDB_No" AS usda_sorszam, f."Long_Desc" AS long_desc,
	a."Water", a."Energ_Kcal", a."Protein", a."Lipid_Tot",
	a."Ash", a."Carbohydrt", a."Fiber_TD", a."Sugar_Tot",
	a."Calcium", a."Iron", a."Magnesium", a."Phosphorus",
	a."Potassium", a."Sodium", a."Zinc", a."Copper", a."Manganese",
	a."Selenium", a."Vit_C", a."Thiamin", a."Riboflavin", a."Niacin",
	a."Panto_acid", a."Vit_B6", a."Folate_Tot", a."Folic_acid",
	a."Food_Folate", a."Folate_DFE", a."Vit_B12", a."Vit_A_IU",
	a."Vit_A_RAE", a."Retinol", a."Vit_E", a."Vit_K", a."Alpha_Carot",
	a."Beta_Carot", a."Beta_Crypt", a."Lycopene", a."Lut+Zea",
	a."FA_SAT", a."FA_Mono", a."FA_Poly", a."Cholesterl", a."GmWt_1",
	a."GmWt_Desc1", a."GmWt_2", a."GmWt_Desc2", a."Refuse_Pct",
	a."Shrt_Desc", a."NDB_No"
	FROM (vi_minden_anyag a JOIN food_des f ON (((a."NDB_No")::text = (f."NDB_No")::text)));

-- Az eredeti es az altalunk felvett elelmiszerek az abbrev es az
-- abbrev_menugene tablakbol.
CREATE VIEW vi_minden_anyag AS
SELECT	abbrev."Water", abbrev."Energ_Kcal", abbrev."Protein",
	abbrev."Lipid_Tot", abbrev."Ash", abbrev."Carbohydrt",
	abbrev."Fiber_TD", abbrev."Sugar_Tot", abbrev."Calcium",
	abbrev."Iron", abbrev."Magnesium", abbrev."Phosphorus",
	abbrev."Potassium", abbrev."Sodium", abbrev."Zinc", abbrev."Copper",
	abbrev."Manganese", abbrev."Selenium", abbrev."Vit_C",
	abbrev."Thiamin", abbrev."Riboflavin", abbrev."Niacin",
	abbrev."Panto_acid", abbrev."Vit_B6", abbrev."Folate_Tot",
	abbrev."Folic_acid", abbrev."Food_Folate", abbrev."Folate_DFE",
	abbrev."Vit_B12", abbrev."Vit_A_IU", abbrev."Vit_A_RAE",
	abbrev."Retinol", abbrev."Vit_E", abbrev."Vit_K",
	abbrev."Alpha_Carot", abbrev."Beta_Carot", abbrev."Beta_Crypt",
	abbrev."Lycopene", abbrev."Lut+Zea", abbrev."FA_SAT",
	abbrev."FA_Mono", abbrev."FA_Poly", abbrev."Cholesterl",
	abbrev."GmWt_1", abbrev."GmWt_Desc1", abbrev."GmWt_2",
	abbrev."GmWt_Desc2", abbrev."Refuse_Pct", abbrev."Shrt_Desc",
	abbrev."NDB_No"
	FROM abbrev
UNION SELECT abbrev_menugene."Water", abbrev_menugene."Energ_Kcal",
	abbrev_menugene."Protein", abbrev_menugene."Lipid_Tot",
	abbrev_menugene."Ash", abbrev_menugene."Carbohydrt",
	abbrev_menugene."Fiber_TD", abbrev_menugene."Sugar_Tot",
	abbrev_menugene."Calcium", abbrev_menugene."Iron",
	abbrev_menugene."Magnesium", abbrev_menugene."Phosphorus",
	abbrev_menugene."Potassium", abbrev_menugene."Sodium",
	abbrev_menugene."Zinc", abbrev_menugene."Copper",
	abbrev_menugene."Manganese", abbrev_menugene."Selenium",
	abbrev_menugene."Vit_C", abbrev_menugene."Thiamin",
	abbrev_menugene."Riboflavin", abbrev_menugene."Niacin",
	abbrev_menugene."Panto_acid", abbrev_menugene."Vit_B6",
	abbrev_menugene."Folate_Tot", abbrev_menugene."Folic_acid",
	abbrev_menugene."Food_Folate", abbrev_menugene."Folate_DFE",
	abbrev_menugene."Vit_B12", abbrev_menugene."Vit_A_IU",
	abbrev_menugene."Vit_A_RAE", abbrev_menugene."Retinol",
	abbrev_menugene."Vit_E", abbrev_menugene."Vit_K",
	abbrev_menugene."Alpha_Carot", abbrev_menugene."Beta_Carot",
	abbrev_menugene."Beta_Crypt", abbrev_menugene."Lycopene",
	abbrev_menugene."Lut+Zea", abbrev_menugene."FA_SAT",
	abbrev_menugene."FA_Mono", abbrev_menugene."FA_Poly",
	abbrev_menugene."Cholesterl", abbrev_menugene."GmWt_1",
	abbrev_menugene."GmWt_Desc1", abbrev_menugene."GmWt_2",
	abbrev_menugene."GmWt_Desc2", abbrev_menugene."Refuse_Pct",
	abbrev_menugene."Shrt_Desc", abbrev_menugene.ndb_no AS "NDB_No"
	FROM abbrev_menugene;
--- Views }}}

------------------------- usda ------------------------ }}}

------------------------- usda_am --------------------- {{{

-- The usda_am schema is the same as SCHEMA usda, just tidied up a bit.
-- It is intended to be drop-in compatible with the original one.
--
-- Differences:
-- -- Column names are case insensitive.
--    Manual querying was difficult because object names
--    needed to be quoted all the time.
-- -- Columns are defined with more appropriate types.
--    -- INTEGER	=> unsigned
--       Usually you mean that and don't want negatives.
--    -- VARCHAR(x)	=> VARCHAR
--       Restricting VARCHAR does not buy you anything
--       in PostgreSQL.
--    -- DOUBLE PRECISION => unreal
--       Usually you don't need the extra precision;
--       OTOH you win space and therefore performance.
--    -- .NDB_No has become unsigned
--       Can't quite understand why it was VARCHAR().
-- -- Added reasonable column constraints.
--    -- .*_Desc become UNIQUE.
--       Unfortunately, it broke FUNCTION uj_alapanyag().
--       (FWIW (1) and (2) broke it anyway.)
-- -- TABLE abbrev_menugene INHERITS from TABLE abbrev.
--    Makes more sense: table inheritance is just for that.
--    At least we can get rid of those horrid VIEW:s.
--
-- I recommend that you replace SCHEMA usda by this one.
--
-- [Maintainer: adam]
CREATE SCHEMA usda_am;
SET search_path TO usda_am, public;

--- Functions {{{
-----------------

-- Finds an unused NDB_No for a new alapanyag, and adds it
-- to food_des and abbrev_menugene.  Updates recept.alapanyag.usda_ndb
-- for alapanyag $1.  Returns the new NDB_No.
--
-- (Hey V.I., ever occurred to you that you carry the name
-- of a very advanced text editor?)
CREATE FUNCTION uj_alapanyag(unsigned) RETURNS unsigned AS
$$
DECLARE
	recept_alapanyag_id	ALIAS FOR $1;
	usda_id			unsigned;
BEGIN
	SELECT INTO usda_id (MAX(NDB_No) + 1) FROM food_des;

	INSERT INTO food_des (NDB_No, Long_Desc) VALUES (usda_id, NULL);
	INSERT INTO abbrev_menugene (NDB_No) VALUES (usda_id);
	UPDATE recept.alapanyag SET usda_ndb_no=usda_id
		WHERE sorszam = recept_alapanyag_id;

	RETURN usda_id;
END
$$ LANGUAGE PLPGSQL;
--- Functions }}}

--- Tables {{{
--------------

-- Food descriptions.
--
-- The following corrections have been made to the table:
--
-- UPDATE food_des SET Shrt_Desc = 'SOY MILK,CHOC,FLUID'
--	WHERE NDB_No = 16166;
-- UPDATE food_des SET Shrt_Desc = 'INF FORMULA, MEAD JOHNSON, '
--		|| 'ENF,LAF LIP, W/IR LIQ CON NOT RE'
--	WHERE NDB_No = 3830;
--
-- [TODO] Food groups (.FdGrp_Cd) may be worth importing from USDA.
CREATE TABLE food_des (
	NDB_No		unsigned		PRIMARY KEY,
			-- 5-digit Nutrient Databank number that
			-- uniquely identifies a food item.
	FdGrp_Cd	CHAR(4),
			-- 4-digit code indicating food group to which
			-- a food item belongs.
	Long_Desc	VARCHAR			UNIQUE,
			-- Long description of the food item.
	Shrt_Desc	VARCHAR			UNIQUE,
			-- Abbreviated description of the food item.
			-- Generated from the long description using
			-- abbreviations in appendix A. If the short
			-- description was longer than 60 characters,
			-- additional abbreviations were made.
	ComName		VARCHAR,
			-- Other names commonly used to describe a food,
			-- including local or regional names for various
			-- foods, for example, "soda" or "pop" for
			-- "carbonated beverages".
	ManufacName	VARCHAR,
			-- Indicates the company that manufactured the
			-- product, when appropriate.
	Survey		VARCHAR,
			-- Indicates if the food item is used in the USDA
			-- Food and Nutrient Database for Dietary Studies
			-- (FNDDS) and has a complete nutrient profile for
			-- a specified set of nutrients.
	Ref_Desc	VARCHAR,
			-- Description of inedible parts of a food item
			-- (refuse), such as seeds or bone.
	Refuse		unsigned,
			-- Amount of inedible material (for example,
			-- seeds, bone, and skin) for applicable foods,
			-- expressed as a percentage of the total weight
			-- of the item as purchased, and they are used
			-- to compute the weight of the edible portion.
	SciName		VARCHAR,
			-- Scientific name of the food item.  Given for the
			-- least processed form of the food (usually raw),
			-- if applicable.
	N_Factor	unreal,
			-- Factor for converting nitrogen to protein.
	Pro_Factor	unreal,
			-- Factor for calculating calories from protein.
	Fat_Factor	unreal,
			-- Factor for calculating calories from fat.
	CHO_Factor	unreal
			-- Factor for calculating calories from carbohydrate.
);

-- This is the abbreviated table, which contains all the food items,
-- but fewer nutrients and other related information than what is
-- provided by all USDA files.  It excludes values for starch, fluoride,
-- total choline and betaine, added vitamin E and added vitamin B12,
-- alcohol, caffeine, theobromine, vitamin D, phytosterols, or individual
-- amino acids, fatty acids, and sugars. 
--
-- NULL:s for nutrition components mean missing values.
-- .GmWt_* are NULL for some hundred entries, which I find odd.
--
-- Calculate the amount of nutrient in edible portion of 1 pound
-- as purchased by:
--	Y := V*4.536*[(100-R)/100] == (V/100 * 1000) * (100-R)/100 * 0.4536
--	V == nutrient value per 100g (abbrev.{Water,Vitamin_C,...})
--	R == percent refuse (food_des.Refuse)
--
-- (We mean avoirdupois pounds here, which equals to 0.453592 kg.)
-- (NOTE `V' is in mg/100g for some nutrients!)
--
-- Calculate the nutrient content per household measure by:
--	N := (V*W)/100 == V/100 * W
--	V == nutrient value per 100g (abbrev.{Water,Vitamin_C,...})
--	W == g weight of portion (abbrev.GmWt[12])
--
-- [TODO] Shouldn't we include values for alcohol and caffeine?
CREATE TABLE abbrev (
	NDB_No		unsigned		PRIMARY KEY
			REFERENCES food_des(NDB_No),
			-- 5-digit Nutrient Databank number.
	Water		unreal,
			-- Water [g/100 g]
	Energ_Kcal	unsigned,
			-- Food energy [kcal/100 g]
	Protein		unreal,
			-- Protein [g/100 g]
	Lipid_Tot	unreal,
			-- Total lipid (fat) [g/100 g]
	Ash		unreal,
			-- Ash [g/100 g]
	Carbohydrt	unreal,
			-- Carbohydrate, by difference [g/100 g]
	Fiber_TD	unreal,
			-- Total dietary fiber [g/100 g]
	Sugar_Tot	unreal,
			-- Total sugars [g/100 g]
	Calcium		unsigned,
			-- Calcium [mg/100 g]
	Iron		unreal,
			-- Iron [mg/100 g]
	Magnesium	unsigned,
			-- Magnesium [mg/100 g]
	Phosphorus	unsigned,
			-- Phosphorus [mg/100 g]
	Potassium	unsigned,
			-- Potassium [mg/100 g]
	Sodium		unsigned,
			-- Sodium [mg/100 g]
	Zinc		unreal,
			-- Zinc [mg/100 g]
	Copper		unreal,
			-- Copper [mg/100 g]
	Manganese	unreal,
			-- Manganese [mg/100 g]
	Selenium	unreal,
			-- Selenium [g/100 g]
	Vit_C		unreal,
			-- Vitamin C [mg/100 g]
	Thiamin		unreal,
			-- Thiamin [mg/100 g]
	Riboflavin	unreal,
			-- Riboflavin [mg/100 g]
	Niacin		unreal,
			-- Niacin [mg/100 g]
	Panto_acid	unreal,
			-- Pantothenic acid  [mg/100 g]
	Vit_B6		unreal,
			-- Vitamin B6 [mg/100 g]
	Folate_Tot	unsigned,
			-- Folate, total [g/100 g]
	Folic_acid	unsigned,
			-- Folic acid [g/100 g]
	Food_Folate	unsigned,
			-- Food folate [g/100 g]
	Folate_DFE	unsigned,
			-- Folate [g dietary folate equivalents/100 g]
	Vit_B12		unreal,
			-- Vitamin B12 [g/100 g]
	Vit_A_IU	unsigned,
			-- Vitamin A [IU/100 g]
	Vit_A_RAE	unsigned,
			-- Vitamin A [g retinol activity equivalents/100g]
	Retinol		unsigned,
			-- Retinol [g/100 g]
	Vit_E		unreal,
			-- Vitamin E (alpha-tocopherol) [mg/100 g]
	Vit_K		unreal,
			-- Vitamin K (phylloquinone) [g/100 g]
	Alpha_Carot	unreal,
			-- Alpha-carotene [g/100 g]
	Beta_Carot	unreal,
			-- Beta-carotene [g/100 g]
	Beta_Crypt	unreal,
			-- Beta-cryptoxanthin [g/100 g]
	Lycopene	unreal,
			-- Lycopene [g/100 g]
	Lut_Zea		unreal,
			-- Lutein + zeazanthin [g/100 g]
	FA_SAT		unreal,
			-- Saturated fatty acid [g/100 g]
	FA_Mono		unreal,
			-- Monounsaturated fatty acids [g/100 g]
	FA_Poly		unreal,
			-- Polyunsaturated fatty acids [g/100 g]
	Cholesterl	unsigned,
			-- Cholesterol [mg/100 g]
	GmWt_1		unreal,
			-- First household weight for this item
			-- from the Weight file.
			-- Weights are given for edible material
			-- without refuse, that is, the weight
			-- of an apple without the core or stem,
			-- or a chicken leg without the bone,
			-- and so forth.
	GmWt_Desc1	VARCHAR,
			-- Information is provided on household
			-- measures for food items (for example,
			-- 1 cup, 1 tablespoon, 1 fruit, 1 leg).
			-- This is the description of household
			-- weight number 1.
	GmWt_2		unreal,
			-- Second household weight for this item
			-- from the Weight file.
	GmWt_Desc2	VARCHAR,
			-- Description of household weight number 2.
	Refuse_Pct	unsigned,
			-- Percentage of refuse.
			-- Duplicate of food_des.Refuse.
	Shrt_Desc	VARCHAR
			-- Abbreviated description of the food item.
			-- Duplicate of food_des.Shrt_Desc.
);

-- Just like TABLE abbrev, except that the data here is not
-- from USDA but from our lovely diatery experts.
-- [TODO] Shouldn't we CREATE UNIQUE INDEX?
CREATE TABLE abbrev_menugene () INHERITS (abbrev);
--- Tables }}}

------------------------- usda_am --------------------- }}}

------------------------- recept ---------------------- {{{

-- Csak a receptek szerkesztesere hasznaljuk. Az itt levo tablakat
-- Erzsi es hallgatoi tavolrol editaljak.
--
-- [Maintainer: VI]
CREATE SCHEMA recept;
SET search_path TO recept;

--- Functions {{{
-----------------

CREATE FUNCTION loginnev(VARCHAR, VARCHAR) RETURNS VARCHAR AS
$$
DECLARE v_pwd VARCHAR := NULL;
DECLARE v_felhnev VARCHAR := 'kismalac';
BEGIN
	SELECT INTO v_pwd nev FROM recept.jelszavak WHERE login = $1;
	IF v_pwd IS NULL
	THEN
		RETURN v_felhnev AS nev;
	END IF;
END
$$ LANGUAGE PLPGSQL;
--- Functions }}}

--- Tables {{{
--------------

CREATE TABLE felhasznalo (
	felhid		SERIAL			PRIMARY KEY,
	nev		VARCHAR(100)		NOT NULL
			CHECK (((nev)::text <> ''::text)),
	tipus		INTEGER			NOT NULL DEFAULT 0,
	"login"		VARCHAR(50)		NOT NULL,
	pwd		VARCHAR(50)		NOT NULL,
);

CREATE TABLE mertegys (
	mertegysid	INTEGER			PRIMARY KEY,
	mertegysnev	VARCHAR(50)
);

-- [Why do we need .hiv_receptid?]
-- [Why would a recipe "eloallit" an "alapanyag"?]
-- [We've got alapanyag:s like "Lecso", "Franciasalata" and "kg".]
CREATE TABLE alapanyag (
	sorszam		INTEGER			PRIMARY KEY,
	megnevezes	VARCHAR(100),
	usda_ndb_no	VARCHAR(6)
			REFERENCES usda.food_des("NDB_No"),
	hiv_receptid	INTEGER
			-- Az alapanyagot eloallito recept ilyen ID-vel
			-- van a recept tablaban, az osszetetel az
			-- usda.abbrev_menugene tablaban van.
);

-- [We've got different recipes with the same name.]
CREATE TABLE recept (
	receptid	INTEGER			PRIMARY KEY,
	etel_neve	VARCHAR(100),
	leiras		TEXT
);

-- Melyik recept milyen halmazokban van benne?
CREATE TABLE recept_index (
	recept_id	INTEGER			NOT NULL
			REFERENCES recept(receptid),
	set_id		INTEGER			NOT NULL
			REFERENCES "set"(set_id),
	PRIMARY KEY (recept_id, set_id)
);

CREATE TABLE recept_reszlet (
	receptid	INTEGER			NOT NULL
			REFERENCES recept(receptid),
	anyagid		INTEGER			NOT NULL
			REFERENCES alapanyag(sorszam),
	jellegkod	INTEGER			NOT NULL,
			-- 0: felnott, 1: iskolas, 2: ovodas
	mennyiseg	NUMERIC(6,3)		NOT NULL,
	mertegysid	INTEGER			NOT NULL
			REFERENCES mertegys(mertegysid),
	PRIMARY KEY (receptid, anyagid, jellegkod)
);

-- [Is it canonical?]
CREATE TABLE receptek_minden_masolat (
	receptid	INTEGER,
	etel_neve	VARCHAR(100),
	anyagid		INTEGER,
	megnevezes	VARCHAR(100),
	mennyiseg	NUMERIC,
	mertegysid	INTEGER,
	mertegysnev	VARCHAR(50)
);

-- A strukturak szintjei, pl. "nap".
CREATE TABLE "level" (
	level_id	INTEGER			PRIMARY_KEY,
	level_name	VARCHAR(50)		NOT NULL
);

-- Egy osztalyozasi szempont egy ontologia,
-- pl. "izhatas szerinti osztalyozas", az etelek szintjen.
CREATE TABLE ontology (
	ont_id		SERIAL			PRIMARY KEY,
	ont_name	VARCHAR(100)		NOT NULL,
	level_id	INTEGER			NOT NULL
			REFERENCES "level"(level_id)
);

-- Egy halmaz, atveve a Protege-ontologiabol.
CREATE TABLE "set" (
	set_id		SERIAL			PRIMARY KEY,
	ont_id		INTEGER			NOT NULL
			REFERENCES ontology(ont_id),
	set_name	VARCHAR(100)		NOT NULL,
	parent_id	INTEGER
			REFERENCES "set"(set_id),
	protege_id	VARCHAR(100)
);

-- Egy olyan struktura (fagraf) melyen belul ki lehet jelolni
-- egy mintazatot (csomopontok egy halmazat), pl. heti menu
-- napi otszori etkezessel.
CREATE TABLE structure (
	struct_id	SERIAL			PRIMARY KEY,
	struct_name	VARCHAR(100)		NOT NULL
);

-- Struktura egy adott csomopontja, pl. a keddi ebed.
CREATE TABLE structure_node (
	node_id		SERIAL			PRIMARY KEY,
	struct_id	INTEGER			NOT NULL
			REFERENCES structure(struct_id),
	parent_id	INTEGER
			REFERENCES structure_node(node_id),
	node_name	VARCHAR(100),
	level_id	INTEGER			NOT NULL
			REFERENCES "level"(level_id),
	order_no	INTEGER
);

-- Egy strukturan belul egy mintazat pl. az elso nap ebed csomopontja
-- es a keddi reggeli ivole csomopontja.
CREATE TABLE pattern (
	pattern_id	SERIAL			PRIMARY KEY,
	pattern_name	VARCHAR(100),
	struct_id	INTEGER			NOT NULL
			REFERENCES structure(struct_id)
);

-- Egy csomopont egy mintazatban (a mintazat alapjaul szolgalo struktura
-- egy csomopontjara mutat).
CREATE TABLE pattern_node (
	pattern_node_id	SERIAL			PRIMARY KEY,
	pattern_id	INTEGER			NOT NULL
			REFERENCES pattern(pattern_id),
	struct_node_id	INTEGER			NOT NULL
			REFERENCES structure_node(node_id)
);

-- Adott szabalymintazat-csomopontjaihoz milyen halmazok tartoznak?
-- Ezek egyuttes ES vagy VAGY kapcsolata (a szabaly tipusatol fuggoen)
-- adja a szabaly feltetel reszet.
CREATE TABLE condition (
	pattern_node_id	INTEGER			NOT NULL
			REFERENCES pattern_node(pattern_node_id),
	set_id		INTEGER			NOT NULL
			REFERENCES "set"(set_id),
	PRIMARY KEY (pattern_node_id, set_id)
);

-- Egy szabaly, pl. penteki reggeliben a vajas kenyer es a sor egyuttes
-- elofordulasa -20%.
CREATE TABLE "rule" (
	rule_id		SERIAL			PRIMARY KEY,
	rule_name	VARCHAR(100),
	pattern_id	INTEGER			NOT NULL
			REFERENCES pattern(pattern_id),
	rule_type	INTEGER			NOT NULL
			-- A szabalyhoz tartozo feltetelek ES (0)
			-- vagy VAGY (1) kapcsolatat kell venni.
);
--- Tables }}}

--- Views {{{
-------------

CREATE VIEW jelszavak AS
SELECT	felhasznalo.felhid, felhasznalo.nev, felhasznalo.tipus,
	felhasznalo. "login", felhasznalo.pwd
	FROM felhasznalo;

CREATE VIEW rec_reszlet_nevekkel AS
SELECT	a.megnevezes, rsz.mennyiseg, m.mertegysnev, rsz.receptid,
	m.mertegysid, rsz.anyagid
	FROM	recept_reszlet rsz
		JOIN alapanyag a ON (rsz.anyagid = a.sorszam)
		JOIN mertegys  m USING (mertegysid);

CREATE VIEW receptek_minden AS
SELECT	r.etel_neve, rsz.megnevezes, rsz.mennyiseg, rsz.mertegysnev,
	rsz.receptid, rsz.mertegysid, rsz.anyagid
	FROM recept r LEFT JOIN rec_reszlet_nevekkel rsz USING (receptid)
	ORDER BY r.etel_neve, rsz.megnevezes;

CREATE VIEW vi_szabalyok AS
SELECT	r.rule_name, p.pattern_name, pn.struct_node_id, sn.node_name,
	l2.level_name AS node_level, s.set_name, l1.level_name AS set_level
	FROM	"rule" r
		JOIN pattern p		USING (pattern_id)
		JOIN pattern_node pn	USING (pattern_id)
		JOIN structure_node sn	ON (pn.struct_node_id = sn.node_id)
		JOIN "level" l2		USING (level_id)
		JOIN condition prs	USING (pattern_node_id)
		JOIN "set" s		USING (set_id)
		JOIN "level" l1		ON (l1.level_id = s.ont_id);

-- Show set relationships.
CREATE VIEW viw_sets_sets AS
SELECT parent.set_name AS parent_name, child.set_name AS child_name
	FROM "set" AS child RIGHT OUTER JOIN "set" AS parent
		ON (child.parent_id = parent.set_id)
	ORDER BY parent_name, child_name;

-- List of all known sets along with their recipe members.
CREATE VIEW viw_sets_recipes AS
SELECT	"set".set_name AS halmaz_neve, recept.etel_neve
	FROM	recept_index
		JOIN "set" USING (set_id)
		JOIN recept ON (recept_index.recept_id = recept.receptid)
	ORDER BY set_name, etel_neve;

-- List of all recipes defined in TABLE recept along with their components.
-- Similar to VIEW rec_reszlek_nevekkel except that it's less verbose.
CREATE VIEW viw_recipes_components AS
SELECT	receptid, recept.etel_neve,
	alapanyag.megnevezes AS alkatresz_neve,
	recept_reszlet.mennyiseg, mertegys.mertegysnev AS mertekegyseg
	FROM	recept_reszlet
		JOIN recept USING (receptid)
		JOIN alapanyag ON (recept_reszlet.anyagid = alapanyag.sorszam)
		JOIN mertegys USING (mertegysid)
	ORDER BY etel_neve, receptid, alkatresz_neve;

-- List of "alapanyag"s associated with more than one measures
-- in TABLE recept_reszlet.  Probably these indicate bugs.
-- This is the ugliest piece of SQL query I've ever written
-- (not counting PLSQL functions).
CREATE VIEW viw_bogus_alapanyags AS
SELECT	DISTINCT ON (recept_reszlet.anyagid, recept_reszlet.mertegysid)
	alapanyag.megnevezes AS alapanyag, mertegys.mertegysnev AS mertekegyseg
	FROM	(SELECT anyagid FROM (SELECT DISTINCT anyagid, mertegysid
			FROM recept_reszlet) AS f
			GROUP BY anyagid
			HAVING COUNT(mertegysid) > 1) AS g
		JOIN alapanyag ON (g.anyagid = alapanyag.sorszam)
		JOIN recept_reszlet USING (anyagid)
		JOIN mertegys USING (mertegysid);

-- Displays the differences between the measures applied to the very same
-- alapanyag by us (recept_reszlet.measureid) and USDA (abbrev.GmWt1_Desc).
-- In an ideal world the last two columns would be identical.
CREATE VIEW viw_bogus_measures AS
SELECT DISTINCT
	alapanyag.megnevezes AS alapanyag,
	mertegys.mertegysnev AS our_measure,
	usda.abbrev."GmWt_Desc1" AS usda_measure
	FROM recept_reszlet
		JOIN mertegys USING (mertegysid)
		JOIN alapanyag ON (recept_reszlet.anyagid = alapanyag.sorszam)
		JOIN usda.abbrev ON (alapanyag.usda_ndb_no = usda.abbrev."NDB_No");
--- Views }}}

------------------------- recept ---------------------- }}}

------------------------- menugene -------------------- {{{

-- [Maintainer: Herczy]
CREATE SCHEMA menugene;
SET search_path TO menugene;

--- Tables ---
--------------

--- Entities {{{
CREATE TABLE sol (
	solid		SERIAL			PRIMARY KEY,
	snid		INTEGER,
			-- Kepernyonev ID, ezzel lehet majd kulonbozo
			-- nyelveken nevet rendelni a megoldashoz.
	name		VARCHAR(250)		UNIQUE,
			-- Ez a megoldas rendszerneve, arra az esetre,
			-- ha a bonyolultabb snid-s lehetoseggel meg
			-- nincs kedvunk vacakolni. Tehat ez amolyan
			-- default nev.
	measureid	INTEGER
			-- Mertekegyseg ID-je.
);

CREATE TABLE attr (
	attrid		SERIAL			PRIMARY KEY,
	snid		INTEGER			NOT NULL UNIQUE,
			-- Screen Name ID
	name		VARCHAR(250)		UNIQUE
);

CREATE TABLE solset (
	solsetid	SERIAL			PRIMARY KEY,
	snid		INTEGER,
	name		VARCHAR(250)		UNIQUE
);

CREATE TABLE constraintset (
	constraintsetid	NUMERIC			NOT NULL,
	constraintsetname VARCHAR(200)
);

CREATE TABLE constraintsol (
	constraintid	NUMERIC			NOT NULL,
	constraintname	VARCHAR(200),
	solid		NUMERIC			NOT NULL,
	minnum		NUMERIC			NOT NULL,
	optnum		NUMERIC			NOT NULL,
	maxnum		NUMERIC			NOT NULL
);

CREATE TABLE div (
	divid		NUMERIC			NOT NULL,
	divname		VARCHAR(250)		NOT NULL
);
--- }}}

--- Relations {{{
CREATE TABLE c_sol_attr (
	solid		INTEGER			NOT NULL,
	attrid		INTEGER			NOT NULL,
	minnum		NUMERIC			NOT NULL,
	defnum		NUMERIC(18,5)		NOT NULL,
	maxnum		NUMERIC(18,5)		NOT NULL,
	divid		NUMERIC
);

CREATE TABLE c_attr_sol (
	attrid		NUMERIC			NOT NULL,
	solid		NUMERIC			NOT NULL
);

CREATE TABLE solsubset (
	solsetid	INTEGER			NOT NULL
			REFERENCES solset(solsetid),
	solsubsetid	INTEGER			NOT NULL
			REFERENCES solset(solsetid),
	PRIMARY KEY (solsetid, solsubsetid)
);

CREATE TABLE c_solset_sol (
	solsetid	INTEGER,
			REFERENCES solset(solsetid),
	solid		INTEGER
			REFERENCES sol(solid)
);

CREATE TABLE c_cset_csol (
	constraintsetid	NUMERIC			NOT NULL,
	constraintid	NUMERIC			NOT NULL
);

CREATE TABLE c_div_sol (
	divid		NUMERIC			NOT NULL,
	solid		NUMERIC,
	"type"		NUMERIC,
			-- 1: tort, 2: szazalek, 3: constraint
			-- (ilyenkor a solid-et nem kell figyelembe venni)
	numerator	NUMERIC,		-- szamlalo
	denominator	NUMERIC,		-- nevezo
	percentage	NUMERIC(18,5),
	constraintid	NUMERIC,
	constraintsetid	NUMERIC,
	hardness	NUMERIC(18,5),
	fitnesstype	NUMERIC
);
--- }}}

--- ??? {{{
-- [These are the relations which seem to convey some of its creator's
-- intentions, but somehow don't fit in the big picture.]

-- [Nothing references it.]
CREATE TABLE soltype (
	soltypeid	NUMERIC			NOT NULL,
			-- [Make it an enum.]
	soltypename	VARCHAR(50),
	alterable	INTEGER
			-- [Move to attr?]
);

-- [What are attribute sets?]
CREATE TABLE c_aset_attr (
	asetid		NUMERIC			NOT NULL,
	attrid		NUMERIC			NOT NULL
);

-- [How does an attribute ever appear in a solution set?]
CREATE TABLE c_attr_sset (
	ssetid		NUMERIC			NOT NULL,
	attrid		NUMERIC			NOT NULL
);

-- [What does a constraint on a solution set specify?]
CREATE TABLE constraintsset (
	constraintid	NUMERIC			NOT NULL,
	constraintname	VARCHAR(200),
	ssetid		NUMERIC			NOT NULL,
	minnum		NUMERIC			NOT NULL,
	optnum		NUMERIC			NOT NULL,
	maxnum		NUMERIC			NOT NULL
);

-- [Why would you create a divider for a solution set?]
CREATE TABLE c_div_sset (
	divid		NUMERIC			NOT NULL,
	ssetid		NUMERIC			NOT NULL,
	percentage	NUMERIC(18,5),
	hardness	NUMERIC(18,5),
	fitnesstype	NUMERIC
);

-- [Nonsense. How do you distribute a constraint among constraints?]
CREATE TABLE c_div_constraintsol (
	divid		NUMERIC			NOT NULL,
	constraintid	NUMERIC			NOT NULL,
	percentage	NUMERIC(18,5),
	hardness	NUMERIC(18,5),
	fitnesstype	NUMERIC
);

-- [Utter nonsense.]
CREATE TABLE c_div_constraintset (
	divid		NUMERIC			NOT NULL,
	constraintsetid	NUMERIC			NOT NULL,
	percentage	NUMERIC(18,5),
	hardness	NUMERIC(18,5),
	fitnesstype	NUMERIC
);

-- [Rules are unfinished, I didn't bother with these tables.]
CREATE TABLE rulesset (
	rulesolid	NUMERIC			NOT NULL,
	solaid		NUMERIC			NOT NULL,
	solbid		NUMERIC			NOT NULL,
	percentage	NUMERIC(7,4)		NOT NULL,
	note		VARCHAR(100)
);

-- [Likewise.]
CREATE TABLE rulesol (
	rulesolid	NUMERIC			NOT NULL,
	solaid		NUMERIC			NOT NULL,
	solbid		NUMERIC			NOT NULL,
	percentage	NUMERIC(7,4)		NOT NULL,
	note		VARCHAR(100)
);

-- [Completely unnecessary.  We've got the same table in the main schema.]
CREATE TABLE c_sn_lang (
	snid		INTEGER			NOT NULL,
	langid		INTEGER			NOT NULL,
	name		VARCHAR(250),
	PRIMARY KEY (snid, langid)
);
--- }}}

--- Junk {{{
-- [These are the relations I could not make any sense of.]

-- [Never understood that one.  Does 'f' stand for 'fuck'?]
CREATE TABLE convsol (
	solid		NUMERIC			NOT NULL,
	ftable		VARCHAR(50)		NOT NULL,
	fcolumn		VARCHAR(50)		NOT NULL,
	fid		VARCHAR(50)		NOT NULL
);

-- [Some lefover duplicate of c_solset sol?]
CREATE TABLE c_sset_sol (
	"valid"		NUMERIC			NOT NULL,
	solid		NUMERIC			NOT NULL
);

-- [Seems to be a duplicate of table c_solset_sol.]
CREATE TABLE c_sset_ssubset (
	solsetid	NUMERIC			NOT NULL,
	subsolsetid	NUMERIC			NOT NULL
);

-- [Duplicate of c_cset_csol?]
CREATE TABLE c_cval_cset (
	constraintid	NUMERIC			NOT NULL,
	constraintsetid	NUMERIC			NOT NULL
);
--- }}}

------------------------- menugene -------------------- }}}

------------------------- menugene_am ----------------- {{{

-- This schema is intended to be the same as the "menugene" schma,
-- except for some syntactic sanitization.  I may rename and reorganize
-- DB objects, change types and such, but the structure will be kept.
--
-- [Maintainer: adam]
CREATE SCHEMA menugene_am;
SET search_path TO menugene_am, public;

--- Prerequisites {{{
---------------------

-- One day these things should land in SCHEMA main.

-- Database entities are identified unambiguously by objid.
-- Whenever you need to reference from a relation to an entity
-- use the objid type.  The type doesn't CHECK (VALUE >= 0)
-- because an objid should always either be generated by
-- SEQUENCE objids (which guarantees non-negativeness)
-- or be a reference to another objid, which is unsigned
-- by recursion.  Use of the objid type is not just semantic
-- sugar: sequences return BIGINT:s, which you need to be
-- aware of, because BIGINT is wider than INTEGER.
-- (It's worth noting that Postgres generates INTEGER type
-- columns when you use SEQUENCE -- looks like a bug.)
CREATE DOMAIN objid AS BIGINT;
CREATE SEQUENCE objids;

-- Creates the necessary unique indices on table $1:
-- $1_index_id for $1.id and $1_index_name_* for $1.name[*].
-- The indices are necessary to guarantee uniqueness
-- of those columns.
CREATE FUNCTION mk_entity_tbl(VARCHAR) RETURNS VOID AS
$$
DECLARE
	tbl	ALIAS FOR $1;
	stmt	VARCHAR;
BEGIN
	-- Create the objid index.  We use EXECUTE because
	-- neither SQL not PL/pgSQL allows variable identifiers
	-- at arbitrary places.  Look up my ferke project
	-- to gain impression how these things can go wild.
	stmt := 'CREATE UNIQUE INDEX '
		|| tbl || '_index_id '
		|| 'ON ' || tbl || '(id);';
	EXECUTE stmt;

	-- Create the developer name index.
	-- (Arrays are subscripted from one.)
	stmt := 'CREATE UNIQUE INDEX '
		|| tbl || '_index_name '
		|| 'ON ' || tbl || '(LOWER(name[1]));';
	EXECUTE stmt;

	-- Create the English name index.
	stmt := 'CREATE UNIQUE INDEX '
		|| tbl || '_index_name_en '
		|| 'ON ' || tbl || '(LOWER(name[2]));';
	EXECUTE stmt;

	-- Create the Hungarian name index.
	stmt := 'CREATE UNIQUE INDEX '
		|| tbl || '_index_name_hu '
		|| 'ON ' || tbl || '(LOWER(name[3]));';
	EXECUTE stmt;
END
$$ LANGUAGE PLPGSQL;
--- Prerequisites }}}

--- Tables {{{
--------------

-- Entities {{{
-- Entities are entities you know from database theory.
-- This table is intended to be the base of the specific
-- entity tables INHERITS:ing from this one.  The pro
-- of this appropach is that you needn't bother with
-- requisite fields like entity ID or name, and you can
-- attach arbitrary notes to entities.  Besides, whenever
-- you have a random objid it becomes easier to determine
-- what type of entity does it refer to.
-- 
-- To create a new entity type, make it INHERTS from this
-- one, then create the necessary indices by calling
-- mk_entity_tbl('new_table_name').
--
-- Nothing is ever INSERT:ed into this table directly:
-- all information is in the descandant entity tables.
-- That's why we omit the unique constraints from the
-- definition, because those imply the creation of
-- UNIQUE INDEX:es, which we wouldn't use anyway.
CREATE TABLE entities (
	id		objid			NOT NULL
						-- PRIMARY KEY
			DEFAULT NEXTVAL('objids'),
			-- The unambiguous ID of the entity.
	name		VARCHAR[],		-- UNIQUE
			-- Textual name (human-readble or not)
			-- of the entity.  Each element of
			-- the array is designated for a
			-- language.  ATM:
			-- -- name[1]: temporary name
			-- -- name[2]: English
			-- -- name[3]: Hungarian
			-- mk_entity_tbl() will see to the
			-- uniqueness of the names per language
			-- per entity type.
	notes		TEXT
			-- Arbitrary unstructured notes
			-- concerning the entity for the
			-- developer's pleasure.
);

-- Registry of measurement units used to express quantities.
-- (The name of this table is somewhat misleading.)
CREATE TABLE measures (
	in_kg		unreal			NOT NULL
			-- One unit of this is how much in kilogram.
) INHERITS (entities);
SELECT mk_entity_tbl('measures');

-- Registry of existing solutions.
--
-- Levels of genomes:
-- L1 weekly menu,
-- L2 daily menu,
-- L3 meal (breakfast, lunch, dinner, ...).
--
-- Levels of non-genomes:
-- L4 recipe (pizza),
-- L5 recipe component (white bread),
-- L6 nutrition component (or whatever we call it now) (vitamin A).
CREATE TABLE sol (
	is_genome	BOOLEAN			NOT NULL,
			-- Breed in a GA?
	measureid	objid
			REFERENCES measures(id)
			-- Makes no sense above L5, so it can be NULL.
) INHERITS (entities);
SELECT mk_entity_tbl('sol');

-- Registry of attributes like "menu for Monday", "dessert of a meal",
-- "vitamin A content of a recipe component" or "a component of a recipe".
CREATE TABLE attr () INHERITS (entities);
SELECT mk_entity_tbl('attr');

-- Registry of all existing solution sets, which group recipes
-- by arbitrary criteria.  Sets may have subsets (also included
-- in this table), constituting a tree-like hierarchy.  Relations
-- between sets are recorded in TABLE c_solset_solset.
CREATE TABLE solset () INHERITS (entities);
SELECT mk_entity_tbl('solset');

-- Registry of constraints.  Used to be TABLE constraintsol.
-- Constraints play role when you compute the fitness of a
-- solution genome.  It's not stored in the database whose
-- (referred to as `parent' below) fitness will use a given
-- constraint (or constraint set), because that is chosen
-- by the user in run time.
-- .{min,opt,max}imum have been made unreal because quantities
-- in USDA are unreal too.
CREATE TABLE cint (
	solid		objid			NOT NULL
			REFERENCES sol(id),
			-- What does this cint constraint?
			-- Makes no sense to REFERENCE to
			-- a sol.is_genome (L1..3), alas
			-- we can't CHECK for it.
	minimum		unreal			NOT NULL,
			-- The smallest quantity of .solid
			-- in the parent we'd like to see.
			-- Used to be .minnum.
	optimum		unreal			NOT NULL,
			-- The user will want that much
			-- of .solid in the parent.
			-- Used to be .optnum.
	maximum		unreal			NOT NULL
			-- The smallest quantity of .solid
			-- in the parent we tolerate.
			-- Used to be .maxnum.
) INHERITS (entities);
SELECT mk_entity_tbl('cint');

-- Registry of existing constraint sets.
-- Used to be TABLE constraintset.
CREATE TABLE cset () INHERITS (entities);
SELECT mk_entity_tbl('cset');

-- Registry of constraint-dividing rules.
CREATE TABLE div () INHERITS (entities);
SELECT mk_entity_tbl('div');
--- }}}

-- Relations {{{
-- Tells what attributes a solution has.
CREATE TABLE c_sol_attr (
	solid		objid			NOT NULL
			REFERENCES sol(id),
	attrid		objid			NOT NULL
			REFERENCES attr(id),
	quantity	unreal			NOT NULL,
			-- E.g. how much white bread does a pizza contain?
			-- Used to be .defnum.
	min		unreal,
			-- Unreasoned and unused by now.
			-- Used to be .minnum.
	max		unreal,
			-- Unreasoned and unused by now.
			-- Used to be .maxnum.
	divid		objid
			REFERENCES div(id),
			-- Tells how to distribute the contraints applied
			-- to this solution among its different attributes.
	UNIQUE (solid, attrid)
);

-- For the quick enumeration of the attributes of a particular solution.
CREATE INDEX sol_attr_index ON c_sol_attr (solid);

-- Tells what values an attribute can present.
-- In case of ATOM attributes there will be only one,
-- pointing to a recipe.  For POOL:s there can be many,
-- pointing to recipes as well.  Finally a GA attribute
-- has only one solid, which .is_genome.
-- [TODO] soltype was not part of the menugene schmea,
-- don't know what's happened to that.
CREATE TABLE c_attr_sol (
	attrid		objid			NOT NULL
			REFERENCES attr(id),
	solid		objid			NOT NULL
			REFERENCES sol(id),
	UNIQUE (attrid, solid)
);

-- For the quick enumeration of the solutions of a particular attribute.
CREATE INDEX attr_sol_index ON c_attr_sol (attrid);

-- Keeps the parent-child relationships between solsets,
-- i.e. solset .subsetid is a child of solset .setid.
-- Used to be TABLE solsubset.
--
-- Too bad PostgreSQL doesn't support recursive queries
-- (MS SQL does, for years) so we must express CHECK
-- against circular dependencies in human terms:
-- if solset A IS a child of solset B
-- 	then solset B IS NOT a child of solset A.
CREATE TABLE c_solset_solset (
	setid		objid			NOT NULL
			REFERENCES solset(id),
			-- Parent solset.
	subsetid	objid			NOT NULL
			REFERENCES solset(id),
			-- Child solset.
	UNIQUE (setid, subsetid)
);

-- For the quick enumeration of the children of a solset.
CREATE INDEX solset_subset_index ON c_solset_solset (setid);

-- Tells what solutions (recipes mostly) constitute a solset.
CREATE TABLE c_solset_sol (
	setid		objid			NOT NULL
			REFERENCES solset(id),
	solid		objid			NOT NULL
			REFERENCES sol(id),
	UNIQUE (setid, solid)
);

-- For the quick enumeration of the members a solset.
CREATE INDEX solset_sol_index ON c_solset_sol (setid);

-- Suppose you've got a genome solution, some constraints applied to it.
-- Each of its relations with its attributes are assigned a dividing rule
-- (c_sol_attr.divid) that tells how to distribute its constraints among
-- the solutions of the attributes.  This rule is described in this table.
--
-- [TODO] What is .fitnesstype doing here?
-- [TODO] The purpose of .divtype == 0 is not clear.
-- [TODO] The meaning of .divtype == 2 is not clear at all.
CREATE TABLE c_div_sol (
	divid		objid			NOT NULL
			REFERENCES div(id),
	divtype		INTEGER			NOT NULL
			CHECK (divtype BETWEEN 0 AND 2),
			-- Tells how to derive the constraints of the
			-- child solutions.
			-- -- 0: use .solid, .numerator, .denominator
			--       [TODO just guessing]
			-- -- 1: use .solid, .multiply, .tolerance
			-- -- 2: use .cint or .cset
			--       [TODO just guessing]
	fitnesstype	VARCHAR
			CHECK (fitnesstype IN ('tdk', 'pb')),
			-- [TODO] Should be in TABLE sol instead.

	-- For .divtype == 0 or 1
	solid		objid
			REFERENCES sol(id),

	-- For .divtype == 0
	numerator	unsigned,		-- Unused by daemon.
	denominator	unsigned,		-- Unused by daemon.

	-- For .divtype == 1
	multiply	unreal,
			-- Multiply the constraint applied to .solid
			-- by this.
			-- Used to be .percentage.  Renamed because
			-- it never was interpreted as a percentage.
	tolerance	unreal,
			-- Multiply the distance of .{min,max}imum
			-- from opimum by this.  (Adjust the tolerated
			-- range of the constraint applied to .solid).
			-- Used to be .hardness.  Renamed because
			-- daemon called it `tolerance.

	-- For .divtype == 2
	cint		objid			-- Unused by daemon.
			REFERENCES cint(id),
	cset		objid			-- Unused by daemon.
			REFERENCES cset(id),

	CHECK (CASE divtype -- [TODO] Find a simplier expression.
		WHEN 0 THEN
			   (solid	IS NOT NULL
			AND multiply	IS NOT NULL)
		WHEN 1 THEN -- [TODO] Just guessing.
			   (solid	IS NOT NULL
			AND numerator	IS NOT NULL
			AND denominator	IS NOT NULL)
		WHEN 2 THEN -- [TODO] Just guessing.
			  (cint		IS NOT NULL
			OR cset		IS NOT NULL)
		ELSE FALSE
		END),
	UNIQUE (divid, solid)
);
-- Relations }}}
--- Tables }}}

------------------------- menugene_am ----------------- }}}

------------------------- szabaly --------------------- {{{

-- [Maintainer: VI]
CREATE SCHEMA szabaly;
SET search_path TO szabaly;

--- Tables ---
--------------

CREATE TABLE ontology (
	ont_id		INTEGER			PRIMARY KEY,
	ont_name	VARCHAR(100)		NOT NULL,
	level_id	INTEGER			NOT NULL
);

CREATE TABLE "set" (
	set_id		INTEGER			PRIMARY KEY,
	ont_id		INTEGER			NOT NULL,
	set_name	VARCHAR(100)		NOT NULL,
	parent_id	INTEGER,
	protege_id	VARCHAR(100)
);

------------------------- szabaly --------------------- }}}

-- vim: set foldmethod=marker:
-- End of postgre.sql

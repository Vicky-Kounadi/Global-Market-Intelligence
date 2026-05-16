USE world;

-- VIEW DATA
SELECT * FROM country LIMIT 10;
SELECT * FROM city LIMIT 10;
SELECT * FROM countrylanguage LIMIT 10;

-- DATA COUNT
SELECT Count(*) AS country_count FROM country;
SELECT Count(*) AS city_count FROM city;
SELECT Count(*) AS lang_count FROM countrylanguage;

-- DATA VALIDATION
-- Valid countries
SELECT *
FROM country
WHERE Name IS NULL OR Code IS NULL
OR Population IS NULL OR Population<0
OR SurfaceArea IS NULL OR SurfaceArea<=0
OR LifeExpectancy IS NULL
OR GNP IS NULL;

SELECT count(*)
FROM country
WHERE Name IS NULL OR Code IS NULL
OR Population IS NULL OR Population<=0
OR SurfaceArea IS NULL OR SurfaceArea<=0
OR LifeExpectancy IS NULL
OR GNP IS NULL OR GNP<=0;
-- RULES: Population > 0, GNP > 0, LifeExpectancy IS NOT NULL (non-states, small terratories eg.Antarctica, Vatican)

SELECT *
FROM city
WHERE Name IS NULL OR ID IS NULL
OR Population IS NULL OR Population<0;
-- RULES: None

SELECT *
FROM countrylanguage
WHERE CountryCode IS NULL OR Language IS NULL
OR (Percentage <0 AND Percentage >=100);
-- RULES: None

-- DATA CONSISTENCY
SELECT * FROM country WHERE Capital IS NULL;
-- Small terratories from validation

SELECT * FROM city WHERE CountryCode IS NULL;
-- None

-- All have matches - no orphans
SELECT count(*)
FROM countrylanguage cl
LEFT JOIN country ON country.Code = cl.CountryCode;
-- All languages have joined with countries (same count of distinct langs), so all languages have a country

SELECT count(distinct country.Code)
FROM country
LEFT JOIN countrylanguage cl ON country.Code = cl.CountryCode;
-- All countries joined min once (same count of distinct countries) so they have a valid lang code

SELECT count(*)
FROM country
LEFT JOIN city ON country.capital = city.id;
-- All countries joined (same count of distinct countries) so they have a valid city code

SELECT country.Code, country.Name, sum(cl.percentage) AS perc
FROM country
LEFT JOIN countrylanguage cl ON country.Code = cl.CountryCode
GROUP BY country.Code
ORDER BY perc;
-- Percentages are fine, except non-states etc. Small >100 in 2 recs (same people, 2+ langs, perc overlap)

-- VIEWS CREATION
-- Rules for valid markets
CREATE VIEW market_base AS
SELECT *
FROM country
WHERE Population > 0 AND GNP > 0 AND LifeExpectancy IS NOT NULL;

SELECT COUNT(*) FROM market_base;
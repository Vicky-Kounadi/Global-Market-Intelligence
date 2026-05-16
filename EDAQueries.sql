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
USE world;

-- VIEW DATA
SELECT * FROM country LIMIT 10;
SELECT * FROM city LIMIT 10;
SELECT * FROM countrylanguage LIMIT 10;

-- DATA COUNT
SELECT Count(*) AS country_count FROM country;
SELECT Count(*) AS city_count FROM city;
SELECT Count(*) AS lang_count FROM countrylanguage;
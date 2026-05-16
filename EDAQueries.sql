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

CREATE VIEW country_city_view AS
SELECT 
    c.Code AS CountryCode,
    c.Name AS Country,
    c.Population AS CountryPopulation,
    ci.ID AS CityID,
    ci.Name AS City,
    ci.Population AS CityPopulation
FROM country c
JOIN city ci ON c.Code = ci.CountryCode;

CREATE VIEW country_language_view AS
SELECT 
    c.Code AS CountryCode,
    c.Name AS Country,
    cl.Language,
    cl.IsOfficial,
    cl.Percentage
FROM country c
JOIN countrylanguage cl ON c.Code = cl.CountryCode;


-- EDA

-- MARKET ASSESMENT
WITH
stats AS(
	SELECT MIN(Population) AS min_population, -- 8000
		MAX(Population) AS max_population, -- 1277558000
        MIN(GNP *1000000/Population) AS min_gnp,
        MAX(GNP *1000000/Population) AS max_gnp,
        MIN(LifeExpectancy) AS min_life,
        MAX(LifeExpectancy) AS max_life
	FROM market_base
),
final_stats AS(
	SELECT Code, Name, 
		Population, ROUND(GNP *1000000/Population, 2) AS GNPperCapita, LifeExpectancy,
        -- Have to log/normalize the population cause data skew is too large and multiply GNP because population is raw
		ROUND(LOG(Population) - LOG(min_population) / (LOG(max_population) -LOG(min_population)), 2) AS population_norm,
		ROUND((GNP *1000000/Population - min_gnp) / (max_gnp - min_gnp), 2) AS gnp_norm,
		ROUND((LifeExpectancy - min_life) / (max_life - min_life), 2) AS life_expect_norm
	FROM market_base, stats
)
SELECT Code, Name,
	Population, GNPperCapita, LifeExpectancy,
    population_norm, gnp_norm, life_expect_norm,
    ROUND((0.4* population_norm + 0.35* gnp_norm + 0.25* life_expect_norm), 2) AS market_potential_score
FROM final_stats
ORDER BY market_potential_score DESC
LIMIT 20;


-- MARKET SEGMENTATION
WITH
lang_count AS (
    SELECT CountryCode, COUNT(DISTINCT Language) AS lang_diversity
    FROM country_language_view
    GROUP BY CountryCode
),
lang_stats AS (
    SELECT MIN(lang_diversity) AS min_lang, MAX(lang_diversity) AS max_lang
    FROM lang_count
),
stats AS(
	SELECT MIN(Population) AS min_population, -- 8000
		MAX(Population) AS max_population, -- 1277558000
        MIN(GNP * 1000000/Population) AS min_gnpcap,
        MAX(GNP * 1000000/Population) AS max_gnpcap,
        MIN(LifeExpectancy) AS min_life,
        MAX(LifeExpectancy) AS max_life
	FROM market_base
),
final_stats AS (
    SELECT mb.Code, mb.Name,
        mb.Population, ROUND(mb.GNP * 1000000 / mb.Population, 2) AS GNPperCapita, mb.LifeExpectancy,
        lc.lang_diversity,
        (LOG(mb.Population) - LOG(s.min_population)) / (LOG(s.max_population) - LOG(s.min_population)) AS population_norm,
        (mb.GNP * 1000000 / mb.Population - s.min_gnpcap) / (s.max_gnpcap - s.min_gnpcap) AS gnp_norm,
        (mb.LifeExpectancy - s.min_life) / (s.max_life - s.min_life) AS life_norm,
        (lc.lang_diversity - ls.min_lang) / (ls.max_lang - ls.min_lang) AS lang_norm
    FROM market_base mb
    JOIN stats s
    JOIN lang_count lc ON mb.Code = lc.CountryCode
    JOIN lang_stats ls
),
avg_vals AS (
    SELECT AVG(population_norm) AS avg_population,
        AVG(gnp_norm) AS avg_gnp,
        AVG(lang_norm) AS avg_lang
    FROM final_stats
)
SELECT fs.Code, fs.Name,
    fs.Population, fs.GNPperCapita,
    ROUND(fs.population_norm, 2) AS population_norm, ROUND(fs.gnp_norm, 2) AS gnp_norm,
    fs.lang_diversity, ROUND(fs.lang_norm, 2) AS lang_norm,
    CASE
        WHEN (fs.population_norm > avg_population + 0.1 AND fs.gnp_norm > avg_gnp + 0.1) THEN 'High Value'
        WHEN (fs.population_norm > avg_population AND fs.gnp_norm <= avg_gnp) THEN 'Emerging'
        WHEN (fs.population_norm <= avg_population AND fs.gnp_norm > avg_gnp + 0.1) THEN 'Niche Premium'
        WHEN (fs.gnp_norm < avg_gnp AND fs.lang_norm > avg_lang + 0.1) THEN 'Challenging'
        ELSE 'Mid-tier'
    END AS market_type
FROM final_stats fs
CROSS JOIN avg_vals
ORDER BY market_type DESC;
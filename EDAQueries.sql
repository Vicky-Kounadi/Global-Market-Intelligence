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
-- , final as (
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
/*)
SELECT market_type, COUNT(*) AS count, ROUND((COUNT(*) / (SELECT COUNT(*) as total_coun from market_base))*100, 2) AS percentage
FROM final
GROUP BY market_type;*/

-- POPULATION VS LIFE EXPECTANCY
WITH
avg_stats AS(
	SELECT AVG(LOG(Population)) AS avg_population, 
        AVG(LifeExpectancy) AS avg_life,
        AVG(LOG(Population) * LifeExpectancy) AS avg_ginomeno,
        AVG(POW(LOG(Population), 2)) AS avg_population2, 
        AVG(POW(LifeExpectancy, 2)) AS avg_life2
	FROM market_base
)
SELECT 
    ROUND((avg_ginomeno - avg_population * avg_life) / 
		SQRT((avg_population2 - POW(avg_population, 2)) * (avg_life2 - POW(avg_life, 2))) , 3)
		AS pearson_correlation
FROM avg_stats;
-- pearson_correlation= -0.205

SELECT Code, Name, Population, LifeExpectancy
FROM market_base
ORDER BY Population
LIMIT 10;

-- ECONOMIC INEQUALITY
WITH
ranked AS (
    SELECT Code, Name, GNP * 1000000/Population AS GNPperCapita,
        ROW_NUMBER() OVER (ORDER BY (GNP * 1000000/Population)) AS row_num,
        COUNT(*) OVER () AS n
    FROM market_base
),
quartiles AS (
    SELECT 
    -- PERCENT_RANK() not working :(
        MAX(CASE WHEN row_num = FLOOR(0.25 * n) THEN GNPperCapita END) AS q1,
        MAX(CASE WHEN row_num = FLOOR(0.75 * n) THEN GNPperCapita END) AS q3
    FROM ranked
),
stats AS (
    SELECT q1, q3, (q3 - q1) AS iqr
    FROM quartiles
)
-- , final as (
SELECT r.Code, r.Name, r.GNPperCapita, r.row_num,
	CASE 
    -- top 10%
		WHEN row_num > 0.9 * n THEN 'High Income'
        WHEN row_num <= 0.1 * n THEN 'Low Income'
    ELSE 'Mid Income'
    END AS income_tier,
    CASE
        WHEN r.GNPperCapita > s.q3 + 1.5 * s.iqr THEN 'High Outlier'
        WHEN r.GNPperCapita < s.q1 - 1.5 * s.iqr THEN 'Low Outlier'
        ELSE 'Normal'
    END AS outlier_flag
FROM ranked r
CROSS JOIN stats s
ORDER BY r.GNPperCapita DESC;
/*)
SELECT income_tier, COUNT(*) AS count, ROUND((COUNT(*) / (SELECT COUNT(*) as total_coun from market_base))*100, 2) AS percentage
FROM final
GROUP BY income_tier;
SELECT outlier_flag, COUNT(*) AS count, ROUND((COUNT(*) / (SELECT COUNT(*) as total_coun from market_base))*100, 2) AS percentage
FROM final
GROUP BY outlier_flag;*/

-- CONTINETN ANALYSIS
WITH
lang_count AS (
    SELECT CountryCode, COUNT(DISTINCT Language) AS lang_diversity
    FROM country_language_view
    GROUP BY CountryCode
)
SELECT continent, COUNT(DISTINCT Code) AS country_count, 
	SUM(population) as total_population, 
	ROUND(AVG(GNP * 1000000/Population), 2) as avg_gnp_per_capita, 
    ROUND(AVG(lang_diversity),0) AS avg_language_diversity -- rounding to solid num, no decimals
FROM market_base
JOIN lang_count ON market_base.Code= lang_count.CountryCode
GROUP BY continent;

-- REGION ANALYSIS
WITH
lang_count AS (
    SELECT CountryCode, COUNT(DISTINCT Language) AS lang_diversity
    FROM country_language_view
    GROUP BY CountryCode
)
SELECT continent, region, COUNT(DISTINCT Code) AS country_count, 
	SUM(population) as total_population, 
	ROUND(AVG(GNP * 1000000/Population), 2) as avg_gnp_per_capita, 
    ROUND(AVG(lang_diversity),0) AS avg_language_diversity -- rounding to solid num, no decimals
FROM market_base
JOIN lang_count ON market_base.Code= lang_count.CountryCode
GROUP BY continent, region;

-- REGION RANKING
-- from market segmentation
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
        MAX(GNP * 1000000/Population) AS max_gnpcap
	FROM market_base
),
final_stats AS (
    SELECT mb.Code, mb.Name,
        mb.Population, ROUND(mb.GNP * 1000000 / mb.Population, 2) AS GNPperCapita, mb.LifeExpectancy,
        lc.lang_diversity,
        (LOG(mb.Population) - LOG(s.min_population)) / (LOG(s.max_population) - LOG(s.min_population)) AS population_norm,
        (mb.GNP * 1000000 / mb.Population - s.min_gnpcap) / (s.max_gnpcap - s.min_gnpcap) AS gnp_norm,
        (lc.lang_diversity - ls.min_lang) / (ls.max_lang - ls.min_lang) AS lang_norm
    FROM market_base mb
    JOIN stats s
    JOIN lang_count lc ON mb.Code = lc.CountryCode
    JOIN lang_stats ls
),
region_stats as (
	SELECT mb.continent, mb.region, COUNT(DISTINCT mb.Code) AS country_count,
		SUM(mb.population) as total_population,
		ROUND(AVG(fs.population_norm), 3) AS avg_population_norm,
		ROUND(AVG(fs.gnp_norm), 3) AS avg_gnp_norm, 
		ROUND(AVG(fs.lang_norm), 3) AS avg_lang_diversity_norm
	FROM market_base mb
	JOIN final_stats fs ON fs.Code = mb.Code
	GROUP BY continent, region
),
score_calc as(
SELECT *,
	-- lang diversity bad -> complex market
	ROUND(0.5* avg_population_norm + 0.4* avg_gnp_norm - 0.1* avg_lang_diversity_norm, 3) AS opportunity_score
FROM region_stats
)
SELECT *,
	DENSE_RANK() OVER (ORDER BY opportunity_score DESC) AS ranking
    /* Top opporuntities per continent
    DENSE_RANK() OVER (PARTITION BY continent ORDER BY opportunity_score DESC) AS ranking */
FROM score_calc;

-- URBAN CONCETRATION
WITH 
rank_cities AS (
/*-- Need market base, not all countries
     SELECT cityid, city, citypopulation,
		countrycode, country, countrypopulation, continent,
        RANK() OVER (PARTITION BY countrycode ORDER BY citypopulation DESC) AS ranking, -- 2 cities can have same pop, both ranking 1, next 3
		ROUND((citypopulation / countrypopulation)*100, 2) AS urdan_concentration_perc
    FROM country_city_view*/
    
	SELECT ci.ID AS city_id, ci.Name AS city, ci.Population AS city_population,
		mb.Code AS country_code, mb.Name AS country, mb.Population AS country_population, mb.Continent,
		RANK() OVER (PARTITION BY mb.Code ORDER BY ci.Population DESC) AS ranking, -- 2 cities can have same pop, both ranking 1, next 3
		ROUND((ci.Population / mb.Population)*100, 2) AS urdan_concentration_perc
    FROM city ci
    JOIN market_base mb ON mb.Code = ci.CountryCode
),
top_cities AS (
	SELECT Continent, country_code, country, country_population, city, city_population, urdan_concentration_perc
	FROM rank_cities
	WHERE ranking = 1
	ORDER BY Continent, urdan_concentration_perc DESC
)
SELECT Continent, ROUND(AVG(urdan_concentration_perc), 2) AS avg_concentration_perc, 
	MAX(urdan_concentration_perc) AS max_concentration_perc,
	SUM(CASE WHEN urdan_concentration_perc > 35 THEN 1 ELSE 0 END) AS highly_centr_countries
FROM top_cities
GROUP BY Continent
ORDER BY avg_concentration_perc DESC;

-- POPULATION DENSITY
WITH
pop_dense AS (
SELECT Code, Name, Region, Population, SurfaceArea, ROUND(Population/SurfaceArea, 2) AS population_density,
        CASE
        -- high density is considered >1000 in global urban data, but for markets it skews the data
            WHEN (Population / SurfaceArea) >= 1000 THEN 'Extremely Dense'
            WHEN (Population / SurfaceArea) >= 300 THEN 'Highly Accessible'
            WHEN (Population / SurfaceArea) >= 100 THEN 'Moderately Accessible'
            ELSE 'Logistically Challenging'
        END AS accessibility_type
FROM market_base
ORDER BY population_density DESC
)
SELECT Region, ROUND(AVG(population_density), 0) AS avg_population_density, 
	MAX(population_density) AS max_population_density, MIN(population_density) AS min_population_density,
    SUM(CASE WHEN population_density >= 300 THEN 1 ELSE 0 END) AS high_accessibility_count,
    SUM(CASE WHEN population_density < 100 THEN 1 ELSE 0 END) AS low_accessibility_count
FROM pop_dense
WHERE Population > 500000
GROUP BY Region
ORDER BY avg_population_density DESC;

-- DIFFERENT LANGUAGE COMPLEXITY
WITH
lang_count AS (
    SELECT CountryCode, COUNT(DISTINCT Language) AS language_count,
        SUM(CASE WHEN isOfficial = 'T' THEN 1 ELSE 0 END) AS official_language_count,
        SUM(CASE WHEN isOfficial = 'F' THEN 1 ELSE 0 END) AS non_official_language_count
    FROM country_language_view
    GROUP BY CountryCode
),
lang_data AS(
SELECT CountryCode, Name, Region,
	language_count, official_language_count, 
	ROUND((non_official_language_count / NULLIF(language_count,0)), 2) AS localization_risk,
    CASE
		WHEN language_count >=8 THEN 'Extreme Diversity'
        WHEN language_count >=4 THEN 'High Diversity'
        ELSE 'Low Diversity'
	END AS language_diversity_level,
	CASE
		WHEN official_language_count >= 3 THEN 'Multi-official'
		WHEN official_language_count = 1 THEN 'Single Official'
		ELSE '-'
	END AS official_language_structure
FROM lang_count lc
RIGHT JOIN market_base mb ON mb.Code = lc.CountryCode
ORDER BY language_count
)
SELECT language_diversity_level, COUNT(*) AS instances
FROM lang_data
GROUP BY language_diversity_level;

-- LANGUAGE REACH
WITH
country_count AS (
    SELECT Language, Percentage,
		CountryCode, Name AS CountryName, Population,
		ROUND((Population* Percentage),0) AS total_country_speakers
    FROM country_language_view clv
    LEFT JOIN country c ON c.Code = clv.CountryCode
),
country_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY Language ORDER BY Percentage DESC) AS ranking
    FROM country_count
), 
lang_data AS(
	SELECT Language, COUNT(DISTINCT CountryCode) AS country_count,
		SUM(total_country_speakers) AS total_global_speakers,
		AVG(Percentage) AS avg_perc_per_country,
		MAX(Percentage) AS max_perc_country
	FROM country_ranked 
	GROUP BY Language
)
SELECT ld.Language, country_count, total_global_speakers, avg_perc_per_country, max_perc_country, CountryName,
	CASE
		WHEN country_count >=20 AND avg_perc_per_country >=10 THEN 'Global Reach'
		WHEN country_count >=10 AND avg_perc_per_country >=15 THEN 'Regional Strenght'
		ELSE 'Localized'
	END AS reach_category
FROM lang_data ld
LEFT JOIN country_ranked cr ON ld.Language = cr.Language AND cr.ranking = 1
ORDER BY country_count DESC
LIMIT 100;

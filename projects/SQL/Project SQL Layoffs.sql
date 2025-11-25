ALTER TABLE layoffsp
RENAME COLUMN `ï»¿Company`       TO company,
RENAME COLUMN `Location HQ`     TO location,
RENAME COLUMN `Industry`        TO industry,
RENAME COLUMN `# Laid Off`      TO total_laid_off,
RENAME COLUMN `%`               TO percentage_laid_off,
RENAME COLUMN `Date`            TO date,
RENAME COLUMN `Stage`           TO stage,
RENAME COLUMN `Country`         TO country,
RENAME COLUMN `$ Raised (mm)`   TO funds_raised_millions,
RENAME COLUMN `Date Added`      TO date_added;

select * 
from layoffsp;

alter table layoffsp
drop column date_added;

select * 
from layoffsp;

Create table layoffsp_staging
like layoffsp;

insert into layoffsp_staging
select *
from layoffsp;

alter table layoffsp_staging
add row_num int;

create table layoffsp_staging2
(company text
, location text
, industry text
, total_laid_off text
, percentage_laid_off text
, `date` text
, stage text
, country text
, funds_raised_millions text, 
row_num int);

INSERT INTO layoffsp_staging2
(`company`,
 `location`,
 `industry`,
 `total_laid_off`,
 `percentage_laid_off`,
 `date`,
 `stage`,
 `country`,
 `funds_raised_millions`,
 `row_num`)
 Select `company`,
 `location`,
 `industry`,
 `total_laid_off`,
 `percentage_laid_off`,
 `date`,
 `stage`,
 `country`,
 `funds_raised_millions`,
 ROW_NUMBER() OVER(partition by 
 `company`,
 `location`,
 `industry`,
 `total_laid_off`,
 `percentage_laid_off`,
 `date`,
 `stage`,
 `country`,
 `funds_raised_millions`,
 `row_num`) AS row_num
 from layoffsp_staging;
 
 # selecting rows which have duplicates using row num values
select *
 from layoffsp_staging2
 where row_num > 1;
 
delete
 from layoffsp_staging2
 where row_num > 1;
 
select *
 from layoffsp_staging2
 where row_num > 1;
 
 # duplicates removed
 
 ## fixing the date format for all cases
update layoffsp_staging2
SET `date` = str_to_date(`date`, '%m/%d/%Y');
select `date`
from layoffsp_staging2;

# deleted two rows of data with missing industry information cleaning missing data
delete from layoffsp_staging2
where industry IS NULL OR industry = '';

-- Populate missing industry data using company context
UPDATE layoffsp_staging2 t1
JOIN layoffs_staging2 t2 ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL AND t2.industry IS NOT NULL;

# removing those company data where neither layoff number nor layoff percentage is available
# such data is redundant for data exploration purposes as most KPIs involve numerical functions being applied on layoff data

delete
from layoffsp_staging2
where total_laid_off =''
AND percentage_laid_off = '' ;

# done with irrelevant data nulls and blanks removed
# adding country to companies who location is given 
# and updating locations where it is missing

Update layoffsp_staging2
Set country = 'Canada'
where company = 'Ludia';

Update layoffsp_staging2
Set country = 'Germany'
where company = 'Fit Analytics';

Update layoffsp_staging2
Set location = 'San Francisco'
where company = 'Product Hunt';



-- 1️⃣ Replace empty strings with NULL for all three columns
UPDATE layoffsp_staging2
SET total_laid_off = NULLIF(total_laid_off, ''),
    funds_raised_millions = NULLIF(funds_raised_millions, ''),
    percentage_laid_off = NULLIF(percentage_laid_off, '');

-- 2️⃣ Change to proper numeric types
ALTER TABLE layoffsp_staging2
MODIFY total_laid_off INT,
MODIFY percentage_laid_off DECIMAL(5,2);

## Starting with DATA EXPLORATORY PROJECT

#1) Major Outliers Events of Layoffs and Counts of Layoffs by Company, Country
# date
SELECT company, country, total_laid_off,percentage_laid_off, `date`
FROM layoffsp_staging2
order by total_laid_off DESC
LIMIT 10;

#Exploring Temporal Characteristics of Data
# Total Layoffs In a Year
select  year(`date`) as years, SUM(total_laid_off) as total_layoffs, count(*) AS events
from layoffsp_staging2
group by years
order by years;

WITH months_CTE AS
(
Select date_format(`date`, '%Y-%m') AS months, 
sum(total_laid_off) AS monthly_total, count(*) AS events_l
From layoffsp_staging2
group by months
)
Select months, monthly_total,
sum(monthly_total) OVER(order by months) AS Rolling_Total, events_l
FROM months_CTE;

#LAYOFFS by Top 10 companies across the years
select company, count(*) as Layoff_Events,
SUM(total_laid_off) As Total_Layoffs
from layoffsp_staging2
group by company
order by Total_Layoffs DESC
Limit 10;

# Top 10 Countries by layoff events
select country, count(*) as Layoff_Events,
SUM(total_laid_off) As Total_Layoffs
from layoffsp_staging2
group by country
order by Total_Layoffs DESC
Limit 10;

select industry, count(*) as Layoff_Events,
SUM(total_laid_off) As Total_Layoffs
from layoffsp_staging2
group by industry
order by Total_Layoffs DESC;

# Company Stage Wise Layoffs
select stage, count(*) as Layoff_Events,
SUM(total_laid_off) As Total_Layoffs
from layoffsp_staging2
where total_laid_off IS NOT NULL AND stage != ''
group by stage
order by Total_Layoffs DESC;

#Complete shutdown
select company,location,`date`, total_laid_off,percentage_laid_off
from layoffsp_staging2
where percentage_laid_off = 100.00;

# Top 5 Most layoff companies each year
WITH top5layoff_CTE AS
(Select company, year(`date`) AS Years,
total_laid_off,percentage_laid_off,
dense_rank() OVER(partition by year(`date`) order by total_laid_off DESC)
AS Rankings
FROM layoffsp_staging2)
SELECT Years,company, total_laid_off,Rankings
FROM top5layoff_CTE
WHERE Rankings <= 5
Order By Years ASC, total_laid_off DESC;


#Layoff by Severity Bands:
SELECT
CASE
	WHEN percentage_laid_off < 10 THEN 'Below 10%'
    WHEN percentage_laid_off < 25 THEN 'Between 10-25%'
    WHEN percentage_laid_off < 50 THEN 'Between 25-50%'
    WHEN percentage_laid_off < 100 THEN '50-99%'
    ELSE '100%'
END
AS severity_band,
COUNT(*) As events
from layoffsp_staging2
GROUP BY severity_band;

# Place Matters: Children's Health and Well-being - How Assets and Risks are Distributed Across Philadelphia

## Table of Contents
[Project Introduction](#project-introduction)

[Project Description](#project-description)

 - [Data and Technical Considerations](#data-and-technical-considerations)
 - [Project Deliverables](#project-deliverables)
 
 [Getting Started](#getting-started)
 
 - [Generating Graphics](#generating-graphics)
 - [Generating Reports](#generating-reports)
 
 [Data and Methodology](#data-and-methodology)

 - [Methodology](#methodology)
  - [Creating Risk and Asset Scores from Variables](#creating-risk-and-asset-scores-from-variables)
  - [Creating Cumulative Scores](#creating-cumulative-scores)
  - [Aggregating Tract Scores to Districts](#aggregating-tract-scores-to-districts)
  - [Risk Variables](#risk-variables)
  - [Asset Variables](#asset-variables)
 - [Life Expectancy and Social Mobility Data](#life-expectancy-and-social-mobility-charts)
 
 - [Data Sources](#data-sources)

## Project Introduction
The purpose of this project is to analyze and visualize the risks and assets for children's behavioral health and well-being across Philadelphia, by City Council district. The primary project outcomes are specific reports for each City Council district and an overall city summary report. 

### Partners
- Thomas Scattergood Behavioral Health Foundation
- Azavea

### Technologies
- Python
- R
- Flask
- CSS/HTML
- Docker

## Project Description
We have long known that Philadelphia has some of the highest rates of poverty, exposure to childhood trauma, unemployment, and low educational attainment.  But, do we know what assets exist in Philadelphia and are we working to strengthen them?  This project sought to identify where assets and risks lie across the city council’s districts.  We recognize the variability across districts, but presented the information in a way that could be easily interpreted.  The project also seeks to show the impact of risks and assets on social mobility and life expectancy.  We hope that this data provides a roadmap for the city, community organizations, and residents to build upon existing assets and considering the significant inequities in our city.

The project is a follow up to Scattergood's 2016 study which analyzed the risks to children's health and well-being across the city, called [Place Matters](http://www.scattergoodfoundation.org/sites/default/files/Place%20Matters_FINAL_10.16.pdf).

### Data and Technical Considerations
In order to make this work transparent and able to be duplicated, each aspect of the project, from data analysis, graphic generation, and layout, is completed via reproducable scripts. This approach allows other cities or regions to adapt this project to their local areas. It also allows Scattergood to more easily duplicate this work at a later date to generate temporal comparisons. 

The analysis and scripts themselves are tailored to this project and any user seeking to duplicate this work with updated data or in a new geography must follow the Getting Started directions and edit the Python and R scripts to be specific to their data. 

### Project Deliverables
The final output of this project: 
- Reports tailored to each city countil district, 10 reports in all, 2 pages each
- A report that provides an overall city summary, as an introduction to the work and to be geared towards at-large council members
- The individual assets and graphics embedded into the report
- Produced datasets and statistics regarding each census tract and city council district
- this GitHub repo containing reproducable data analysis, visualizations, and report generation

## Getting Started
- update/build the docker container `./scripts/dockerbuild.sh` (this may take a little while if you haven't built it yet)
- enter into docker container  `./scripts/container.sh`
- enter a census API key into `./src/data/census.py`
- run the overlay `python -m src.run` 
- (optional) refresh report copy from csv `python -m src.run.generate_json`

### Generating Graphics
The bar charts and maps are generated via an R script which is not run from within the Docker container. To run the R script and generate the graphics, the following programs and packages are needed. Program and package versions that were used during this project are provided below. The script may work with older or newer versions but will require testing. 
- `R: 3.5.2`
- `tidyverse: 1.2.1`
- `tidyr: 0.8.2`
- `ggthemes: 4.0.1`
- `sf: 0.7-2`
- `svglite: 1.2.1`
- `httr: 1.4.0`
- `classInt: 0.3-1`
- `ggsn: 0.5.0`

Once appropriate dependencies are installed, insert the correct working directory into the script. Then run `R/plotting.R`.

### Generating Reports
See the [Flask App documentation](flask-app/README.md)

## Data and Methodology
### Methodology
This project generates scores for each risk and asset at the census tract level. Scores are then aggregated to each city council district. Risks are subtracted from assets to compute the final cumulative score. This cumulative score is also computed at the census tract level in order to visualize the variance across a more local level. 

The methodology for computing scores, as percentiles, is taken from the Place Matters report. This allows the risk scores, which now incorporate updated American Community Survey (ACS) data, to be compared to the 2016 study. 

#### Aggregating Tract Scores to Districts
Census tracts were assigned to districts based on the location of each tract's centroid. Scores were then aggregated to districts by taking the mean of the scores for the census tracts which were assigned to each distrct.

#### Creating Risk and Asset Scores from Variables
The Place Matters report converts values for each variable to percentiles and takes the mean of each percentile for each variable to compute the risk scores. 

For example, a poverty percentage is found for each census tract. This list of poverty percentages is then converted to percentiles. The highest poverty percentage is the 100th percentile, the lowest poverty percentage is the 1st percentile. All other values are added as percentiles along this rank. 

Once all variable scores are converted to percentiles, the mean of those percentiles is taken. Risk scores per district and tract are the mean of the percentiles for crime, low education status, poverty, unemployment, and adverse childhood experiences (ACEs). Asset scores per district and tract are the mean of the percentiles for SNAP utilizaiton, behavioral health center utilization, walkable access to healthy food, access to parks, and school quality. Information about how these variables are computed is below.

#### Creating Cumulative Scores
To create the cumulative scores, which took into account how assets might mitigate risks, the risk scores were subtracted from the asset scores at the district level. This generated a cumulative score for each council district in the city, allowing each district to be ranked against one another. The same cumulative score calculation was computed at the census tract level for visualization purposes. 

#### Risk Variables
- Crime
  - Shooting victims, from 2014 onward, per 10,000 people.
- Education
  - Percent of the population that is 25 years and over, with less than a 9th grade education.
    - Census API variable: S1501_C02_007E
- Poverty
  - Percent of families in poverty with related children of the householder under 18 years old. 
    - Census API variable: S1702_C01_002E
- Unemployment
  - The unemployment rate for the population 16 years and over. 
    - Census API variable: S2301_C04_001E
- Adverse Childhood Experiences (ACEs)
  - 2016 Philadelphia Expanded ACE Survey conducted by the Philadelphia Health Management Corporation (PHMC).
  - PHMC delivered a weight-adjusted file that was based on age, sex, race, and poverty distribution to get the proper sample size per census tract. This census tract weight adjusted file was used for census tract calculations.
  - PHMC provided an additional weight to be applied when ACE data was aggregated to the district level. When aggregating risks from census tracts to districts, this weight was applied.

#### Asset Variables
- SNAP Utilization
  - Households receiving food stamps which, in the past 12 months, have been below the poverty level
    - Census API Variable: S2201_C03_021E
  - Households not receiving food stamps which, in the past 12 months, have been below the poverty level
    - Census API Variable: S2201_C05_021E
  - SNAP utilization metric was generated as a percentage of total households below poverty that are receiving food stamps.
- Behavioral Health Usage
  - This dataset is a behavioral heatlh usage percentage by zip code. 
  - Usage by zip code was disaggregated to the census tract level by computing an area weighted join. This resulted in a usage metric per census tract.
- Walkable Access to Healthy Food
  - This dataset provivdes a block level assessment of access to healthy grocery stores. It was aggregated to the census tract level via centroid.
- Park Assets
  - Calculated a kernel density for existing and planned Rebuild locations
  - Calculated a kernel density for park assets by sites 
  - Each kernel density was aggregated to each census tract. This provides two scores per census tract, one which represents the density of parks and recreation assets, the other representing the density of Rebuild locations. The average of the two scores was taken, producing one score per census tract.
- School Performance
  - School performance scores are at the catchment level and were disagregated to tracts using an area weighted join.
  - Averaged scores for all three levels (elementary, middle, high) to get an overall metric, providing one score per census tract.
  
 ### Life Expectancy and Social Mobility Charts
 Life expectancy and social mobility data are provided for context for each district and for the city as a whole. Neither of these datasets are incorporated into the risk, asset, or cumulative scores. 
 
 #### Life Expectancy Data
 The data is provided as life expectancy, in years, per census tract. The data was aggregated to districts following the methodology outlined above.
 
 #### Social Mobility Data
The data represented as social mobility is obtained from Opportunity Insights, from the [All Outcomes by Census Tract, Race, Gender and Parental Income Percentile table](https://opportunityinsights.org/wp-content/uploads/2018/10/Codebook-for-Table-4.pdf). Data is provided at the census tract level. The variable used was `kir_pooled_pooled_mean`, this is a pool of all races and genders. `Kir` is a code for the outcome defined as "Mean percentile rank (relative to other children born in the same year) in the national distribution of individual income (i.e. just own earnings) measured as mean earnings in 2014-2015 for the baseline sample". The data was aggregated to districts following the methodology outlined above.

### Data Sources
#### American Community Survey, 2016 5-Year Estimates
- Snap households
- Educational Status
- Poverty
- Unemployment

#### The Census Bureau Tiger Database
- Census tract boundaries, 2010

#### City of Philadelphia
- Crime data, 2006-2018
- Park assets, date not available
- Health centers, 2018
- Streets, 2018
- Walkable access to health food, 2012-2014
- District boundaries, 2016
- School performance data, 2016-2017
- School locations, 2018
- School catchments, 2017-2018
- Community school locations, 2018
- Rebuild locations, 2018

#### PASDA
- Park boundaries, 2016
- Libraries, 2012

#### Public Health Management Corporation’s Community Health Database, 
- Adverse Childhood Experiences (ACEs) data, 2016

#### Community Behavioral Health
- Behavioral health usage by zip code, based on unique eligible members. 2015

#### Opportunity Insights
- [Social mobility data](https://opportunityinsights.org/data/). Data is provided for children born
between 1978 and 1983. Data gathered by Azavea in 2018.

#### National Center for Health Statistics. U.S. Small-Area Life Expectancy Estimates Project (USALEEP)
- [Life Expectancy Estimates Files](https://www.cdc.gov/nchs/nvss/usaleep/usaleep.html), 2010-2015. National Center for Health Statistics. 2018.

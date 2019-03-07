library(sf)
library(classInt)
library(svglite)
library(ggthemes)
library(tidyverse)
library(tidyr)
library(httr)
library(ggsn)


# Set Working Directory ---------------------------------------------------

# Add your working directory at the top of the repo
# setwd('my-local-location/scattergood-reporting-phila-assets-risks/')


# Reading in data ---------------------------------------------------------

# Location of data that is already downloaded or exported from python script
RISK_TRACTS_FILE = 'data/interim/risk_tracts.geojson'
RISK_DISTRICTS_FILE = 'data/interim/risk_districts.geojson'
ASSET_TRACTS_FILE = 'data/interim/asset_tracts.geojson'
ASSET_DISTRICTS_FILE = 'data/interim/asset_districts.geojson'
CUMULATIVE_TRACTS_FILE = 'data/interim/cumulative_tracts.geojson'
CUMULATIVE_DISTRICTS_FILE = 'data/interim/cumulative_districts.geojson'
DISTRICTS_FILE = 'data/interim/risk_districts.geojson'
PARKS_FILE = 'data/raw/Philadelphia_PPR_Park_Boundaries2016_dissolved.geojson'
COMMUNITY_SCHOOLS_LIST_FILE = 'data/raw/community_schools_list.csv'
LIBRARY_FILE = 'data/raw/PhiladelphiaLibraries201302.geojson'

# Reading in computed scores for risk, assets, and aggregated to districts
risk_tracts = sf::st_read(RISK_TRACTS_FILE)
risk_districts = sf::st_read(RISK_DISTRICTS_FILE)
asset_tracts = sf::st_read(ASSET_TRACTS_FILE)
asset_districts = sf::st_read(ASSET_DISTRICTS_FILE)
cumu_tracts = sf::st_read(CUMULATIVE_TRACTS_FILE)
cumu_districts = sf::st_read(CUMULATIVE_DISTRICTS_FILE)
districts = sf::st_read(DISTRICTS_FILE)

# Reading in Neighborhoods file, this will be used for name labels, not for boundaries
neighborhoods <- sf::st_read('https://raw.githubusercontent.com/azavea/geo-data/master/Neighborhoods_Philadelphia/Neighborhoods_Philadelphia.geojson')
neighborhoods = st_transform(neighborhoods, 3857)
neighborhoods <- neighborhoods %>% mutate(lon=map_dbl(geometry, ~st_centroid(.x)[[1]]), # add centroid values for labels
                                          lat=map_dbl(geometry, ~st_centroid(.x)[[2]]))

# Manually select which neighborhood names will be labeled for each district
names_1 <- data.frame(districts = 1, name = c('Pennsport', 'Old City', 'Fairhill', 'Frankford', 'Yorktown'))
names_2 <- data.frame(districts = 2, name = c('Riverfront', 'Navy Yard', 'Cedar Park', 'West Passyunk')) #'Penrose', 
names_3 <- data.frame(districts = 3, name = c('Powelton', 'Fairmount', 'Walnut Hill', 'Grays Ferry')) # 'Overbrook'
names_4 <- data.frame(districts = 4, name = c('East Mount Airy', 'Carroll Park', 'Fairmount', 'East Falls')) # 'Roxborough'
names_5 <- data.frame(districts = 5, name = c('Tioga', 'Spring Garden', 'Stanton', 'Yorktown', 'Upper Kensington'))
names_6 <- data.frame(districts = 6, name = c('Pennypack Woods', 'Tacony', 'Frankford', 'Millbrook')) # 'Bridesburg', 
names_7 <- data.frame(districts = 7, name = c('Port Richmond', 'Frankford', 'Feltonville', 'Olney', 'Mayfair'))
names_8 <- data.frame(districts = 8, name = c('Strawberry Mansion', 'Wister', 'East Germantown', 'Roxborough')) #'Hunting Park', 
names_9 <- data.frame(districts = 9, name = c('Oxford Circle', 'Logan', 'Fox Chase', 'Crescentville', 'West Mount Airy'))
names_10 <- data.frame(districts = 10, name = c('Pennypack Park', 'Bustleton', 'Somerton', 'Byberry', 'Academy Gardens'))

# Bind all of the vectors of neighborhood names together
names <- rbind(names_1, names_2, names_3, names_4, names_5, names_6, names_7, names_8, names_9, names_10)

# Data for profile maps

  # Locations of all schools
  schools <- sf::st_read('http://data.phl.opendata.arcgis.com/datasets/d46a7e59e2c246c891fbee778759717e_0.geojson')
  schools <- st_transform(schools, 3857)
  # Layer 1) Locations of community schools
  comm_schools_list <- read_csv(COMMUNITY_SCHOOLS_LIST_FILE)
  comm_schools <- schools %>% filter(FACILNAME_LABEL %in% comm_schools_list$school_name)
  
  # Layer 2) Locations of district schools, excluding community schools
  dist_schools <- schools %>% filter(TYPE == 'District' & !FACILNAME_LABEL %in% comm_schools_list$school_name)
  
  # Layer 3 + 4) PDPH + FQHC health centers
  health <- sf::st_read('http://data.phl.opendata.arcgis.com/datasets/f87c257e1039470a8a472694c2cd2e4f_0.geojson')
  health <- st_transform(health, 3857)
  health_fqhc <- health %>% filter(ORGANIZATION != 'PDPH')
  health_pdph <- health %>% filter(ORGANIZATION == 'PDPH')
  
  # Layer 5) Parks
  parks <- sf::st_read(PARKS_FILE)
  parks <- st_transform(parks, 3857)
  
  # Layer 6) Locations of rebuild sites

  rebuild_list <- c("8th & Diamond Playground", "Al Pearlman Sports Center", "Athletic Recreation Center", "Barrett Playground", "Belfield Recreation Center", "Capitolo Playground", "Carousel House", "Carroll Park", "Cecil B. Moore Recreation Center",
                    "Cherashore Playground", "Chew Playground", "Cobbs Creek Environmental Education Center", "Cobbs Creek Recreation Center & Pool", "Cohocksink Recreation Center",
                    "Disston Recreation Center", "East Poplar Playground", "Fishtown Recreation Center", "Fotteral Square", "Fox Chase Playground", "Francis Myers Recreation Center",
                    "Frank Glavin Playground", "Gifford Playground", "Hancock Playground", "Happy Hollow Playground", "Harrowgate Park", "Hayes Playground",
                    "Heitzman Playground", "James Finnegan Playground", "Jerome Brown Playground", "John C. Anderson Cultural Center", "Kingsessing Recreation Center", 
                    "Lawncrest Recreation Center", "Library Branch - Blanche A. Nixon", "Library Branch - Haverford Avenue", "Library Branch - Nicetown-tioga", 
                    "Library Branch - Paschalville", "Library Branch - West Oak Lane", "Malcolm X Memorial Park", "Mander Playground", "Marian Anderson Recreation Center", 
                    "Martin Luther King Recreation Center", "McPherson Square", "McVeigh Recreation Center", "Miles Mack Playground", "Moss Playground", 
                    "Murphy Recreation Center", "Nelson Playground", "Olney Recreation Center", "Panati Playground", "West Fairmount Park", "Pelbano Playground", 
                    "Piccoli Playground", "Pleasant Hill Park", "Powers Park", "Rivera Recreation Center", "Russo Park Playground", "Shepard Recreation Center", 
                    "Trenton & Auburn Playground", "Vare Recreation Center", "Vernon Park", "Vogt Recreation Center", "Waterloo Playground", "West Mill Creek", 
                    "Ziehler Playground")
  
  park_assets <- sf::st_read('http://data.phl.opendata.arcgis.com/datasets/4df9250e3d624ea090718e56a9018694_0.geojson')
  park_assets <- st_transform(park_assets, 3857)
  libraries <- sf::st_read(LIBRARY_FILE)
  libraries <- st_transform(libraries, 3857)
  rebuild_parks <- park_assets %>% filter(ASSET_NAME %in% rebuild_list)
  rebuild_parks <- st_centroid(rebuild_parks)
  rebuild_libraries <- libraries %>% filter(ASSET_NAME %in% rebuild_list)
  
  # Layer 7) Street data for visualization on profile map
  streets <- sf::st_read('http://data-phl.opendata.arcgis.com/datasets/c36d828494cd44b5bd8b038be696c839_0.geojson')
  streets <- st_transform(streets, 3857)
  arterials <- streets %>% filter(CLASS == '1'|CLASS == '2')
  locals <- streets %>% filter(CLASS == '3')

# Colors
text_color <- '#27323d'
cumulative_colors <- c('#ffda09', '#ccd84d', '#9ad27e', '#67cb9b', '#34bfa4', '#01b199')
cumulative_colors_districts <- c('#ffda09', '#9ad27e', '#67cb9b', '#01b199')
risk_colors <- c('#fff3c3', '#ffeea6', '#ffe889', '#ffe36a', '#ffde43', '#ffda09')
risk_colors_districts <- c('#fff3c3', '#ffe889', '#ffe36a', '#ffda09')
asset_colors <- c('#01b199', '#0eb9a4', '#58c3b1', '#7eccbf', '#9fd8cd', '#bee4dc')
asset_colors_districts <- c('#01b199', '#58c3b1', '#7eccbf', '#bee4dc')

# Functions for Mapping ---------------------------------------------------
map_style_legend <- function(){
    theme_void() + theme(legend.position = "bottom",
                       legend.text=element_text(size=10, color = text_color),
                       legend.title=element_text(size=15, color = text_color),
                       panel.grid.major = element_line(colour = 'white'),
                       plot.margin = unit(c(0, 0, 0.5, 0), "cm"))#top, #right #bottom #left
}
  
map_style_without_legend <- function(){
    theme_void() + theme(legend.position = "none",
                         panel.grid.major = element_line(colour = 'white'))
}

scale_bar <- function(data, dist){
  scalebar(data, st.bottom = FALSE, location="bottomright", dist = dist, dist_unit = "mi",
           transform = FALSE, model = "WGS84", st.color=text_color, box.fill=c('#929090', 'white'),
           box.color='#929090', border.size = 0.25, st.size=3.5, height=0.02)
}

fill_color_discrete <- function(colorList, name, labels){
  scale_fill_manual(values = c(colorList[1:length(colorList)]),
                    name = name,
                    labels = labels,
                    na.value="#929090",
                    guide = guide_legend(
                      default.unit="inch",
                      keywidth=0.6,
                      keyheight=0.2,
                      direction = "horizontal",
                      nrow = 1,
                      byrow = T,
                      draw.ulim = F,
                      title.position = 'top',
                      title.hjust = 0.5,
                      label.position = 'bottom')
  )
}
fill_color_stretch <- function(low_color, high_color, name){
  scale_fill_gradient(low = low_color, high = high_color,
                      name = name,
                      na.value="#929090",
                      guide = guide_colorbar(
                        direction = "horizontal",
                        barheight = unit(3, units = "mm"),
                        barwidth = unit(60, units = "mm"),
                        draw.ulim = F,
                        title.position = 'top',
                        title.hjust = 0.5,
                        label.hjust = 0.5)
  )
}

createBreaks <- function(data, variable, num, style){
  breaks <- classIntervals(data[[variable]], num, style = style)$brks
  return (breaks)
}

createRoundedLabels <- function(data, variable, num, style){
  breaks <- createBreaks(data, variable, num, style)
  breaks_rounded <- round(breaks,0)
  these_labels <- vector()
  counter <- 0
  for(i in breaks[1:length(breaks)-1]){
    counter <- counter + 1
    these_labels <- c(these_labels, paste(breaks_rounded[counter], '-',breaks_rounded[counter + 1]))
  }
  if(any(is.na(data[[variable]]))){
    these_labels <- c(these_labels, 'No value')
  }
  return (these_labels)
}

createBins <- function(data, variable, num, style){
  breaks <- createBreaks(data, variable, num, style)
  data <- data %>%
    mutate(bins = findInterval(data[[variable]], breaks)) %>%
    mutate(bins = ifelse(bins == max(bins, na.rm=T), bins - 1, bins))
  data$bins <- as.factor(data$bins)
  return(data)
}

save_files <- function(dist, plot, name){
  p = paste0('flask-app/static/plots/', 'district_', dist, '_', name, '.png')
  ggsave(p, plot = plot, device = 'png', width = 6, height = 6)
  s = paste0('flask-app/static/plots/', 'district_', dist, '_', name, '.svg')
  ggsave(s, plot = plot, device = 'svg', width = 6, height = 6)
}


district_maps = function(district){

  # Filter districts to select only the specific district for each iteration
  the_district = districts %>%
    filter(DISTRICT == district)
  
  # Select all the other districts, to be used as a visual mask
  all_but_the_district = districts %>%
    filter(DISTRICT != district)
  
  # The following sequence is used to create the bounds of the map. Because each district is a different shape, 
  # this needs to be carried out in order to create a buffer around each district and to make the map extent a square for
  # regardless of district shape.
  
    # find bounding coorindates
    bbox <- st_bbox(the_district)
    
    # create four corners of actual bounding polygon
    points = st_sfc(st_point(c(bbox$xmin, bbox$ymax)), st_point(c(bbox$xmin, bbox$ymin)), 
                    st_point(c(bbox$xmax, bbox$ymin)), st_point(c(bbox$xmax, bbox$ymax)), crs=3857)
    
    # find diagonal distance of coordinates of bounding polygon
    diagonal <- st_distance(points[1], points[3])
    
    # create the buffer distance, which is just less than half of the diagonal distance of coordinates
    buffer_dist <- diagonal/2.5
    
    # convert coordinates from bounding polygon into a data.frame
    points_df <- data.frame(st_coordinates(points))
    
    # add the first point coorindates again to the end, this will make the polygon able to close
    points_df <- rbind(points_df, points_df[1,])
    
    # create an actual bounding polygon, not just coordinates
    poly <- st_sf(
      st_sfc(
        st_polygon(
          list(as.matrix(points_df)))), crs = 3857)
    
    # find centroid of polygon
    poly_centroid <- st_centroid(poly)
    
    # create buffer of centroid using the the half diagonal length as distance
    the_district_buffer = st_buffer(poly_centroid, dist = buffer_dist)
    
    # create coordinates for the map range, using the buffer
    mapRange <- c(range(st_coordinates(the_district_buffer)[,1]),
                  range(st_coordinates(the_district_buffer)[,2]))
  
  # Select the neighborhood names to be used for this district
  the_names <- names %>% filter(districts == district)
  the_neighborhoods <- neighborhoods %>% filter(mapname %in% the_names$name)

  # Create map for cumulative score by tract
  overall = ggplot() +
    geom_sf(data = createBins(cumu_tracts, 'cumulative', 6, 'jenks'), aes(fill = bins), size = 0) +
    geom_sf(data = arterials, color = '#100C0C', size = ifelse(arterials$CLASS == 1, 0.6, 0.3), alpha=1)+
    geom_sf(data = all_but_the_district, color = 'white', size = 0, alpha = 0.6) +
    geom_text(data = the_neighborhoods, aes(label = mapname, x = lon, y = lat),
              size = 4, color = 'white', hjust = 'right', check_overlap = TRUE) +
    geom_sf(data = the_district, color = 'white', size = 0.7, alpha=0) +
    coord_sf(xlim = mapRange[c(1:2)], ylim = mapRange[c(3:4)]) +
    #scale_bar(the_district, 1) + # optional scale bar
    map_style_legend() +
    fill_color_discrete(cumulative_colors, "Overall Score", createRoundedLabels(cumu_tracts, 'cumulative', 6, 'jenks'))
    
  save_files(district, overall, 'overall')

  # Filter risk tracts to select only the specific district for each iteration
  one_district_risk = sf::st_intersection(districts, risk_tracts) %>%
    filter(DISTRICT == district)

  # Filter asset tracks to select only the specific district for each iteration
  one_district_asset = sf::st_intersection(districts, asset_tracts) %>%
    filter(DISTRICT == district)

  # Create map for asset score by tract
  asset = ggplot() +
    geom_sf(data = createBins(one_district_asset, 'asset', 6, 'jenks'), aes(fill = bins), size = 0) +
    #scale_bar(one_district_asset, 1) + # optional scale bar
    map_style_legend() +
    fill_color_discrete(asset_colors, "Asset Score", createRoundedLabels(one_district_asset, 'asset', 6, 'jenks'))

   save_files(district, asset, 'asset')

  # Create map for risk score by tract
  risk = ggplot() +
    geom_sf(data = createBins(one_district_risk, 'risk.1', 6, 'jenks'), aes(fill = bins), size = 0) +
    #scale_bar(one_district_risk, 1) + # optional scale bar
    map_style_legend() +
    fill_color_discrete(risk_colors, "Risk Score", createRoundedLabels(one_district_risk, 'risk.1', 6, 'jenks'))

  save_files(district, risk, 'risk')

  # Create locator map to show where in the city the district is
  locator = ggplot() +
    geom_sf(data = districts, size = 0.1) +
    geom_sf(data = the_district, fill = '#8E8E8E', size = 0, alpha=1) +
    theme_void() +
    theme(legend.position = "none",
          panel.grid.major = element_line(colour = 'white'))

  save_files(district, locator, 'locator')

  # Create profile map
  profile <-
   ggplot() +
   geom_sf(data = all_but_the_district, fill = '#BEBEBE', size = 0, alpha=0.75) +
   geom_sf(data = the_district, fill = '#ECECEC', size = 0, alpha=1) +
   geom_sf(data = arterials, color = '#646262', size = ifelse(arterials$CLASS == 1, 0.6, 0.3), alpha=0.6) +
   geom_sf(data = locals, color = '#646262', size = 0.1, alpha=0.4) +
   geom_sf(data = districts, color = '#ffffff', size = 0.5, alpha=0) +
   geom_sf(data = parks, fill = '#5DAF85', size = 0, alpha = 1) +
   geom_sf(data = health_pdph, color = '#218FDD', size = 2.5, alpha = 1, shape = 0, stroke = 1) +
   geom_sf(data = health_fqhc, fill = '#113DB4', color = '#113DB4', size = 2.5, alpha = 1, shape = 22, stroke = 1) +
   geom_sf(data = rebuild_parks, color = '#00600C', size = 2.5, alpha = 1, shape = 8, stroke = 1) +
   geom_sf(data = rebuild_libraries, color = '#00600C', size = 2.5, alpha = 1, shape = 8, stroke = 1) +
   geom_sf(data = dist_schools, color = '#FC7450', size = 2.5, alpha = 1, shape = 2, stroke = 1) +
   geom_sf(data = comm_schools, fill = '#CA1700', color = '#CA1700', size = 2.5, alpha = 1, shape = 24, stroke = 1) +
   geom_text(data = the_neighborhoods, aes(label = mapname, x = lon, y = lat),
             size = 4, color = '#2C2B2B', hjust = 'right', check_overlap = TRUE) +
   scale_color_manual(values=c("#2A8A8C", "#042E69")) +
   coord_sf(xlim = mapRange[c(1:2)], ylim = mapRange[c(3:4)]) +
   #scale_bar(the_district, 1) + # optional scale bar
   map_style_without_legend()

  save_files(district, profile, 'profile')
 }


# Generating all maps for disitricts -----------------------------------------------------

for (i in unique(districts$DISTRICT)) {
  district_maps(i)
}

# Generating maps for city summary -----------------------------------------------------

# Create cleaned up spatial dataframe for mapping with cumulative district scores
district_shapes <- districts[,1]
cumulative_districts_df <- as.data.frame(cumu_districts)[,c(1,4)]
cumu_districts_v2 <- district_shapes %>% left_join(cumulative_districts_df)

# Create map of cumulative scores per district
overall_summary = 
  ggplot() +
  geom_sf(data = createBins(cumu_districts_v2, 'cumulative', 4, 'quantile'), aes(fill = bins), size = 0.5, color = 'white') +
  #scale_bar(cumu_districts_v2, 2) + # optional scale bar
  map_style_legend() +
  fill_color_discrete(cumulative_colors_districts, "Overall Score", 
                      createRoundedLabels(cumu_districts_v2, 'cumulative', 4, 'quantile'))

ggsave('flask-app/static/plots/city_summary_overall.png', 
       plot = overall_summary, device = 'png', width = 5, height = 6)
ggsave('flask-app/static/plots/city_summary_overall.svg', 
       plot = overall_summary, device = 'svg', width = 5, height = 6)

# Create map for asset score by tract
asset_summary = 
  ggplot() +
  geom_sf(data = createBins(asset_districts, 'asset', 4, 'quantile'), aes(fill = bins), size = 0.5, color = 'white') +
  #scale_bar(asset_districts, 2) + # optional scale bar
  map_style_legend() +
  fill_color_discrete(asset_colors_districts, "Asset Score", createRoundedLabels(asset_districts, 'asset', 4, 'quantile'))


ggsave('flask-app/static/plots/city_summary_asset.png', 
       plot = asset_summary, device = 'png', width = 5, height = 6)
ggsave('flask-app/static/plots/city_summary_asset.svg', 
       plot = asset_summary, device = 'svg', width = 5, height = 6)

# Create map for risk score by tract
risk_summary = 
  ggplot() +
  geom_sf(data = createBins(risk_districts, 'risk', 4, 'quantile'), aes(fill = bins), size = 0.5, color = 'white') +
  #scale_bar(risk_districts, 2) + # optional scale bar
  map_style_legend() +
    fill_color_discrete(risk_colors_districts, "Risk Score", createRoundedLabels(risk_districts, 'risk', 4, 'quantile'))

ggsave('flask-app/static/plots/city_summary_risk.png', 
       plot = risk_summary, device = 'png', width = 5, height = 6)
ggsave('flask-app/static/plots/city_summary_risk.svg', 
       plot = risk_summary, device = 'svg', width = 5, height = 6)

# Reading in and cleaning data for charts ------------------------------------------------------------------

# Location of data that is already downloaded or exported from python script for Charts
RISK_DISTRICTS_CSV = 'data/interim/risk_districts.csv'
ASSET_DISTRICTS_CSV = 'data/interim/asset_districts.csv'
ASSET_TRACTS_CSV = 'data/interim/asset_tracts.csv'
LIFE_EXPECTANCY_CSV = 'data/interim/life_expectancy_districts.csv'
SOCIAL_MOBILITY_CSV = 'data/interim/social_mobility_districts.csv'
DEMOGRAPHICS_CSV = 'data/interim/selected_demographic_characteristics.csv'

# Reading in computed scores for risk, assets, and aggregated to districts, as well as life expectancy, social mobility and demographics
risk_scores <- read_csv(RISK_DISTRICTS_CSV)
asset_scores <- read_csv(ASSET_DISTRICTS_CSV)
asset_tract_scores <- read_csv(ASSET_TRACTS_CSV)
life <- read_csv(LIFE_EXPECTANCY_CSV)
social <- read_csv(SOCIAL_MOBILITY_CSV)
dem <- read_csv(DEMOGRAPHICS_CSV)

# Convert wide data to long data for plotting
risk_long <- risk_scores %>% gather(variables, scores, c(crime:unemployment, aces))
asset_long <- asset_scores %>% gather(variables, scores, behavioural:parks)
life_long <- life %>% gather(variables, scores, min:mean)
social_long <- social %>% gather(variables, scores, min:mean)

# Set factor levels for life expectancy
life_long$variables <- factor(life_long$variables, levels = c('mean', 'max', 'min'), ordered = TRUE)
# Compute city mean in order to add line to chart
life_city_mean <- unique(life_long$city_mean)
# Compute national mean in order to add line to chart
life_national_mean <- unique(life_long$national_mean)

# Set factor levels for social mobility
social_long$variables <- factor(social_long$variables, levels = c('mean', 'max', 'min'), ordered = TRUE)
# Compute city mean in order to add line to chart
social_city_mean <- unique(social_long$city_mean)

# set color variable
avg_color <- '#767676'

# Functions bar charts for districts ---------------------------------------------------

save_plots <- function(dist, plot, name){
  p = paste0('flask-app/static/plots/', 'district_', dist, '_', name, '.png')
  ggsave(p, plot = plot, device = 'png', width= 9, height= 4)
  s = paste0('flask-app/static/plots/', 'district_', dist, '_', name, '.svg')
  ggsave(s, plot = plot, device = 'svg', width= 9, height= 4)
}

charts <- function(district){

  # Filter risk data to select only the specific district for each iteration
  the_risks = risk_long %>%
    filter(DISTRICT == district)
  the_risks_score <- unique(the_risks$risk)
  
  # Filter asset data to select only the specific district for each iteration
  the_assets = asset_long %>%
    filter(DISTRICT == district)
  the_assets_score <- unique(the_assets$asset)
  
  # Filter life expectancy data to select only the specific district for each iteration
  the_life = life_long %>%
    filter(DISTRICT == district) 
  
  # Filter social mobility data to select only the specific district for each iteration
  the_social = social_long %>%
    filter(DISTRICT == district) 
  
  # Create plot of asset scores
  asset_plot <-
    ggplot(the_assets, aes(x=variables, y=scores))+
    geom_bar(width = 0.4, stat='identity', position='identity', fill="#142969")+
    labs(x=' ', y='Percentile')+
    scale_y_continuous(expand = c(0, 0))+
    scale_x_discrete(labels=c("Beh. Health\nUtilization", "Food\nAccess", "Parks &\nRec", "School\nQuality", "SNAP\nUtilization"))+
    theme_minimal(base_size = 22)+
    theme(
      legend.position= 'none',
      panel.background = element_rect(fill = '#ffffff', colour = NA),
      rect = element_rect(fill = '#ffffff', colour = NA),
      axis.ticks = element_blank(),
      axis.text.x = element_text(color = text_color),
      axis.text.y = element_text(color = text_color),
      axis.title.y=element_text(face="italic", colour = text_color, size = 20),
      panel.grid.major.x = element_blank(),
      plot.margin = unit(c(0.5, 1, -0.5, 0.5), "cm")) #top, #right #bottom #left
  
  save_plots(district, asset_plot, 'asset_barchart')
  
  # Create plot of risk scores
  risk_plot <- 
    ggplot(the_risks, aes(x=variables, y=scores))+
    geom_bar(width = 0.4, stat='identity', position='identity', fill="#FC7450")+
    labs(x=' ', y='Percentile')+
    scale_x_discrete(labels=c("ACEs", "Shootings", "Limited\nEducation", "Poverty", "Unemployment"))+
    scale_y_continuous(expand = c(0, 0))+ 
    theme_minimal(base_size = 22)+
    theme(
      legend.position= 'none',
      panel.background = element_rect(fill = '#ffffff', colour = NA),
      rect = element_rect(fill = '#ffffff', colour = NA),
      axis.ticks = element_blank(),
      axis.text.x = element_text(color = text_color),
      axis.text.y = element_text(color = text_color),
      axis.title.y=element_text(face="italic", colour = text_color, size = 20),
      panel.grid.major.x = element_blank(),
      plot.margin = unit(c(0.5, 1, -0.5, 0.5), "cm")) #top, #right #bottom #left
  
  save_plots(district, risk_plot, 'risk_barchart')
  
  # Create plot for life expectancy
  life_plot <- 
    ggplot(the_life, aes(x=variables, y=scores))+
    geom_bar(width = 0.6, stat='identity', position='identity', fill="#162B67")+
    labs(x=' ', y=' ')+
    coord_flip()+
    geom_hline(yintercept = life_city_mean, colour = avg_color, size=0.5, linetype='dashed')+
    geom_text(aes(0.55, (life_city_mean-5), label = 'City Avg.'), colour = avg_color, size = 6)+
    geom_hline(yintercept = life_national_mean, colour = avg_color, size=0.5, linetype='dashed')+
    geom_text(aes(0.55, (life_national_mean+1), label = 'National Avg.'), colour = avg_color, hjust = 0, size = 6)+
    geom_text(aes(3, 2, label = 'Lowest in District'), colour = '#ffffff', hjust = 0, size = 8)+
    geom_text(aes(2, 2, label = 'Highest in District'), colour = '#ffffff', hjust = 0, size = 8)+
    geom_text(aes(1, 2, label = 'Average in District'), colour = '#ffffff', hjust = 0, size = 8)+ 
    ylab("Life expectancy at birth for people who were born in the district,\n from 2010-2015")+
    scale_y_continuous(expand = c(0, 0), breaks = c(0,10,20,30,40,50,60,70,80,90), limits = c(0,95))+
    theme_minimal(base_size = 25)+
    theme(
      legend.position= 'none',
      panel.background = element_rect(fill = '#ffffff', colour = NA),
      rect = element_rect(fill = '#ffffff', colour = NA),
      axis.ticks = element_blank(),
      axis.text.y = element_blank(),
      axis.text.x = element_text(color = text_color),
      axis.title.x=element_text(face="italic", colour = text_color, size = 20),
      panel.grid.major.y = element_blank(),
      plot.margin = unit(c(0, 1, 0, -0.5), "cm")) #top, #right #bottom #left
  
  save_plots(district, life_plot, 'life_exp_barchart')
  
  
  
  # Create plot for social mobility
  social_plot <- 
    ggplot(the_social, aes(x=variables, y=scores))+
    geom_bar(width = 0.6, stat='identity', position='identity', fill="#162B67")+
    labs(x=' ', y=' ')+
    coord_flip()+
    geom_hline(yintercept = social_city_mean, colour = avg_color, size=0.5, linetype='dashed')+
    geom_text(aes(0.55, (social_city_mean+0.04), label = 'City Avg.'), colour = avg_color, size = 6)+
    geom_text(aes(3, 0.02, label = 'Lowest in District'), colour = '#ffffff', hjust = 0, size = 8)+
    geom_text(aes(2, 0.02, label = 'Highest in District'), colour = '#ffffff', hjust = 0, size = 8)+
    geom_text(aes(1, 0.02, label = 'Average in District'), colour = '#ffffff', hjust = 0, size = 8)+
    ylab("Mean percentile rank of income, based on national distribution,\nfor children who grew up in the district")+
    scale_y_continuous(expand = c(0, 0), breaks = c(0,0.1,0.2,0.3,0.4,0.5,0.6), limits = c(0,0.7), 
                       labels=c(' ','10th','20th','30th','40th','50th','60th'))+
    theme_minimal(base_size = 25)+
    theme(
      legend.position= 'none',
      panel.background = element_rect(fill = '#ffffff', colour = NA),
      rect = element_rect(fill = '#ffffff', colour = NA),
      axis.ticks = element_blank(),
      axis.text.y = element_blank(),
      axis.text.x = element_text(color = text_color),
      axis.title.x=element_text(face="italic", colour = text_color, size = 20),
      panel.grid.major.y = element_blank(),
      plot.margin = unit(c(0, 1, 0, -0.5), "cm")) #top, #right #bottom #left
  
  save_plots(district, social_plot, 'social_mobility_barchart')
}


# Generating bar charts for districts -----------------------------------------------------

for (i in unique(districts$DISTRICT)) {
  charts(i)
}

# Functions  mini bar charts for the page 2 table ---------------------------------------------------

save_table_plots <- function(dist, variable, plot, name){
  p = paste0('flask-app/static/plots/', 'district_', dist, '_', variable, '_', name, '.png')
  ggsave(p, plot = plot, device = 'png', width= 9, height= 3)
  s = paste0('flask-app/static/plots/', 'district_', dist, '_', variable, '_', name, '.svg')
  ggsave(s, plot = plot, device = 'svg', width= 9, height= 3)
}

table_bars <- function(district){

  # Filter asset tract data to select only the specific district for each iteration
  the_assets = asset_scores %>%
    filter(DISTRICT == district)
  
  # Select the column header names for the columns which actually represent unique asset scores
  asset_names <- names(the_assets)[3:7]
    
  # Iterate of the column names selected above, create a bar chart for each one
    for(i in asset_names){
      variable = i
      
      max_variable = max(asset_scores[[variable]], na.rm=T)
      
      max_district <- asset_scores %>% filter(asset_scores[[variable]] == max_variable)
      max_district <- max_district$DISTRICT

      # Create a new dataframe which finds the min value and max value for that asset for the district
      asset_bars <- data.frame(DISTRICT = c(district, max_district),
                                  variables = c('this_district', 'max_district'), 
                                  scores = c(the_assets[[variable]], 
                                             max_variable))

     # Create a bar chart which plots the min value and max value
     asset_table_plot <-
        ggplot(asset_bars, aes(x=variables, y=scores))+
        geom_bar(width = 0.6, stat='identity', position='identity', fill="#162B67")+
        labs(x=NULL, y=NULL, title=NULL)+
        scale_y_continuous(expand = c(0, 0), breaks = c(0,10,20,30,40,50,60,70,80,90,100), limits = c(0,100))+
        coord_flip()+
        theme(
          panel.background=element_blank(),
          panel.grid.major=element_blank(),
          panel.grid.minor=element_blank(),
          axis.ticks=element_blank(),
          axis.text.x=element_blank(),
          axis.text.y=element_blank(),
          axis.title.x=element_blank(),
          axis.title.y=element_blank(),
          plot.background = element_rect(fill = "transparent",colour = NA),
          plot.margin = unit(c(-1, 0.5, -1, 0.5), "cm"), #top, #right #bottom #left
          legend.position = 'none')
      
      save_table_plots(district, variable, asset_table_plot, 'table_barchart')
    }
}

# Generating mini bar charts for the page 2 table -----------------------------------------------------
for (i in unique(districts$DISTRICT)) {
  table_bars(i)
}

# Generating bar charts for city summary ----------------------------------

# creating variables for lowest and highest life expectancy in Philadelphia
lowest_life <- min(life$min)
highest_life <- max(life$max)

# creating data frame for lowest and highest life exp.
life_summary <- data.frame(variables=c('lowest', 'highest'), 
                           scores=c(lowest_life, highest_life))

# creating variables for lowest and highest social mobility in Philadelphia
lowest_social <- min(social$min)
highest_social <- max(social$max)

# creating data frame for lowest and highest social mobility
social_summary <- data.frame(variables=c('lowest', 'highest'), 
                             scores=c(lowest_social, highest_social))

# Create city summary social mobility bar chart
social_summary_plot <- 
  ggplot(social_summary, aes(x=variables, y=scores))+
  geom_bar(width = 0.7, stat='identity', position='identity', fill="#162B67")+
  labs(x=' ', y=' ')+
  coord_flip()+
  geom_hline(yintercept = social_city_mean, colour = avg_color, size=0.8, linetype='dashed')+
  geom_text(aes(2.3, (social_city_mean+0.05), label = 'City Avg.'), colour = avg_color, size = 8)+
  geom_text(aes(2, 0.01, label = 'Lowest in Philadelphia'), colour = '#ffffff', hjust = 0, size = 8)+
  geom_text(aes(1, 0.01, label = 'Highest in Philadelphia'), colour = '#ffffff', hjust = 0, size = 8)+
  scale_y_continuous(expand = c(0, 0), breaks = c(0,0.1,0.2,0.3,0.4,0.5,0.6,0.7), limits = c(0,0.75), 
                     labels=c(' ','10th','20th','30th','40th','50th','60th','70th'))+
  ylab("Mean percentile rank of income, based on national distribution,\nfor children who grew up in Philadelphia")+
  theme_minimal(base_size = 30)+
  theme(
    legend.position= 'none',
    panel.background = element_rect(fill = '#ffffff', colour = NA),
    rect = element_rect(fill = '#ffffff', colour = NA),
    axis.ticks = element_blank(),
    axis.text.y = element_blank(),
    axis.text.x = element_text(color = text_color),
    axis.title.x=element_text(face="italic", colour = text_color),
    plot.margin = unit(c(0.25, 1, 0.5, -0.5), "cm"), #top, #right #bottom #left
    panel.grid.major.y = element_blank())

ggsave('flask-app/static/plots/city_summary_social_mobility_barchart.png', 
       plot = social_summary_plot, device = 'png', width= 13, height= 4)
ggsave('flask-app/static/plots/city_summary_social_mobility_barchart.svg', 
       plot = social_summary_plot, device = 'svg', width= 13, height= 4)

# Create city summary life expectancy bar chart
life_summary_plot <- 
  ggplot(life_summary, aes(x=variables, y=scores))+
  geom_bar(width = 0.7, stat='identity', position='identity', fill="#162B67")+
  labs(x=' ', y=' ')+
  coord_flip()+
  geom_hline(yintercept = life_city_mean, colour = avg_color, size=0.8, linetype='dashed')+
  geom_text(aes(2.5, (life_city_mean-5), label = 'City Avg.'), colour = avg_color, size = 8)+
  geom_hline(yintercept = life_national_mean, colour = avg_color, size=0.8, linetype='dashed')+
  geom_text(aes(2.5, (life_national_mean+1), label = 'National Avg.'), colour = avg_color, hjust = 0, size = 8)+
  geom_text(aes(2, 2, label = 'Lowest in Philadelphia'), colour = '#ffffff', hjust = 0, size = 8)+
  geom_text(aes(1, 2, label = 'Highest in Philadelphia'), colour = '#ffffff', hjust = 0, size = 8)+
  ylab("Life expectancy at birth for people who were born in Philadelphia,\n from 2010-2015")+
  scale_y_continuous(expand = c(0, 0), breaks = c(0,10,20,30,40,50,60,70,80,90), limits = c(0,95))+
  theme_minimal(base_size = 30)+
  theme(
    legend.position= 'none',
    panel.background = element_rect(fill = '#ffffff', colour = NA),
    rect = element_rect(fill = '#ffffff', colour = NA),
    axis.ticks = element_blank(),
    axis.text.y = element_blank(),
    axis.text.x = element_text( color = text_color),
    axis.title.x=element_text(face="italic",  color = text_color),
    plot.margin = unit(c(0.25, 1, 0.5, -0.5), "cm"), #top, #right #bottom #left
    panel.grid.major.x = element_blank())

ggsave('flask-app/static/plots/city_summary_life_exp_barchart.png', 
       plot = life_summary_plot, device = 'png', width= 13, height= 4)
ggsave('flask-app/static/plots/city_summary_life_exp_barchart.svg', 
       plot = life_summary_plot, device = 'svg', width= 13, height= 4)



# Count profile points and parks for each district ------------------------

countPointsPolys <- function(){
  counts <- data.frame(DISTRICT = c(1:10), health_pdph_centers = NA, health_fqhc_centers = NA,
                       school_dist = NA, school_comm = NA, rebuild = NA, parks_intersect = NA, 
                       parks_within = NA)
  
  for (i in unique(districts$DISTRICT)) {
   
    district = i
    
    the_district = districts %>%
      filter(DISTRICT == district)
    
    counts <- counts %>% 
      mutate(health_pdph_centers = 
               ifelse(DISTRICT == district, 
                      lengths(st_covers(the_district, health_pdph)), 
                      health_pdph_centers)) %>%
      mutate(health_fqhc_centers =
               ifelse(DISTRICT == district,
                      lengths(st_covers(the_district, health_fqhc)),
                      health_fqhc_centers)) %>%
      mutate(school_dist =
               ifelse(DISTRICT == district,
                      lengths(st_covers(the_district, dist_schools)),
                      school_dist)) %>%
      mutate(school_comm =
               ifelse(DISTRICT == district,
                      lengths(st_covers(the_district, comm_schools)),
                      school_comm)) %>%
      mutate(rebuild =
               ifelse(DISTRICT == district,
                      lengths(st_covers(the_district, rebuild_libraries)) + lengths(st_covers(the_district, rebuild_parks)),
                      rebuild)) %>%
      mutate(parks_intersect =
               ifelse(DISTRICT == district,
                      lengths(st_intersects(the_district, parks)),
                      parks_intersect)) %>%
      mutate(parks_within =
               ifelse(DISTRICT == district,
                      lengths(st_contains(the_district, parks)),
                      parks_within))
    
  } 
  return(counts)
}

district_profile_counts <- countPointsPolys()
write.csv(district_profile_counts, "data/interim/district_profile_counts.csv", row.names = FALSE)

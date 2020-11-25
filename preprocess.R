library(dplyr)
library(stringr)
library(ggplot2)
library(data.table)


setwd("C:/Users/maxim/ECE/ING5/Data Analytics/project/Shiny App/project_Airbnb")

dataURLs <- read.csv(file="data_urls.csv")

selectedCountries <- c("france", "spain", "belgium")

min_date <- '2020-01-01'
max_date <- '2020-07-01'

dataURLs <- dataURLs %>%
  filter(country %in% selectedCountries) %>%
  filter(data_date > min_date & data_date < max_date)

#Creating a dataframe to associate cities to their country
cityCountry <- read.csv(text="country,city")

for(i in 1:nrow(dataURLs)) {
  url <- dataURLs[i,]
  listingsURL <- url[1, "listings_url"]
  calendarURL <- url[1, "calendar_url"]
  country <- url[1, "country"]
  city <- url[1, "city"]
  data_date <- url[1, "data_date"]
  
  listings <- fread(listingsURL)
  calendar <- fread(calendarURL)
  
  newrow <- data.frame(country, city)
  names(newrow) <- c("country", "city")
  cityCountry <- rbind(cityCountry, newrow)

  ## Add Keys: columns country, city and day date
  listings$country <- country
  listings$city <- city
  listings$data_date <- data_date
  
  ## Select interesting columns
  ### Most columns don't contain interesting information
  columns_listings <- c("country","city", "data_date", "id", "neighbourhood_cleansed", 
                        "latitude", "longitude", 
                        "property_type", "room_type", "accommodates", "bedrooms", 
                        "beds", "price", "minimum_nights",  "maximum_nights")
  
  listings <- listings %>% 
    select(columns_listings) %>% 
    arrange(id)
  
  
  # Cleaning calendar dataframe
  
  ## arrange by id and date
  calendar <- calendar %>% 
    arrange(listing_id, date)
  
  ## add day number (starting first day)
  calendar <- calendar %>%
    group_by(listing_id) %>%
    mutate(day_nb = row_number()) %>%
    ungroup()
  
  ## change available column to binary
  calendar <- calendar %>%
    mutate(available = ifelse(available=="t", 1, 0))
  
  ## clean price column and transform to numeric
  calendar <- calendar %>%
    mutate(price = str_replace(price, "\\$", ""),
           adjusted_price = str_replace(adjusted_price, "\\$", ""))
  calendar <- calendar %>%
    mutate(price = str_replace(price, ",", ""),
           adjusted_price = str_replace(adjusted_price, ",", ""))
  calendar <- calendar %>%
    mutate(price = as.numeric(price),
           adjusted_price = as.numeric(adjusted_price))
  
  ## calculate estimated revenue for upcoming day
  calendar <- calendar %>%
    mutate(revenue = price*(1-available))
  
  ## calculate availability, price, revenue for next 30, 60 days ... for each listing_id
  calendar <- calendar %>%
    group_by(listing_id) %>%
    summarise(availability_30 = sum(available[day_nb<=30], na.rm = TRUE),
              #availability_60 = sum(available[day_nb<=60], na.rm = TRUE),
              #availability_90 = sum(available[day_nb<=90], na.rm = TRUE),
              #availability_365 = sum(available[day_nb<=365], na.rm = TRUE),
              price_30 = mean(price[day_nb<=30 & available==0], na.rm = TRUE),
              #price_60 = mean(price[day_nb<=60 & available==0], na.rm = TRUE),
              #price_90 = mean(price[day_nb<=90 & available==0], na.rm = TRUE),
              #price_365 = mean(price[day_nb<=365 & available==0], na.rm = TRUE),
              revenue_30 = sum(revenue[day_nb<=30], na.rm = TRUE),
              #revenue_60 = sum(revenue[day_nb<=60], na.rm = TRUE),
              #revenue_90 = sum(revenue[day_nb<=90], na.rm = TRUE),
              #revenue_365 = sum(revenue[day_nb<=365], na.rm = TRUE)           
    )
  
  if (class(listings$id) != "integer") {
    listings <- listings %>%
      mutate(
        id = as.numeric(id)
      )
  }
  
  listings_cleansed <- listings %>% left_join(calendar, by = c("id" = "listing_id"))
  
  dir.create(file.path("data_cleansed", country, city, data_date), recursive = TRUE)
  
  print(paste0("saving data into ", file.path("data_cleansed", country, city, data_date, "listings.csv")))
  write.csv(listings_cleansed, file.path("data_cleansed", country, city, data_date, "listings.csv"))
}

cityCountry <- cityCountry %>%
  select(city, country) %>%
  group_by(country) %>%
  distinct(city)

write.csv(cityCountry, "country_city.csv")
print("--- Preprocess finished ---")
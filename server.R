#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(dplyr)
library(stringr)
library(ggplot2)
library(data.table)
library(lubridate)
library(leaflet)

# Define server logic required to draw a histogram
shinyServer(function(input, output, session) {
    
    ## Once data for multiple cities are prepared
    ## We can read these data and concatenate them together into one dataframe
    
    # Get the dataframe associating cities to countries
    cityCountry <- read.csv("country_city.csv")

    # Reading cleansed data
    countries <- cityCountry$country
    countries <- unique(countries)
    cities <- cityCountry

    addCountryToCity <- function(city, country) {
        paste(city, ' - ', country )
    }

    cities <- mutate(cities, cityText = addCountryToCity(city, country))

    # Put the cities into the input of cities
    observe({
        citiesInput <- input$cities
        if(is.null(citiesInput)){
            # Can also set the label and select items
            updateCheckboxGroupInput(session, "cities",
                                     choices = setNames(cities$city, cities$cityText)
            )
        }
    })

    # We are only interested in data between min_date and max_date
    min_date <- '2020-01-01'
    max_date <- '2020-07-01'
    
    files_paths <- c()
    
    # Read data in cities of every country between min_date and max_date
    for(country in countries){
        citiesOfCountry <- cityCountry %>%
            filter(country == country)
        citiesOfCountry <- citiesOfCountry$city
        citiesOfCountry <- unique(citiesOfCountry)
        
        for(city in citiesOfCountry){
            #file_dir <- file.path(".", "data", city)
            file_dir <- file.path(".", "data_cleansed", country, city)
            file_subdirs <- list.dirs(file_dir)
            file_subdirs <- file_subdirs[-1]
            
            for(file_subdir in file_subdirs){
                if(file_subdir < file.path(file_dir, min_date) | file_subdir > file.path(file_dir, max_date)  )
                    file_subdirs = file_subdirs[file_subdirs != file_subdir]
            }
            files_paths <- c(files_paths, file_subdirs)
        }
    }
    files_paths <- file.path(files_paths, "listings.csv")
    listings <- 
        do.call(rbind,
                lapply(files_paths, read.csv, row.names=1))
    
    ## Preprocess
    listings$bedrooms <- ifelse(listings$bedrooms >= 5, "5+", listings$bedrooms)
    
    multipleCities <- reactive({
        if(length(input$cities) > 1){
            return(TRUE)
        } else {
            return(FALSE)
        }
    })
    
    hasAggregation <- reactive({
        if(input$aggregType == "no_aggreg" || input$aggregOn == "no_aggreg"){
            return(FALSE)
        } else {
            return(TRUE)
        }
    })
    
    data <- reactive({
        cities <- input$cities
        
        daterange <- input$daterange
        startdate <- ymd(daterange[1])
        enddate <- ymd(daterange[2])
        
        daterange <- interval(startdate, enddate)
        
        listings <- listings %>%
            filter(city %in% cities) %>%
            filter(ymd(data_date) %within% daterange)
            
        #View(listings)
        listings
    })
    
    plotLogic <- reactive({
        feature <- input$feature
        aggregType <- input$aggregType
        aggregOn <- input$aggregOn
        plotType <- input$plotType
        isGrouped <- input$isGrouped
        binwidth <- input$binwidth
        
        # If it is a basic plot without aggregation
        if(!hasAggregation()){
            # place the data inside the plot
            p <- ggplot(data(), aes_string(feature))
        }
        # If it has an aggregation
        else {
            aggreg_data <- data() %>%
                group_by(!!aggregOn := get(aggregOn), city)
            
            p <- switch (aggregType,
                 "no_aggreg" = return(NULL),
                 
                 "total" = {
                     total_data <- aggreg_data %>%
                         summarise(total = sum(get(feature), na.rm = TRUE), .groups = 'drop')
                     
                     plot <- ggplot(total_data, aes(y = total, x=get(aggregOn)))
                 },
                 
                 "average" = {
                     avg_data = aggreg_data %>%
                         summarise(average = mean(get(feature), na.rm = TRUE), .groups = 'drop')
                     
                     plot <- ggplot(avg_data, aes(y = average, x=get(aggregOn)))
                 },
                 
                 "median" = {
                     median_data = aggreg_data %>%
                         summarise(median = median(get(feature), na.rm = TRUE), .groups = 'drop')
                     
                     plot <- ggplot(median_data, aes(y = median, x=get(aggregOn)))
                 })
        }
        
        # determining if we plot with a facet for each city or not
        if(isGrouped && multipleCities()){
            p <- p + facet_wrap(.~city, ncol=1)
        }
        
        # adding the plot layer, depending if we want to plot an aggregation or not
        if(!hasAggregation()){
            
            #scaling if necessary
            if(feature == "revenue_30"){
                p <- p + scale_x_continuous(limits = quantile(data()$revenue_30, c(0.1, 0.9), na.rm = TRUE))
            }
            #scaling if necessary
            if(feature == "price_30"){
                p <- p + scale_x_continuous(limits = quantile(data()$price_30, c(0.1, 0.9), na.rm = TRUE))
            }
            
            p <- p + switch(plotType,
                "boxplot" = {
                    geom_boxplot(aes(fill = city), outlier.shape = NA)
                },
                
                "histogram" = {
                    geom_histogram(binwidth = binwidth, aes(fill = city))
                },
                
                "barplot" = {
                    geom_bar(aes(fill = city))
                },
                
                "circle" = {
                    geom_bar(aes(fill = city))
                })
        } else {
            p <- p + switch(plotType,
                "boxplot" = {
                    return(NULL)
                },
                
                "histogram" = {
                    geom_histogram(stat='identity', aes_string(fill=aggregOn))
                },
                
                "barplot" = {
                    geom_bar(stat='identity', aes_string(fill=aggregOn))
                },
                
                "circle" = {
                    geom_bar(stat='identity', aes_string(fill=aggregOn))
                })
        }
        
        # adding polar coord if the selected plot is circle
        if(plotType == "circle"){
            p <- p + coord_polar()
        }
        
        # add the labels
        p <- p + switch(feature,
            "no_feature" = return(NULL),
            "availability_30" = xlab("Availability over the last 30 days"),
            "revenue_30" = xlab("Revenue over the last 30 days"),
            "price_30" = xlab("Price"))
        
        # Adding the final title
        featureTitle <- switch (feature,
            "availability_30" = "Availability over the last 30 days",
            "revenue_30" = "Revenue over the last 30 days",
            "price_30" = "Price")
        
        p <- p + ggtitle(label = paste(featureTitle))

        p
    })
    
    plot1 <- reactive({
        if(multipleCities()){
            plotLogic()
        } else {
            return(NULL)
        }
    })
    
    
    plot2 <- reactive({
        if(multipleCities() || is.null(input$cities)){
            return(NULL)
        } else {
            plotLogic()
        }
    })
    
    dataToPlot <- reactive({
        feature <- input$feature
        top <- input$top

        dt <- data() %>%
                arrange(desc((!!as.name(feature)))) %>%
                head(top)
        
        dt
    }) 
    
    map <- reactive({
        if(multipleCities() || is.null(input$cities)){
            return(NULL)
        } else {
            feature = input$feature
            if(feature == "no_feature"){
                return(NULL)
            }
            else{
                dt = dataToPlot()
                leaflet() %>%
                    addProviderTiles(providers$Stamen.TonerLite,
                                     options = providerTileOptions(noWrap = TRUE)
                    ) %>%
                    addMarkers(lng = dt$longitude, lat = dt$latitude,
                               label = paste0("long : ", dt$longitude, " - ",
                                             "lat : ", dt$latitude, " - ",
                                             feature, " : ", dt[[feature]])) 
            }
        }
    })

    output$plot1 <-renderPlot(plot1())
    output$plot2 <-renderPlot(plot2())
    output$map <- renderLeaflet(map())

})

#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(leaflet)

# Define UI for application that draws a histogram
shinyUI(fluidPage(

    # Application title
    titlePanel("Airbnb City Analysis"),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            checkboxGroupInput("cities", "Cities to compare :",
                            
                               ),
            
            dateRangeInput("daterange", "Date range:",
                           start = "2020-01-01",
                           end   = "2020-07-01",
                           min    = "2020-01-01",
                           max    = "2020-07-01"),
            
            selectInput("feature", "Feature to compare :",
                        c("-" = "no_feature",
                          "Availability over the last 30 days" = "availability_30",
                          "Revenue over the last 30 days" = "revenue_30",
                          "Price" = "price_30")),
            
            selectInput("aggregType", "Aggregation Type :",
                        c("-" = "no_aggreg",
                          "Total" = "total",
                          "Average" = "average",
                          "Median" = "median")),
            
            selectInput("aggregOn", "Aggregation On :",
                        c("-" = "no_aggreg",
                          "Room Type" = "room_type",
                          "House Size (number of bedrooms)" = "bedrooms",
                          "Neighbourhood" = "neighbourhood_cleansed")),
            
            selectInput("plotType", "Plot Type :",
                        c("Boxplot" = "boxplot",
                          "Histogram" = "histogram",
                          "Barplot" = "barplot",
                          "Circle" = "circle")),
            
            sliderInput("binwidth", "Bin width :",
                        min = 1, max = 200, value = 3
            ),
            
            checkboxInput("isGrouped", "Group the data by city", TRUE),
            
            sliderInput("top", "Top data points (for map) :",
                        min = 1, max = 1000, value = 50
            ),
        ),

        # Show a plot of the generated distribution
        mainPanel(
            tabsetPanel(
                tabPanel("Comparing cities", plotOutput("plot1")),
                tabPanel("Deep dive into a city", 
                         plotOutput("plot2"),
                         leafletOutput("map"))
            )
        )
    )
))

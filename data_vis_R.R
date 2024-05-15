rm(list=ls())

# Load necessary libraries
library(sf)
library(ggplot2)
library(raster)
library(leaflet)
library(dplyr)
library(htmlwidgets)

# Read CSV data
data <- read.csv("sound_and_tree_data.csv", sep = ";")

# Separating longitude and latitude from the location column
location_split <- strsplit(as.character(data$location), ", ")

# Function to extract and properly convert coordinates
extract_latitude <- function(coord) {
  coord <- gsub("°S", "", coord)
  as.numeric(sub(",", ".", coord)) * -1  # Convert to negative
}

extract_longitude <- function(coord) {
  coord <- gsub("°E", "", coord)
  as.numeric(sub(",", ".", coord))  # East is positive
}

# Apply the functions to get latitudes and longitudes
latitudes <- sapply(location_split, function(x) extract_latitude(x[1]))
longitudes <- sapply(location_split, function(x) extract_longitude(x[2]))

# Add latitudes and longitudes to the data frame
data$longitude <- longitudes
data$latitude <- latitudes

# Remove obsolete column
data <- data %>% select(-location)

print(data)

# Convert to a spatial data frame (assuming EPSG:4326 for WGS84)
gdf <- st_as_sf(data, coords = c("longitude", "latitude"), crs = 4326)

# Save the spatial data in multiple formats
st_write(gdf, "output/sound_and_tree_data_R.geojson", driver = "GeoJSON", append=FALSE)
st_write(gdf, "output/sound_and_tree_data_R.shp", append=FALSE)
st_write(gdf, "output/sound_and_tree_data_R.gpkg", driver = "GPKG", append=FALSE)

############################## DO OVDJE RADI ###################################

# Load raster image
img <- stack("assets/siteA_orthomosaic_lowres.tif")
plot(img)
img_bounds <- extent(img)

# Filter data based on labels
amp <- gdf %>% filter(label == "amp")
speakers <- gdf %>% filter(label == "speaker") %>% st_transform(3163)
trees <- gdf %>% filter(label == "tree") %>% st_transform(3163)
amp <- amp %>% st_transform(3163)

# Calculate distances between trees and speakers
distances <- data.frame(
  distance_to_speaker1 = st_distance(trees, speakers[1, ]),
  distance_to_speaker2 = st_distance(trees, speakers[2, ]),
  distance_to_speaker3 = st_distance(trees, speakers[3, ]),
  distance_to_speaker4 = st_distance(trees, speakers[4, ])
)
trees <- cbind(trees, distances)

trees_wgs84 <- st_transform(trees, 4326)
speakers_wgs84 <- st_transform(speakers, 4326)
amp_wgs84 <- st_transform(amp, 4326)

# Extract numeric coordinates for mean calculation
amp_coords <- st_coordinates(amp_wgs84)

# Create a leaflet map
m <- leaflet() %>%
  addProviderTiles(providers$Stamen.Terrain, options = providerTileOptions(maxZoom = 50)) %>%
  setView(lng = mean(amp_coords[, 1]), lat = mean(amp_coords[, 2]), zoom = 20)

m

# Project raster to WGS84 and add to the leaflet map
img_wgs84 <- projectRaster(img, crs = "+proj=longlat +datum=WGS84")
img_layer <- raster(img_wgs84)  # Convert to a RasterLayer

# Check for NA values and determine min/max values for the palette
min_val <- min(values(img_layer), na.rm = TRUE)
max_val <- max(values(img_layer), na.rm = TRUE)

if (is.infinite(min_val) || is.infinite(max_val)) {
  # Handle the case where all values are NA
  min_val <- 0
  max_val <- 1
}

# Create a color palette
img_pal <- colorNumeric(c("black", "white"), domain = c(min_val, max_val), na.color = "transparent")

# Add the raster image to the leaflet map
m <- m %>%
  addRasterImage(img_layer, colors = img_pal, opacity = 0.8)

# Add markers
add_circles <- function(df, color, radius, label) {
  m <<- m %>%
    addCircleMarkers(
      lng = st_coordinates(df)[, 1],
      lat = st_coordinates(df)[, 2],
      radius = radius,
      color = color,
      fillColor = color,
      fillOpacity = 0.5,
      popup = label
    )
}
add_circles(trees_wgs84, "red", trees_wgs84$sound_dB/2, paste(trees_wgs84$label, trees_wgs84$row, trees_wgs84$designation, sep = "_"))
add_circles(amp_wgs84, "yellow", 5, paste(amp_wgs84$label, amp_wgs84$row, amp_wgs84$designation, sep = "_"))
add_circles(speakers_wgs84, "blue", 5, paste(speakers_wgs84$label, speakers_wgs84$row, speakers_wgs84$designation, sep = "_"))

# Save the map as an HTML file
saveWidget(m, "output/sound_and_tree_data_R.html", selfcontained = TRUE)

# Save trees with distances as CSV
write.csv(st_drop_geometry(trees), "output/trees_and_distances_R.csv")

# Plot the data using ggplot2
ggplot() +
  geom_raster(aes(x = img_bounds@xmin:img_bounds@xmax, y = img_bounds@ymin:img_bounds@ymax, fill = img_layer)) +
  geom_sf(data = trees_wgs84, aes(size = (sound_dB^2)/2), color = "red") +
  geom_sf(data = speakers_wgs84, size = 5, color = "blue") +
  geom_sf(data = amp_wgs84, size = 5, color = "yellow") +
  geom_sf_text(data = trees_wgs84, aes(label = paste(row, designation, sound_dB, "dB", sep = "-")), color = "white", angle = 45) +
  labs(x = "Longitude(°)", y = "Latitude(°)") +
  theme_minimal() +
  ggsave("output/sound_and_tree_data_R.png", width = 10, height = 10)
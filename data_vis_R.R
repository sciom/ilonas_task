rm(list=ls())

# Load necessary libraries
library(sf)
library(ggplot2)
library(raster)
library(dplyr)

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

# Save trees with distances as CSV
write.table(trees, "output/trees_and_distances_R.csv", sep=";")

trees_wgs84 <- st_transform(trees, 4326)
speakers_wgs84 <- st_transform(speakers, 4326)
amp_wgs84 <- st_transform(amp, 4326)

############################## PLOTTING ###################################

# Load raster
img <- raster("assets/siteA_orthomosaic_lowres.tif")

# Assuming your raster file has three bands corresponding to RGB
img <- stack("assets/siteA_orthomosaic_lowres.tif")

# Explicitly define the CRS to project the raster
desired_crs <- "+proj=longlat +datum=WGS84 +no_defs"  # This is the WGS 84 CRS
img_projected <- projectRaster(img, crs = desired_crs)

# Ensure the raster has been correctly projected
if (is.null(img_projected)) {
  stop("Raster projection failed.")
}

# Create an RGB object from the raster
rgb_image <- raster::brick(img_projected[[1]], img_projected[[2]], img_projected[[3]])
rgb_df <- as.data.frame(rasterToPoints(rgb_image))
names(rgb_df) <- c("x", "y", "r", "g", "b")

# Convert to hexadecimal colors
rgb_df$color <- rgb(rgb_df$r, rgb_df$g, rgb_df$b, maxColorValue = 255)

# Convert sf to data frame for ggplot
point_df <- as.data.frame(st_coordinates(gdf))
point_df$row <- gdf$row
point_df$designation <- gdf$designation
point_df$label <- gdf$label
point_df$sound_dB <- gdf$sound_dB
point_df$point_size <- gdf$sound_dB/3  # arbitrary scaling factor for point size calculation
point_df$point_size[is.na(point_df$point_size)] <- 3

# Calculate the range of x and y coordinates from point data with a buffer
x_range <- range(point_df$X, na.rm = TRUE)
y_range <- range(point_df$Y, na.rm = TRUE)

# Adding a buffer to avoid cutting off points at the edges (adjust the buffer size as needed)
buffer <- 0.0001  # Adjust the buffer size depending on your coordinate system and extent
x_lim <- c(x_range[1] - buffer, x_range[2] + buffer)
y_lim <- c(y_range[1] - buffer, y_range[2] + buffer)

# Generate all combinations of tree and speaker coordinates for lines
tree_speaker_pairs <- expand.grid(
  tree_index = 1:nrow(trees_wgs84),
  speaker_index = 1:nrow(speakers_wgs84)
)

# Create a data frame to hold the coordinates for these combinations
lines_df <- data.frame(
  tree_x = trees_wgs84$geometry[tree_speaker_pairs$tree_index] %>% st_coordinates() %>% `[`(, 1),
  tree_y = trees_wgs84$geometry[tree_speaker_pairs$tree_index] %>% st_coordinates() %>% `[`(, 2),
  speaker_x = speakers_wgs84$geometry[tree_speaker_pairs$speaker_index] %>% st_coordinates() %>% `[`(, 1),
  speaker_y = speakers_wgs84$geometry[tree_speaker_pairs$speaker_index] %>% st_coordinates() %>% `[`(, 2)
)

# Define the plot with specific zoom
plot <- ggplot() +
  geom_tile(data = rgb_df, aes(x = x, y = y, fill = color)) +
  scale_fill_identity() +
  geom_point(data = point_df, aes(x = X, y = Y, color = label), size = point_df$point_size, alpha=0.7) +
  scale_color_manual(values = c("tree" = "red", "speaker" = "blue", "amp" = "yellow")) +
  labs(
    x = "Longitude (°)",  # X-axis label
    y = "Latitude (°)",  # Y-axis label
    color = "Label"  # Legend title
  ) +
  coord_fixed(xlim = x_lim, ylim = y_lim) +
  theme_minimal()

# Add dashed lines between all trees and all speakers
plot <- plot + geom_segment(data = lines_df, aes(x = tree_x, y = tree_y, xend = speaker_x, yend = speaker_y),
                            linetype = "dashed", color = "white", alpha = 0.3)

# Filter data for trees to add labels with background boxes
tree_labels <- point_df[point_df$label == "tree", ]

# Add labels next to trees with a semi-transparent background box
plot <- plot + geom_label(data = tree_labels, aes(x = X, y = Y, label = paste(row, "-", designation, " | ", sound_dB, " dB", sep = "")),
                          color = "white", fill = "black", alpha = 0.5, fontface = "bold",
                          hjust = -0.1, vjust = 0, size = 3, angle = 45,
                          label.size = 0.5,  # Adjusts padding around text
                          label.padding = unit(0.5, "lines"))  # Adjusts space around text within the box

# Save the plot
ggsave("output/sound_and_tree_data_R.png", plot = plot, width = 10, height = 10, units = "in", bg = "white")



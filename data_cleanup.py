import pandas as pd
import geopandas as gpd

data = pd.read_csv("sound_and_tree_data.csv")

# Separating longitude and lattitude from the location column
longitudes = []
latitudes = []


# Splitting the location column into longitude and latitude
for location in data["location"]:
    location = location.split(", ")
    latitudes.append(float("-" + location[0].replace("°S", "").replace(",", ".")))
    longitudes.append(float(location[1].replace("°E", "").replace(",", ".")))
    
data["longitude"] = longitudes
data["latitude"] = latitudes

# removing obsolete column
data = data.drop(columns=["location"])

print(data)

# creating a geodataframe

gdf = gpd.GeoDataFrame(data, geometry=gpd.points_from_xy(data.longitude, data.latitude))

gdf.to_file("output/sound_and_tree_data.geojson", driver="GeoJSON")
gdf.to_file("output/sound_and_tree_data.shp")
gdf.to_file("output/sound_and_tree_data.gpkg", driver="GPKG")


# Visualize using folium

import folium

m = folium.Map(location=[-1.286389, 36.817223], zoom_start=12)

for i in range(len(data)):
    folium.Marker([data.iloc[i]["latitude"], data.iloc[i]["longitude"]], popup=data.iloc[i]["tree_type"]).add_to(m)
    
m.save("output/sound_and_tree_data.html")


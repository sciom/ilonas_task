import folium
import pandas as pd
import geopandas as gpd
import rasterio as rs
import contextily as ctx
import matplotlib.pyplot as plt

data = pd.read_csv("sound_and_tree_data.csv", delimiter=";")

bats_data = pd.read_csv("bats_t1.csv", delimiter=",")

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

gdf = gpd.GeoDataFrame(data, geometry=gpd.points_from_xy(data.longitude, data.latitude), crs="EPSG:4326")

gdf.to_file("output/sound_and_tree_data.geojson", driver="GeoJSON")
gdf.to_file("output/sound_and_tree_data.shp")
gdf.to_file("output/sound_and_tree_data.gpkg", driver="GPKG")


# Visualize using folium


amp = gdf[gdf["label"] == "amp"]

m = folium.Map(
    location=[amp["latitude"], amp["longitude"]],
    zoom_start=20,
    max_zoom=50,
    TileLayer="Stamen Terrain")

img = rs.open("assets/siteA_orthomosaic_lowres.tif")
img_data = img.read([1,2,3])

# transform the image into NxMx3 array
img_data = img_data.transpose(1,2,0)

overlay = folium.raster_layers.ImageOverlay(
    name="Orthomosaic",
    image=img_data,
    bounds=[
        [img.bounds[3], img.bounds[2]],
        [img.bounds[1], img.bounds[0]],
    ],
    opacity=0.8,
    interactive=True,
    cross_origin=True
)
m.add_child(overlay)

speakers = gdf[gdf["label"] == "speaker"]
speakers.reset_index(drop=True, inplace=True)
trees = gdf[gdf["label"] == "tree"]
trees.reset_index(drop=True, inplace=True)

trees.to_crs(epsg=3163, inplace=True)
speakers.to_crs(epsg=3163, inplace=True)
amp.to_crs(epsg=3163, inplace=True)

# calculate the distance between the trees and the speakers

distances = {
    "distance_to_speaker1": [],
    "distance_to_speaker2": [],
    "distance_to_speaker3": [],
    "distance_to_speaker4": [],
}

# calculate the distance between the trees and the speakers in meters

for i in range(len(trees)):
    for j in range(len(speakers)):
        distances[f"distance_to_speaker{j+1}"].append(
            trees.iloc[i].geometry.distance(speakers.iloc[j].geometry)
        )

trees = pd.concat([trees, pd.DataFrame(distances)], axis=1)

trees_wgs84 = trees.copy()
trees_wgs84 = trees_wgs84.to_crs(epsg=4326)
speakers_wgs84 = speakers.copy()
speakers_wgs84 = speakers_wgs84.to_crs(epsg=4326)
amp_wgs84 = amp.copy()
amp_wgs84 = amp_wgs84.to_crs(epsg=4326)


    



for i in range(len(trees)):
    print(i)
    label = "_".join((
        trees.iloc[i]["label"],
        str(trees.iloc[i]["row"]),
        str(trees.iloc[i]["designation"])))
    # add a circular marker where the diameter is based on `data["sound_dB"]` column
    folium.CircleMarker(
        [trees.iloc[i]["latitude"], trees.iloc[i]["longitude"]],
        radius=trees.iloc[i]["sound_dB"]/2 ,
        color="red",
        fill=True,
        fill_color="red",
        fill_opacity=0.5,
        popup=label
    ).add_to(m)
    folium.Marker([trees.iloc[i]["latitude"], trees.iloc[i]["longitude"]], popup=label).add_to(m)
    
for i in range(len(amp)):
    label = "_".join((
        amp.iloc[i]["label"],
        str(amp.iloc[i]["row"]),
        str(amp.iloc[i]["designation"])))
    folium.CircleMarker(
        [amp.iloc[i]["latitude"], amp.iloc[i]["longitude"]],
        radius=5,
        color="yellow",
        fill=True,
        fill_color="yellow",
        fill_opacity=0.5,
        popup=label
        ).add_to(m)

for i in range(len(speakers)):
    label = "_".join((
        speakers.iloc[i]["label"],
        str(speakers.iloc[i]["row"]),
        str(speakers.iloc[i]["designation"])))
    folium.CircleMarker(
        [speakers.iloc[i]["latitude"], speakers.iloc[i]["longitude"]],
        radius=5,
        color="blue",
        fill=True,
        fill_color="blue",
        fill_opacity=0.5,
        popup=label).add_to(m)
    
    
    # folium.Marker([data.iloc[i]["latitude"], data.iloc[i]["longitude"]], popup=label).add_to(m)
    
# m.save("output/sound_and_tree_data.html")

trees.to_csv("output/trees_and_distances_bats.csv")

# plot the trees and the speakers on a map

# scale data from 1 to 10
# sound_data_scaled = (trees["sound_dB"] - trees["sound_dB"].min()) / (trees["sound_dB"].max() - trees["sound_dB"].min())


fig, ax = plt.subplots(figsize=(10, 10))
# draw basemap

# plot the basemap using rasterio tif

plt.imshow(
    img_data,
    extent=[img.bounds[0], img.bounds[2], img.bounds[1], img.bounds[3]])

trees_wgs84.plot(
    ax=ax, color="red", label="Trees", markersize=(trees["sound_dB"]**2)/2)
speakers_wgs84.plot(
    ax=ax, color="blue", label="Speakers", markersize=50)
amp_wgs84.plot(
    ax=ax, color="yellow", label="Amplifier")
bats.plot(
    ax=ax, color="green", label="Bats", markersize=150
)

# plot the distance between the trees and the speakers
# by drawing a line between the trees and the speakers

for i in range(len(trees)):
    for j in range(len(speakers)):
        x = [trees_wgs84.iloc[i].geometry.x, speakers_wgs84.iloc[j].geometry.x]
        y = [trees_wgs84.iloc[i].geometry.y, speakers_wgs84.iloc[j].geometry.y]
        plt.plot(x, y, color="white", linestyle="--", alpha=0.3)

# add labels to the trees

for i in range(len(trees)):
    t = plt.text(
        trees_wgs84.iloc[i].geometry.x,
        trees_wgs84.iloc[i].geometry.y,
        f"{trees.iloc[i].row}-{trees.iloc[i].designation} | {trees.iloc[i].sound_dB}dB",
        fontsize=10,
        color="white",rotation=45)
    t.set_bbox(dict(facecolor="black", alpha=0.3, edgecolor="black"))
legend = ax.legend()
legend.legendHandles[0]._sizes = [50]

bats_data["longitude"] = bats_data["LATITUDE"].apply(lambda x: float(x.replace(",", ".").replace("°E", "")))
bats_data["latitude"] = bats_data["LONGITUDE"].apply(lambda x: float(x.replace(",", ".").replace("°S", ""))*-1)
bats_data
bats = gpd.GeoDataFrame(bats_data, geometry=gpd.points_from_xy(bats_data["longitude"], bats_data["latitude"]), crs="EPSG:4326")

# split by period
bats_during = bats[bats["PERIOD"] == "during"]
bats_after = bats[bats["PERIOD"] == "after"]

# merge by date

recordedpoints = []
for i in range(len(bats)):
    
    if [bats.iloc[i].geometry.x, bats.iloc[i].geometry.y] in recordedpoints:
        t = plt.text(
            bats.iloc[i].geometry.x - 0.00020,
            bats.iloc[i].geometry.y - 0.0001,
            f"{bats.iloc[i]['MANUAL_ID']} \nNb. of sounds:{bats.iloc[i]['Nb_of_sound']} \n{bats.iloc[i]['DATE']} \nPeriod:{bats.iloc[i]['PERIOD']}",
            fontsize=10,
            color="white",rotation=0)
        if bats.iloc[i]["PERIOD"] == "during":
            t.set_bbox(dict(facecolor="red", alpha=0.3, edgecolor="black"))
        t.set_bbox(dict(facecolor="black", alpha=0.3, edgecolor="black"))
    else:
        
        t = plt.text(
            bats.iloc[i].geometry.x+ 0.00001,
            bats.iloc[i].geometry.y - 0.0001,
            f"{bats.iloc[i]['MANUAL_ID']} \nNb. of sounds:{bats.iloc[i]['Nb_of_sound']} \n{bats.iloc[i]['DATE']} \nPeriod:{bats.iloc[i]['PERIOD']}",
            fontsize=10,
            color="white",rotation=0)
        recordedpoints.append([bats.iloc[i].geometry.x, bats.iloc[i].geometry.y])  
        t.set_bbox(dict(facecolor="black", alpha=0.3, edgecolor="black"))
    




# ctx.add_basemap(ax, crs=trees_wgs84.crs, source=ctx.providers.OpenStreetMap.Maapnik)

plt.xlabel("Longitude(°)")
plt.ylabel("Latitude(°)")

x_edge = (trees_wgs84.total_bounds[2]-trees_wgs84.total_bounds[0])*.1
y_edge = (trees_wgs84.total_bounds[3]-trees_wgs84.total_bounds[1])*.1

plt.xlim(trees_wgs84.total_bounds[0]-x_edge, trees_wgs84.total_bounds[2]+x_edge)
plt.ylim(trees_wgs84.total_bounds[1]-y_edge, trees_wgs84.total_bounds[3]+y_edge)

plt.savefig("output/sound_and_tree_data_bats.png")
plt.show()


trees.to_csv("output/trees_and_distances_bats.csv")

bats.to_file("output/bats.geojson", driver="GeoJSON")
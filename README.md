# The task

Ilona wants to visualize the data from the .xlsx file. The data contains the following collumns:

- Name_row
- Name_tree
- name_speacker
- name_amplifyer
- location
- sound (dB)

The original email from Ilona is as follows:

```
As I talked about it this morning I will need a visual which shows the sound perceived by the marked tree. I have noted everything in the excel below, the coordinates of the trees but also of the speakers and the amplifier so that you understand well and therefore know if it is possible to place them on the map and around each tree to put a more or less large circle depending on the sound received.

So we can also perhaps have the distance between each marked tree and the speaker precisely. We can see with all this if we have an impact depending on the intensity of the sound.
```

The data is in the file `sound and tree data.xlsx`. 

First, we need to clean the data a bit. We will separate longitudes and latitudes from the `location` column and create new columns for them. we will also add a column for the distance between the tree and the speaker, aswell as a column for labels "tree", "amplifier" and "speaker". Reformating of the data will be done using python. The data will be saved in a new file `sound_and_tree_data_cleaned.csv` and provided with this document.

## Data cleanup

### 1. Load the data

First, we will load the data from the excel file.

```python
import pandas as pd

data = pd.read_excel('sound and tree data.xlsx')
```



Then we will create a map with the trees, speakers and amplifiers. The size of the circles will be proportional to the sound intensity. We will also add a line between the tree and the speaker, with the distance between them.


## Python

With python we will use the following libraries:

- pandas
- geopandas
- folium

### Cleaning the data





## QGIS

## R
import os

def write_file(geodataframe, filename):
    # write geojson
    filename = 'data/interim/' + filename
    geojson = filename + '.geojson'
    if os.path.isfile(geojson):
        os.remove(geojson)
    geodataframe.to_file(driver = 'GeoJSON', filename=geojson)

    # write csv
    csv = filename + '.csv'
    geodataframe \
        .drop('geometry', axis = 1) \
        .to_csv(csv)

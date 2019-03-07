import io
import copy
import requests
import pandas as pd
import geopandas as gpd

from scipy.stats import rankdata, percentileofscore
from shapely.geometry import Point


def get_phila_tracts():
    TRACTS_GEOJSON = 'http://data.phl.opendata.arcgis.com/datasets/8bc0786524a4486bb3cf0f9862ad0fbf_0.geojson'
    tracts = geodataframe_from_url(TRACTS_GEOJSON)
    tracts = tracts[['GEOID10', 'geometry']]
    tracts = tracts.rename(index=str, columns={'GEOID10': 'GEOFIPS'})
    return tracts


def get_phila_zipcodes():
    ZIPCODES_GEOJSON = 'http://data.phl.opendata.arcgis.com/datasets/b54ec5210cee41c3a884c9086f7af1be_0.geojson'
    zipcodes = geodataframe_from_url(ZIPCODES_GEOJSON)[['CODE', 'geometry']]
    zipcodes['ZIPCODE'] = zipcodes['CODE'].astype(int)
    return zipcodes


def query_phila_carto(sql):
    base = 'https://phl.carto.com/api/v2/sql?format=GeoJSON&q='
    query = base + sql
    return geodataframe_from_url(query)


def geodataframe_from_url(url):
    response = requests.get(url)
    geojson = response.json()
    gdf = gpd.GeoDataFrame.from_features(geojson['features'])
    gdf = gdf.dropna(subset=['geometry'], how='all')
    gdf.crs = {'init': 'epsg:4326'}
    gdf = gdf.to_crs({'init': 'epsg:3857'})
    return gdf


def get_rebuild_sites():
    rebuild_uri = 'data/raw/rebuildsites-libgeo.json'
    rebuild_sites = pd.read_json(rebuild_uri, orient='records')
    rebuild_libs = rebuild_sites[rebuild_sites['latlng'] != ""].reset_index()
    rebuild_libs['geometry'] = rebuild_libs['latlng'].apply(Point)
    rebuild_libs['ADDRESS'] = rebuild_libs['addr']
    rebuild_libs['ASSET_NAME'] = rebuild_libs['id']
    rebuild_libs['SITE_NAME'] = rebuild_libs['id']
    rebuild_libs = rebuild_libs.drop(['addr', 'id', 'latlng'], axis=1)
    rebuild_libs_gdf = gpd.GeoDataFrame(rebuild_libs, geometry='geometry')
    rebuild_libs_gdf.crs = {'init': 'epsg:4326'}
    rebuild_libs_gdf = rebuild_libs_gdf.to_crs({'init': 'epsg:3857'})
    return rebuild_libs_gdf


def get_phila_districts():
    DISTRICTS_GEOJSON = 'http://data.phl.opendata.arcgis.com/datasets/9298c2f3fa3241fbb176ff1e84d33360_0.geojson'
    districts = geodataframe_from_url(DISTRICTS_GEOJSON)
    return districts


def array_to_percentiles(array):
    ranks = rankdata(array)
    return [percentileofscore(ranks, a, 'mean') for a in ranks]


def join_polygon_to_polygon(inner_polygon, outer_polygon):
    centroids = copy.deepcopy(inner_polygon)
    centroids['geometry'] = centroids.centroid
    c = gpd.sjoin(centroids, outer_polygon, how='left', op='intersects')
    c['geometry'] = inner_polygon['geometry']
    return c


def get_area_within_tracts(geojson_url, category):
    tracts = get_phila_tracts()
    area_of_interest = geodataframe_from_url(geojson_url)
    union = gpd.overlay(tracts, area_of_interest, how='union')
    union[category] = union.area
    union = union[['GEOFIPS', category]]
    return pd.DataFrame(union.groupby('GEOFIPS').sum().reset_index())


def convert_tract_to_fips(tract):
    tract = str(tract)
    tract_split = tract.split('.')
    tract_a = tract_split[0]
    tract_a = tract_a.zfill(4)

    if len(tract_split) == 1:
        tract_b = '00'
    else:
        tract_b = tract_split[1]

    geofips = '42101' + tract_a + tract_b
    return geofips


def pd_data_frame_from_csv_url(url):
    r = requests.get(url, verify=False).content
    return pd.read_csv(io.StringIO(r.decode('utf-8')))

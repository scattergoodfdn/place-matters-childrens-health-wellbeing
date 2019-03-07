import os

import pandas as pd
import geopandas as gpd

from src.utils import write_file

class CumulativeScore():

    def __init__(self):
        self.risk_tracts = gpd.read_file('data/interim/risk_tracts.geojson')
        self.asset_tracts = gpd.read_file('data/interim/asset_tracts.geojson')
        self.risk_districts = gpd.read_file(
            'data/interim/risk_districts.geojson')
        self.asset_districts = gpd.read_file(
            'data/interim/asset_districts.geojson')

    def calculate_cumulative_scores(self):
        risk = self.risk_tracts[['GEOFIPS', 'DISTRICT', 'risk', 'geometry']]
        assets = self.asset_tracts[['GEOFIPS', 'DISTRICT', 'asset']]
        cumulative = pd.merge(risk, assets, on=['GEOFIPS', 'DISTRICT'])
        cumulative['cumulative'] = cumulative['asset'] - cumulative['risk']

        write_file(cumulative, 'cumulative_tracts')

        # Calculate cumulative score by using the district risk and asset scores
        district_asset = self.asset_districts[['DISTRICT', 'asset', 'geometry']]
        district_risk = self.risk_districts[['DISTRICT', 'risk']]
        cumulative_districts = pd.merge(district_asset, district_risk, on=['DISTRICT'])
        cumulative_districts['cumulative'] = cumulative_districts['asset'] - cumulative_districts['risk']

        write_file(gpd.GeoDataFrame(cumulative_districts), 'cumulative_districts')


def cumulative_scores():
    c = CumulativeScore()
    c.calculate_cumulative_scores()

import os

import numpy as np
import geopandas as gpd
import pandas as pd
from functools import reduce

from src.utils import write_file
from src.data.overlay import Overlay
from src.data.census import CensusAPICall
from src.data.utils import (query_phila_carto, get_phila_tracts,
                            get_phila_districts, array_to_percentiles,
                            join_polygon_to_polygon, convert_tract_to_fips)


class RiskOverlay(Overlay):

    def __crime__(self):
        population_df = self.__population__()
        shooting_victims = query_phila_carto(
            'select * from shootings where year > 2013')
        victims_with_tracts = gpd.sjoin(
            shooting_victims, self.tracts, how='left', op='intersects')
        df = victims_with_tracts[['GEOFIPS']].groupby(
            ['GEOFIPS']).size().reset_index(name='shooting_victims')
        df = pd.merge(population_df, df, how='left')
        df['shooting_victims'] = df['shooting_victims'].fillna(0)
        df['crime'] = (df['shooting_victims'] / df['population']) * 10000
        return df[['GEOFIPS', 'crime']]

    def __education__(self):
        return self.census_api.get_census_variable_df('education')

    def __poverty__(self):
        population_df = self.__population__()
        poverty_df = self.census_api.get_census_variable_df('poverty')
        poverty_df['poverty'] = 100 * \
            (poverty_df['poverty'] / population_df['population'])
        return poverty_df

    def __unemployment__(self):
        return self.census_api.get_census_variable_df('unemployment')

    def __aces__(self):
        aces = pd.read_csv('data/raw/aces_scores.txt')
        aces['GEOFIPS'] = aces['TRACT'].apply(convert_tract_to_fips)
        aces['total_acescore_mean'] = \
            pd.to_numeric(aces['total_acescore_mean'], errors='coerce')
        aces['aces'] = aces['total_acescore_mean']
        population_df = self.__population__()
        aces = pd.merge(population_df, aces, how='left')
        return aces[['GEOFIPS', 'aces', 'acebalwt']]

    def get_aces_districts(self):
        aces = self.__aces__()
        aces['score'] = aces['aces'] * aces['acebalwt']
        tracts = self.get_tract_data_geo()
        tracts_with_aces = pd.merge(aces, tracts)
        district_sums = tracts_with_aces[['score', 'acebalwt', 'DISTRICT']] \
            .groupby('DISTRICT') \
            .sum() \
            .reset_index()
        district_sums['aces'] = \
            district_sums['score'] / district_sums['acebalwt']
        return district_sums[['DISTRICT', 'aces']]

    def get_risk_data(self):
        return self.risk_data

    def calculate_risk_score(self):
        # population
        population = self.__population__()

        # risk layers
        crime = self.__crime__()
        education = self.__education__()
        poverty = self.__poverty__()
        unemployment = self.__unemployment__()
        aces = self.__aces__()

        # combine
        df_list = [population, crime, education, poverty, unemployment, aces]
        self.risk_data = reduce(lambda x, y: pd.merge(x, y), df_list)
        self.risk_data = self.risk_data[self.risk_data['population'] > 5]

        overlay_variables = [
            'crime', 'education', 'poverty', 'unemployment', 'aces']

        for v in overlay_variables:
            self.risk_data[v] = array_to_percentiles(self.risk_data[v])
        self.risk_data['risk'] = self.risk_data[overlay_variables].mean(axis=1)


def risk_overlay():
    r = RiskOverlay()
    r.calculate_risk_score()

    tracts = r.get_tract_data_geo()
    districts = r.get_district_data_geo()
    risk_data = r.get_risk_data()

    # merge tracts with risk 
    risk_tract_geo = pd.merge(tracts, risk_data, how='left')

    # write tract geojson/csv
    write_file(risk_tract_geo, 'risk_tracts')

    # aggregate to district
    district_risk = risk_tract_geo \
        .drop(['geometry', 'GEOFIPS', 'population', 'aces', 'acebalwt'], axis=1) \
        .groupby('DISTRICT') \
        .mean() \
        .reset_index()

    # merge with district gdf
    districts_with_risk = pd.merge(districts, district_risk)
    districts_with_risk = districts_with_risk.drop(['OBJECTID', 'ID'], axis=1)

    # aces district scores must be calculated differently
    d = r.get_aces_districts()
    d['aces'] = array_to_percentiles(d['aces'])
    districts_with_risk = pd.merge(districts_with_risk, d)

    # recalculate the overall risk score
    risk_columns = districts_with_risk[
        ['crime', 'education', 'poverty', 'unemployment', 'aces']]
    districts_with_risk['risk'] = risk_columns.mean(axis=1)

    # write districts geojson/csv
    write_file(districts_with_risk, 'risk_districts')

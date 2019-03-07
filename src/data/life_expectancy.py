import os
import requests

import pandas as pd
import numpy as np

from src.data.overlay import Overlay
from src.data.utils import pd_data_frame_from_csv_url

class LifeExpectancy(Overlay):

    def read_data(self):
        self.LIFE_EXPECTANCY_DATA_URL = 'https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NVSS/USALEEP/CSV/PA_A.CSV'
        df = pd_data_frame_from_csv_url(self.LIFE_EXPECTANCY_DATA_URL)
        df = df[df['CNTY2KX'] == 101][['Tract ID', 'e(0)']]
        df.columns = ['GEOFIPS', 'life_expectancy']
        df['GEOFIPS'] = df['GEOFIPS'].astype(str)
        self.phila_life_expectancy_df = df

    def calculate_district_stats(self):
        df = pd.merge(self.tracts, self.phila_life_expectancy_df)
        df = df[['DISTRICT', 'life_expectancy']]
        summaries = df.groupby('DISTRICT') \
            ['life_expectancy'].agg(['min','max','mean']) \
            .reset_index()
        summaries['city_mean'] = np.mean(df['life_expectancy'])
        summaries['national_mean'] = 78.6
        self.summaries = summaries
        summaries.to_csv('data/interim/life_expectancy_districts.csv')

    def run(self):
        self.read_data()
        self.calculate_district_stats()


def life_expectancy():
    le = LifeExpectancy()
    le.run()

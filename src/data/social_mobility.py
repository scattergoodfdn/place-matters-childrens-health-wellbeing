import os
import requests
import zipfile

import pandas as pd
import numpy as np

from src.data.overlay import Overlay

class SocialMobility(Overlay):

    def download_data(self):
        self.SOCIAL_MOBILITY_DATA_URL = 'https://opportunityinsights.org/wp-content/uploads/2018/10/tract_outcomes.zip'
        zipfile_uri = 'data/raw/social_mobility_data.zip'
        if not os.path.isfile(zipfile_uri):
            r = requests.get(self.SOCIAL_MOBILITY_DATA_URL)
            with open(zipfile_uri, 'wb') as z:
                z.write(r.content)
        csv_uri = 'data/organized/tract_outcomes_early.csv'
        if not os.path.isfile(csv_uri):
            with zipfile.ZipFile(zipfile_uri, 'r') as zip_ref:
                zip_ref.extractall('data/organized/')

    def read_data(self):
        df = pd.read_csv('data/organized/tract_outcomes_early.csv')
        df['GEOFIPS'] = df['state'].apply(lambda x: str(x).zfill(2)) + \
            df['county'].apply(lambda x: str(x).zfill(3)) + \
            df['tract'].apply(lambda x: str(x).zfill(6))
        df = df[(df['state'] == 42) & (df['county'] == 101)] \
            [['GEOFIPS', 'kir_pooled_pooled_mean']] \
            .rename(index=str, columns={'kir_pooled_pooled_mean': 'income_percentile'})
        self.phila_income_opportunity_df = df

    def calculate_district_stats(self):
        df = pd.merge(self.tracts, self.phila_income_opportunity_df)
        df = df[['DISTRICT', 'income_percentile']]
        summaries = df.groupby('DISTRICT') \
            ['income_percentile'].agg(['min','max','mean']) \
            .reset_index()
        summaries['city_mean'] = np.mean(df['income_percentile'])
        self.summaries = summaries
        summaries.to_csv('data/interim/social_mobility_districts.csv')

    def run(self):
        self.download_data()
        self.read_data()
        self.calculate_district_stats()


def social_mobility():
    sm = SocialMobility()
    sm.run()

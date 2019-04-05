import requests

import pandas as pd

CENSUS_API_KEY = # add your census api key here

CENSUS_VARIABLES = {
        'population': 'S0101_C01_001E',
        'education': 'S1501_C02_007E',
        'poverty': 'S1702_C01_002E',
        'unemployment': 'S2301_C04_001E',
        'snap_households': 'S2201_C03_021E',
        'not_snap_households': 'S2201_C05_021E',
        'age_18_and_over': 'S0101_C01_025E',
        'foreign_born': 'B05002_013E',
        'hispanic_by_race': 'B03002_012E',
        'hispanic_by_origin': 'B03001_003E',
        'african_american': 'B02001_003E',
        'african_american_non_hispanic_by_race': 'B03002_004E',
        'white': 'B02001_002E',
        'white_non_hispanic_by_race': 'B03002_003E',
        'asian': 'B02001_005E',
        'asian_non_hispanic_by_race': 'B03002_006E',
        'speaks_only_english': 'C16001_002E'
        # api variables https://api.census.gov/data/2016/acs/acs5/subject/variables.html
        #   https://api.census.gov/data/2016/acs/acs5/variables.html
}

class CensusAPICall():

    def __init__(self):
        self.census_api_base = 'https://api.census.gov/data'
        self.year = '2016'
        self.dataset = 'acs/acs5/subject'
        self.geography = 'for=tract:*&in=state:42+county:101'
        self.api_key = CENSUS_API_KEY

    def api_response_to_df(self, response):
        response_array = response.json()
        values = response_array[1:]
        columns = response_array[0]
        df = pd.DataFrame(values, columns=columns)
        df['GEOFIPS'] = df['state'] + df['county'] + df['tract']
        df = df[['GEOFIPS', columns[0]]]
        df[columns[0]] = df[columns[0]].astype(float)
        return df

    def get_census_variable_df(self, census_variable_str, subject=True):
        census_variable = CENSUS_VARIABLES[census_variable_str]
        query = '{}/{}/{}?get={}&{}&key={}'.format(self.census_api_base, self.year,
                                                   self.dataset, census_variable,
                                                   self.geography, self.api_key)
        if not subject:
            query = query.replace('subject', '')

        response = requests.get(query)
        df = self.api_response_to_df(response=response)
        df.columns = ['GEOFIPS', census_variable_str]
        return df

    def get_census_variable_array(self, census_variable):
        return self.get_census_variable_df(census_variable)[census_variable].values

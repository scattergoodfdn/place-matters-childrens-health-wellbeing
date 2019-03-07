from src.data.census import CensusAPICall
from src.data.utils import (
    get_phila_tracts, get_phila_districts, join_polygon_to_polygon)


class Overlay(object):

    def __init__(self):
        self.census_api = CensusAPICall()
        self.districts = get_phila_districts()

        tracts = get_phila_tracts()
        x = join_polygon_to_polygon(tracts, self.districts)
        self.tracts = x[['GEOFIPS', 'DISTRICT', 'geometry']]

    def __population__(self):
        return self.census_api.get_census_variable_df('population')

    def get_tract_data_geo(self):
        return self.tracts

    def get_district_data_geo(self):
        return self.districts

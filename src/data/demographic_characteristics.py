import os
import requests

import pandas as pd
import numpy as np
from functools import reduce

from src.data.overlay import Overlay


class DemographicCharacteristics(Overlay):

    def __percent_children__(self):
        adults = self.census_api.get_census_variable_df('age_18_and_over')
        population = self.__population__()
        people = pd.merge(adults, population)
        people['count_age_18_and_over'] = (people['age_18_and_over'] / 100) * people['population']
        people['count_children'] = people['population'] - people['count_age_18_and_over']
        children = people.drop('age_18_and_over', axis=1)
        df = pd.merge(self.tracts, children) \
            .drop(['GEOFIPS', 'geometry'], axis=1) \
            .groupby('DISTRICT') \
            .sum() \
            .reset_index()
        df['pct_children'] = df['count_children'] / df['population']
        return df

    def __percent_foreign_born__(self):
        foreign_born = self.census_api.get_census_variable_df(
            'foreign_born', False)
        foreign_born['count_foreign_born'] = foreign_born['foreign_born']
        foreign_born = foreign_born.drop('foreign_born', axis=1)
        population = self.__population__()
        pct_foreign_born = pd.merge(population, foreign_born)
        df = pd.merge(self.tracts, pct_foreign_born) \
            .drop(['GEOFIPS', 'geometry'], axis=1) \
            .groupby('DISTRICT') \
            .sum() \
            .reset_index()
        df['pct_foreign_born'] = df[
            'count_foreign_born'] / df['population']
        df = df \
            .drop('population', axis=1)
        return df

    def __majority_race__(self):
        african_american = self.census_api.get_census_variable_df(
            'african_american', False)
        white = self.census_api.get_census_variable_df('white', False)
        asian = self.census_api.get_census_variable_df('asian', False)
        races = reduce(lambda x, y: pd.merge(x, y), [
                       self.tracts, african_american, asian, white])
        races = races.drop(['geometry', 'GEOFIPS'], axis=1) \
            .groupby('DISTRICT') \
            .sum() \
            .reset_index()
        l = []
        for i, r in races.iterrows():
            race = 'white'
            if r['asian'] > r[race]:
                race = 'asian'
            if r['african_american'] > r[race]:
                race = 'african_american'
            l.append([r['DISTRICT'], race])
        df = pd.DataFrame(l, columns=['DISTRICT', 'majority_race'])
        df = pd.merge(df, races)
        return df

    def __majority_foreign_language__(self):
        speaks_english = self.census_api.get_census_variable_df(
            'speaks_only_english', False)
        speaks_english['count_speaks_only_english'] = speaks_english['speaks_only_english']
        speaks_english = speaks_english.drop('speaks_only_english', axis=1)
        population = self.__population__()
        df = reduce(lambda x, y: pd.merge(x, y), [self.tracts, speaks_english, population]) \
            .drop(['GEOFIPS', 'geometry'], axis=1) \
            .groupby('DISTRICT') \
            .sum() \
            .reset_index()
        df['pct_speaks_only_english'] = df[
            'count_speaks_only_english'] / df['population']
        df = df[['DISTRICT', 'pct_speaks_only_english', 'count_speaks_only_english']]
        return df

    def generate_demographic_characteristics_csv(self):
        pct_children = self.__percent_children__()
        pct_foreign_born = self.__percent_foreign_born__()
        majority_race = self.__majority_race__()
        majority_foreign_language = self.__majority_foreign_language__()
        dfs = [pct_children, pct_foreign_born,
               majority_race, majority_foreign_language]
        demographic_characteristics = reduce(lambda x, y: pd.merge(x, y), dfs)
        demographic_characteristics.to_csv(
            'data/interim/selected_demographic_characteristics.csv')

    def run(self):
        self.generate_demographic_characteristics_csv()


def demographic_characteristics():
    dc = DemographicCharacteristics()
    dc.run()

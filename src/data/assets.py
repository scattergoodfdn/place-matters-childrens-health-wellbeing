import os
import subprocess
import rasterio
import numpy as np
import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt

from functools import reduce
from shapely.geometry import Point
from rasterio.plot import show
from rasterstats import zonal_stats, zonal_stats
from rasterio.transform import from_bounds
from sklearn.neighbors import KernelDensity

from src.utils import write_file
from src.data.overlay import Overlay
from src.data.census import CensusAPICall
from src.data.area_weighted_join import area_weighted_join
from src.data.utils import (query_phila_carto, get_phila_tracts, get_phila_zipcodes,
                            get_phila_districts, array_to_percentiles,
                            join_polygon_to_polygon, geodataframe_from_url,
                            get_rebuild_sites)


class AssetOverlay(Overlay):

    def __benefits__(self):
        not_snap_hh = self.census_api.get_census_variable_df('not_snap_households')
        snap_hh = self.census_api.get_census_variable_df('snap_households')
        snap_pai = pd.merge(not_snap_hh, snap_hh, on='GEOFIPS')
        snap_pai['total_snap'] = snap_pai['snap_households'] + snap_pai['not_snap_households']
        snap_pai['benefits'] = snap_pai['snap_households'] / snap_pai['total_snap']
        snap_pai.to_csv('snap_pai.csv')
        return snap_pai[['GEOFIPS', 'benefits']]

    def __behavioural__(self):
        zipcodes = get_phila_zipcodes()
        usage_uri = 'data/raw/behavioural_health_usage_by_zipcode.csv'
        usage = pd.read_csv(usage_uri)[['ZIPCODE', 'usage']]
        zipcodes_with_usage = pd.merge(zipcodes, usage)
        tracts = get_phila_tracts()
        x = area_weighted_join(zipcodes_with_usage, 'ZIPCODE',
                               tracts, 'GEOFIPS', 'usage', True) \
            .rename(index=str, columns={'usage': 'behavioural'})
        return x[['GEOFIPS', 'behavioural']]

    def __food__(self):
        WALKABLE_ACCESS_TO_HEALTHY_FOOD = 'http://data.phl.opendata.arcgis.com/datasets/4748c96b9db444a48de1ae38ca93f554_0.geojson'
        food_access_blocks = \
            geodataframe_from_url(WALKABLE_ACCESS_TO_HEALTHY_FOOD)

        # scale food access scores 0-3
        access_levels = ['No Access', 'Low Access',
                         'Moderate Access', 'High Access']
        food_access_blocks['score'] = food_access_blocks \
            .apply(lambda row: access_levels.index(row.ACCESS_), axis=1)

        # spatial join census blocks to tracts
        food_access_blocks.geometry = food_access_blocks.geometry.centroid
        phila_tracts = get_phila_tracts()
        food_access_tracts = gpd.sjoin(
            phila_tracts, food_access_blocks, how="inner", op='contains')

        # aggregate scores to census tract
        score_agg_by_tract = food_access_tracts['score'] \
            .groupby(food_access_tracts['GEOFIPS']) \
            .mean() \
            .reset_index()
        score_agg_by_tract = score_agg_by_tract \
            .rename(index=str, columns={"score": "food"})

        return score_agg_by_tract

    def __parks__(self):
        # get rec assets from url
        PARKS_ASSETS = 'http://data.phl.opendata.arcgis.com/datasets/4df9250e3d624ea090718e56a9018694_0.geojson'
        parks_assets = geodataframe_from_url(PARKS_ASSETS)

        # get rebuild sites
        rebuild_libs_gdf = get_rebuild_sites()
        parks_assets = parks_assets.append(rebuild_libs_gdf)


        # mark park sites that are rebuild
        rebuild_site_ids = [r['SITE_NAME']
                            for i, r in rebuild_libs_gdf.iterrows()]
        parks_assets['rebuild_sites'] = parks_assets[
            'SITE_NAME'].apply(lambda x: int(x in rebuild_site_ids))


        # dissolve asset data to sites
        parks_sites = parks_assets.dissolve(by='SITE_NAME').reset_index()

        # calc zonal stats
        def get_zs(lon, lat, array, poly):

            xmin, ymin, xmax, ymax = [
                lon.min(), lat.min(), lon.max(), lat.max()]
            nrows, ncols = np.shape(array)
            xres = (xmax - xmin) / float(ncols)
            yres = (ymax - ymin) / float(nrows)
            affine = from_bounds(xmin, ymin, xmax, ymax, ncols, nrows)
            zs = zonal_stats(poly, array, affine=affine, stats=['mean'])
            return zs[0]['mean']

        # calc kernel density
        def calc_kernel_density(series, flag):
            latlon = series['geometry'].centroid
            latlon = latlon.to_crs(epsg=4326)
            lats = [i.y for i in latlon]
            lons = [i.x for i in latlon]
            rebuild = np.array(
                [d for d in series['rebuild_sites']], dtype='int')
            nx = 1000
            ny = 1000
            xgrid = np.linspace(min(lons), max(lons), nx)
            ygrid = np.linspace(min(lats), max(lats), nx)
            X, Y = np.meshgrid(xgrid[::5], ygrid[::5][::-1])
            xy = np.vstack([Y.ravel(), X.ravel()]).T

            if flag == True:
                latlon = latlon[rebuild == 1]

            kde = KernelDensity(bandwidth=0.003, metric='haversine')
            kde.fit([[p.y, p.x] for p in latlon])

            Z = np.full(X.shape[0], 0)
            Z = np.exp(kde.score_samples(xy))
            Z = Z.reshape(X.shape)
            return (X, Y, Z)

        tracts = get_phila_tracts()
        tracts = tracts.to_crs({'init': 'epsg:4326'})


        # rebuild sites kernel density estimate
        rskde = calc_kernel_density(parks_sites, True)
        tracts['rskde'] = tracts['geometry'].apply(
            lambda p: get_zs(rskde[0], rskde[1], rskde[2], p))

        # park assets kernel density esitmate
        pakde = calc_kernel_density(parks_assets, False)
        tracts['akde'] = tracts['geometry'].apply(
            lambda p: get_zs(pakde[0], pakde[1], pakde[2], p))

        # merge parks and rebuild gdfs
        tracts['parks'] = tracts.apply(lambda row: (
            row['rskde'] + row['akde']) / 2, axis=1)

        return tracts[['GEOFIPS', 'parks']]

    def __schools__(self):
        # get tract spatial data
        tracts = get_phila_tracts()

        # get school performance data
        SCHOOL_PERFORMANCE_XLSX = 'data/raw/SPR_SY1617_School_Metric_Scores_20180118.xlsx'
        school_performance = pd.read_excel(SCHOOL_PERFORMANCE_XLSX, 1)
        school_performance['id'] = school_performance['SRC School ID'] \
            .astype(str)
        school_performance_scores = school_performance[['Student Survey Climate Score', 'Overall Score']] \
            .apply(pd.to_numeric, errors='coerce')
        school_performance['score'] = school_performance_scores.mean(axis=1)
        school_performance = school_performance[['id', 'score']]

        # download and unzip school catchment shapefiles
        SCHOOL_CATCHMENTS_ZIP = 'https://cdn.philasd.org/offices/performance/Open_Data/School_Information/School_Catchment/SDP_Catchment_1718.zip'
        zipfile_dir = 'data/raw/'
        zipfile = 'catchments.zip'
        zipfile_uri = os.path.join(zipfile_dir, zipfile)

        if not os.path.isfile(zipfile_uri):
            subprocess.call(['wget', SCHOOL_CATCHMENTS_ZIP, '-O', zipfile_uri])
            subprocess.call(['unzip', zipfile_uri, '-d', zipfile_dir])

        def __get_tract_scores_for_school_level__(school_level):
            shp_dir = 'Catchment_{}_2017-18'.format(school_level)
            shp = 'Catchment_{}_2017.shp'.format(school_level)
            catchments_uri = os.path.join(zipfile_dir, shp_dir, shp)
            catchments = gpd.read_file(catchments_uri)
            catchments['id'] = catchments['{}_ID'.format(school_level)] \
                .str[:3].astype(str)
            catchments = catchments[['id', 'geometry']]
            catchments_with_scores = pd.merge(
                catchments, school_performance, how='inner')
            x = area_weighted_join(
                catchments_with_scores, 'id', tracts, 'GEOFIPS', 'score', True)
            score_field = 'score_{}'.format(school_level)
            x[score_field] = x['score']
            return x[['GEOFIPS', score_field]]

        print('Gathering elementary school performance data...')
        elementary = __get_tract_scores_for_school_level__('ES')
        print('Gathering middle school performance data...')
        middle = __get_tract_scores_for_school_level__('MS')
        print('Gathering high school performance data...')
        high = __get_tract_scores_for_school_level__('HS')

        for i in [elementary, middle, high]:
            tracts = tracts.merge(i, how='left')
        tracts['score'] = tracts[
            ['score_ES', 'score_MS', 'score_HS']].mean(axis=1)

        tracts = tracts.rename(index=str, columns={"score": "schools"})
        return tracts[['GEOFIPS', 'schools']]

    def get_asset_data(self):
        return self.asset_data

    def calculate_asset_score(self):
        # population
        population = self.__population__()

        # asset layers
        benefits = self.__benefits__()
        behavioural = self.__behavioural__()
        food = self.__food__()
        parks = self.__parks__()
        schools = self.__schools__()

        df_list = [population, behavioural, food, schools, benefits, parks]
        self.asset_data = reduce(
            lambda x, y: pd.merge(x, y, how='left'), df_list)
        self.asset_data = self.asset_data[self.asset_data['population'] > 5]
        overlay_variables = ['behavioural',
                             'food', 'schools', 'benefits', 'parks']

        for v in overlay_variables:
            self.asset_data[v] = array_to_percentiles(self.asset_data[v])
        self.asset_data['asset'] = self.asset_data[
            overlay_variables].mean(axis=1)


def asset_overlay():
    a = AssetOverlay()
    a.calculate_asset_score()

    tracts = a.get_tract_data_geo()
    districts = a.get_district_data_geo()
    asset_data = a.get_asset_data()

    # merge tracts with asset data
    asset_tracts_geo = pd.merge(tracts, asset_data, how='left')
    write_file(asset_tracts_geo, 'asset_tracts')

    # aggregate to district
    district_asset = asset_tracts_geo.drop(['geometry', 'GEOFIPS', 'population', 'asset'], axis=1) \
        .groupby('DISTRICT') \
        .mean() \
        .reset_index()

    # merge with district gdf
    districts_with_asset = pd.merge(districts, district_asset)
    districts_with_asset = districts_with_asset \
        .drop(['OBJECTID', 'ID'], axis=1)

    # recalculate the overall asset score
    asset_columns = districts_with_asset[
        ['behavioural', 'food', 'schools', 'benefits', 'parks']]
    districts_with_asset['asset'] = asset_columns.mean(axis=1)

    write_file(districts_with_asset, 'asset_districts')

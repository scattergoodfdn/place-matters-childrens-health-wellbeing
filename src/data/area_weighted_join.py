"""
Spatially join misaligned polygons
"""

import os
import argparse
import numpy as np
import geopandas as gpd
import pandas as pd


def area_weighted_join(source_gdf, source_uuid, target_gdf, target_uuid,
                       variable, rate):

    if source_gdf.crs != target_gdf.crs:
        target_gdf = target_gdf.to_crs(source_gdf.crs)

    if source_uuid not in source_gdf.columns:
        print('The UUID is not present in source geographies.')
    elif target_uuid not in target_gdf.columns:
        print('The UUID is not present in target geographies.')
    elif variable not in source_gdf.columns:
        print('The variable is not present in target geographies.')
    else:
        uuids = source_gdf[source_uuid]
        areas = source_gdf['geometry'].area
        source_areas = dict(zip(uuids, areas))

        union = gpd.overlay(target_gdf, source_gdf, how='union')
        proportions = {}
        for k, v in union.iterrows():
            if v[source_uuid] in source_areas.keys():
                prop_value = v['geometry'].area / \
                    source_areas[v[source_uuid]]
                prop_key = (v[target_uuid], v[source_uuid])
                proportions[prop_key] = prop_value
        fields = [source_uuid, target_uuid, variable]
        union = pd.DataFrame(union)[fields]
        union = union.dropna(subset=[source_uuid])
        union['proportion'] = union.apply(
            lambda x: proportions[(x[1], x[0])], 1)

        def __calc_proportion__(value, proportion):
            if not value:
                return None
            if value == 'None':
                return None
            else:
                return float(value) * proportion

        union['value'] = union.apply(
            lambda x: __calc_proportion__(x[2], x[3]), 1)
        union = union[[target_uuid, 'value', 'proportion']]
        proportional_results = union.groupby(
            [target_uuid]).sum().reset_index()
        if rate:
            proportional_results[variable] = proportional_results[
                'value'] / proportional_results['proportion']
        else:
            proportional_results[variable] = proportional_results['value']
        proportional_results = proportional_results[[target_uuid, variable]]

        aggregated = pd.merge(target_gdf, proportional_results, on=target_uuid)
        return aggregated

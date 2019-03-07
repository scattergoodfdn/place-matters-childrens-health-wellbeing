import os
import json

import pandas as pd
import numpy as np

def get_rank_column(df, value_column, ascending=False):
	df = df.sort_values(by=value_column, ascending=ascending) 
	rank_column = value_column + '_rank'
	df.insert(0, rank_column, range(1, len(df) + 1))
	return df

def load_base_json():
	with open('data/interim/json_files/base_json.json') as f:
		data = json.load(f)
	return data

def get_df(file_uri):
		try:
			df = pd.read_csv(file_uri)
		except:
			raise Exception('invalid formatting in {}, change file encoding to utf-8 or delete non utf-8 characters in file.'.format(file_uri))
		return df


def district_no_to_dict(district_no):
	# load base json
	data = load_base_json()
	d = data['district']

	def get_rank(file_uri, field, district_no):
		# define ordinal function
		ordinal = lambda n: "%d%s" % (n,"tsnrhtdd"[(n/10%10!=1)*(n%10<4)*n%10::4])
		df = get_df(file_uri)
		df = get_rank_column(df, field)
		df_district = df[df['DISTRICT'] == district_no] \
			.reset_index()
		return ordinal(df_district[field + '_rank'][0])

	def get_value(file_uri, field, district_no, decimal_places=1, decimal_to_pct=False):
		df = get_df(file_uri)
		df_district = df[df['DISTRICT'] == district_no] \
			.reset_index()
		val = df_district[field][0]
		if isinstance(val, (int, float)):
			val = round(val, decimal_places)
		if isinstance(val, str):
			val = val.replace('_',' ').title()
		if decimal_to_pct:
			val = round(val * 100, 1)
		return val

	def get_tract_stat(file_uri, field, district_no, stat):
		df = get_df(file_uri)
		df_district = df[df['DISTRICT'] == district_no] \
			.reset_index()
		if stat == 'min':
			val = np.min(df_district[field])
		elif stat == 'max':
			val = np.max(df_district[field])
		else:
			print('"stat" parameter must be one of "min" or "max"')
			return None
		return round(val, 1)

	# define uris
	risk_districts = 'data/interim/risk_districts.csv'
	asset_districts = 'data/interim/asset_districts.csv'
	asset_tracts = 'data/interim/asset_tracts.csv'
	cumulative_districts = 'data/interim/cumulative_districts.csv'
	selected_demographic_characteristics = 'data/interim/selected_demographic_characteristics.csv'

	# get risk and asset ranks and cumulative score
	d['risk_rank'] = get_rank(risk_districts, 'risk', district_no)
	d['asset_rank'] =  get_rank(asset_districts, 'asset', district_no)
	d['overall_score'] = get_value(cumulative_districts, 'cumulative', district_no)
	d['overall_rank'] = get_rank(cumulative_districts, 'cumulative', district_no)

	# selected demographic characteristics
	d['majority_race'] = get_value(selected_demographic_characteristics, 'majority_race', district_no)
	d['pct_english_speaking'] = get_value(selected_demographic_characteristics, 'pct_speaks_only_english', district_no, 3, True)
	d['pct_children'] = get_value(selected_demographic_characteristics, 'pct_children', district_no, 3, True)
	d['pct_foreign_born'] = get_value(selected_demographic_characteristics, 'pct_foreign_born', district_no, 3, True)

	# asset characteristics
	d['snap_utilization_col1'] = get_tract_stat(asset_tracts, 'benefits', district_no, 'min')
	d['snap_utilization_col2'] = get_tract_stat(asset_tracts, 'benefits', district_no, 'max')
	d['school_qual_col1'] = get_tract_stat(asset_tracts, 'schools', district_no, 'min')
	d['school_qual_col2'] = get_tract_stat(asset_tracts, 'schools', district_no, 'max')
	d['park_rec_access_col1'] = get_tract_stat(asset_tracts, 'parks', district_no, 'min')
	d['park_rec_access_col2'] = get_tract_stat(asset_tracts, 'parks', district_no, 'max')
	d['walk_food_access_col1'] = get_tract_stat(asset_tracts, 'food', district_no, 'min')
	d['walk_food_access_col2'] = get_tract_stat(asset_tracts, 'food', district_no, 'max')
	d['behavioral_health_utilization_col1'] = get_tract_stat(asset_tracts, 'behavioural', district_no, 'min')
	d['behavioral_health_utilization_col2'] = get_tract_stat(asset_tracts, 'behavioural', district_no, 'max')

	# text fields
	text = get_df('data/interim/json_files/base_district_text.csv')
	district_text = text[text['district'] == district_no] \
		.reset_index()
	text_fields = ['profile_p1', 'profile_p2', 'risk_summary', 'asset_summary','key_takeaway']
	for tf in text_fields:
		d[tf] = district_text[tf][0]

	return d

def generate_city_dict():
	data = load_base_json()
	c = data['city']
	
	# pull text from csv
	df = get_df('data/interim/json_files/base_city_text.csv')
	text_fields = ['top_summary_1', 'top_summary_2', 'second_summary', 'key_takeaway']
	for tf in text_fields:
		c[tf] = df[tf][0]

	return c

def generate_json_for_flask():
	DISTRICTS = [1,2,3,4,5,6,7,8,9,10]
	all_districts = {}
	
	# generate dicts for each district
	for district in DISTRICTS:
		key = 'district{}'.format(district)
		all_districts[key] = district_no_to_dict(district)
	
	# generate city dict
	all_districts['city'] = generate_city_dict()

	# write to data.json in flask app static directory
	with open('flask-app/static/data.json', 'w') as fp:
		json.dump(all_districts, fp)

def main():
    generate_json_for_flask()

if __name__ == '__main__':
	main()
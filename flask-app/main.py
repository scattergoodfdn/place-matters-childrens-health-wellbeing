from flask import Flask, render_template, make_response, url_for, request
from flaskext.markdown import Markdown
import json


app = Flask(__name__)
Markdown(app)

@app.route('/')
@app.route('/help')
def help():
	return render_template('help.html')


@app.route('/dev/report1/district<id>')
def district_report1( id ):
	
	overall =  "district_{}_overall.svg".format(id)
	profile =  "district_{}_profile.svg".format(id)
	locator =  "district_{}_locator.png".format(id)
	life_exp =  "district_{}_life_exp_barchart.svg".format(id)
	social_mob =  "district_{}_social_mobility_barchart.svg".format(id)

	with open('static/data.json') as f:
		data = json.load(f)
		district_data = data['district{}'.format(id)]
		city_data = data['city']


	return render_template('report1.html', 	name=id,
											overall_impath=overall,
											profile_impath=profile, 
											locator_impath=locator,
											life_exp_impath=life_exp,
											social_mob_impath=social_mob,
											district_data=district_data,
											city_data=city_data
											)


@app.route('/dev/report2/district<id>')
def district_report2( id ):
	
	assetbar =  "district_{}_asset_barchart.svg".format(id)
	riskbar =  "district_{}_risk_barchart.svg".format(id)
	asset =  "district_{}_asset.svg".format(id)
	risk =  "district_{}_risk.svg".format(id)

	benefits_table_barchart = "district_{}_benefits_table_barchart.svg".format(id)
	schools_table_barchart = "district_{}_schools_table_barchart.svg".format(id)
	parks_table_barchart = "district_{}_parks_table_barchart.svg".format(id)
	food_table_barchart = "district_{}_food_table_barchart.svg".format(id)
	behavioural_table_barchart = "district_{}_behavioural_table_barchart.svg".format(id)

	with open('static/data.json') as f:
		data = json.load(f)
		district_data = data['district{}'.format(id)]
		city_data = data['city']

	return render_template('report2.html', 	name=id,
											asset_impath=asset, 
											risk_impath=risk,
											assetbar_impath=assetbar, 
											riskbar_impath=riskbar,
											district_data=district_data,
											city_data=city_data,
											benefits_tbc_impath = benefits_table_barchart,
											schools_tbc_impath = schools_table_barchart, 
											parks_tbc_impath = parks_table_barchart,
											food_tbc_impath = food_table_barchart, 
											behavioural_tbc_impath = behavioural_table_barchart 
											)


@app.route('/dev/city')
def city(name=None):

	with open('static/data.json') as f:
		data = json.load(f)
		city_data = data['city']

	return render_template('city.html', city_data=city_data )
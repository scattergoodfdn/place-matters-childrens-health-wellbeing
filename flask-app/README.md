Flask App for Generating Reports
==============================

A lightweight Python http/html server with jinja templates. 

#### Setup (will add to docker setup file): 

standard add start variable to your path

`export FLASK_APP=main.py`

run these for getting flavor of flask working in the environment used in the docker container 

`export LC_ALL=C.UTF-8`

`export LANG=C.UTF-8`


Running 
------------

our dockerfile exposes port 8888, specify that otherwise flask defaults to port 5000 

`flask run --host=0.0.0.0 --port=8888`


navigate in browser to `http://localhost:8888/`


Flask App File Structure
------------

    ├── README.md
    ├── static             <- standard flask convention
    │   ├── css            
    │   ├── images           
    │   └── plots
    │
    ├── templates          <- standard flask convention
    │   ├── report1.html
    │   ├── report2.html
    │   ├── city.html
    │   └── help.html   
    │
    └── main.py            <- contains url routes & functions


URL Routes
------------

`/` `/help` --> landing/help/man page

`/dev/city`   --> serves up city.html

`/dev/report1/districtX`   ---> serves up report1.html

`/dev/report2/districtX`   ---> serves up report2.html


##### Report Generation:

When ready to generate a report, we recommend using a headless browser to produce a pdf. The url accessed by the headless browser will be the flask app running on localhost on your machine. Here we provide a command line tool that uses Puppeteer, a headless version of Google Chrome. Note: These steps should be run on your local machine.

Make sure node and npm are installed on your machine (https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)

Install this node package 

`npm i puppeteer-cli` (https://www.npmjs.com/package/puppeteer-cli)

Generate a report when the flask server is running

`$ puppeteer print --margin-top 0 --margin-bottom 0 --margin-right 0 --margin-left 0 http://localhost:8888/dev/reportX/districtX file.pdf`

Alternative to removing blank 2nd page of pdf with pdftk (https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/)

`puppeteer print --margin-top 0 --margin-bottom 0 --margin-right 0 --margin-left 0 http://localhost:8888/dev/reportX/districtX tmp.pdf && pdftk tmp.pdf cat 1-r2 output reportXdistrictX.pdf`



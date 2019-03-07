from src.data.risks import risk_overlay
from src.data.assets import asset_overlay
from src.data.social_mobility import social_mobility
from src.data.life_expectancy import life_expectancy
from src.data.demographic_characteristics import demographic_characteristics
from src.analysis.cumulative_score import cumulative_scores
from src.visualization.generate_json import generate_json_for_flask
from src.visualization.generate_plots import generate_plots

def main():
    risk_overlay()
    asset_overlay()
    cumulative_scores()
    social_mobility()
    life_expectancy()
    demographic_characteristics()
    generate_json_for_flask()

if __name__ == '__main__':
    main()

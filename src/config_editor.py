import os
import configparser
from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)
config_path = os.path.join(os.path.dirname(__file__), '../conf/gnirsdc/config.ini')
config = configparser.ConfigParser()
config.read(config_path)

@app.route('/')
def index():
    config.read(config_path)
    # Create a dictionary to hold both DEFAULT and DEBUG sections with uppercase keys
    sections_dict = {
        'DEFAULT': {k.upper(): v for k, v in config.defaults().items()},
        'DEBUG': {k.upper(): v for k, v in config['DEBUG'].items()}
    }
    return render_template('config_editor.html', sections=sections_dict)

@app.route('/save', methods=['POST'])
def save():
    for section in ['DEFAULT', 'DEBUG']:
        if section not in config:
            config[section] = {}
        for key, value in request.form.items():
            if key.startswith(f"{section}_"):
                _, actual_key = key.split('_', 1)
                config[section][actual_key] = value
    with open(config_path, 'w') as configfile:
        config.write(configfile)
    return redirect(url_for('index'))

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)

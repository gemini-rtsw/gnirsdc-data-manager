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
    return render_template('config_editor.html', config=config)

@app.route('/save', methods=['POST'])
def save():
    for section in config.sections():
        for key in config[section]:
            config[section][key] = request.form.get(f"{section}_{key}", config[section][key])
    with open(config_path, 'w') as configfile:
        config.write(configfile)
    return redirect(url_for('index'))

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)

import os
import configparser
from flask import Flask, render_template, request, redirect, url_for

class AlignedCasePreservingConfigParser(configparser.ConfigParser):
    def optionxform(self, optionstr):
        return optionstr

    def write(self, fp, space_around_delimiters=True):
        if space_around_delimiters:
            d = " = "
        else:
            d = "="
        for section in self._sections:
            fp.write(f"[{section}]\n")
            for (key, value) in self._sections[section].items():
                if key != "__name__":
                    fp.write(f"{key:<20}{d}{value}\n")
            fp.write("\n")

app = Flask(__name__)
config_path = os.path.join(os.path.dirname(__file__), '../conf/gnirsdc/config.ini')
config = AlignedCasePreservingConfigParser()
config.read(config_path)

@app.route('/')
def index():
    config.read(config_path)
    # Create a dictionary to hold both DEFAULT and DEBUG sections
    sections_dict = {
        'DEFAULT': dict(config.defaults()),
        'DEBUG': dict(config['DEBUG'])
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

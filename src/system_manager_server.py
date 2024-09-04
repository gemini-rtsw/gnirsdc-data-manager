import os
import configparser
from flask import Flask, render_template, request, redirect, url_for, send_file
import datetime

class AlignedCasePreservingConfigParser(configparser.ConfigParser):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.optionxform = str  # This preserves the case

    def write(self, fp, space_around_delimiters=True):
        if space_around_delimiters:
            d = " = "
        else:
            d = "="
        if self._defaults:
            fp.write("[DEFAULT]\n")
            for (key, value) in self._defaults.items():
                fp.write(f"{key:<20}{d}{value}\n")
            fp.write("\n")
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
    return redirect(url_for('monitoring'))

@app.route('/config')
def config_page():  # Renamed from 'config' to 'config_page'
    config.read(config_path)
    # Create a dictionary to hold both DEFAULT and DEBUG sections
    sections_dict = {
        'DEFAULT': dict(config.defaults()),
        'DEBUG': dict(config['DEBUG'])
    }
    return render_template('config_editor.html', active_tab='config', sections=sections_dict)

@app.route('/monitoring')
def monitoring():
    return render_template('monitoring.html', active_tab='monitoring')

@app.route('/logs')
def logs():
    log_dir = '/readout_data/logs'
    log_files = os.listdir(log_dir)
    return render_template('logs.html', active_tab='logs', log_files=log_files)

@app.route('/logs/<filename>')
def view_log(filename):
    log_dir = '/readout_data/logs'
    log_path = os.path.join(log_dir, filename)
    if os.path.isfile(log_path):
        return send_file(log_path, mimetype='text/plain')
    else:
        return "Log file not found", 404

@app.route('/save', methods=['POST'])
def save():
    for section in ['DEFAULT', 'DEBUG']:
        if section == 'DEFAULT':
            config.defaults().clear()
        elif section not in config:
            config[section] = {}
        for key, value in request.form.items():
            if key.startswith(f"{section}_"):
                _, actual_key = key.split('_', 1)
                if section == 'DEFAULT':
                    config.defaults()[actual_key] = value
                else:
                    config[section][actual_key] = value
    with open(config_path, 'w') as configfile:
        config.write(configfile)
    return redirect(url_for('index'))

@app.route('/fits')
def fits_files():
    staging_dir = '/staging/perm'
    readout_dir = '/readout_data/fits'
    
    all_files = []
    
    # Check and add files from staging directory if it exists
    if os.path.exists(staging_dir):
        staging_files = [os.path.join('staging', f) for f in os.listdir(staging_dir) if f.endswith('.fits')]
        all_files.extend(staging_files)
    
    # Check and add files from readout directory if it exists
    if os.path.exists(readout_dir):
        readout_files = [os.path.join('readout', f) for f in os.listdir(readout_dir) if f.endswith('.fits')]
        all_files.extend(readout_files)
    
    # Create a list of dictionaries containing file information
    files_info = []
    for f in all_files:
        full_path = os.path.join('/staging/perm' if f.startswith('staging') else '/readout_data/fits', os.path.basename(f))
        stat = os.stat(full_path)
        files_info.append({
            'display_path': f,
            'full_path': full_path,
            'size': stat.st_size,
            'mtime': datetime.datetime.fromtimestamp(stat.st_mtime)
        })
    
    # Sort files by modification time
    files_info.sort(key=lambda x: x['mtime'], reverse=True)
    
    return render_template('fits_files.html', active_tab='fits', fits_files=files_info)

@app.route('/fits/<path:filename>')
def view_fits(filename):
    if filename.startswith('staging/'):
        file_path = os.path.join('/staging/perm', os.path.basename(filename))
    elif filename.startswith('readout/'):
        file_path = os.path.join('/readout_data/fits', os.path.basename(filename))
    else:
        return "File not found", 404

    if os.path.isfile(file_path):
        return send_file(file_path, mimetype='application/fits')
    else:
        return "FITS file not found", 404

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)

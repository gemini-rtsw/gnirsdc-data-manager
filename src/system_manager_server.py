import os
import sys

# Set the working directory to the script's directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

import configparser
from flask import Flask, render_template, request, redirect, url_for, send_file, jsonify, Response, send_from_directory
import datetime
from caproto.threading.client import Context
from caproto import SubscriptionType, ChannelType
import asyncio
import threading
import time
import logging
import argparse
import json
import caproto
from epics import caput, caget
from astropy.io import fits
from queue import Queue
import subprocess
import markdown2
import paramiko
import numpy as np
import io
import matplotlib.pyplot as plt

# Set up logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

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

app = Flask(__name__, static_folder='static')
config_path = '../conf/gnirsdc/config.ini'
config = AlignedCasePreservingConfigParser()
config.read(config_path)

# Create a caproto context
ctx = Context()

# Global variables
log_messages = []
MAX_LOG_MESSAGES = 100
clients = set()
clients_lock = threading.Lock()

# SSH configuration
SSH_HOST = 'localhost'  # Since we're using --network=host, localhost refers to the host machine
SSH_PORT = 22
SSH_USERNAME = 'telops'
SSH_KEY_FILE = os.path.expanduser('~/.ssh/id_rsa')

def run_ssh_command(command):
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SSH_HOST, port=SSH_PORT, username=SSH_USERNAME, key_filename=SSH_KEY_FILE)
        
        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')
        
        ssh.close()
        
        return output, error
    except Exception as e:
        logger.error(f"Error executing SSH command: {str(e)}")
        raise

def pv_handler(sub, response):
    global log_messages
    value = response.data[0]
    if isinstance(value, bytes):
        value = value.decode('utf-8')
    
    logger.debug(f"Raw PV value received: {value}")
    
    log_entry = {"status": "connected", "value": value}
    log_messages.append(log_entry)
    log_messages = log_messages[-MAX_LOG_MESSAGES:]
    logger.debug(f"Added log entry: {log_entry}")
    
    # Notify all clients
    with clients_lock:
        for client_queue in clients:
            client_queue.put(json.dumps(log_messages))

def subscribe_to_pv():
    global config_mode
    pv_name = f"{config[config_mode].get('DEFAULT_PREFIX', 'nirs')}:log_message"
    logger.info(f"Subscribing to PV: {pv_name}")
    
    while True:
        try:
            pv, = ctx.get_pvs(pv_name)
            sub = pv.subscribe(data_type='time')
            sub.add_callback(pv_handler)
            logger.info(f"Successfully subscribed to PV: {pv_name}")
            return sub
        except Exception as e:
            logger.error(f"Error subscribing to PV {pv_name}: {str(e)}")
            time.sleep(5)  # Wait before retrying

def run_subscription():
    subscribe_to_pv()
    while True:
        time.sleep(1)  # Keep the thread alive

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
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    debug_mode = config_mode == 'DEBUG'
    return render_template('monitoring.html', active_tab='monitoring', debug_mode=debug_mode)

@app.route('/get_log_messages')
def get_log_messages():
    return jsonify([{
        "status": entry["status"],
        "value": entry["value"]
    } for entry in log_messages])

@app.route('/logs')
def logs():
    log_dir = config[config_mode].get('LOG_DIR', '/readout_data/logs')
    log_files = os.listdir(log_dir)
    return render_template('logs.html', active_tab='logs', log_files=log_files)

@app.route('/logs/<filename>')
def view_log(filename):
    log_dir = config[config_mode].get('LOG_DIR', '/readout_data/logs')
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
    staging_dir = config[config_mode].get('STAGING_DIR', '/staging/perm')
    readout_dir = config[config_mode].get('READOUT_DIR', '/readout_data/fits')
    
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
        full_path = os.path.join(staging_dir if f.startswith('staging') else readout_dir, os.path.basename(f))
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
    staging_dir = config[config_mode].get('STAGING_DIR', '/staging/perm')
    readout_dir = config[config_mode].get('READOUT_DIR', '/readout_data/fits')

    if filename.startswith('staging/'):
        file_path = os.path.join(staging_dir, os.path.basename(filename))
    elif filename.startswith('readout/'):
        file_path = os.path.join(readout_dir, os.path.basename(filename))
    else:
        return "File not found", 404

    if os.path.isfile(file_path):
        return send_file(file_path, mimetype='application/fits')
    else:
        return "FITS file not found", 404

@app.route('/fits_header/<path:filename>')
def view_fits_header(filename):
    staging_dir = config[config_mode].get('STAGING_DIR', '/staging/perm')
    readout_dir = config[config_mode].get('READOUT_DIR', '/readout_data/fits')

    if filename.startswith('staging/'):
        file_path = os.path.join(staging_dir, os.path.basename(filename))
    elif filename.startswith('readout/'):
        file_path = os.path.join(readout_dir, os.path.basename(filename))
    else:
        return "File not found", 404

    if os.path.isfile(file_path):
        with fits.open(file_path) as hdul:
            header = hdul[0].header
        
        # Convert header to a string representation, including comments
        header_text = []
        for card in header.cards:
            key = card.keyword
            value = card.value
            comment = card.comment
            if key == 'COMMENT':
                header_text.append(f'COMMENT {value}')
            elif key == 'HISTORY':
                header_text.append(f'HISTORY {value}')
            elif comment:
                header_text.append(f'{key:<8} = {value:<20} / {comment}')
            else:
                header_text.append(f'{key:<8} = {value}')
        
        header_text = '\n'.join(header_text)
        
        return render_template('fits_header.html', filename=filename, header_text=header_text)
    else:
        return "FITS file not found", 404

@app.route('/sse')
def sse():
    def event_stream():
        client_queue = Queue()
        with clients_lock:
            clients.add(client_queue)
        try:
            while True:
                message = client_queue.get()
                yield f"data: {message}\n\n"
        finally:
            with clients_lock:
                clients.remove(client_queue)

    return Response(event_stream(), content_type='text/event-stream')

@app.route('/start_integration', methods=['POST'])
def start_integration():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        caput(f'{top_name}:dc:observe.DIR', "MARK", wait=True)
        caput(f'{top_name}:dc:apply.DIR', "START")
        return jsonify({"status": "success", "message": "Integration started successfully"})
    except Exception as e:
        logger.error(f"Error starting integration: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/set_integration_params', methods=['POST'])
def set_integration_params():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        fowler_num = max(1, int(request.form.get('fowler_num', 1)))
        digital_avgs = max(1, int(request.form.get('digital_avgs', 1)))
        integ_time = float(request.form.get('integ_time', 0))
        file_name = request.form.get('file_name', '')
        coadds = max(1, int(request.form.get('coadds', 1)))

        caput(f'{top_name}:dc:lnrNum', fowler_num, wait=True)
        caput(f'{top_name}:dc:digitalAvgs', digital_avgs, wait=True)
        caput(f'{top_name}:dc:integTime.VAL', integ_time, wait=True)
        caput(f'{top_name}:dc:observe.A', file_name, wait=True)
        caput(f'{top_name}:dc:coadds.VAL', coadds, wait=True)

        return jsonify({
            "status": "success",
            "message": "Integration parameters set successfully",
            "fowler_num": fowler_num,
            "digital_avgs": digital_avgs,
            "coadds": coadds
        })
    except Exception as e:
        logger.error(f"Error setting integration parameters: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/get_heartbeat')
def get_heartbeat():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        heartbeat_value = caget(f'{top_name}:heartbeat')
        return jsonify({"status": "success", "heartbeat": heartbeat_value})
    except Exception as e:
        logger.error(f"Error getting heartbeat value: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/get_all_pvs')
def get_all_pvs():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        detector_bias_str = caget(f'{top_name}:dc:arSetup.H', as_string=True)
        try:
            detector_bias_v = float(detector_bias_str)
            detector_bias_mv = detector_bias_v * 1000  # Convert V to mV
            detector_bias_display = f"{detector_bias_mv:.2f} mV"
            bias_mode = "DEEP" if detector_bias_str == "0.6" else "SHALLOW"
        except ValueError:
            detector_bias_display = "N/A"
            bias_mode = "UNKNOWN"

        pvs = {
            'top_name': top_name,
            'heartbeat': caget(f'{top_name}:heartbeat'),
            'tcs_connection': caget(f'{top_name}:tcs_connection'), 
            'fowler_num': caget(f'{top_name}:dc:lnrNum'),
            'digital_avgs': caget(f'{top_name}:dc:digitalAvgs'),
            'integ_time': caget(f'{top_name}:dc:integTime.VAL'),
            'file_name': caget(f'{top_name}:dc:observe.A'),
            'temperature': caget(f'{top_name}:dc:temperature'),
            'interlock_override': caget(f'{top_name}:dc:disable_interlock'),
            'apply_c_value': caget(f'{top_name}:dc:applyC.VAL'),
            'gmp_status': caget(f'{top_name}:gmp_status'),
            'detector_bias': detector_bias_display,
            'bias_mode': bias_mode,
            'sdsu_state': caget(f'{top_name}:dc:sdsuState', as_string=True),
            'coadds': caget(f'{top_name}:dc:coadds.VAL'),
            'ntp_time': caget(f'{top_name}:ntp_time'),
        }
        return jsonify({"status": "success", "pvs": pvs})
    except Exception as e:
        logger.error(f"Error getting PV values: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/initialize_sdsu', methods=['POST'])
def initialize_sdsu():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        caput(f'{top_name}:dc:initSDSU.DIR', "MARK", wait=True)
        caput(f'{top_name}:dc:apply.DIR', "START")
        return jsonify({"status": "success", "message": "SDSU initialized successfully"})
    except Exception as e:
        logger.error(f"Error initializing SDSU: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/get_file_log')
def get_file_log():
    log_dir = config[config_mode].get('LOG_DIR', '/readout_data/logs')
    log_file = os.path.join(log_dir, 'irdc.log')
    try:
        with open(log_file, 'r') as f:
            return f.read()
    except Exception as e:
        logger.error(f"Error reading log file: {str(e)}")
        return "Error reading log file", 500

@app.route('/engineering')
def engineering():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    interlock_status = caget(f'{top_name}:dc:disable_interlock')
    return render_template('engineering.html', interlock_status=interlock_status)


@app.route('/toggle_interlock', methods=['POST'])
def toggle_interlock():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        current_status = caget(f'{top_name}:dc:disable_interlock')
        new_status = not current_status
        caput(f'{top_name}:dc:disable_interlock', int(new_status), wait=True)
        return jsonify({"status": "success", "new_interlock_status": new_status})
    except Exception as e:
        logger.error(f"Error toggling interlock: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/clear_errors', methods=['POST'])
def clear_errors():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        caput(f'{top_name}:dc:apply.DIR', "PRESET", wait=True)
        return jsonify({"status": "success", "message": "Errors cleared successfully"})
    except Exception as e:
        logger.error(f"Error clearing errors: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_from_directory(app.static_folder, filename)

# Add this new route to handle the bias voltage toggle
@app.route('/toggle_bias_voltage', methods=['POST'])
def toggle_bias_voltage():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        new_value = request.json['new_value']
        if new_value not in ['0.3', '0.6']:
            raise ValueError("Invalid bias voltage value")
        
        caput(f'{top_name}:dc:arSetup.H', new_value, wait=True)
        return jsonify({"status": "success", "new_bias_voltage": new_value})
    except Exception as e:
        logger.error(f"Error changing bias voltage: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/apply_tdl', methods=['POST'])
def apply_tdl():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        caput(f'{top_name}:dc:TDL.DIR', "MARK", wait=True)
        caput(f'{top_name}:dc:apply.DIR', "START")
        return jsonify({"status": "success", "message": "TDL applied successfully"})
    except Exception as e:
        logger.error(f"Error applying TDL: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/start_controller', methods=['POST'])
def start_controller():
    try:
        if config_mode == 'DEBUG':
            command = '/usr/local/bin/dc-start.sh --top tgnirs'
        else:
            command = '/usr/local/bin/dc-start.sh'
        
        output, error = run_ssh_command(command)
        return jsonify({
            "status": "success",
            "message": "Controller started successfully",
            "output": output,
            "error": error
        })
    except Exception as e:
        logger.error(f"Error starting controller: {str(e)}")
        return jsonify({
            "status": "error",
            "message": f"Error starting controller: {str(e)}",
        }), 500

@app.route('/stop_controller', methods=['POST'])
def stop_controller():
    try:
        output, error = run_ssh_command('/usr/local/bin/dc-stop.sh')
        return jsonify({
            "status": "success",
            "message": "Controller stopped successfully",
            "output": output,
            "error": error
        })
    except Exception as e:
        logger.error(f"Error stopping controller: {str(e)}")
        return jsonify({
            "status": "error",
            "message": f"Error stopping controller: {str(e)}",
        }), 500

@app.route('/readme')
def readme():
    readme_path = '../README.md'
    with open(readme_path, 'r') as f:
        content = f.read()
    html_content = markdown2.markdown(content, extras=["fenced-code-blocks", "tables", "toc"])
    toc = html_content.toc_html
    return render_template('readme.html', active_tab='readme', content=html_content, toc=toc)

import logging

import time
import os
from flask import current_app

last_valid_preview = None

@app.route('/preview_latest_fits')
def preview_latest_fits():
    try:
        fits_dir = '/readout_data/fits'
        current_app.logger.info(f"Searching for FITS files in {fits_dir}")

        files = [f for f in os.listdir(fits_dir) if os.path.isfile(os.path.join(fits_dir, f))]
        if not files:
            current_app.logger.warning("No FITS files found in directory")
            return "No FITS files found", 404
        
        latest_file = max(files, key=lambda f: os.path.getmtime(os.path.join(fits_dir, f)))
        file_path = os.path.join(fits_dir, latest_file)
        current_app.logger.info(f"Latest FITS file: {latest_file}")

        with fits.open(file_path) as hdul:
            current_app.logger.info(f"FITS file structure: {[hdu.name for hdu in hdul]}")
            
            # Try to find the first HDU with data
            data = None
            for hdu in hdul:
                if hdu.data is not None:
                    data = hdu.data
                    current_app.logger.info(f"Using data from HDU: {hdu.name}")
                    break
            
            if data is None:
                raise ValueError("No data found in any HDU of the FITS file")

        current_app.logger.info(f"Data shape: {data.shape}, Data type: {data.dtype}")

        # Create a figure and axis
        fig, ax = plt.subplots(figsize=(10, 8))

        # Create an image plot with a colorbar
        im = ax.imshow(data, cmap='viridis', aspect='auto')
        plt.colorbar(im, ax=ax, label='Pixel Value')

        # Set title and labels
        ax.set_title(f'Preview of {latest_file}')
        ax.set_xlabel('X Pixel')
        ax.set_ylabel('Y Pixel')

        # Add text with data statistics
        stats_text = f"Min: {data.min():.2f}\nMax: {data.max():.2f}\nMean: {data.mean():.2f}\nMedian: {np.median(data):.2f}"
        plt.text(1.05, 0.95, stats_text, transform=ax.transAxes, verticalalignment='top')

        # Save the plot to a bytes buffer
        buf = io.BytesIO()
        plt.savefig(buf, format='png', bbox_inches='tight')
        buf.seek(0)
        plt.close(fig)

        current_app.logger.info("Preview generated successfully")

        response = send_file(buf, mimetype='image/png')
        response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0, max-age=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '-1'
        return response

    except Exception as e:
        current_app.logger.error(f"Error generating preview: {str(e)}")
        return f"Error generating preview: {str(e)}", 500

@app.route('/check_latest_fits')
def check_latest_fits():
    fits_dir = '/readout_data/fits'
    files = [f for f in os.listdir(fits_dir) if os.path.isfile(os.path.join(fits_dir, f))]
    if not files:
        return jsonify({"error": "No FITS files found"}), 404
    
    latest_file = max(files, key=lambda f: os.path.getmtime(os.path.join(fits_dir, f)))
    modified_time = os.path.getmtime(os.path.join(fits_dir, latest_file))
    
    return jsonify({
        "filename": latest_file,
        "modified_time": modified_time
    })

@app.route('/preview')
def preview():
    app.logger.debug("Rendering preview template")
    return render_template('preview.html', active_tab='preview')

last_modified_time = 0

@app.route('/fits_updates')
def fits_updates():
    def generate():
        global last_modified_time
        while True:
            fits_dir = '/readout_data/fits'
            files = [f for f in os.listdir(fits_dir) if os.path.isfile(os.path.join(fits_dir, f))]
            if files:
                latest_file = max(files, key=lambda f: os.path.getmtime(os.path.join(fits_dir, f)))
                current_modified_time = os.path.getmtime(os.path.join(fits_dir, latest_file))
                if current_modified_time > last_modified_time:
                    last_modified_time = current_modified_time
                    yield f"data: {latest_file}\n\n"
            time.sleep(0.1)

    return Response(generate(), content_type='text/event-stream')

def scan_fits_directory():
    global last_modified_time
    while True:
        fits_dir = '/readout_data/fits'
        files = [f for f in os.listdir(fits_dir) if os.path.isfile(os.path.join(fits_dir, f))]
        if files:
            latest_file = max(files, key=lambda f: os.path.getmtime(os.path.join(fits_dir, f)))
            current_modified_time = os.path.getmtime(os.path.join(fits_dir, latest_file))
            if current_modified_time > last_modified_time:
                last_modified_time = current_modified_time
                # You can add any additional processing here if needed
        time.sleep(0.1)

# Start the background thread
fits_scan_thread = threading.Thread(target=scan_fits_directory, daemon=True)
fits_scan_thread.start()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the system manager server")
    parser.add_argument("--debug", action="store_true", help="Run in debug mode")
    parser.add_argument("--port", type=int, default=8080, help="Port to run the server on")
    args = parser.parse_args()

    if args.debug:
        config_mode = 'DEBUG'
        debug_mode = config['DEBUG'].getboolean('DEBUG', fallback=False)
        logger.info(f"Debug flag detected. Using DEBUG from config: {debug_mode}")
    else:
        config_mode = 'DEFAULT'
        debug_mode = False
        logger.info("Running in production mode")

    logger.info("Starting PV subscription thread")
    subscription_thread = threading.Thread(target=run_subscription, daemon=True)
    subscription_thread.start()

    logger.info(f"Starting Flask application on port {args.port}")
    app.run(host='0.0.0.0', port=args.port, debug=debug_mode, threaded=True)
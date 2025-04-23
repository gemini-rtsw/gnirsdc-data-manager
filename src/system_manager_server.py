import os
import sys

# Set the working directory to the script's directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

import configparser
from flask import Flask, render_template, request, redirect, url_for, send_file, jsonify, Response, send_from_directory, make_response
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
from queue import Queue, Full as QueueFull, Empty
import subprocess
import markdown2
import paramiko
import numpy as np
import io
import matplotlib.pyplot as plt
from paramiko.ssh_exception import SSHException
import socket
import shutil
import zipfile
from io import BytesIO
from functools import lru_cache
import logging
import time
import os
from flask import current_app
from collections import deque  # Import deque for more efficient log message handling
from datetime import datetime, timedelta


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
log_messages = deque(maxlen=1000)  # Use deque with fixed maxlen instead of list
MAX_LOG_MESSAGES = 1000  # Keep this for reference
clients = set()
clients_lock = threading.Lock()

# SSH configuration
SSH_HOST = 'localhost'  # Since we're using --network=host, localhost refers to the host machine
SSH_PORT = 22
SSH_USERNAME = 'telops'
SSH_KEY_FILE = '/home/telops/.ssh/id_rsa'  # Path inside the container

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

# Define a central PV subscription manager
class PVSubscriptionManager:
    def __init__(self, ctx):
        self.ctx = ctx
        self.subscriptions = {}
        self.latest_values = {}
        self.subscription_lock = threading.Lock()
        self.clients = set()
        self.clients_lock = threading.Lock()

    def handle_subscription(self, sub, response):
        pv_name = sub.pv.name
        value = response.data[0]
        
        # Store metadata from the response for later use
        metadata = {
            'type': response.data_type,
            'count': response.data_count
        }
        
        if hasattr(response, 'metadata'):
            if hasattr(response.metadata, 'enum_strings'):
                metadata['enum_strings'] = response.metadata.enum_strings
            if hasattr(response.metadata, 'precision'):
                metadata['precision'] = response.metadata.precision
            if hasattr(response.metadata, 'units'):
                metadata['units'] = response.metadata.units
        
        # Handle string values properly
        if isinstance(value, bytes):
            try:
                value = value.decode('utf-8').strip('\x00')
            except UnicodeDecodeError:
                pass  # Keep as bytes if it can't be decoded
                
        # Handle enum/string values from the metadata if available
        if 'enum_strings' in metadata and metadata['enum_strings'] and isinstance(value, (int, np.integer)):
            try:
                enum_strings = metadata['enum_strings']
                if 0 <= value < len(enum_strings):
                    value = enum_strings[value].decode('utf-8') if isinstance(enum_strings[value], bytes) else enum_strings[value]
            except Exception as e:
                logger.error(f"Error converting enum value for {pv_name}: {str(e)}")
            
        logger.debug(f"PV update: {pv_name} = {value} (type: {metadata.get('type')})")
        
        with self.subscription_lock:
            # Store both value and metadata
            self.latest_values[pv_name] = {
                'value': value,
                'metadata': metadata
            }
        
        # Special handling for log messages
        if pv_name.endswith(':log_message'):
            # Store the log message in the server's log queue
            log_entry = {"status": "connected", "value": value}
            log_messages.append(log_entry)
            logger.debug(f"Added log entry: {log_entry}")
            
            # For log messages, send in the format expected by the frontend
            # No need to broadcast here since we'll return logs via get_log_messages
            # self.broadcast_to_clients({"value": value}) - Remove this line to avoid duplicates
            
            # Instead, broadcast the log_message field name with the value
            # This allows the client to handle it specifically as a log message
            self.broadcast_to_clients({"log_message": value})
        else:
            # Normal handling for other PVs - broadcast just the field update
            short_name = pv_name.split(':')[-1]  # Extract just the final part of the PV name
            self.broadcast_to_clients({short_name: value})
            
    def broadcast_to_clients(self, data):
        """Broadcast data to all connected clients"""
        # Skip if there are no clients
        with clients_lock:
            if not clients:
                return
        
        try:
            # Create the message outside of any locks
            # Convert NumPy types before JSON serialization
            sanitized_data = self._sanitize_for_json(data)
            
            try:
                message = json.dumps(sanitized_data)
            except TypeError as e:
                logger.error(f"JSON serialization error with data: {sanitized_data}")
                logger.error(f"Error: {str(e)}")
                return
            
            # Get a copy of clients under the lock
            with clients_lock:
                client_queues = list(clients)
            
            # Track failed clients for cleanup
            failed_clients = []
            
            # Send to each client without holding the lock
            for client_queue in client_queues:
                try:
                    client_queue.put_nowait(message)
                except QueueFull:
                    # Skip slow clients but don't remove them
                    logger.debug(f"Skipping slow client, queue full")
                except Exception as e:
                    # Mark client for removal on persistent errors
                    logger.error(f"Error sending to client: {str(e)}")
                    failed_clients.append(client_queue)
            
            # Clean up any failed clients
            if failed_clients:
                with clients_lock:
                    for failed in failed_clients:
                        if failed in clients:
                            clients.remove(failed)
                    logger.info(f"Removed {len(failed_clients)} failed clients. Remaining: {len(clients)}")
                            
            if len(client_queues) > 0:
                logger.debug(f"Broadcast to {len(client_queues)} clients")
        except Exception as e:
            # Catch any other errors to prevent broadcast issues from crashing the application
            logger.error(f"Error in broadcast: {str(e)}")
            
    def _sanitize_for_json(self, data):
        """Sanitize data for JSON serialization by converting NumPy types to Python native types"""
        if isinstance(data, dict):
            return {k: self._sanitize_for_json(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._sanitize_for_json(item) for item in data]
        elif hasattr(data, 'dtype'):
            # Handle NumPy scalars
            return data.item()
        elif isinstance(data, (np.integer, np.floating, np.bool_)):
            # Handle NumPy types
            return data.item()
        elif isinstance(data, bytes):
            # Handle bytes
            try:
                return data.decode('utf-8').strip('\x00')
            except UnicodeDecodeError:
                return str(data)
        else:
            return data

    def subscribe_to_pv(self, pv_name):
        """Subscribe to a PV if not already subscribed"""
        with self.subscription_lock:
            if pv_name in self.subscriptions:
                return self.subscriptions[pv_name]
            
            try:
                pv, = self.ctx.get_pvs(pv_name)
                sub = pv.subscribe(data_type='time')
                sub.add_callback(self.handle_subscription)
                self.subscriptions[pv_name] = sub
                logger.info(f"Subscribed to PV: {pv_name}")
                return sub
            except Exception as e:
                logger.error(f"Error subscribing to PV {pv_name}: {str(e)}")
                return None

    def subscribe_to_multiple_pvs(self, pv_names):
        """Subscribe to multiple PVs at once"""
        results = []
        for pv_name in pv_names:
            sub = self.subscribe_to_pv(pv_name)
            results.append(sub)
        return results

    def get_latest_value(self, pv_name):
        """Get the latest value for a PV"""
        with self.subscription_lock:
            pv_data = self.latest_values.get(pv_name)
            if pv_data:
                return pv_data['value']
            return None
            
    def get_pv_metadata(self, pv_name):
        """Get metadata for a PV"""
        with self.subscription_lock:
            pv_data = self.latest_values.get(pv_name)
            if pv_data and 'metadata' in pv_data:
                return pv_data['metadata']
            return None

    def get_all_values(self):
        """Get all current PV values"""
        with self.subscription_lock:
            return {pv_name: data for pv_name, data in self.latest_values.items()}

    def clear_all_subscriptions(self):
        """Clear all current subscriptions"""
        with self.subscription_lock:
            for pv_name, sub in list(self.subscriptions.items()):
                try:
                    sub.clear()
                    logger.info(f"Cleared subscription for PV: {pv_name}")
                except Exception as e:
                    logger.error(f"Error clearing subscription for {pv_name}: {str(e)}")
            self.subscriptions.clear()
    
    def setup_core_subscriptions(self, top_name):
        """Set up subscriptions for core PVs"""
        core_pvs = [
            f'{top_name}:log_message',
            f'{top_name}:heartbeat',
            f'{top_name}:tcs_connection',
            f'{top_name}:dc:lnrNum',
            f'{top_name}:dc:digitalAvgs',
            f'{top_name}:dc:integTime.VAL',
            f'{top_name}:dc:observe.A',
            f'{top_name}:dc:temperature',
            f'{top_name}:dc:disable_interlock',
            f'{top_name}:dc:applyC.VAL',
            f'{top_name}:gmp_status',
            f'{top_name}:dc:arSetup.H',
            f'{top_name}:dc:sdsuState',
            f'{top_name}:dc:coadds.VAL',
            f'{top_name}:dc:sequence',
            f'{top_name}:ntp_time',
            f'{top_name}:sad:dc:rdout',
            f'{top_name}:sad:dc:obsProgress'
        ]
        return self.subscribe_to_multiple_pvs(core_pvs)

    def check_subscription_health(self):
        """Check if any subscriptions need to be reconnected"""
        disconnected_count = 0
        total_count = len(self.subscriptions)
        
        # Count disconnected PVs
        with self.subscription_lock:
            for pv_name, sub in list(self.subscriptions.items()):
                if not sub.pv.connected:
                    disconnected_count += 1
        
        # If most PVs are disconnected, force complete reinit
        if disconnected_count > 0 and disconnected_count / total_count > 0.5:
            logger.warning(f"{disconnected_count}/{total_count} PVs disconnected. Forcing complete reconnection...")
            reinitialize_connections()
            return
        
        # Regular connection check for individual PVs
        with self.subscription_lock:
            for pv_name, sub in list(self.subscriptions.items()):
                if not sub.pv.connected:
                    logger.warning(f"Subscription to {pv_name} disconnected, reconnecting")
                    # Remove old subscription
                    self.subscriptions.pop(pv_name, None)
                    # Try to resubscribe
                    self.subscribe_to_pv(pv_name)

# Create a global instance
pv_manager = PVSubscriptionManager(ctx)

# Restore the routes that were accidentally removed
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
    } for entry in list(log_messages)])  # Convert deque to list for JSON serialization

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
    
    # Get date range parameters
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
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
        file_mtime = datetime.fromtimestamp(stat.st_mtime)
        
        # Apply date filter if both start and end dates are provided
        if start_date and end_date:
            start = datetime.strptime(start_date, '%Y-%m-%d')
            end = datetime.strptime(end_date, '%Y-%m-%d') + timedelta(days=1)  # Include the entire end date
            if start <= file_mtime < end:
                files_info.append({
                    'display_path': f,
                    'full_path': full_path,
                    'size': stat.st_size,
                    'mtime': file_mtime
                })
        else:
            files_info.append({
                'display_path': f,
                'full_path': full_path,
                'size': stat.st_size,
                'mtime': file_mtime
            })
    
    # Sort files by modification time
    files_info.sort(key=lambda x: x['mtime'], reverse=True)
    
    return render_template('fits_files.html', active_tab='fits', fits_files=files_info,
                           start_date=start_date, end_date=end_date)

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

# Modify the SSE route to use non-blocking queue
@app.route('/sse')
def sse():
    def event_stream():
        # Generate a simple client ID that doesn't rely on request object
        client_id = f"client-{hash(time.time())}"
        logger.info(f"Client connected: {client_id}")
        
        # Use a queue with maximum size to prevent memory issues
        client_queue = Queue(maxsize=100)
        
        # Register this client
        try:
            with clients_lock:
                clients.add(client_queue)
                client_count = len(clients)
            
            logger.info(f"Client {client_id} registered. Total clients: {client_count}")
            
            # Send an initial update with the connection status
            yield f"data: {json.dumps({'connected': True})}\n\n"
            
            # Keep streaming updates
            while True:
                try:
                    # Use a timeout to prevent completely blocking
                    message = client_queue.get(timeout=30)
                    yield f"data: {message}\n\n"
                except Empty:
                    # Queue.Empty exception - send a heartbeat
                    # Use 'server_heartbeat' instead of 'heartbeat' to distinguish from PV value
                    yield f"data: {json.dumps({'server_heartbeat': int(time.time())})}\n\n"
                except Exception as e:
                    # Log other errors but try to keep the connection
                    logger.error(f"Error in SSE stream for {client_id}: {str(e)}")
                    # Send an empty update to keep connection alive
                    yield f"data: {{}}\n\n"
                    time.sleep(1)  # Brief pause to prevent tight loop on error
        except GeneratorExit:
            # Client disconnected
            logger.info(f"Client disconnected: {client_id}")
        except Exception as e:
            # Log any other unexpected errors
            logger.error(f"Unexpected error in SSE for {client_id}: {str(e)}")
        finally:
            # Make sure we clean up on disconnect
            try:
                with clients_lock:
                    if client_queue in clients:
                        clients.remove(client_queue)
                        client_count = len(clients)
                    logger.info(f"Client {client_id} unregistered. Remaining clients: {client_count}")
            except Exception as e:
                logger.error(f"Error cleaning up client {client_id}: {str(e)}")

    # Set proper headers for SSE
    response = Response(event_stream(), content_type='text/event-stream')
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'  # Disable buffering for Nginx
    return response

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

@app.route('/abort_integration', methods=['POST'])
def abort_integration():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        caput(f'{top_name}:dc:abort.DIR', "MARK", wait=True)
        caput(f'{top_name}:dc:apply.DIR', "START")
        return jsonify({'status': 'success', 'message': 'Integration aborted'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)})

@app.route('/set_integration_params', methods=['POST'])
def set_integration_params():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        fowler_num = max(1, int(request.form.get('fowler_num', 1)))
        digital_avgs = max(1, int(request.form.get('digital_avgs', 1)))
        integ_time = float(request.form.get('integ_time', 0))
        file_name = request.form.get('file_name', '')
        coadds = max(1, int(request.form.get('coadds', 1)))
        sequence = max(1, int(request.form.get('sequence', 1)))

        caput(f'{top_name}:dc:lnrNum', fowler_num, wait=True)
        caput(f'{top_name}:dc:digitalAvgs', digital_avgs, wait=True)
        caput(f'{top_name}:dc:integTime.VAL', integ_time, wait=True)
        caput(f'{top_name}:dc:observe.A', file_name, wait=True)
        caput(f'{top_name}:dc:coadds.VAL', coadds, wait=True)
        caput(f'{top_name}:dc:sequence', sequence, wait=True)

        return jsonify({
            "status": "success",
            "message": "Integration parameters set successfully",
            "fowler_num": fowler_num,
            "digital_avgs": digital_avgs,
            "coadds": coadds,
            "sequence": sequence
        })
    except Exception as e:
        logger.error(f"Error setting integration parameters: {str(e)}")
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

@app.route('/power_on_cad', methods=['POST'])
def power_on_cad():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        caput(f'{top_name}:dc:powerOn.DIR', "MARK", wait=True)
        caput(f'{top_name}:dc:apply.DIR', "START")
        return jsonify({"status": "success", "message": "CAD powered on successfully"})
    except Exception as e:
        logger.error(f"Error powering on CAD: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/power_off_cad', methods=['POST'])
def power_off_cad():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    try:
        caput(f'{top_name}:dc:powerOff.DIR', "MARK", wait=True)
        caput(f'{top_name}:dc:apply.DIR', "START")
        return jsonify({"status": "success", "message": "CAD powered off successfully"})
    except Exception as e:
        logger.error(f"Error powering off CAD: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/get_file_log')
def get_file_log():
    log_dir = config[config_mode].get('LOG_DIR', '/readout_data/logs')
    log_file = os.path.join(log_dir, 'irdc.log')
    try:
        if not os.path.exists(log_file):
            return jsonify({"status": "error", "message": "Log file not found"}), 404
            
        # Get file size
        file_size = os.path.getsize(log_file)
        
        # If file is too large, only read the last 500KB
        max_size = 500 * 1024  # 500KB
        
        with open(log_file, 'r') as f:
            if file_size > max_size:
                # Seek to end - max_size
                f.seek(file_size - max_size)
                # Skip partial line
                f.readline()
                content = f.read()
            else:
                content = f.read()
                
        return jsonify({"status": "success", "content": content})
    except Exception as e:
        logger.error(f"Error reading log file: {str(e)}")
        return jsonify({"status": "error", "message": f"Error reading log file: {str(e)}"}), 500

@app.route('/engineering')
def engineering():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    interlock_pv = f'{top_name}:dc:disable_interlock'
    interlock_status = pv_manager.get_latest_value(interlock_pv)
    return render_template('engineering.html', interlock_status=interlock_status)


@app.route('/toggle_interlock', methods=['POST'])
def toggle_interlock():
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    interlock_pv = f'{top_name}:dc:disable_interlock'
    try:
        current_status = pv_manager.get_latest_value(interlock_pv)
        new_status = not current_status
        caput(interlock_pv, int(new_status), wait=True)
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
        mode = request.json.get('mode', 'normal')
        
        # Set the appropriate top name based on mode
        if mode in ['debug', 'full_debug']:
            config[config_mode]['DEFAULT_PREFIX'] = 'tgnirs'
        else:
            # Reset to default from config file
            config.read(config_path)
        
        # Clear existing subscriptions and set up new ones with the updated top name
        top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
        pv_manager.clear_all_subscriptions()
        pv_manager.setup_core_subscriptions(top_name)
        
        if mode == 'normal':
            command = '/usr/local/bin/dc-start.sh'
        elif mode == 'debug':
            command = '/usr/local/bin/dc-start.sh --top tgnirs'
        elif mode == 'full_debug':
            command = '/usr/local/bin/dc-start.sh --top tgnirs --debug'
        else:
            raise ValueError(f"Invalid mode: {mode}")
        
        output, error = run_ssh_command(command)
        
        if error:
            raise Exception(f"Error in command execution: {error}")
        
        return jsonify({
            "status": "success",
            "message": "Controller started successfully",
            "output": output,
            "error": error,
            "top_name": config[config_mode]['DEFAULT_PREFIX']  # Return the current top name
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

last_preview_image = None
preview_lock = threading.Lock()
no_files_warning_logged = False
no_preview_logged = False  # Add this flag

def update_preview_only():
    """Update the preview image only"""
    global last_preview_image, no_files_warning_logged, no_preview_logged
    try:
        # Generate preview image
        fits_dir = '/readout_data/fits'
        os.makedirs(fits_dir, exist_ok=True)
        files = [f for f in os.listdir(fits_dir) if os.path.isfile(os.path.join(fits_dir, f))]
        
        if not files:
            if not no_files_warning_logged:
                current_app.logger.warning("No files found in directory")
                no_files_warning_logged = True
            preview_image = None
            latest_file = None
        else:
            no_files_warning_logged = False
            latest_file = max(files, key=lambda f: os.path.getmtime(os.path.join(fits_dir, f)))
            file_path = os.path.join(fits_dir, latest_file)

            try:
                with fits.open(file_path) as hdul:
                    data = None
                    for hdu in hdul:
                        if hdu.data is not None:
                            data = hdu.data
                            break
                    
                    if data is None:
                        raise ValueError("No data found in any HDU of the file")

                fig, ax = plt.subplots(figsize=(10, 8))
                im = ax.imshow(data, cmap='viridis', aspect='auto')
                plt.colorbar(im, ax=ax, label='Pixel Value')
                ax.set_title(f'Preview of {latest_file}')
                ax.set_xlabel('X Pixel')
                ax.set_ylabel('Y Pixel')

                buf = io.BytesIO()
                plt.savefig(buf, format='png', bbox_inches='tight')
                buf.seek(0)
                plt.close(fig)

                preview_image = buf.getvalue()
                no_preview_logged = False  # Reset when we get a preview

            except Exception as e:
                current_app.logger.error(f"Error processing file {latest_file}: {str(e)}")
                preview_image = None

        with preview_lock:
            if preview_image is not None:
                last_preview_image = preview_image

        if latest_file:
            current_app.logger.info(f"Preview cached successfully for {latest_file}")
        else:
            if not no_preview_logged:
                current_app.logger.info("No new preview available")
                no_preview_logged = True

    except Exception as e:
        current_app.logger.error(f"Error generating preview: {str(e)}")

@app.route('/preview')
def preview():
    return render_template('preview.html', active_tab='preview')

@app.route('/preview_latest_fits')
def preview_latest_fits():
    global last_preview_image
    with preview_lock:
        if request.args.get('info') == 'true':
            # Return JSON with file info
            if last_preview_image is None:
                return jsonify({"status": "error", "message": "No preview available"}), 404
            else:
                return jsonify({
                    "status": "success",
                    "timestamp": time.time()
                })
        else:
            # Return the actual image data
            if last_preview_image is None:
                return "No preview available", 404
            
            response = make_response(last_preview_image)
            response.headers.set('Content-Type', 'image/png')
            response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0, max-age=0'
            response.headers['Pragma'] = 'no-cache'
            response.headers['Expires'] = '-1'
            return response

# Add a simple request rate limiter
pv_cache = {}
pv_cache_time = 0
PV_CACHE_TTL = 0.2  # 200ms throttling

@app.route('/get_all_pvs')
def get_all_pvs():
    """Get all PV values from the PV manager with throttling"""
    global pv_cache, pv_cache_time
    
    current_time = time.time()
    
    # Return cached data if it's fresh enough
    if current_time - pv_cache_time < PV_CACHE_TTL and pv_cache:
        return jsonify(pv_cache)
        
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    all_pv_data = pv_manager.get_all_values()
    
    # Define mapping from PVs to UI field names
    pv_to_ui_map = {
        f'{top_name}:dc:lnrNum': 'fowler_num',
        f'{top_name}:dc:digitalAvgs': 'digital_avgs',
        f'{top_name}:dc:integTime.VAL': 'integ_time',
        f'{top_name}:dc:observe.A': 'file_name',
        f'{top_name}:dc:temperature': 'temperature',
        f'{top_name}:dc:disable_interlock': 'interlock_override',
        f'{top_name}:dc:applyC.VAL': 'apply_c_value',
        f'{top_name}:dc:sdsuState': 'sdsu_state',
        f'{top_name}:dc:coadds.VAL': 'coadds',
        f'{top_name}:dc:sequence': 'sequence',
        f'{top_name}:sad:dc:rdout': 'rdout',
        f'{top_name}:sad:dc:obsProgress': 'obs_progress',
        f'{top_name}:heartbeat': 'heartbeat',
        f'{top_name}:tcs_connection': 'tcs_connection',
        f'{top_name}:gmp_status': 'gmp_status',
        f'{top_name}:ntp_time': 'ntp_time'
    }
    
    # Track connection status for key status indicators
    connection_status = {}
    
    # Check connection status for key status indicators
    key_status_pvs = [
        f'{top_name}:heartbeat',
        f'{top_name}:tcs_connection',
        f'{top_name}:gmp_status',
        f'{top_name}:dc:sdsuState',
        f'{top_name}:dc:disable_interlock'
    ]
    
    # Check if each key PV is connected
    for pv_name in key_status_pvs:
        if pv_name in pv_manager.subscriptions:
            sub = pv_manager.subscriptions[pv_name]
            connection_status[pv_name] = sub.pv.connected
        else:
            connection_status[pv_name] = False
    
    # Process values for display
    formatted_values = {}
    
    # Add top_name explicitly
    formatted_values['top_name'] = top_name
    
    # Add connection status for key status indicators
    formatted_values['connection_status'] = {
        'heartbeat': connection_status.get(f'{top_name}:heartbeat', False),
        'tcs_connection': connection_status.get(f'{top_name}:tcs_connection', False),
        'gmp_status': connection_status.get(f'{top_name}:gmp_status', False),
        'sdsu_state': connection_status.get(f'{top_name}:dc:sdsuState', False),
        'interlock_override': connection_status.get(f'{top_name}:dc:disable_interlock', False)
    }
    
    # Process each PV using its metadata
    for pv_name, pv_data in all_pv_data.items():
        if not pv_data:
            continue
            
        value = pv_data.get('value')
        metadata = pv_data.get('metadata', {})
        pv_type = metadata.get('type')
        
        if value is None:
            continue
            
        # Get UI field name from mapping or extract from PV name
        ui_field = pv_to_ui_map.get(pv_name)
        if not ui_field:
            # Use last part of PV name as fallback
            if ':' in pv_name:
                ui_field = pv_name.split(':')[-1]
                # Clean up special characters in field names
                ui_field = ui_field.replace('.', '_').replace('-', '_')
            else:
                ui_field = pv_name
        
        # Convert NumPy types to native Python types for JSON serialization
        if hasattr(value, 'dtype'):
            value = value.item()
        
        # Format value based on its type
        if isinstance(value, bytes):
            try:
                value = value.decode('utf-8').strip('\x00')
            except UnicodeDecodeError:
                value = str(value)
        
        # Convert strings to correct types based on metadata
        if pv_type == ChannelType.DOUBLE or pv_type == ChannelType.FLOAT:
            # Apply precision if available
            if 'precision' in metadata:
                try:
                    precision = metadata['precision']
                    if isinstance(value, (int, float)):
                        value = round(value, precision)
                except (TypeError, ValueError):
                    pass
                
        # String values should be cleaned up
        elif pv_type == ChannelType.STRING:
            if value is not None:
                value = str(value).strip()
            
        # Special handling for sdsuState - also add sdsu_state alias
        if ui_field == 'sdsu_state' or ui_field == 'sdsuState':
            formatted_values['sdsu_state'] = value 
            
        # Store the value
        formatted_values[ui_field] = value
        
    # Special handling for calculated values
    bias_pv = f'{top_name}:dc:arSetup.H'
    if bias_pv in all_pv_data and all_pv_data[bias_pv]:
        detector_bias_str = all_pv_data[bias_pv]['value']
        try:
            if isinstance(detector_bias_str, str):
                detector_bias_v = float(detector_bias_str)
            else:
                detector_bias_v = float(detector_bias_str)
            detector_bias_mv = detector_bias_v * 1000
            formatted_values['detector_bias'] = f"{detector_bias_mv:.2f} mV"
            formatted_values['bias_mode'] = "DEEP" if detector_bias_str == "0.6" else "SHALLOW"
        except (ValueError, TypeError):
            formatted_values['detector_bias'] = "N/A"
            formatted_values['bias_mode'] = "UNKNOWN"
    
    # Special handling for NTP time - just pass the raw value with no processing
    ntp_pv = f'{top_name}:ntp_time'
    if ntp_pv in all_pv_data and all_pv_data[ntp_pv]:
        if all_pv_data[ntp_pv].get('value') is not None:
            # Just pass the raw value directly
            formatted_values['ntp_time'] = all_pv_data[ntp_pv]['value']
        else:
            # Use a default of 0 if no value is available
            formatted_values['ntp_time'] = 0
    else:
        formatted_values['ntp_time'] = 0
    
    # Ensure readout progress is correctly calculated
    if 'rdout' in formatted_values and 'obs_progress' in formatted_values:
        rdout = formatted_values['rdout']
        obs_progress = formatted_values['obs_progress']
        
        if rdout == 0:
            formatted_values['obs_progress'] = 0
    
    # Add default values for missing fields to ensure UI can render properly
    default_fields = {
        'heartbeat': 0,
        'tcs_connection': '',
        'fowler_num': 1,
        'digital_avgs': 1,
        'integ_time': 0,
        'file_name': '',
        'temperature': 0,
        'interlock_override': 0,
        'apply_c_value': 0,
        'gmp_status': '',
        'detector_bias': 'N/A',
        'bias_mode': 'UNKNOWN',
        'sdsu_state': 'UNKNOWN',
        'coadds': 1,
        'sequence': 1,
        'ntp_time': 0,
        'rdout': 0,
        'obs_progress': 0
    }
    
    # Fill in any missing values with defaults
    for key, default_value in default_fields.items():
        if key not in formatted_values:
            formatted_values[key] = default_value

    # Prepare and cache response
    response = {"status": "success", "pvs": formatted_values}
    pv_cache = response
    pv_cache_time = current_time
            
    return jsonify(response)

# Start the preview generation thread
def preview_thread_function():
    """Thread function for preview updates"""
    while True:
        with app.app_context():
            update_preview_only()
        time.sleep(1.0)  # Update preview every 1 second

# Health check thread to ensure PV subscriptions remain active
def subscription_health_check():
    """Thread function to periodically check subscription health"""
    while True:
        try:
            pv_manager.check_subscription_health()
        except Exception as e:
            logger.error(f"Error in subscription health check: {str(e)}")
        time.sleep(5)  # Check every 5 seconds

# Start the subscription health check thread
health_check_thread = threading.Thread(target=subscription_health_check, daemon=True)
health_check_thread.start()

# Start the preview thread
preview_thread = threading.Thread(target=preview_thread_function, daemon=True)
preview_thread.start()

@app.route('/get_hostname')
def get_hostname():
    try:
        hostname = subprocess.check_output(['hostname']).decode('utf-8').strip()
        return jsonify({"status": "success", "hostname": hostname})
    except Exception as e:
        logger.error(f"Error getting hostname: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/get_eng_info')
def get_eng_info():
    try:
        disk_space = get_disk_space()
        dir_sizes = get_directory_sizes()
        return jsonify({
            "status": "success",
            "disk_space": disk_space,
            "dir_sizes": dir_sizes
        })
    except Exception as e:
        logger.error(f"Error getting engineering info: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

import psutil

def get_disk_space():
    try:
        command = "df -h"
        output, error = run_ssh_command(command)
        
        if error:
            raise Exception(f"Error executing df -h: {error}")
        
        lines = output.strip().split('\n')
        headers = lines[0].split()
        disk_info = {}
        
        for line in lines[1:]:
            parts = line.split()
            if len(parts) >= 6:  # Ensure we have all expected fields
                filesystem = parts[0]
                size = parts[1]
                used = parts[2]
                available = parts[3]
                use_percent = parts[4]
                mountpoint = ' '.join(parts[5:])  # Join remaining parts as mountpoint
                
                # Convert sizes to GB if possible
                try:
                    size_gb = convert_to_gb(size)
                    used_gb = convert_to_gb(used)
                    available_gb = convert_to_gb(available)
                except ValueError:
                    size_gb = size
                    used_gb = used
                    available_gb = available
                
                disk_info[mountpoint] = {
                    'device': filesystem,
                    'total': size_gb,
                    'used': used_gb,
                    'free': available_gb,
                    'percent_used': use_percent.rstrip('%')
                }
        
        return disk_info
    except Exception as e:
        logger.error(f"Error getting disk space: {str(e)}")
        return {}

def convert_to_gb(size_str):
    size = float(size_str[:-1])
    unit = size_str[-1].upper()
    if unit == 'T':
        return size * 1024
    elif unit == 'G':
        return size
    elif unit == 'M':
        return size / 1024
    elif unit == 'K':
        return size / (1024 * 1024)
    else:
        return size / (1024 * 1024 * 1024)

def get_directory_sizes():
    base_dir = '/readout_data'
    dir_sizes = {}
    
    try:
        # List all subdirectories in the base_dir
        subdirs = [d for d in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, d))]
        
        for subdir in subdirs:
            path = os.path.join(base_dir, subdir)
            size = subprocess.check_output(['du', '-sh', path]).split()[0].decode('utf-8')
            dir_sizes[subdir] = size
    except Exception as e:
        logger.error(f"Error getting directory sizes: {str(e)}")
    
    return dir_sizes

@app.route('/download_fits')
def download_fits():
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    # Reuse the logic from fits_files() to get the filtered list of files
    staging_dir = config[config_mode].get('STAGING_DIR', '/staging/perm')
    readout_dir = config[config_mode].get('READOUT_DIR', '/readout_data/fits')
    
    all_files = []
    if os.path.exists(staging_dir):
        staging_files = [os.path.join('staging', f) for f in os.listdir(staging_dir) if f.endswith('.fits')]
        all_files.extend(staging_files)
    if os.path.exists(readout_dir):
        readout_files = [os.path.join('readout', f) for f in os.listdir(readout_dir) if f.endswith('.fits')]
        all_files.extend(readout_files)
    
    files_to_download = []
    for f in all_files:
        full_path = os.path.join(staging_dir if f.startswith('staging') else readout_dir, os.path.basename(f))
        stat = os.stat(full_path)
        file_mtime = datetime.fromtimestamp(stat.st_mtime)
        
        if start_date and end_date:
            start = datetime.strptime(start_date, '%Y-%m-%d')
            end = datetime.strptime(end_date, '%Y-%m-%d') + timedelta(days=1)
            if start <= file_mtime < end:
                files_to_download.append((f, full_path))
        else:
            files_to_download.append((f, full_path))
    
    # Create a ZIP file in memory
    memory_file = BytesIO()
    with zipfile.ZipFile(memory_file, 'w') as zf:
        for file_name, file_path in files_to_download:
            zf.write(file_path, file_name)
    
    memory_file.seek(0)
    
    return send_file(
        memory_file,
        mimetype='application/zip',
        as_attachment=True,
        download_name='fits_files.zip'
    )

def initialize_subscriptions():
    """Initialize all PV subscriptions at startup"""
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    logger.info(f"Setting up core PV subscriptions with prefix: {top_name}")
    pv_manager.setup_core_subscriptions(top_name)

# Add this function at the global level, after the pv_manager is created
def reinitialize_connections():
    """Completely reinitialize all EPICS connections"""
    global ctx, pv_manager
    
    logger.warning("Reinitializing all EPICS connections from scratch")
    
    # Clear existing subscriptions
    pv_manager.clear_all_subscriptions()
    
    # Create a new context
    ctx = Context()
    
    # Create a new manager
    pv_manager = PVSubscriptionManager(ctx)
    
    # Initialize subscriptions just like at startup
    top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
    logger.info(f"Setting up core PV subscriptions with prefix: {top_name}")
    pv_manager.setup_core_subscriptions(top_name)

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

    # Initialize subscriptions at startup
    initialize_subscriptions()

    logger.info(f"Starting Flask application on port {args.port}")
    app.run(host='0.0.0.0', port=args.port, debug=debug_mode)

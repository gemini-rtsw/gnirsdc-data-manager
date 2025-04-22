#!/usr/bin/env python3
"""
Simple network monitor for GNIRS Data Manager server-client communication.
Focuses on tracking preview image requests and their sizes/timing.

Usage:
    python network_monitor.py --url http://localhost:8080
"""

import argparse
import requests
import time
import statistics
from datetime import datetime
import sys
import threading
import json

class NetworkMonitor:
    def __init__(self, base_url, interval=1.0, endpoints=None):
        self.base_url = base_url
        self.interval = interval
        self.running = True
        self.endpoints = endpoints or [
            '/preview_latest_fits',  # Preview image
            '/get_all_pvs',          # PV values
            '/get_log_messages'      # Log messages
        ]
        self.stats = {endpoint: {'sizes': [], 'times': [], 'errors': 0} for endpoint in self.endpoints}
        self.last_minute_data = {endpoint: {'sizes': [], 'times': []} for endpoint in self.endpoints}
        self.session = requests.Session()  # Reuse connection

    def monitor_endpoint(self, endpoint):
        """Request an endpoint and record metrics"""
        url = f"{self.base_url}{endpoint}"
        try:
            start_time = time.time()
            response = self.session.get(url, timeout=5)
            end_time = time.time()
            
            elapsed_ms = (end_time - start_time) * 1000
            size_kb = len(response.content) / 1024
            
            # Store stats
            self.stats[endpoint]['sizes'].append(size_kb)
            self.stats[endpoint]['times'].append(elapsed_ms)
            
            # Store for rolling window
            self.last_minute_data[endpoint]['sizes'].append(size_kb)
            self.last_minute_data[endpoint]['times'].append(elapsed_ms)
            
            # Keep last minute only (assuming interval is respected)
            max_samples = int(60 / self.interval)
            if len(self.last_minute_data[endpoint]['sizes']) > max_samples:
                self.last_minute_data[endpoint]['sizes'] = self.last_minute_data[endpoint]['sizes'][-max_samples:]
                self.last_minute_data[endpoint]['times'] = self.last_minute_data[endpoint]['times'][-max_samples:]
            
            return {
                'endpoint': endpoint,
                'status': response.status_code,
                'size_kb': size_kb,
                'time_ms': elapsed_ms,
            }
        except Exception as e:
            self.stats[endpoint]['errors'] += 1
            return {
                'endpoint': endpoint,
                'status': 'ERROR',
                'error': str(e)
            }

    def print_stats(self):
        """Print current statistics"""
        now = datetime.now().strftime("%H:%M:%S")
        print(f"\n===== Network Stats at {now} =====")
        print(f"{'Endpoint':<20} {'Last Size':<12} {'Last Time':<12} {'1min Avg Size':<15} {'1min Avg Time':<15}")
        print("-" * 80)
        
        for endpoint in self.endpoints:
            stats = self.stats[endpoint]
            last_minute = self.last_minute_data[endpoint]
            
            if stats['sizes']:
                last_size = stats['sizes'][-1]
                last_time = stats['times'][-1]
                
                # Calculate 1-minute averages
                avg_size = statistics.mean(last_minute['sizes']) if last_minute['sizes'] else 0
                avg_time = statistics.mean(last_minute['times']) if last_minute['times'] else 0
                
                print(f"{endpoint:<20} {last_size:<12.2f}KB {last_time:<12.2f}ms {avg_size:<15.2f}KB {avg_time:<15.2f}ms")
            else:
                print(f"{endpoint:<20} {'N/A':<12} {'N/A':<12} {'N/A':<15} {'N/A':<15}")
        
        print(f"\nTotal Data Transferred: {sum(sum(self.stats[e]['sizes']) for e in self.endpoints):.2f} KB")
        print(f"Error Count: {sum(self.stats[e]['errors'] for e in self.endpoints)}")
        
        # Print preview image specific stats if available
        if '/preview_latest_fits' in self.stats and self.stats['/preview_latest_fits']['sizes']:
            preview_sizes = self.stats['/preview_latest_fits']['sizes']
            print(f"\nPreview Image Stats:")
            print(f"  Min Size: {min(preview_sizes):.2f} KB")
            print(f"  Max Size: {max(preview_sizes):.2f} KB")
            print(f"  Avg Size: {statistics.mean(preview_sizes):.2f} KB")
            print(f"  Total Preview Data: {sum(preview_sizes):.2f} KB")

    def run(self):
        """Main monitoring loop"""
        try:
            while self.running:
                for endpoint in self.endpoints:
                    result = self.monitor_endpoint(endpoint)
                    
                    # Simple one-line output for each request
                    status = result.get('status', 'ERROR')
                    if status != 'ERROR':
                        size = result.get('size_kb', 0)
                        time_ms = result.get('time_ms', 0)
                        print(f"{datetime.now().strftime('%H:%M:%S')} - {endpoint}: {status} | {size:.2f} KB | {time_ms:.2f} ms")
                    else:
                        error = result.get('error', 'Unknown error')
                        print(f"{datetime.now().strftime('%H:%M:%S')} - {endpoint}: ERROR | {error}")
                
                # Print detailed stats every 10 seconds
                if int(time.time()) % 10 == 0:
                    self.print_stats()
                
                time.sleep(self.interval)
        except KeyboardInterrupt:
            print("\nMonitoring stopped by user")
            self.running = False
            self.print_stats()

def main():
    parser = argparse.ArgumentParser(description='Monitor network traffic for GNIRS Data Manager')
    parser.add_argument('--url', default='http://localhost:8080', help='Base URL of the server')
    parser.add_argument('--interval', type=float, default=1.0, help='Polling interval in seconds')
    args = parser.parse_args()
    
    print(f"Starting network monitor for {args.url}")
    print("Press Ctrl+C to stop")
    
    monitor = NetworkMonitor(args.url, args.interval)
    monitor.run()

if __name__ == "__main__":
    main() 
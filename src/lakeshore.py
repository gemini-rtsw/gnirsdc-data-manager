# lakeshore.py
import socket
from logging import getLogger

class Lakeshore325:
    def __init__(self, ip, port, timeout=5):
        self.ip = ip
        self.port = port
        self.timeout = timeout
        self.sock = None
        self.logger = getLogger('Temperature Controller')

    def connect(self):
        try:
            self.logger.info(f"Connecting to Lakeshore 325 at {self.ip}:{self.port}")

            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(self.timeout)  # Set the connection timeout
            self.sock.connect((self.ip, self.port))
            self.logger.info(f"Connected to Lakeshore 325 at {self.ip}:{self.port}")
        except socket.timeout:
            self.logger.info(f"Connection to {self.ip}:{self.port} timed out after {self.timeout} seconds")
            self.sock = None
        except Exception as e:
            self.logger.info(f"Failed to connect to {self.ip}:{self.port} - {e}")
            self.sock = None

    def disconnect(self):
        if self.sock:
            try:
                self.sock.close()
                self.logger.info("Disconnected from Lakeshore 325")
            except Exception as e:
                self.logger.info(f"Failed to disconnect from {self.ip}:{self.port} - {e}")
            self.sock = None

    def send_command(self, command):
        try:
            if not self.sock:
                # Attempt to reconnect if socket is closed
                self.connect()
                
            if self.sock:
                # Flush any buffered data before sending new command
                self.sock.settimeout(0.1)  # Short timeout for flush
                try:
                    while True:
                        data = self.sock.recv(1024)
                        if not data:
                            break
                except socket.timeout:
                    pass  # Expected when buffer is empty
                finally:
                    self.sock.settimeout(self.timeout)  # Restore original timeout
                
                self.sock.sendall(command)
                response = self.sock.recv(1024).strip()
                return response.decode('utf-8')
            else:
                self.logger.irdc_debug(f"Temperature controller is not connected: {self.ip} {self.port}")
                return None
        except (socket.timeout, socket.error) as e:
            self.logger.irdc_debug(f"Connection error: {e}")
            # Close socket on network errors
            if self.sock:
                try:
                    self.sock.close()
                except:
                    pass
                self.sock = None
            return None
        except Exception as e:
            self.logger.irdc_debug(f"Failed to send command: {e}")
            return None

    def check_status(self):
        response = self.send_command(b'*IDN?\n')
        return response

    def read_temperature(self):
        response = self.send_command(b'KRDG? 0\n')
        try:
            if response is None:
                self.logger.irdc_debug("Connection failed or error occurred, returning -999")
                return -999
            temperature_value = float(response)
            return temperature_value
        except (ValueError, TypeError):
            self.logger.irdc_debug(f"Failed to convert response to float: {response}")
            return -999

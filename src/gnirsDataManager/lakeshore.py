# lakeshore.py
import socket

class Lakeshore325:
    def __init__(self, ip, port):
        self.ip = ip
        self.port = port
        self.sock = None

    def connect(self):
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((self.ip, self.port))
            print(f"Connected to Lakeshore 325 at {self.ip}:{self.port}")
        except Exception as e:
            print(f"Failed to connect to {self.ip}:{self.port} - {e}")
            self.sock = None

    def disconnect(self):
        if self.sock:
            try:
                self.sock.close()
                print("Disconnected from Lakeshore 325")
            except Exception as e:
                print(f"Failed to disconnect from {self.ip}:{self.port} - {e}")
            self.sock = None

    def send_command(self, command):
        try:
            if self.sock:
                self.sock.sendall(command)
                response = self.sock.recv(1024).strip()
                return response.decode('utf-8')
            else:
                printf("Temperature controller is not connected: {self.ip} {self.port}")
                return None
        except Exception as e:
            print(f"Failed to send command: {e}")
            return None

    def check_status(self):
        response = self.send_command(b'*IDN?\n')
        return response

    def read_temperature(self):
        response = self.send_command(b'KRDG? 0\n')
        try:
            temperature_value = float(response)
            return temperature_value
        except ValueError:
            print(f"Failed to convert response to float: {response}")
            return None

import socket
import time

class Lakeshore325:
    def __init__(self, ip, port):
        self.ip = ip
        self.port = port
        self.sock = None

    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((self.ip, self.port))

    def disconnect(self):
        if self.sock:
            self.sock.close()
            self.sock = None

    def send_command(self, command):
        try:
            self.sock.sendall(command)
            response = self.sock.recv(1024).strip()
            return response.decode('utf-8')
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

if __name__ == "__main__":
    lakeshore = Lakeshore325(ip='10.1.2.60', port=3302)
    lakeshore.connect()

    temperature = lakeshore.read_temperature()
    if temperature is not None:
        print(f"Current Temperature: {temperature} K")
    else:
        print("Could not read temperature.")

    # Adding a short delay before checking status to ensure command completion
    time.sleep(0.5)

    status = lakeshore.check_status()
    if status:
        print(f"Lakeshore Status: {status}")
    else:
        print("Could not check status.")

    lakeshore.disconnect()

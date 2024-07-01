import socket

def read_temperature():
    try:
        # Open a socket connection
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.connect(('10.1.2.60', 3302))
            
            # Send command to read temperature
            command = b'KRDG? 0\n'
            sock.sendall(command)
            
            # Read the response
            response = sock.recv(1024).strip()
            
            # Convert response to string and then to float
            temperature_value = float(response.decode('utf-8'))
            return temperature_value
    except Exception as e:
        print(f"Failed to read temperature: {e}")
        return None

if __name__ == "__main__":
    temperature = read_temperature()
    if temperature is not None:
        print(f"Current Temperature: {temperature} K")
    else:
        print("Could not read temperature.")

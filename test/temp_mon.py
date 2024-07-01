import socket

def check_lakeshore_status():
    try:
        # Create a socket connection to the WTI device on port 3302
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('10.1.2.60', 3302))
        
        # Send the *IDN? command to the Lakeshore 325 controller
        command = b'*IDN?\n'
        sock.sendall(command)
        
        # Receive the response
        response = sock.recv(1024).strip()
        
        # Convert response to string
        response_str = response.decode('utf-8')
        
        # Close the socket connection
        sock.close()
        
        return response_str
    except Exception as e:
        print(f"Failed to check status: {e}")
        return None

def read_temperature():
    try:
        # Create a new socket connection to the WTI device on port 3302
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('10.1.2.60', 3302))
        
        # Send the KRDG? 0 command to read temperature from sensor 0
        command = b'KRDG? 0\n'
        sock.sendall(command)
        
        # Receive the response
        response = sock.recv(1024).strip()
        
        # Convert response to float
        temperature_value = float(response.decode('utf-8'))
        
        # Close the socket connection
        sock.close()
        
        return temperature_value
    except Exception as e:
        print(f"Failed to read temperature: {e}")
        return None

if __name__ == "__main__":
    status = check_lakeshore_status()
    if status:
        print(f"Lakeshore Status: {status}")
    else:
        print("Could not check status.")
    
    # Close and reopen the socket connection for reading temperature
    temperature = read_temperature()
    if temperature is not None:
        print(f"Current Temperature: {temperature} K")
    else:
        print("Could not read temperature.")

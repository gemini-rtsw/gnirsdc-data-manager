import paramiko

def read_temperature():
    try:
        # Create an SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Connect to the WTI device
        ssh.connect('10.1.2.60', username='super', password='super')  # Replace 'your_password' with the actual password

        # Start an interactive shell session
        session = ssh.invoke_shell()

        # Send the command to connect to port 2 (Lakeshore)
        session.send('connect 2\n')
        session.recv(1000)  # Receive initial connection response

        # Send the command to read temperature
        session.send('KRDG? 0\n')
        response = session.recv(1000).decode('utf-8').strip()

        # Close the SSH connection
        ssh.close()

        # Convert response to float and return temperature
        temperature_value = float(response)
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

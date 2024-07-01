import paramiko

def read_temperature():
    try:
        # Create an SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Connect to the WTI device
        ssh.connect('10.1.2.60', username='super', password='your_password')  # Replace 'your_password' with the actual password

        # Open a session
        stdin, stdout, stderr = ssh.exec_command('connect 2')
        stdin.write('KRDG? 0\n')
        stdin.flush()

        # Read response
        response = stdout.read().strip().decode('utf-8')

        # Close SSH connection
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

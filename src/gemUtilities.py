from caproto.sync.client import read

def checkCAConnection(channel_name, timeout=1.0):
    try:
        response = read(channel_name, timeout=timeout)
        if response is not None:
            return True
    except TimeoutError:
        return False
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return False





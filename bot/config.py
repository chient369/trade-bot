import json
from utils.logger import log

class Config:
    """
    A class to hold configuration settings, allowing nested dictionary access
    via attributes (e.g., settings.Broker.Account).
    """
    def __init__(self, data):
        for key, value in data.items():
            if isinstance(value, dict):
                # If the value is a dictionary, create a nested Config object
                setattr(self, key, Config(value))
            else:
                setattr(self, key, value)

def load_config(path='config.json'):
    """
    Loads the configuration from a JSON file and returns a Config object.
    """
    try:
        with open(path, 'r') as f:
            data = json.load(f)
            log.info(f"Configuration loaded successfully from {path}")
            return Config(data)
    except FileNotFoundError:
        log.error(f"FATAL: Configuration file not found at '{path}'. Please ensure it exists.")
        return None
    except json.JSONDecodeError:
        log.error(f"FATAL: Error decoding JSON from '{path}'. Please check for syntax errors.")
        return None

# Load the configuration upon module import, making it accessible application-wide
settings = load_config()
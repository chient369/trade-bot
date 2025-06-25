import logging
import sys
import os
from datetime import datetime

def setup_logger():
    """
    Set up the main logger for the application.
    It logs to both the console and a file named with the current date.
    """
    logger = logging.getLogger("TradingBot")
    logger.setLevel(logging.INFO)

    # --- Avoid adding handlers multiple times ---
    if logger.handlers:
        return logger

    # --- Create Formatter ---
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    # --- Console Handler ---
    stream_handler = logging.StreamHandler(sys.stdout)
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)

    # --- File Handler ---
    # Create logs directory if it doesn't exist
    log_dir = 'logs'
    os.makedirs(log_dir, exist_ok=True)

    # Create a file handler that logs messages to a file named with the current date
    log_file_name = f"{datetime.now().strftime('%Y%m%d')}_trading-bot.log"
    file_handler = logging.FileHandler(os.path.join(log_dir, log_file_name))
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
        
    return logger

# Initialize and export the logger
log = setup_logger() 
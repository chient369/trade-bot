import logging
import os
from datetime import datetime

# --- Define CSV Columns ---
TRADE_LOG_COLUMNS = [
    'timestamp', 'trade_id', 'magic_number', 'symbol', 'strategy_name', 
    'event_type', 'direction', 'lot_size', 'entry_price', 'initial_sl', 
    'initial_tp', 'close_price', 'pnl', 'reason_message'
]

class CsvFormatter(logging.Formatter):
    """Custom formatter to output log records into a CSV format."""
    def __init__(self):
        super().__init__()
        self.output_delimiter = ','

    def format(self, record):
        # Create a dictionary from the log record's extra data
        log_data = record.__dict__.get('log_data', {})
        
        # Ensure all columns are present, fill with empty string if not
        csv_row = [str(log_data.get(col, '')) for col in TRADE_LOG_COLUMNS]
        
        return self.output_delimiter.join(csv_row)

def setup_trade_logger():
    """
    Sets up a logger to record trade events into a CSV file.
    """
    logger = logging.getLogger("TradeJournal")
    logger.setLevel(logging.INFO)

    # --- Avoid adding handlers multiple times ---
    if logger.handlers:
        return logger
        
    log_dir = 'logs'
    os.makedirs(log_dir, exist_ok=True)
    
    # --- File Handler for CSV ---
    log_file_path = os.path.join(log_dir, "trade_journal.csv")
    
    # Check if file exists to write header
    write_header = not os.path.exists(log_file_path)

    file_handler = logging.FileHandler(log_file_path, mode='a')
    file_handler.setFormatter(CsvFormatter())
    logger.addHandler(file_handler)

    # Write header if the file is new
    if write_header:
        file_handler.stream.write(','.join(TRADE_LOG_COLUMNS) + '\n')
        file_handler.stream.flush()

    return logger

# Initialize and export the trade logger
trade_log = setup_trade_logger()

def log_trade_event(event_data):
    """
    Helper function to log a trade event.
    The 'extra' dict is used to pass data to the CsvFormatter.
    """
    # Add timestamp automatically
    event_data['timestamp'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    # We pass the data dictionary in the 'extra' parameter.
    trade_log.info("", extra={'log_data': event_data}) 
import pandas as pd
from utils.logger import log
from strategies.xauusd_m5_strategy import XauUsdM5Strategy
from bot.config import settings
import sys

class MockMT5Connector:
    """
    A mock connector that simulates the real MT5Connector but uses data from a CSV file.
    """
    def __init__(self, csv_filepath):
        log.info(f"Initializing MockMT5Connector with data from '{csv_filepath}'")
        try:
            self.data = pd.read_csv(csv_filepath)
            self.data['time'] = pd.to_datetime(self.data['time'], unit='s')
            self.current_index = 0
            log.info(f"Loaded {len(self.data)} data points.")
        except FileNotFoundError:
            log.error(f"Mock data file not found at '{csv_filepath}'.")
            sys.exit(1)

    def get_market_data(self, symbol, timeframe, count):
        """
        Returns a slice of the historical data to simulate a real-time data feed.
        """
        if self.current_index < count:
            # Not enough historical data to provide
            return None
        
        # Return 'count' rows of data up to the current point in the backtest
        start_index = self.current_index - count
        end_index = self.current_index
        return self.data.iloc[start_index:end_index].copy()

    # --- Mock other methods that the strategy might call ---
    # We don't need them to do anything for a simple logic test.
    def get_symbol_info(self, symbol): return None
    def get_account_info(self): return None
    def get_last_tick(self, symbol): return None
    def place_order(self, *args, **kwargs): log.info("MOCK: place_order called."); return None


def run_local_test():
    """
    Initializes and runs the backtest on the local CSV data.
    """
    log.info("--- Starting Local Backtest ---")

    if not settings:
        log.error("Failed to load settings. Exiting local test.")
        return

    # 1. Load all historical data
    try:
        full_data = pd.read_csv('sample_data.csv')
        full_data['time'] = pd.to_datetime(full_data['time'], unit='s')
        log.info(f"Loaded {len(full_data)} data points for backtest.")
    except FileNotFoundError:
        log.error("Mock data file 'sample_data.csv' not found.")
        return

    # 2. Initialize the Strategy (connector can be None for this test)
    strategy = XauUsdM5Strategy(mt5_connector=None)
    strategy.symbol = settings.Trading.Symbol

    # 3. Loop through the data, simulating the bot's tick
    # We start from a point where we have enough data for the longest indicator
    start_point = settings.Strategy.EMASlow_Period + 2 
    
    for i in range(start_point, len(full_data) + 1):
        # The number of candles to feed into the logic is the same as the live bot
        num_candles_to_feed = settings.Strategy.EMASlow_Period + 50
        
        # Ensure we don't request a slice that goes out of bounds (negative index)
        start_slice = max(0, i - num_candles_to_feed)
        current_df_slice = full_data.iloc[start_slice:i]
        
        current_candle_time = current_df_slice.iloc[-1]['time']
        log.info("="*50)
        log.info(f"Simulating tick, evaluating candle from: {current_candle_time}")

        # 4. Run the core logic on the data slice
        signal_type, signal_candle = strategy.run_logic_on_data(current_df_slice)

        if signal_type:
            log.info(f"\\n*** ---> Signal Found: {signal_type} on candle {signal_candle['time']} <--- ***\\n")

    log.info("--- Local Backtest Finished ---")

if __name__ == "__main__":
    run_local_test() 
import MetaTrader5 as mt5
from utils.logger import log
import pandas as pd
from config import settings

class MT5Connector:
    """
    Handles the connection and data exchange with the MetaTrader 5 terminal.
    """
    def __init__(self, account, password, server):
        self.account = account
        self.password = password
        self.server = server
        self.connected = False

    def connect(self):
        """
        Initialize connection to the MetaTrader 5 terminal.
        """
        log.info("Initializing connection to MetaTrader 5...")
        if not mt5.initialize(login=self.account, password=self.password, server=self.server):
            log.error(f"MT5 initialization failed. Error code: {mt5.last_error()}")
            self.connected = False
            return False
        
        log.info("Successfully connected to MetaTrader 5.")
        self.connected = True
        return True

    def disconnect(self):
        """
        Shutdown connection to the MetaTrader 5 terminal.
        """
        if self.connected:
            mt5.shutdown()
            log.info("MetaTrader 5 connection shut down.")
        self.connected = False

    def get_market_data(self, symbol, timeframe, count):
        """
        Fetch historical candle data.
        
        :param symbol: The financial instrument's symbol (e.g., "XAUUSD").
        :param timeframe: The timeframe for the candles (e.g., mt5.TIMEFRAME_M5).
        :param count: The number of candles to retrieve.
        :return: A pandas DataFrame with the candle data or None on failure.
        """
        if not self.connected:
            log.error("Not connected to MT5. Cannot fetch market data.")
            return None
            
        try:
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, count)
            if rates is None:
                log.error(f"Failed to get rates for {symbol}. Error: {mt5.last_error()}")
                return None
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            return df
        except Exception as e:
            log.error(f"An exception occurred while fetching market data: {e}")
            return None

    def place_order(self, symbol, order_type, volume, price, sl, tp, comment=""):
        """
        Place a new market order.
        
        :param symbol: Symbol to trade.
        :param order_type: mt5.ORDER_TYPE_BUY or mt5.ORDER_TYPE_SELL.
        :param volume: The lot size.
        :param price: The execution price.
        :param sl: The stop loss price.
        :param tp: The take profit price.
        :param comment: A comment for the order.
        :return: The result of the order request.
        """
        if not self.connected:
            log.error("Not connected to MT5. Cannot place order.")
            return None
        
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": settings.Trading.Slippage,
            "magic": settings.Trading.MagicNumber,
            "comment": comment,
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC, # Or FOK depending on broker
        }
        
        result = mt5.order_send(request)
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            log.error(f"Order failed: {result.comment} (retcode: {result.retcode})")
        else:
            log.info(f"Order placed successfully: {result.comment}")
            
        return result

    def get_account_info(self):
        """
        Retrieves account information like balance and equity.
        """
        if not self.connected:
            log.error("Not connected to MT5. Cannot get account info.")
            return None
        return mt5.account_info()

    def get_symbol_info(self, symbol):
        """
        Retrieves symbol properties.
        """
        if not self.connected:
            log.error(f"Not connected to MT5. Cannot get info for {symbol}.")
            return None
        return mt5.symbol_info(symbol)
        
    def get_last_tick(self, symbol):
        """
        Retrieves the latest tick data (bid/ask prices).
        """
        if not self.connected:
            log.error(f"Not connected to MT5. Cannot get last tick for {symbol}.")
            return None
        return mt5.symbol_info_tick(symbol)

    def get_open_positions(self, symbol=None):
        """
        Retrieves all open positions, optionally filtered by symbol.
        """
        if not self.connected:
            log.error("Not connected to MT5. Cannot get open positions.")
            return []
            
        positions = mt5.positions_get(symbol=symbol)
        if positions is None:
            return []
        
        # Return as a list of position objects
        return list(positions)

    def modify_position(self, ticket, sl, tp):
        """
        Modifies the stop loss and take profit of an open position.
        
        :param ticket: The ticket of the position to modify.
        :param sl: The new stop loss price.
        :param tp: The new take profit price.
        :return: The result of the trade request.
        """
        if not self.connected:
            log.error("Not connected to MT5. Cannot modify position.")
            return None

        request = {
            "action": mt5.TRADE_ACTION_SLTP,
            "position": ticket,
            "sl": sl,
            "tp": tp,
            "magic": settings.Trading.MagicNumber,
        }
        
        result = mt5.order_send(request)
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            log.error(f"Failed to modify position {ticket}: {result.comment} (retcode: {result.retcode})")
        else:
            log.info(f"Position {ticket} modified successfully.")
            
        return result

    # Add other necessary methods here, e.g., for modifying/closing trades
    # get_open_trades(), modify_position(), etc. 
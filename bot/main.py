import schedule
import time
import sys
from utils.logger import log
from utils.trade_logger import log_trade_event
from config import settings
from connectors.mt5_connector import MT5Connector
from strategies.xauusd_m5_strategy import XauUsdM5Strategy
from risk_management.position_sizer import calculate_lot_size
from risk_management.trade_manager import TradeManager
import MetaTrader5 as mt5
# Import other necessary modules like TradeManager, position_sizer etc.

# --- Global variables ---
# We define these globally so they can be initialized once in main()
# and used in the trading_bot_tick() function without passing them around.
mt5_connector: MT5Connector = None
strategy: XauUsdM5Strategy = None
timeframe_map = {
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "H1": mt5.TIMEFRAME_H1,
    # Add other timeframes as needed
}

def execute_trade(signal_type, signal_candle):
    """
    Handles the entire process of executing a trade.
    """
    log.info(f"--- Executing {signal_type} Trade ---")
    
    # 1. Log the entry signal reason
    log_trade_event({
        "symbol": settings.Trading.Symbol,
        "strategy_name": "XAUUSD_M5_EMA_RSI",
        "event_type": "SIGNAL_DETECTED",
        "direction": signal_type,
        "reason_message": f"Signal candle at {signal_candle.name} triggered the entry."
    })

    # 2. Get required info
    symbol_info = mt5_connector.get_symbol_info(settings.Trading.Symbol)
    account_info = mt5_connector.get_account_info()
    last_tick = mt5_connector.get_last_tick(settings.Trading.Symbol)
    
    if not all([symbol_info, account_info, last_tick]):
        log.error("Could not retrieve all necessary info for trade execution. Aborting.")
        return

    point = symbol_info.point
    pip_value = settings.RiskManagement.PipDecimalValue

    # 3. Define SL and TP prices
    if signal_type == "BUY":
        sl_price = signal_candle['low'] - (settings.RiskManagement.StopLossBufferPips * 10 * point)
        stop_loss_pips = (last_tick.ask - sl_price) / pip_value
        tp_price = last_tick.ask + (stop_loss_pips * settings.RiskManagement.RiskRewardRatio * pip_value)
        entry_price = last_tick.ask
        order_type = mt5.ORDER_TYPE_BUY
    else: # SELL
        sl_price = signal_candle['high'] + (settings.RiskManagement.StopLossBufferPips * 10 * point)
        stop_loss_pips = (sl_price - last_tick.bid) / pip_value
        tp_price = last_tick.bid - (stop_loss_pips * settings.RiskManagement.RiskRewardRatio * pip_value)
        entry_price = last_tick.bid
        order_type = mt5.ORDER_TYPE_SELL

    # 4. Calculate Lot Size
    lot_size = calculate_lot_size(
        account_balance=account_info.balance,
        risk_percentage=settings.RiskManagement.RiskPercentage,
        stop_loss_pips=stop_loss_pips,
        pip_value_per_lot=settings.RiskManagement.PipValuePerLot
    )

    if lot_size <= 0:
        log.warning(f"Calculated lot size is {lot_size}. Aborting trade.")
        return

    # 5. Place Order
    trade_result = mt5_connector.place_order(
        symbol=settings.Trading.Symbol,
        order_type=order_type,
        volume=lot_size,
        price=entry_price,
        sl=sl_price,
        tp=tp_price,
        comment=f"{signal_type} by Python Bot"
    )

    # 6. Log the execution result
    if trade_result and trade_result.retcode == mt5.TRADE_RETCODE_DONE:
        log_trade_event({
            "trade_id": trade_result.order,
            "magic_number": trade_result.request.magic,
            "symbol": settings.Trading.Symbol,
            "strategy_name": "XAUUSD_M5_EMA_RSI",
            "event_type": "ORDER_PLACED",
            "direction": signal_type,
            "lot_size": lot_size,
            "entry_price": trade_result.price,
            "initial_sl": sl_price,
            "initial_tp": tp_price,
            "reason_message": "Order placed successfully."
        })
    else:
        log_trade_event({
            "symbol": settings.Trading.Symbol,
            "strategy_name": "XAUUSD_M5_EMA_RSI",
            "event_type": "ORDER_FAILED",
            "direction": signal_type,
            "reason_message": f"Failed to place order. Retcode: {trade_result.retcode if trade_result else 'N/A'}"
        })

def trading_bot_tick():
    """
    This function is executed at each scheduled interval.
    """
    log.info("="*50)
    log.info("Bot tick executing...")
    
    open_positions = mt5_connector.get_open_positions(settings.Trading.Symbol)
    
    if len(open_positions) >= settings.Trading.MaxOpenTrades:
        log.info(f"Found {len(open_positions)} open position(s). Managing them...")
        for pos in open_positions:
          manager = TradeManager(mt5_connector, pos)
          manager.run_management()
    else:
        # If NO: Go to Entry Logic
        log.info("No open trades. Checking for new entry signals...")
        signal_type, signal_candle = strategy.check_for_entry()
        if signal_type and not signal_candle.empty:
            execute_trade(signal_type, signal_candle)

def main():
    """
    Main function to initialize and run the trading bot.
    """
    log.info("Starting XAUUSD M5 Trading Bot...")
    
    # Exit if config failed to load
    if not settings:
        sys.exit(1)

    global mt5_connector, strategy
    
    mt5_connector = MT5Connector(
        account=settings.Broker.Account,
        password=settings.Broker.Password,
        server=settings.Broker.Server
    )
    
    if not mt5_connector.connect():
        log.error("Failed to connect to MT5. Exiting application.")
        return # Exit if connection fails

    # Initialize the strategy, passing the correct timeframe enum
    strategy = XauUsdM5Strategy(mt5_connector)
    strategy.timeframe = timeframe_map.get(settings.Trading.Timeframe, mt5.TIMEFRAME_M5)
    strategy.symbol = settings.Trading.Symbol
    
    # --- Scheduling ---
    log.info(f"Scheduling bot tick for every 5 minutes on the clock (e.g., xx:00, xx:05, xx:10)...")
    # This is a more robust way to schedule for every 5th minute of the hour.
    # We schedule a separate job for each 5-minute mark.
    for minute in ["00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"]:
        schedule.every().hour.at(f"{minute}:01").do(trading_bot_tick)

    try:
        # The first run will be handled by the scheduler at the next appropriate time.
        log.info("Bot is running. Waiting for the next scheduled tick...")
        while True:
            schedule.run_pending()
            time.sleep(1)
    except KeyboardInterrupt:
        log.info("Bot stopped by user.")
    finally:
        # Ensure disconnection on exit
        mt5_connector.disconnect()
        log.info("Bot has been shut down gracefully.")


if __name__ == "__main__":
    main() 
from utils.logger import log
from config import settings
# We will need pandas and a library for indicators, e.g., pandas_ta
# For now, we just lay out the structure.
import pandas as pd 
import pandas_ta as ta

class XauUsdM5Strategy:
    """
    Implements the XAUUSD M5 Trend-Following strategy.
    """
    def __init__(self, mt5_connector):
        self.mt5 = mt5_connector
        self.symbol = settings.Trading.Symbol
        self.timeframe = "M5" # Placeholder, will need to be mapped to mt5 enum

    def _calculate_indicators(self, df):
        """
        Calculate and attach all required indicators to the DataFrame.
        """
        log.info("Calculating indicators...")
        df['ema_fast'] = df['close'].ewm(span=settings.Strategy.EMAFast_Period, adjust=False).mean()
        df['ema_slow'] = df['close'].ewm(span=settings.Strategy.EMASlow_Period, adjust=False).mean()
        
        # RSI Calculation
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=settings.Strategy.RSI_Period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=settings.Strategy.RSI_Period).mean()
        rs = gain / loss
        df['rsi'] = 100 - (100 / (1 + rs))

        # ADX Calculation using pandas_ta
        adx_period = settings.Strategy.ADX_Period
        df.ta.adx(length=adx_period, append=True)
        # pandas_ta appends columns like 'ADX_14', let's rename for consistency if needed, but direct access is fine
        
        log.info("Indicators calculated.")
        return df

    def _get_candle_properties(self, candle):
        """Helper function to get candle properties."""
        body_size = abs(candle['close'] - candle['open'])
        total_range = candle['high'] - candle['low']
        if total_range == 0: # Avoid division by zero for doji-like candles
            return 0, 0, 0
        
        upper_wick = candle['high'] - max(candle['open'], candle['close'])
        lower_wick = min(candle['open'], candle['close']) - candle['low']
        return body_size, upper_wick, lower_wick

    def _is_bullish_signal(self, df, index=-2):
        """
        Checks for bullish confirmation candle patterns on the specified candle.
        """
        log.info(f"Checking for bullish signal on candle at {df['time'].iloc[index]}")
        
        candle = df.iloc[index]
        prev_candle = df.iloc[index - 1]

        is_bullish = candle['close'] > candle['open']
        is_prev_bearish = prev_candle['close'] < prev_candle['open']

        # 1. Bullish Engulfing
        is_engulfing = (is_bullish and is_prev_bearish and
                        candle['close'] > prev_candle['open'] and 
                        candle['open'] < prev_candle['close'])
        if is_engulfing:
            log.info(f"Bullish Engulfing pattern found at {candle['time']}.")
            return True

        # 2. Bullish Pin Bar (Hammer)
        body_size, upper_wick, lower_wick = self._get_candle_properties(candle)
        total_range = candle['high'] - candle['low']
        
        is_pin_bar = (total_range > 0 and 
                      body_size < settings.CandlePatterns.PinBar.BodyMaxPercent * total_range and
                      lower_wick > settings.CandlePatterns.PinBar.WickMinPercent * total_range and
                      upper_wick < settings.CandlePatterns.PinBar.OppositeWickMaxPercent * total_range)
        if is_pin_bar:
            log.info(f"Bullish Pin Bar (Hammer) found at {candle['time']}.")
            return True

        return False

    def _is_bearish_signal(self, df, index=-2):
        """
        Checks for bearish confirmation candle patterns on the specified candle.
        """
        log.info(f"Checking for bearish signal on candle at {df['time'].iloc[index]}")

        candle = df.iloc[index]
        prev_candle = df.iloc[index - 1]

        is_bearish = candle['close'] < candle['open']
        is_prev_bullish = prev_candle['close'] > prev_candle['open']

        # 1. Bearish Engulfing
        is_engulfing = (is_bearish and is_prev_bullish and
                        candle['open'] > prev_candle['close'] and
                        candle['close'] < prev_candle['open'])
        if is_engulfing:
            log.info(f"Bearish Engulfing pattern found at {candle['time']}.")
            return True
        
        # 2. Bearish Pin Bar (Shooting Star)
        body_size, upper_wick, lower_wick = self._get_candle_properties(candle)
        total_range = candle['high'] - candle['low']

        is_pin_bar = (total_range > 0 and
                      body_size < settings.CandlePatterns.PinBar.BodyMaxPercent * total_range and
                      upper_wick > settings.CandlePatterns.PinBar.WickMinPercent * total_range and
                      lower_wick < settings.CandlePatterns.PinBar.OppositeWickMaxPercent * total_range)
        if is_pin_bar:
            log.info(f"Bearish Pin Bar (Shooting Star) found at {candle['time']}.")
            return True
            
        return False

    def run_logic_on_data(self, df):
        """
        Runs the core entry signal logic on a given DataFrame.
        This is separated to make local backtesting easier.
        """
        df = self._calculate_indicators(df)
        
        # Not enough data after indicator calculation (e.g. for rolling means)
        if len(df) < 2:
            return None, None

        prev_candle_idx = -2
        signal_candle = df.iloc[prev_candle_idx]
        adx_col = f"ADX_{settings.Strategy.ADX_Period}"

        # --- Enhanced Logging for Traceability ---
        log.info(f"Signal Candle ({signal_candle['time']}): O={signal_candle['open']:.5f}, H={signal_candle['high']:.5f}, L={signal_candle['low']:.5f}, C={signal_candle['close']:.5f}")
        log.info(f"Indicators: EMA_Fast={df['ema_fast'].iloc[prev_candle_idx]:.5f}, EMA_Slow={df['ema_slow'].iloc[prev_candle_idx]:.5f}, RSI={df['rsi'].iloc[prev_candle_idx]:.2f}, ADX={df[adx_col].iloc[prev_candle_idx]:.2f}")

        # --- Check for Long Entry ---
        log.info("--- Checking LONG conditions ---")

        # 1. ADX Filter
        if settings.Strategy.EnableADXFilter:
            is_trending = df[adx_col].iloc[prev_candle_idx] > settings.Strategy.ADX_Threshold
            log.info(f"1. Trend Strength Filter (ADX > {settings.Strategy.ADX_Threshold}): {is_trending}")
        else:
            is_trending = True
            log.info("1. Trend Strength Filter: SKIPPED (disabled in config)")

        # 2. Trend Confirmation
        is_uptrend = (df['ema_fast'].iloc[prev_candle_idx] > df['ema_slow'].iloc[prev_candle_idx] and
                      df['close'].iloc[prev_candle_idx] > df['ema_slow'].iloc[prev_candle_idx])
        log.info(f"2. Trend Confirmation (EMA_Fast > EMA_Slow AND Close > EMA_Slow): {is_uptrend}")
        
        # 3. Pullback Confirmation
        is_pullback = signal_candle['low'] <= df['ema_fast'].iloc[prev_candle_idx]
        log.info(f"3. Pullback Confirmation (Low <= EMA_Fast): {is_pullback}")

        # 4. Candle Pattern Filter
        if settings.Strategy.EnableCandlePatternFilter:
            is_bull_pattern = self._is_bullish_signal(df, prev_candle_idx)
            log.info(f"4. Candle Pattern Confirmation (Bullish Engulfing/Pinbar): {is_bull_pattern}")
        else:
            is_bull_pattern = True
            log.info("4. Candle Pattern Confirmation: SKIPPED (disabled in config)")

        # 5. RSI Filter
        if settings.Strategy.EnableRSIFilter:
            is_rsi_ok = df['rsi'].iloc[prev_candle_idx] < settings.Strategy.RSI_Overbought
            log.info(f"5. RSI Filter (RSI < {settings.Strategy.RSI_Overbought}): {is_rsi_ok}")
        else:
            is_rsi_ok = True
            log.info(f"5. RSI Filter: SKIPPED (disabled in config)")

        if is_trending and is_uptrend and is_pullback and is_bull_pattern and is_rsi_ok:
            log.info(">>>> LONG SIGNAL DETECTED <<<<")
            return "BUY", signal_candle

        # --- Check for Short Entry ---
        log.info("--- Checking SHORT conditions ---")

        # 1. ADX check is the same for short entries
        if settings.Strategy.EnableADXFilter:
            # Re-use the is_trending variable calculated for the long check
            log.info(f"1. Trend Strength Filter (ADX > {settings.Strategy.ADX_Threshold}): {is_trending}")
        else:
            log.info("1. Trend Strength Filter: SKIPPED (disabled in config)")

        # 2. Trend Confirmation
        is_downtrend = (df['ema_fast'].iloc[prev_candle_idx] < df['ema_slow'].iloc[prev_candle_idx] and
                        df['close'].iloc[prev_candle_idx] < df['ema_slow'].iloc[prev_candle_idx])
        log.info(f"2. Trend Confirmation (EMA_Fast < EMA_Slow AND Close < EMA_Slow): {is_downtrend}")

        # 3. Pullback Confirmation
        is_pullback = signal_candle['high'] >= df['ema_fast'].iloc[prev_candle_idx]
        log.info(f"3. Pullback Confirmation (High >= EMA_Fast): {is_pullback}")

        # 4. Candle Pattern Filter
        if settings.Strategy.EnableCandlePatternFilter:
            is_bear_pattern = self._is_bearish_signal(df, prev_candle_idx)
            log.info(f"4. Candle Pattern Confirmation (Bearish Engulfing/Pinbar): {is_bear_pattern}")
        else:
            is_bear_pattern = True
            log.info("4. Candle Pattern Confirmation: SKIPPED (disabled in config)")

        # 5. RSI Filter
        if settings.Strategy.EnableRSIFilter:
            is_rsi_ok = df['rsi'].iloc[prev_candle_idx] > settings.Strategy.RSI_Oversold
            log.info(f"5. RSI Filter (RSI > {settings.Strategy.RSI_Oversold}): {is_rsi_ok}")
        else:
            is_rsi_ok = True
            log.info(f"5. RSI Filter: SKIPPED (disabled in config)")
        
        if is_trending and is_downtrend and is_pullback and is_bear_pattern and is_rsi_ok:
            log.info(">>>> SHORT SIGNAL DETECTED <<<<")
            return "SELL", signal_candle
            
        log.info("No new entry signals found.")
        return None, None

    def check_for_entry(self):
        """
        Main entry logic method. Gets live data and runs the logic.
        """
        log.info("Checking for new trade entry signals...")
        data = self.mt5.get_market_data(self.symbol, self.timeframe, settings.Strategy.EMASlow_Period + 50)
        
        if data is None or len(data) < settings.Strategy.EMASlow_Period:
            log.warning("Not enough market data to proceed.")
            return None, None

        return self.run_logic_on_data(data) 
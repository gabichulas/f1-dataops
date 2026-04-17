import argparse
import fastf1
import os
import sys
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)   

TIME_COLUMNS = [
    'Time', 
    'LapTime', 
    'PitOutTime', 
    'PitInTime', 
    'Sector1Time', 
    'Sector2Time', 
    'Sector3Time', 
    'Sector1SessionTime', 
    'Sector2SessionTime', 
    'Sector3SessionTime', 
    'LapStartTime'
    ]

def main():
    parser = argparse.ArgumentParser(prog="pysync")
    parser.add_argument("year", type=int, help="Year of the session. Example: 2021")
    parser.add_argument("round", type=int, help="Number of round. Example: 1 (Australia GP if you chose year=2025)")
    parser.add_argument("session_type", type=str, choices=['FP1', 'FP2', 'FP3', 'Q', 'S', 'SS', 'SQ', 'R'], help="Type of the session. Example: 'Q' (Qualifying)")
    args = parser.parse_args()
    
    base_path = os.getenv("F1_DATA_PATH", "/tmp/f1_data")
    cache_path = os.getenv("F1_CACHE_PATH", "/tmp/f1_cache")
    
    full_path = os.path.join(base_path, f"year={args.year}/round={args.round}/session_type={args.session_type}/")
    
    try:
        os.makedirs(full_path, exist_ok=True)
        os.makedirs(cache_path, exist_ok=True)
    except OSError as e:
        logging.error(f"Failed to create directories: {e}")
        sys.exit(1)
    
    fastf1.Cache.enable_cache(cache_path)
    
    
    logging.info(f"Fetching session data for {args.year} Round {args.round} ({args.session_type})")
    
    try:
        session = fastf1.get_session(args.year, args.round, args.session_type)
        session.load(laps=True, telemetry=False, weather=False, messages=False)
    except Exception as e:
        logging.error(f"Failed to load session from FastF1 API: {e}")
        sys.exit(1)
    
    df_laps = session.laps.copy()
    
    if df_laps.empty:
        logging.warning("Session loaded but no laps found. Gracefully exiting.")
        sys.exit(0)
    
    for col in TIME_COLUMNS:
        if col in df_laps.columns:
            df_laps[col] = df_laps[col].dt.total_seconds()
    
    df_laps.dropna(axis=1, how='all', inplace=True)
    
    file_name = "data.parquet"
    
    export_path = os.path.join(full_path, file_name)
    
    try:
        df_laps.to_parquet(export_path, engine='pyarrow', compression='snappy')
        logging.info(f"Successfully saved {len(df_laps)} laps to {export_path}")
    except Exception as e:
        logging.error(f"Failed to write Parquet file: {e}")
        sys.exit(1)
    
    
if __name__ == "__main__":
    main()
import argparse
import fastf1
import os


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
    
    base_path = "/tmp/f1_data"
    
    full_path = os.path.join(base_path, f"year={args.year}/round={args.round}/session_type={args.session_type}/")
    
    os.makedirs(full_path, exist_ok=True)
    os.makedirs("/tmp/f1_cache", exist_ok=True)
    
    fastf1.Cache.enable_cache("/tmp/f1_cache")
    
    session = fastf1.get_session(args.year, args.round, args.session_type)
    
    session.load(laps=True, telemetry=False, weather=False, messages=False)
    
    df_laps = session.laps.copy()
    
    
    for col in TIME_COLUMNS:
        if col in df_laps.columns:
            df_laps[col] = df_laps[col].dt.total_seconds()
    
    
    file_name = "data.parquet"
    
    export = os.path.join(full_path, file_name)
    
    df_laps.to_parquet(export, engine='pyarrow', compression='snappy')
    
    print(f"Succesfully saved {len(df_laps)} laps to {export}")
    
    
if __name__ == "__main__":
    main()
import json
import os
from datetime import datetime, timedelta, timezone
from google.cloud import storage
from google.cloud import tasks_v2

PROJECT_ID = os.environ.get("PROJECT_ID")
REGION = os.environ.get("REGION")
BUCKET_NAME = os.environ.get("BUCKET_NAME")
QUEUE_NAME = os.environ.get("QUEUE_NAME")
JOB_NAME = os.environ.get("JOB_NAME")
SERVICE_ACCOUNT_EMAIL = os.environ.get("SERVICE_ACCOUNT_EMAIL")

def schedule_f1_extractions(request):
    storage_client = storage.Client()
    tasks_client = tasks_v2.CloudTasksClient()

    try:
        bucket = storage_client.bucket(BUCKET_NAME)
        blob = bucket.blob("f1_calendar_2026.json")
        calendar_data = json.loads(blob.download_as_string())
    except Exception as e:
        print(f"Error reading calendar from GCS: {e}")
        return f"Internal Server Error: {e}", 500

    now = datetime.now(timezone.utc)
    one_week_from_now = now + timedelta(days=7)
    tasks_created = 0

    for round_num, gp_info in calendar_data.get("calendar", {}).items():
        for session in gp_info.get("sessions", []):
            time_str = session["time"].replace("Z", "+00:00")
            session_time = datetime.fromisoformat(time_str)

            if now <= session_time <= one_week_from_now:
                
                execution_time = session_time + timedelta(hours=2)
                
                enqueue_cloud_run_job(
                    tasks_client, 
                    calendar_data["year"], 
                    round_num, 
                    session["type"], 
                    execution_time
                )
                tasks_created += 1

    msg = f"Success! Enqueued {tasks_created} tasks for the upcoming week."
    print(msg)
    return msg, 200

def enqueue_cloud_run_job(client, year, round_num, session_type, execution_time):

    parent = client.queue_path(PROJECT_ID, REGION, QUEUE_NAME)

    url = f"https://run.googleapis.com/v2/projects/{PROJECT_ID}/locations/{REGION}/jobs/{JOB_NAME}:run"

    payload = {
        "overrides": {
            "containerOverrides": [
                {
                    "args": [str(year), str(round_num), session_type]
                }
            ]
        }
    }

    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": url,
            "headers": {"Content-type": "application/json"},
            "body": json.dumps(payload).encode(),
            "oauth_token": {
                "service_account_email": SERVICE_ACCOUNT_EMAIL
            }
        },
        "schedule_time": {
            "seconds": int(execution_time.timestamp())
        }
    }

    client.create_task(request={"parent": parent, "task": task})
    print(f"Scheduled {year} R{round_num} {session_type} at {execution_time} UTC")
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel, Field
from datetime import datetime
import boto3
import os

print("Starting FastAPI application...")
# Initialize FastAPI
app = FastAPI()


# Environment variables
REGION = os.getenv("REGION" , "us-east-1")
SSM_PARAM_NAME = os.getenv("SSM_PARAM_NAME")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")

# Boto3 clients
ssm_client = boto3.client('ssm', region_name=REGION)
sqs_client = boto3.client('sqs', region_name=REGION)

# Pydantic models
class EmailData(BaseModel):
    email_subject: str
    email_sender: str
    email_timestream: str
    email_content: str

class EmailRequest(BaseModel):
    data: EmailData
    token: str

# Helper: Validate timestamp
def is_valid_timestream(ts: str) -> bool:
    try:
        dt = datetime.utcfromtimestamp(int(ts))
        return True
    except (ValueError, OverflowError):
        return False

# Helper: Retrieve token from SSM
def get_valid_token() -> str:
    response = ssm_client.get_parameter(Name=SSM_PARAM_NAME, WithDecryption=True)
    return response['Parameter']['Value']

@app.get("/health")
async def health_check():
    return {"status": "ok"}


# Main route
@app.post("/")
async def receive_email(req: EmailRequest):
    print("Received request:", req)
    # Step 1: Validate token
    valid_token = get_valid_token()
    if req.token != valid_token:
        raise HTTPException(status_code=401, detail="Invalid token")

    # Step 2: Validate timestamp
    if not is_valid_timestream(req.data.email_timestream):
        raise HTTPException(status_code=400, detail="Invalid or missing email_timestream")

    # Step 3: Send to SQS
    try:
        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=req.data.json()
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"SQS Error: {str(e)}")

    return {"message": "Message forwarded to SQS successfully"}

if __name__ == "__main__":
    ##minor change to trigger  workflow
    print("Starting FastAPI application...") 
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
    

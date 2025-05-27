import os
import time
import boto3
from botocore.exceptions import ClientError
import logging
import uuid



logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration from environment variables
REGION = os.getenv("REGION" , "us-east-1")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL" )
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "microservice-data")
S3_UPLOAD_PATH = os.getenv("S3_UPLOAD_PATH", "uploads/")
POLL_INTERVAL_SECONDS = int(os.getenv("POLL_INTERVAL_SECONDS", "10"))

# Initialize boto3 clients
sqs_client = boto3.client('sqs', region_name='us-east-1')
s3_client = boto3.client('s3' , region_name='us-east-1')    

def upload_message_to_s3(message_body, message_id):
    try:
        # Create a unique file name in S3
        s3_key = f"{S3_UPLOAD_PATH}{message_id}.txt"
        s3_client.put_object(Bucket=S3_BUCKET_NAME, Key=s3_key, Body=message_body.encode('utf-8'))
        logger.info(f"Uploaded message {message_id} to s3://{S3_BUCKET_NAME}/{s3_key}")
        return True
    except ClientError as e:
        logger.error(f"Failed to upload message {message_id} to S3: {e}")
        return False

def delete_message_from_queue(receipt_handle):
    try:
        sqs_client.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=receipt_handle)
        logger.info(f"Deleted message from SQS queue")
    except ClientError as e:
        logger.error(f"Failed to delete message from SQS: {e}")

def poll_sqs_and_upload():
    while True:
        try:
            response = sqs_client.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=10,  # long polling
            )

            messages = response.get('Messages', [])
            if not messages:
                logger.info("No messages received. Waiting for next poll.")
            else:
                for msg in messages:
                    message_body = msg['Body']
                    receipt_handle = msg['ReceiptHandle']
                    message_id = msg.get('MessageId', str(uuid.uuid4()))

                    if upload_message_to_s3(message_body, message_id):
                        delete_message_from_queue(receipt_handle)
        except Exception as e:
            logger.error(f"Error during polling or processing: {e}")

        time.sleep(POLL_INTERVAL_SECONDS)

if __name__ == "__main__":
    if not SQS_QUEUE_URL or not S3_BUCKET_NAME:
        logger.error("SQS_QUEUE_URL and S3_BUCKET_NAME environment variables must be set.")
        exit(1)

    logger.info(f"Starting SQS to S3 microservice polling every {POLL_INTERVAL_SECONDS} seconds.")
    poll_sqs_and_upload()
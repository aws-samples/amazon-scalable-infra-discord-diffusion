import json

from nacl.signing import VerifyKey
from nacl.exceptions import BadSignatureError
import os
import boto3
import requests
import random

lambda_client = boto3.client('lambda')
# Create SQS client
sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
APPLICATION_ID = os.environ.get("APPLICATION_ID")

PUBLIC_KEY = os.environ.get("PUBLIC_KEY") # found on Discord Application -> General Information page
RESPONSE_TYPES =  { 
                    "PONG": 1, 
                    "CHANNEL_MESSAGE_WITH_SOURCE": 4,
                    "DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE": 5,
                    "DEFERRED_UPDATE_MESSAGE": 6,
                    "UPDATE_MESSAGE": 7,
                    "APPLICATION_COMMAND_AUTOCOMPLETE_RESULT": 8,
                    "MODAL": 9
                  }

def sendSQSMessage(customer_data, it_id, it_token, user_id, username, application_id):
    # Send message to SQS queue
    MyMessageAttributes = {}
    for customer_request in customer_data:
        MyMessageAttributes[customer_request] = {
                'DataType': 'String',
                'StringValue': str(customer_data[customer_request])
            }
    if "negative_prompt" in MyMessageAttributes:
        MyMessageAttributes['prompt']['StringValue'] = f"{MyMessageAttributes['prompt']['StringValue']}###{MyMessageAttributes['negative_prompt']['StringValue']}"
    MyMessageAttributes.update({
        'interactionId': {
            'DataType': 'String',
            'StringValue': str(it_id)
        },
        'interactionToken': {
            'DataType': 'String',
            'StringValue': str(it_token)
        },
        'userId': {
            'DataType': 'Number',
            'StringValue': str(user_id)
        },
        'username': {
            'DataType': 'String',
            'StringValue': str(username)
        },
        'applicationId': {
            'DataType': 'String',
            'StringValue': str(application_id)
        },
    })
    # print(MyMessageAttributes)
    response = sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageAttributes=MyMessageAttributes,
        MessageBody=json.dumps(MyMessageAttributes),
        # Each request gets processed randomly
        # MessageGroupId=f'{user_id}{random.randint(0,99999)}'
        # Each request is processed one at a time for a user. Multiple user requests are processed at once if > 1 machine.
        MessageGroupId=user_id
    )
    # print(response['MessageId'])
    return MyMessageAttributes

def verify_signature(event):
    raw_body = event.get("body")
    auth_sig = event['headers'].get('x-signature-ed25519')
    auth_ts  = event['headers'].get('x-signature-timestamp')
    
    message = auth_ts.encode() + raw_body.encode()
    verify_key = VerifyKey(bytes.fromhex(PUBLIC_KEY))
    verify_key.verify(message, bytes.fromhex(auth_sig)) # raises an error if unequal

def ping_pong(body):
    if body.get("type") == 1:
        return True
    return False
    
def getCustomerData(discord_raw):
    customer_data = {}
    for customer_input in range(0, len(discord_raw['data']['options'])):
        customer_data[discord_raw['data']['options'][customer_input]['name']] = discord_raw['data']['options'][customer_input]['value']
    return customer_data

def validateRequest(r):
    if not r.ok:
        print("Failure")
        raise Exception(r.text)
    else:
        print("Success")
    return

def messageResponse(customer_data):
    message_response = f"\nPrompt: {customer_data['prompt']}"
    if 'negative_prompt' in customer_data:
        message_response += f"\nNegative Prompt: {customer_data['negative_prompt']}"
    if 'seed' in customer_data:
        message_response += f"\nSeed: {customer_data['seed']}"
    if 'steps' in customer_data:
        message_response += f"\nSteps: {customer_data['steps']}"
    if 'sampler' in customer_data:
        message_response += f"\nSampler: {customer_data['sampler']}"
    return message_response

def lambda_handler(event, context):
    print(f"{event}") # debug print
    # verify the signature
    try:
        verify_signature(event)
    except Exception as e:
        print("[UNAUTHORIZED] Invalid request signature")
        return {
            "statusCode": 401,
            "body": "invalid request signature"
        }
        
    # check if message is a ping
    body = json.loads(event['body'])
    # print(body)
    if body.get("type") == 1:
        print("PONG")
        return {'type': 1}
    
    # Collect customer data
    info = json.loads(event.get("body"))
    # print(info)
    customer_data = getCustomerData(info)
    
    # Trigger async lambda for picture generation
    # print(f"Payload = {info}")
    # lambda_client.invoke(FunctionName='discord_stable_diffusion_backend',
                        #  InvocationType='Event',
                        #  Payload=json.dumps(info))
    
    # Send work to SQS Queue
    it_id = info['id']  
    it_token = info['token']
    user_id = info['member']['user']['id']
    username = info['member']['user']['username']
    sendSQSMessage(customer_data, it_id,it_token, user_id, username, APPLICATION_ID)
    message_response = messageResponse(customer_data)
    # Respond to user
    print("Going to return some data!")
    return {
            "type": RESPONSE_TYPES['CHANNEL_MESSAGE_WITH_SOURCE'],
            "data": {
                "tts": False,
                "content": f"Submitted to Sparkle```{message_response}```",
                "embeds": [],
                "allowed_mentions": { "parse": [] }
            }
        }
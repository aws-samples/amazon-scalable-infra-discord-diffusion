import boto3
import os
import math
from datetime import datetime
from dateutil import tz

# Leave outside of Lambda to benefit from globals
SQS_QUEUE_NAME = os.environ.get("SQS_QUEUE_NAME")
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
ACCOUNT_ID = os.environ.get("ACCOUNT_ID")
ECS_SERVICE_NAME = os.environ.get("ECS_SERVICE_NAME")
ECS_CLUSTER = os.environ.get("ECS_CLUSTER")
LATENCY_SECONDS =  os.environ.get("LATENCY_SECONDS")
TIME_PER_MESSAGE =  os.environ.get("TIME_PER_MESSAGE")

sqs = boto3.client('sqs')
cw = boto3.client('cloudwatch')
ecs = boto3.client('ecs')
    
def lambda_handler(event, context):
    acceptablebacklogpercapacityunit = int((int(LATENCY_SECONDS) / float(TIME_PER_MESSAGE)))
    response = ecs.describe_services(cluster=ECS_CLUSTER, services=[ECS_SERVICE_NAME])
    # Get correct service
    service_num = 0
    for service_i in range(0, len(response['services'])):
        if response['services'][service_i]['serviceName'] == ECS_SERVICE_NAME:
            service_num = service_i
            break
        
    # Set the desired task count by running-count and pending-count. If its pending, its trying to be desired!
    try:    
        desired_task_count = int(response['services'][service_num]['runningCount']) + int(response['services'][service_num]['pendingCount'])
        print(f"Current ECS Task(s): {desired_task_count}")
    except IndexError:
        desired_task_count = 0
        print("[WARNING]: Service is not available, defaulting Task to 0.")
    num_messages = sqs.get_queue_attributes(QueueUrl=SQS_QUEUE_URL, AttributeNames=['ApproximateNumberOfMessages', 'ApproximateNumberOfMessagesNotVisible'])
    datapoint_for_sqs_attribute = int(num_messages['Attributes']['ApproximateNumberOfMessages']) + int(num_messages['Attributes']['ApproximateNumberOfMessagesNotVisible'])
    
    print(f"Queue Message(s): {datapoint_for_sqs_attribute}")
    
    desired_num_tasks = math.ceil(datapoint_for_sqs_attribute/acceptablebacklogpercapacityunit)
    print(f"Desired Task(s): {desired_num_tasks}")
    scale_adjustment = desired_num_tasks - desired_task_count
    print(f"Required Adjustment of Task(s): {scale_adjustment}")

    publishCWMetric('SQS', SQS_QUEUE_NAME, 'ApproximateNumberOfMessages', int(datapoint_for_sqs_attribute), cw)
    publishCWMetric('SQS', SQS_QUEUE_NAME, 'ScaleAdjustmentTaskCount', scale_adjustment, cw)
    publishCWMetric('SQS', SQS_QUEUE_NAME, 'DesiredTasks', desired_num_tasks, cw)
    return


def publishCWMetric(dimension, dimension_value, metric, metric_val, cw):
    cw.put_metric_data(
        Namespace='SQS AutoScaling',
        MetricData=[{
            'MetricName': metric,
            'Dimensions': [{
                'Name': dimension,
                'Value': dimension_value
            }],
            'Timestamp': datetime.now(tz.tzlocal()),
            'Value': metric_val
        }]
    )
    return
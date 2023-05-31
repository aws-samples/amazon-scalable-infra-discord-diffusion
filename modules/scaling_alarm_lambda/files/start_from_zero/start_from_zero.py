import json
import boto3
import os

sqs_client = boto3.client('sqs')
client = boto3.client('autoscaling')
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
AUTOSCALING_GROUP = os.environ.get("AUTOSCALING_GROUP")

### Spin up an EC2 from the autoscaling group if there are no messages in the queue.
def lambda_handler(event, context):
    message_count = sqs_client.get_queue_attributes(QueueUrl=SQS_QUEUE_URL, AttributeNames=['ApproximateNumberOfMessages', 'ApproximateNumberOfMessagesNotVisible'])
    message_count = int(message_count['Attributes']['ApproximateNumberOfMessages']) + int(message_count['Attributes']['ApproximateNumberOfMessagesNotVisible'])
    # Describe autoscaling group
    response = client.describe_auto_scaling_groups(
        AutoScalingGroupNames=[
            AUTOSCALING_GROUP,
        ],
        # NextToken='string',
        # MaxRecords=123,
        # Filters=[
        #     {
        #         'Name': 'AutoScalingGroupName',
        #         'Values': [
        #             autoscaling_group,
        #         ]
        #     },
        # ]
    )
    asg_desired_capacity = response["AutoScalingGroups"][0]['DesiredCapacity']

    # First message and asg has no capacity. 
    if int(message_count) > 0 and asg_desired_capacity == 0:
        # Starting from Zero is true!
        response = client.set_desired_capacity(
            AutoScalingGroupName=AUTOSCALING_GROUP,
            DesiredCapacity=1,
            # HonorCooldown=True
        )
        print("Set ASG Desired Capacity to 1")
        return True
    return False

# This file contains the code to delete a task from the DynamoDB table. 
# The code is similar to the create_task.py file, but instead of inserting data into the table, 
# it deletes a task based on the task_id provided in the request. 
# The response message indicates whether the task was deleted successfully or not.

import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tasks-table')

def lambda_handler(event, context):
    task_id = event['pathParameters']['task_id']

    response = table.delete_item(
        Key={'task_id': task_id},
        ReturnValues="ALL_OLD"
    )

    if 'Attributes' in response:
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Task deleted successfully'})
        }
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'Task not found'})
        }

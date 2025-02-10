# This function retrieves a task from the DynamoDB table based on the task_id provided in the URL path.
# If the task is found, it returns the task details along with a success message.
# If the task is not found, it returns a 404 status code with an error message.

import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tasks-table')

def lambda_handler(event, context):
    task_id = event['pathParameters']['task_id']  # Extract task_id from URL path
    
    response = table.get_item(Key={'task_id': task_id})

    if 'Item' in response:
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Task retrieved successfully',
                'task': response['Item']
            })
        }
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'Task not found'})
        }

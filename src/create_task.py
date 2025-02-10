import json
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tasks-table')

def lambda_handler(event, context):
    try:
        data = json.loads(event.get('body', "{}"))
        # Generate a unique task_id and timestamp for the new task
        task_id =  data.get('task_id')
        timestamp = datetime.now(timezone.utc).isoformat()

        if not task_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'task_id is required'})
            }

        # Insert new tasks into the DynamoDB table with default values
        table.put_item(
            Item={
                    'task_id': task_id,
                    'title': data.get('title', 'Untitled Task'),
                    'description': data.get('description', ''),
                    'status': data.get('status', 'pending'),
                    'priority': data.get('priority', 'medium'),
                    'created_at': timestamp,
                    'updated_at': timestamp,
                    'due_date': data.get('due_date', "N/A"),
                    'assigned_to': data.get('assigned_to', None),
                    'category': data.get('category', 'general'),
                    'tags': data.get('tags', []),
                    'attachments': data.get('attachments', [])
                }
            )

        return {
                'statusCode': 201,
                'body': json.dumps({'task_id': task_id, 'message': 'Task created successfully'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'message': 'Error creating task: {}'.format(str(e))})
        }
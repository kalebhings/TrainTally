"""
Join Group Lambda Function
Join a group using an invite code
"""
import json
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
groups_table = dynamodb.Table(os.environ['GROUPS_TABLE'])

def lambda_handler(event, context):
    """
    Join a group with invite code
    
    Expected body:
    {
        "inviteCode": "ABC123XY"
    }
    """
    try:
        # Extract user ID from Cognito JWT
        user_id = event['requestContext']['authorizer']['claims']['sub']
        username = event['requestContext']['authorizer']['claims'].get('name', 'Unknown')
        
        # Parse request body
        body = json.loads(event['body'])
        
        # Validate required fields
        if 'inviteCode' not in body:
            return error_response(400, "Missing required field: inviteCode")
        
        invite_code = body['inviteCode'].strip().upper()
        
        # Find group by invite code
        response = groups_table.query(
            IndexName='InviteCodeIndex',
            KeyConditionExpression='inviteCode = :code',
            ExpressionAttributeValues={':code': invite_code}
        )
        
        if not response['Items']:
            return error_response(404, "Invalid invite code")
        
        group = response['Items'][0]
        group_id = group['groupId']
        
        # Check if user is already a member
        if user_id in group.get('members', []):
            return error_response(409, "You are already a member of this group")
        
        # Add user to group
        groups_table.update_item(
            Key={'groupId': group_id},
            UpdateExpression='SET members = list_append(members, :user), memberDetails.#uid = :details, updatedAt = :updated',
            ExpressionAttributeNames={'#uid': user_id},
            ExpressionAttributeValues={
                ':user': [user_id],
                ':details': {
                    'username': username,
                    'joinedAt': datetime.utcnow().isoformat(),
                    'role': 'member'
                },
                ':updated': datetime.utcnow().isoformat()
            }
        )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'message': 'Successfully joined group',
                'groupId': group_id,
                'groupName': group['groupName']
            })
        }
        
    except KeyError as e:
        return error_response(401, f"Unauthorized: Missing claim {str(e)}")
    except json.JSONDecodeError:
        return error_response(400, "Invalid JSON in request body")
    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(500, "Internal server error")


def cors_headers():
    """CORS headers for response"""
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }


def error_response(status_code, message):
    """Format error response"""
    return {
        'statusCode': status_code,
        'headers': cors_headers(),
        'body': json.dumps({'error': message})
    }

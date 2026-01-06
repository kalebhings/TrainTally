"""
Create Group Lambda Function
Creates a new family/friend group with invite code
"""
import json
import os
import boto3
import uuid
import random
import string
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
groups_table = dynamodb.Table(os.environ['GROUPS_TABLE'])

def lambda_handler(event, context):
    """
    Create a new group
    
    Expected body:
    {
        "groupName": "Smith Family",
        "description": "Our family game nights",
        "isPrivate": true
    }
    """
    try:
        # Extract user ID from Cognito JWT
        user_id = event['requestContext']['authorizer']['claims']['sub']
        username = event['requestContext']['authorizer']['claims'].get('name', 'Unknown')
        
        # Parse request body
        body = json.loads(event['body'])
        
        # Validate required fields
        if 'groupName' not in body:
            return error_response(400, "Missing required field: groupName")
        
        group_name = body['groupName'].strip()
        if len(group_name) < 3 or len(group_name) > 50:
            return error_response(400, "Group name must be between 3 and 50 characters")
        
        # Generate group ID and invite code
        group_id = str(uuid.uuid4())
        invite_code = generate_invite_code()
        
        # Create group record
        group_record = {
            'groupId': group_id,
            'groupName': group_name,
            'description': body.get('description', ''),
            'isPrivate': body.get('isPrivate', True),
            'inviteCode': invite_code,
            'ownerId': user_id,
            'members': [user_id],
            'memberDetails': {
                user_id: {
                    'username': username,
                    'joinedAt': datetime.utcnow().isoformat(),
                    'role': 'owner'
                }
            },
            'createdAt': datetime.utcnow().isoformat(),
            'updatedAt': datetime.utcnow().isoformat()
        }
        
        # Store in DynamoDB
        groups_table.put_item(Item=group_record)
        
        return {
            'statusCode': 201,
            'headers': cors_headers(),
            'body': json.dumps({
                'message': 'Group created successfully',
                'groupId': group_id,
                'inviteCode': invite_code,
                'group': {
                    'groupId': group_id,
                    'groupName': group_name,
                    'description': group_record['description'],
                    'inviteCode': invite_code,
                    'memberCount': 1
                }
            })
        }
        
    except KeyError as e:
        return error_response(401, f"Unauthorized: Missing claim {str(e)}")
    except json.JSONDecodeError:
        return error_response(400, "Invalid JSON in request body")
    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(500, "Internal server error")


def generate_invite_code():
    """Generate a unique 8-character invite code"""
    # Use uppercase letters and numbers, excluding similar-looking characters (0, O, I, 1)
    chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'
    return ''.join(random.choice(chars) for _ in range(8))


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

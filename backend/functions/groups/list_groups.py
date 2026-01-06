"""
List Groups Lambda Function
Get all groups a user belongs to
"""
import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
groups_table = dynamodb.Table(os.environ['GROUPS_TABLE'])

def lambda_handler(event, context):
    """
    List all groups the user is a member of
    """
    try:
        # Extract user ID from Cognito JWT
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Query groups using UserGroupsIndex
        response = groups_table.query(
            IndexName='UserGroupsIndex',
            KeyConditionExpression='userId = :uid',
            ExpressionAttributeValues={':uid': user_id}
        )
        
        # Format groups
        groups = []
        for item in response['Items']:
            member_details = item.get('memberDetails', {})
            user_role = member_details.get(user_id, {}).get('role', 'member')
            
            groups.append({
                'groupId': item['groupId'],
                'groupName': item['groupName'],
                'description': item.get('description', ''),
                'memberCount': len(item.get('members', [])),
                'role': user_role,
                'inviteCode': item['inviteCode'] if user_role == 'owner' else None,
                'createdAt': item['createdAt']
            })
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'groups': groups,
                'count': len(groups)
            })
        }
        
    except KeyError as e:
        return error_response(401, f"Unauthorized: Missing claim {str(e)}")
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

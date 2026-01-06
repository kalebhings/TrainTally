"""
Get Group Leaderboard Lambda Function
Retrieves leaderboards for a specific family/friend group
"""
import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
leaderboards_table = dynamodb.Table(os.environ['LEADERBOARDS_TABLE'])
groups_table = dynamodb.Table(os.environ['GROUPS_TABLE'])

def lambda_handler(event, context):
    """
    Get group leaderboards
    
    Path parameters:
    - groupId: The group ID
    
    Query parameters:
    - gameVersion: Filter by game version (optional)
    - limit: Number of entries to return (default: 50, max: 100)
    """
    try:
        # Extract user ID from Cognito JWT
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Get group ID from path
        group_id = event['pathParameters']['groupId']
        
        # Verify user is member of this group
        if not is_group_member(user_id, group_id):
            return error_response(403, "You are not a member of this group")
        
        # Parse query parameters
        params = event.get('queryStringParameters') or {}
        game_version = params.get('gameVersion', 'all')
        limit = min(int(params.get('limit', 50)), 100)
        
        # Build leaderboard type key
        leaderboard_type = f"group:{group_id}:{game_version}"
        
        # Query leaderboards
        response = leaderboards_table.query(
            IndexName='ScoreIndex',
            KeyConditionExpression='leaderboardType = :type',
            ExpressionAttributeValues={':type': leaderboard_type},
            ScanIndexForward=False,  # Highest scores first
            Limit=limit
        )
        
        # Format entries
        entries = []
        for rank, item in enumerate(response['Items'], start=1):
            entries.append({
                'rank': rank,
                'userId': item['userId'],
                'username': item.get('username', 'Anonymous'),
                'score': float(item['score']),
                'gamesPlayed': int(item.get('gamesPlayed', 0)),
                'wins': int(item.get('wins', 0)),
                'averageScore': float(item.get('averageScore', 0)),
                'lastUpdated': item.get('lastUpdated')
            })
        
        # Get group details
        group = groups_table.get_item(Key={'groupId': group_id})
        group_name = group.get('Item', {}).get('groupName', 'Unknown Group')
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'groupId': group_id,
                'groupName': group_name,
                'gameVersion': game_version,
                'entries': entries,
                'count': len(entries)
            })
        }
        
    except KeyError as e:
        return error_response(400, f"Missing required parameter: {str(e)}")
    except ValueError:
        return error_response(400, "Invalid query parameters")
    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(500, "Internal server error")


def is_group_member(user_id, group_id):
    """Check if user is a member of the group"""
    try:
        response = groups_table.get_item(Key={'groupId': group_id})
        if 'Item' not in response:
            return False
        
        members = response['Item'].get('members', [])
        return user_id in members
    except Exception as e:
        print(f"Error checking group membership: {str(e)}")
        return False


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

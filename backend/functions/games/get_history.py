"""
Get Game History Lambda Function
Retrieves user's game history with pagination
"""
import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
games_table = dynamodb.Table(os.environ['GAMES_TABLE'])

def lambda_handler(event, context):
    """
    Get user's game history
    
    Query parameters:
    - limit: Number of games to return (default: 20, max: 100)
    - lastKey: Pagination token from previous response
    - gameVersion: Filter by game version (optional)
    """
    try:
        # Extract user ID from Cognito JWT
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Parse query parameters
        params = event.get('queryStringParameters') or {}
        limit = min(int(params.get('limit', 20)), 100)
        last_key = params.get('lastKey')
        game_version = params.get('gameVersion')
        
        # Build query
        query_params = {
            'KeyConditionExpression': 'userId = :uid',
            'ExpressionAttributeValues': {':uid': user_id},
            'ScanIndexForward': False,  # Most recent first
            'Limit': limit
        }
        
        # Add pagination token if provided
        if last_key:
            query_params['ExclusiveStartKey'] = json.loads(last_key)
        
        # Execute query
        if game_version:
            # Use GameVersionIndex for filtering
            query_params['IndexName'] = 'GameVersionIndex'
            query_params['KeyConditionExpression'] = 'gameVersion = :gv'
            query_params['ExpressionAttributeValues'] = {':gv': game_version}
            response = games_table.query(**query_params)
        else:
            # Use TimestampIndex for chronological order
            query_params['IndexName'] = 'TimestampIndex'
            response = games_table.query(**query_params)
        
        # Convert Decimal to float for JSON serialization
        games = convert_decimals_to_float(response['Items'])
        
        # Prepare response
        result = {
            'games': games,
            'count': len(games)
        }
        
        # Add pagination token if more results exist
        if 'LastEvaluatedKey' in response:
            result['lastKey'] = json.dumps(response['LastEvaluatedKey'])
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps(result)
        }
        
    except KeyError as e:
        return error_response(401, f"Unauthorized: Missing claim {str(e)}")
    except ValueError:
        return error_response(400, "Invalid query parameters")
    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(500, "Internal server error")


def convert_decimals_to_float(obj):
    """Convert Decimal to float for JSON serialization"""
    if isinstance(obj, list):
        return [convert_decimals_to_float(item) for item in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimals_to_float(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj


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

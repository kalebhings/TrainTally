"""
Submit Game Lambda Function
Handles submission of completed games to DynamoDB
"""
import json
import os
import boto3
from datetime import datetime
from decimal import Decimal
import uuid

dynamodb = boto3.resource('dynamodb')
games_table = dynamodb.Table(os.environ['GAMES_TABLE'])

def lambda_handler(event, context):
    """
    Submit a completed game
    
    Expected body:
    {
        "gameVersion": "usa_1910",
        "players": [
            {
                "name": "John",
                "color": "red",
                "score": 142,
                "trainCarsUsed": 43,
                "destinationTickets": [
                    {"description": "Seattle to New York", "points": 22, "completed": true}
                ],
                "routePoints": 98,
                "bonuses": [{"id": "longest_route", "points": 10}]
            }
        ],
        "datePlayed": "2026-01-06T19:30:00Z",
        "shareWithGroups": ["group-id-1", "group-id-2"]
    }
    """
    try:
        # Extract user ID from Cognito JWT
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Parse request body
        body = json.loads(event['body'])
        
        # Validate required fields
        required_fields = ['gameVersion', 'players']
        for field in required_fields:
            if field not in body:
                return error_response(400, f"Missing required field: {field}")
        
        if len(body['players']) < 2:
            return error_response(400, "Game must have at least 2 players")
        
        # Generate game ID
        game_id = str(uuid.uuid4())
        timestamp = int(datetime.utcnow().timestamp() * 1000)
        
        # Prepare game record
        game_record = {
            'userId': user_id,
            'gameId': game_id,
            'timestamp': timestamp,
            'gameVersion': body['gameVersion'],
            'players': convert_floats_to_decimal(body['players']),
            'datePlayed': body.get('datePlayed', datetime.utcnow().isoformat()),
            'shareWithGroups': body.get('shareWithGroups', []),
            'winner': get_winner(body['players']),
            'createdAt': datetime.utcnow().isoformat(),
            'updatedAt': datetime.utcnow().isoformat()
        }
        
        # Store in DynamoDB
        games_table.put_item(Item=game_record)
        
        return {
            'statusCode': 201,
            'headers': cors_headers(),
            'body': json.dumps({
                'message': 'Game submitted successfully',
                'gameId': game_id,
                'timestamp': timestamp
            })
        }
        
    except KeyError as e:
        return error_response(401, f"Unauthorized: Missing claim {str(e)}")
    except json.JSONDecodeError:
        return error_response(400, "Invalid JSON in request body")
    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(500, "Internal server error")


def get_winner(players):
    """Determine the winner (player with highest score)"""
    if not players:
        return None
    winner = max(players, key=lambda p: p.get('score', 0))
    return {
        'name': winner['name'],
        'score': winner['score'],
        'color': winner.get('color', '')
    }


def convert_floats_to_decimal(obj):
    """Convert floats to Decimal for DynamoDB"""
    if isinstance(obj, list):
        return [convert_floats_to_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {k: convert_floats_to_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
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

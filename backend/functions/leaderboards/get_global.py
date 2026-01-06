"""
Get Global Leaderboard Lambda Function
Retrieves global leaderboards across all users
"""
import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
leaderboards_table = dynamodb.Table(os.environ['LEADERBOARDS_TABLE'])

def lambda_handler(event, context):
    """
    Get global leaderboards
    
    Query parameters:
    - gameVersion: Filter by game version (optional, default: all versions)
    - limit: Number of entries to return (default: 50, max: 100)
    - timeframe: all|month|week (default: all)
    """
    try:
        # Parse query parameters
        params = event.get('queryStringParameters') or {}
        game_version = params.get('gameVersion', 'all')
        limit = min(int(params.get('limit', 50)), 100)
        timeframe = params.get('timeframe', 'all')
        
        # Build leaderboard type key
        leaderboard_type = f"global:{game_version}:{timeframe}"
        
        # Query leaderboards using ScoreIndex (sorted by score descending)
        response = leaderboards_table.query(
            IndexName='ScoreIndex',
            KeyConditionExpression='leaderboardType = :type',
            ExpressionAttributeValues={':type': leaderboard_type},
            ScanIndexForward=False,  # Highest scores first
            Limit=limit
        )
        
        # Convert Decimal to float and format entries
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
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'leaderboardType': leaderboard_type,
                'gameVersion': game_version,
                'timeframe': timeframe,
                'entries': entries,
                'count': len(entries)
            })
        }
        
    except ValueError:
        return error_response(400, "Invalid query parameters")
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

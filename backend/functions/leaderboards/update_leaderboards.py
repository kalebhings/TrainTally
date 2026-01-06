"""
Update Leaderboards Lambda Function
Triggered by DynamoDB stream when new games are submitted
"""
import json
import os
import boto3
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
leaderboards_table = dynamodb.Table(os.environ['LEADERBOARDS_TABLE'])
groups_table = dynamodb.Table(os.environ['GROUPS_TABLE'])

def lambda_handler(event, context):
    """
    Process DynamoDB stream events to update leaderboards
    """
    try:
        for record in event['Records']:
            if record['eventName'] == 'INSERT':
                # New game submitted
                game = record['dynamodb']['NewImage']
                update_leaderboards_for_game(game)
        
        return {'statusCode': 200, 'body': 'Leaderboards updated'}
    
    except Exception as e:
        print(f"Error updating leaderboards: {str(e)}")
        raise


def update_leaderboards_for_game(game_data):
    """Update global and group leaderboards for a new game"""
    # Parse game data
    user_id = game_data['userId']['S']
    game_version = game_data['gameVersion']['S']
    players = deserialize_dynamodb(game_data['players'])
    share_with_groups = game_data.get('shareWithGroups', {}).get('L', [])
    
    # Find the submitting user's score
    user_player = None
    is_winner = False
    
    for player in players:
        # Assuming the first player or player matching some criteria is the submitting user
        # You might need to add a field to identify which player is the submitting user
        if not user_player:
            user_player = player
            is_winner = player == game_data['winner']['M']
    
    if not user_player:
        return
    
    score = int(user_player.get('score', 0))
    
    # Update global leaderboard
    update_leaderboard_entry(
        leaderboard_type=f"global:{game_version}:all",
        user_id=user_id,
        score=score,
        is_winner=is_winner
    )
    
    # Update group leaderboards
    for group_item in share_with_groups:
        group_id = group_item['S']
        update_leaderboard_entry(
            leaderboard_type=f"group:{group_id}:{game_version}",
            user_id=user_id,
            score=score,
            is_winner=is_winner
        )


def update_leaderboard_entry(leaderboard_type, user_id, score, is_winner):
    """Update or create a leaderboard entry"""
    try:
        # Get existing entry
        response = leaderboards_table.get_item(
            Key={
                'leaderboardType': leaderboard_type,
                'userId': user_id
            }
        )
        
        if 'Item' in response:
            # Update existing entry
            item = response['Item']
            games_played = int(item.get('gamesPlayed', 0)) + 1
            wins = int(item.get('wins', 0)) + (1 if is_winner else 0)
            total_score = float(item.get('score', 0)) * (games_played - 1) + score
            avg_score = total_score / games_played
            
            leaderboards_table.update_item(
                Key={
                    'leaderboardType': leaderboard_type,
                    'userId': user_id
                },
                UpdateExpression='SET score = :score, gamesPlayed = :gp, wins = :wins, averageScore = :avg, lastUpdated = :lu',
                ExpressionAttributeValues={
                    ':score': Decimal(str(avg_score)),  # Use average as score for ranking
                    ':gp': games_played,
                    ':wins': wins,
                    ':avg': Decimal(str(avg_score)),
                    ':lu': datetime.utcnow().isoformat()
                }
            )
        else:
            # Create new entry
            leaderboards_table.put_item(
                Item={
                    'leaderboardType': leaderboard_type,
                    'userId': user_id,
                    'score': Decimal(str(score)),
                    'gamesPlayed': 1,
                    'wins': 1 if is_winner else 0,
                    'averageScore': Decimal(str(score)),
                    'lastUpdated': datetime.utcnow().isoformat()
                }
            )
    
    except Exception as e:
        print(f"Error updating leaderboard entry: {str(e)}")
        raise


def deserialize_dynamodb(obj):
    """Convert DynamoDB stream format to Python objects"""
    if isinstance(obj, dict):
        if 'L' in obj:
            return [deserialize_dynamodb(item) for item in obj['L']]
        elif 'M' in obj:
            return {k: deserialize_dynamodb(v) for k, v in obj['M'].items()}
        elif 'S' in obj:
            return obj['S']
        elif 'N' in obj:
            return float(obj['N'])
        elif 'BOOL' in obj:
            return obj['BOOL']
        elif 'NULL' in obj:
            return None
        else:
            return {k: deserialize_dynamodb(v) for k, v in obj.items()}
    else:
        return obj

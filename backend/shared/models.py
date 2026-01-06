"""
Data models for TrainTally backend
"""
from typing import List, Optional, Dict, Any
from dataclasses import dataclass, asdict
from datetime import datetime
from enum import Enum


class GameVersion(str, Enum):
    """Supported game versions"""
    USA_BASE = "usa_base"
    USA_1910 = "usa_1910"
    GERMANY = "germany"
    OLD_WEST = "old_west"


class PlayerColor(str, Enum):
    """Available player colors"""
    RED = "red"
    BLUE = "blue"
    GREEN = "green"
    YELLOW = "yellow"
    BLACK = "black"
    PURPLE = "purple"


@dataclass
class DestinationTicket:
    """Represents a destination ticket"""
    description: str
    points: int
    completed: bool
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class Bonus:
    """Represents a bonus (e.g., longest route)"""
    id: str
    points: int
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class Player:
    """Represents a player in a game"""
    name: str
    color: str
    score: int
    trainCarsUsed: int
    destinationTickets: List[DestinationTicket]
    routePoints: int
    bonuses: List[Bonus]
    meeplePoints: Optional[int] = 0
    
    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data['destinationTickets'] = [t.to_dict() for t in self.destinationTickets]
        data['bonuses'] = [b.to_dict() for b in self.bonuses]
        return data


@dataclass
class GameSession:
    """Represents a completed game session"""
    userId: str
    gameId: str
    timestamp: int
    gameVersion: str
    players: List[Player]
    datePlayed: str
    shareWithGroups: List[str]
    winner: Dict[str, Any]
    createdAt: str
    updatedAt: str
    
    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data['players'] = [p.to_dict() for p in self.players]
        return data


@dataclass
class Group:
    """Represents a family/friend group"""
    groupId: str
    groupName: str
    description: str
    isPrivate: bool
    inviteCode: str
    ownerId: str
    members: List[str]
    memberDetails: Dict[str, Dict[str, Any]]
    createdAt: str
    updatedAt: str
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class LeaderboardEntry:
    """Represents a leaderboard entry"""
    leaderboardType: str
    userId: str
    username: str
    score: float
    gamesPlayed: int
    wins: int
    averageScore: float
    lastUpdated: str
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


def validate_game_submission(data: Dict[str, Any]) -> tuple[bool, Optional[str]]:
    """
    Validate game submission data
    
    Returns:
        (is_valid, error_message)
    """
    # Check required fields
    required_fields = ['gameVersion', 'players']
    for field in required_fields:
        if field not in data:
            return False, f"Missing required field: {field}"
    
    # Validate game version
    if data['gameVersion'] not in [v.value for v in GameVersion]:
        return False, f"Invalid game version: {data['gameVersion']}"
    
    # Validate players
    players = data['players']
    if not isinstance(players, list) or len(players) < 2:
        return False, "Game must have at least 2 players"
    
    if len(players) > 6:
        return False, "Game cannot have more than 6 players"
    
    # Validate each player
    for i, player in enumerate(players):
        if not isinstance(player, dict):
            return False, f"Player {i} is not a valid object"
        
        if 'name' not in player or not player['name'].strip():
            return False, f"Player {i} missing name"
        
        if 'score' not in player or not isinstance(player['score'], (int, float)):
            return False, f"Player {i} missing or invalid score"
        
        if player['score'] < 0:
            return False, f"Player {i} has negative score"
    
    return True, None


def validate_group_creation(data: Dict[str, Any]) -> tuple[bool, Optional[str]]:
    """
    Validate group creation data
    
    Returns:
        (is_valid, error_message)
    """
    if 'groupName' not in data:
        return False, "Missing required field: groupName"
    
    group_name = data['groupName'].strip()
    if len(group_name) < 3:
        return False, "Group name must be at least 3 characters"
    
    if len(group_name) > 50:
        return False, "Group name cannot exceed 50 characters"
    
    return True, None

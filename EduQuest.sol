// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EduQuest {
    struct User {
        uint256 questPoints;
        uint256 completedQuests;
        uint256 monthlyPoints;
    }

    struct LeaderboardEntry {
        address user;
        uint256 points;
    }

    mapping(address => User) public users;
    LeaderboardEntry[] public leaderboard; // Dynamic leaderboard
    uint256 public currentMonth;

    event QuestCompleted(address user, uint256 points);
    event PointsRedeemed(address user, uint256 points);
    event LeaderboardUpdated(address user, uint256 points);

    constructor() {
        currentMonth = block.timestamp / (30 days);
    }

    function completeQuest(uint256 _points) public {
        users[msg.sender].questPoints += _points;
        users[msg.sender].completedQuests += 1;
        users[msg.sender].monthlyPoints += _points;
        emit QuestCompleted(msg.sender, _points);

        // Update leaderboard
        updateLeaderboard(msg.sender, users[msg.sender].monthlyPoints);
    }

    function redeemPoints(uint256 _amount) public {
        require(users[msg.sender].questPoints >= _amount, "Not enough points");
        users[msg.sender].questPoints -= _amount;
        emit PointsRedeemed(msg.sender, _amount);
    }

    function getUserStats() public view returns (uint256, uint256, uint256) {
        return (users[msg.sender].questPoints, users[msg.sender].completedQuests, users[msg.sender].monthlyPoints);
    }

    function getLeaderboard() public view returns (LeaderboardEntry[] memory) {
        return leaderboard;
    }

    function updateLeaderboard(address _user, uint256 _points) internal {
        // Simple leaderboard logic - top 3
        bool exists = false;
        for (uint i = 0; i < leaderboard.length; i++) {
            if (leaderboard[i].user == _user) {
                leaderboard[i].points = _points;
                exists = true;
                break;
            }
        }
        if (!exists) {
            leaderboard.push(LeaderboardEntry(_user, _points));
        }
        // Sort leaderboard (bubble sort for simplicity)
        for (uint i = 0; i < leaderboard.length - 1; i++) {
            for (uint j = 0; j < leaderboard.length - i - 1; j++) {
                if (leaderboard[j].points < leaderboard[j + 1].points) {
                    (leaderboard[j], leaderboard[j + 1]) = (leaderboard[j + 1], leaderboard[j]);
                }
            }
        }
        // Keep only top 3
        if (leaderboard.length > 3) {
            while (leaderboard.length > 3) {
                leaderboard.pop();
            }
        }
        emit LeaderboardUpdated(_user, _points);
    }

    function startNewMonth() public {
        currentMonth = block.timestamp / (30 days);
        delete leaderboard; // Reset leaderboard for new month
    }
}

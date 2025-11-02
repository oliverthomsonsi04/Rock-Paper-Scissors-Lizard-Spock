// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Rock, Paper, Scissors, Lizard, Spock (RPSLS) Game
 * @dev Implements the game using a commit-reveal scheme to prevent cheating.
 * Two players stake Ether, and the winner takes the pot.
 *
 * Game Flow:
 * 1. Player 1 creates a game by staking ETH and providing a hash of their move.
 * 2. Player 2 joins the game by staking the same amount and providing their hash.
 * 3. Player 1 reveals their move and salt.
 * 4. Player 2 reveals their move and salt.
 * 5. The contract determines the winner and transfers the pot.
 */
contract RPSLS {
    enum Move { None, Rock, Paper, Scissors, Lizard, Spock }
    enum GameState { Open, P2Joined, P1Revealed, Finished }

    struct Game {
        address player1;
        address player2;
        bytes32 p1Commit;
        bytes32 p2Commit;
        Move p1Move;
        Move p2Move;
        uint256 stake;
        GameState state;
    }

    mapping(uint256 => Game) public games;
    uint256 public gameIdCounter;

    event GameCreated(uint256 indexed gameId, address indexed player1, uint256 stake);
    event GameJoined(uint256 indexed gameId, address indexed player2);
    event GameRevealed(uint256 indexed gameId, address indexed player, Move move);
    event GameFinished(uint256 indexed gameId, address winner, uint256 prize);
    event GameDraw(uint256 indexed gameId);

    /**
     * @dev Creates a game hash from a move and a secret salt.
     * This can be called off-chain to generate the commit hash.
     * @param _move The player's chosen move.
     * @param _salt A secret, random string to prevent hash collision.
     * @return The keccak256 hash of the move and salt.
     */
    function getHash(Move _move, string calldata _salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_move, _salt));
    }

    /**
     * @dev Player 1 creates a new game.
     * @param _commit The hash of player 1's move and salt.
     */
    function createGame(bytes32 _commit) public payable {
        require(msg.value > 0, "RPSLS: Stake must be greater than zero");
        gameIdCounter++;
        uint256 gameId = gameIdCounter;
        games[gameId] = Game({
            player1: msg.sender,
            player2: address(0),
            p1Commit: _commit,
            p2Commit: 0,
            p1Move: Move.None,
            p2Move: Move.None,
            stake: msg.value,
            state: GameState.Open
        });
        emit GameCreated(gameId, msg.sender, msg.value);
    }

    /**
     * @dev Player 2 joins an existing game.
     * @param _gameId The ID of the game to join.
     * @param _commit The hash of player 2's move and salt.
     */
    function joinGame(uint256 _gameId, bytes32 _commit) public payable {
        Game storage game = games[_gameId];
        require(game.state == GameState.Open, "RPSLS: Game not open");
        require(msg.sender != game.player1, "RPSLS: Cannot play against yourself");
        require(msg.value == game.stake, "RPSLS: Must match player 1's stake");

        game.player2 = msg.sender;
        game.p2Commit = _commit;
        game.state = GameState.P2Joined;
        emit GameJoined(_gameId, msg.sender);
    }

    /**
     * @dev A player reveals their move.
     * @param _gameId The ID of the game.
     * @param _move The move that was committed.
     * @param _salt The salt used to generate the commit hash.
     */
    function reveal(uint256 _gameId, Move _move, string calldata _salt) public {
        Game storage game = games[_gameId];
        require(game.state == GameState.P2Joined || game.state == GameState.P1Revealed, "RPSLS: Game not in reveal phase");
        require(_move != Move.None, "RPSLS: Invalid move");

        if (msg.sender == game.player1) {
            require(game.p1Move == Move.None, "RPSLS: Player 1 already revealed");
            require(getHash(_move, _salt) == game.p1Commit, "RPSLS: Player 1 hash does not match commit");
            game.p1Move = _move;
            game.state = GameState.P1Revealed;
            emit GameRevealed(_gameId, msg.sender, _move);
        } else if (msg.sender == game.player2) {
            require(game.state == GameState.P1Revealed, "RPSLS: Player 1 must reveal first");
            require(game.p2Move == Move.None, "RPSLS: Player 2 already revealed");
            require(getHash(_move, _salt) == game.p2Commit, "RPSLS: Player 2 hash does not match commit");
            game.p2Move = _move;
            emit GameRevealed(_gameId, msg.sender, _move);
        } else {
            revert("RPSLS: You are not a player in this game");
        }

        // If both players have revealed, determine the winner
        if (game.p1Move != Move.None && game.p2Move != Move.None) {
            _determineWinner(_gameId);
        }
    }

    /**
     * @dev Determines the winner and distributes the prize. Internal function.
     */
    function _determineWinner(uint256 _gameId) private {
        Game storage game = games[_gameId];
        game.state = GameState.Finished;
        uint256 prize = game.stake * 2;

        address winner = _getWinner(game.player1, game.p1Move, game.player2, game.p2Move);

        if (winner == address(0)) { // It's a draw
            // Return stakes to players
            payable(game.player1).transfer(game.stake);
            payable(game.player2).transfer(game.stake);
            emit GameDraw(_gameId);
        } else {
            // Transfer prize to the winner
            payable(winner).transfer(prize);
            emit GameFinished(_gameId, winner, prize);
        }
    }

    /**
     * @dev Logic to determine the winner based on the rules of RPSLS.
     * @return The address of the winner, or address(0) for a draw.
     */
    function _getWinner(address p1, Move m1, address p2, Move m2) private pure returns (address) {
        if (m1 == m2) return address(0); // Draw

        // Winning conditions for Player 1
        if ((m1 == Move.Rock && (m2 == Move.Scissors || m2 == Move.Lizard)) ||
            (m1 == Move.Paper && (m2 == Move.Rock || m2 == Move.Spock)) ||
            (m1 == Move.Scissors && (m2 == Move.Paper || m2 == Move.Lizard)) ||
            (m1 == Move.Lizard && (m2 == Move.Spock || m2 == Move.Paper)) ||
            (m1 == Move.Spock && (m2 == Move.Scissors || m2 == Move.Rock))) {
            return p1;
        }

        // If P1 didn't win and it's not a draw, P2 must be the winner
        return p2;
    }
}

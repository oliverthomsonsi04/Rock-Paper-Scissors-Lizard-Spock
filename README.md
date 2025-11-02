# Rock, Paper, Scissors, Lizard, Spock (RPSLS) Smart Contract

This Solidity contract implements the game "Rock, Paper, Scissors, Lizard, Spock" for two players on the Ethereum blockchain. It uses a **commit-reveal scheme** to ensure that neither player can cheat by waiting for the other player's move before choosing their own.

Both players stake an equal amount of Ether, and the winner takes the entire pot.

> "Scissors cuts Paper, Paper covers Rock, Rock crushes Lizard, Lizard poisons Spock, Spock smashes Scissors, Scissors decapitates Lizard, Lizard eats Paper, Paper disproves Spock, Spock vaporizes Rock, and as it always has, Rock crushes Scissors." - Sheldon Cooper

## Features

-   **Fair Play**: The commit-reveal scheme ensures a trustless and fair game.
-   **Stake-Based**: Players put Ether on the line, with the winner taking the pot (2x stake).
-   **Multi-Game Support**: The contract can handle multiple games simultaneously.
-   **Event-Driven**: Emits events for all major game state changes.
-   **Helper Function**: Includes a `getHash` view function to help users create their commit hash off-chain.

## Concepts Demonstrated

-   **Commit-Reveal Scheme**: A fundamental pattern for fair on-chain games.
-   **Enums**: For defining game states and moves (`GameState`, `Move`).
-   **Structs**: To organize and store data for each game session.
-   **Mappings**: To associate a `gameId` with its `Game` struct.
-   **Complex State Management**: The game progresses through several states from `Open` to `Finished`.
-   **Hashing with `keccak256`**: Used to create commitments.

## How It Works: The Commit-Reveal Scheme

Because all blockchain data is public, a simple "Player 1 chooses Rock" transaction would be visible to Player 2 before they make their move, allowing them to cheat. The commit-reveal scheme solves this:

1.  **Commit Phase**:
    -   A player (e.g., Player 1) chooses a move (e.g., `Rock`) and a secret random string, called a "salt" (e.g., `"mySecretSalt123"`).
    -   They calculate a cryptographic hash of their move and the salt: `hash = keccak256("Rock", "mySecretSalt123")`.
    -   They submit *only this hash* to the contract. The hash reveals nothing about the chosen move, but it acts as a commitment.
    -   Player 2 does the same.

2.  **Reveal Phase**:
    -   Once both players have committed their hashes, they reveal their original move and salt.
    -   The contract re-calculates the hash using the revealed move and salt and checks if it matches the hash committed earlier.
    -   If it matches, the move is accepted. If not, the transaction fails.
    -   Once both moves are revealed and verified, the contract can safely determine the winner.

## How to Play

### 1. Player 1: Create a Game

1.  Choose your move (e.g., `Rock` which corresponds to `enum` value `1`) and a secret salt (e.g., `"abc"`).
2.  Use the `getHash()` function (or an off-chain tool) to get your commit hash. For example, `getHash(1, "abc")`.
3.  Call `createGame()`, passing in your commit hash and sending your stake (e.g., 0.1 ETH).

### 2. Player 2: Join the Game

1.  Find the `gameId` of the game you want to join.
2.  Choose your move and a different secret salt.
3.  Generate your own commit hash.
4.  Call `joinGame()`, passing the `gameId`, your commit hash, and an amount of ETH that **exactly matches** Player 1's stake.

### 3. Player 1: Reveal

1.  Call the `reveal()` function, passing the `gameId`, your original move (`1` for Rock), and your original salt (`"abc"`). The contract will verify your move against your committed hash.

### 4. Player 2: Reveal & Determine Winner

1.  After Player 1 has revealed, call the `reveal()` function with your move and salt.
2.  Once your move is verified, the contract will automatically execute the winner determination logic.
3.  The pot (stake from both players) is transferred to the winner. If it's a draw, each player gets their original stake back.

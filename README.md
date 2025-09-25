# ScootFi 🛴 - Tokenized Electric Scooter Sharing

## Overview

ScootFi is a decentralized electric scooter sharing platform built on Stacks blockchain. The system enables tokenized rentals where users can rent electric scooters using cryptocurrency, with transparent pricing and automated payment processing through smart contracts.

## Features

### Core Functionality
- **Scooter Registration**: Operators can register new scooters on the platform
- **Tokenized Rentals**: Users can rent scooters using STX tokens
- **Real-time Availability**: Track scooter availability and location status
- **Automated Billing**: Smart contract handles payment processing automatically
- **Rental History**: Complete audit trail of all rental transactions
- **Dynamic Pricing**: Configurable rental rates per minute/hour

### Smart Contract Architecture
- **Scooter Management Contract**: Handles scooter registration, availability, and status updates
- **Rental System Contract**: Manages rental transactions, payments, and user interactions
- **Integrated Token Economy**: Native STX integration for seamless payments

## Technical Stack

- **Blockchain**: Stacks 2.0
- **Smart Contracts**: Clarity language
- **Development**: Clarinet framework
- **Testing**: Vitest with Clarinet SDK
- **CI/CD**: GitHub Actions

## Project Structure

```
ScootFi/
├── contracts/
│   ├── scooter-manager.clar     # Scooter registration and management
│   └── rental-system.clar       # Rental transactions and payments
├── tests/
│   ├── scooter-manager_test.ts  # Scooter management tests
│   └── rental-system_test.ts    # Rental system tests
├── settings/
│   ├── Devnet.toml             # Development network config
│   ├── Testnet.toml            # Test network config
│   └── Mainnet.toml            # Main network config
├── Clarinet.toml               # Project configuration
├── package.json                # Node.js dependencies
└── README.md                   # This file
```

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Node.js](https://nodejs.org/) (for testing)
- [Git](https://git-scm.com/)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd ScootFi
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## Usage

### Deploying Contracts

1. **Development Network**:
```bash
clarinet integrate
```

2. **Testnet Deployment**:
```bash
clarinet deploy --testnet
```

### Key Operations

#### Register a Scooter
```clarity
(contract-call? .scooter-manager register-scooter 
    u1001                    ;; scooter-id
    "Downtown Location A"    ;; location
    u50)                     ;; rate per minute (microSTX)
```

#### Rent a Scooter
```clarity
(contract-call? .rental-system start-rental 
    u1001                    ;; scooter-id
    u60)                     ;; duration in minutes
```

#### End Rental
```clarity
(contract-call? .rental-system end-rental 
    u1001)                   ;; scooter-id
```

## Contract Details

### Scooter Manager Contract
- Maintains scooter registry with unique IDs
- Tracks location and availability status
- Manages operator permissions
- Configurable rental rates

### Rental System Contract
- Processes rental transactions
- Handles STX payments automatically
- Maintains rental history
- Calculates usage-based billing

## Testing

Run the complete test suite:
```bash
npm test
```

Individual contract testing:
```bash
clarinet test tests/scooter-manager_test.ts
clarinet test tests/rental-system_test.ts
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security Considerations

- All payments are handled through native STX transfers
- Contract includes proper access controls
- Rental state validation prevents double-spending
- Operator permissions are enforced

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Roadmap

- [ ] Mobile app integration
- [ ] GPS tracking integration
- [ ] Multi-token support
- [ ] Staking rewards for operators
- [ ] Insurance protocol integration
- [ ] Cross-chain compatibility

## Contact

For questions and support, please open an issue on GitHub.

---

Built with ❤️ on Stacks blockchain

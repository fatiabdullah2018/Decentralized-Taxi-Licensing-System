# Decentralized Taxi Licensing System

A comprehensive blockchain-based taxi licensing and management system built on the Stacks blockchain using Clarity smart contracts.

## Overview

This system provides a decentralized approach to taxi licensing, ensuring transparency, accountability, and efficient management of taxi operations through five interconnected smart contracts.

## Contracts

### 1. Driver License Verification (`driver-license.clar`)
- Validates commercial driving credentials
- Manages driver registration and license status
- Tracks license expiration and renewal
- Maintains driver reputation scores

### 2. Vehicle Inspection (`vehicle-inspection.clar`)
- Ensures taxi safety and maintenance standards
- Records inspection results and certificates
- Manages vehicle registration and compliance
- Tracks maintenance schedules

### 3. Fare Regulation (`fare-regulation.clar`)
- Enforces municipal pricing guidelines
- Manages base rates and surge pricing
- Calculates fare estimates
- Handles fare dispute resolution

### 4. Route Optimization (`route-optimization.clar`)
- Manages efficient passenger pickup systems
- Tracks driver locations and availability
- Optimizes route assignments
- Maintains service area boundaries

### 5. Insurance Compliance (`insurance-compliance.clar`)
- Verifies commercial vehicle coverage
- Manages insurance policy validation
- Tracks coverage periods and renewals
- Handles claims and compliance reporting

## Features

- **Decentralized Governance**: Community-driven decision making
- **Transparent Operations**: All transactions recorded on blockchain
- **Automated Compliance**: Smart contract enforcement of regulations
- **Real-time Verification**: Instant validation of credentials and compliance
- **Dispute Resolution**: Built-in mechanisms for handling conflicts

## Getting Started

### Prerequisites
- Clarinet CLI
- Node.js 18+
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

3. Run tests:
   \`\`\`bash
   npm test
   \`\`\`

4. Deploy contracts:
   \`\`\`bash
   clarinet deploy
   \`\`\`

## Testing

The system includes comprehensive tests using Vitest:

\`\`\`bash
npm run test
\`\`\`

## Contract Interactions

### Driver Registration
\`\`\`clarity
(contract-call? .driver-license register-driver
"John Doe"
"DL123456789"
u1735689600) ;; expiration timestamp
\`\`\`

### Vehicle Registration
\`\`\`clarity
(contract-call? .vehicle-inspection register-vehicle
"ABC123"
"Toyota Camry"
u2023)
\`\`\`

### Set Base Fare
\`\`\`clarity
(contract-call? .fare-regulation set-base-fare u250) ;; $2.50 in cents
\`\`\`

## Architecture

The system follows a modular architecture where each contract handles specific aspects of taxi operations while maintaining data integrity and cross-contract compatibility.

## Security Considerations

- All contracts include proper access controls
- Input validation prevents malicious data
- Emergency pause mechanisms for critical situations
- Multi-signature requirements for administrative functions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

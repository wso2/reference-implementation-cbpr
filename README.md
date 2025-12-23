# SWIFT MT/MX CBPR+ Translation Reference Implementation

A comprehensive reference implementation for SWIFT MT ↔ MX message translation using CBPR+ (Cross Border Payments Regulation Plus) standards. This solution provides seamless bi-directional translation between SWIFT MT (legacy format) and ISO 20022 MX (modern XML format) messages through various integration patterns.

## 🌟 Features

- **Bi-directional Translation**: Complete MT→MX and MX→MT message transformation
- **Multiple Integration Patterns**: Support for various messaging protocols and transport mechanisms
- **CBPR+ Compliance**: Implements Cross Border Payments Regulation Plus standards
- **Real-time Dashboard**: OpenSearch-based dashboard for monitoring and analytics
- **Comprehensive Logging**: Structured JSON logging with search and visualization capabilities
- **Error Handling**: Comprehensive error management with message routing
- **Extensible Architecture**: RESTful extension APIs for custom processing logic
- **Transaction Analysis**: Automatic extraction of currency, amount, and message types
- **Enterprise Authentication**: Federated login support with OIDC (Asgardeo)
- **Enterprise Ready**: Production-ready implementations with observability

## Get Started Now

**🚀 Ready to use? Download the latest release:**

[![Download Translator](https://img.shields.io/badge/Download%20Translator-v2.0.8-success?style=for-the-badge)](https://github.com/wso2/reference-implementation-cbpr/releases/tag/translator-v2.0.8)

[![Download Dashboard](https://img.shields.io/badge/Download%20Dashboard-v1.0.1-success?style=for-the-badge)](https://github.com/wso2/reference-implementation-cbpr/releases/tag/dashboard-v1.0.1)

**💡 Just need Java 17+ to run!** No need to clone the repository or install development tools.

**📊 Want the dashboard?** Set up [OpenSearch](https://opensearch.org/downloads/) and follow our [Dashboard Guide](dashboard/README.md).

---

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────────────────────┐    ┌─────────────────┐
│   MT Messages   │───▶│        Translation Engine       │───▶│   MX Messages   │
│  (Any Protocol) │    │         (Ballerina)             │    │  (Any Protocol) │
└─────────────────┘    └─────────────────────────────────┘    └─────────────────┘
         │                              │                              │
         ▼                              ▼                              ▼
┌─────────────────┐    ┌─────────────────────────────────┐    ┌─────────────────┐
│ Integration     │    │       OpenSearch Dashboard      │    │ Integration     │
│ Specific        │    │    • Message Analytics          │    │ Specific        │
│ Error Handling  │    │    • Real-time Monitoring       │    │ Error Handling  │
└─────────────────┘    │    • Error Analysis             │    └─────────────────┘
                       │    • Performance Metrics        │
                       │    • Federated Authentication   │
                       └─────────────────────────────────┘
```

### Components Overview

- **Translation Engine**: Core Ballerina-based message transformation
- **Integration Layer**: Protocol-specific adapters (FTP/SFTP, MQ, Kafka, etc.)
- **Dashboard**: OpenSearch-based analytics and monitoring platform
- **Extension APIs**: RESTful endpoints for custom processing hooks
- **Authentication**: OIDC-based federated login with role-based access

## 🔌 Available Components

### Translation Integrations

| Integration | Description | Status | Documentation |
|-------------|-------------|---------|---------------|
| **FTP/SFTP** | File-based integration with FTP/SFTP servers | ✅ Available | [README](translator/integrations/ftp-sftp/) |

### Dashboard & Monitoring

| Component | Description | Status | Documentation |
|-----------|-------------|---------|---------------|
| **OpenSearch Dashboard** | Real-time analytics and monitoring | ✅ Available | [README](dashboard/swift_dashboard/) |
| **Message Analytics** | Transaction analysis and reporting | ✅ Available | Part of Dashboard |
| **Federated Authentication** | OIDC-based login with Asgardeo | ✅ Available | Part of Dashboard |

### Planned Integrations

| Integration   | Description | Status | Target Release |
|---------------|-------------|---------|----------------|
| **IBM MQ**    | Message Queue integration | 🚧 Planned | TBD            |
| **Rabbit MQ** | Message Queue integration | 🚧 Planned | TBD        |
| **HTTP/REST** | RESTful API integration | 🚧 Planned | TBD        |

## 🚀 Quick Start

### Option 1: Use Pre-built Release (Recommended)

**Prerequisites for Release:**
- Java 17+ (only requirement for running the translator)
- Access to your FTP/SFTP server
- OpenSearch 2.19.0+ (optional, for dashboard analytics)

**Quick Installation:**

Visit the [Releases Page](https://github.com/wso2/reference-implementation-cbpr/releases) to:
- 📦 Download specific versions
- 📋 View release notes and changelogs
```bash
# Download latest release
wget https://github.com/wso2/reference-implementation-cbpr/releases/latest/download/swift-mt-mx-translator-2.0.8.tar.gz

# Extract and install
tar -xzf swift-mt-mx-translator-*.tar.gz
cd swift-mt-mx-translator-*

# Manual installation
java -jar swiftMtMxTranslator.jar
```

**Configuration:**
```bash
# Create a configuration file and configure the setup.
Refer to the sample [Config.toml](https://github.com/wso2/reference-implementation-cbpr/blob/main/translator/integrations/ftp-sftp/swiftMtMxTranslator/Config.toml) for details.
```

### Option 2: Development Setup (For Contributors)

**Prerequisites for Development:**
- [Ballerina Swan Lake](https://ballerina.io/downloads/) (2201.10.5+)
- Java 17+ (for Ballerina runtime)
- [OpenSearch](https://opensearch.org/downloads/) (2.19.0+) and [OpenSearch Dashboards](https://opensearch.org/downloads/#opensearch-dashboards) (for dashboard development)
- [Node.js](https://nodejs.org/) v20 (for dashboard plugin development)
- Git (for cloning and contributing)

**Development Setup:**

1. **Clone the repository (for development only)**
   ```bash
   git clone https://github.com/wso2/reference-implementation-cbpr.git
   cd reference-implementation-cbpr
   ```

2. **Set up the dashboard (optional)**
   ```bash
   cd dashboard/swift_dashboard/
   # Follow the OpenSearch Dashboard setup guide in dashboard/README.md
   ```

3. **Build from source**
   ```bash
   cd translator/integrations/ftp-sftp/swiftMtMxTranslator/
   bal build
   java -jar target/bin/swiftMtMxTranslator.jar
   ```

## 📁 Repository Structure

```
reference-implementation-cbpr/
├── README.md                           # This file - general overview
├── LICENSE                            # Apache 2.0 License
├── dashboard/                         # Dashboard components
│   └── swift_dashboard/               # OpenSearch Dashboard plugin
│       ├── README.md                  # Dashboard setup guide
│       ├── opensearch_dashboards.json # Plugin configuration
│       ├── public/                    # Frontend React components
│       ├── server/                    # Backend API endpoints
│       └── package.json               # Dependencies and build scripts
├── resources/                         # Shared resources
│   └── translator-extensions-v1.0.0.yaml  # Extension API contract
└── translator/                        # Translation implementations
    └── integrations/                  # Integration-specific implementations
        └── ftp-sftp/                  # FTP/SFTP integration
            ├── README.md              # FTP/SFTP specific documentation
            └── swiftMtMxTranslator/   # Ballerina implementation
```

## 📋 Supported Message Types

### SWIFT MT Messages
- **Payment Messages**: MT101, MT102, MT102STP, MT103, MT103STP, MT103REMIT, MT107, MT110, MT111, MT112, MT190, MT191, 
MT192, MT195, MT196, MT199
- **Treasury Messages**: MT200, MT201, MT202, MT202COV, MT203, MT204, MT205, MT205COV, MT210, MT290, MT291, MT292, 
MT295, MT296, MT299
- **System Messages**: MT900, MT910, MT920, MT940, MT941, MT942, MT950, MT970, MT971, MT972, MT973, MT990, MT991, MT992, 
MT995, MT996

### ISO 20022 MX Messages
- **Payment Initiation**: pain.001, pain.008
- **Cash Management**: camt.026, camt.027, camt.028, camt.029, camt.031, camt.033, camt.034, camt.050, camt.052, 
camt.053, camt.054, camt.055, camt.056, camt.057, camt.058, camt.060, camt.105, camt.106, camt.107, camt.108, camt.109
- **Payment Clearing**: pacs.002, pacs.003, pacs.004, pacs.008, pacs.009, pacs.010

## 🔧 Extension Framework

All integrations support a common extension framework through RESTful APIs:

### Extension Points
- **Pre-processing**: Modify messages before translation
- **Post-processing**: Modify messages after translation

### Extension API Contract
The extension APIs follow a standardized contract defined in `resources/translator-extensions-v1.0.0.yaml`:

```yaml
# Common extension endpoints (available for all integrations)
POST /mt-mx/pre-process     # Pre-process MT messages
POST /mt-mx/post-process    # Post-process MX messages

POST /mx-mt/pre-process     # Pre-process MX messages  
POST /mx-mt/post-process    # Post-process MT messages
```

## 📊 Monitoring & Observability

### Universal Dashboard Logs
All integrations generate standardized JSON logs that are automatically indexed in OpenSearch.

### Dashboard Features
The OpenSearch Dashboard provides:

- **Real-time Monitoring**: Live message processing statistics
- **Message Analytics**: Transaction volume, success rates, error analysis
- **Currency Analysis**: Transaction breakdown by currency
- **Error Categorization**: Field errors, unsupported messages, invalid formats
- **Performance Metrics**: Processing times and throughput analysis
- **Search & Filter**: Advanced search capabilities across all messages
- **Visual Reports**: Charts, graphs, and trend analysis
- **Role-based Access**: Federated authentication with OIDC

### Dashboard Access
```bash
# After setting up OpenSearch and the dashboard plugin
http://{opensearch_dashboard_host}:{opensearch_dashboard_port}/app/swiftDashboard
ex: http://localhost:5601/app/swiftDashboard
```

### Application Logs
All integrations follow consistent logging patterns:
- **Info**: Processing status and integration-specific operations
- **Debug**: Detailed message content and transformation steps  
- **Error**: Exception handling and failure scenarios
- **Warn**: Non-critical issues and retries

### Observability Features
- **Metrics**: Message throughput, success rates, processing times
- **Tracing**: End-to-end message flow tracking

## 🤝 Contributing

We welcome contributions! Please read our [licence](LICENSE) and [issue template](issue_template.md) before submitting.

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request using our [PR template](pull_request_template.md)

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Dashboard Setup**: Follow the [Dashboard Setup Guide](dashboard/swift_dashboard/) for OpenSearch configuration
- **Integration Help**: Check individual integration READMEs for specific setup instructions
- **Issues**: Report bugs using our [issue template](issue_template.md)
- **WSO2 Support**: Contact WSO2 for enterprise support and consulting

## 🔗 Related Projects

- [Ballerina SWIFT MT](https://central.ballerina.io/ballerinax/financial.swift.mt)
- [Ballerina ISO 20022](https://central.ballerina.io/ballerinax/financial.iso20022)
- [OpenSearch Dashboard Plugin Development](https://opensearch.org/docs/latest/dashboards/dev-tools/)
- [WSO2 Financial Solutions](https://wso2.com/solutions/financial-services/)

---

**Developed by WSO2** | **For CBPR+ Compliance** | **Enterprise Ready** | **OpenSearch Powered**

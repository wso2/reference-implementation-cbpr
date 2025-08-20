# FTP/SFTP Integration for SWIFT MT/MX Translation

File-based integration for SWIFT MT ↔ MX message translation using FTP/SFTP protocols. This integration provides automated file processing with configurable polling intervals and comprehensive error handling through directory-based routing.

## 🌟 FTP/SFTP Specific Features

- **Protocol Support**: Both FTP and SFTP protocols
- **Automated Polling**: Configurable file polling intervals
- **Directory-based Routing**: Success/failure/skip directory management
- **Private Key Authentication**: SFTP key-based authentication support
- **File Pattern Matching**: Configurable filename patterns
- **Atomic File Processing**: Ensures message integrity during processing
- **Temporary File Management**: Safe file handling with cleanup

## Get Started Now

**🚀 Production Ready? Use the latest release:**

[![Download FTP/SFTP Release](https://img.shields.io/github/v/release/wso2/reference-implementation-cbpr?label=Download%20FTP%2FSFTP%20Release&style=for-the-badge&color=success)](https://github.com/wso2/reference-implementation-cbpr/releases/latest)

**💡 Only need Java 17+ and FTP/SFTP server access!**

---

## 🏗️ FTP/SFTP Architecture

```
┌─────────────────┐    ┌─────────────────────────────────┐    ┌─────────────────┐
│   FTP Server    │    │     Ballerina Translator        │    │   FTP Server    │
│                 │    │                                 │    │                 │
│ /mt/inward/     │───▶│  ┌─────────────────────────────┐│◀───│ /mx/inward/     │
│ /mt/success/    │◀───│  │     MT → MX Listener        ││───▶│ /mx/success/    │
│ /mt/failed/     │◀───│  └─────────────────────────────┘│───▶│ /mx/failed/     │
│ /mt/skipped/    │◀───│                                 │───▶│ /mx/skipped/    │
│                 │    │  ┌─────────────────────────────┐│    │                 │
│ /mt/outward/    │◀───│  │     MX → MT Listener        ││───▶│ /mx/outward/    │
│                 │    │  └─────────────────────────────┘│    │                 │
└─────────────────┘    └─────────────────────────────────┘    └─────────────────┘
```

## 🚀 Quick Start Options

### Option 1: Use Pre-built Release (Recommended)

**Prerequisites:**
- Java 17+ (only requirement)
- FTP/SFTP server with proper permissions
- Access to create directories on the server

**Installation Steps:**

1. **Download and extract the release**
   ```bash
   # Download latest release
   wget https://github.com/wso2/reference-implementation-cbpr/releases/latest/download/swift-mt-mx-translator-1.0.0.tar.gz
   
   # Extract
   tar -xzf swift-mt-mx-translator-*.tar.gz
   cd swift-mt-mx-translator-*
   ```

2. **Setup FTP/SFTP directories**
   ```bash
   # Connect to your FTP/SFTP server and create directory structure
   mkdir -p /mt/{inward,success,failed,skipped,outward}
   mkdir -p /mx/{inward,success,failed,skipped,outward}
   ```

3. **Configure the application**
   ```bash
   # Create a configuration file and configure the setup.
   Refer to the sample [Config.toml](https://github.com/wso2/reference-implementation-cbpr/blob/main/translator/integrations/ftp-sftp/swiftMtMxTranslator/Config.toml) for details.
   ```

4. **Run the translator**
   ```bash
   java -jar swiftMtMxTranslator.jar
   ```

### Option 2: Development Setup (For Contributors)

**Prerequisites:**
- [Ballerina Swan Lake](https://ballerina.io/downloads/) (2201.10.5+)
- Java 17+ (for Ballerina runtime)
- Git (for cloning)
- FTP/SFTP server access

**Development Steps:**

1. **Clone and navigate**
   ```bash
   git clone https://github.com/wso2/reference-implementation-cbpr.git
   cd reference-implementation-cbpr/translator/integrations/ftp-sftp/swiftMtMxTranslator
   ```

2. **Configure the application**
   ```bash
   # Create a configuration file and configure the setup.
   Refer to the sample [Config.toml](https://github.com/wso2/reference-implementation-cbpr/blob/main/translator/integrations/ftp-sftp/swiftMtMxTranslator/Config.toml) for details.
   ```

3. **Create required directories on FTP server**
   ```bash
   # Create directory structure (adjust paths as per your configuration)
   mkdir -p /mt/{inward,success,failed,skipped,outward}
   mkdir -p /mx/{inward,success,failed,skipped,outward}
   ```

4. **Build and run**
   ```bash
   bal build
   bal run
   ```

## ⚙️ Configuration

### FTP/SFTP Connection Settings

Configure your FTP/SFTP connections in `Config.toml`:

```toml
# MT->MX Listener Configuration
[mtMxListener]
name = "MT MX Listener"
protocol = "ftp"  # Options: "ftp" or "sftp"
host = "127.0.0.1"
port = 21  # Use 22 for SFTP
username = "your_username"
password = "your_password"
pvtKeyPath = ""  # Path to private key file (SFTP only)
keyPass = ""     # Private key password (if required)
pollingInterval = 1.0  # Polling interval in seconds
inwardFilepath = "/mt/inward/"
inwardFileNamePattern = "(.*).txt"

# MT->MX Client Configuration (for sending translated files)
[mtMxClient]
name = "MT MX Client"
protocol = "ftp"
host = "127.0.0.1"
port = 21
username = "your_username"
password = "your_password"
pvtKeyPath = "" # For SFTP with private key authentication
keyPass = "" # For SFTP with private key authentication (if key is encrypted)
successFilepath = "/mt/success/"
failedFilepath = "/mt/failed/"
skippedFilepath = "/mt/skipped/"
outwardFilepath = "/mt/outward/"

# MX->MT Listener Configuration
[mxMtListener]
name = "MX MT Listener"
protocol = "ftp"
host = "127.0.0.1"
port = 21
username = "your_username"
password = "your_password"
pvtKeyPath = "" # For SFTP with private key authentication
keyPass = "" # For SFTP with private key authentication (if key is encrypted)
pollingInterval = 1.0
inwardFilepath = "/mx/inward/"
inwardFileNamePattern = "(.*).xml"

# MX->MT Client Configuration
[mxMtClient]
name = "MX MT Client"
protocol = "ftp"
host = "127.0.0.1"
port = 21
username = "your_username"
password = "your_password"
pvtKeyPath = ""
keyPass = ""
successFilepath = "/mx/success/"
failedFilepath = "/mx/failed/"
skippedFilepath = "/mx/skipped/"
outwardFilepath = "/mx/outward/"

# Logging Configuration
[ballerina.log]
level = "DEBUG"
format="json"

[log]
dashboardLogFilePath = "/logs/swiftTranslator"
ballerinaLogFilePath = "/logs/swiftTranslator"

# Translator Configuration
[translator]
supportedMTMessageTypes = [
   "103", "110", "111", "112", "190", "191", "192", "196", "199", "202", "205", 
   "210", "290", "291", "292", "296", "299", "900", "910", "940", "942"
]

[translator.mxMtExtension]
preProcess = true # Enable/disable pre-processing for MX to MT translation
postProcess = true # Enable/disable post-processing for MX to MT translation
basepath = "http://localhost:9090" # Base URL for extension APIs

[translator.mtMxExtension]
preProcess = true # Enable/disable pre-processing for MT to MX translation
postProcess = true # Enable/disable post-processing for MT to MX translation
basepath = "http://localhost:9090" # Base URL for extension APIs
```

### Directory Structure

The FTP/SFTP server must have a similar directory structure. You can change the paths in the configuration file as 
needed, the default structure expected is as follows:

```
FTP/SFTP Root/
├── mt/
│   ├── inward/     # Place MT messages here for MX translation
│   ├── success/    # Successfully processed MT messages moved here
│   ├── failed/     # Failed MT message processing moved here
│   ├── skipped/    # Skipped MT messages moved here
│   └── outward/    # Translated MT messages placed here
└── mx/
    ├── inward/     # Place MX messages here for MT translation
    ├── success/    # Successfully processed MX messages moved here
    ├── failed/     # Failed MX message processing moved here
    ├── skipped/    # Skipped MX messages moved here
    └── outward/    # Translated MX messages placed here
```


### Manual Service Management

```bash
# Run in foreground (for testing)
java -jar swiftMtMxTranslator.jar

# Run in background
nohup java -jar swiftMtMxTranslator.jar > translator.log 2>&1 &

# Check if running
ps aux | grep swiftMtMxTranslator

# Stop background process
pkill -f swiftMtMxTranslator
```

### Health Monitoring

```bash
# Check FTP/SFTP connectivity
ftp your-ftp-server.com    # For FTP
sftp your-sftp-server.com  # For SFTP

# Monitor directory activity
watch -n 5 'ls -la /mt/inward/ /mx/inward/'

# Check translation logs
tail -f /tmp/swiftTranslator/dashboard.log
```

## 📁 Project Structure

```
swiftMtMxTranslator/
├── Ballerina.toml               # Project configuration
├── Config.toml                  # Runtime configuration
├── Dependencies.toml            # Dependency versions
├── configurables.bal            # Configuration management
├── constants.bal                # Application constants
├── types.bal                   # Type definitions  
├── utils.bal                   # Utility functions
├── mt_listener.bal             # MT message FTP listener
├── mx_listener.bal             # MX message FTP listener
├── mt_listener_utils.bal       # MT processing utilities
├── mx_listener_utils.bal       # MX processing utilities
└── target/                     # Build artifacts
    ├── bin/
    │   └── swiftMtMxTranslator.jar
    └── cache/
```

## 🔄 Message Processing Flow

### MT → MX Translation Flow

1. **File Detection**: MT files placed in `/mt/inward/` directory
2. **File Retrieval**: File downloaded and moved to temporary processing area
3. **Pre-processing**: Optional pre-processing via extension API
4. **MT Parsing**: Parse SWIFT MT message format
5. **Translation**: Convert MT to corresponding MX format using CBPR+ rules
6. **MX Generation**: Generate ISO 20022 XML message
7. **Post-processing**: Optional post-processing via extension API
8. **File Routing**:
   - **Success**: Original MT → `/mt/success/`, Translated MX → `/mx/outward/`
   - **Failure**: Original MT → `/mt/failed/`
   - **Skip**: Original MT → `/mt/skipped/` (unsupported message types)

### MX → MT Translation Flow

1. **File Detection**: MX files placed in `/mx/inward/` directory
2. **File Retrieval**: File downloaded and moved to temporary processing area
3. **Pre-processing**: Optional pre-processing via extension API
4. **MX Parsing**: Parse ISO 20022 XML message
5. **Translation**: Convert MX to corresponding MT format using CBPR+ rules
6. **MT Generation**: Generate SWIFT MT message format
7. **Post-processing**: Optional post-processing via extension API
8. **File Routing**:
   - **Success**: Original MX → `/mx/success/`, Translated MT → `/mt/outward/`
   - **Failure**: Original MX → `/mx/failed/`
   - **Skip**: Original MX → `/mx/skipped/` (unsupported message types)

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

## 🔧 Extension APIs

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

### Troubleshooting

#### Common Issues

1. **Files not being picked up**
   ```bash
   # Check directory permissions
   ls -la /mt/inward/
   
   # Verify file pattern matching
   # Ensure files match the pattern in inwardFileNamePattern
   ```

2. **SFTP connection failures**
   ```bash
   # Test SFTP connectivity
   sftp -i /path/to/private/key username@hostname
   
   # Check private key permissions
   chmod 600 /path/to/private/key
   ```

3. **Translation failures**
   ```bash
   # Check application logs for stack traces
   tail -f /logs/swiftTranslator/ballerina*.log
   ```

#### Performance Tuning

- **Polling Interval**: Adjust `pollingInterval` based on message volume
- **Concurrent Processing**: Configure multiple listeners for high throughput
- **Network Timeouts**: Adjust FTP client timeout settings
- **Memory Settings**: Tune JVM heap size for large message processing

## 📚 Additional Resources

- [Ballerina SWIFT MT](https://central.ballerina.io/ballerinax/financial.swift.mt)
- [Ballerina ISO 20022](https://central.ballerina.io/ballerinax/financial.iso20022)
- [CBPR+ Implementation Guidelines](https://www2.swift.com/mapping/#/)

---

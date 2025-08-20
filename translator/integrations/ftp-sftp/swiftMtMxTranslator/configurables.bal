// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

# In the configurations, inward and outward are relative to the Translator.

# Configurables for the MT->MX FTP listener
configurable ListenerConfig mtMxListener = {
    name: "MT MX Listener 1",
    // Protocol can be "ftp" or "sftp"
    protocol: "sftp",
    host: "127.0.0.1",
    port: 23,
    username: "",
    password: "",
    // Path to the private key file for SFTP, if using SFTP
    pvtKeyPath: "",
    // Password for the private key file, if applicable
    keyPass: "",
    pollingInterval: 1,
    // Directory where incoming MT files are placed
    inwardFilepath: "/mt/inward/",
    // Pattern to match incoming files.
    inwardFileNamePattern: "(.*).txt"
};

# Configurables for the MT->MX FTP client (used to send files)
configurable ClientConfig mtMxClient = {
    name: "MT MX Client 1",
    // Protocol can be "ftp" or "sftp"
    protocol: mtMxListener.protocol,
    host: mtMxListener.host,
    port: mtMxListener.port,
    username: mtMxListener.username,
    password: mtMxListener.password,
    pvtKeyPath: mtMxListener.pvtKeyPath,
    keyPass: mtMxListener.keyPass,
    // Directory where original MT messages are moved after successful processing
    successFilepath: "/mt/success/",
    // Directory where original MT messages are moved after failed processing
    failedFilepath: "/mt/failed/",
    // Directory where original MT messages are moved if processing skipped
    skippedFilepath: "/mt/skipped/",
    // Directory where translated MT files are moved
    outwardFilepath: "/mt/outward/"
};

# Configurables for the MX->MT FTP listener
configurable ListenerConfig mxMtListener = {
    name: "MX MT Listener 1",
    // Protocol can be "ftp" or "sftp"
    protocol: "sftp",
    host: "127.0.0.1",
    port: 23,
    username: "",
    password: "",
    pvtKeyPath: "",
    keyPass: "",
    pollingInterval: 1,
    // Directory where incoming MX files are placed
    inwardFilepath: "/mx/inward/",
    // Pattern to match incoming files.
    inwardFileNamePattern: "(.*).xml"
};

# Configurables for the MX->MT FTP client (used to send files) 
configurable ClientConfig mxMtClient = {
    name: "MX MT Client 1",
    // Protocol can be "ftp" or "sftp"
    protocol: mxMtListener.protocol,
    host: mxMtListener.host,
    port: mxMtListener.port,
    username: mxMtListener.username,
    password: mxMtListener.password,
    pvtKeyPath: mxMtListener.pvtKeyPath,
    keyPass: mxMtListener.keyPass,
    // Directory where original MX messages are moved after successful processing
    successFilepath: "/mx/success/",
    // Directory where original MX messages are moved after failed processing
    failedFilepath: "/mx/failed/",
    // Directory where original MX messages are moved if processing skipped
    skippedFilepath: "/mx/skipped/",
    // Directory where translated MX files are moved
    outwardFilepath: "/mx/outward/"
};

# Configurables for logging
configurable LogConfig log = {
    // Path to the dashboard log file
    dashboardLogFilePath: "/logs/",
    // Path to the Ballerina log file
    ballerinaLogFilePath: "/logs/"
};


string[] & readonly supportedMTMessageTypes = [
    "103", "110", "111", "112", "190", "191", "192", "196", "199", "202", "205", "210", "290", "291", "292", "296", 
    "299", "900", "910", "940", "942"
];

const Extension mtMxExtension = {
    preProcess: false,
    postProcess: false,
    basepath: "http://localhost:9090"
};

const Extension mxMtExtension = {
    basepath: "http://localhost:9090",
    preProcess: false,
    postProcess: false
};

configurable Translator translator = {
    supportedMTMessageTypes : supportedMTMessageTypes,
    mtMxExtension: mtMxExtension,
    mxMtExtension: mxMtExtension
};

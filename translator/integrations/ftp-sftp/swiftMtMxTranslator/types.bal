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

import ballerina/ftp;

type ListenerConfig record {
    string name;
    boolean enable = true;
    string protocol;
    string host;
    int port;
    string username;
    string password;
    string pvtKeyPath;
    string keyPass;
    decimal pollingInterval;
    string inwardFilepath;
    string inwardFileNamePattern;
};

type ClientConfig record {
    string name;
    boolean enable = true;
    string protocol;
    string host;
    int port;
    string username;
    string password;
    string pvtKeyPath;
    string keyPass;
    string bkpSuccessFilepath;
    string bkpFailedFilepath;
    string bkpSkippedFilepath;
    string outwardFilepath; 
    string outputFileNamePattern;
    string skippedOutputFileNamePattern;
};

type LogConfig record {
    string dashboardLogFilePath;
    string ballerinaLogFilePath;
};

type MoesifConfig record {
    boolean enabled = false;
    string applicationId;
    string apiEndpoint = "https://api.moesif.net/v1/actions";
    decimal timeout = 5.0;
    int retryCount = 3;
    decimal retryInterval = 2.0;
    float retryBackOffFactor = 2.0;
    decimal retryMaxWaitInterval = 10.0;
};

type FtpClient record {
    ClientConfig clientConfig;
    ftp:Client? 'client;
};

type FtpListener record {
    ListenerConfig listenerConfig;
    ftp:Listener? 'listener;
};

type Extension record{
    boolean preProcess;
    boolean postProcess;
    boolean skippedMsgPostProcess;
    string basepath?;
};

type Translator record {
    string[] supportedMTMessageTypes?;
    Extension mtMxExtension;
    Extension mxMtExtension;
};

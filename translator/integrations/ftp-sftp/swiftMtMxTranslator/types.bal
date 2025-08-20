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
    string protocol;
    string host;
    int port;
    string username;
    string password;
    string pvtKeyPath;
    string keyPass;
    string successFilepath;
    string failedFilepath;
    string skippedFilepath;
    string outwardFilepath; 
};

type LogConfig record {
    string dashboardLogFilePath;
    string ballerinaLogFilePath;
};

type FtpClient record {
    ClientConfig clientConfig;
    ftp:Client 'client;
};

type FtpListener record {
    ListenerConfig listenerConfig;
    ftp:Listener 'listener;
};

type Extension record{
    boolean preProcess;
    boolean postProcess;
    string basepath?;
};

type Translator record {
    string[] supportedMTMessageTypes?;
    Extension mtMxExtension;
    Extension mxMtExtension;
};

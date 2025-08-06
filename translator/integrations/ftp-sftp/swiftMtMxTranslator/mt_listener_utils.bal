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
import ballerina/http;

// MT->MX Translator FTP listener auth configurations
ftp:AuthConfiguration mtMxListenerFtpListenerAuthConfig = {
    credentials: {
        username: mtMxListener.username,
        password: mtMxListener.password
    },
    privateKey: mtMxListener.pvtKeyPath == "" ? () : {
        path: mtMxListener.pvtKeyPath,
        password: mtMxListener.keyPass
    }
};

// MT->MX Translator FTP listener
listener ftp:Listener mtFileListener = new ({
    protocol: mtMxListener.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
    host: mtMxListener.host,
    auth: mtMxListenerFtpListenerAuthConfig,
    port: mtMxListener.port,
    path: mtMxListener.inwardFilepath,
    fileNamePattern: mtMxListener.inwardFileNamePattern,
    pollingInterval: mtMxListener.pollingInterval
});

// MT->MX Translator FTP client auth configurations
ftp:AuthConfiguration mtMxClientFtpListenerAuthConfig = {
    credentials: {
        username: mtMxClient.username,
        password: mtMxClient.password
    },
    privateKey: mtMxClient.pvtKeyPath == "" ? () : {
        path: mtMxClient.pvtKeyPath,
        password: mtMxClient.keyPass
    }
};

// MT->MX Translator FTP client
ftp:Client mtFileClient = check new ({
    protocol: mtMxClient.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
    host: mtMxClient.host,
    port: mtMxClient.port,
    auth: mtMxClientFtpListenerAuthConfig
});

string mtMxListenerName = mtMxListener.name;
FtpClient mtMxClientObj = {
    clientConfig: mtMxClient,
    'client: mtFileClient
};
FtpListener mtMxListenerObj = {
    listenerConfig: mtMxListener,
    'listener: mtFileListener
};

http:Client mtmxClient = check new (mtMxExtension.basepath);

string[] supportedMessageTypes = translator.supportedMTMessageTypes ?: supportedMTMessageTypes;

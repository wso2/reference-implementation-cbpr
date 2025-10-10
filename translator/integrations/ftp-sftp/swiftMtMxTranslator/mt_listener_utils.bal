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
import ballerina/log;

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
ftp:Listener? mtFileListener = getMtMXListener();

public function getMtMXListener() returns ftp:Listener? {

    if !mtMxListener.enable {
        return;
    }
    ftp:Listener|ftp:Error 'listener = new ({
        protocol: mtMxListener.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
        host: mtMxListener.host,
        auth: mtMxListenerFtpListenerAuthConfig,
        port: mtMxListener.port,
        path: mtMxListener.inwardFilepath,
        fileNamePattern: mtMxListener.inwardFileNamePattern,
        pollingInterval: mtMxListener.pollingInterval
    });
    if ('listener is ftp:Error) {
        log:printError("Error occurred while creating the FTP listener", 'error = 'listener);
        return;
    }
    return 'listener;
}

// MT->MX Translator FTP client auth configurations
ftp:AuthConfiguration mtClientFtpListenerAuthConfig = {
    credentials: {
        username: mtClient.username,
        password: mtClient.password
    },
    privateKey: mtClient.pvtKeyPath == "" ? () : {
            path: mtClient.pvtKeyPath,
            password: mtClient.keyPass
        }
};

// FTP client for MT server
ftp:Client? mtFileClient = getMtClient();

public function getMtClient() returns ftp:Client? {
    if !mtClient.enable {
        log:printWarn(string `[Client - ${mtClient.name}] Client is disabled.`);
        return;
    }
    ftp:Client|ftp:Error 'client = new ({
        protocol: mtClient.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
        host: mtClient.host,
        auth: mtClientFtpListenerAuthConfig,
        port: mtClient.port
    });
    if ('client is ftp:Error) {
        log:printError("Error occurred while creating the FTP client", 'error = 'client);
        return;
    }
    log:printInfo(string `[Client - ${mtClient.name}] Client started.`);
    return 'client;
}

string mtMxListenerName = mtMxListener.name;
FtpClient mtMxClientObj = {
    clientConfig: mtClient,
    'client: mtFileClient
};
FtpListener mtMxListenerObj = {
    listenerConfig: mtMxListener,
    'listener: mtFileListener
};

http:Client mtmxExtHttpClient = check new (mtMxExtension.basepath);

string[] supportedMessageTypes = translator.supportedMTMessageTypes ?: supportedMTMessageTypes;

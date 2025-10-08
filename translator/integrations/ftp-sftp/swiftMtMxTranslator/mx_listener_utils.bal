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
ftp:AuthConfiguration mxMtListenerFtpListenerAuthConfig = {
    credentials: {
        username: mxMtListener.username,
        password: mxMtListener.password
    },
    privateKey: mxMtListener.pvtKeyPath == "" ? () : {
        path: mxMtListener.pvtKeyPath,
        password: mxMtListener.keyPass
    }
};

// MT->MX Translator FTP listener
ftp:Listener? mxFileListener = getMxMtListener();

public function getMxMtListener() returns ftp:Listener? {

    if !mxMtListener.enable {
        return;
    }
    ftp:Listener|ftp:Error 'listener = new ({
    protocol: mxMtListener.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
    host: mxMtListener.host,
    auth: mxMtListenerFtpListenerAuthConfig,
    port: mxMtListener.port,
    path: mxMtListener.inwardFilepath,
    fileNamePattern: mxMtListener.inwardFileNamePattern,
    pollingInterval: mxMtListener.pollingInterval
});
    if ('listener is ftp:Error) {
        log:printError("Error occurred while creating the FTP listener", 'error = 'listener);
        return;
    }
    return 'listener;

}

// MT->MX Translator FTP client auth configurations
ftp:AuthConfiguration mxClientFtpListenerAuthConfig = {
    credentials: {
        username: mxClient.username,
        password: mxClient.password
    },
    privateKey: mxClient.pvtKeyPath == "" ? () : {
        path: mxClient.pvtKeyPath,
        password: mxClient.keyPass
    }
};

// MX Server FTP client
ftp:Client? mxFileClient = getMxClient();

public function getMxClient() returns ftp:Client? {
    if !mxClient.enable {
        log:printWarn(string `[Client - ${mxClient.name}] Client is disabled.`);
        return;
    }
    ftp:Client|ftp:Error 'client = new ({
        protocol: mxClient.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
        host: mxClient.host,
        auth: mxClientFtpListenerAuthConfig,
        port: mxClient.port
});
    if ('client is ftp:Error) {
        log:printError("Error occurred while creating the FTP client", 'error = 'client);
        return;
    }
    log:printInfo(string `[Client - ${mxClient.name}] Client started.`);
    return 'client;
}

string mxMtListenerName = mxMtListener.name;

FtpClient mxMtClientObj = {
    clientConfig: mxClient,
    'client: mxFileClient
};
FtpListener mxMtListenerObj = {
    listenerConfig: mxMtListener,
    'listener: mxFileListener
};

http:Client mxmtExtHttpClient = check new (mxMtExtension.basepath);

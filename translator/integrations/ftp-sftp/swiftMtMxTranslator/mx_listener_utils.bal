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
listener ftp:Listener mxFileListener = new ({
    protocol: mxMtListener.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
    host: mxMtListener.host,
    auth: mxMtListenerFtpListenerAuthConfig,
    port: mxMtListener.port,
    path: mxMtListener.inwardFilepath,
    fileNamePattern: mxMtListener.inwardFileNamePattern,
    pollingInterval: mxMtListener.pollingInterval
});

// MT->MX Translator FTP client auth configurations
ftp:AuthConfiguration mxMtClientFtpListenerAuthConfig = {
    credentials: {
        username: mxMtClient.username,
        password: mxMtClient.password
    },
    privateKey: mxMtClient.pvtKeyPath == "" ? () : {
        path: mxMtClient.pvtKeyPath,
        password: mxMtClient.keyPass
    }
};

// MT->MX Translator FTP client
ftp:Client mxFileClient = check new ({
    protocol: mxMtClient.protocol == "sftp" ? ftp:SFTP : ftp:FTP,
    host: mxMtClient.host,
    port: mxMtClient.port,
    auth: mxMtClientFtpListenerAuthConfig
});

string mxMtListenerName = mxMtListener.name;

FtpClient mxMtClientObj = {
    clientConfig: mxMtClient,
    'client: mxFileClient
};
FtpListener mxMtListenerObj = {
    listenerConfig: mxMtListener,
    'listener: mxFileListener
};

http:Client mxmtClient = check new (mxMtExtension.basepath);

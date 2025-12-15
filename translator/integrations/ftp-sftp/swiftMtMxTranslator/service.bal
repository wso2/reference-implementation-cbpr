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
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;

public function main() returns error? {
    time:Utc utc = time:utcNow();
    string date = time:utcToString(utc).substring(0, 10);
    string filePath = log.ballerinaLogFilePath + "/ballerina-" + date + ".log";
    log:Error? outputFile = log:setOutputFile(filePath, log:APPEND);
    if outputFile is log:Error {
        log:printWarn(string `[Listener - ${mtMxListenerName}] Failed to set the output file for ballerina log.`);
    }

    // Initialize log rotator for daily log rotation
    initLogRotator();

    if mtMxListener.enable {
        // Attach the service to the listener along with the resource path.
        ftp:Listener? mtListener = mtFileListener;
        if mtListener is ftp:Listener {
            check mtListener.attach(mtFileListenerService);
            // Start the listener.
            check mtListener.'start();
            // Register the listener dynamically.
            runtime:registerListener(mtListener);
            log:printInfo(string `[Listener - ${mtMxListenerName}] Listener started.`);
        } else {
            log:printError("Error occurred while creating the FTP listener");
            return error("Error occurred while creating the FTP listener");
        }
    }

    if mxMtListener.enable {
        // Attach the service to the listener along with the resource path.
        ftp:Listener? mxListener = mxFileListener;
        if mxListener is ftp:Listener {
            check mxListener.attach(mxFileListenerService);
            // Start the listener.
            check mxListener.'start();
            // Register the listener dynamically.
            runtime:registerListener(mxListener);
            log:printInfo(string `[Listener - ${mxMtListenerName}] Listener started.`);
        } else {
            log:printError("Error occurred while creating the FTP listener");
            return error("Error occurred while creating the FTP listener");
        }
    }
}

service /healthz on new http:Listener(8080) {

    resource function get .() returns http:Response {
        http:Response response = new;
        response.statusCode = 200;
        response.setJsonPayload({
            "status": "UP",
            "timestamp": time:utcToString(time:utcNow())
        });
        return response;
    }
}

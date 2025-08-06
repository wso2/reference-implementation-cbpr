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

import ballerina/file;
import ballerina/ftp;
import ballerina/io;
import ballerina/log;
import ballerina/regex;
import ballerina/time;
import ballerina/uuid;


# Handle error scenarios for FTP client and listener operations
#
# + ftpClient - FtpClient instance to interact with the FTP server
# + listenerName - Name of the listener for logging purposes
# + logId - log identifier for tracking the operation
# + incomingMsg - the incoming message that caused the error
# + errorMsg - the error encountered during the operation
# + fileId - identifier for the file being processed
# + direction - direction of the message (inward or outward)
function handleError(FtpClient ftpClient, string listenerName, string logId, string incomingMsg, error errorMsg,
        string fileId, string direction) {
    log:printInfo(string `[Listner - ${listenerName}][${logId}] Message translation failed. Sending to FTP.`);
    sendToSourceFTP(ftpClient, logId, FAILURE, incomingMsg, fileId);
    appendToDashboardLogs(listenerName, incomingMsg, translatedMessage = NOT_AVAILABLE, msgId = fileId,
            direction = direction, mtmsgType = UNKNOWN, mxMsgType = UNKNOWN, currency = NOT_AVAILABLE,
            amount = NOT_AVAILABLE, errorMsg = errorMsg.toBalString(), status = FAILED);
    cleanTempFile(fileId, logId, listenerName);
    return;
}

# Handle scenarios where the message translation is skipped.
#
# + sourceClient - source FtpClient instance to interact with the source FTP server
# + destinationClient - destination FtpClient instance to interact with the destination FTP server
# + listenerName - listener name for logging purposes
# + logId - log id
# + incomingMsg - incoming message that is being skipped
# + fileId - identifier for the file being processed
# + direction - direction of message (inward or outward)
# + mtmsgType - message type of the MT message
# + mxMsgType - message type of the MX message
function handleSkip(FtpClient sourceClient, FtpClient destinationClient, string listenerName, string logId, 
    string incomingMsg, string fileId, string direction, string mtmsgType = NOT_AVAILABLE, 
    string mxMsgType = NOT_AVAILABLE) {

    log:printInfo(string `[Listner - ${listenerName}][${logId}] Message type is not supported. 
        Skipping message translation.`);
    sendToSourceFTP(sourceClient, logId, SKIP, incomingMsg, fileId);
    sendToDestinationFTP(destinationClient, logId, incomingMsg, fileId, "");
    appendToDashboardLogs(listenerName, incomingMsg, translatedMessage = NOT_AVAILABLE, msgId = fileId,
            direction = direction, mtmsgType = mtmsgType, mxMsgType = mxMsgType, currency = NOT_AVAILABLE,
            amount = NOT_AVAILABLE, status = SKIPPED);
    cleanTempFile(fileId, logId, listenerName);
    return;
}

# Handle successful message translation and sending to FTP servers.
#
# + sourceClient - source FtpClient instance to interact with the source FTP server
# + destinationClient - destination Ftp Client instance to interact with the destination FTP server
# + listenerName - listener name for logging purposes
# + logId - log id
# + incomingMsg - incoming message
# + translatedMsg - translated message
# + fileId - file identifier for the message being processed 
# + direction - direction of the message (inward or outward)
# + mtmsgType - mt message type
# + mxMsgType - mx message type
# + currency - currency of transaction
# + amount - amount of transaction  
# + fileType - file type
function handleSuccess(FtpClient sourceClient, FtpClient destinationClient, string listenerName, string logId, 
        string incomingMsg, string translatedMsg, string fileId, string direction, string mtmsgType, string mxMsgType, 
        string currency = NOT_AVAILABLE, string amount = NOT_AVAILABLE, string fileType = "txt") {

    log:printInfo(string `[Listner - ${listenerName}][${logId}] Message translated successfully. Sending to FTP.`);
    sendToSourceFTP(sourceClient, logId, SUCCESS, incomingMsg, fileId);
    sendToDestinationFTP(destinationClient, logId, translatedMsg, fileId, fileType);
    appendToDashboardLogs(listenerName, incomingMsg, translatedMessage = translatedMsg, msgId = fileId,
            direction = direction, mtmsgType = mtmsgType, mxMsgType = mxMsgType, currency = currency,
            amount = amount, status = SUCCESSFUL);
    cleanTempFile(fileId, logId, listenerName);
    return;
}

# Append a log entry to the dashboard logs file.
#
# + listenerName - ftp listener name for logging purposes
# + orgnlMessage - original message
# + translatedMessage - translated message
# + msgId - message id
# + direction - direction of the message (inward or outward)
# + mtmsgType - MT message type
# + mxMsgType - MX message type
# + currency - currency of the transaction
# + amount - amount of the transaction
# + errorMsg - error message
# + status - status of the operation (successful, failed, skipped)
function appendToDashboardLogs(string listenerName, string orgnlMessage, string translatedMessage, string msgId, 
    string direction, string mtmsgType, string mxMsgType, string currency, string amount, string errorMsg = "", 
    string status = SUCCESSFUL) {

    // Create values for the JSON object
    time:Utc currentTime = time:utcNow();
    time:Civil civilTime = time:utcToCivil(currentTime);
    string|error timestamp = time:civilToString(civilTime);
    if timestamp is error {
        log:printError(string `[Listner - ${listenerName}][${msgId}] Error while generating timestamp. 
            Setting default value.`, err = timestamp.toBalString());
        timestamp = "0000-00-00T00:00:00Z";
    }
    else {

        // Create the JSON log entry
        json logEntry = {
            "id": msgId,
            "mtMessageType": mtmsgType,
            "mxMessageType": mxMsgType,
            "currency": currency,
            "amount": amount,
            "date": timestamp,
            "direction": direction,
            "translatedMessage": translatedMessage,
            "status": status,
            "originalMessage": orgnlMessage,
            "fieldError": errorMsg.includes("required") ? errorMsg : "",
            "notSupportedError": errorMsg.toLowerAscii().includes("not supported") ? errorMsg : "",
            "invalidError": errorMsg.toLowerAscii().includes("invalid")
                && !errorMsg.toLowerAscii().includes("not supported") ? errorMsg : "",
            "otherError": !errorMsg.includes("required") && !errorMsg.includes("not supported")
                && !errorMsg.toLowerAscii().includes("invalid") ? errorMsg : ""
        };

        // Convert to JSON string and append newline
        string jsonLogString = logEntry.toJsonString() + "\n";

        // Write to file
        io:FileWriteOption option = OPTION_APPEND;
        time:Utc utc = time:utcNow();
        string date = time:utcToString(utc).substring(0, 9);
        string filePath = log.dashboardLogFilePath + "dashboard" + date + ".log";
        io:Error? fileWriteString = io:fileWriteString(filePath, jsonLogString, option);
        if fileWriteString is io:Error {
            handleLogFailure(listenerName, msgId, fileWriteString);
        }
    }
}

# Handle errors while logging to the dashboard.
#
# + listenerName - listener name for logging purposes
# + logId - log id
# + e - error encountered during logging
function handleLogFailure(string listenerName, string logId, error e) {
    log:printError(string `[Listner - ${listenerName}][${logId}] Error while logging to dashboard.`, 
        err = e.toBalString());
}

# Send a message to the source FTP server.
#
# + ftpClient - ftpClient instance to interact with the FTP server
# + logId - log identifier for tracking the operation
# + status - status of the operation (success, failure, skip)
# + message - content of the message to be sent
# + fileName - name of the file being processed
function sendToSourceFTP(FtpClient ftpClient, string logId, string status, string message, string fileName) {

    log:printInfo(string `[Client - ${ftpClient.clientConfig.name}][${logId}] Sending message to FTP. Status: ${status} 
        Message ID: ${fileName}`);
    string directory;
    match status {
        "success" => {
            directory = ftpClient.clientConfig.successFilepath;
        }
        "failure" => {
            directory = ftpClient.clientConfig.failedFilepath;
        }
        "skip" => {
            directory = ftpClient.clientConfig.skippedFilepath;
        }
        _ => {
            directory = "unknown";
            log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] Unknown file write status: 
                ${status}`);
            return;
        }
    }

    string fileId = fileName != "" ? fileName : logId;

    string outputFileName = string `${directory}/${fileId}`;

    ftp:Error? ftpWrite = (ftpClient.'client)->put(outputFileName, message);
    if ftpWrite is ftp:Error {
        log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] Error while sending SWIFT message 
            to FTP`, err = ftpWrite.toBalString());
    }
}


# Send a message to the destination FTP server.
#
# + ftpClient - ftp client instance to interact with the FTP server
# + logId - log identifier for tracking the operation  
# + message - message content to be sent
# + msgId - message id 
# + fileType - file type of the message
function sendToDestinationFTP(FtpClient ftpClient, string logId, string message, string msgId, string fileType) {

    log:printDebug(string `[Client - ${ftpClient.clientConfig.name}][${logId}] 
        Sending message to FTP. Message ID: ${msgId}`);
    time:Utc currentTime = time:utcNow();
    time:Civil civilTime = time:utcToCivil(currentTime);
    string|time:Error timestamp = time:civilToString(civilTime);
    if timestamp is time:Error {
        log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] 
            Error while generating timestamp`, err = timestamp.toBalString());
        return;
    }
    string fileSuffix = timestamp.substring(0, 10) + "_" + timestamp.substring(11, 13) + "-" + 
        timestamp.substring(14, 16) + "-" + timestamp.substring(17, 19);
    string directory = ftpClient.clientConfig.outwardFilepath;

    string:RegExp separator = re `\.`;
    string fileId = msgId != "" ? separator.split(msgId)[0] : logId;
    string extension = fileType != "" ? string `.${fileType}` : "";
    string outputFileName = string `${directory}/${fileId}_${fileSuffix}${extension}`;

    ftp:Error? ftpWrite = (ftpClient.'client)->put(outputFileName, message);
    if ftpWrite is ftp:Error {
        log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] Error while sending SWIFT 
            message to FTP`, err = ftpWrite.toBalString());
    }
}

# Get information about the MT message.
#
# + listenerName - listener name for logging purposes
# + message - the MT message content
# + return - a tuple containing the message type, currency, and amount
function getMtMessageInfo(string listenerName, string message) returns [string, string, string] {

    [string, string, string] [msgType, msgCcy, msgAmnt] = [];
    msgType = UNKNOWN;

    foreach string msgTyp in MT_MESSAGE_NAMES {
        if msgTyp.length() >= 3 &&
            (message.includes("2:I" + msgTyp.substring(0, 3)) || message.includes("2:O" + msgTyp.substring(0, 3))) {
            if msgTyp.length() > 3 && message.includes("119:" + msgTyp.substring(3)) {
                msgType = msgTyp;
                break;
            }
            msgType = msgTyp.substring(0, 3);
        }
    }

    foreach string mtField in MT_TRANS_AMNT_FIELD {
        if message.includes(":" + mtField.substring(2) + ":") {
            // ensure type of a constant. No need to handle error.
            int|error index = message.indexOf(":" + mtField.substring(2) + ":").ensureType(int);
            if index is error {
                log:printWarn(string `[Listener - ${listenerName}] Error occurred while getting the transaction 
                    currency and amount.`, index);
                msgCcy = NOT_AVAILABLE;
                msgAmnt = NOT_AVAILABLE;
                return [msgType, msgCcy, msgAmnt];
            }
            int|error endIndex = message.indexOf("\n", index).ensureType(int);
            if endIndex is error {
                log:printWarn(string `[Listener - ${listenerName}] Error occurred while getting the transaction 
                    currency and amount.`, endIndex);
                msgCcy = NOT_AVAILABLE;
                msgAmnt = NOT_AVAILABLE;
                return [msgType, msgCcy, msgAmnt];
            }
            if mtField == "MT32B" {
                msgCcy = message.length() > index + 7 ? message.substring(index + 5, index + 8) : NOT_AVAILABLE;
                msgAmnt = message.length() > index + 8 ? message.substring(index + 8, endIndex) : NOT_AVAILABLE;
                break;
            }
            msgCcy = message.length() > index + 14 ? message.substring(index + 11, index + 14) : NOT_AVAILABLE;
            msgAmnt = message.length() > index + 14 ? message.substring(index + 14, endIndex) : NOT_AVAILABLE;
        }
    }

    return [msgType, msgCcy, regex:replace(msgAmnt, "\\,", ".")];
}

# Get the MX message type from the XML content.
#
# + xmlContent - the XML content of the MX message
# + return - the MX message type or an error
function getMxMessageType(xml xmlContent) returns string|error {
    xml:Element document = xml `<Empty/>`;
    foreach xml:Element element in xmlContent.elementChildren() {
        if element.getName().includes("Document") {
            document = element;
        }
    }
    map<string> attributeMap = (document).getAttributes();
    foreach string attributeKey in attributeMap.keys() {
        if attributeKey.includes("xmlns") {
            foreach string recordKey in isoMessageTypes.keys() {
                string? nameSpace = attributeMap[attributeKey];
                if nameSpace is string && nameSpace.includes(recordKey) {
                    int index = check nameSpace.indexOf(recordKey).ensureType();
                    return nameSpace.substring(index);
                }
            }
        }
    }
    return UNKNOWN;
}

# Clean up temporary files created during processing.
#
# + fileName - name of the temporary file to be deleted
# + logId - unique identifier for the log entry
# + listenerName - name of the listener
function cleanTempFile(string fileName, string logId, string listenerName) {
    error? fileDelete = file:remove(string `/tmp/swiftTranslator/${fileName}`);
    if fileDelete is error {
        log:printError(string `[Listner - ${listenerName}][${logId}] Error while deleting temporary file`,
                err = fileDelete.toBalString());
    } else {
        log:printDebug(string `[Listner - ${listenerName}][${logId}] Temporary file deleted successfully.`);
    }
}

# Get the transaction currency and amount from the SWIFT MT message.
#
# + swiftMessage - the SWIFT message record
# + return - the transaction currency and amount
function getTransactionCcyAndAmnt(record {} swiftMessage) returns [string, string] {
    string|error ccy = "";
    string|error amnt = "";

    foreach string mtField in MT_TRANS_AMNT_FIELD {
        if swiftMessage[BLOCK4] is record {} && (<record {}>swiftMessage[BLOCK4])[string `${mtField}`] is record {} {

            ccy = (<record {}>(<record {}>(<record {}>swiftMessage[BLOCK4])[string `${mtField}`])["Ccy"])["content"].ensureType();
            amnt = (<record {}>(<record {}>(<record {}>swiftMessage[BLOCK4])[string `${mtField}`])["Amnt"])["content"].ensureType();
        }
    }

    if ccy is string && amnt is string {
        return [ccy, regex:replace(amnt, "\\,", ".")];
    }
    if ccy is error && amnt is string {
        return [NOT_AVAILABLE, regex:replace(amnt, "\\,", ".")];
    }
    if amnt is error && ccy is string {
        return [ccy, NOT_AVAILABLE];
    }
    return [NOT_AVAILABLE, NOT_AVAILABLE];
}

# Generate a unique log ID.
# + return - the generated log ID
function generateLogId() returns string {
    return uuid:createType1AsString();
}

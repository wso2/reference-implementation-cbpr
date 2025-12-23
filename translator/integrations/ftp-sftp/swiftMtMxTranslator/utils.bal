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
# + refId - reference id
function handleError(FtpClient ftpClient, string listenerName, string logId, string incomingMsg, error errorMsg,
        string fileId, string direction, string refId) {
    log:printInfo(string `[Listener - ${listenerName}][${logId}] Message translation failed. Sending to FTP.`);
    sendToSourceFTP(ftpClient, logId, FAILURE, incomingMsg, fileId);
    appendToDashboardLogs(listenerName, incomingMsg, translatedMessage = getErrorMessage(errorMsg), msgId = fileId, refId = refId,
            direction = direction, mtmsgType = UNKNOWN, mxMsgType = UNKNOWN, currency = NOT_AVAILABLE,
            amount = NOT_AVAILABLE, errorMsg = errorMsg.toBalString(), status = FAILED);
    return;
}

function getErrorMessage(error errorMsg) returns string {
    any|error details = errorMsg.detail();
    if details is map<any> && details.hasKey("body") && details["body"] is map<any> {
        map<any> body = <map<any>>details["body"];
        if body.hasKey("message") && body["message"] is string {
            return <string>body["message"];
        }
    } else if errorMsg.message().length() > 0 {
        return errorMsg.message();
    }
    return NOT_AVAILABLE;
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
# + refId - reference id
# + mtmsgType - message type of the MT message  
# + mxMsgType - message type of the MX message  
# + extension - file extension for storing the skipped message
function handleSkip(FtpClient sourceClient, FtpClient destinationClient, string listenerName, string logId,
        string incomingMsg, string fileId, string direction, string refId, string mtmsgType = NOT_AVAILABLE,
        string mxMsgType = NOT_AVAILABLE, string extension = "") {

    log:printInfo(string `[Listener - ${listenerName}][${logId}] Message type is not supported. ` + 
        "Skipping message translation.");

    // Post-process the skipped MT or MX message if the extension is enabled.
    string|error postProcessedMsg;
    if direction == OUTWARD {
        postProcessedMsg = postProcessSkippedMtMxMessage(incomingMsg, logId);
    } else {
        postProcessedMsg = postProcessSkippedMxMtMessage(incomingMsg, logId);
    }

    if postProcessedMsg is error {
        log:printError(string `[Listner - ${listenerName}][${logId}] Error while post-processing skipped message.`,
                err = postProcessedMsg.toBalString());
        handleError(sourceClient, listenerName, logId, incomingMsg, postProcessedMsg, fileId, direction, refId);
        return;
    }

    sendToSourceFTP(sourceClient, logId, SKIP, postProcessedMsg, fileId);
    sendToDestinationFTP(destinationClient, logId, postProcessedMsg, fileId, false, extension);
    appendToDashboardLogs(listenerName, postProcessedMsg, translatedMessage = NOT_AVAILABLE, msgId = fileId, refId = refId,
            direction = direction, mtmsgType = mtmsgType, mxMsgType = mxMsgType, currency = NOT_AVAILABLE,
            amount = NOT_AVAILABLE, status = SKIPPED);
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
# + refId - reference id
# + mtmsgType - mt message type  
# + mxMsgType - mx message type  
# + currency - currency of transaction  
# + amount - amount of transaction
function handleSuccess(FtpClient sourceClient, FtpClient destinationClient, string listenerName, string logId,
        string incomingMsg, string|xml translatedMsg, string fileId, string direction, string refId, string mtmsgType,
        string mxMsgType, string currency = NOT_AVAILABLE, string amount = NOT_AVAILABLE) {

    log:printInfo(string `[Listener - ${listenerName}][${logId}] Message translated successfully. Sending to FTP.`);
    sendToSourceFTP(sourceClient, logId, SUCCESS, incomingMsg, fileId);
    sendToDestinationFTP(destinationClient, logId, translatedMsg, fileId);
    appendToDashboardLogs(listenerName, incomingMsg, translatedMessage = translatedMsg.toBalString(), msgId = fileId,
            refId = refId, direction = direction, mtmsgType = mtmsgType, mxMsgType = mxMsgType, currency = currency,
            amount = amount, status = SUCCESSFUL);
    return;
}

# Append a log entry to the dashboard logs file.
#
# + listenerName - ftp listener name for logging purposes
# + orgnlMessage - original message
# + translatedMessage - translated message
# + msgId - message id
# + refId - reference id
# + direction - direction of the message (inward or outward)
# + mtmsgType - MT message type
# + mxMsgType - MX message type
# + currency - currency of the transaction
# + amount - amount of the transaction
# + errorMsg - error message
# + status - status of the operation (successful, failed, skipped)
function appendToDashboardLogs(string listenerName, string orgnlMessage, string translatedMessage, string msgId,
        string refId, string direction, string mtmsgType, string mxMsgType, string currency, string amount,
        string errorMsg = "", string status = SUCCESSFUL) {

    // Create values for the JSON object
    time:Utc currentTime = time:utcNow();
    time:Civil civilTime = time:utcToCivil(currentTime);
    string|error timestamp = time:civilToString(civilTime);
    string timeString = timestamp is string ? timestamp : "0000-00-00T00:00:00Z";

    // Create the JSON log entry
    json logEntry = {
        "id": msgId,
        "refId": refId,
        "mtMessageType": mtmsgType,
        "mxMessageType": mxMsgType,
        "currency": currency,
        "amount": amount,
        "date": timeString,
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
    string date = time:utcToString(utc).substring(0, 10);
    string filePath = log.dashboardLogFilePath + "dashboard-" + date + ".log";
    io:Error? fileWriteString = io:fileWriteString(filePath, jsonLogString, option);
    if fileWriteString is io:Error {
        handleLogFailure(listenerName, msgId, fileWriteString);
    }
}

# Handle errors while logging to the dashboard.
#
# + listenerName - listener name for logging purposes
# + logId - log id
# + e - error encountered during logging
function handleLogFailure(string listenerName, string logId, error e) {
    log:printError(string `[Listener - ${listenerName}][${logId}] Error while logging to dashboard.`,
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

    ftp:Client? 'client = ftpClient.'client;
    if 'client is ftp:Client {
        string directory;
        match status {
            "success" => {
                directory = ftpClient.clientConfig.bkpSuccessFilepath;
            }
            "failure" => {
                directory = ftpClient.clientConfig.bkpFailedFilepath;
            }
            "skip" => {
                directory = ftpClient.clientConfig.bkpSkippedFilepath;
            }
            _ => {
                directory = "unknown";
                log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] ` + 
                    string `Unknown file write status: ${status}`);
                return;
            }
        }

        string fileId = fileName != "" ? fileName : logId;

        string outputFileName = string `${directory}/${fileId}`;

        ftp:Error? ftpWrite = ('client)->put(outputFileName, message);
        if ftpWrite is ftp:Error {
            log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] ` + 
                string `Error while sending SWIFT message to FTP ${outputFileName}`, err = ftpWrite.toBalString());
        } else {
            log:printInfo(string `[Client - ${ftpClient.clientConfig.name}][${logId}] ` +
                string `Sending message to FTP ${outputFileName}. Status: ${status} Message ID: ${fileName}`);
        }
    } else {
        log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] FTP client is not initialized.`);
    }
}

# Send a message to the destination FTP server.
#
# + ftpClient - ftp client instance to interact with the FTP server  
# + logId - log identifier for tracking the operation  
# + message - message content to be sent  
# + msgId - message id  
# + translated - indicates if the message is translated or not
# + fileExtension - file extension for storing the message
function sendToDestinationFTP(FtpClient ftpClient, string logId, string|xml message, string msgId,
        boolean translated = true, string fileExtension = "") {

    ftp:Client? 'client = ftpClient.'client;
    if 'client is ftp:Client {
        time:Utc currentTime = time:utcNow();
        time:Civil civilTime = time:utcToCivil(currentTime);
        string|time:Error timestamp = time:civilToString(civilTime);
        if timestamp is time:Error {
            log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] Error while generating timestamp`, 
                err = timestamp.toBalString());
            return;
        }
        string fileSuffix = timestamp.substring(0, 10) + "_" + timestamp.substring(11, 13) + "-" +
        timestamp.substring(14, 16) + "-" + timestamp.substring(17, 19);
        string directory = ftpClient.clientConfig.outwardFilepath;

        string:RegExp separator = re `\.`;
        string fileId = msgId != "" ? separator.split(msgId)[0] : logId;
        string extension;
        string outputFileName;
        if translated {
            extension = fileExtension != "" ? fileExtension : ftpClient.clientConfig.outputFileNamePattern;
            outputFileName = string `${directory}/${fileId}_${fileSuffix}${extension}`;
        } else {
            // not translated message (assumed to be skipped message)
            extension = fileExtension != "" ? string `.${fileExtension}` : ftpClient.clientConfig.skippedOutputFileNamePattern;
            outputFileName = string `${directory}/${fileId}${extension}`;
        }

        ftp:Error? ftpWrite = ('client)->put(outputFileName, message);
        if ftpWrite is ftp:Error {
            log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] ` + 
                string `Error while sending SWIFT message to FTP ${outputFileName}`, err = ftpWrite.toBalString());
        } else {
            log:printDebug(string `[Client - ${ftpClient.clientConfig.name}][${logId}]` +
                string `Sending message to FTP ${outputFileName}. Message ID: ${msgId}`);
        }
    } else {
        log:printError(string `[Client - ${ftpClient.clientConfig.name}][${logId}] FTP client is not initialized.`);
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
                log:printWarn(string `[Listener - ${listenerName}] ` + 
                    "Error occurred while getting the transaction currency and amount.", index);
                msgCcy = NOT_AVAILABLE;
                msgAmnt = NOT_AVAILABLE;
                return [msgType, msgCcy, msgAmnt];
            }
            int|error endIndex = message.indexOf("\n", index).ensureType(int);
            if endIndex is error {
                log:printWarn(string `[Listener - ${listenerName}] ` + 
                    "Error occurred while getting the transaction currency and amount.", endIndex);
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
        log:printError(string `[Listener - ${listenerName}][${logId}] Error while deleting temporary file`,
                err = fileDelete.toBalString());
    } else {
        log:printDebug(string `[Listener - ${listenerName}][${logId}] Temporary file deleted successfully.`);
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

// TODO: Remove `toXmlString` function once following Bal issue is fixed.
// https://github.com/wso2-enterprise/wso2-integration-internal/issues/2231
# Convert an XML message to a properly formatted XML string with declaration.
#
# + message - the XML message to be converted to string format
# + return - the XML message as a string with proper XML declaration
function toXmlString(xml message) returns string {
    if message.toString().includes("<?xml") {
        return message.toString();
    }
    return string `<?xml version="1.0" encoding="UTF-8"?>${message.toString()}`;
}

function extractRefId(json? mtMsgBlock4, xml? mxMsg) returns string {

    string refId = UNKNOWN;
    if mtMsgBlock4 is json && mtMsgBlock4?.MT20?.msgId?.content is string {
        json|error id = mtMsgBlock4?.MT20?.msgId?.content;
        if id is json {
            refId = id.toString();
        }
    }
    if refId == UNKNOWN && mxMsg is xml {
        refId = (mxMsg/**/<head:BizMsgIdr>).data();
    }
    return refId;
}


# Get the file name from the context if in batch mode; otherwise, use the provided file name.
#
# + fileName - the default file name
# + context - the context map containing batch mode information
# + return - the appropriate file name or an error
function getFileName(string fileName, map<any> context) returns string|error {
    if context.hasKey(IS_BATCH) && (check boolean:fromString(context[IS_BATCH].toString())) {
        string|error ctxFileName = context[FILE_NAME].ensureType();
        string extension = context.hasKey(FILE_EXTENSION) ? "." + context[FILE_EXTENSION].toString() : "";
        string batchIndex = context.hasKey(BATCH_INDEX) ? context[BATCH_INDEX].toString() : "";
        if ctxFileName is string {
            if extension != "" && ctxFileName.endsWith(extension) {
                string fileNameWithoutExtension = ctxFileName.substring(0, ctxFileName.length() - extension.length());
                return string `${fileNameWithoutExtension}_${batchIndex}${extension}`;
            }
            return string `${ctxFileName}_${batchIndex}`;
        }
    }
    return fileName;
}

# Split a bulk MX message into individual transactions.
#
# + inputMsg - input MX message
# + return - return an array of individual MX messages
function splitInputToSingleTransactions(string inputMsg) returns string[] {

    string[] splittedStrings = re `<\?xml`.split(inputMsg);
    string[] transactions = [];
    foreach string input in splittedStrings {
        if input.trim().length() > 0 {
            transactions.push("<?xml" + input);
        }
    }
    return transactions;
}

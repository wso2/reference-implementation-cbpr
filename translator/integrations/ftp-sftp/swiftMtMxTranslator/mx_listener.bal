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
import ballerina/io;
import ballerina/log;
import ballerinax/financial.iso20022ToSwiftmt as mxToMt;
import ballerinax/financial.swift.mt as swiftmt;

// MX->MT Translator service
ftp:Service mxFileListenerService = service object {

    remote function onFileChange(ftp:WatchEvent & readonly event, ftp:Caller caller) returns error? {

        foreach ftp:FileInfo addedFile in event.addedFiles {

            string logId = generateLogId();
            map<any> context = {};
            log:printInfo(string `[Listener - ${mxMtListenerName}][${logId}] File received: ${addedFile.name}`);
            context[FILE_NAME] = addedFile.name;
            context[FILE_EXTENSION] = addedFile.extension;
            // Get the newly added file from the SFTP server as a `byte[]` stream.
            stream<byte[] & readonly, io:Error?> fileStream = check caller->get(addedFile.pathDecoded);

            // copy to local file system
            check io:fileWriteBlocksFromStream(string `/tmp/swiftTranslator/${addedFile.name}`, fileStream);
            check fileStream.close();

            // performs a read operation to read the lines as an array.
            string inMsg = check io:fileReadString(string `/tmp/swiftTranslator/${addedFile.name}`);

            log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] Incoming message: ${inMsg}`);

            // Delete the file from the SFTP server after reading.
            check caller->delete(addedFile.pathDecoded);

            // Check if the incoming message is a SWIFT MX message.
            if inMsg.startsWith("<?xml") {
                string[] splittedMsg = splitInputToSingleTransactions(inMsg);
                if splittedMsg.length() > 1 {
                    log:printDebug(string `[Listener - ${mxMtListenerName}] Incoming message has multiple messages. ` + 
                        "Starting batch processing.");
                    context[IS_BATCH] = "true";
                    int i = 1;
                    foreach string msg in splittedMsg {
                        if msg.trim().length() > 0 {
                            context[BATCH_INDEX] = i;
                            handleMxMtTranslation(msg, addedFile.name, string `${logId}_${i}`, context);
                        }
                        i += 1;
                    }
                    // save original batch file in success folder
                    sendToSourceFTP(mxMtClientObj, logId, SUCCESS, inMsg, addedFile.name);
                } else {
                    // only one message available. Proceed with translation.
                    handleMxMtTranslation(inMsg, addedFile.name, logId, context);
                }
            } else if inMsg.startsWith("{1:") {            
                // Incoming message is a SWIFT MT message. Do not process it.
                log:printInfo(string `[Listener - ${mxMtListenerName}] Incoming message is a SWIFT MT message.` + 
                    " Skipping processing.");
                handleSkip(mxMtClientObj, mtMxClientObj, mxMtListenerName, logId, inMsg, addedFile.name, INWARD, 
                    UNKNOWN, addedFile.extension);
            } else {
                // If message is neither MX nor MT, log error and move to error folder.
                log:printError(string `[Listener - ${mxMtListenerName}][${logId}] Invalid input message.`);
                handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, error("Invalid input message"), addedFile.name, 
                    INWARD, UNKNOWN);
            }
            cleanTempFile(addedFile.name, logId, mxMtListenerName);
        }
    }
};

// Handle the translation of MX to MT messages.
function handleMxMtTranslation(string inMsg, string fileName, string logId, map<any> context) {

    // Pre-process the incoming MX message if the extension is enabled.
    string|error iso20022MessageString = preProcessMxMtMessage(inMsg, logId);
    string|error processingFileName = getFileName(fileName, context);

    if processingFileName is error {
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}] Error while retrieving file name from context.`,
                err = processingFileName.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, processingFileName, fileName, INWARD, UNKNOWN);
        return;
    }

    if iso20022MessageString is error {
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}] Error while pre-processing MX message.`,
                err = iso20022MessageString.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, iso20022MessageString, processingFileName, INWARD, 
            UNKNOWN);
        return;
    }

    xml|error iso20022Message = xml:fromString(iso20022MessageString);
    if iso20022Message is error {
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}] Error occurred while converting the string to XML.`, 
            err = iso20022Message.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, iso20022Message, processingFileName, INWARD, UNKNOWN);
        return;

    }

    record {}|error mtRecord = mxToMt:toSwiftMtMessage(iso20022Message);

    string refId = extractRefId((), iso20022Message);

    if mtRecord is error {
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}]` + 
            " Error occurred while converting the ISO20022 message to SWIFT MT message.", err = mtRecord.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, mtRecord, processingFileName, INWARD, refId);
        return;
    }
    string|error mxMsgType = getMxMessageType(iso20022Message);
    if mxMsgType is error {
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}] Error while retrieving MX message type.`,
            err = mxMsgType.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, mxMsgType, processingFileName, INWARD, refId);
        return;
    }

    // Identify MT message type from the parsed message.
    string mtMsgType = "";
    if mtRecord[BLOCK2] is record {} {
        record {} block2 = <record {}>mtRecord[BLOCK2];
        mtMsgType = block2[MESSAGE_TYPE] is string ? block2[MESSAGE_TYPE].toString() : "";
    }
    if mtMsgType == "" {
        log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] Parsed MT message: ${mtRecord.toBalString()}`);
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}] Error while retrieving MT message type.`,
                error("Invalid MT message type."));
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, error("Invalid MT message type."),
                processingFileName, INWARD, refId);
        return;
    }

    string|error validationFlag = "";
    if mtRecord[BLOCK3] is record {} {
        if (<record {}>mtRecord[BLOCK3])[VALIDATION_FLAG] is record {} {
            validationFlag = (<record {}>(<record {}>mtRecord[BLOCK3])[VALIDATION_FLAG])[VALUE].ensureType();
        }
    }
    if validationFlag is string && 
        (validationFlag.equalsIgnoreCaseAscii("REMIT") || validationFlag.equalsIgnoreCaseAscii("COV")) {
        mtMsgType = mtMsgType + validationFlag;
    }
    log:printInfo(string `[Listener - ${mxMtListenerName}][${logId}]` + 
        string ` Successfully converted the ${mxMsgType} ISO20022 message to SWIFT MT ${mtMsgType} message.`);
    [string, string] [msgCcy, msgAmnt] = getTransactionCcyAndAmnt(mtRecord);

    string|error finMessage = swiftmt:toFinMessage(mtRecord);
    if finMessage is error {
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}]` + 
            "Error occurred while converting the SWIFT MT message to FIN message.", err = finMessage.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, finMessage, processingFileName, INWARD, refId);
        return;
    }

    // Post-process the translated MX message if the extension is enabled.
    string|error postProcessedMsg = postProcessMxMtMessage(finMessage, iso20022MessageString, logId);
    if postProcessedMsg is error {
        log:printError(string `[Listener - ${mxMtListenerName}][${logId}] Error while post-processing FIN message.`,
                err = postProcessedMsg.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, postProcessedMsg, processingFileName, INWARD, refId);
        return;
    }

    handleSuccess(mxMtClientObj, mtMxClientObj, mxMtListenerName, logId, inMsg, postProcessedMsg, processingFileName,
            INWARD, refId, mtMsgType, mxMsgType, msgCcy, msgAmnt);
}

// Pre-process the incoming MX message if the extension is enabled.
function preProcessMxMtMessage(string message, string logId) returns string|error {
    if !translator.mxMtExtension.preProcess {
        log:printInfo(string `[Listener - ${mxMtListenerName}][${logId}]` + 
            " Pre-processing is disabled. Skipping pre-processing.");
        return message;
    }
    log:printInfo(string `[Listener - ${mxMtListenerName}][${logId}] MXMT pre-process extension engaged.`);
    log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] Pre-processing message: ${message.toBalString()}`);
    string|error mxmtClientResponse = mxmtExtHttpClient->post(MX_MT_PRE_PROCESS_CONTEXT_PATH, message);

    if mxmtClientResponse is error {
        log:printError(string `[Listener - ${mxMtListenerName}] Error occurred while calling MXMT preprocess endpoint.`,
                err = mxmtClientResponse.toBalString());
    } else {
        log:printInfo(string `[Listener - ${mxMtListenerName}][${logId}] MXMT pre-process response received.`);
        log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] MXMT pre-process response: ` + 
            string `${mxmtClientResponse.toBalString()}`);
    }
    return mxmtClientResponse;
}

// Post-process the translated MX message if the extension is enabled.
function postProcessMxMtMessage(string message, string originalMessage, string logId) returns string|error {

    if !translator.mxMtExtension.postProcess {
        log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] Post-processing is disabled. ` + 
            "Skipping post-processing.");
        return message;
    }
    log:printInfo(string `[Listener - ${mxMtListenerName}][${logId}] MXMT post-process extension engaged.`);
    log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] Post-processing message: ${message.toBalString()}`);
    http:Request clientRequest = new;
    clientRequest.setHeader("Content-Type", "application/json");
    clientRequest.setPayload({"translatedMessage": message.toString(), "originalMessage": originalMessage});

    string|error mxmtClientResponse = mxmtExtHttpClient->post(MX_MT_POST_PROCESS_CONTEXT_PATH, clientRequest);

    if mxmtClientResponse is error {
        log:printError(string `[Listener - ${mxMtListenerName}] Error occurred while calling MXMT postprocess endpoint.`,
                err = mxmtClientResponse.toBalString());
        return mxmtClientResponse;
    }
    return mxmtClientResponse;
}

// Post-process the skipped MX message if the extension is enabled.
function postProcessSkippedMxMtMessage(string originalMessage, string logId) returns string|error {

    if !translator.mxMtExtension.skippedMsgPostProcess {
        log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] Skipped message Post-processing is disabled. ` + 
            "Skipping post-processing.");
        return originalMessage;
    }
    log:printInfo(string `[Listener - ${mxMtListenerName}][${logId}] MXMT skipped message post-process extension engaged.`);
    log:printDebug(string `[Listener - ${mxMtListenerName}][${logId}] Skipped Post-processing message: ${originalMessage.toBalString()}`);

    http:Request clientRequest = new;
    clientRequest.setHeader("Content-Type", "application/json");
    clientRequest.setPayload({"translatedMessage": "", "originalMessage": originalMessage});

    string|error mxmtClientResponse = mxmtExtHttpClient->post(MX_MT_SKIPPED_POST_PROCESS_CONTEXT_PATH, clientRequest);

    if mxmtClientResponse is error {
        log:printError(string `[Listener - ${mxMtListenerName}] Error occurred while calling MXMT skipped postprocess endpoint.`,
                err = mxmtClientResponse.toBalString());
        return mxmtClientResponse;
    }
    return mxmtClientResponse;
}

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

// MT->MX Translator service
service on mxFileListener {

    remote function onFileChange(ftp:WatchEvent & readonly event, ftp:Caller caller) returns error? {

        foreach ftp:FileInfo addedFile in event.addedFiles {

            string logId = generateLogId();
            log:printInfo(string `[Listner - ${mxMtListenerName}][${logId}] File received: ${addedFile.name}`);
            // Get the newly added file from the SFTP server as a `byte[]` stream.
            stream<byte[] & readonly, io:Error?> fileStream = check caller->get(addedFile.pathDecoded);
            // Delete the file from the SFTP server after reading.
            check caller->delete(addedFile.pathDecoded);

            // copy to local file system
            check io:fileWriteBlocksFromStream(string `/tmp/swiftTranslator/${addedFile.name}`, fileStream);
            check fileStream.close();

            // performs a read operation to read the lines as an array.
            string inMsg = check io:fileReadString(string `/tmp/swiftTranslator/${addedFile.name}`);

            log:printDebug(string `[Listner - ${mxMtListenerName}][${logId}] Incoming message: ${inMsg}`);

            // Identify if the incoming message is an ISO20022 message.
            if mtRegex.isFullMatch(inMsg) {
                // Incoming message is a SWIFT MT message. Do not process it.
                log:printInfo(string `[Listner - ${mxMtListenerName}] Incoming message is a SWIFT MT message. 
                    Skipping processing.`);
                handleSkip(mxMtClientObj, mtMxClientObj, mxMtListenerName, logId, inMsg, addedFile.name, INWARD);
                return;
            }
            handleMxMtTranslation(inMsg, addedFile.name, logId);
        }
    }

    function init() {
        log:printInfo(string `[Listner - ${mxMtListenerName}] Listener started.`);

    }
}

// Handle the translation of MX to MT messages.
function handleMxMtTranslation(string inMsg, string fileName, string logId) {

    // Pre-process the incoming MX message if the extension is enabled.
    string|error iso20022MessageString = preProcessMxMtMessage(inMsg, logId);

    if iso20022MessageString is error {
        log:printError(string `[Listner - ${mxMtListenerName}][${logId}] Error while pre-processing MX message.`,
                err = iso20022MessageString.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, iso20022MessageString, fileName, INWARD);
        return;
    }

    xml|error iso20022Message = xml:fromString(iso20022MessageString);
    if iso20022Message is error {
        log:printError(string `[Listner - ${mxMtListenerName}][${logId}] Error occurred while converting the 
            string to XML.`, err = iso20022Message.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, iso20022Message, fileName, INWARD);
        return;

    }

    record {}|error mtRecord = mxToMt:toSwiftMtMessage(iso20022Message);

    if mtRecord is error {
        log:printError(string `[Listner - ${mxMtListenerName}][${logId}] Error occurred while converting the 
            ISO20022 message to SWIFT MT message.`, err = mtRecord.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, mtRecord, fileName, INWARD);
        return;
    }
    string|error mxMsgType = getMxMessageType(iso20022Message);
    if mxMsgType is error {
        log:printError(string `[Listner - ${mxMtListenerName}][${logId}] Error while retrieving MX message type.`,
                err = mxMsgType.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, mxMsgType, fileName, INWARD);
        return;
    }

    // Identify MT message type from the parsed message.
    string mtMsgType = "";
    if mtRecord[BLOCK2] is record {} {
        record {} block2 = <record {}>mtRecord[BLOCK2];
        mtMsgType = block2[MESSAGE_TYPE] is string ? block2[MESSAGE_TYPE].toString() : "";
    }
    if mtMsgType == "" {
        log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] Parsed MT message: 
                ${mtRecord.toBalString()}`);
        log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error while retrieving MT message type.`,
                error("Invalid MT message type."));
        handleError(mtMxClientObj, mtMxListenerName, logId, inMsg, error("Invalid MT message type."),
                fileName, OUTWARD);
        return;
    }

    string|error validationFlag = "";
    if mtRecord[BLOCK3] is record {} {
        if (<record {}>mtRecord[BLOCK3])[VALIDATION_FLAG] is record {} {
            validationFlag = (<record {}>(<record {}>mtRecord[BLOCK3])[VALIDATION_FLAG])[VALUE].ensureType();
        }
    }
    if validationFlag is string {
        mtMsgType = mtMsgType + validationFlag;
    }
    log:printInfo(string `[Listner - ${mxMtListenerName}][${logId}] Successfully converted the ${mxMsgType} ISO20022 
        message to SWIFT MT ${mtMsgType} message.`);
    [string, string] [msgCcy, msgAmnt] = getTransactionCcyAndAmnt(mtRecord);

    string|error finMessage = swiftmt:toFinMessage(mtRecord);
    if finMessage is error {
        log:printError(string `[Listner - ${mxMtListenerName}][${logId}] Error occurred while converting the SWIFT MT 
            message to FIN message.`, err = finMessage.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, finMessage, fileName, INWARD);
        return;
    }

    // Post-process the translated MX message if the extension is enabled.
    string|error postProcessedMsg = postProcessMxMtMessage(finMessage, iso20022MessageString, logId);
    if postProcessedMsg is error {
        log:printError(string `[Listner - ${mxMtListenerName}][${logId}] Error while post-processing FIN message.`,
                err = postProcessedMsg.toBalString());
        handleError(mxMtClientObj, mxMtListenerName, logId, inMsg, postProcessedMsg, fileName, INWARD);
        return;
    }

    handleSuccess(mxMtClientObj, mtMxClientObj, mxMtListenerName, logId, inMsg, postProcessedMsg, fileName,
            INWARD, mtMsgType, mxMsgType, msgCcy, msgAmnt, "fin");
}


// Pre-process the incoming MX message if the extension is enabled.
function preProcessMxMtMessage(string message, string logId) returns string|error {
    if !translator.mxMtExtension.preProcess {
        log:printInfo(string `[Listner - ${mxMtListenerName}][${logId}] Pre-processing is disabled. 
            Skipping pre-processing.`);
        return message;
    }
    log:printInfo(string `[Listner - ${mxMtListenerName}][${logId}] MXMT pre-process extension engaged.`);
    log:printDebug(string `[Listner - ${mxMtListenerName}][${logId}] Pre-processing message: ${message.toBalString()}`);
    string|error mxmtClientResponse = mxmtClient->post(MX_MT_PRE_PROCESS_CONTEXT_PATH, message);

    if mxmtClientResponse is error {
        log:printError(string `[Listner - ${mxMtListenerName}] Error occurred while calling MXMT preprocess endpoint.`,
                err = mxmtClientResponse.toBalString());
    } else {
        log:printInfo(string `[Listner - ${mxMtListenerName}][${logId}] MXMT pre-process response received.`);
        log:printDebug(string `[Listner - ${mxMtListenerName}][${logId}] MXMT pre-process response: 
            ${mxmtClientResponse.toBalString()}`);
    }
    return mxmtClientResponse;
}

// Post-process the translated MX message if the extension is enabled.
function postProcessMxMtMessage(string message, string originalMessage, string logId) returns string|error {

    if !translator.mxMtExtension.postProcess {
        log:printDebug(string `[Listner - ${mxMtListenerName}][${logId}] Post-processing is disabled. 
            Skipping post-processing.`);
        return message;
    }
    log:printInfo(string `[Listner - ${mxMtListenerName}][${logId}] MXMT post-process extension engaged.`);
    log:printDebug(string `[Listner - ${mxMtListenerName}][${logId}] Post-processing message: ${message.toBalString()}`);
    http:Request clientRequest = new;
    clientRequest.setHeader("Content-Type", "application/json");
    clientRequest.setPayload({"translatedMessage": message.toString(), "originalMessage": originalMessage});

    string|error mxmtClientResponse = mxmtClient->post(MX_MT_POST_PROCESS_CONTEXT_PATH, clientRequest);

    if mxmtClientResponse is error {
        log:printError(string `[Listner - ${mxMtListenerName}] Error occurred while calling MXMT postprocess endpoint.`,
                err = mxmtClientResponse.toBalString());
        return mxmtClientResponse;
    }
    return mxmtClientResponse;
}

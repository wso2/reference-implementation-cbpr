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

import ballerinax/financial.swift.mt as swiftmt;
import ballerinax/financial.swiftmtToIso20022 as mtToMx;
import ballerina/time;


// MT->MX Translator service
service on mtFileListener {

    // When a file event is successfully received, the `onFileChange` method is called.
    remote function onFileChange(ftp:WatchEvent & readonly event, ftp:Caller caller) returns error? {

        // `addedFiles` contains the paths of the newly-added files/directories after the last polling was called.
        foreach ftp:FileInfo addedFile in event.addedFiles {

            string logId = generateLogId();

            log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] File received: ${addedFile.name}`);
            // Get the newly added file from the SFTP server as a `byte[]` stream.
            stream<byte[] & readonly, io:Error?> fileStream = check caller->get(addedFile.pathDecoded);
            // Delete the file from the SFTP server after reading.
            check caller->delete(addedFile.pathDecoded);

            // copy to local file system
            check io:fileWriteBlocksFromStream(string `/tmp/swiftTranslator/${addedFile.name}`, fileStream);
            check fileStream.close();

            // performs a read operation to read the lines as an array.
            string inMsg = check io:fileReadString(string `/tmp/swiftTranslator/${addedFile.name}`);
            log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] Incoming message: ${inMsg}`);

            handleMtMxTranslation(inMsg, addedFile.name, logId);
        }
    }

    function init() {
        time:Utc utc = time:utcNow();
        string date = time:utcToString(utc).substring(0, 9);
        string filePath = log.ballerinaLogFilePath + "/ballerina" + date + ".log";
        log:Error? outputFile = log:setOutputFile(filePath, log:APPEND);
        if outputFile is log:Error {
            log:printWarn(string `[Listner - ${mtMxListenerName}] Failed to set the output file for ballerina log.`);
        }
        log:printInfo(string `[Listner - ${mtMxListenerName}] Listener started.`);
        
        // Initialize log rotator for daily log rotation
        initLogRotator();
    }
}

// Handle MT->MX translation
function handleMtMxTranslation(string incomingMsg, string fileName, string logId) {

    // Pre-process the incoming MT message if the extension is enabled.
    string|error swiftMessage = preProcessMtMxMessage(incomingMsg, logId);

    if swiftMessage is error {
        log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error while pre-processing MT message.`,
                err = swiftMessage.toBalString());
        handleError(mtMxClientObj, mtMxListenerName, logId, incomingMsg, swiftMessage, fileName, INWARD);
        return;
    }

    // Parse the SWIFT MT message.
    if !mtRegex.isFullMatch(swiftMessage) {
        log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Invalid MT message format.`,
                error("Invalid MT message format. Regex validation failed."));
        // Unsupported messages are treated as skipped messages. 
        // If required, this can be configured to treat as a failure by configuring the 
        // skippedFilepath in the configurables.
        handleSkip(mtMxClientObj, mxMtClientObj, mtMxListenerName, logId, swiftMessage, fileName, INWARD);
        return;
    }

    record {}|error parsedMsg = swiftmt:parse(swiftMessage);
    if parsedMsg is error {
        log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error while parsing MT message. 
                    Invalid MT message.`, parsedMsg);
        handleError(mtMxClientObj, mtMxListenerName, logId, swiftMessage, parsedMsg, fileName, OUTWARD);
        return;
    }
    log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] MT message parsed successfully.`);

    // Identify MT message type from the parsed message.
    string msgType = "";
    if parsedMsg[BLOCK2] is record {} {
        record {} block2 = <record {}>parsedMsg[BLOCK2];
        msgType = block2[MESSAGE_TYPE] is string ? block2[MESSAGE_TYPE].toString() : "";
    }
    if msgType == "" {
        log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] Parsed MT message: 
                ${parsedMsg.toBalString()}`);
        log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Invalid MT message type.`,
                error("Invalid MT message type."));
        handleError(mtMxClientObj, mtMxListenerName, logId, swiftMessage, error("Invalid MT message type."),
                fileName, OUTWARD);
        return;
    }

    // Only convert supported messages
    if supportedMessageTypes.indexOf(msgType) != () {
        log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] Message type ${msgType} is supported. 
            Translator engaged.`);

        xml|error translatedMsg = mtToMx:toIso20022Xml(swiftMessage);

        if translatedMsg is xml {
            [string, string, string] [mtMsgType, msgCcy, msgAmnt] =
                        getMtMessageInfo(mtMxListenerName, swiftMessage);
            string|error mxMsgType = getMxMessageType(translatedMsg);
            if mxMsgType is error {
                log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error while retrieving MX message type.`,
                        err = mxMsgType.toBalString());
                handleError(mtMxClientObj, mtMxListenerName, logId, swiftMessage, mxMsgType, fileName, OUTWARD);
                return;
            }
            log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] MT ${msgType} message translated to 
                MX message type: ${mxMsgType}.`);

            // Post-process the translated MT message if the extension is enabled.
            xml|error postProcessedMsg = postProcessMtMxMessage(translatedMsg, swiftMessage, logId);

            if postProcessedMsg is error {
                log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error while post-processing the 
                    translated message.`, err = postProcessedMsg.toBalString());
                handleError(mtMxClientObj, mtMxListenerName, logId, swiftMessage, postProcessedMsg, fileName, OUTWARD);
                return;
            }
            handleSuccess(mtMxClientObj, mxMtClientObj, mtMxListenerName, logId, swiftMessage,
                    postProcessedMsg.toBalString(), fileName, OUTWARD, mtMsgType, mxMsgType, msgCcy, msgAmnt, "xml");
        } else {
            // If the translation fails, log the error and send the original message to the failed directory.
            log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error while translating MT message to MX.`,
                    err = translatedMsg.toBalString());
            handleError(mtMxClientObj, mtMxListenerName, logId, swiftMessage, translatedMsg, fileName,
                    OUTWARD);
            return;
        }
    } else {
        // If the message type is not supported, log the message and send it to the skip directory.
        log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] Message type is ${msgType}. 
            Translator is not engaged for this message type.`);
        handleSkip(mtMxClientObj, mxMtClientObj, mtMxListenerName, logId, swiftMessage, fileName, OUTWARD);

    }
}


// Pre-process the incoming MT message if the extension is enabled.
function preProcessMtMxMessage(string message, string logId) returns string|error {
    if !translator.mtMxExtension.preProcess {
        log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] Pre-processing is disabled. 
            Skipping pre-processing.`);
        return message;
    }
    log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] MTMX pre-process extension engaged.`);
    log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] Pre-processing message: ${message.toBalString()}`);
    string|error mtmxClientResponse = mtmxClient->post(MT_MX_PRE_PROCESS_CONTEXT_PATH, message);

    if mtmxClientResponse is error {
        log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error occurred while calling MTMX preprocess 
            endpoint.`, err = mtmxClientResponse.toBalString());
    } else {
        log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] MTMX pre-process response received.`);
        log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] MTMX pre-process response: 
            ${mtmxClientResponse.toBalString()}`);
    }
    return mtmxClientResponse;
}

// Post-process the translated MT message if the extension is enabled.
function postProcessMtMxMessage(xml message, string originalMessage, string logId) returns xml|error {

    if !translator.mtMxExtension.postProcess {
        log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] Post-processing is disabled. 
            Skipping post-processing.`);
        return message;
    }
    log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] MTMX post-process extension engaged.`);
    log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] Post-processing message: ${message.toBalString()}`);
    http:Request clientRequest = new;
    clientRequest.setHeader("Content-Type", "application/json");
    clientRequest.setPayload({"message": message.toString(), "originalMessage": originalMessage});

    xml|error mtmxClientResponse = mtmxClient->post(MT_MX_POST_PROCESS_CONTEXT_PATH, clientRequest);

    if mtmxClientResponse is error {
        log:printError(string `[Listner - ${mtMxListenerName}][${logId}] Error occurred while calling MTMX postprocess 
            endpoint.`, err = mtmxClientResponse.toBalString());
        return mtmxClientResponse;
    } else {
        log:printInfo(string `[Listner - ${mtMxListenerName}][${logId}] MTMX post-process response received.`);
        log:printDebug(string `[Listner - ${mtMxListenerName}][${logId}] MTMX post-process response: 
            ${mtmxClientResponse.toBalString()}`);
    }
    return mtmxClientResponse;
}

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

import ballerina/log;
import ballerina/task;
import ballerina/time;

// Log rotation job implementation
class LogRotationJob {
    *task:Job;
    
    public function execute() {
        rotateBallerinaLog();
    }
}

// Initialize log rotator to run daily at 12 AM
public function initLogRotator() returns error? {
    LogRotationJob logRotationJob = new();
    
    // Calculate delay until next 12 AM
    time:Civil|error delayUntilMidnight = calculateDelayUntilMidnight();

    if delayUntilMidnight is error {
        log:printError("Failed to calculate delay until midnight", err = delayUntilMidnight.toBalString());
        return delayUntilMidnight;
    }
    
    // Schedule recurring execution every 24 hours starting from next midnight
    task:JobId|task:Error recurringResult = task:scheduleJobRecurByFrequency(logRotationJob, 86400, maxCount = -1, 
        startTime = delayUntilMidnight);
    if recurringResult is task:Error {
        log:printError("Failed to schedule log rotation task", err = recurringResult.toBalString());
    } else {
        log:printInfo(string `Log rotation task scheduled successfully to run daily at 12 AM`);
    }
}

// Calculate civil time for next day 12 AM
function calculateDelayUntilMidnight() returns time:Civil|error {
    
    time:Zone|error zone = time:loadSystemZone();
    if zone is error {
        return zone;
    }

    time:Utc nextDayUtc = time:utcAddSeconds(time:utcNow(), 86400);
    time:Civil nextDayCivil = zone.utcToCivil(nextDayUtc);

    //todo: Add the proper fix after fixing the issue: https://github.com/wso2-enterprise/wso2-integration-internal/issues/4614
    string|error nextDayCivilStr = time:civilToString(nextDayCivil);
    if nextDayCivilStr is error {
        return nextDayCivilStr;
    }

    time:Civil|error nextDayCivilFromStr = time:civilFromString(nextDayCivilStr);
    if nextDayCivilFromStr is error {
        return nextDayCivilFromStr;
    }
    
    nextDayCivilFromStr.hour = 0;
    nextDayCivilFromStr.minute = 0;
    nextDayCivilFromStr.second = 0.0;
    
    return nextDayCivilFromStr;
}

// Rotate Ballerina log file by updating the file name with current date
function rotateBallerinaLog() {
    time:Utc utc = time:utcNow();
    string date = time:utcToString(utc).substring(0, 10); // YYYY-MM-DD format
    string newLogFilePath =  log.ballerinaLogFilePath + "/ballerina-" + date + ".log";
    
    log:Error? result = log:setOutputFile(newLogFilePath, log:APPEND);
    if result is log:Error {
        log:printError("Failed to rotate log file", err = result.toBalString());
    } else {
        log:printInfo(string `Log file rotated successfully to: ${newLogFilePath}`);
    }
}

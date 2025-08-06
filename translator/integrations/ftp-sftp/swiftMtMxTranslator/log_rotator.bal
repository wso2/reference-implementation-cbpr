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
public function initLogRotator() {
    LogRotationJob logRotationJob = new();
    
    // Calculate delay until next 12 AM
    time:Civil delayUntilMidnight = calculateDelayUntilMidnight();
    string|time:Error timeString = time:civilToString(delayUntilMidnight);
    if timeString is error {
        log:printError("Failed to convert civil time to string", err = timeString.toBalString());
        return;
    }
    
    // Schedule recurring execution every 24 hours starting from next midnight
    task:JobId|task:Error recurringResult = task:scheduleJobRecurByFrequency(logRotationJob, 60, maxCount = -1, startTime = delayUntilMidnight);
    if recurringResult is task:Error {
        log:printError("Failed to schedule log rotation task", err = recurringResult.toBalString());
    } else {
        log:printInfo(string `Log rotation task scheduled successfully to run daily at 12 AM (starting in ${timeString})`);
    }
}

// Calculate civil time for next day 12 AM
function calculateDelayUntilMidnight() returns time:Civil {
    time:Utc currentUtc = time:utcNow();

    // Convert to civil time in your local timezone
    // time:Zone systemZone = check time:loadSystemZone();
    time:Civil currentCivil = time:utcToCivil(currentUtc);

    // Get the next day's date
    time:Date nextDayDate = {
        year: currentCivil.year,
        month: currentCivil.month,
        day: currentCivil.day + 1
    };
    
    // Create a new civil time for the next day at 12 AM
    time:Civil nextDay12Am = {
        year: nextDayDate.year,
        month: nextDayDate.month,
        day: nextDayDate.day,
        hour: 0,
        minute: 0,
        second: 0.0,
        utcOffset: currentCivil.utcOffset
    };

    return nextDay12Am;
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

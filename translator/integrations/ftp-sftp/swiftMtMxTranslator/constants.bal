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

import ballerinax/financial.iso20022.cash_management as camtIsoRecord;
import ballerinax/financial.iso20022.payment_initiation as painIsoRecord;
import ballerinax/financial.iso20022.payments_clearing_and_settlement as pacsIsoRecord;
import ballerina/lang.regexp;

const OUTWARD = "Outward";
const INWARD = "Inward";

const UNKNOWN = "Unknown";
const NOT_AVAILABLE = "N/A";

const FAILED = "Failed";
const SUCCESSFUL = "Successful";
const SKIPPED = "Skipped";

const OPTION_APPEND = "APPEND";

const RTGS = "RTGS";
const SWIFTMT = "SWIFTMT";
const SWIFTMX = "SWIFTMX";

const MT_MESSAGE_NAMES = [
    "101", "102", "102STP", "103", "103STP", "103REMIT", "104", "107","110", "111", "112", "190", "191", "192", "195",
    "196", "199", "200", "201", "202", "202COV", "203", "204", "205", "205COV", "210", "290", "291", "292", "295",
    "296", "299", "900", "910", "920", "940", "941", "942", "950", "970", "971", "972", "973", "990", "991", "992", 
    "995", "996", "999"];

const MT_TRANS_AMNT_FIELD = ["MT32A", "MT32B", "MT32C", "MT32D"];

final readonly & map<typedesc<record {}>> isoMessageTypes = {
    "pacs.002": pacsIsoRecord:Pacs002Envelope,
    "pacs.003": pacsIsoRecord:Pacs003Envelope,
    "pacs.004": pacsIsoRecord:Pacs004Envelope,
    "pacs.008": pacsIsoRecord:Pacs008Envelope,
    "pacs.009": pacsIsoRecord:Pacs009Envelope,
    "pacs.010": pacsIsoRecord:Pacs010Envelope,
    "pain.001": painIsoRecord:Pain001Envelope,
    "pain.008": painIsoRecord:Pain008Envelope,
    "camt.026": camtIsoRecord:Camt026Envelope,
    "camt.027": camtIsoRecord:Camt027Envelope,
    "camt.028": camtIsoRecord:Camt028Envelope,
    "camt.029": camtIsoRecord:Camt029Envelope,
    "camt.031": camtIsoRecord:Camt031Envelope,
    "camt.033": camtIsoRecord:Camt033Envelope,
    "camt.034": camtIsoRecord:Camt034Envelope,
    "camt.050": camtIsoRecord:Camt050Envelope,
    "camt.052": camtIsoRecord:Camt052Envelope,
    "camt.053": camtIsoRecord:Camt053Envelope,
    "camt.054": camtIsoRecord:Camt054Envelope,
    "camt.055": camtIsoRecord:Camt055Envelope,
    "camt.056": camtIsoRecord:Camt056Envelope,
    "camt.057": camtIsoRecord:Camt057Envelope,
    "camt.060": camtIsoRecord:Camt060Envelope,
    "camt.105": camtIsoRecord:Camt105Envelope,
    "camt.106": camtIsoRecord:Camt106Envelope,
    "camt.107": camtIsoRecord:Camt107Envelope,
    "camt.108": camtIsoRecord:Camt108Envelope,
    "camt.109": camtIsoRecord:Camt109Envelope
};

const string MT_MX_PRE_PROCESS_CONTEXT_PATH = "/mt-mx/pre-process";
const string MT_MX_POST_PROCESS_CONTEXT_PATH = "/mt-mx/post-process";
const string MX_MT_PRE_PROCESS_CONTEXT_PATH = "/mx-mt/pre-process";
const string MX_MT_POST_PROCESS_CONTEXT_PATH = "/mx-mt/post-process";

const string BLOCK2 = "block2";
const string BLOCK3 = "block3";
const string BLOCK4 = "block4";
const string MESSAGE_TYPE = "messageType";
const string VALIDATION_FLAG = "ValidationFlag";
const string VALUE = "value";

regexp:RegExp mtRegex = re `^\{1:[^\}]+\}\{2:[^\}]+\}(\{3:[^\}]+\}\})?(\{4:\n)?(.*\n)*-\}(\{5:[^\}]+\}\})?`;

enum status {
    SUCCESS = "success",
    FAILURE = "failure",
    SKIP = "skip"
}

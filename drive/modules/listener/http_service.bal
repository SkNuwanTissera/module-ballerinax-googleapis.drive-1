// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerina/http;
import ballerinax/googleapis.drive as drive;

service class HttpService {
    
    public string channelUuid;
    public string currentToken;
    public string watchResourceId;
    public json[] currentFileStatus = [];
    public ListenerConfiguration config;
    public string specificFolderOrFileId;
    public drive:Client driveClient;
    public boolean isWatchOnSpecificResource;
    public boolean isFolder = true;
    private SimpleHttpService httpService;
    public MethodNames methods = {};
    private string dnsVerificationFileContent;

    public isolated function init(SimpleHttpService httpService, string channelUuid, string currentToken, 
                                    string watchResourceId, drive:Client driveClient, ListenerConfiguration config, 
                                    boolean isWatchOnSpecificResource, boolean isFolder, string specificFolderOrFileId, 
                                    string dnsVerificationFileContent) {
        self.httpService = httpService;
        self.channelUuid = channelUuid;
        self.currentToken = currentToken;
        self.watchResourceId = watchResourceId;
        self.driveClient = driveClient;
        self.config = config;
        self.isFolder = isFolder;
        self.isWatchOnSpecificResource = isWatchOnSpecificResource;
        self.specificFolderOrFileId = specificFolderOrFileId;
        self.dnsVerificationFileContent = dnsVerificationFileContent;

        string[] methodNames = getServiceMethodNames(httpService);

        foreach var methodName in methodNames {
            match methodName {
                "onFileCreate" => {
                    self.methods.isOnNewFileCreate = true;
                }
                "onFolderCreate" => {
                    self.methods.isOnNewFolderCreate = true;
                }
                "onFileUpdate" => {
                    self.methods.isOnFileUpdate = true;
                }
                "onFolderUpdate" => {
                    self.methods.isOnFolderUpdate = true;
                }
                "onDelete" => {
                    self.methods.isOnDelete = true;
                }
                "onFileTrash" => {
                    self.methods.isOnFileTrash = true;
                }
                "onFolderTrash" => {
                    self.methods.isOnFolderTrash = true;
                }
                _ => {
                    log:printError("Unrecognized method [" + methodName + "] found in the implementation");
                }
            }
        }
    }

    resource isolated function post events(http:Caller caller, http:Request request) returns @tainted error? {
        if(check request.getHeader(GOOGLE_CHANNEL_ID) != self.channelUuid){
            fail error("Diffrent channel IDs found, Resend the watch request");
        } else {
            ChangesListResponse[] response = check getAllChangeList(self.currentToken, self.config);
            foreach ChangesListResponse item in response {
                self.currentToken = item?.newStartPageToken.toString();
                if (self.isWatchOnSpecificResource && self.isFolder) {
                    log:printDebug("Folder watch response processing");
                    check mapEventForSpecificResource(<@untainted> self.specificFolderOrFileId, <@untainted> item, 
                    <@untainted> self.driveClient, <@untainted> self.httpService, self.methods);
                } else if (self.isWatchOnSpecificResource && self.isFolder == false) {
                    log:printDebug("File watch response processing");
                    check mapFileUpdateEvents(self.specificFolderOrFileId, item, self.driveClient, self.httpService, 
                    self.methods);
                } else {
                    log:printDebug("Whole drive watch response processing");
                    check mapEvents(<@untainted>item, <@untainted>self.driveClient, <@untainted>self.httpService, 
                                    <@untainted>self.methods);
                }
            } 
            check caller->respond(http:STATUS_OK);
        }
    }
    
    // Resource function required for domain verification by Google
    resource isolated function get [string name](http:Caller caller) returns @tainted error? {
        http:Response r = new();
        if(self.dnsVerificationFileContent.length() < 100 && 
                self.dnsVerificationFileContent.startsWith(GOOGLE_SITE_VERIFICATION_PREFIX)){
            r.setHeader(CONTENT_TYPE, "text/html; charset=UTF-8");
            r.setTextPayload(self.dnsVerificationFileContent);
            log:printDebug("Domain verification on process");
        } else {
            fail error("Invalid input for domain verification");
        }
        check caller->respond(r);
    }
}


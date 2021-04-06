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

import ballerina/http;
import ballerina/log;
import ballerina/os;
import ballerina/test;
import ballerinax/googleapis_drive as drive;

configurable string callbackURL = os:getEnv("CALLBACK_URL");
configurable string clientId = os:getEnv("CLIENT_ID");
configurable string clientSecret = os:getEnv("CLIENT_SECRET");
configurable string refreshUrl = drive:REFRESH_URL;
configurable string refreshToken = os:getEnv("REFRESH_TOKEN");

drive:Configuration clientConfiguration = {clientConfig: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshUrl: refreshUrl,
        refreshToken: refreshToken
}};

# Event Trigger class  
public class EventTrigger {
    
    public isolated function onNewFolderCreatedEvent(string folderId) {
        log:printInfo(TRIGGER_LOG + "New folder was created : " + folderId);
    }

    public isolated function onFolderDeletedEvent(string folderID) {
        log:printInfo(TRIGGER_LOG + "This folder was removed to the trashed : " + folderID);
    }

    public isolated function onNewFileCreatedEvent(string fileId) {
        log:printInfo(TRIGGER_LOG + "New File was created : " + fileId);
    }

    public isolated function onFileDeletedEvent(string fileId) {
        log:printInfo(TRIGGER_LOG + "This File was removed to the trashed : " + fileId);
    }

    public isolated function onNewFileCreatedInSpecificFolderEvent(string fileId) {
        log:printInfo(TRIGGER_LOG + "A file with Id " + fileId + " was created in side the folder specified");
    }

    public isolated function onNewFolderCreatedInSpecificFolderEvent(string folderId) {
        log:printInfo(TRIGGER_LOG + "A folder with Id " + folderId + " was created in side the folder specified");
    }

    public isolated function onFolderDeletedInSpecificFolderEvent(string folderId) {
        log:printInfo(TRIGGER_LOG + "A folder with Id " + folderId + " was deleted in side the folder specified");
    }

    public isolated function onFileDeletedInSpecificFolderEvent(string fileId) {
        log:printInfo(TRIGGER_LOG + "A file with Id " + fileId + " was deleted in side the folder specified");
    }
    public isolated function onFileUpdateEvent(string fileId) {
        log:printInfo(TRIGGER_LOG + "File updated : " + fileId);
    }
}

ListenerConfiguration congifuration = {
    port: 9090,
    callbackURL: callbackURL,
    clientConfiguration: clientConfiguration,
    eventService: new EventTrigger()
};

listener DriveEventListener gDrivelistener = new (congifuration);

service / on gDrivelistener {
    resource function post gdrive(http:Caller caller, http:Request request) returns string|error? {
        error? procesOutput = gDrivelistener.findEventType(caller, request);
        http:Response response = new;
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error in responding ", 'error = result);
        }
    }
}

@test:Config {enable: false}
public isolated function testDriveAPITrigger() {
    log:printInfo("gDriveClient -> watchFiles()");
    int i = 0;
    while (true) {
        i = 0;
    }
    test:assertTrue(true, msg = "expected to be created a watch in google drive");
}

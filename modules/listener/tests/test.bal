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
import ballerina/test;
import ballerinax/googleapis_drive as drive;

configurable string callbackURL = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshUrl = drive:REFRESH_URL;
configurable string refreshToken = ?;

drive:Configuration clientConfiguration = {clientConfig: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshUrl: refreshUrl,
        refreshToken: refreshToken
}};

ListenerConfiguration congifuration = {
    port: 9090,
    callbackURL: callbackURL,
    clientConfiguration: clientConfiguration
};

listener DriveEventListener gDrivelistener = new (congifuration);

service / on gDrivelistener {
    resource function post gdrive(http:Caller caller, http:Request request) returns @tainted error? {
        EventInfo? eventInfo = check gDrivelistener.findEventType(caller, request);
        if (eventInfo?.eventType == NEW_FILE_CREATED){
            log:print("New File was created : " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == FILE_DELETED_ON_SPECIFIED_FOLDER) {
            log:print("New File was created on specified folder : " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == FILE_DELETED) {
            log:print("File was deleted: " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == FILE_DELETED_ON_SPECIFIED_FOLDER) {
            log:print("File was deleted on specified folder : " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == NEW_FOLDER_CREATED) {
            log:print("New folder was created : " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == NEW_FOLDER_CREATED_ON_SPECIFIED_FOLDER) {
            log:print("New folder was created on specified folder : " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == FOLDER_DELETED) {
            log:print("Folder was deleted : " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == FOLDER_DELETED_ON_SPECIFIED_FOLDER) {
            log:print("Folder was deleted on specified folder : " + eventInfo?.fileOrFolderId.toString());
        } else if (eventInfo?.eventType == FILE_UPDATED) {
            log:print("File was updated on specified folder : " + eventInfo?.fileOrFolderId.toString());
        }
        http:Response response = new;
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error in responding ", err = result);
        }
    }
}

@test:Config {enable: true}
public isolated function testDriveAPITrigger() {
    log:print("gDriveClient -> watchFiles()");
    int i = 0;
    while (true) {
        i = 0;
    }
    test:assertTrue(true, msg = "expected to be created a watch in google drive");
}

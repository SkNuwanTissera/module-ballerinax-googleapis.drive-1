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
import ballerinax/googleapis_drive as drive;
import ballerinax/googleapis_drive.'listener as listen;

configurable string callbackURL = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshUrl = drive:REFRESH_URL;
configurable string refreshToken = ?;

string fileId = "<FILE_ID>";
string parentFolderId = "<PLACE_FOLDER_ID_HERE>";

# Event Trigger class  
public class EventTrigger {
    
    public isolated function onNewFolderCreatedEvent(string folderId) {}

    public isolated function onFolderDeletedEvent(string folderID) {}

    public isolated function onNewFileCreatedEvent(string fileId) {}

    public isolated function onFileDeletedEvent(string fileId) {}

    public isolated function onNewFileCreatedInSpecificFolderEvent(string fileId) {}

    public isolated function onNewFolderCreatedInSpecificFolderEvent(string folderId) {}

    public isolated function onFolderDeletedInSpecificFolderEvent(string folderId) {}

    public isolated function onFileDeletedInSpecificFolderEvent(string fileId) {}

    public isolated function onFileUpdateEvent(string fileId) {
        log:printInfo("Update on file :" + fileId);
    }
}

    drive:Configuration config = {
        clientConfig: {
            clientId: clientId,
            clientSecret: clientSecret,
            refreshUrl: refreshUrl,
            refreshToken: refreshToken
        }
    };

    listen:ListenerConfiguration configuration = {
        port: 9090,
        callbackURL: callbackURL,
        clientConfiguration: config,
        eventService: new EventTrigger(),
        specificFolderOrFileId : parentFolderId
    };

    listener listen:DriveEventListener gDrivelistener = new (configuration);

    service / on gDrivelistener {
        resource function post gdrive(http:Caller caller, http:Request request) returns string|error? {
            error? procesOutput = gDrivelistener.findEventType(caller, request);
            http:Response response = new;
            var result = caller->respond(response);
            if (result is error) {
                log:printError("Error in responding ", err = result);
            }
        }
    }

public function main() returns error? {
    drive:Client driveClient = check new (config);
    drive:File payloadFileMetadata = {
        name : "newFileNameonUpdate",
        mimeType : "application/vnd.google-apps.document",
        description : "A short description of the file"
    };
    drive:File|error response = driveClient->updateFileMetadataById(fileId, payloadFileMetadata);
    if (response is drive:File) {
        log:printInfo(response.toString());
    }
}

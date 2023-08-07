import ballerina/http;
import ballerina/regex;
import ballerina/io;
import ballerina/log;

//Import the SCIM module.
import ballerinax/scim;

configurable string orgName = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string[] scope = [
    "internal_user_mgt_view",
    "internal_user_mgt_list",
    "internal_user_mgt_create",
    "internal_user_mgt_delete",
    "internal_user_mgt_update",
    "internal_user_mgt_delete",
    "internal_group_mgt_view",
    "internal_group_mgt_list",
    "internal_group_mgt_create",
    "internal_group_mgt_delete",
    "internal_group_mgt_update",
    "internal_group_mgt_delete"
];

//Create a SCIM connector configuration
scim:ConnectorConfig scimConfig = {
    orgName: orgName,
    clientId: clientId,
    clientSecret: clientSecret,
    scope: scope
};

//Initialize the SCIM client.
scim:Client scimClient = check new (scimConfig);

type UserCreateRequest record {
    string password;
    string email;
    string name;
};

string salesGroupId = "051a8658-6946-48fc-9edf-b4dea92c8f1b";
string marketingGroupId = "4dfbd183-7adc-4634-9924-b09e95d4979c";
string defaultGroupId = "642e21eb-5e9b-4d7b-8aa5-858d0c19ee7f";

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    resource function get groupUserCount() returns json|error {
        scim:GroupResource salesResponse = check scimClient->getGroup(salesGroupId);
        int salesCount = 0;
        if salesResponse.members != () {
            salesCount = (<scim:Member[]>salesResponse.members).length();
        }
        scim:GroupResource marketingResponse = check scimClient->getGroup(marketingGroupId);
        int marketingCount = 0;
        if marketingResponse.members != () {
            marketingCount = (<scim:Member[]>marketingResponse.members).length();
        }
        json output = {SalesTeamCount: salesCount, MarketingTeamCount: marketingCount};
        return output;
    }

    resource function post createUser(@http:Payload UserCreateRequest payload) returns string|error {
        
        // create user
        scim:UserCreate user = { password: payload.password };
        user.userName = string `DEFAULT/${payload.email}`;
        io:println(user.userName);
        user.name = {formatted: payload.name};
        scim:UserResource response = check scimClient->createUser(user);
        string groupId;
        // add created user to the relevant group
        string createdUser = response.id.toString();
        if regex:matches(payload.email, "[A-Za-z0-9]+@sales\\.greenApps\\.com") {
            groupId = salesGroupId;
        }
        else if regex:matches(payload.email.toString(), "[A-Za-z0-9]+@marketing\\.greenApps\\.com") {
            groupId = marketingGroupId;
        }
        else {
            groupId = defaultGroupId;
        }
        scim:GroupPatch Group = {Operations: [{op: "add", value: {members: [{"value": createdUser, "display": user.userName}]}}]};
        scim:GroupResource groupResponse = check scimClient->patchGroup(groupId, Group);
        return "User Successfully Created";
    }

    resource function get getAllUsers() returns json|error {
        
        log:printInfo("Get All Users ===============================");

        scim:UserResponse|scim:ErrorResponse|error response = scimClient->getUsers();
        if response is scim:UserResponse {
            log:printInfo(response.toString());
            scim:UserResource[] userResources = response.Resources ?: [];
            scim:UserResource user = userResources[0];
            return {
                email: user.userName,
                firstName: user.name?.givenName,
                lastName: user.name?.familyName
            };
        } else if response is scim:ErrorResponse {
            log:printInfo(response.toString());
            return {
                errorCode: response.detail().status,
                message: response.detail().detail
            };
        }
        return {
            errorCode: 500,
            message: "Unknown error occurred"
        };
    }

    resource function get searchProfile(string email) returns json|error {
        
        log:printInfo("Search Profile: " + email + " ===============================");
        string userName = string `DEFAULT/${email}`;
        scim:UserSearch searchData = { filter: string `userName eq ${userName}` };
        scim:UserResponse|scim:ErrorResponse|error response = scimClient->searchUser(searchData);
        if response is scim:UserResponse {
            log:printInfo(response.toString());
            scim:UserResource[] userResources = response.Resources ?: [];
            scim:UserResource user = userResources[0];
            return {
                email: user.userName,
                firstName: user.name?.givenName,
                lastName: user.name?.familyName
            };
        } else if response is scim:ErrorResponse {
            log:printInfo(response.toString());
            return {
                errorCode: response.detail().status,
                message: response.detail().detail
            };
        }
        return {
            errorCode: 500,
            message: "Unknown error occurred"
        };
    }

    resource function delete deleteUser(string email) returns json|error {
        
        // Get user ID
        string userId = "";
        string userName = string `DEFAULT/${email}`;
        scim:UserSearch searchData = {filter: string `userName eq ${userName}`};
        scim:UserResponse|scim:ErrorResponse|error response = scimClient->searchUser(searchData);
        if response is scim:UserResponse {
            scim:UserResource[] userResources = response.Resources ?: [];
            scim:UserResource user = userResources[0];
            userId = user.id ?: "";
        } else if response is scim:ErrorResponse {
            return {
                errorCode: response.detail().status,
                message: response.detail().detail
            };
        } else {
            return {
                errorCode: 500,
                message: "Unknown error occurred"
            };
        }
        if (userId != "") {
            scim:ErrorResponse|error? deleteResponse = scimClient->deleteUser(userId);
            if !(deleteResponse is error) {
                return {
                    status: "success",
                    message: "User deleted successfully"
                };
            }
        } else {
            return {
                errorCode: 404,
                message: string`Coundn't extract the user ID for: ${email}`
            };
        }
    }

}

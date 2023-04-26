import ballerina/http;
import ballerina/log;
import ballerinax/scim;

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # A resource for generating greetings
    # + name - the input string name
    # + return - string name with hello message or error
    resource function get greeting(string name) returns string|error {

        scim:ConnectorConfig config = {
            orgName: "petshop", 
            clientId: "RwqGZaaveYVsyNfwD0OpL3hZk3Ya", 
            clientSecret: "RyouXtghzudBxfUdQoYmdsUo5gUa", 
            scope: ["SYSTEM"]
        };
        scim:Client scimClient = check new (config);

        log:printInfo("==== Get all users");
        scim:UserResponse|error getUsersResult = scimClient->getUsers(domain = "DEFAULT");
        if getUsersResult is scim:UserResponse {
            scim:UserResource[] userResources = getUsersResult.Resources ?: [];
            foreach var user in userResources {
                log:printInfo(user.userName ?: "");
            }
        } else {
            log:printError(getUsersResult.toString());
        }

        // Send a response back to the caller.
        if name is "" {
            return error("name should not be empty!");
        }
        return "Hello, " + name;
    }
}

function printUser(scim:UserResource user) {

    // log:printInfo(user.toJsonString());

    log:printInfo(string`ID: ${user.id ?: ""}`);
    log:printInfo(string`Username: ${user.userName ?: ""}`);
    if (user.name is scim:Name) {
        scim:Name name = user.name ?: {};
        log:printInfo(string`Given name: ${name.givenName ?: ""}`);
        log:printInfo(string`Family name: ${name?.familyName ?: ""}`);
    }
    log:printInfo(string`Nick name: ${user.nickName ?: ""}`);
}


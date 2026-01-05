console.log(">>> msal_bridge.js LOADED");

let msalInstance = null;

window.msalInit = function (clientId, tenantId, redirectUri) {
    console.log(">>> msalInit called");

    msalInstance = new msal.PublicClientApplication({
    auth: {
        clientId: "28dcac5c-ef2d-4dd8-a724-d0a6ef0e0523",
        authority: "https://login.microsoftonline.com/common",
        redirectUri: "http://localhost:57777"
    }
});

    console.log(">>> MSAL initialized");
};

window.msalLogin = async function (scopesJson) {
    console.log(">>> msalLogin called with scopesJson:", scopesJson);

    const scopes = JSON.parse(scopesJson);

    const result = await msalInstance.loginPopup({
        scopes: scopes
    });

    return result.idToken;
};

window.msalGetToken = async function (scopesJson) {
    console.log(">>> msalGetToken called with scopesJson:", scopesJson);

    const scopes = JSON.parse(scopesJson);

    const result = await msalInstance.acquireTokenPopup({
        scopes: scopes
    });

    return result.accessToken;
};
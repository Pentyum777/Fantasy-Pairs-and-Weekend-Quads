// Prevent double‑initialization during Flutter Web hot reload
if (!window.__msalInitialized) {
    window.__msalInitialized = true;

    console.log("MSAL: Initializing...");

    const msalConfig = {
        auth: {
            clientId: "c75121a5-552e-46c6-a357-2e5029b56131",
            authority: "https://login.microsoftonline.com/common",
            redirectUri: window.location.origin
        },
        cache: {
            cacheLocation: "localStorage",
            storeAuthStateInCookie: true
        }
    };

    const msalInstance = new msal.PublicClientApplication(msalConfig);
    let activeAccount = null;

    // Restore account
    const restored = msalInstance.getActiveAccount();
    if (restored) {
        activeAccount = restored;
        console.log("MSAL: Restored active account", activeAccount);
    } else {
        const accounts = msalInstance.getAllAccounts();
        if (accounts.length > 0) {
            msalInstance.setActiveAccount(accounts[0]);
            activeAccount = accounts[0];
            console.log("MSAL: Restored fallback account", activeAccount);
        }
    }

    function dispatchToken(token) {
        console.log("MSAL: Dispatching token event to Dart");
        window.dispatchEvent(new CustomEvent("msalToken", {
            detail: token
        }));
    }

    window.msalLogin = async function (scopesJson) {
        console.log(">>> msalLogin called with:", scopesJson);

        const scopes = JSON.parse(scopesJson);

        try {
            const result = await msalInstance.loginPopup({ scopes });

            msalInstance.setActiveAccount(result.account);
            activeAccount = result.account;

            console.log("MSAL: Login success", result);

            if (result.accessToken) {
                dispatchToken(result.accessToken);
            }

            return result.accessToken || null;

        } catch (err) {
            console.error("MSAL Login Error:", err);
            return null;
        }
    };

    window.msalGetToken = async function (scopesJson) {
        console.log(">>> msalGetToken called with:", scopesJson);

        const scopes = JSON.parse(scopesJson);

        if (!activeAccount) {
            console.warn("MSAL: No active account, calling login...");
            return await window.msalLogin(scopesJson);
        }

        try {
            const result = await msalInstance.acquireTokenSilent({
                scopes,
                account: activeAccount
            });

            console.log("MSAL: Silent token success", result);

            if (result.accessToken) {
                dispatchToken(result.accessToken);
            }

            return result.accessToken || null;

        } catch (err) {
            console.warn("MSAL: Silent token failed, falling back to popup", err);
            return await window.msalLogin(scopesJson);
        }
    };

    console.log("MSAL: Initialization complete.");
}
// Prevent double-initialization during Flutter Web hot reload
if (!window.__msalInitialized) {
    window.__msalInitialized = true;

    console.log("MSAL: Initializing (Redirect + PKCE)...");

    // -------------------------------------------------------------------
    // TOKEN DELIVERY (Callback + Pending Token)
    // -------------------------------------------------------------------
    function deliverToken(token, account) {
        if (typeof window.onMsalToken === "function") {
            console.log("MSAL: Delivering token + account to Flutter");
            window.onMsalToken(token, account);
            window.__pendingMsalToken = null;
            window.__pendingMsalAccount = null;
        } else {
            console.log("MSAL: Flutter not ready, stashing pending token + account");
            window.__pendingMsalToken = token;
            window.__pendingMsalAccount = account;
        }
    }

    // Intercept assignment to window.onMsalToken
    Object.defineProperty(window, "onMsalToken", {
        set: function (callback) {
            console.log("MSAL: Flutter registered onMsalToken callback");
            this.__onMsalToken = callback;

            // Deliver pending token immediately
            if (window.__pendingMsalToken && window.__pendingMsalAccount) {
                console.log("MSAL: Delivering previously stashed token + account");
                callback(window.__pendingMsalToken, window.__pendingMsalAccount);
                window.__pendingMsalToken = null;
                window.__pendingMsalAccount = null;
            }
        },
        get: function () {
            return this.__onMsalToken;
        }
    });

    // -------------------------------------------------------------------
    // MSAL CONFIG
    // -------------------------------------------------------------------
    const msalConfig = {
        auth: {
            clientId: "c75121a5-552e-46c6-a357-2e5029b56131",
            authority: "https://login.microsoftonline.com/common",

            // IMPORTANT: GitHub Pages requires BOTH versions registered in Azure AD
            redirectUri: "https://pentyum777.github.io/Fantasy-Pairs-and-Weekend-Quads/"
        },
        cache: {
            cacheLocation: "localStorage",
            storeAuthStateInCookie: true
        }
    };

    const msalInstance = new msal.PublicClientApplication(msalConfig);
    let activeAccount = null;

    // -------------------------------------------------------------------
    // HANDLE REDIRECT RESULT
    // -------------------------------------------------------------------
    msalInstance.handleRedirectPromise().then((result) => {
        if (result) {
            console.log("MSAL: Redirect login success →", result);

            msalInstance.setActiveAccount(result.account);
            activeAccount = result.account;

            if (result.accessToken) {
                deliverToken(result.accessToken, activeAccount);
            }
        } else {
            console.log("MSAL: No redirect result");
        }
    }).catch((err) => {
        console.error("MSAL Redirect Error:", err);
    });

    // -------------------------------------------------------------------
    // RESTORE ACTIVE ACCOUNT
    // -------------------------------------------------------------------
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

    // -------------------------------------------------------------------
    // LOGIN (REDIRECT)
    // -------------------------------------------------------------------
    window.msalLogin = async function (scopesJson) {
        console.log(">>> msalLogin called with:", scopesJson);

        const scopes = JSON.parse(scopesJson);

        try {
            console.log("MSAL: Starting redirect login...");
            await msalInstance.loginRedirect({ scopes });
        } catch (err) {
            console.error("MSAL Login Redirect Error:", err);
        }
    };

    // -------------------------------------------------------------------
    // SILENT TOKEN ACQUISITION
    // -------------------------------------------------------------------
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
                deliverToken(result.accessToken, activeAccount);
            }

            return result.accessToken || null;

        } catch (err) {
            console.warn("MSAL: Silent token failed, redirecting to login", err);
            await msalInstance.loginRedirect({ scopes });
            return null;
        }
    };

    console.log("MSAL: Initialization complete (Redirect Mode).");
}
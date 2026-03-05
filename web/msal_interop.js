// Load MSAL browser library from CDN
// (Same version you used before)
const msalConfig = {
  auth: {
    clientId: "c75121a5-552e-46c6-a357-2e5029b56131",
    authority: "https://login.microsoftonline.com/common",
    redirectUri: window.location.origin + window.location.pathname
  }
};

const msalInstance = new msal.PublicClientApplication(msalConfig);

// Called by Dart: MsalService.startLogin()
window.msalLogin = async function (scopesJson) {
  console.log("msalLogin called with scopes:", scopesJson);

  const scopes = JSON.parse(scopesJson);

  try {
    const result = await msalInstance.loginPopup({
      scopes: scopes
    });

    const account = {
      username: result.account.username
    };

    if (typeof window.onMsalToken === "function") {
      window.onMsalToken(result.accessToken, account);
    } else {
      window.__pendingMsalToken = result.accessToken;
      window.__pendingMsalAccount = account;
    }
  } catch (err) {
    console.error("MSAL loginPopup error:", err);
  }
};

// Called by Dart: MsalService.startGetToken()
window.msalGetToken = async function (scopesJson) {
  console.log("msalGetToken called with scopes:", scopesJson);

  const scopes = JSON.parse(scopesJson);

  try {
    const result = await msalInstance.acquireTokenSilent({
      scopes: scopes,
      account: msalInstance.getAllAccounts()[0]
    });

    const account = {
      username: result.account.username
    };

    if (typeof window.onMsalToken === "function") {
      window.onMsalToken(result.accessToken, account);
    } else {
      window.__pendingMsalToken = result.accessToken;
      window.__pendingMsalAccount = account;
    }
  } catch (err) {
    console.warn("Silent token failed, falling back to popup:", err);

    return window.msalLogin(scopesJson);
  }
};
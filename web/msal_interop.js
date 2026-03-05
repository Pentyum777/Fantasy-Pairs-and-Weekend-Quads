const msalConfig = {
  auth: {
    clientId: "c75121a5-552e-46c6-a357-2e5029b56131",
    authority: "https://login.microsoftonline.com/common",
    redirectUri: window.location.origin + window.location.pathname
  }
};

const msalInstance = new msal.PublicClientApplication(msalConfig);

window.msalLogin = async function (scopesJson) {
  console.log("msalLogin called with scopes:", scopesJson);

  const scopes = JSON.parse(scopesJson);

  try {
    await msalInstance.loginRedirect({ scopes });
  } catch (err) {
    console.error("MSAL loginRedirect error:", err);
  }
};

window.msalGetToken = async function (scopesJson) {
  console.log("msalGetToken called with scopes:", scopesJson);

  const scopes = JSON.parse(scopesJson);

  try {
    const result = await msalInstance.acquireTokenSilent({
      scopes: scopes,
      account: msalInstance.getAllAccounts()[0]
    });

    const account = { username: result.account.username };

    if (typeof window.onMsalToken === "function") {
      window.onMsalToken(result.accessToken, account);
    } else {
      window.__pendingMsalToken = result.accessToken;
      window.__pendingMsalAccount = account;
    }

  } catch (err) {
    console.warn("Silent token failed, redirecting:", err);
    await msalInstance.loginRedirect({ scopes });
  }
};

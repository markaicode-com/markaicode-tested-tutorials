"use client";
import { ConnectButton } from "thirdweb/react";
import { client } from "./lib/client";
import { generatePayload, isLoggedIn, login, logout } from "./actions/auth";

export function LoginButton() {
  return (
    <ConnectButton
      client={client}
      auth={{
        isLoggedIn: async () => await isLoggedIn(),
        getLoginPayload: async ({ address }) => generatePayload({ address }),
        doLogin: async (params) => await login(params),
        doLogout: async () => await logout(),
      }}
    />
  );
}

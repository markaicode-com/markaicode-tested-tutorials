"use server";
import type { VerifyLoginPayloadParams } from "thirdweb/auth";
import { cookies } from "next/headers";
import { thirdwebAuth } from "../lib/thirdwebAuth";

export const generatePayload = thirdwebAuth.generatePayload;

export async function login(payload: VerifyLoginPayloadParams) {
  const verified = await thirdwebAuth.verifyPayload(payload);
  if (verified.valid) {
    const jwt = await thirdwebAuth.generateJWT({ payload: verified.payload });
    (await cookies()).set("jwt", jwt, { httpOnly: true, secure: true, sameSite: "lax" });
  }
}

export async function isLoggedIn() {
  const jwt = (await cookies()).get("jwt");
  if (!jwt?.value) return false;
  const result = await thirdwebAuth.verifyJWT({ jwt: jwt.value }).catch(() => null);
  return result?.valid ?? false;
}

export async function logout() {
  (await cookies()).delete("jwt");
}

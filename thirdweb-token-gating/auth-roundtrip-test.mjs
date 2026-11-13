import { createThirdwebClient } from "thirdweb";
import { createAuth, signLoginPayload } from "thirdweb/auth";
import { privateKeyToAccount } from "thirdweb/wallets";
import crypto from "node:crypto";
const generatePrivateKey = () => "0x" + crypto.randomBytes(32).toString("hex");
import fs from "node:fs";
const env = Object.fromEntries(fs.readFileSync(".env.local","utf8").trim().split("\n").map(l=>l.split("=")));
const client = createThirdwebClient({ clientId: env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID });
const auth = createAuth({ domain: env.NEXT_PUBLIC_THIRDWEB_AUTH_DOMAIN, adminAccount: privateKeyToAccount({ client, privateKey: env.THIRDWEB_ADMIN_PRIVATE_KEY }), client });
const user = privateKeyToAccount({ client, privateKey: generatePrivateKey() });
const payload = await auth.generatePayload({ address: user.address });
const signed = await signLoginPayload({ payload, account: user });
const v = await auth.verifyPayload(signed);
console.log("verifyPayload valid:", v.valid);
const jwt = await auth.generateJWT({ payload: v.payload });
const j = await auth.verifyJWT({ jwt });
console.log("verifyJWT valid:", j.valid, "sub matches user:", j.valid && j.parsedJWT.sub.toLowerCase() === user.address.toLowerCase());
// tampered signature should fail
const bad = await auth.verifyPayload({ ...signed, signature: signed.signature.slice(0,-4) + "0000" });
console.log("tampered signature valid:", bad.valid);
fs.writeFileSync("jwt.txt", jwt); // used by the curl tests in NOTES.md

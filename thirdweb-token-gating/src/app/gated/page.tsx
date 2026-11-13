import { cookies } from "next/headers";
import { thirdwebAuth } from "../lib/thirdwebAuth";
import { hasAccess } from "../lib/hasAccess";

export default async function GatedPage() {
  const jwt = (await cookies()).get("jwt");
  if (!jwt?.value) return <p>You are not logged in. <a href="/">Log in</a></p>;

  // verifyJWT throws on a garbled cookie, so treat any error as "not valid".
  const auth = await thirdwebAuth.verifyJWT({ jwt: jwt.value }).catch(() => null);
  if (!auth?.valid) return <p>Your session expired. <a href="/">Log in again</a></p>;

  const address = auth.parsedJWT.sub;
  if (!(await hasAccess(address))) {
    return <p>You are logged in, but this wallet doesn&apos;t hold the membership NFT.</p>;
  }

  return <p>Welcome, member. This content is only for NFT holders.</p>;
}

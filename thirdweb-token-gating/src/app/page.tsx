import { LoginButton } from "./LoginButton";

export default function Home() {
  return (
    <main>
      <h1>Members area</h1>
      <LoginButton />
      <p><a href="/gated">Go to the members-only page</a></p>
    </main>
  );
}

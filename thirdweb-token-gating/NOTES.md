# thirdweb v5 token gating (Next.js 16): test notes

Companion code for https://markaicode.com/token-gating-website-thirdweb-sdk-v4/

Adapted from thirdweb's official example (github.com/thirdweb-example/gated-site-example, thirdweb 5.22 / Next 14) for thirdweb 5.122.1 and Next.js 16, with two fixes found while testing.

## Test run: 2026-11-14 (Linux container, Node 22.22, npm 10.9)

Versions: next 16.4.6, react 19.3.1, thirdweb 5.122.1, @x402/{core,evm,svm,extensions} 2.31.0.

| Check | Result |
|---|---|
| `next build` with only next/react/thirdweb installed | FAILED: Module not found `@x402/core/client`, `@x402/evm`, `@x402/svm/exact/client` (optional peers of @coinbase/cdp-sdk 1.62.0, pulled in by thirdweb → @base-org/account). Same with `--webpack`. |
| `next build` after `npm i @x402/core @x402/evm @x402/svm @x402/extensions` | OK |
| Login round trip (auth-roundtrip-test.mjs): generatePayload → signLoginPayload → verifyPayload → generateJWT → verifyJWT | verifyPayload valid: true; verifyJWT valid: true; JWT subject = signing wallet |
| Tampered signature | verifyPayload valid: false |
| GET /gated, no cookie | "You are not logged in" (HTTP 200) |
| GET /gated, garbled `jwt` cookie, original code | HTTP 500: verifyJWT throws "Invalid JWT header" |
| GET /gated, garbled cookie, with `.catch(() => null)` | "Your session expired" (HTTP 200) |
| GET /gated, valid JWT, chain unreachable (no network to the RPC in the container) | original: HTTP 500 `fetch failed`; with try/catch in hasAccess: "doesn't hold the membership NFT" (fails closed, HTTP 200) |
| GET /gated, valid JWT, wallet that holds the NFT | NOT TESTED (needs network access to Base and a real NFT) |

The wallet connect UI (ConnectButton in a browser) was not tested.

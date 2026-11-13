import { getContract } from "thirdweb";
import { base } from "thirdweb/chains";
import { balanceOf } from "thirdweb/extensions/erc721";
import { client } from "./client";

// Your NFT collection (ERC-721) and the chain it lives on.
const nft = getContract({
  client,
  chain: base,
  address: process.env.NFT_CONTRACT_ADDRESS as string,
});

export async function hasAccess(address: string): Promise<boolean> {
  try {
    const owned = await balanceOf({ contract: nft, owner: address });
    return owned >= 1n;
  } catch (err) {
    // If the blockchain can't be reached, fail closed: no access.
    console.error("NFT balance check failed", err);
    return false;
  }
}
